// lib/widgets/home_header.dart
// 首页顶部标题栏组件（从 home_page.dart 提取）
// v1.17.4 P3-2 代码复杂度优化

import 'package:flutter/material.dart';
import 'dart:io';
import '../theme/theme_helper.dart';

/// 首页顶部标题栏
/// 包含：Logo、问候语、签到状态胶囊、会员等级标签、头像
class HomeHeaderWidget extends StatelessWidget {
  final bool isLoggedIn;
  final bool checkedInToday;
  final String? userName;
  final String? avatarPath;
  final String membershipLevel;
  final int totalRegistered;
  final int guardianCount;
  final int continuousDays;
  final VoidCallback onTapAvatar;
  final VoidCallback onTapMembership;

  const HomeHeaderWidget({
    super.key,
    required this.isLoggedIn,
    required this.checkedInToday,
    this.userName,
    this.avatarPath,
    required this.membershipLevel,
    required this.totalRegistered,
    required this.guardianCount,
    required this.continuousDays,
    required this.onTapAvatar,
    required this.onTapMembership,
  });

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return '夜深了';
    if (hour < 9) return '早上好';
    if (hour < 12) return '上午好';
    if (hour < 14) return '中午好';
    if (hour < 18) return '下午好';
    return '晚上好';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: ZaiNeSpacing.md,    // 12
        bottom: ZaiNeSpacing.xl,  // 24
      ),
      child: Row(
        children: [
          // Logo
          ClipRRect(
            borderRadius: BorderRadius.circular(ZaiNeRadius.small),  // 12
            child: Image.asset(
              'assets/images/zaine_logo_home.png',
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: ZaiNeSpacing.sm),  // 8
          // 问候语 + 签到状态
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreeting(),
                  style: TextStyle(
                    fontSize: ZaiNeFontSize.bodySm,  // 14
                    color: ZaiNeColors.textHint(),  // 辅助文字（自动适配暗黑模式）
                  ),
                ),
                const SizedBox(height: ZaiNeSpacing.xs),
                Row(
                  children: [
                    const Text(
                      '在呢',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: ZaiNeColors.brandOrange,
                      ),
                    ),
                    const SizedBox(width: ZaiNeSpacing.sm),  // 8
                    // 签到状态胶囊
                    _buildCheckInStatusCapsule(),
                    const SizedBox(width: ZaiNeSpacing.xs),  // 4
                    // 会员等级标签
                    GestureDetector(
                      onTap: onTapMembership,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: ZaiNeSpacing.xs,  // 4
                            vertical: ZaiNeSpacing.xs,    // 4
                          ),
                        decoration: BoxDecoration(
                          gradient: membershipLevel == 'smart'
                              ? const LinearGradient(
                                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : LinearGradient(
                                  colors: [
                                    Colors.orange.shade300,
                                    Colors.orange.shade400,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          borderRadius: BorderRadius.circular(ZaiNeRadius.small),  // 12
                        
                          boxShadow: ZaiNeShadows.card,),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              membershipLevel == 'smart'
                                  ? Icons.auto_awesome
                                  : Icons.shield_outlined,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: ZaiNeSpacing.xs),  // 4
                            Text(
                              membershipLevel == 'smart' ? '智能版' : '体验版',
                              style: const TextStyle(
                                fontSize: ZaiNeFontSize.micro,  // 12
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 头像
          GestureDetector(
            onTap: onTapAvatar,
            child: _buildAvatar(),
          ),
        ],
      ),
    );
  }

  /// 签到状态胶囊
  Widget _buildCheckInStatusCapsule() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ZaiNeSpacing.xs,  // 4
        vertical: ZaiNeSpacing.xs,    // 4
      ),
      decoration: BoxDecoration(
        color: checkedInToday
            ? Colors.green.shade50
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(ZaiNeRadius.small),  // 12
      
        boxShadow: ZaiNeShadows.card,),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            checkedInToday ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: checkedInToday ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: ZaiNeSpacing.xs),  // 4
          Text(
            checkedInToday ? '已签到' : '未签到',
            style: TextStyle(
              fontSize: ZaiNeFontSize.micro,  // 12
              color: checkedInToday ? Colors.green : Colors.orange,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 头像 Widget
  Widget _buildAvatar() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: avatarPath == null
            ? LinearGradient(
                colors: [
                  ZaiNeColors.brandOrange.withValues(alpha: 0.2),
                  const Color(0xFFFFB347).withValues(alpha: 0.2),
                ],
              )
            : null,
        color: avatarPath == null ? null : null,
        image: avatarPath != null && avatarPath!.isNotEmpty
            ? DecorationImage(
                image: avatarPath!.startsWith('/')
                    ? FileImage(File(avatarPath!))
                    : AssetImage(avatarPath!) as ImageProvider,
                fit: BoxFit.cover,
              )
            : null,
        border: Border.all(
          color: ZaiNeColors.brandOrange.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: avatarPath == null
          ? Icon(
              isLoggedIn ? Icons.person : Icons.person_add,
              color: ZaiNeColors.brandOrange,
              size: 24,
            )
          : null,
    );
  }
}
