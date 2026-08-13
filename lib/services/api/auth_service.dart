// lib/services/api/auth_service.dart
// 登录/注册 API（v1.4/v1.5，v1.9.x 新增短信验证流程）
//
// 提供统一的认证接口：
//   - quickLogin: 手机号快速登录（旧，无验证码）
//   - sendCode: 发送短信验证码（v1.9.x 新增）
//   - verifyAndDownload: 验证验证码+裂变绑定（v1.9.x 新增）
//   - isLoggedIn: 检查登录状态
//   - logout: 退出登录

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../api_service.dart';
import '../deep_link_service.dart';
import '../membership_service.dart';
import '../guardian_card_service.dart';
import '../platform/health_service.dart';

/// 安全存储实例（单例）
const _secureStorage = FlutterSecureStorage(
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);

class AuthService {
  /// 安全存储 Token（使用 Keychain）
  static Future<void> _saveToken(String token) async {
    await _secureStorage.write(key: 'auth_token', value: token);
  }

  /// 读取 Token（从 Keychain）
  static Future<String?> _getToken() async {
    return await _secureStorage.read(key: 'auth_token');
  }

  /// 删除 Token（从 Keychain）
  static Future<void> _deleteToken() async {
    await _secureStorage.delete(key: 'auth_token');
  }

  /// 获取 Token（统一入口）
  /// 从 Keychain 读取（主存储）
  /// 【防御 v1.91.0】捕获 Keychain 异常，失败时返回 null（视为未登录）
  static Future<String?> getToken() async {
    try {
      final token = await _getToken();
      return (token != null && token.isNotEmpty) ? token : null;
    } catch (e) {
      if (kDebugMode) debugPrint('[AuthService] ⚠️ 读取 Token 失败: $e');
      return null;
    }
  }

  // ========== 用户身份信息服务 ==========

  /// 获取当前用户 ID（统一入口）
  /// 从 Keychain 读取（主存储）
  /// 【防御 v1.91.0】捕获 Keychain 异常，失败时返回 null
  static Future<String?> getUserId() async {
    try {
      final userId = await _secureStorage.read(key: 'user_id');
      return (userId != null && userId.isNotEmpty) ? userId : null;
    } catch (e) {
      if (kDebugMode) debugPrint('[AuthService] ⚠️ 读取 user_id 失败: $e');
      return null;
    }
  }

  /// 获取当前用户手机号（统一入口）
  /// 从 Keychain 读取（主存储）
  /// 【防御 v1.91.0】捕获 Keychain 异常，失败时返回 null
  static Future<String?> getUserPhone() async {
    try {
      final phone = await _secureStorage.read(key: 'user_phone');
      return (phone != null && phone.isNotEmpty) ? phone : null;
    } catch (e) {
      if (kDebugMode) debugPrint('[AuthService] ⚠️ 读取 user_phone 失败: $e');
      return null;
    }
  }

  /// 手机号快速登录（v1.5 快速登录，无需验证码）
  /// [phone] 手机号，[cardId] 可选守护卡邀请码
  /// [invitePhone] 可选，邀请人手机号（紧急联系人邀请）[v1.76.0]
  /// [enableBidirectional] 可选，是否建立双向守护 [v1.76.0]
  static Future<Map<String, dynamic>> quickLogin(
    String phone, {
    String? cardId,
    String? invitePhone,
    bool enableBidirectional = false,
  }) async {
    final res = await ApiService.post(
      '/api/auth/quick-login',
      body: {
        'phone': phone,
        if (cardId != null && cardId.isNotEmpty) 'card_id': cardId,
        if (invitePhone != null && invitePhone.isNotEmpty) 'invite_phone': invitePhone,
        if (enableBidirectional) 'enable_bidirectional': true,
      },
      auth: false,
    );
    if (kDebugMode) debugPrint('[AuthService] quickLogin 响应: success=${res['success']}, token=${res['token'] != null ? '有' : '无/null'}, userId=${res['userId']}');
    if (res['success'] == true && res['token'] != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        // 【修复 v1.80.0】同一用户重新登录时不清除头像和用户数据
        final oldUid = prefs.getString('user_id');
        final newUid = res['userId'] ?? '';
        final isSameUser = oldUid != null && oldUid.isNotEmpty && oldUid == newUid;
        if (!isSameUser && oldUid != null && oldUid.isNotEmpty) {
          // 只有切换账号时才清除旧账号头像数据
          await prefs.remove('avatar_path_$oldUid');
          await prefs.remove('avatar_base64_$oldUid');
          await prefs.remove('avatar_path'); // 清 fallback 键
          await prefs.remove('avatar_base64');
          await prefs.remove('user_name');
          // 【修复 v1.91.0】清除旧账号的签到隔离缓存
          await prefs.remove('last_check_in_date_$oldUid');
          await prefs.remove('continuous_days_$oldUid');
          await prefs.remove('total_check_in_days_$oldUid');
          await prefs.remove('checkin_history_$oldUid');
        try {
          final dir = await getApplicationDocumentsDirectory();
          final f = File('${dir.path}/avatar.png');
          if (await f.exists()) await f.delete();
          final rf = File('${dir.path}/avatar_remote_$oldUid.png'); // 清旧账号隔离远端头像
          if (await rf.exists()) await rf.delete();
        } catch (_) {}
        // 【修复 v1.91.0】清除 Flutter 图像内存缓存，防止旧头像残影
        try { PaintingBinding.instance.imageCache.clear(); } catch (_) {}
        // 【v1.97.4 修复】清除联系人缓存，防止切换账号串号
        await _clearContactCaches();
      }
      if (kDebugMode) debugPrint('[AuthService] ${isSameUser ? "同一用户重新登录，保留本地数据" : "切换账号，已清除旧数据"}');

        await _saveToken(res['token']);
        // 【修复 v1.94.x】手机号归一化为纯数字（去除 +、空格、横线），避免 SOS 短信出现 ++
        final normalizedPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
        // 【修复 v1.77.0】敏感信息存储到 Keychain（安全，主存储）
        await _secureStorage.write(key: 'user_phone', value: normalizedPhone);
        await _secureStorage.write(key: 'user_id', value: res['userId'] ?? '');
        // 【v1.90.0】保留 SP 双写以兼容现有 40+ 处读取（逐步迁移到 Keychain）
        await prefs.setString('user_phone', normalizedPhone);
        await prefs.setString('user_id', res['userId'] ?? '');
        await prefs.setBool('is_logged_in', true); // 非敏感，保留在 SP
        // 注意：user_name 和 avatar 仍然存储在 SP（非敏感，且需要频繁读取）
        if (kDebugMode) debugPrint('[AuthService] ✅ 登录状态已写入 Keychain + SP');
        // 同步会员信息到本地
        await MembershipService.syncFromLoginResponse(res);
        // 核销 pending card_code（裂变注册奖励）— 失败不影响登录
        await DeepLinkService.processPendingCardCode(phone);
        // 初始化守护卡额度（新用户首次登录自动获得 3 张）
        await GuardianCardService.initGiftCards();
        // 【修复 v1.9.61】清除残留签到状态缓存（防止从其他账号切换后状态污染）
        await prefs.remove('last_check_in_date');
        await prefs.remove('continuous_days');
        await prefs.remove('total_check_in_days');
        await prefs.remove('checkin_history');
        // 【修复 v1.91.0】同时清除新账号可能残余的隔离缓存
        await prefs.remove('last_check_in_date_$newUid');
        await prefs.remove('continuous_days_$newUid');
        await prefs.remove('total_check_in_days_$newUid');
        await prefs.remove('checkin_history_$newUid');
      } catch (e) {
        // 后处理异常（如裂变绑定API失败）不影响登录，token已保存，用户已登录成功
        if (kDebugMode) debugPrint('[AuthService] ⚠️ quickLogin 后处理异常（不影响登录）: $e');
      }
    } else if (res['success'] == true && res['token'] == null) {
      if (kDebugMode) debugPrint('[AuthService] ⚠️ 后端返回 success=true 但 token 为 null，未写入登录状态');
    } else {
      if (kDebugMode) debugPrint('[AuthService] ❌ 登录失败: ${res['error'] ?? res['message'] ?? '未知错误'}');
    }
    return res;
  }

  /// 发送短信验证码（v1.9.x 新方案，需验证码登录）
  /// [phone] 手机号，[cardCode] 可选守护卡邀请码
  static Future<Map<String, dynamic>> sendCode({
    required String phone,
    String? cardCode,
  }) async {
    if (kDebugMode) debugPrint('[AuthService] 发送验证码: phone=$phone, cardCode=$cardCode');
    return await ApiService.post(
      '/api/auth/send-code',
      body: {
        'phone': phone,
        if (cardCode != null && cardCode.isNotEmpty) 'card_code': cardCode,
      },
      auth: false,
    );
  }

  /// 验证短信验证码，返回登录凭证 + 下载链接（v1.9.x 新方案）
  /// [phone] 手机号，[code] 验证码，[cardCode] 可选守护卡邀请码
  ///
  /// 成功后存储 token。card_code 绑定由后端 verify-and-link 接口在服务器端完成。
  /// 返回数据含 download_url（落地页用）。
  static Future<Map<String, dynamic>> verifyAndDownload({
    required String phone,
    required String code,
    String? cardCode,
  }) async {
    if (kDebugMode) debugPrint('[AuthService] 验证验证码: phone=$phone, code=$code, cardCode=$cardCode');
    final res = await ApiService.post(
      '/api/auth/verify-and-link',
      body: {
        'phone': phone,
        'code': code,
        if (cardCode != null && cardCode.isNotEmpty) 'card_code': cardCode,
      },
      auth: false,
    );

    if (res['success'] == true && res['token'] != null) {
      // 存储登录凭证
      final prefs = await SharedPreferences.getInstance();
      // 【修复 v1.80.0】同一用户重新登录时不清除头像和用户数据
      final oldUid = prefs.getString('user_id');
      final newUid = res['userId'] ?? '';
      final isSameUser = oldUid != null && oldUid.isNotEmpty && oldUid == newUid;
      if (!isSameUser && oldUid != null && oldUid.isNotEmpty) {
        await prefs.remove('avatar_path_$oldUid');
        await prefs.remove('avatar_base64_$oldUid');
        await prefs.remove('avatar_path');
        await prefs.remove('avatar_base64');
        // 【修复 v1.91.0】清除旧账号的签到隔离缓存
        await prefs.remove('last_check_in_date_$oldUid');
        await prefs.remove('continuous_days_$oldUid');
        await prefs.remove('total_check_in_days_$oldUid');
        await prefs.remove('checkin_history_$oldUid');
        try {
          final dir = await getApplicationDocumentsDirectory();
          final f = File('${dir.path}/avatar.png');
          if (await f.exists()) await f.delete();
          final rf = File('${dir.path}/avatar_remote_$oldUid.png');
          if (await rf.exists()) await rf.delete();
        } catch (_) {}
        // 【修复 v1.91.0】清除 Flutter 图像内存缓存
        try { PaintingBinding.instance.imageCache.clear(); } catch (_) {}
      }

      await _saveToken(res['token']);
      // 【修复 v1.77.0】敏感信息存储到 Keychain（安全，主存储）
      await _secureStorage.write(key: 'user_id', value: res['userId'] ?? '');
      await _secureStorage.write(key: 'user_phone', value: phone);
      // 【v1.90.0】保留 SP 双写以兼容现有 40+ 处读取（逐步迁移到 Keychain）
      await prefs.setString('user_id', res['userId'] ?? '');
      await prefs.setString('user_phone', phone);
      await prefs.setBool('is_logged_in', true); // 非敏感，保留在 SP
      await prefs.setBool('onboarding_completed', true); // 非敏感，保留在 SP
      if (kDebugMode) debugPrint('[AuthService] ✅ 验证登录成功: userId=${res['userId']}, isNew=${res['is_new_user']}');
      // 同步会员信息到本地
      await MembershipService.syncFromLoginResponse(res);
      // 初始化守护卡额度（新用户首次登录自动获得 3 张）
      await GuardianCardService.initGiftCards();
      // card_code 绑定由后端 verify-and-link 接口在服务器端完成，无需重复调用
      // 【修复 v1.9.61】清除残留签到状态缓存（防止从其他账号切换后状态污染）
      final prefs2 = await SharedPreferences.getInstance();
      await prefs2.remove('last_check_in_date');
      await prefs2.remove('continuous_days');
      await prefs2.remove('total_check_in_days');
      await prefs2.remove('checkin_history');
    }

    return res;
  }

  /// 【v1.97.4 修复】清除所有按手机号缓存的守护圈联系人状态（contact_* 键未做 per-uid 隔离），
  /// 防止切换账号后旧账号的签到/激活/头像缓存串到新账号。
  static Future<void> _clearContactCaches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      int n = 0;
      for (final k in keys) {
        if (k.startsWith('contact_')) {
          await prefs.remove(k);
          n++;
        }
      }
      if (kDebugMode) debugPrint('[AuthService] 已清除 $n 个 contact_* 缓存');
    } catch (e) {
      debugPrint('[AuthService._clearContactCaches] 异常: $e');
    }
  }

  /// 退出登录
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    // 【v1.97.4 修复】先取旧 user_id 再清除（修复 +177 在 remove 之后才读导致 oldUid 恒为 null 的 bug）
    final oldUid = prefs.getString('user_id') ?? '';

    // 【v1.97.4 修复】彻底隔离头像，杜绝多账号切换串号：
    // 1) 清除非隔离兜底键
    await prefs.remove('avatar_path');
    await prefs.remove('avatar_base64');
    // 2) 清除旧账号按 uid 隔离的头像键（A 退出后 B 不会读到 A 的）
    if (oldUid.isNotEmpty) {
      await prefs.remove('avatar_path_$oldUid');
      await prefs.remove('avatar_base64_$oldUid');
    }
    // 3) 删除所有头像文件：本地选择用的 avatar.png + 远端同步用的旧共享 avatar_remote.png + 按 uid 隔离的远端文件
    try {
      final dir = await getApplicationDocumentsDirectory();
      final names = ['avatar.png', 'avatar_remote.png'];
      if (oldUid.isNotEmpty) names.add('avatar_remote_$oldUid.png');
      for (final name in names) {
        final f = File('${dir.path}/$name');
        if (await f.exists()) await f.delete();
      }
    } catch (e) {
      debugPrint('[AuthService.logout] 清理头像文件异常: $e');
    }
    // 4) 清除全局档案（user_profile 非隔离，B 登录前若未重同步会残留 A 的姓名/头像）
    await prefs.remove('user_profile');
    if (oldUid.isNotEmpty) await prefs.remove('user_profile_$oldUid');
    // 5) 清除 Flutter 图像内存缓存（防止旧头像残影）
    try { PaintingBinding.instance.imageCache.clear(); } catch (_) {}
    // 6) 清除 HealthKit「健康数据镜像缓存」，【保留】授权粘性标记 health_authorized：
    //    HealthKit 授权是设备级（iOS 对 App 整体授权，与登录账号无关），同一台手机任意账号都应视为已授权；
    //    旧逻辑 clearAuthorized() 把标记也清掉，导致切账号后守护卡先闪「未检测」再靠实时探测回「守护中」——跳动根因之一。
    await HealthService.clearHealthMirror();
    // 7) 【v1.97.4 修复】清除按手机号缓存的守护圈联系人状态（contact_* 键未做 per-uid 隔离），
    //    防止切换账号后旧账号的签到/激活/头像缓存串到新账号。
    await _clearContactCaches();
    debugPrint('[AuthService.logout] 头像/档案/HealthKit 镜像/联系人缓存已彻底清理（oldUid=$oldUid）');

    // 【修复 v1.90.1】清除 SharedPreferences 中的 user_id / user_phone
    await prefs.remove('user_id');
    await prefs.remove('user_phone');
    await _deleteToken();
    // 【修复 v1.77.0】从 Keychain 中删除敏感信息
    await _secureStorage.delete(key: 'user_id');
    await _secureStorage.delete(key: 'user_phone');
    // 【修复 v1.77.0】同时从 SP 中清除敏感信息（双写兼容，退出时双清）
    await prefs.remove('user_name'); // 【v1.9.73】退出时清除用户名（SP 中，非敏感）
    await prefs.setBool('is_logged_in', false);
    await MembershipService.clear();
    // 【修复 v1.9.61】退出登录清除签到状态缓存
    await prefs.remove('last_check_in_date');
    await prefs.remove('continuous_days');
    await prefs.remove('total_check_in_days');
    await prefs.remove('checkin_history');
  }

  /// 检查登录状态
  /// 【防御 v1.91.0】捕获所有 Keychain 异常，防止崩溃
  /// 同时验证 token 和 user_id 同时存在（防止 Keychain 写入不完整）
  static Future<bool> isLoggedIn() async {
    // 1. 优先从 Keychain 读取 token（主存储，安全），失败则重试最多 3 次
    String? token;
    int attempts = 0;
    try {
      for (int retry = 0; retry < 3; retry++) {
        attempts = retry + 1;
        try {
          token = await _getToken();
        } catch (e) {
          if (kDebugMode) debugPrint('[AuthService] ⚠️ Keychain 读取 token 失败 (尝试 $attempts/3): $e');
          if (retry < 2) await Future.delayed(const Duration(milliseconds: 150));
          continue;
        }
        if (token != null && token.isNotEmpty) break;
        if (retry < 2) await Future.delayed(const Duration(milliseconds: 150));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[AuthService] ⚠️ isLoggedIn 异常: $e');
      return false;
    }

    if (token != null && token.isNotEmpty) {
      // 【防御 v1.91.0】确认 user_id 也存在（防止 Keychain 写入不完整）
      try {
        final userId = await _secureStorage.read(key: 'user_id');
        if (userId == null || userId.isEmpty) {
          if (kDebugMode) debugPrint('[AuthService] ⚠️ token 存在但 user_id 缺失，视为未登录');
          return false;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[AuthService] ⚠️ 验证 user_id 失败: $e');
        return false;
      }
      if (kDebugMode && attempts > 1) debugPrint('[AuthService] ✅ Keychain 第 $attempts 次读取成功');
      return true;
    }

    // 2. Keychain 读取失败，检查 user_id 是否存在（兜底）
    // 旧版本登录的用户可能没有 SP token 备份，但有 user_id 记录
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId != null && userId.isNotEmpty) {
        if (kDebugMode) debugPrint('[AuthService] ⚠️ token 丢失但 user_id 存在，允许继续（兜底）');
        return true;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[AuthService] ⚠️ 读取 user_id 失败: $e');
    }

    return false;
  }

  // ========== 【新增 v1.9.78】Apple Sign In ==========
  
  /// Apple Sign In 登录
  /// 调用后端 /auth/apple-login 接口
  static Future<Map<String, dynamic>> appleLogin({
    required String identityToken,
    String? authorizationCode,
    String? userId,
    String? email,
    String? givenName,
    String? familyName,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('[AuthService] Apple 登录开始...');
      }

      final res = await ApiService.post('/auth/apple-login', body: {
        'identity_token': identityToken,
        'authorization_code': authorizationCode,
        'user_id': userId,
        'email': email,
        'given_name': givenName,
        'family_name': familyName,
      });

      if (res['success'] == true) {
        // 保存 token 和 user_id
        if (res['token'] != null) {
          await _saveToken(res['token']);
        }
        if (res['userId'] != null) {
          await _secureStorage.write(key: 'user_id', value: res['userId']);
        }

        if (kDebugMode) {
          debugPrint('[AuthService] Apple 登录成功, userId=${res['userId']}');
        }
      }

      return res;
    } catch (e) {
      if (kDebugMode) debugPrint('[AuthService] Apple 登录异常: $e');
      return {'success': false, 'message': 'Apple 登录失败: $e'};
    }
  }
}
