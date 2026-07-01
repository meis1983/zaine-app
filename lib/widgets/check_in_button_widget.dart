// lib/widgets/check_in_button_widget.dart
// 签到按钮组件（从 home_page.dart 提取）
// v1.17.4 P3-2 代码复杂度优化

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/theme_helper.dart';
import '../utils/badge_generator.dart';

/// 签到按钮
/// 显示签到状态、徽章等级，支持点击签到
class CheckInButtonWidget extends StatelessWidget {
  final int continuousDays;
  final bool checkedInToday;
  final VoidCallback onTap;
  final Animation<double> scaleAnimation;
  /// 【修复 v1.91.0】数据是否已就绪（首次启动无本地缓存时显示骨架屏，避免 "连续 0 天" 视觉错）
  final bool isDataReady;

  const CheckInButtonWidget({
    super.key,
    required this.continuousDays,
    required this.checkedInToday,
    required this.onTap,
    required this.scaleAnimation,
    this.isDataReady = true,
  });

  @override
  Widget build(BuildContext context) {
    // 【P3】统一使用 BadgeGenerator.getLevel，避免重复维护50级映射
    final badgeLevel = BadgeGenerator.getLevel(continuousDays);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(90),
          onTap: onTap,
          onTapDown: (_) => HapticFeedback.lightImpact(),
          child: AnimatedBuilder(
            animation: scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: scaleAnimation.value,
                child: child,
              );
            },
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: checkedInToday
                      ? [Colors.teal.shade400, Colors.green.shade500]
                      : [ZaiNeColors.brandOrange, const Color(0xFFFF6B3D)],
                ),
                // 签到按钮阴影故意偏大，让按钮有"浮起"感
                boxShadow: [
                  BoxShadow(
                    color: (checkedInToday
                            ? Colors.teal.shade300
                            : ZaiNeColors.brandOrange)
                        .withValues(alpha: checkedInToday ? 0.25 : 0.4),
                    blurRadius: checkedInToday ? 20 : 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 【P3】徽章等级图标 — 连续签到 >=1 天即显示徽章
                  if (continuousDays >= 1)
                    Text(
                      badgeLevel.emoji,
                      style: const TextStyle(fontSize: 28),
                    )
                  else
                    Icon(
                      checkedInToday ? Icons.check_circle : Icons.touch_app,
                      size: 44,
                      color: Colors.white,
                    ),
                  const SizedBox(height: ZaiNeSpacing.xs),
                  Text(
                    checkedInToday ? '今日已签到' : '点击签到',
                    style: const TextStyle(
                      fontSize: ZaiNeFontSize.title,  // 20
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  // 【P3】连续签到 >=1 天即显示徽章和天数
                  // 【修复 v1.91.0】数据未就绪时显示骨架屏占位，避免"短暂显示 0 天"
                  if (!isDataReady) ...[
                    const SizedBox(height: ZaiNeSpacing.xs),
                    // 占位骨架（两个浅色横条）
                    Container(
                      width: 60,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 80,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ] else if (continuousDays >= 1) ...[
                    const SizedBox(height: ZaiNeSpacing.xs),
                    Text(
                      badgeLevel.title,
                      style: TextStyle(
                        fontSize: ZaiNeFontSize.micro,  // 12
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '连续 $continuousDays 天',
                      style: TextStyle(
                        fontSize: ZaiNeFontSize.micro,  // 12
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
