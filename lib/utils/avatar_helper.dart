// lib/utils/avatar_helper.dart
// 头像存储工具 — 用用户ID隔离 key，防止切换账号时头像串用

import 'package:shared_preferences/shared_preferences.dart';
import '../services/api/auth_service.dart';

class AvatarHelper {
  /// 获取当前用户ID（可能为空）
  static Future<String> _getUserId() async {
    final userId = await AuthService.getUserId();
    return userId ?? '';
  }

  /// 获取用户隔离的 avatar_path key
  static Future<String> pathKey() async {
    final uid = await _getUserId();
    return uid.isNotEmpty ? 'avatar_path_$uid' : 'avatar_path';
  }

  /// 获取用户隔离的 avatar_base64 key
  static Future<String> base64Key() async {
    final uid = await _getUserId();
    return uid.isNotEmpty ? 'avatar_base64_$uid' : 'avatar_base64';
  }

  /// 读取头像路径
  static Future<String?> getPath(SharedPreferences prefs) async {
    final key = await pathKey();
    return prefs.getString(key);
  }

  /// 保存头像路径
  static Future<void> setPath(SharedPreferences prefs, String path) async {
    final key = await pathKey();
    await prefs.setString(key, path);
  }

  /// 读取头像 base64
  static Future<String?> getBase64(SharedPreferences prefs) async {
    final key = await base64Key();
    return prefs.getString(key);
  }

  /// 保存头像 base64
  static Future<void> setBase64(SharedPreferences prefs, String base64) async {
    final key = await base64Key();
    await prefs.setString(key, base64);
  }

  /// 删除所有头像记录
  static Future<void> clear(SharedPreferences prefs) async {
    final uid = await _getUserId();
    await prefs.remove('avatar_path_$uid');
    await prefs.remove('avatar_base64_$uid');
  }
}
