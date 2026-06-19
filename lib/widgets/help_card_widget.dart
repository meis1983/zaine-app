// lib/widgets/help_card_widget.dart
// 紧急求助卡片组件（从 home_page.dart 提取）
// v1.17.4 P3-2 代码复杂度优化

import 'package:flutter/material.dart';
import '../theme/theme_helper.dart';

/// 紧急求助卡片
/// 点击进入求助页面
class HelpCardWidget extends StatelessWidget {
  final bool isLoggedIn;
  final VoidCallback onTap;

  const HelpCardWidget({
    super.key,
    required this.isLoggedIn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: ZaiNeSpacing.xl,  // 24
          vertical: ZaiNeSpacing.lg,   // 16
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFF4757),
              Color(0xFFFF6B81),
              Color(0xFFFF4757),
            ],
          ),
          // 求助卡片故意用更大圆角(20)，比其他卡片(16)更醒目
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF4757).withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // 求助图标
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emergency,
                size: 32,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: ZaiNeSpacing.lg),  // 16
            // 文字
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '紧急求助',
                    style: TextStyle(
                      fontSize: ZaiNeFontSize.title,  // 20
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: ZaiNeSpacing.xs),  // 4
                  Text(
                    isLoggedIn ? '点击发送紧急求助' : '请先完善健康档案',
                    style: TextStyle(
                      fontSize: ZaiNeFontSize.caption,  // 13
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            // 箭头
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withValues(alpha: 0.6),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
