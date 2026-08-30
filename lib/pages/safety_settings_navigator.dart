// safety_settings_navigator.dart
// 【CN 165 合规整改 · 方案 A（文件 swap）】
// profile_page.dart 无条件 import 本文件作为"安全中心"导航层 active 文件。
//
// 海外构建（默认）：本文件保留完整实现 → 卡片 + 跳转 SafetySettingsPage。
// CN 构建：build_ipa.sh 在 `if [ "$ZAI_REGION" = "cn" ]` 块内、flutter build 之前，
//   把本文件整体替换为 safety_settings_navigator_stub.dart（无 SafetySettingsPage import），
//   trap 在构建结束后还原本文件 → CN 编译单元根本不引用 SafetySettingsPage 类符号，
//   Dart AOT 物理剔除整文件 → 苹果类级判定扫不到安全中心（表里如一）。
//
// 为何不用 Dart const bool 条件导入：
//   Dart stable 的条件导入 `if (kIsChinaBuild)` 仅支持 `dart.library.*` / `dart.env.*`（实验），
//   自定义顶层 const bool 会被编译器静默忽略（永远选 first URI）→ stub 丢弃 → 类符号残留。
//   文件 swap 是已知 100% 生效的路径（与现有 PBXPROJ / Info.plist sed 切换对称）。
//
// ⚠️ 维护提示：改海外版"安全中心" UI 改本文件即可；stub 仅在函数签名变化时才需同步。

import 'package:flutter/material.dart';

import '../l10n/i18n.dart';
import '../theme/theme_helper.dart';
import 'safety_settings_page.dart';

/// 海外版：构建"安全中心"卡片 widget。
/// 卡片点击 → `openSafetySettings(context)`。
Widget buildSafetyCenterEntry(bool isDark) {
  return _SafetyCenterCardImpl(isDark: isDark);
}

/// 海外版：用户点击"安全中心"卡片后的页面跳转。
void openSafetySettings(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const SafetySettingsPage()),
  );
}

// ============ 原 _buildSafetyCenterEntry 函数体完整搬迁 ============

class _SafetyCenterCardImpl extends StatelessWidget {
  const _SafetyCenterCardImpl({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: ZaiNeColors.cardBg(),
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(((isDark ? 0.12 : 0.04) * 255).round()),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => openSafetySettings(context),
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              // 左侧图标
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade600],
                  ),
                  borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                ),
                child: const Icon(Icons.security_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: ZaiNeSpacing.cardSm),
              // 中间文字
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr.s235, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ZaiNeColors.textPrimary())),
                    const SizedBox(height: 3),
                    Text(
                      tr.s236,
                      style: TextStyle(fontSize: 12, color: ZaiNeColors.textSecondary()),
                    ),
                  ],
                ),
              ),
              // 右侧箭头
              Icon(Icons.chevron_right_rounded, color: ZaiNeColors.textSecondary(), size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
