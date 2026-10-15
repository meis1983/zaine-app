// lib/widgets/peace_request_banner.dart
// 首页平安确认请求横幅组件（从 home_page.dart 提取）
// v1.17.4 P3-2 代码复杂度优化
// 方案C 合并版（CN V1.1）：响应侧升级为三按钮「我没事 / 立即签到 / 需要帮助」
// v1.97.6 方案E：去「立即签到」，改两按钮「我没事 / 需要帮助」+ 卡片式精致布局
//   - 去掉「立即签到」：报平安与签到是两个动作，绑定混淆；两按钮聚焦核心语义
//   - 卡片式：白底圆角卡 + 头像/名字/请求语 + 主次按钮（我没事=绿实心主 / 需要帮助=红描边次）

import 'package:flutter/material.dart';
import '../theme/theme_helper.dart';
import '../l10n/i18n.dart';

/// 平安确认请求横幅
/// 当有守护者发来平安确认请求时显示
class PeaceRequestBannerWidget extends StatelessWidget {
  final List<Map<String, dynamic>> pendingRequests;
  // 方案C：单一确认 → 响应（responseType: ok / help；checkin 已废弃不再发起）
  final Function(int requestId, String responseType) onRespond;
  final Function(int requestId) onDismiss;

  const PeaceRequestBannerWidget({
    super.key,
    required this.pendingRequests,
    required this.onRespond,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (pendingRequests.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (final req in pendingRequests) _buildBanner(context, req),
        const SizedBox(height: ZaiNeSpacing.xs), // 4
      ],
    );
  }

  Widget _buildBanner(BuildContext context, Map<String, dynamic> req) {
    final name = (req['guardian_name'] ?? tr.s374).toString();
    final avatarChar = (name.isNotEmpty) ? String.fromCharCodes(name.runes.take(1)) : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: ZaiNeSpacing.sm), // 8
      padding: const EdgeInsets.all(ZaiNeSpacing.lg), // 16
      decoration: BoxDecoration(
        color: ZaiNeColors.cardBg(),
        borderRadius: BorderRadius.circular(ZaiNeRadius.card), // 16
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: ZaiNeShadows.card,
      ),
      // 方案E：卡片式——上为「头像+名字+请求语+关闭」，分割线后为两按钮 + 底部副文案
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部行：头像 + 名字 + 请求语 + 关闭
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF7C4DFF),
                child: Text(
                  avatarChar,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: ZaiNeSpacing.md), // 12
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: ZaiNeFontSize.bodySm, // 14
                        fontWeight: FontWeight.w600,
                        color: ZaiNeColors.textPrimary(),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr.z0763, // 点击下方按钮让他们安心
                      style: TextStyle(
                        fontSize: ZaiNeFontSize.micro, // 12
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => onDismiss(req['request_id'] ?? 0),
                icon: Icon(Icons.close, color: Colors.grey[400], size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: ZaiNeSpacing.md), // 12
          // 分隔线
          Divider(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: ZaiNeSpacing.md), // 12
          // 按钮区：我没事（绿实心主按钮，宽）｜ 需要帮助（红描边次按钮，窄）
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _ResponseButton(
                  label: tr.z0902, // 我没事
                  filled: true,
                  backgroundColor: const Color(0xFF3B6D11),
                  textColor: Colors.white,
                  onTap: () => onRespond(req['request_id'] ?? 0, 'ok'),
                ),
              ),
              const SizedBox(width: ZaiNeSpacing.md), // 12
              Expanded(
                flex: 2,
                child: _ResponseButton(
                  label: tr.z0904, // 需要帮助
                  filled: false,
                  backgroundColor: Colors.white,
                  borderColor: const Color(0xFFA32D2D),
                  textColor: const Color(0xFFA32D2D),
                  onTap: () => onRespond(req['request_id'] ?? 0, 'help'),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZaiNeSpacing.md), // 12
          // 底部副文案
          Text(
            tr.z0914, // 回复后对方会立即看到你的状态
            style: TextStyle(
              fontSize: ZaiNeFontSize.micro, // 12
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}

/// 平安确认按钮（支持实心/描边两种样式）
/// 注意：label 来自 tr.xxx（运行时调用），因此本组件及子组件均不可声明为 const。
class _ResponseButton extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;
  final bool filled;
  final VoidCallback onTap;

  const _ResponseButton({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.borderColor,
    this.filled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        side: (filled || borderColor == null)
            ? null
            : BorderSide(color: borderColor!, width: 1),
        padding: const EdgeInsets.symmetric(
          horizontal: ZaiNeSpacing.md, // 12
          vertical: ZaiNeSpacing.sm, // 8
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZaiNeRadius.button), // 8
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: textColor,
        ),
      ),
    );
  }
}
