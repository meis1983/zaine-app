// lib/widgets/stats_row_widget.dart
// 底部三列统计组件（从 home_page.dart 提取）
// v1.17.4 P3-2 代码复杂度优化

import 'package:flutter/material.dart';
import '../theme/theme_helper.dart';
import 'stat_item_widget.dart';

/// 底部三列统计
/// 显示连续签到、累计签到、本周进度
class StatsRowWidget extends StatelessWidget {
  final int continuousDays;
  final int totalDays;
  final int weeklyDays;

  const StatsRowWidget({
    super.key,
    required this.continuousDays,
    required this.totalDays,
    required this.weeklyDays,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StatItemWidget(
            icon: Icons.local_fire_department,
            iconColor: Colors.orange,
            label: '连续签到',
            value: '$continuousDays 天',
            bgColor: Colors.orange.shade50,
          ),
        ),
        const SizedBox(width: ZaiNeSpacing.lg),  // 16
        Expanded(
          child: StatItemWidget(
            icon: Icons.calendar_today,
            iconColor: Colors.blue,
            label: '累计签到',
            value: '$totalDays 天',
            bgColor: Colors.blue.shade50,
          ),
        ),
        const SizedBox(width: ZaiNeSpacing.lg),  // 16
        Expanded(
          child: StatItemWidget(
            icon: Icons.pie_chart,
            iconColor: Colors.teal,
            label: '本周进度',
            value: '$weeklyDays/7',
            bgColor: Colors.teal.shade50,
          ),
        ),
      ],
    );
  }
}
