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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../api_service.dart';
import '../deep_link_service.dart';
import '../membership_service.dart';

class AuthService {
  /// 手机号快速登录（v1.5 快速登录，无需验证码）
  /// [phone] 手机号，[cardId] 可选守护卡邀请码
  static Future<Map<String, dynamic>> quickLogin(String phone, {String? cardId}) async {
    final res = await ApiService.post(
      '/api/auth/quick-login',
      body: {
        'phone': phone,
        if (cardId != null && cardId.isNotEmpty) 'card_id': cardId,
      },
      auth: false,
    );
    debugPrint('[AuthService] quickLogin 响应: success=${res['success']}, token=${res['token'] != null ? '有' : '无/null'}, userId=${res['userId']}');
    if (res['success'] == true && res['token'] != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        // 【修复 v1.9.61】登录前先清除旧账号残留的头像数据（防止切换账号后头像串用）
        final oldUid = prefs.getString('user_id');
        if (oldUid != null && oldUid.isNotEmpty) {
          await prefs.remove('avatar_path_$oldUid');
          await prefs.remove('avatar_base64_$oldUid');
        }
        await prefs.remove('avatar_path'); // 清 fallback 键
        await prefs.remove('avatar_base64');
        await prefs.remove('user_name'); // 【v1.9.73】清除旧账号用户名（防止签到徽章串名）
        try {
          final dir = await getApplicationDocumentsDirectory();
          final f = File('${dir.path}/avatar.png');
          if (await f.exists()) await f.delete();
        } catch (_) {}

        await prefs.setString('auth_token', res['token']);
        await prefs.setString('user_phone', phone);
        await prefs.setBool('is_logged_in', true);
        if (res['userId'] != null) {
          await prefs.setString('user_id', res['userId']);
        }
        debugPrint('[AuthService] ✅ 登录状态已写入 SP: auth_token, user_phone, is_logged_in, user_id');
        // 同步会员信息到本地
        await MembershipService.syncFromLoginResponse(res);
        // 核销 pending card_code（裂变注册奖励）— 失败不影响登录
        await DeepLinkService.processPendingCardCode(phone);
        // 【修复 v1.9.61】清除残留签到状态缓存（防止从其他账号切换后状态污染）
        await prefs.remove('last_check_in_date');
        await prefs.remove('continuous_days');
        await prefs.remove('total_check_in_days');
        await prefs.remove('checkin_history');
      } catch (e) {
        // 后处理异常（如裂变绑定API失败）不影响登录，token已保存，用户已登录成功
        debugPrint('[AuthService] ⚠️ quickLogin 后处理异常（不影响登录）: $e');
      }
    } else if (res['success'] == true && res['token'] == null) {
      debugPrint('[AuthService] ⚠️ 后端返回 success=true 但 token 为 null，未写入登录状态');
    } else {
      debugPrint('[AuthService] ❌ 登录失败: ${res['error'] ?? res['message'] ?? '未知错误'}');
    }
    return res;
  }

  /// 发送短信验证码（v1.9.x 新方案，需验证码登录）
  /// [phone] 手机号，[cardCode] 可选守护卡邀请码
  static Future<Map<String, dynamic>> sendCode({
    required String phone,
    String? cardCode,
  }) async {
    debugPrint('[AuthService] 发送验证码: phone=$phone, cardCode=$cardCode');
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
    debugPrint('[AuthService] 验证验证码: phone=$phone, code=$code, cardCode=$cardCode');
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
      // 【修复 v1.9.61】登录前先清除旧账号残留的头像数据
      final oldUid = prefs.getString('user_id');
      if (oldUid != null && oldUid.isNotEmpty) {
        await prefs.remove('avatar_path_$oldUid');
        await prefs.remove('avatar_base64_$oldUid');
      }
      await prefs.remove('avatar_path');
      await prefs.remove('avatar_base64');
      try {
        final dir = await getApplicationDocumentsDirectory();
        final f = File('${dir.path}/avatar.png');
        if (await f.exists()) await f.delete();
      } catch (_) {}

      await prefs.setString('auth_token', res['token']);
      await prefs.setString('user_id', res['userId'] ?? '');
      await prefs.setString('user_phone', phone);
      await prefs.setBool('is_logged_in', true);
      await prefs.setBool('onboarding_completed', true);
      debugPrint('[AuthService] ✅ 验证登录成功: userId=${res['userId']}, isNew=${res['is_new_user']}');
      // 同步会员信息到本地
      await MembershipService.syncFromLoginResponse(res);
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

  /// 退出登录
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    // 【修复 v1.9.73】保留头像缓存和文件（与健康档案/紧急联系人保持一致）
    // 不退出时清除头像，确保重新登录后头像仍然存在
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('user_name'); // 【v1.9.73】退出时清除用户名
    await prefs.setBool('is_logged_in', false);
    await MembershipService.clear();
    // 【修复 v1.9.61】退出登录清除签到状态缓存
    await prefs.remove('last_check_in_date');
    await prefs.remove('continuous_days');
    await prefs.remove('total_check_in_days');
    await prefs.remove('checkin_history');
  }

  /// 检查登录状态
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return token != null && token.isNotEmpty;
  }
}
