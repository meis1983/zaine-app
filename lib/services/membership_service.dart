// lib/services/membership_service.dart
// 会员等级状态管理（v2.1）
// MVP阶段：本地缓存会员等级，开发者模式可模拟切换

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class MembershipService {
  /// 会员等级
  static const String levelFree = 'free';   // 体验版
  static const String levelSmart = 'smart'; // 智能版

  /// SharedPreferences key
  static const String _keyLevel = 'membership_level';
  static const String _keyExpireAt = 'membership_expire_at';
  static const String _keyAutoCallLimit = 'membership_auto_call_limit';
  static const String _keyMaxContacts = 'membership_max_contacts';

  /// 体验版配置
  static const int freeAutoCallLimit = 1;
  static const int freeMaxContacts = 5;

  /// 智能版配置
  static const int smartAutoCallLimit = 3;
  static const int smartMaxContacts = 10;

  /// 是否智能版会员
  static bool isSmartMember() {
    // 优先从内存缓存读取
    if (_cachedLevel.isNotEmpty) {
      return _cachedLevel == levelSmart;
    }
    return false; // 默认体验版
  }

  /// 获取当前会员等级
  static String getLevel() {
    if (_cachedLevel.isNotEmpty) return _cachedLevel;
    return levelFree;
  }

  /// 获取紧急求助快捷拨打/短信上限
  static int getAutoCallLimit() {
    if (_cachedAutoCallLimit > 0) return _cachedAutoCallLimit;
    return isSmartMember() ? smartAutoCallLimit : freeAutoCallLimit;
  }

  /// 获取最大联系人数量
  static int getMaxContacts() {
    if (_cachedMaxContacts > 0) return _cachedMaxContacts;
    return isSmartMember() ? smartMaxContacts : freeMaxContacts;
  }

  // 内存缓存（登录成功后从后端同步到本地）
  static String _cachedLevel = '';
  static String _cachedExpireAt = '';
  static int _cachedAutoCallLimit = 0;
  static int _cachedMaxContacts = 0;

  /// 从后端登录响应同步会员信息到本地
  static Future<void> syncFromLoginResponse(Map<String, dynamic> response) async {
    try {
      final level = (response['membership_level'] ?? levelFree).toString();
      final expireAt = (response['membership_expire_at'] ?? '').toString();
      final autoCallLimit = response['auto_call_limit'] as int? ?? 0;
      final maxContacts = response['max_contacts'] as int? ?? 0;

      // 更新内存缓存
      _cachedLevel = level;
      _cachedExpireAt = expireAt;
      _cachedAutoCallLimit = autoCallLimit;
      _cachedMaxContacts = maxContacts;

      // 持久化到本地
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLevel, level);
      await prefs.setString(_keyExpireAt, expireAt);
      await prefs.setInt(_keyAutoCallLimit, autoCallLimit);
      await prefs.setInt(_keyMaxContacts, maxContacts);

      debugPrint('[Membership] 同步会员信息: level=$level, autoCallLimit=$autoCallLimit, maxContacts=$maxContacts');
    } catch (e) {
      debugPrint('[Membership] 同步会员信息失败: $e');
    }
  }

  /// 从本地存储加载会员信息（App启动时调用）
  static Future<void> loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedLevel = prefs.getString(_keyLevel) ?? levelFree;
      _cachedExpireAt = prefs.getString(_keyExpireAt) ?? '';
      _cachedAutoCallLimit = prefs.getInt(_keyAutoCallLimit) ?? 0;
      _cachedMaxContacts = prefs.getInt(_keyMaxContacts) ?? 0;

      debugPrint('[Membership] 从本地加载: level=$_cachedLevel, autoCallLimit=$_cachedAutoCallLimit');
    } catch (e) {
      debugPrint('[Membership] 加载本地会员信息失败: $e');
    }
  }

  /// 开发者模式：设置会员等级（仅用于测试）
  static Future<void> setMembershipForDebug(String level) async {
    if (level != levelFree && level != levelSmart) return;

    _cachedLevel = level;
    _cachedAutoCallLimit = level == levelSmart ? smartAutoCallLimit : freeAutoCallLimit;
    _cachedMaxContacts = level == levelSmart ? smartMaxContacts : freeMaxContacts;
    _cachedExpireAt = level == levelSmart
        ? DateTime.now().add(const Duration(days: 30)).toIso8601String()
        : '';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLevel, _cachedLevel);
    await prefs.setString(_keyExpireAt, _cachedExpireAt);
    await prefs.setInt(_keyAutoCallLimit, _cachedAutoCallLimit);
    await prefs.setInt(_keyMaxContacts, _cachedMaxContacts);

    debugPrint('[Membership] 开发者模式切换: level=$level');
  }

  /// 清除会员信息（退出登录时调用）
  static Future<void> clear() async {
    _cachedLevel = '';
    _cachedExpireAt = '';
    _cachedAutoCallLimit = 0;
    _cachedMaxContacts = 0;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLevel);
    await prefs.remove(_keyExpireAt);
    await prefs.remove(_keyAutoCallLimit);
    await prefs.remove(_keyMaxContacts);
  }
}
