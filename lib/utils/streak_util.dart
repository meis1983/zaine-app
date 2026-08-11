// lib/utils/streak_util.dart
// 连续签到天数计算（单一真相源）
// 【v1.95.0 彻底同步】首页 / 守护圈 / 同步服务统一从此函数计算，
// 一律从签到历史日期列表整体重算，避免依赖易错的内存增量状态导致"天数变 0"。
//
// 🔴【v1.97.2 根治 · 读取侧也收敛】
// 历史根因：连续天数在 App 内有 6 处独立读取点，各自 `prefs.getInt(continuous_days_$uid)`
// 直接读缓存。而缓存会被后端 `signin_streak` 字段污染（后端是独立累加计数器，
// 与它自己的 checkin_history 表自相矛盾，会漂移偏高）。
// 结果：首屏读到污染值 → 渲染错误天数 → 网络重算后再跳变为正确值（用户可见「先 6 后 3」）。
//
// 根治策略：**读取侧统一走 readStreak()，永远以本地签到历史重算，缓存仅作历史为空时的兜底。**
// 本地历史是同步可读的（SharedPreferences 内存镜像），零网络延迟，首帧即正确，从源头消除跳变。

import 'package:shared_preferences/shared_preferences.dart';

class StreakUtil {
  /// 签到历史 key（用户隔离）
  static String historyKeyOf(String uid) =>
      uid.isNotEmpty ? 'checkin_history_$uid' : 'checkin_history';

  /// 连续天数缓存 key（用户隔离）
  static String streakKeyOf(String uid) =>
      uid.isNotEmpty ? 'continuous_days_$uid' : 'continuous_days';

  /// 从签到历史（日期字符串列表，支持 yyyy-MM-dd 或 ISO 格式）重算连续天数。
  /// 规则：从今天（或昨天，允许今天尚未签到）往前连续命中即计数，遇到断签即终止。
  static int calculateStreak(List<String> history) {
    if (history.isEmpty) return 0;

    final dates = history
        .map((s) => DateTime.tryParse(s))
        .where((d) => d != null)
        .map((d) => DateTime(d!.year, d.month, d.day))
        .toSet() // 去重
        .toList();

    if (dates.isEmpty) return 0;

    // 降序排序（最新在前）
    dates.sort((a, b) => b.compareTo(a));

    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    int streak = 0;

    // 从今天或昨天开始往前检查
    for (int i = 0; i < 365; i++) {
      final checkDate = today.subtract(Duration(days: i));
      if (dates.any((d) => d == checkDate)) {
        streak++;
      } else if (i > 0) {
        // 中间有断签（i=0 是今天，允许今天还没签到）
        break;
      }
    }

    return streak;
  }

  /// 🔴【v1.97.2 根治 · 全 App 唯一读取入口】
  /// 读取连续签到天数：**永远以本地签到历史重算为准**。
  ///
  /// streak 是衍生值不是存储值——从签到日期列表实时算出连续天数。
  /// 不读 `continuous_days_$uid` 缓存：该缓存曾长期被后端漂移的
  /// `signin_streak` 污染（偏高），导致首屏先显示错误值再跳变。
  ///
  /// 历史为空时返回 0（不回退缓存）——新用户 / 尚未同步 = 确实是 0 天，
  /// 由调用方决定是否在数据未就绪时显示 loading 而非 0。
  ///
  /// 同步方法（不含 await），可安全用于 `setState` 内部与首帧渲染。
  static int readStreak(SharedPreferences prefs, String uid) {
    final history = prefs.getStringList(historyKeyOf(uid)) ?? const <String>[];
    if (history.isEmpty) return 0;
    return calculateStreak(history);
  }

  /// 重算并把结果写回缓存，返回重算值。
  ///
  /// 用于「历史刚被 MERGE 更新」之后（如服务器同步完成、签到成功写入今日）
  /// 让缓存与真相源对齐，供尚未迁移到 readStreak 的旧调用点 / 手表回包读取。
  ///
  /// 注意：**无条件写入**（含降低值）。历史上 `if (new > cached)` 的
  /// 「只升不降」保护会让偏高的污染值永远无法被修正，是本 bug 长期存在的关键成因。
  /// 历史为空时返回 0（不回退缓存），与 readStreak 一致。
  static Future<int> recalcAndPersist(SharedPreferences prefs, String uid) async {
    final history = prefs.getStringList(historyKeyOf(uid)) ?? const <String>[];
    if (history.isEmpty) return 0;
    final streak = calculateStreak(history);
    await prefs.setInt(streakKeyOf(uid), streak);
    return streak;
  }

  /// 把某一天并入本地签到历史（幂等去重），返回并入后的完整历史。
  /// 供签到成功后立即更新真相源使用（手机端 / 手表端统一走这里）。
  static Future<List<String>> appendDate(
    SharedPreferences prefs,
    String uid,
    String yyyyMmDd,
  ) async {
    final key = historyKeyOf(uid);
    final set = (prefs.getStringList(key) ?? const <String>[]).toSet();
    set.add(yyyyMmDd);
    final list = set.toList();
    await prefs.setStringList(key, list);
    return list;
  }
}
