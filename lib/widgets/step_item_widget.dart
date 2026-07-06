// lib/widgets/step_item_widget.dart
// 引导步骤项组件（从 help_page.dart 提取）
// v1.17.4 P3-2 代码复杂度优化

import 'package:flutter/material.dart';
import '../theme/theme_helper.dart';

/// 引导步骤项
/// 显示步骤编号/图标、标签、描述，支持完成/未完成/锁定状态
class StepItemWidget extends StatelessWidget {
  final int stepNum;
  final IconData icon;
  final Color iconBgColor;
  final String label;
  final String desc;
  final bool isDone;
  final VoidCallback? onTap;
  final bool locked;
  final bool isActionButton;
  final AnimationController? pulseController;

  const StepItemWidget({
    super.key,
    required this.stepNum,
    required this.icon,
    required this.iconBgColor,
    required this.label,
    required this.desc,
    required this.isDone,
    required this.onTap,
    this.locked = false,
    this.isActionButton = false,
    this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = !isDone && !locked;
    final isLocationAction = !isDone && !locked && isActionButton;

    return Opacity(
      opacity: locked ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(ZaiNeSpacing.lg),
          decoration: BoxDecoration(
            color: isDone
                ? Colors.green.shade50
                : (isLocationAction
                    ? Colors.green.shade50
                    : (isActive ? Colors.white : Colors.grey.shade100)),
            borderRadius: BorderRadius.circular(ZaiNeRadius.card),
            border: Border.all(
              color: isDone
                  ? Colors.green.shade300
                  : (isLocationAction
                      ? Colors.green
                      : (isActive ? iconBgColor.withValues(alpha: 0.25) : Colors.grey.shade300)),
              width: isDone ? 1.5 : (isLocationAction ? 2.0 : 1),
            ),
            boxShadow: isLocationAction
                ? [BoxShadow(color: Colors.green.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 4))]
                : (isDone
                    ? null
                    : (isActive
                        ? [BoxShadow(color: iconBgColor.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))]
                        : null)),
          ),
          child: Row(
            children: [
              // 左侧：序号 / 图标 / 完成勾 / 动画按钮
              if (isLocationAction && pulseController != null)
                _buildLocationIcon()
              else if (isDone)
                _buildDoneIcon()
              else
                _buildNormalIcon(),
              const SizedBox(width: ZaiNeSpacing.cardSm),
              // 中间：文字
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDone ? Colors.green.shade700 : (isLocationAction ? Colors.green.shade700 : Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDone ? '已完成 ✓' : (locked ? '🔒 请先完成上一步' : desc),
                      style: TextStyle(fontSize: 12, color: isDone ? Colors.green.shade600 : (isLocationAction ? Colors.green.shade600 : Colors.grey[500])),
                    ),
                  ],
                ),
              ),
              // 右侧：箭头 或 锁定图标 或 "去开启" 按钮 或 完成对勾
              if (isDone)
                Icon(Icons.check_circle, color: Colors.green.shade400, size: 22)
              else if (locked)
                Icon(Icons.lock_outline, color: Colors.grey[400], size: 20)
              else if (isLocationAction)
                _buildActionButton()
              else
                _buildChevronIcon(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.green, Color(0xFF38EF7D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.green.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: AnimatedBuilder(
        animation: pulseController!,
        builder: (context, child) => Transform.scale(
          scale: 1.0 + (pulseController!.value * 0.08),
          child: child,
        ),
        child: const Icon(Icons.location_searching, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildDoneIcon() {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: Colors.green,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check, color: Colors.white, size: 24),
    );
  }

  Widget _buildNormalIcon() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: iconBgColor.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: iconBgColor, size: 22),
    );
  }

  Widget _buildActionButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.md, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(ZaiNeRadius.pill),
        boxShadow: [BoxShadow(color: Colors.green.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('去开启', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
          SizedBox(width: 2),
          Icon(Icons.arrow_forward_ios, size: 11, color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildChevronIcon() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: iconBgColor.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.chevron_right, color: iconBgColor, size: 18),
    );
  }
}
