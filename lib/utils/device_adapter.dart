import 'package:flutter/material.dart';

/// iPhone Duo / 通用折叠屏适配工具层。
///
/// 设计原则：
/// 1. 全函数/Widget 在「非折叠设备」上必须 100% 无副作用——当前所有真机
///    （iPhone / iPad / Android 手机）都不会回报 displayFeatures，因此 fold 相关
///    逻辑自动 no-op，绝不改变已确认良好的 UI。
/// 2. 宽度断点让页面在 Split View（iOS 27 可调窗口，可窄至 ~320pt）与
///    内屏 7.6″ 大宽画布上都能自适应。
/// 3. 铰链避让仅为「未来 proof」——iOS Duo 不回报 displayFeature，故当前恒为空操作。

/// Material Design 窗口宽度档位（适配折叠屏 / Split View 的核心尺）。
enum WindowWidthClass {
  /// 手机竖屏 / Split View 窄窗：< 600pt
  compact,

  /// 小平板 / 折叠屏半屏：600–839pt
  medium,

  /// 折叠屏展开 / 大平板 / 横屏：>= 840pt
  expanded,
}

/// 依据当前可用宽度判定窗口档位。
WindowWidthClass windowWidthClass(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  if (width >= 840) return WindowWidthClass.expanded;
  if (width >= 600) return WindowWidthClass.medium;
  return WindowWidthClass.compact;
}

bool isCompactWidth(BuildContext context) =>
    windowWidthClass(context) == WindowWidthClass.compact;

bool isExpandedWidth(BuildContext context) =>
    windowWidthClass(context) == WindowWidthClass.expanded;

/// 在响应式网格里按宽度选列数：compact 用 [compactCount]，
/// medium 用 [mediumCount]，expanded 用 [expandedCount]。
int responsiveCrossAxisCount(
  BuildContext context, {
  int compactCount = 2,
  int mediumCount = 3,
  int expandedCount = 4,
}) {
  switch (windowWidthClass(context)) {
    case WindowWidthClass.compact:
      return compactCount;
    case WindowWidthClass.medium:
      return mediumCount;
    case WindowWidthClass.expanded:
      return expandedCount;
  }
}

/// 找到当前可能存在的折叠铰链 / 折痕 display feature（仅折叠设备会回报）。
/// 用动态类型 + 字符串匹配，兼容不同 Flutter 版本的折叠 API 命名，
/// 避免老 SDK 缺少 DisplayFeature / DisplayFeatureType 类型时编译失败。
dynamic foldDisplayFeature(BuildContext context) {
  for (final f in MediaQuery.of(context).displayFeatures) {
    final typeName = f.type.toString();
    if (typeName.contains('hinge') || typeName.contains('fold')) {
      return f;
    }
  }
  return null;
}

/// 铰链避让内边距：若设备回报了纵向铰链（横跨高度、位于中间的窄带），
/// 则左右各留铰链宽度，避免内容压在中缝。无铰链设备返回 EdgeInsets.zero。
EdgeInsets foldSafePadding(BuildContext context) {
  final fold = foldDisplayFeature(context);
  if (fold == null) return EdgeInsets.zero;
  // 仅处理「纵向分隔」（铰链在中间、bounds 横跨全高）的情形。
  final size = MediaQuery.of(context).size;
  final bounds = fold.bounds as Rect;
  final isVerticalSplit =
      bounds.top <= 0 && bounds.bottom >= size.height - 1;
  if (!isVerticalSplit) return EdgeInsets.zero;
  final band = bounds.width;
  return EdgeInsets.symmetric(horizontal: band);
}

/// 铰链安全区：把 child 包进避让内边距。
///
/// 普通设备（无 displayFeatures）直接透传 child，零影响；
/// 折叠设备展开时自动避开中缝。应用于页面 body，不影响对话框
/// （对话框由 Navigator 上层渲染，不在本 Widget 子树内）。
class FoldSafeArea extends StatelessWidget {
  final Widget child;
  final bool left;
  final bool right;
  final bool top;
  final bool bottom;

  const FoldSafeArea({
    super.key,
    required this.child,
    this.left = true,
    this.right = true,
    this.top = false,
    this.bottom = false,
  });

  @override
  Widget build(BuildContext context) {
    final pad = foldSafePadding(context);
    return Padding(
      padding: EdgeInsets.only(
        left: left ? pad.left : 0,
        right: right ? pad.right : 0,
        top: top ? pad.top : 0,
        bottom: bottom ? pad.bottom : 0,
      ),
      child: child,
    );
  }
}

/// 响应式构建器：回调里直接拿到当前宽度档位，页面据此切换布局。
class ResponsiveLayout extends StatelessWidget {
  final Widget Function(BuildContext context, WindowWidthClass widthClass)
      builder;

  const ResponsiveLayout({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return builder(context, windowWidthClass(context));
  }
}
