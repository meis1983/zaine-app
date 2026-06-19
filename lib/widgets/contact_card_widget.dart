import 'package:flutter/material.dart';
import '../theme/theme_helper.dart';

/// 联系人卡片 Widget（完整版）
/// 
/// 从 ContactsPage 的 _buildContactCard() 方法提取
/// 显示单个联系人信息，支持拖动排序、编辑、删除
class ContactCardWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final name = (contact['name'] ?? '').toString();
    final phone = (contact['phone'] ?? '').toString();
    final relation = (contact['relation'] ?? '亲友').toString();

    return Container(
      key: ValueKey('contact_${name}_$itemIndex'),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ZaiNeColors.cardBg(),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.lg, vertical: ZaiNeSpacing.md),
        child: Row(
          children: [
            // 拖动手柄
            if (dragHandle != null) dragHandle!,
            const SizedBox(width: ZaiNeSpacing.sm),

            // 头像
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF7F50).withValues(alpha: 0.1),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF7F50),
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
                      // 会员限制锁定图标
                      if (!isPremium) ...[
                        Icon(Icons.lock_outline, size: 13, color: ZaiNeColors.textSecondary()),
                        const SizedBox(width: ZaiNeSpacing.xs),
                      ],
                      // 优先级标签
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.sm, vertical: ZaiNeSpacing.xs),
                        decoration: BoxDecoration(
                          color: priorityColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: priorityColor.withValues(alpha: 0.3),
                            width: 0.5,
                          ),
                        
                          boxShadow: ZaiNeShadows.card,),
                        child: Text(
                          priorityLabel,
                          style: TextStyle(
                            fontSize: 9.5,
                            color: priorityColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: ZaiNeSpacing.xs),
                  Text(
                    phone,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: ZaiNeSpacing.xs),
                  // 关系标签
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.sm, vertical: ZaiNeSpacing.xs),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    
                      boxShadow: ZaiNeShadows.card,),
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
                  onPressed: onEdit,
                  visualDensity: VisualDensity.compact,
                  tooltip: '编辑',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  onPressed: onDelete,
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
