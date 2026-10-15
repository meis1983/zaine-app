import 'package:flutter/material.dart';
import '../theme/theme_helper.dart';
import 'step_item_widget.dart';
import 'connector_widget.dart';
import '../l10n/i18n.dart';

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

  LightweightGuideWidget({
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
    if (!hasProfileReady) missingItems.add(tr.s854);
    if (!hasContactsReady) missingItems.add(tr.s855);
    if (!hasLocationReady) missingItems.add(tr.s856);

    return Scaffold(
      backgroundColor: ZaiNeColors.scaffoldBg(),
      body: SafeArea(
        child: Column(
          children: [
            // 顶部品牌区（无返回按钮，tab 页面）
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(ZaiNeSpacing.xl, 0, ZaiNeSpacing.xl, ZaiNeSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: ZaiNeSpacing.md),

                    // 温和标题
                    _buildTitle(),
                    SizedBox(height: ZaiNeSpacing.sm),

                    // 副标题
                    _buildSubtitle(missingItems.length),
                    SizedBox(height: ZaiNeSpacing.xxl),

                    // ====== 三步卡片列表 ======
                    StepItemWidget(
                      stepNum: 1,
                      icon: Icons.person_outline,
                      iconBgColor: Colors.blue,
                      label: tr.z0029,
                      desc: tr.z0666,
                      isDone: hasProfileReady,
                      onTap: !hasProfileReady ? onGoToProfile : null,
                    ),

                    SizedBox(height: ZaiNeSpacing.lg),

                    // 连接线
                    ConnectorWidget(isActive: hasProfileReady),

                    StepItemWidget(
                      stepNum: 2,
                      icon: Icons.contact_phone_outlined,
                      iconBgColor: Colors.orange,
                      label: tr.s351,
                      desc: tr.z0667,
                      isDone: hasContactsReady,
                      onTap: (hasProfileReady && !hasContactsReady)
                          ? onGoToContacts
                          : null,
                      locked: !hasProfileReady, // 上一步没完成则锁定
                    ),

                    SizedBox(height: ZaiNeSpacing.lg),

                    ConnectorWidget(isActive: hasContactsReady),

                    StepItemWidget(
                      stepNum: 3,
                      icon: Icons.location_on_outlined,
                      iconBgColor: Colors.green,
                      label: tr.s967,
                      desc: tr.z0668,
                      isDone: hasLocationReady,
                      onTap: (hasContactsReady && !hasLocationReady)
                          ? onRequestLocationPermission
                          : null,
                      locked: !hasContactsReady, // 上一步没完成则锁定
                      isActionButton: true, // 标记为需要特殊样式的按钮
                      pulseController: pulseController,
                    ),

                    SizedBox(height: ZaiNeSpacing.xxl),

                    // 底部提示
                    _buildBottomPrompt(missingItems.length),
                    SizedBox(height: ZaiNeSpacing.xl),
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
      padding: EdgeInsets.symmetric(horizontal: ZaiNeSpacing.xl, vertical: ZaiNeSpacing.lg),
      child: Row(
        children: [
          SizedBox(width: ZaiNeSpacing.xxl), // 左侧占位平衡（替代返回按钮）
          Spacer(),
          Text(
            tr.s071,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: ZaiNeColors.textPrimary(),
            ),
          ),
          Spacer(),
          SizedBox(width: ZaiNeSpacing.xxl), // 平衡
        ],
      ),
    );
  }

  /// 标题（富文本）
  Widget _buildTitle() {
    return Center(
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 22, height: 1.4),
          children: [
            TextSpan(
              text: tr.z0669,
              style: TextStyle(color: ZaiNeColors.textPrimary(), fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text: tr.z0670,
              style: TextStyle(
                color: Colors.orange.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextSpan(text: ' ✨', style: TextStyle(fontSize: 20)),
          ],
        ),
      ),
    );
  }

  /// 副标题
  Widget _buildSubtitle(int missingCount) {
    return Center(
      child: Text(
        tr.z0671(missingCount),
        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
      ),
    );
  }

  /// 底部提示（还差最后一步时显示）
  Widget _buildBottomPrompt(int missingCount) {
    if (missingCount == 1) {
      return Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: ZaiNeSpacing.lg, vertical: ZaiNeSpacing.md),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star, size: 16, color: Colors.orange.shade700),
              SizedBox(width: ZaiNeSpacing.sm),
              Text(
                tr.z0672,
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
    return SizedBox.shrink();
  }
}
