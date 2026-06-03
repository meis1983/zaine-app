// lib/theme/theme_helper.dart
// 主题色公共工具类（v1.7: 消除6个页面的 DRY 违规）

import 'package:flutter/material.dart';
import '../main.dart';

/// 统一的主题颜色辅助方法
/// 所有页面通过此类获取当前模式下的颜色值
class ZaiNeColors {
  ZaiNeColors._();

  // ====== 背景色 ======

  /// 页面 Scaffold 背景色
  static Color scaffoldBg() {
    switch (themeNotifier.mode) {
      case ZaiNeThemeMode.dark:
        return const Color(0xFF121212);
      case ZaiNeThemeMode.soft:
        return const Color(0xFFF2EDE8);
      default:
        return const Color(0xFFFFF8F0);
    }
  }

  /// 卡片/容器背景色
  static Color cardBg() {
    switch (themeNotifier.mode) {
      case ZaiNeThemeMode.dark:
        return const Color(0xFF1E1E1E);
      case ZaiNeThemeMode.soft:
        return const Color(0xFFE5DFD8);
      default:
        return Colors.white;
    }
  }

  // ====== 文字颜色 ======

  /// 主文字（标题、重要内容）
  static Color textPrimary() =>
      themeNotifier.mode == ZaiNeThemeMode.dark ? Colors.white : Colors.black87;

  /// 次要文字（副标题、描述）
  static Color textSecondary() =>
      themeNotifier.mode == ZaiNeThemeMode.dark ? Colors.grey[400]! : Colors.grey[600]!;

  /// 辅助文字（提示、占位）
  static Color textHint() =>
      themeNotifier.mode == ZaiNeThemeMode.dark ? Colors.grey[500]! : Colors.grey[400]!;

  // ====== 特殊组件色 ======

  /// 定位卡片背景色（渐变用）
  static Color locationCardBg() => cardBg();

  /// 分割线颜色
  static Color dividerColor() =>
      themeNotifier.mode == ZaiNeThemeMode.dark ? Colors.grey[800]! : Colors.grey[200]!;
}
