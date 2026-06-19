import 'package:flutter/material.dart';

/// 签到热力图组件
///
/// 展示用户过去一年的签到情况，类似 GitHub 贡献图
/// 每个方块代表一天，颜色深浅表示当天的签到状态
class CheckinHeatmap extends StatelessWidget {
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

  const CheckinHeatmap({
    super.key,
    required this.checkinDates,
    this.baseColor = const Color(0xFF4CAF50),
    this.showMonthLabels = true,
    this.showWeekdayLabels = true,
    this.cellSize = 12,
    this.cellSpacing = 3,
  });

  @override
  Widget build(BuildContext context) {
    // 生成过去一年的日期网格
    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: 365));
    
    // 计算统计数据
    final stats = _calculateStats(startDate, now);
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题和统计
            _buildHeader(stats),
            const SizedBox(height: 16),
            // 热力图
            _buildHeatmapGrid(startDate, now),
            const SizedBox(height: 12),
            // 图例
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
              const Text(
                '签到热力图',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '过去一年的签到记录',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
        // 统计数据
        _buildStatItem('总签到', '${stats['totalCheckins']}', '天'),
        const SizedBox(width: 16),
        _buildStatItem('连续', '${stats['currentStreak']}', '天'),
        const SizedBox(width: 16),
        _buildStatItem('最长', '${stats['maxStreak']}', '天'),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade400,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: baseColor,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              unit,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeatmapGrid(DateTime startDate, DateTime endDate) {
    // 计算需要显示的总周数
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
          // 星期标签
          if (showWeekdayLabels) _buildWeekdayLabels(),
          const SizedBox(width: 8),
          // 月份标签 + 热力图网格
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showMonthLabels) _buildMonthLabels(firstSunday, totalWeeks),
              const SizedBox(height: 4),
              Row(
                children: List.generate(totalWeeks, (weekIndex) {
                  return _buildWeekColumn(firstSunday, weekIndex);
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayLabels() {
    final weekdays = ['日', '一', '二', '三', '四', '五', '六'];
    // 只显示部分星期标签，避免拥挤
    final visibleIndices = [1, 3, 5]; // 一、三、五
    
    return Column(
      children: List.generate(7, (index) {
        if (!visibleIndices.contains(index)) {
          return SizedBox(height: cellSize + cellSpacing);
        }
        return Container(
          height: cellSize,
          margin: EdgeInsets.only(bottom: cellSpacing),
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
      final middleOfWeek = current.add(const Duration(days: 3));
      
      if (middleOfWeek.month != lastMonth) {
        lastMonth = middleOfWeek.month;
        months.add(
          Container(
            width: (cellSize + cellSpacing) * 7,
            alignment: Alignment.centerLeft,
            child: Text(
              '${middleOfWeek.month}月',
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey.shade500,
              ),
            ),
          ),
        );
      } else {
        months.add(
          SizedBox(width: (cellSize + cellSpacing) * 7),
        );
      }
      
      current = current.add(const Duration(days: 7));
    }
    
    return Row(children: months);
  }

  Widget _buildWeekColumn(DateTime firstSunday, int weekIndex) {
    final weekStart = firstSunday.add(Duration(days: weekIndex * 7));
    
    return Column(
      children: List.generate(7, (dayIndex) {
        final date = weekStart.add(Duration(days: dayIndex));
        final isCheckedIn = _isDateCheckedIn(date);
        final isInRange = date.isAfter(
          DateTime.now().subtract(const Duration(days: 365)),
        ) && date.isBefore(DateTime.now().add(const Duration(days: 1)));
        
        return Container(
          width: cellSize,
          height: cellSize,
          margin: EdgeInsets.only(
            right: cellSpacing,
            bottom: cellSpacing,
          ),
          decoration: BoxDecoration(
            color: _getCellColor(isCheckedIn, isInRange),
            borderRadius: BorderRadius.circular(2),
          ),
          child: isCheckedIn
              ? Center(
                  child: Icon(
                    Icons.check,
                    size: cellSize * 0.6,
                    color: Colors.white,
                  ),
                )
              : null,
        );
      }),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '少',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade400,
          ),
        ),
        const SizedBox(width: 4),
        ...List.generate(4, (index) {
          return Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(
              color: baseColor.withValues(alpha: 0.2 + (index * 0.25)),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
        const SizedBox(width: 4),
        Text(
          '多',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade400,
          ),
        ),
      ],
    );
  }

  bool _isDateCheckedIn(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return checkinDates.any((checkinDate) {
      final normalized = DateTime(
        checkinDate.year,
        checkinDate.month,
        checkinDate.day,
      );
      return normalized.isAtSameMomentAs(normalizedDate);
    });
  }

  Color _getCellColor(bool isCheckedIn, bool isInRange) {
    if (!isInRange) {
      return Colors.grey.shade100;
    }
    if (!isCheckedIn) {
      return Colors.grey.shade200;
    }
    // 根据连续签到天数调整颜色深浅
    return baseColor.withValues(alpha: 0.8);
  }

  Map<String, dynamic> _calculateStats(DateTime startDate, DateTime endDate) {
    // 统计总签到天数
    final totalCheckins = checkinDates.where((date) {
      return date.isAfter(startDate) && date.isBefore(endDate);
    }).length;

    // 计算当前连续签到
    int currentStreak = 0;
    final today = DateTime(endDate.year, endDate.month, endDate.day);
    for (int i = 0; i < 365; i++) {
      final checkDate = today.subtract(Duration(days: i));
      if (_isDateCheckedIn(checkDate)) {
        currentStreak++;
      } else if (i > 0) {
        break;
      }
    }

    // 计算最长连续签到
    int maxStreak = 0;
    int tempStreak = 0;
    final sortedDates = checkinDates.toList()..sort();
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

  const CheckinStatsCard({
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
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '签到统计',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCircle(
                    '累计签到',
                    totalDays,
                    '天',
                    accentColor,
                  ),
                ),
                Expanded(
                  child: _buildStatCircle(
                    '当前连续',
                    currentStreak,
                    '天',
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildStatCircle(
                    '本周签到',
                    weeklyDays,
                    '天',
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
        const SizedBox(height: 8),
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
