import 'package:flutter/material.dart';
import '../theme/theme_helper.dart';
import 'step_item_widget.dart';
import 'connector_widget.dart';

/// 轻量引导页 Widget
/// 
/// 从 HelpPage 的 _buildLightweightGuide() 方法提取
/// 包含：顶部品牌区、标题、三步卡片列表、底部提示
class LightweightGuideWidget extends StatelessWidget {
  final bool hasProfileReady;
  final bool hasContactsReady;
  final bool hasLocationReady;
  final AnimationController pulseController;
  final VoidCallback onGoToProfile;
  final VoidCallback onGoToContacts;
  final VoidCallback onRequestLocationPermission;

  const LightweightGuideWidget({
    super.key,
    required this.hasProfileReady,
    required this.hasContactsReady,
    required this.hasLocationReady,
    required this.pulseController,
    required this.onGoToProfile,
    required this.onGoToContacts,
    required this.onRequestLocationPermission,
  });

  @override
  Widget build(BuildContext context) {
    // 计算还差几步
    final missingItems = <String>[];
    if (!hasProfileReady) missingItems.add('档案');
    if (!hasContactsReady) missingItems.add('联系人');
    if (!hasLocationReady) missingItems.add('定位');

    return Scaffold(
      backgroundColor: ZaiNeColors.scaffoldBg(),
      body: SafeArea(
        child: Column(
          children: [
            // 顶部品牌区（无返回按钮，tab 页面）
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: ZaiNeSpacing.md),

                    // 温和标题
                    _buildTitle(),
                    const SizedBox(height: ZaiNeSpacing.sm),

                    // 副标题
                    _buildSubtitle(missingItems.length),
                    const SizedBox(height: ZaiNeSpacing.xxl),

                    // ====== 三步卡片列表 ======
                    StepItemWidget(
                      stepNum: 1,
                      icon: Icons.person_outline,
                      iconBgColor: Colors.blue,
                      label: '完善健康档案',
                      desc: '姓名 · 年龄 · 血型',
                      isDone: hasProfileReady,
                      onTap: !hasProfileReady ? onGoToProfile : null,
                    ),

                    const SizedBox(height: ZaiNeSpacing.lg),

                    // 连接线
                    ConnectorWidget(isActive: hasProfileReady),

                    StepItemWidget(
                      stepNum: 2,
                      icon: Icons.contact_phone_outlined,
                      iconBgColor: Colors.orange,
                      label: '添加紧急联系人',
                      desc: '至少绑定一位家人或朋友',
                      isDone: hasContactsReady,
                      onTap: (hasProfileReady && !hasContactsReady)
                          ? onGoToContacts
                          : null,
                      locked: !hasProfileReady, // 上一步没完成则锁定
                    ),

                    const SizedBox(height: ZaiNeSpacing.lg),

                    ConnectorWidget(isActive: hasContactsReady),

                    StepItemWidget(
                      stepNum: 3,
                      icon: Icons.location_on_outlined,
                      iconBgColor: Colors.green,
                      label: '开启位置权限',
                      desc: '点击下方按钮 → 弹出系统框 → 点「允许」',
                      isDone: hasLocationReady,
                      onTap: (hasContactsReady && !hasLocationReady)
                          ? onRequestLocationPermission
                          : null,
                      locked: !hasContactsReady, // 上一步没完成则锁定
                      isActionButton: true, // 标记为需要特殊样式的按钮
                      pulseController: pulseController,
                    ),

                    const SizedBox(height: ZaiNeSpacing.xxl),

                    // 底部提示
                    _buildBottomPrompt(missingItems.length),
                    const SizedBox(height: ZaiNeSpacing.xl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 顶部品牌栏
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.xl, vertical: ZaiNeSpacing.lg),
      child: Row(
        children: [
          const SizedBox(width: ZaiNeSpacing.xxl), // 左侧占位平衡（替代返回按钮）
          const Spacer(),
          Text(
            '求助设置',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: ZaiNeColors.textPrimary(),
            ),
          ),
          const Spacer(),
          const SizedBox(width: ZaiNeSpacing.xxl), // 平衡
        ],
      ),
    );
  }

  /// 标题（富文本）
  Widget _buildTitle() {
    return Center(
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 22, height: 1.4),
          children: [
            TextSpan(
              text: '让紧急求助 ',
              style: TextStyle(color: ZaiNeColors.textPrimary(), fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text: '随时可用',
              style: TextStyle(
                color: Colors.orange.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
            const TextSpan(text: ' ✨', style: TextStyle(fontSize: 20)),
          ],
        ),
      ),
    );
  }

  /// 副标题
  Widget _buildSubtitle(int missingCount) {
    return Center(
      child: Text(
        '简单 $missingCount 步，一次设置永久生效',
        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
      ),
    );
  }

  /// 底部提示（还差最后一步时显示）
  Widget _buildBottomPrompt(int missingCount) {
    if (missingCount == 1) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.lg, vertical: ZaiNeSpacing.md),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star, size: 16, color: Colors.orange.shade700),
              const SizedBox(width: ZaiNeSpacing.sm),
              Text(
                '还差最后一步就大功告成！',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
