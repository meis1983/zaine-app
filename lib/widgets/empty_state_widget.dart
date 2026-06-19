import 'package:flutter/material.dart';
import '../theme/theme_helper.dart';

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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF7F50).withValues(alpha: 0.1),
              ),
              child: Icon(
                Icons.people_outline,
                size: 50,
                color: Colors.grey.shade300,
              ),
            ),
            const SizedBox(height: ZaiNeSpacing.xl),
            Text(
              '暂无紧急联系人',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: ZaiNeColors.textSecondary(),
              ),
            ),
            const SizedBox(height: ZaiNeSpacing.md),
            Text(
              '添加至少一个紧急联系人\n确保求助功能正常触发',
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
                  const Expanded(
                    child: Text(
                      '紧急联系人将在求助时收到您的位置和健康信息\n拖动可调整优先顺序',
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
