// lib/utils/streak_util.dart
// 连续签到天数计算（单一真相源）
// 【v1.95.0 彻底同步】首页 / 守护圈 / 同步服务统一从此函数计算，
// 一律从签到历史日期列表整体重算，避免依赖易错的内存增量状态导致"天数变 0"。

class StreakUtil {
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
}
