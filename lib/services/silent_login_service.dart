// lib/services/silent_login_service.dart
// 静默登录服务 - 处理下载链接参数（v1.9.x 新增）
//
// 处理从落地页验证后下载App的场景：
//   1. 读取下载链接参数（token + phone）
//   2. 保存待处理凭证
//   3. 执行静默登录

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class SilentLoginService {
  static const String _pendingTokenKey = 'pending_token';
  static const String _pendingPhoneKey = 'pending_phone';

  /// 从 URL 参数中提取 Token 和 Phone
  ///
  /// 支持格式：
  ///   - zaine://download?token=xxx&phone=xxx
  ///   - https://zaine.love/download?token=xxx&phone=xxx
  static (String?, String?) parseDownloadParams(Uri uri) {
    // 只处理 /download 路径
    final path = uri.path;
    if (!path.endsWith('/download') && !path.contains('download')) {
      return (null, null);
    }

    final token = uri.queryParameters['token'];
    final phoneBase64 = uri.queryParameters['phone'];

    if (token == null || token.isEmpty) {
      return (null, null);
    }

    // 解码 Base64 手机号
    String? phone;
    if (phoneBase64 != null && phoneBase64.isNotEmpty) {
      try {
        phone = utf8.decode(base64Decode(phoneBase64));
      } catch (e) {
        debugPrint('[SilentLogin] Base64解码手机号失败: $e');
      }
    }

    debugPrint('[SilentLogin] 解析下载参数: token=${token.substring(0, token.length > 10 ? 10 : token.length)}..., phone=$phone');
    return (token, phone);
  }

  /// 保存待处理的 Token 和 Phone
  static Future<void> savePendingAuth(String token, String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingTokenKey, token);
    await prefs.setString(_pendingPhoneKey, phone);
    debugPrint('[SilentLogin] 已保存待处理登录凭证: phone=$phone');
  }

  /// 执行静默登录
  /// 将 pending_token 和 pending_phone 写入正式存储
  static Future<bool> performSilentLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_pendingTokenKey);
    final phone = prefs.getString(_pendingPhoneKey);

    if (token == null || token.isEmpty) {
      debugPrint('[SilentLogin] 无待处理Token，跳过静默登录');
      return false;
    }

    // 验证Token格式（JWT: header.payload.signature）
    if (!_isValidToken(token)) {
      debugPrint('[SilentLogin] Token格式无效，清除并跳过静默登录');
      await clearPendingLogin();
      return false;
    }

    // 写入正式存储
    // 【修复 v1.9.61】静默登录前清除旧账号残留的头像数据（防止切换账号后头像串用）
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

    await prefs.setString('auth_token', token);
    await prefs.setString('user_phone', phone ?? '');
    await prefs.setBool('is_logged_in', true);
    await prefs.setBool('onboarding_completed', true); // 跳过引导页

    // 清除 pending 数据
    await prefs.remove(_pendingTokenKey);
    await prefs.remove(_pendingPhoneKey);

    debugPrint('[SilentLogin] ✅ 静默登录完成: phone=$phone');
    return true;
  }

  /// 是否有待处理的静默登录
  static Future<bool> hasPendingLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_pendingTokenKey);
    return token != null && token.isNotEmpty;
  }

  /// 清除待处理的静默登录（取消登录）
  static Future<void> clearPendingLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingTokenKey);
    await prefs.remove(_pendingPhoneKey);
    debugPrint('[SilentLogin] 已清除待处理登录凭证');
  }

  /// 验证Token格式是否有效
  /// JWT格式：header.payload.signature
  static bool _isValidToken(String token) {
    if (token.isEmpty) return false;
    final parts = token.split('.');
    return parts.length == 3;
  }
}
