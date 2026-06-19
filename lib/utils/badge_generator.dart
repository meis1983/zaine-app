import 'dart:math';
import 'package:flutter/material.dart';

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
    if (days >= 1825) return const LevelInfo('🌟👑🌟', '终身守护王', Color(0xFFFFD700), '5年+，守护已成为习惯');
    if (days >= 1400) return const LevelInfo('🏆🏆🏆', '千四传奇',   Color(0xFFE91E63), '近4年，传奇永不落幕');
    if (days >= 1100) return const LevelInfo('👑👑👑', '三冠王者',   Color(0xFF9C27B0), '3年+，王者风范');
    if (days >= 900)  return const LevelInfo('🏆🏆', '双冠传奇',   Color(0xFF673AB7), '近3年，传奇继续');
    if (days >= 730)  return const LevelInfo('💎💎💎', '守护之钻',   Color(0xFF7C4DFF), '2年+，你是最可靠的守护者');
    if (days >= 650)  return const LevelInfo('👑👑', '双冠王者',   Color(0xFF3F51B5), '近2年，荣耀加倍');
    if (days >= 550)  return const LevelInfo('💎💎', '双钻守护',   Color(0xFF2196F3), '近2年，钻石闪耀');
    if (days >= 450)  return const LevelInfo('🏆', '年度冠军',   Color(0xFF03A9F4), '近1.5年，冠军之心');
    if (days >= 365)  return const LevelInfo('🔥🔥', '年度烈焰',   Color(0xFFFF6B35), '1年+，你的坚持令人敬佩');
    if (days >= 300)  return const LevelInfo('👑', '三百王者',   Color(0xFFFF9800), '近1年，王者之路');
    if (days >= 250)  return const LevelInfo('🥇', '黄金守护',   Color(0xFFFFC107), '250天+，黄金品质');
    if (days >= 200)  return const LevelInfo('💎', '守护宝石',   Color(0xFF7C4DFF), '200天+，宝石璀璨');
    if (days >= 180)  return const LevelInfo('🥈', '白银守护',   Color(0xFF90A4AE), '半年+，银光闪闪');
    if (days >= 160)  return const LevelInfo('🥉', '青铜守护',   Color(0xFFCD7F32), '近半年，青铜坚韧');
    if (days >= 140)  return const LevelInfo('🏅', '铜质奖章',   Color(0xFFFFA726), '140天+，奖章荣耀');
    if (days >= 120)  return const LevelInfo('🎖️', '守护勋章',   Color(0xFFEF5350), '120天+，勋章加身');
    if (days >= 100)  return const LevelInfo('⭐', '百日守护',   Color(0xFF9C27B0), '100天+，习惯已经养成');
    if (days >= 95)   return const LevelInfo('🎨', '艺术大师',   Color(0xFFEC407A), '95天+，大师风范');
    if (days >= 90)   return const LevelInfo('💫', '季度闪耀',   Color(0xFFAB47BC), '一个季度，闪耀光芒');
    if (days >= 85)   return const LevelInfo('🎭', '舞台主角',   Color(0xFF7E57C2), '85天+，主角光环');
    if (days >= 80)   return const LevelInfo('🎪', '马戏明星',   Color(0xFF5C6BC0), '80天+，明星风采');
    if (days >= 75)   return const LevelInfo('🏕️', '露营达人',   Color(0xFF42A5F5), '75天+，达人之路');
    if (days >= 70)   return const LevelInfo('🏔️', '雪山巍峨',   Color(0xFF29B6F6), '70天+，巍峨如山');
    if (days >= 65)   return const LevelInfo('🌋', '火山喷发',   Color(0xFFFF7043), '65天+，热情如火');
    if (days >= 60)   return const LevelInfo('🔥', '双月烈焰',   Color(0xFFFF5722), '两个月，烈焰燃烧');
    if (days >= 55)   return const LevelInfo('🌊', '海浪奔腾',   Color(0xFF26C6DA), '55天+，奔腾不息');
    if (days >= 50)   return const LevelInfo('⚡', '五十雷霆',   Color(0xFFFFCA28), '50天+，雷霆万钧');
    if (days >= 45)   return const LevelInfo('☁️', '云端漫步',   Color(0xFF81D4FA), '45天+，漫步云端');
    if (days >= 40)   return const LevelInfo('🌈', '彩虹初现',   Color(0xFFFF7043), '40天+，彩虹绚烂');
    if (days >= 35)   return const LevelInfo('🌙', '月半守护',   Color(0xFF9FA8DA), '35天+，月半圆满');
    if (days >= 30)   return const LevelInfo('🌟', '月度之星',   Color(0xFF3F51B5), '一个月，你是真正的守护者');
    if (days >= 28)   return const LevelInfo('🌰', '果实累累',   Color(0xFF8D6E63), '28天+，硕果累累');
    if (days >= 26)   return const LevelInfo('🍂', '秋叶静美',   Color(0xFFA1887F), '26天+，静美如斯');
    if (days >= 24)   return const LevelInfo('🍁', '枫叶飘红',   Color(0xFFEF5350), '24天+，枫叶正红');
    if (days >= 22)   return const LevelInfo('🌳', '绿树成荫',   Color(0xFF66BB6A), '22天+，绿树成荫');
    if (days >= 20)   return const LevelInfo('🌲', '青松挺拔',   Color(0xFF43A047), '20天+，青松挺拔');
    if (days >= 18)   return const LevelInfo('🌵', '仙人掌',     Color(0xFF9CCC65), '18天+，坚韧不拔');
    if (days >= 16)   return const LevelInfo('🌴', '棕榈挺立',   Color(0xFF7CB342), '16天+，挺立如松');
    if (days >= 14)   return const LevelInfo('🌺', '两周绽放',   Color(0xFFFF4081), '两周，绽放光彩');
    if (days >= 12)   return const LevelInfo('🌹', '玫瑰初绽',   Color(0xFFE91E63), '12天+，玫瑰初绽');
    if (days >= 10)   return const LevelInfo('🌻', '向阳而生',   Color(0xFFFF9800), '10天+，向阳而生');
    if (days >= 9)    return const LevelInfo('🌼', '雏菊绽放',   Color(0xFFFFB74D), '9天+，雏菊绽放');
    if (days >= 8)    return const LevelInfo('🌸', '樱花初开',   Color(0xFFF48FB1), '8天+，樱花初开');
    if (days >= 7)    return const LevelInfo('✨', '闪亮新星',   Color(0xFF2196F3), '一周，好的开始是成功的一半');
    if (days >= 6)    return const LevelInfo('🌺', '初露锋芒',   Color(0xFF26A69A), '6天+，锋芒初露');
    if (days >= 5)    return const LevelInfo('🌷', '含苞待放',   Color(0xFFEC407A), '5天+，含苞待放');
    if (days >= 4)    return const LevelInfo('🌾', '幼苗成长',   Color(0xFF8BC34A), '4天+，幼苗成长');
    if (days >= 3)    return const LevelInfo('🍀', '三叶草',     Color(0xFF4CAF50), '3天，幸运三连');
    if (days >= 2)    return const LevelInfo('🌿', '嫩芽初绽',   Color(0xFF66BB6A), '2天，嫩芽初绽');
    return const LevelInfo('🌱', '守护种子', Color(0xFF4CAF50), '每一个伟大都始于第一步');
  }

  // ───────── 30条日常轮换文案 ─────────
  static const List<String> _dailyMessages = [
    '每一个伟大都始于第一步',
    '坚持，比完美更重要',
    '守护自己，是你给世界最好的礼物',
    '今天的你，比昨天更强大',
    '独居不独心，有人在默默关注你',
    '你比自己想象的更坚强',
    '每一天，都是新的开始',
    '别怕慢，怕的是停下脚步',
    '你值得被好好对待',
    '照顾好自己，世界才会更好',
    '你的坚持，正在改变一切',
    '别小看今天的自己',
    '平安，就是最好的消息',
    '对自己温柔一点，你也很辛苦',
    '签到只是一秒钟，安心却是一整天',
    '你的存在本身就很重要',
    '先照顾好自己，再照顾世界',
    '今天也是被在乎的一天',
    '你认真生活的样子，真好看',
    '小小的习惯，大大的力量',
    '今天，也请为自己骄傲',
    '世上最温暖的词，叫「我在」',
    '你从来不是一个人',
    '每一个今天，都是未来的基石',
    '对自己说一句：今天辛苦了',
    '把今天过好，就是最好的明天',
    '你值得拥有平安和幸福',
    '今天也要记得微笑',
    '守护自己，就是守护爱着你的人',
    '关关难过关关过，你真的很棒',
  ];

  // ───────── 7级断签回归文案 ─────────
  static final List<_ReturnLevel> _returnLevels = [
    const _ReturnLevel(0, 1,     '昨天偷了个懒？没关系，今天继续就好。'),
    const _ReturnLevel(2, 3,     '几天不见，你还好吗？回来就好，我们继续。'),
    const _ReturnLevel(4, 7,     '一周没见。最近在忙什么？记得有人在等你。'),
    const _ReturnLevel(8, 14,    '快半个月没见了。欢迎回来，这里有人在想你。'),
    const _ReturnLevel(15, 30,   '好久不见。这一个月过得怎么样？不论如何，欢迎回家。'),
    const _ReturnLevel(31, 90,   '你终于回来了！这段时间去了哪里？我们都很想你。'),
    const _ReturnLevel(91, 99999, '好久好久不见。感谢你还记得这里。无论离开多久，家永远为你敞开。'),
  ];

  static String _getReturnMessage(int absentDays) {
    for (final lvl in _returnLevels) {
      if (absentDays >= lvl.min && absentDays <= lvl.max) return lvl.message;
    }
    return _returnLevels.last.message;
  }

  // ───────── 里程碑（10个）─────────
  static final Map<int, _MilestoneInfo> _milestones = {
    7:   const _MilestoneInfo('一周啦', '一周啦！新习惯正在养成，你比自己想象的更棒。', '🌈', Color(0xFFE91E63)),
    10:  const _MilestoneInfo('两位数', '两位数打卡达成！继续向前。', '⭐', Color(0xFFFFD700)),
    20:  const _MilestoneInfo('20天', '20天的坚持，你已经在悄悄变强。', '🌸', Color(0xFFFF69B4)),
    30:  const _MilestoneInfo('月度之星', '🎉 一个月！恭喜你成为「月度之星」，守护已融入日常。', '🌟', Color(0xFF3F51B5)),
    45:  const _MilestoneInfo('一个半月', '一个半月。你用实际行动证明，坚持并不难。', '🌙', Color(0xFF9C27B0)),
    60:  const _MilestoneInfo('两个月', '🔥 两个月！你的守护之火正在燃烧。', '🔥', Color(0xFFFF4500)),
    90:  const _MilestoneInfo('一个季度', '一个季度。你渡过了春夏秋冬的一个切面，了不起。', '🌿', Color(0xFF4CAF50)),
    100: const _MilestoneInfo('百日守护', '⭐ 百日守护！你是自己的英雄。今天值得好好庆祝。', '⭐', Color(0xFF9C27B0)),
    180: const _MilestoneInfo('半年', '半年了。这180天的坚守，是你给自己最好的礼物。', '💎', Color(0xFF7C4DFF)),
    365: const _MilestoneInfo('一周年', '👑 一年！你做到了。守护已经成为你的本能。', '👑', Color(0xFFFFD700)),
  };

  static _MilestoneInfo? _matchMilestone(int days) {
    if (_milestones.containsKey(days)) return _milestones[days];
    // 每旬 30/60/90/120/150...
    if (days % 30 == 0 && days >= 30) {
      return _MilestoneInfo('$days天里程碑', '第 $days 天！你的每一步坚持都在创造奇迹。', '🎯', const Color(0xFF2196F3));
    }
    return null;
  }

  // ───────── 法定节假日（7个）─────────
  static final List<_SpecialDate> _festivals = [
    const _SpecialDate('元旦', '新年第一天，从这个签到开始。今年，也要好好守护自己。', '🎉', 1, 1, Color(0xFFE91E63)),
    const _SpecialDate('春节', '新年快乐！无论在哪过年，记得有人一直在牵挂你。', '🧧', 2, 17, Color(0xFFFF4500)),
    const _SpecialDate('清明', '慎终追远，珍惜当下。好好活着，就是最好的告慰。', '🌿', 4, 5, Color(0xFF4CAF50)),
    const _SpecialDate('劳动节', '致敬每一个认真生活的你。今天，让自己歇一歇。', '🏋️', 5, 1, Color(0xFFFF9800)),
    const _SpecialDate('端午', '端午安康。系一根彩绳，也系住对自己的那份关心。', '🎋', 6, 19, Color(0xFF795548)),
    const _SpecialDate('中秋', '海上生明月，天涯共此时。你并不孤单。', '🌕', 9, 25, Color(0xFFFFD700)),
    const _SpecialDate('国庆', '普天同庆，山河远阔。别忘了，对自己好一点。', '🇨🇳', 10, 1, Color(0xFFF44336)),
  ];

  // ───────── 传统节日（5个）─────────
  static final List<_SpecialDate> _tradFestivals = [
    const _SpecialDate('元宵', '花灯如昼，月圆人圆。愿你每一天都温暖明亮。', '🏮', 3, 3, Color(0xFFFF69B4)),
    const _SpecialDate('龙抬头', '二月二，龙抬头。春天来了，你的好运也开始抬头。', '🐉', 3, 20, Color(0xFF4CAF50)),
    const _SpecialDate('七夕', '今夜星河璀璨。先爱自己，再爱他人。', '💖', 8, 19, Color(0xFFE91E63)),
    const _SpecialDate('重阳', '登高望远，天高云淡。人生不怕晚，就怕不上山。', '🏔️', 10, 18, Color(0xFFFF9800)),
    const _SpecialDate('除夕', '岁末的最后一次签到。这一年，你辛苦了。', '🎊', 2, 16, Color(0xFFD32F2F)),
  ];

  // ───────── 二十四节气（24个）─────────
  // 8个「四立二分二至」大节点保留emoji，其余16个普通覆盖
  static final List<_SpecialDate> _solarTerms = [
    const _SpecialDate('小寒', '天寒地冻，照顾好自己就是最大的温暖。', '❄️', 1, 5, Color(0xFF90CAF9)),
    const _SpecialDate('大寒', '一年中最冷的时刻，也是最靠近春天的时刻。', '🧊', 1, 20, Color(0xFF64B5F6)),
    const _SpecialDate('立春', '春回大地。你心里的种子，要发芽了。', '🌱', 2, 4, Color(0xFF4CAF50)),
    const _SpecialDate('雨水', '好雨知时节。今天记得带伞，也要记得吃饭。', '💧', 2, 18, Color(0xFF42A5F5)),
    const _SpecialDate('惊蛰', '春雷乍响，万物复苏。你身体里的能量也该醒了。', '⚡', 3, 5, Color(0xFFFFCA28)),
    const _SpecialDate('春分', '昼夜等长，阴阳平衡。今天，和自己和解。', '☯️', 3, 20, Color(0xFF8BC34A)),
    const _SpecialDate('清明（节气）', '春和景明，万物生长。今天适合出去走走。', '🌿', 4, 4, Color(0xFF66BB6A)),
    const _SpecialDate('谷雨', '雨生百谷。播种希望，静待收获。', '🌾', 4, 20, Color(0xFF43A047)),
    const _SpecialDate('立夏', '夏天来了，热气腾腾地活着。', '☀️', 5, 5, Color(0xFFFF7043)),
    const _SpecialDate('小满', '小满胜万全。凡事不必太满，刚刚好就好。', '🌻', 5, 21, Color(0xFFFFCA28)),
    const _SpecialDate('芒种', '芒种忙种。所有付出，终将收获。', '🌾', 6, 5, Color(0xFF8D6E63)),
    const _SpecialDate('夏至', '一年中最长的白昼。今天，要多爱自己一点。', '☀️', 6, 21, Color(0xFFFF6D00)),
    const _SpecialDate('小暑', '暑气渐浓。心静自然凉。', '🌴', 7, 7, Color(0xFFFF8A65)),
    const _SpecialDate('大暑', '炎炎夏日，记得给自己一杯凉白开。', '🔥', 7, 23, Color(0xFFE64A19)),
    const _SpecialDate('立秋', '一叶知秋。有些事，该放就放。', '🍂', 8, 7, Color(0xFFFFAB40)),
    const _SpecialDate('处暑', '暑气消退，秋意渐浓。一切都在慢慢变好。', '🌤️', 8, 23, Color(0xFF90A4AE)),
    const _SpecialDate('白露', '白露为霜。天凉了，记得添衣。', '💧', 9, 7, Color(0xFF80DEEA)),
    const _SpecialDate('秋分', '平分秋色。生活有一半明媚，一半从容。', '🍁', 9, 23, Color(0xFFFF8F00)),
    const _SpecialDate('寒露', '露水渐寒。再忙，也别忘了签到。', '🍂', 10, 8, Color(0xFFA1887F)),
    const _SpecialDate('霜降', '霜降人间。秋天最后一个节气，要好好收尾。', '❄️', 10, 23, Color(0xFF78909C)),
    const _SpecialDate('立冬', '冬天来了。记得把温暖留一份给自己。', '🌨️', 11, 7, Color(0xFF90CAF9)),
    const _SpecialDate('小雪', '小雪飘落。愿你心里有光，不惧严寒。', '❄️', 11, 22, Color(0xFFB3E5FC)),
    const _SpecialDate('大雪', '大雪纷飞。在最冷的日子里，做自己的暖阳。', '☃️', 12, 7, Color(0xFFE0E0E0)),
    const _SpecialDate('冬至', '冬至大如年。今天记得吃饺子/汤圆，也要记得签到。', '🥟', 12, 22, Color(0xFF42A5F5)),
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
  static BadgeData generate(int days, {bool isReturnCheckin = false, DateTime? date}) {
    final now = date ?? DateTime.now();
    final m = now.month, d = now.day;

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
    // 🥇 法定节假日
    final festival = _findByDate(_festivals, m, d);
    if (festival != null) {
      return BadgeData(
        days: days, emoji: festival.emoji, title: festival.name,
        badgeColor: festival.color, message: festival.message,
        bgStyle: bgStyle, ringStyle: ringStyle, decoType: decoType,
        hueShift: hueShift.toDouble(), particleCount: particleCount,
        glowRadius: glowRadius, bgOpacity: bgOpacity, isFestival: true,
      );
    }

    // 🥈 传统节日
    final trad = _findByDate(_tradFestivals, m, d);
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
      return BadgeData(
        days: days, emoji: '🤗', title: '欢迎回来',
        badgeColor: const Color(0xFFFF9800), message: _getReturnMessage(days),
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
