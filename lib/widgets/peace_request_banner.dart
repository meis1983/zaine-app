// lib/widgets/peace_request_banner.dart
// 首页平安确认请求横幅组件（从 home_page.dart 提取）
// v1.17.4 P3-2 代码复杂度优化

import 'package:flutter/material.dart';
import '../theme/theme_helper.dart';

/// 平安确认请求横幅
/// 当有守护者发来平安确认请求时显示
class PeaceRequestBannerWidget extends StatelessWidget {
  final List<Map<String, dynamic>> pendingRequests;
  final Function(int requestId) onConfirm;
  final Function(int requestId) onDismiss;

  const PeaceRequestBannerWidget({
    super.key,
    required this.pendingRequests,
    required this.onConfirm,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (pendingRequests.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (final req in pendingRequests) _buildBanner(context, req),
        const SizedBox(height: ZaiNeSpacing.xs),  // 4
      ],
    );
  }

  Widget _buildBanner(BuildContext context, Map<String, dynamic> req) {
    return Container(
      margin: const EdgeInsets.only(bottom: ZaiNeSpacing.sm),  // 8
      padding: const EdgeInsets.symmetric(
        horizontal: ZaiNeSpacing.lg,  // 16
        vertical: ZaiNeSpacing.md,   // 12
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C4DFF), Color(0xFF9C27B0)],
        ),
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),  // 16
        boxShadow: ZaiNeShadows.card,
      ),
      child: Row(
        children: [
          const Icon(Icons.favorite, color: Colors.white, size: 22),
          const SizedBox(width: ZaiNeSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${req['guardian_name'] ?? '守护者'}想确认你是否平安',
                  style: const TextStyle(
                    fontSize: ZaiNeFontSize.bodySm,  // 14
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: ZaiNeSpacing.xs),  // 4
                Text(
                  '点击下方按钮让他们安心',
                  style: TextStyle(
                    fontSize: ZaiNeFontSize.micro,  // 12
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: ZaiNeSpacing.sm),  // 8
          TextButton(
            onPressed: () => onConfirm(req['request_id'] ?? 0),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(
                horizontal: ZaiNeSpacing.lg,  // 16
                vertical: ZaiNeSpacing.sm,   // 8
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ZaiNeRadius.button),  // 8
              ),
            ),
            child: const Text('我平安', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          IconButton(
            onPressed: () => onDismiss(req['request_id'] ?? 0),
            icon: const Icon(Icons.close, color: Colors.white70, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
