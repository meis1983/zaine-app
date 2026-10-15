// lib/widgets/widget_health_tip.dart
// 健康小贴士组件（从 home_page.dart 拆出）

import 'package:flutter/material.dart';
import '../theme/theme_helper.dart';
import '../l10n/i18n.dart';

/// 健康小贴士卡片
/// 每天固定显示一条（基于日期索引），点击可刷新
class HealthTipWidget extends StatelessWidget {
  HealthTipWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final tips = [
      {'icon': Icons.water_drop, 'color': Colors.blue, 'title': tr.z0673, 'desc': tr.z0674},
      {'icon': Icons.directions_walk, 'color': Colors.green, 'title': tr.z0675, 'desc': tr.z0676},
      {'icon': Icons.bedtime, 'color': Colors.indigo, 'title': tr.z0677, 'desc': tr.z0678},
      {'icon': Icons.favorite, 'color': Colors.red, 'title': tr.z0679, 'desc': tr.z0680},
      {'icon': Icons.restaurant, 'color': Colors.orange, 'title': tr.z0681, 'desc': tr.z0682},
      {'icon': Icons.phone_android, 'color': Colors.purple, 'title': tr.z0683, 'desc': tr.z0684},
      {'icon': Icons.window, 'color': Colors.teal, 'title': tr.z0685, 'desc': tr.z0686},
      {'icon': Icons.people, 'color': Colors.deepOrange, 'title': tr.z0687, 'desc': tr.z0688},
      {'icon': Icons.medication, 'color': Colors.amber, 'title': tr.z0689, 'desc': tr.z0690},
      {'icon': Icons.emoji_emotions, 'color': Colors.pink, 'title': tr.z0691, 'desc': tr.z0692},
      {'icon': Icons.safety_check, 'color': Colors.cyan, 'title': tr.z0693, 'desc': tr.z0694},
      {'icon': Icons.flash_on, 'color': Colors.amber.shade700, 'title': tr.z0695, 'desc': tr.z0696},
      {'icon': Icons.local_hospital, 'color': Colors.redAccent, 'title': tr.z0697, 'desc': tr.z0698},
      {'icon': Icons.thermostat, 'color': Colors.lightBlue, 'title': tr.z0699, 'desc': tr.z0700},
    ];

    final now = DateTime.now();
    final dayIndex = now.difference(DateTime(2026, 1, 1)).inDays % tips.length;
    final tip = tips[dayIndex];

    return GestureDetector(
      onTap: () {}, // 点击反馈由父组件处理
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ZaiNeSpacing.lg, vertical: ZaiNeSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              (tip['color'] as Color).withValues(alpha: 0.08),
              (tip['color'] as Color).withValues(alpha: 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(ZaiNeRadius.cardSm),
          border: Border.all(color: (tip['color'] as Color).withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: (tip['color'] as Color).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(ZaiNeRadius.input),
              ),
              child: Icon(tip['icon'] as IconData,
                  size: 20, color: tip['color'] as Color),
            ),
            SizedBox(width: ZaiNeSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tip['title'] as String,
                    style: TextStyle(
                      fontSize: ZaiNeFontSize.body,
                      fontWeight: FontWeight.w600,
                      color: ZaiNeColors.textPrimary(),
                    ),
                  ),
                  SizedBox(height: ZaiNeSpacing.xs),
                  Text(
                    tip['desc'] as String,
                    style: TextStyle(fontSize: ZaiNeFontSize.micro, color: ZaiNeColors.textSecondary()),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.refresh, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
