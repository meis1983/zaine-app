import 'package:flutter/material.dart';
import '../theme/theme_helper.dart';
import '../l10n/i18n.dart';

/// 签到热力图组件
///
/// 展示用户过去的签到情况，类似 GitHub 贡献图
/// 每个方块代表一天，颜色深浅表示当天的签到状态
/// 🔴【v1.97.3 修复 Bug 5】
/// - 多级颜色（4 级渐变）替代单调两态色
/// - 时间范围切换（7天 / 30天 / 90天 / 365天）
/// - 点击格子显示日期 + 签到状态 Tooltip
/// - 连续签到格子高亮边框
class CheckinHeatmap extends StatefulWidget {
  /// 签到记录列表，包含签到的日期
  final List<DateTime> checkinDates;

  /// 热力图颜色主题
  final Color baseColor;

  /// 是否显示月份标签
  final bool showMonthLabels;

  /// 是否显示星期标签
  final bool showWeekdayLabels;

  /// 方块大小
  final double cellSize;

  /// 方块间距
  final double cellSpacing;

  CheckinHeatmap({
    super.key,
    required this.checkinDates,
    this.baseColor = const Color(0xFF4CAF50),
    this.showMonthLabels = true,
    this.showWeekdayLabels = true,
    this.cellSize = 12,
    this.cellSpacing = 3,
  });

  @override
  State<CheckinHeatmap> createState() => _CheckinHeatmapState();
}

class _CheckinHeatmapState extends State<CheckinHeatmap> {
  /// 0 = 7天（默认）, 1 = 30天, 2 = 90天, 3 = 365天
  /// 🔴【v1.97.3 (162) 修复】默认由 1年 改为 7天（用户反馈默认一年太长）
  int _selectedRange = 0;

  static final _rangeOptions = [
    {'label': tr.z0883, 'days': 7},
    {'label': tr.z0884, 'days': 30},
    {'label': tr.z0885, 'days': 90},
    {'label': tr.z0886, 'days': 365},
  ];

  int get _rangeDays => _rangeOptions[_selectedRange]['days'] as int;

  /// 预计算日期→签到映射，避免每次遍历
  late Set<String> _checkinSet;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rebuildCheckinSet();
  }

  void _rebuildCheckinSet() {
    _checkinSet = widget.checkinDates
        .map((d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}')
        .toSet();
  }

  bool _isCheckedIn(DateTime date) {
    final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return _checkinSet.contains(key);
  }

  /// 计算某日所在连续签到段的长度（前后延伸）
  int _streakLength(DateTime date) {
    if (!_isCheckedIn(date)) return 0;
    int count = 1;
    // 往前数
    DateTime prev = date.subtract(Duration(days: 1));
    while (_isCheckedIn(prev) && count < 365) {
      count++;
      prev = prev.subtract(Duration(days: 1));
    }
    // 往后数
    DateTime next = date.add(Duration(days: 1));
    while (_isCheckedIn(next) && count < 365) {
      count++;
      next = next.add(Duration(days: 1));
    }
    return count;
  }

  /// 根据连续签到长度返回颜色级别 (0-3)
  /// 1天 = 浅色, 2-3天 = 中浅, 4-6天 = 中深, 7+天 = 深色
  int _colorLevel(int streakLen) {
    if (streakLen <= 0) return 0;
    if (streakLen <= 1) return 1;
    if (streakLen <= 3) return 2;
    if (streakLen <= 6) return 3;
    return 4; // 7天+，最高级
  }

  Color _levelColor(int level) {
    switch (level) {
      case 0:
        return Colors.grey.shade200;
      case 1:
        return widget.baseColor.withValues(alpha: 0.55);
      case 2:
        return widget.baseColor.withValues(alpha: 0.7);
      case 3:
        return widget.baseColor.withValues(alpha: 0.85);
      case 4:
        return widget.baseColor; // 满色
      default:
        return Colors.grey.shade200;
    }
  }

  @override
  Widget build(BuildContext context) {
    _rebuildCheckinSet();

    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: _rangeDays));
    final stats = _calculateStats(startDate, now);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: EdgeInsets.all(ZaiNeSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(stats),
            SizedBox(height: ZaiNeSpacing.lg),
            if (stats['totalCheckins'] == 0) _buildEmptyState() else _buildHeatmapGrid(startDate, now),
            SizedBox(height: ZaiNeSpacing.md),
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> stats) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr.z0887,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: ZaiNeSpacing.xxs),
              Text(
                tr.z0888(stats['totalCheckins'], stats['currentStreak'], stats['maxStreak']),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
        // 时间范围切换
        _buildRangeSelector(),
      ],
    );
  }

  Widget _buildRangeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_rangeOptions.length, (index) {
          final isSelected = _selectedRange == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedRange = index),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? widget.baseColor : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _rangeOptions[index]['label'] as String,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.grey.shade500,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHeatmapGrid(DateTime startDate, DateTime endDate) {
    final totalDays = endDate.difference(startDate).inDays;
    final totalWeeks = (totalDays / 7).ceil();

    // 找到起始日期所在周的第一天（周日）
    final firstSunday = startDate.subtract(
      Duration(days: startDate.weekday % 7),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true, // 最新的在右边
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showWeekdayLabels) _buildWeekdayLabels(),
          SizedBox(width: ZaiNeSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.showMonthLabels) _buildMonthLabels(firstSunday, totalWeeks),
              SizedBox(height: ZaiNeSpacing.xxs),
              Row(
                children: List.generate(totalWeeks, (weekIndex) {
                  return _buildWeekColumn(firstSunday, weekIndex, endDate);
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayLabels() {
    final weekdays = [tr.s172, tr.s166, tr.s167, tr.s168, tr.s169, tr.s170, tr.s171];
    final visibleIndices = [1, 3, 5]; // 一、三、五

    return Column(
      children: List.generate(7, (index) {
        if (!visibleIndices.contains(index)) {
          return SizedBox(height: widget.cellSize + widget.cellSpacing);
        }
        return Container(
          height: widget.cellSize,
          margin: EdgeInsets.only(bottom: widget.cellSpacing),
          alignment: Alignment.centerRight,
          child: Text(
            weekdays[index],
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade400,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildMonthLabels(DateTime firstSunday, int totalWeeks) {
    final months = <Widget>[];
    DateTime current = firstSunday;
    int? lastMonth;

    for (int week = 0; week < totalWeeks; week++) {
      final middleOfWeek = current.add(Duration(days: 3));

      if (middleOfWeek.month != lastMonth) {
        lastMonth = middleOfWeek.month;
        months.add(
          Container(
            width: (widget.cellSize + widget.cellSpacing) * 7,
            alignment: Alignment.centerLeft,
            child: Text(
              tr.z0889(middleOfWeek.month),
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey.shade500,
              ),
            ),
          ),
        );
      } else {
        months.add(
          SizedBox(width: (widget.cellSize + widget.cellSpacing) * 7),
        );
      }

      current = current.add(Duration(days: 7));
    }

    return Row(children: months);
  }

  Widget _buildWeekColumn(DateTime firstSunday, int weekIndex, DateTime endDate) {
    final weekStart = firstSunday.add(Duration(days: weekIndex * 7));

    return Column(
      children: List.generate(7, (dayIndex) {
        final date = weekStart.add(Duration(days: dayIndex));
        final isCheckedIn = _isCheckedIn(date);
        final isInRange = date.isAfter(
          endDate.subtract(Duration(days: _rangeDays)),
        ) && date.isBefore(endDate.add(Duration(days: 1)));

        final streakLen = isCheckedIn ? _streakLength(date) : 0;
        final level = _colorLevel(streakLen);

        // 连续签到 ≥3 天的格子加微妙边框
        final showBorder = isCheckedIn && streakLen >= 3;

        final dateStr = '${date.month}/${date.day}';
        final weekdayNames = [tr.s172, tr.s166, tr.s167, tr.s168, tr.s169, tr.s170, tr.s171];
        final tooltipMsg = isCheckedIn
            ? tr.z0890(dateStr, weekdayNames[date.weekday % 7])
            : (isInRange ? tr.z0891(dateStr, weekdayNames[date.weekday % 7]) : '');

        return Tooltip(
          message: tooltipMsg,
          preferBelow: false,
          child: Container(
            width: widget.cellSize,
            height: widget.cellSize,
            margin: EdgeInsets.only(
              right: widget.cellSpacing,
              bottom: widget.cellSpacing,
            ),
            decoration: BoxDecoration(
              color: _levelColor(level),
              borderRadius: BorderRadius.circular(ZaiNeRadius.tiny),
              border: showBorder
                  ? Border.all(
                      color: widget.baseColor.withValues(alpha: 0.5),
                      width: 0.5,
                    )
                  : null,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          tr.s173,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade400,
          ),
        ),
        SizedBox(width: ZaiNeSpacing.xxs),
        ...List.generate(5, (index) {
          return Container(
            width: 12,
            height: 12,
            margin: EdgeInsets.only(right: 3),
            decoration: BoxDecoration(
              color: _levelColor(index),
              borderRadius: BorderRadius.circular(ZaiNeRadius.tiny),
            ),
          );
        }),
        SizedBox(width: ZaiNeSpacing.xxs),
        Text(
          tr.z0892,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade400,
          ),
        ),
      ],
    );
  }

  /// 选中时间范围内没有任何签到时的空态提示（修复「整片空白」无反馈问题）
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_month_outlined, size: 42, color: Colors.grey.shade300),
          SizedBox(height: 10),
          Text(
            tr.z0893(_rangeDays),
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
          SizedBox(height: 4),
          Text(
            tr.z0894,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade300),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _calculateStats(DateTime startDate, DateTime endDate) {
    // 统计范围内的总签到天数
    final totalCheckins = widget.checkinDates.where((date) {
      return date.isAfter(startDate) && date.isBefore(endDate);
    }).length;

    // 计算当前连续签到
    int currentStreak = 0;
    final today = DateTime(endDate.year, endDate.month, endDate.day);
    for (int i = 0; i < _rangeDays; i++) {
      final checkDate = today.subtract(Duration(days: i));
      if (_isCheckedIn(checkDate)) {
        currentStreak++;
      } else if (i > 0) {
        break;
      }
    }

    // 计算最长连续签到
    int maxStreak = 0;
    int tempStreak = 0;
    final sortedDates = widget.checkinDates.toList()..sort();
    DateTime? prevDate;

    for (final date in sortedDates) {
      final normalized = DateTime(date.year, date.month, date.day);

      if (prevDate != null) {
        final diff = normalized.difference(prevDate).inDays;
        if (diff == 1) {
          tempStreak++;
        } else if (diff > 1) {
          maxStreak = tempStreak > maxStreak ? tempStreak : maxStreak;
          tempStreak = 1;
        }
      } else {
        tempStreak = 1;
      }
      prevDate = normalized;
    }
    maxStreak = tempStreak > maxStreak ? tempStreak : maxStreak;

    return {
      'totalCheckins': totalCheckins,
      'currentStreak': currentStreak,
      'maxStreak': maxStreak,
    };
  }
}

/// 简化的签到统计卡片
class CheckinStatsCard extends StatelessWidget {
  final int totalDays;
  final int currentStreak;
  final int maxStreak;
  final int weeklyDays;
  final Color accentColor;

  CheckinStatsCard({
    super.key,
    required this.totalDays,
    required this.currentStreak,
    required this.maxStreak,
    required this.weeklyDays,
    this.accentColor = const Color(0xFF4CAF50),
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: EdgeInsets.all(ZaiNeSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr.z0895,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: ZaiNeSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _buildStatCircle(
                    tr.s413,
                    totalDays,
                    tr.z0004,
                    accentColor,
                  ),
                ),
                Expanded(
                  child: _buildStatCircle(
                    tr.z0896,
                    currentStreak,
                    tr.z0004,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildStatCircle(
                    tr.z0897,
                    weeklyDays,
                    tr.z0004,
                    Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCircle(String label, int value, String unit, Color color) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.1),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 10,
                    color: color.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: ZaiNeSpacing.sm),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
