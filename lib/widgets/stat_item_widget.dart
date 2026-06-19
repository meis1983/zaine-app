// lib/widgets/stat_item_widget.dart
// 单个统计项组件（从 home_page.dart 提取）
// v1.17.4 P3-2 代码复杂度优化

import 'package:flutter/material.dart';
import '../theme/theme_helper.dart';

/// 单个统计项
/// 显示图标、标签、数值
class StatItemWidget extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color bgColor;

  const StatItemWidget({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: ZaiNeSpacing.lg,   // 16
          horizontal: ZaiNeSpacing.sm,  // 8
        ),
        decoration: BoxDecoration(
          color: ZaiNeColors.cardBg(),
          borderRadius: BorderRadius.circular(ZaiNeRadius.card),  // 16
          boxShadow: ZaiNeShadows.card,
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: ZaiNeSpacing.sm),  // 8
            Text(
              value,
              style: TextStyle(
                fontSize: ZaiNeFontSize.subtitle,  // 17
                fontWeight: FontWeight.bold,
                color: ZaiNeColors.textPrimary(),
              ),
            ),
            const SizedBox(height: ZaiNeSpacing.xs),  // 4
            Text(
              label,
              style: TextStyle(
                fontSize: ZaiNeFontSize.micro,  // 12
                color: ZaiNeColors.textSecondary(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
