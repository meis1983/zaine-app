import 'package:flutter/material.dart';
import '../theme/theme_helper.dart';

/// 分享卡片颜色工具
/// 根据连续签到天数返回对应的渐变色（7级徽章系统匹配）
class ShareCardGenerator {
  /// 获取天数对应的渐变色
  /// 每天一种颜色，7色循环：红→橙→金→绿→青→蓝→紫
  static LinearGradient getGradientByDays(int days) {
    // 7 种颜色按天循环（dayIndex 0-6）
    final dayIndex = (days - 1) % 7;
    const gradients = [
      [Color(0xFFFF4757), Color(0xFFFF6B81)], // Day 1,8,15... 红
      [ZaiNeColors.brandOrange, Color(0xFFFFB347)], // Day 2,9,16... 橙
      [Color(0xFFFFD700), Color(0xFFFF8C00)], // Day 3,10,17.. 金
      [Color(0xFF11998E), Color(0xFF38EF7D)], // Day 4,11,18.. 绿
      [Color(0xFF00D2D3), Color(0xFF0ABDE3)], // Day 5,12,19.. 青
      [Color(0xFF4FACFE), Color(0xFF00F2FE)], // Day 6,13,20.. 蓝
      [Color(0xFF7C4DFF), Color(0xFFE040FB)], // Day 7,14,21.. 紫
    ];
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: gradients[dayIndex],
    );
  }
}
