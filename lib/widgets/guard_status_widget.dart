// lib/widgets/guard_status_widget.dart
// 守护状态条组件（从 home_page.dart 提取）
// v1.17.4 P3-2 代码复杂度优化

import 'package:flutter/material.dart';
import '../theme/theme_helper.dart';

/// 守护状态条
/// 显示守护状态、连续天数、守护圈人数
class GuardStatusWidget extends StatelessWidget {
  final bool isLoggedIn;
  final int continuousDays;
  final int totalRegistered;
  final int guardianCount;

  const GuardStatusWidget({
    super.key,
    required this.isLoggedIn,
    required this.continuousDays,
    required this.totalRegistered,
    required this.guardianCount,
  });

  @override
  Widget build(BuildContext context) {
    // 【P2】显示历史最高连续纪录，减少断签心理落差
    String statusText = isLoggedIn
        ? '守护已就绪 · $continuousDays 天连续守护'
        : '请完善健康档案，开启守护';

    // 【v2.0 新增】显示守护圈人数
    if (isLoggedIn && totalRegistered > 0) {
      statusText += ' · $totalRegistered 位守护成员';
    } else if (isLoggedIn && guardianCount > 0) {
      statusText += ' · $guardianCount 位守护者';
    }

    final statusColor = isLoggedIn ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ZaiNeSpacing.lg,  // 16
        vertical: ZaiNeSpacing.sm,   // 8
      ),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(ZaiNeRadius.small),  // 12
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, color: statusColor, size: 18),
          const SizedBox(width: ZaiNeSpacing.sm),  // 8
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: ZaiNeFontSize.caption,  // 13
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (isLoggedIn) Icon(Icons.check_circle, color: statusColor, size: 16),
        ],
      ),
    );
  }
}
