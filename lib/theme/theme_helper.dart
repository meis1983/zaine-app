// lib/theme/theme_helper.dart
// 主题色公共工具类（v1.7: 消除6个页面的 DRY 违规）
// v1.8: 添加设计Token（圆角/间距/字体/阴影/语义化颜色）

import 'package:flutter/material.dart';
import '../main.dart';

/// 统一的主题颜色辅助方法
/// 所有页面通过此类获取当前模式下的颜色值
class ZaiNeColors {
  ZaiNeColors._();

  // 品牌色（橙色系）
  static const Color brandOrange = Color(0xFFFF7F50);
  static const Color brandOrangeLight = Color(0xFFFFF5F0);

  // ===== 背景色 =====

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

  // ===== 文字颜色 =====

  /// 主文字（标题、重要内容）
  static Color textPrimary() =>
      themeNotifier.mode == ZaiNeThemeMode.dark ? Colors.white : Colors.black87;

  /// 次要文字（副标题、描述）
  static Color textSecondary() =>
      themeNotifier.mode == ZaiNeThemeMode.dark ? Colors.grey[400]! : Colors.grey[600]!;

  /// 辅助文字（提示、占位）
  static Color textHint() =>
      themeNotifier.mode == ZaiNeThemeMode.dark ? Colors.grey[500]! : Colors.grey[400]!;

  // ===== 特殊组件色 =====

  /// 定位卡片背景色（渐变用）
  static Color locationCardBg() => cardBg();

  /// 分割线颜色
  static Color dividerColor() =>
      themeNotifier.mode == ZaiNeThemeMode.dark ? Colors.grey[800]! : Colors.grey[200]!;

  /// 边框颜色（语义化别名，同 dividerColor）
  static Color borderColor() => dividerColor();

  // ===== 语义化颜色（状态色）=====

  /// 成功/安全（绿色系）
  static Color success() =>
      themeNotifier.mode == ZaiNeThemeMode.dark ? Colors.green.shade300 : Colors.green.shade600;

  /// 警告/提醒（橙色系）
  static Color warning() =>
      themeNotifier.mode == ZaiNeThemeMode.dark ? Colors.orange.shade300 : Colors.orange.shade600;

  /// 危险/错误（红色系）
  static Color danger() =>
      themeNotifier.mode == ZaiNeThemeMode.dark ? Colors.red.shade300 : Colors.red.shade600;

  /// 信息/链接（蓝色系）
  static Color info() =>
      themeNotifier.mode == ZaiNeThemeMode.dark ? Colors.blue.shade300 : Colors.blue.shade600;
}

/// 圆角规范（ZaiNeRadius）
/// 使用方式：ZaiNeRadius.card
class ZaiNeRadius {
  ZaiNeRadius._();
  static const double card   = 16; // 卡片/大容器
  static const double small  = 12; // 小元素/标签
  static const double button = 8;  // 按钮/输入框
  static const double tag    = 4;  // 极小标签
  static const double circle = 90; // 圆形头像
}

/// 间距规范（ZaiNeSpacing）
/// 使用方式：ZaiNeSpacing.md
class ZaiNeSpacing {
  ZaiNeSpacing._();
  static const double xs  = 4;  // 极小（图标与文字）
  static const double sm  = 8;  // 小（同一组元素内）
  static const double md  = 12; // 中（卡片内部padding）
  static const double lg  = 16; // 大（页面边距/卡片间）
  static const double xl  = 24; // 超大（页面标题与内容）
  static const double xxl = 32; // 特大（页面区块间距）
}

/// 字体规范（ZaiNeFontSize）
/// 使用方式：ZaiNeFontSize.title
class ZaiNeFontSize {
  ZaiNeFontSize._();
  static const double title    = 20; // 页面大标题
  static const double subtitle = 17; // 副标题/卡片标题
  static const double body     = 15; // 正文
  static const double bodySm   = 14; // 次正文
  static const double caption  = 13; // 辅助文字
  static const double micro    = 12; // 极小文字/标签
}

/// 阴影规范（ZaiNeShadows）
/// 使用方式：boxShadow: ZaiNeShadows.card
class ZaiNeShadows {
  ZaiNeShadows._();
  static List<BoxShadow> get card => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];
  static List<BoxShadow> get light => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.03),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];
  static List<BoxShadow> get none => [];
}
