import 'package:flutter/material.dart';
import '../theme/theme_helper.dart';
import '../l10n/i18n.dart';

/// 联系人空状态 Widget
/// 
/// 从 ContactsPage 的 _buildEmptyState() 方法提取
/// 显示空状态提示，引导用户添加联系人
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ZaiNeSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ZaiNeColors.brandOrange.withValues(alpha: 0.1),
              ),
              child: Icon(
                Icons.people_outline,
                size: 50,
                color: Colors.grey.shade300,
              ),
            ),
            const SizedBox(height: ZaiNeSpacing.xl),
            Text(
              tr.z0880,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: ZaiNeColors.textSecondary(),
              ),
            ),
            const SizedBox(height: ZaiNeSpacing.md),
            Text(
              tr.z0881,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: ZaiNeColors.textSecondary().withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: ZaiNeSpacing.xxl),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: ZaiNeSpacing.md),
                  Expanded(
                    child: Text(
                      tr.z0882,
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
