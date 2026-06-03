/// 季节配色工具
///
/// 根据当前月份自动返回对应的季节主题色，
/// 用于守护卡信封、卡片等组件的动态配色。
library;

import 'package:flutter/material.dart';

/// 季节枚举
enum Season {
  spring, // 春季 (3-5月)
  summer, // 夏季 (6-8月)
  autumn, // 秋季 (9-11月)
  winter, // 冬季 (12-2月)
}

/// 季节主题配置
class SeasonTheme {
  final String name;
  final String emoji;
  final Color primaryColor; // 主色调
  final Color secondaryColor; // 辅助色
  final Color accentColor; // 强调色
  final Color envelopeColor; // 信封底色
  final Color envelopeFlapColor; // 信封翻盖色
  final Color sealColor; // 封印色
  final LinearGradient? envelopeGradient; // 信封渐变

  const SeasonTheme({
    required this.name,
    required this.emoji,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.envelopeColor,
    required this.envelopeFlapColor,
    required this.sealColor,
    this.envelopeGradient,
  });
}

/// 季节配色管理器
class SeasonThemeManager {
  SeasonThemeManager._();

  /// 春季主题 - 樱花粉
  static const SeasonTheme spring = SeasonTheme(
    name: '春',
    emoji: '🌸',
    primaryColor: Color(0xFFFFB7C5), // 樱花粉
    secondaryColor: Color(0xFFFFE4E9), // 浅粉
    accentColor: Color(0xFFE91E63), // 粉红
    envelopeColor: Color(0xFFFFF0F3), // 信封底色
    envelopeFlapColor: Color(0xFFFFD6DD), // 翻盖色
    sealColor: Color(0xFFC2185B), // 封印深粉
    envelopeGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFF0F3), Color(0xFFFFE4E9)],
    ),
  );

  /// 夏季主题 - 荷叶绿
  static const SeasonTheme summer = SeasonTheme(
    name: '夏',
    emoji: '🌻',
    primaryColor: Color(0xFF81C784), // 荷叶绿
    secondaryColor: Color(0xFFC8E6C9), // 浅绿
    accentColor: Color(0xFF4CAF50), // 翠绿
    envelopeColor: Color(0xFFF1F8E9), // 信封底色
    envelopeFlapColor: Color(0xFFDCEDC8), // 翻盖色
    sealColor: Color(0xFF388E3C), // 封印深绿
    envelopeGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF1F8E9), Color(0xFFDCEDC8)],
    ),
  );

  /// 秋季主题 - 枫叶橙
  static const SeasonTheme autumn = SeasonTheme(
    name: '秋',
    emoji: '🍂',
    primaryColor: Color(0xFFFFB74D), // 枫叶橙
    secondaryColor: Color(0xFFFFE0B2), // 浅橙
    accentColor: Color(0xFFFF9800), // 橙黄
    envelopeColor: Color(0xFFFFF8E1), // 信封底色
    envelopeFlapColor: Color(0xFFFFECB3), // 翻盖色
    sealColor: Color(0xFFF57C00), // 封印深橙
    envelopeGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
    ),
  );

  /// 冬季主题 - 雪花蓝
  static const SeasonTheme winter = SeasonTheme(
    name: '冬',
    emoji: '❄️',
    primaryColor: Color(0xFF90CAF9), // 雪花蓝
    secondaryColor: Color(0xFFBBDEFB), // 浅蓝
    accentColor: Color(0xFF2196F3), // 天蓝
    envelopeColor: Color(0xFFE3F2FD), // 信封底色
    envelopeFlapColor: Color(0xFFBBDEFB), // 翻盖色
    sealColor: Color(0xFF1976D2), // 封印深蓝
    envelopeGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
    ),
  );

  /// 根据月份获取季节
  static Season getSeasonByMonth([int? month]) {
    final m = month ?? DateTime.now().month;
    if (m >= 3 && m <= 5) return Season.spring;
    if (m >= 6 && m <= 8) return Season.summer;
    if (m >= 9 && m <= 11) return Season.autumn;
    return Season.winter; // 12, 1, 2
  }

  /// 获取当前季节主题
  static SeasonTheme getCurrentTheme() {
    return getThemeBySeason(getSeasonByMonth());
  }

  /// 根据季节获取主题
  static SeasonTheme getThemeBySeason(Season season) {
    switch (season) {
      case Season.spring:
        return spring;
      case Season.summer:
        return summer;
      case Season.autumn:
        return autumn;
      case Season.winter:
        return winter;
    }
  }

  /// 获取所有季节主题（用于设置页选择）
  static List<SeasonTheme> get allThemes => [spring, summer, autumn, winter];

  /// 获取季节问候语
  static String getSeasonGreeting() {
    final season = getSeasonByMonth();
    final hour = DateTime.now().hour;
    String timeGreeting;
    if (hour < 6) {
      timeGreeting = '夜深了';
    } else if (hour < 12) {
      timeGreeting = '早安';
    } else if (hour < 18) {
      timeGreeting = '午安';
    } else {
      timeGreeting = '晚安';
    }

    switch (season) {
      case Season.spring:
        return '$timeGreeting，春暖花开';
      case Season.summer:
        return '$timeGreeting，夏日清凉';
      case Season.autumn:
        return '$timeGreeting，秋高气爽';
      case Season.winter:
        return '$timeGreeting，冬日温暖';
    }
  }
}
