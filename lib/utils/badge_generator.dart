import 'dart:math';
import 'package:flutter/material.dart';
import '../l10n/i18n.dart';

/// ====== 徽章数据模型 ======
class BadgeData {
  final int days;
  final String emoji;
  final String title;
  final Color badgeColor;
  final String message;
  final int bgStyle;     // 0-6: 放射/波纹/星点/藤蔓/水波/火焰/雪花
  final int ringStyle;   // 0-6: 实线/虚线/双圈/点阵/锯齿/花边/编织
  final int decoType;    // 0-6: ★♥🌸🍃💧🔥❄
  final double hueShift;
  final int particleCount;
  final double glowRadius;
  final double bgOpacity;
  final bool isMilestone;
  final bool isFestival;
  final bool isReturnCheckin;
  final bool isSolarTerm;

  const BadgeData({
    required this.days,
    required this.emoji,
    required this.title,
    required this.badgeColor,
    required this.message,
    required this.bgStyle,
    required this.ringStyle,
    required this.decoType,
    required this.hueShift,
    required this.particleCount,
    required this.glowRadius,
    required this.bgOpacity,
    this.isMilestone = false,
    this.isFestival = false,
    this.isReturnCheckin = false,
    this.isSolarTerm = false,
  });
}

/// ====== 等级信息 ======
class LevelInfo {
  final String emoji;
  final String title;
  final Color color;
  final String desc;
  const LevelInfo(this.emoji, this.title, this.color, this.desc);
}

/// ====== 节日/节气数据 ======
class _SpecialDate {
  final String name;
  final String message;
  final String emoji;
  final int month;
  final int day;
  final Color color;
  const _SpecialDate(this.name, this.message, this.emoji, this.month, this.day, this.color);
}

/// ====== 里程碑数据 ======
class _MilestoneInfo {
  final String title;
  final String message;
  final String emoji;
  final Color color;
  const _MilestoneInfo(this.title, this.message, this.emoji, this.color);
}

/// ====== 主生成器 ======
class BadgeGenerator {
  // ───────── 50级徽章体系 ─────────
  /// 根据连续签到天数获取徽章等级信息
  /// 供首页、弹窗、分享卡片统一调用
  static LevelInfo getLevel(int days) {
    if (days >= 1825) return LevelInfo('🌟👑🌟', tr.z0052, Color(0xFFFFD700), tr.z0053);
    if (days >= 1400) return LevelInfo('🏆🏆🏆', tr.z0054,   Color(0xFFE91E63), tr.z0055);
    if (days >= 1100) return LevelInfo('👑👑👑', tr.z0056,   Color(0xFF9C27B0), tr.z0057);
    if (days >= 900)  return LevelInfo('🏆🏆', tr.z0058,   Color(0xFF673AB7), tr.z0059);
    if (days >= 730)  return LevelInfo('💎💎💎', tr.z0060,   Color(0xFF7C4DFF), tr.z0061);
    if (days >= 650)  return LevelInfo('👑👑', tr.z0062,   Color(0xFF3F51B5), tr.z0063);
    if (days >= 550)  return LevelInfo('💎💎', tr.z0064,   Color(0xFF2196F3), tr.z0065);
    if (days >= 450)  return LevelInfo('🏆', tr.z0066,   Color(0xFF03A9F4), tr.z0067);
    if (days >= 365)  return LevelInfo('🔥🔥', tr.z0068,   Color(0xFFFF6B35), tr.z0069);
    if (days >= 300)  return LevelInfo('👑', tr.z0070,   Color(0xFFFF9800), tr.z0071);
    if (days >= 250)  return LevelInfo('🥇', tr.z0072,   Color(0xFFFFC107), tr.z0073);
    if (days >= 200)  return LevelInfo('💎', tr.z0074,   Color(0xFF7C4DFF), tr.z0075);
    if (days >= 180)  return LevelInfo('🥈', tr.z0076,   Color(0xFF90A4AE), tr.z0077);
    if (days >= 160)  return LevelInfo('🥉', tr.z0078,   Color(0xFFCD7F32), tr.z0079);
    if (days >= 140)  return LevelInfo('🏅', tr.z0080,   Color(0xFFFFA726), tr.z0081);
    if (days >= 120)  return LevelInfo('🎖️', tr.z0082,   Color(0xFFEF5350), tr.z0083);
    if (days >= 100)  return LevelInfo('⭐', tr.z0011,   Color(0xFF9C27B0), tr.z0084);
    if (days >= 95)   return LevelInfo('🎨', tr.z0085,   Color(0xFFEC407A), tr.z0086);
    if (days >= 90)   return LevelInfo('💫', tr.z0087,   Color(0xFFAB47BC), tr.z0088);
    if (days >= 85)   return LevelInfo('🎭', tr.z0089,   Color(0xFF7E57C2), tr.z0090);
    if (days >= 80)   return LevelInfo('🎪', tr.z0091,   Color(0xFF5C6BC0), tr.z0092);
    if (days >= 75)   return LevelInfo('🏕️', tr.z0093,   Color(0xFF42A5F5), tr.z0094);
    if (days >= 70)   return LevelInfo('🏔️', tr.z0095,   Color(0xFF29B6F6), tr.z0096);
    if (days >= 65)   return LevelInfo('🌋', tr.z0097,   Color(0xFFFF7043), tr.z0098);
    if (days >= 60)   return LevelInfo('🔥', tr.z0099,   Color(0xFFFF5722), tr.z0100);
    if (days >= 55)   return LevelInfo('🌊', tr.z0101,   Color(0xFF26C6DA), tr.z0102);
    if (days >= 50)   return LevelInfo('⚡', tr.z0103,   Color(0xFFFFCA28), tr.z0104);
    if (days >= 45)   return LevelInfo('☁️', tr.z0105,   Color(0xFF81D4FA), tr.z0106);
    if (days >= 40)   return LevelInfo('🌈', tr.z0107,   Color(0xFFFF7043), tr.z0108);
    if (days >= 35)   return LevelInfo('🌙', tr.z0109,   Color(0xFF9FA8DA), tr.z0110);
    if (days >= 30)   return LevelInfo('🌟', tr.z0012,   Color(0xFF3F51B5), tr.z0111);
    if (days >= 28)   return LevelInfo('🌰', tr.z0112,   Color(0xFF8D6E63), tr.z0113);
    if (days >= 26)   return LevelInfo('🍂', tr.z0114,   Color(0xFFA1887F), tr.z0115);
    if (days >= 24)   return LevelInfo('🍁', tr.z0116,   Color(0xFFEF5350), tr.z0117);
    if (days >= 22)   return LevelInfo('🌳', tr.z0118,   Color(0xFF66BB6A), tr.z0119);
    if (days >= 20)   return LevelInfo('🌲', tr.z0120,   Color(0xFF43A047), tr.z0121);
    if (days >= 18)   return LevelInfo('🌵', tr.z0122,     Color(0xFF9CCC65), tr.z0123);
    if (days >= 16)   return LevelInfo('🌴', tr.z0124,   Color(0xFF7CB342), tr.z0125);
    if (days >= 14)   return LevelInfo('🌺', tr.z0126,   Color(0xFFFF4081), tr.z0127);
    if (days >= 12)   return LevelInfo('🌹', tr.z0128,   Color(0xFFE91E63), tr.z0129);
    if (days >= 10)   return LevelInfo('🌻', tr.z0130,   Color(0xFFFF9800), tr.z0131);
    if (days >= 9)    return LevelInfo('🌼', tr.z0132,   Color(0xFFFFB74D), tr.z0133);
    if (days >= 8)    return LevelInfo('🌸', tr.z0134,   Color(0xFFF48FB1), tr.z0135);
    if (days >= 7)    return LevelInfo('✨', tr.z0136,   Color(0xFF2196F3), tr.z0137);
    if (days >= 6)    return LevelInfo('🌺', tr.z0138,   Color(0xFF26A69A), tr.z0139);
    if (days >= 5)    return LevelInfo('🌷', tr.z0140,   Color(0xFFEC407A), tr.z0141);
    if (days >= 4)    return LevelInfo('🌾', tr.z0142,   Color(0xFF8BC34A), tr.z0143);
    if (days >= 3)    return LevelInfo('🍀', tr.z0144,     Color(0xFF4CAF50), tr.z0145);
    if (days >= 2)    return LevelInfo('🌿', tr.z0146,   Color(0xFF66BB6A), tr.z0147);
    return LevelInfo('🌱', tr.z0148, Color(0xFF4CAF50), tr.z0013);
  }

  // ───────── 30条日常轮换文案 ─────────
  static List<String> _dailyMessages = [
    tr.z0013,
    tr.z0149,
    tr.z0150,
    tr.z0151,
    tr.z0152,
    tr.z0153,
    tr.z0154,
    tr.z0155,
    tr.z0156,
    tr.z0157,
    tr.z0158,
    tr.z0159,
    tr.z0160,
    tr.z0161,
    tr.z0162,
    tr.z0163,
    tr.z0164,
    tr.z0165,
    tr.z0166,
    tr.z0167,
    tr.z0168,
    tr.z0169,
    tr.z0170,
    tr.z0171,
    tr.z0172,
    tr.z0173,
    tr.z0174,
    tr.z0175,
    tr.z0176,
    tr.z0177,
  ];

  // ───────── 7级断签回归文案 ─────────
  static final List<_ReturnLevel> _returnLevels = [
    _ReturnLevel(0, 1,     tr.z0178),
    _ReturnLevel(2, 3,     tr.z0179),
    _ReturnLevel(4, 7,     tr.z0180),
    _ReturnLevel(8, 14,    tr.z0181),
    _ReturnLevel(15, 30,   tr.z0182),
    _ReturnLevel(31, 90,   tr.z0183),
    _ReturnLevel(91, 99999, tr.z0184),
  ];

  static String _getReturnMessage(int absentDays) {
    for (final lvl in _returnLevels) {
      if (absentDays >= lvl.min && absentDays <= lvl.max) return lvl.message;
    }
    return _returnLevels.last.message;
  }

  // ───────── 里程碑（10个）─────────
  static final Map<int, _MilestoneInfo> _milestones = {
    7:   _MilestoneInfo(tr.z0185, tr.z0186, '🌈', Color(0xFFE91E63)),
    10:  _MilestoneInfo(tr.z0187, tr.z0188, '⭐', Color(0xFFFFD700)),
    20:  _MilestoneInfo(tr.z0189, tr.z0190, '🌸', Color(0xFFFF69B4)),
    30:  _MilestoneInfo(tr.z0012, tr.z0191, '🌟', Color(0xFF3F51B5)),
    45:  _MilestoneInfo(tr.z0192, tr.z0193, '🌙', Color(0xFF9C27B0)),
    60:  _MilestoneInfo(tr.z0194, tr.z0195, '🔥', Color(0xFFFF4500)),
    90:  _MilestoneInfo(tr.z0196, tr.z0197, '🌿', Color(0xFF4CAF50)),
    100: _MilestoneInfo(tr.z0011, tr.z0198, '⭐', Color(0xFF9C27B0)),
    180: _MilestoneInfo(tr.z0199, tr.z0200, '💎', Color(0xFF7C4DFF)),
    365: _MilestoneInfo(tr.z0201, tr.z0202, '👑', Color(0xFFFFD700)),
  };

  static _MilestoneInfo? _matchMilestone(int days) {
    if (_milestones.containsKey(days)) return _milestones[days];
    // 每旬 30/60/90/120/150...
    if (days % 30 == 0 && days >= 30) {
      return _MilestoneInfo(tr.z0203(days), tr.z0204(days), '🎯', const Color(0xFF2196F3));
    }
    return null;
  }

  // ───────── 法定节假日（7个）─────────
  // 说明：端午、中秋等基于农历的节日此处使用「近似公历日期」，
  //       春节和除夕由 _festivalsForDate(year) 动态按农历推算，保证不偏年。
  static List<_SpecialDate> _festivalsStatic = [
    _SpecialDate(tr.z0205, tr.z0206, '🎉', 1, 1, Color(0xFFE91E63)),
    _SpecialDate(tr.z0207, tr.z0208, '🌿', 4, 5, Color(0xFF4CAF50)),
    _SpecialDate(tr.z0209, tr.z0210, '🏋️', 5, 1, Color(0xFFFF9800)),
    _SpecialDate(tr.z0211, tr.z0212, '🎋', 6, 19, Color(0xFF795548)),
    _SpecialDate(tr.z0213, tr.z0214, '🌕', 9, 25, Color(0xFFFFD700)),
    _SpecialDate(tr.z0215, tr.z0216, '🇨🇳', 10, 1, Color(0xFFF44336)),
  ];

  /// 春节（正月初一）公历日期速查表（2020-2030）。
  /// 农历年与公历年的对应每年不同，必须按当前年份查表，不能硬编码单一日期。
  /// 数据来源：紫金山天文台 / 香港天文台公开发布的农历日期表（权威）。
  static const Map<int, List<int>> _lunarNewYearDates = {
    2020: [1, 25],
    2021: [2, 12],
    2022: [2, 1],
    2023: [1, 22],
    2024: [2, 10],
    2025: [1, 29],
    2026: [2, 17],
    2027: [2, 6],
    2028: [1, 26],
    2029: [2, 13],
    2030: [2, 3],
  };

  /// 除夕（农历年最后一天）公历日期速查表。
  /// 除夕 = 春节前一天
  static const Map<int, List<int>> _lunarNewYearEveDates = {
    2020: [1, 24],
    2021: [2, 11],
    2022: [1, 31],
    2023: [1, 21],
    2024: [2, 9],
    2025: [1, 28],
    2026: [2, 16],
    2027: [2, 5],
    2028: [1, 25],
    2029: [2, 12],
    2030: [2, 2],
  };

  /// 根据年份返回「春节」配置，日期自动按公历查表
  static _SpecialDate _springFestivalForYear(int year) {
    final md = _lunarNewYearDates[year] ?? _lunarNewYearDates[2026]!;
    return _SpecialDate(tr.z0217, tr.z0218, '🧧', md[0], md[1], const Color(0xFFFF4500));
  }

  /// 根据年份返回「除夕」配置
  static _SpecialDate _newYearEveForYear(int year) {
    final md = _lunarNewYearEveDates[year] ?? _lunarNewYearEveDates[2026]!;
    return _SpecialDate(tr.z0219, tr.z0220, '🎊', md[0], md[1], const Color(0xFFD32F2F));
  }

  /// 根据年份返回当年的法定节日列表（春节+除夕按年动态）
  static List<_SpecialDate> _festivalsForDate(int year) {
    return [
      _springFestivalForYear(year),
      ..._festivalsStatic,
    ];
  }

  /// 根据年份返回当年的传统节日列表（含除夕）
  static List<_SpecialDate> _tradFestivalsForDate(int year) {
    return [
      _SpecialDate(tr.z0221, tr.z0222, '🏮', 3, 3, Color(0xFFFF69B4)),
      _SpecialDate(tr.z0223, tr.z0224, '🐉', 3, 20, Color(0xFF4CAF50)),
      _SpecialDate(tr.z0225, tr.z0226, '💖', 8, 19, Color(0xFFE91E63)),
      _SpecialDate(tr.z0227, tr.z0228, '🏔️', 10, 18, Color(0xFFFF9800)),
      _newYearEveForYear(year),
    ];
  }

  // ───────── 二十四节气（24个）─────────
  // 8个「四立二分二至」大节点保留emoji，其余16个普通覆盖
  static final List<_SpecialDate> _solarTerms = [
    _SpecialDate(tr.z0229, tr.z0230, '❄️', 1, 5, Color(0xFF90CAF9)),
    _SpecialDate(tr.z0231, tr.z0232, '🧊', 1, 20, Color(0xFF64B5F6)),
    _SpecialDate(tr.z0233, tr.z0234, '🌱', 2, 4, Color(0xFF4CAF50)),
    _SpecialDate(tr.z0235, tr.z0236, '💧', 2, 18, Color(0xFF42A5F5)),
    _SpecialDate(tr.z0237, tr.z0238, '⚡', 3, 5, Color(0xFFFFCA28)),
    _SpecialDate(tr.z0239, tr.z0240, '☯️', 3, 20, Color(0xFF8BC34A)),
    _SpecialDate(tr.z0241, tr.z0242, '🌿', 4, 4, Color(0xFF66BB6A)),
    _SpecialDate(tr.z0243, tr.z0244, '🌾', 4, 20, Color(0xFF43A047)),
    _SpecialDate(tr.z0245, tr.z0246, '☀️', 5, 5, Color(0xFFFF7043)),
    _SpecialDate(tr.z0247, tr.z0248, '🌻', 5, 21, Color(0xFFFFCA28)),
    _SpecialDate(tr.z0249, tr.z0250, '🌾', 6, 5, Color(0xFF8D6E63)),
    _SpecialDate(tr.z0251, tr.z0252, '☀️', 6, 21, Color(0xFFFF6D00)),
    _SpecialDate(tr.z0253, tr.z0254, '🌴', 7, 7, Color(0xFFFF8A65)),
    _SpecialDate(tr.z0255, tr.z0256, '🔥', 7, 23, Color(0xFFE64A19)),
    _SpecialDate(tr.z0257, tr.z0258, '🍂', 8, 7, Color(0xFFFFAB40)),
    _SpecialDate(tr.z0259, tr.z0260, '🌤️', 8, 23, Color(0xFF90A4AE)),
    _SpecialDate(tr.z0261, tr.z0262, '💧', 9, 7, Color(0xFF80DEEA)),
    _SpecialDate(tr.z0263, tr.z0264, '🍁', 9, 23, Color(0xFFFF8F00)),
    _SpecialDate(tr.z0265, tr.z0266, '🍂', 10, 8, Color(0xFFA1887F)),
    _SpecialDate(tr.z0267, tr.z0268, '❄️', 10, 23, Color(0xFF78909C)),
    _SpecialDate(tr.z0269, tr.z0270, '🌨️', 11, 7, Color(0xFF90CAF9)),
    _SpecialDate(tr.z0271, tr.z0272, '❄️', 11, 22, Color(0xFFB3E5FC)),
    _SpecialDate(tr.z0273, tr.z0274, '☃️', 12, 7, Color(0xFFE0E0E0)),
    _SpecialDate(tr.z0275, tr.z0276, '🥟', 12, 22, Color(0xFF42A5F5)),
  ];

  /// 四立二分二至（8个大节气）保留emoji特效
  static const _bigSolarTerms = {2, 6, 9, 12, 15, 18, 21, 24}; // 1-indexed

  // ───────── 匹配逻辑 ─────────
  static _SpecialDate? _findByDate(List<_SpecialDate> list, int m, int d) {
    for (final item in list) {
      if (item.month == m && item.day == d) return item;
    }
    return null;
  }

  /// 核心生成方法
  /// [days] 当前连续签到天数
  /// [isReturnCheckin] 是否是断签后回归签到
  /// [absentDays] 断签天数（仅 isReturnCheckin=true 时需要）
  /// [date] 指定日期（用于测试）
  static BadgeData generate(int days, {bool isReturnCheckin = false, int absentDays = 0, DateTime? date}) {
    final now = date ?? DateTime.now();
    final m = now.month, d = now.day;
    final year = now.year;

    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;

    // 背景图案：用日期种子，每天不重复（7种循环，但每天不同）
    final bgStyle = dayOfYear % 7;
    final ringStyle = dayOfYear % 7;
    final decoType = dayOfYear % 7;
    final hueShift = (days * 7) % 360;
    final particleCount = 3 + (days % 8);
    final glowRadius = 12.0 + (days % 7) * 2;
    final bgOpacity = 0.06 + (days % 10) * 0.01;

    // ====== 优先级匹配 ======
    // 🥇 法定节假日（春节按年动态查表，2026年=2/17）
    final festival = _findByDate(_festivalsForDate(year), m, d);
    if (festival != null) {
      return BadgeData(
        days: days, emoji: festival.emoji, title: festival.name,
        badgeColor: festival.color, message: festival.message,
        bgStyle: bgStyle, ringStyle: ringStyle, decoType: decoType,
        hueShift: hueShift.toDouble(), particleCount: particleCount,
        glowRadius: glowRadius, bgOpacity: bgOpacity, isFestival: true,
      );
    }

    // 🥈 传统节日（含除夕，按年动态查表）
    final trad = _findByDate(_tradFestivalsForDate(year), m, d);
    if (trad != null) {
      final lvl = getLevel(days);
      return BadgeData(
        days: days, emoji: lvl.emoji, title: trad.name,
        badgeColor: lvl.color, message: trad.message,
        bgStyle: bgStyle, ringStyle: ringStyle, decoType: decoType,
        hueShift: hueShift.toDouble(), particleCount: particleCount,
        glowRadius: glowRadius, bgOpacity: bgOpacity, isFestival: true,
      );
    }

    // 🥉 里程碑
    final milestone = _matchMilestone(days);
    if (milestone != null) {
      return BadgeData(
        days: days, emoji: milestone.emoji, title: milestone.title,
        badgeColor: milestone.color, message: milestone.message,
        bgStyle: bgStyle, ringStyle: ringStyle, decoType: decoType,
        hueShift: hueShift.toDouble(), particleCount: particleCount,
        glowRadius: glowRadius, bgOpacity: bgOpacity, isMilestone: true,
      );
    }

    // 🏅 二十四节气
    final solarTerm = _findByDate(_solarTerms, m, d);
    if (solarTerm != null) {
      final lvl = getLevel(days);
      final isBig = _bigSolarTerms.contains(_solarTerms.indexOf(solarTerm) + 1);
      return BadgeData(
        days: days, emoji: isBig ? solarTerm.emoji : lvl.emoji,
        title: solarTerm.name, badgeColor: lvl.color, message: solarTerm.message,
        bgStyle: bgStyle, ringStyle: ringStyle, decoType: decoType,
        hueShift: hueShift.toDouble(), particleCount: particleCount,
        glowRadius: glowRadius, bgOpacity: bgOpacity, isSolarTerm: true,
      );
    }

    // 💪 断签回归
    if (isReturnCheckin) {
      final actualAbsentDays = absentDays > 0 ? absentDays : days; // 兜底：如果没传 absentDays，用 days 估算
      return BadgeData(
        days: days, emoji: '🤗', title: tr.z0277,
        badgeColor: const Color(0xFFFF9800), message: _getReturnMessage(actualAbsentDays),
        bgStyle: bgStyle, ringStyle: ringStyle, decoType: decoType,
        hueShift: hueShift.toDouble(), particleCount: particleCount,
        glowRadius: glowRadius, bgOpacity: bgOpacity, isReturnCheckin: true,
      );
    }

    // 📜 日常
    final lvl = getLevel(days);
    return BadgeData(
      days: days, emoji: lvl.emoji, title: lvl.title,
      badgeColor: lvl.color, message: _dailyMessages[days % 30],
      bgStyle: bgStyle, ringStyle: ringStyle, decoType: decoType,
      hueShift: hueShift.toDouble(), particleCount: particleCount,
      glowRadius: glowRadius, bgOpacity: bgOpacity,
    );
  }

  // ───────── 装饰元素字符 ─────────
  static const decoChars = ['★', '♥', '🌸', '🍃', '💧', '🔥', '❄'];

  /// 色相偏移后的颜色
  static Color shiftHue(Color color, double shift) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withHue((hsl.hue + shift) % 360).toColor();
  }

  /// 背景图案画家索引
  static CustomPainter bgPainter(int style, Color color, double opacity, int particleCount) {
    switch (style) {
      case 0: return _RadialPainter(color, opacity);
      case 1: return _RingPainter(color, opacity, particleCount);
      case 2: return _StarPainter(color, opacity, particleCount);
      case 3: return _VinePainter(color, opacity);
      case 4: return _WavePainter(color, opacity);
      case 5: return _FlamePainter(color, opacity);
      case 6: return _SnowPainter(color, opacity, particleCount);
      default: return _RadialPainter(color, opacity);
    }
  }

  /// 圆环边框风格（用于徽章圆形 border）
  static Border? ringBorder(int style, Color color, double width) {
    switch (style) {
      case 0: return Border.all(color: color.withValues(alpha: 0.3), width: width);       // 实线
      case 1: return Border.all(color: color.withValues(alpha: 0.3), width: width);       // 虚线：使用 painter
      case 2: return Border.all(color: color.withValues(alpha: 0.3), width: width + 1);   // 双圈：使用 painter
      case 3: return Border.all(color: color.withValues(alpha: 0.3), width: width);       // 点阵：使用 painter
      case 4: return Border.all(color: color.withValues(alpha: 0.3), width: width);       // 锯齿：使用 painter
      case 5: return Border.all(color: color.withValues(alpha: 0.3), width: width);       // 花边：使用 painter
      case 6: return Border.all(color: color.withValues(alpha: 0.3), width: width);       // 编织：使用 painter
      default: return Border.all(color: color.withValues(alpha: 0.3), width: width);
    }
  }
}

// ====== 断签回归梯度辅助 ======
class _ReturnLevel {
  final int min;
  final int max;
  final String message;
  const _ReturnLevel(this.min, this.max, this.message);
}

// ═══════════════════════════════════════════
//  背景图案画家（7种）
// ═══════════════════════════════════════════

/// ① 放射光芒
class _RadialPainter extends CustomPainter {
  final Color color; final double opacity;
  _RadialPainter(this.color, this.opacity);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: opacity * 0.5)..strokeWidth = 0.5;
    final cx = size.width / 2, cy = size.height / 2, r = size.shortestSide / 2;
    for (int i = 0; i < 24; i++) {
      final angle = (i / 24) * 2 * pi;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + cos(angle) * r, cy + sin(angle) * r),
        paint..strokeWidth = 0.5 + (i % 3) * 0.5,
      );
    }
  }
  @override bool shouldRepaint(covariant CustomPainter old) => false;
}

/// ② 同心波纹
class _RingPainter extends CustomPainter {
  final Color color; final double opacity; final int rings;
  _RingPainter(this.color, this.opacity, this.rings);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.stroke..color = color.withValues(alpha: opacity * 0.4);
    final cx = size.width / 2, cy = size.height / 2, maxR = size.shortestSide / 2;
    for (int i = 0; i < 5; i++) {
      final r = maxR * (i + 1) / 5;
      canvas.drawCircle(Offset(cx, cy), r, paint..strokeWidth = 1.0 - i * 0.15);
    }
  }
  @override bool shouldRepaint(covariant CustomPainter old) => false;
}

/// ③ 星点散落
class _StarPainter extends CustomPainter {
  final Color color; final double opacity; final int count;
  _StarPainter(this.color, this.opacity, this.count);
  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42);
    for (int i = 0; i < count + 3; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final s = 1.0 + rng.nextDouble() * 2.5;
      final paint = Paint()..color = color.withValues(alpha: opacity * (0.3 + rng.nextDouble() * 0.7));
      canvas.drawCircle(Offset(x, y), s, paint);
    }
  }
  @override bool shouldRepaint(covariant CustomPainter old) => false;
}

/// ④ 藤蔓生长
class _VinePainter extends CustomPainter {
  final Color color; final double opacity;
  _VinePainter(this.color, this.opacity);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity * 0.3)
      ..style = PaintingStyle.stroke..strokeWidth = 0.8;
    final path = Path();
    path.moveTo(0, size.height);
    for (double x = 0; x <= size.width; x += 2) {
      final y = size.height - sin(x / 20) * 20 - cos(x / 35) * 15;
      path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }
  @override bool shouldRepaint(covariant CustomPainter old) => false;
}

/// ⑤ 水波荡漾
class _WavePainter extends CustomPainter {
  final Color color; final double opacity;
  _WavePainter(this.color, this.opacity);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity * 0.25)
      ..style = PaintingStyle.stroke..strokeWidth = 0.8;
    for (int wave = 0; wave < 3; wave++) {
      final path = Path();
      final amp = 12.0 + wave * 6;
      final freq = 0.03 - wave * 0.005;
      final phase = wave * 1.5;
      final y0 = size.height * (0.2 + wave * 0.3);
      path.moveTo(0, y0 + sin(phase) * amp);
      for (double x = 0; x <= size.width; x += 3) {
        path.lineTo(x, y0 + sin(x * freq + phase) * amp);
      }
      canvas.drawPath(path, paint..strokeWidth = 0.8 - wave * 0.2);
    }
  }
  @override bool shouldRepaint(covariant CustomPainter old) => false;
}

/// ⑥ 火焰跳动
class _FlamePainter extends CustomPainter {
  final Color color; final double opacity;
  _FlamePainter(this.color, this.opacity);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity * 0.2)
      ..style = PaintingStyle.fill;
    final cx = size.width / 2, cy = size.height * 0.55;
    final path = Path();
    path.moveTo(cx, cy - 30);
    path.quadraticBezierTo(cx - 30, cy, cx - 20, cy + 20);
    path.quadraticBezierTo(cx - 10, cy - 5, cx, cy + 25);
    path.quadraticBezierTo(cx + 10, cy - 5, cx + 20, cy + 20);
    path.quadraticBezierTo(cx + 30, cy, cx, cy - 30);
    canvas.drawPath(path, paint);
  }
  @override bool shouldRepaint(covariant CustomPainter old) => false;
}

/// ⑦ 雪花结晶
class _SnowPainter extends CustomPainter {
  final Color color; final double opacity; final int count;
  _SnowPainter(this.color, this.opacity, this.count);
  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(99);
    const arms = 6;
    for (int c = 0; c < count; c++) {
      final cx = rng.nextDouble() * size.width;
      final cy = rng.nextDouble() * size.height;
      final len = 4.0 + rng.nextDouble() * 8;
      final paint = Paint()
        ..color = color.withValues(alpha: opacity * (0.2 + rng.nextDouble() * 0.5))
        ..strokeWidth = 0.8;
      for (int i = 0; i < arms; i++) {
        final angle = (i / arms) * 2 * pi;
        canvas.drawLine(Offset(cx, cy), Offset(cx + cos(angle) * len, cy + sin(angle) * len), paint);
      }
    }
  }
  @override bool shouldRepaint(covariant CustomPainter old) => false;
}
