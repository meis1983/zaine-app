import 'package:flutter/material.dart';
import '../theme/theme_helper.dart';

/// 联系人卡片 Widget（完整版）
///
/// 从 ContactsPage 的 _buildContactCard() 方法提取
/// 显示单个联系人信息，支持拖动排序、编辑、删除
/// 【隐私】手机号默认脱敏显示(138****5678)，点击眼睛图标或号码才显示明文
class ContactCardWidget extends StatefulWidget {
  final int itemIndex;
  final int contactIndex;
  final Map<String, dynamic> contact;
  final Color priorityColor;
  final String priorityLabel;
  final bool isPremium;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Widget? dragHandle;

  const ContactCardWidget({
    super.key,
    required this.itemIndex,
    required this.contactIndex,
    required this.contact,
    required this.priorityColor,
    required this.priorityLabel,
    required this.isPremium,
    required this.onEdit,
    required this.onDelete,
    this.dragHandle,
  });

  @override
  State<ContactCardWidget> createState() => _ContactCardWidgetState();
}

class _ContactCardWidgetState extends State<ContactCardWidget> {
  bool _revealed = false;

  /// 手机号脱敏：保留前3后4，中间以 **** 代替
  String _maskPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 7) {
      return digits.replaceRange(3, digits.length - 4, '****');
    }
    if (digits.length > 1) {
      return '${digits[0]}****${digits[digits.length - 1]}';
    }
    return phone;
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.contact['name'] ?? '').toString();
    final phone = (widget.contact['phone'] ?? '').toString();
    final relation = (widget.contact['relation'] ?? '亲友').toString();
    final displayPhone =
        phone.isEmpty ? '' : (_revealed ? phone : _maskPhone(phone));

    return Container(
      key: ValueKey('contact_${name}_${widget.itemIndex}'),
      margin: const EdgeInsets.only(bottom: ZaiNeSpacing.md),
      decoration: BoxDecoration(
        color: ZaiNeColors.cardBg(),
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: ZaiNeSpacing.lg, vertical: ZaiNeSpacing.md),
        child: Row(
          children: [
            // 拖动手柄
            if (widget.dragHandle != null) widget.dragHandle!,
            const SizedBox(width: ZaiNeSpacing.sm),

            // 头像
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ZaiNeColors.brandOrange.withValues(alpha: 0.1),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: ZaiNeColors.brandOrange,
                  ),
                ),
              ),
            ),

            const SizedBox(width: ZaiNeSpacing.md),

            // 信息区
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: ZaiNeSpacing.sm),
                      // 优先级标签
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: ZaiNeSpacing.sm,
                            vertical: ZaiNeSpacing.xs),
                        decoration: BoxDecoration(
                          color: widget.priorityColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: widget.priorityColor.withValues(alpha: 0.3),
                            width: 0.5,
                          ),
                          boxShadow: ZaiNeShadows.card,
                        ),
                        child: Text(
                          widget.priorityLabel,
                          style: TextStyle(
                            fontSize: 9.5,
                            color: widget.priorityColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: ZaiNeSpacing.xs),
                  // 【隐私】手机号默认脱敏，点击眼睛/号码切换明文
                  if (phone.isNotEmpty)
                    InkWell(
                      onTap: () => setState(() => _revealed = !_revealed),
                      borderRadius: BorderRadius.circular(6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _revealed
                                ? Icons.visibility_off
                                : Icons.visibility,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            displayPhone,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: ZaiNeSpacing.xs),
                  // 关系标签
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: ZaiNeSpacing.sm, vertical: ZaiNeSpacing.xs),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: ZaiNeShadows.card,
                    ),
                    child: Text(
                      relation,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 操作按钮
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.grey[500], size: 18),
                  onPressed: widget.onEdit,
                  visualDensity: VisualDensity.compact,
                  tooltip: '编辑',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 18),
                  onPressed: widget.onDelete,
                  visualDensity: VisualDensity.compact,
                  tooltip: '删除',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
