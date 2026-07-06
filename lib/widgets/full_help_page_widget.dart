import 'package:flutter/material.dart';
import '../theme/theme_helper.dart';
import 'help_demo_mode.dart';
import 'location_card_widget.dart';

/// 完整求助页面 Widget
/// 
/// 从 HelpPage 的 _buildFullHelpPage() 方法提取
/// 包含：警告提示、就绪指示器、档案预览、求助按钮、体验演示按钮、实时定位卡片
class FullHelpPageWidget extends StatelessWidget {
  final bool isTriggering;
  final int countdown;
  final String? myPhone;
  final String userName;
  final int userAge;
  final String bloodType;
  final AnimationController pulseController;
  final VoidCallback onTriggerHelp;
  final VoidCallback onCancelHelp;
  final VoidCallback onShowPhoneInput;
  
  // LocationCard 参数
  final bool locationLoading;
  final String? locationLat;
  final String? locationLng;
  final String? locationAddress;
  final VoidCallback onLocationRefresh;

  const FullHelpPageWidget({
    super.key,
    required this.isTriggering,
    required this.countdown,
    this.myPhone,
    required this.userName,
    required this.userAge,
    required this.bloodType,
    required this.pulseController,
    required this.onTriggerHelp,
    required this.onCancelHelp,
    required this.onShowPhoneInput,
    this.locationLoading = false,
    this.locationLat,
    this.locationLng,
    this.locationAddress,
    required this.onLocationRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZaiNeColors.scaffoldBg(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: null, // tab 页面无返回按钮
        title: Text('紧急求助', style: TextStyle(color: ZaiNeColors.textPrimary())),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.xl, vertical: ZaiNeSpacing.md),
          child: Column(
            children: [
              // 温和警告提示
              _buildWarningBanner(),
              const SizedBox(height: ZaiNeSpacing.lg),

              // 就绪指示器
              _buildReadyIndicator(),
              const SizedBox(height: ZaiNeSpacing.md),

              // 档案预览
              _buildProfilePreview(),
              const SizedBox(height: ZaiNeSpacing.sm),

              // 手机号设置提示
              _buildPhonePrompt(),

              const SizedBox(height: ZaiNeSpacing.xxl),

              // 紧急求助按钮区域
              _buildHelpButtonArea(context),
              const SizedBox(height: ZaiNeSpacing.lg),

              // 体验演示按钮
              _buildDemoButton(context),
              const SizedBox(height: ZaiNeSpacing.xl),

              // 实时定位卡片
              LocationCardWidget(
                isLoading: locationLoading,
                coordLat: locationLat,
                coordLng: locationLng,
                address: locationAddress,
                onRefresh: onLocationRefresh,
              ),
              const SizedBox(height: ZaiNeSpacing.xl),

              // 底部留白
              SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 16),
            ],
          ),
        ),
      ),
    );
  }

  /// 警告提示横幅
  Widget _buildWarningBanner() {
    return Container(
      padding: const EdgeInsets.all(ZaiNeSpacing.md),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      
        boxShadow: ZaiNeShadows.card,),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: ZaiNeSpacing.sm),
          Expanded(
            child: Text(
              '紧急情况才使用，将联系紧急联系人并发送位置',
              style: TextStyle(fontSize: 13, color: Colors.orange.shade800),
            ),
          ),
        ],
      ),
    );
  }

  /// 就绪指示器
  Widget _buildReadyIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.lg, vertical: ZaiNeSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
      
        boxShadow: ZaiNeShadows.card,),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade600, size: 16),
          const SizedBox(width: ZaiNeSpacing.sm),
          Text(
            '档案 · 联系人 · 定位 已就绪',
            style: TextStyle(
              fontSize: 12,
              color: Colors.green.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 档案预览卡片
  Widget _buildProfilePreview() {
    return Container(
      padding: const EdgeInsets.all(ZaiNeSpacing.cardXs),
      decoration: BoxDecoration(
        color: ZaiNeColors.cardBg(),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade100),
      
        boxShadow: ZaiNeShadows.card,),
      child: Row(
        children: [
          Icon(Icons.medical_information, color: Colors.blue.shade600, size: 18),
          const SizedBox(width: ZaiNeSpacing.sm),
          Expanded(
            child: Text(
              '${myPhone != null && myPhone!.isNotEmpty ? "$myPhone · " : ""}$userName · $userAge岁 · $bloodType',
              style: TextStyle(
                color: Colors.blue.shade800,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
        ],
      ),
    );
  }

  /// 手机号设置提示
  Widget _buildPhonePrompt() {
    if (myPhone == null || myPhone!.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: GestureDetector(
          onTap: onShowPhoneInput,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.md, vertical: ZaiNeSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade300),
            
              boxShadow: ZaiNeShadows.card,),
            child: Row(
              children: [
                Icon(Icons.phone_android, color: Colors.orange.shade700, size: 16),
                const SizedBox(width: ZaiNeSpacing.sm),
                Expanded(
                  child: Text(
                    '手机号未设置，点击此处补充 →',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  /// 求助按钮区域（触发中/未触发）
  Widget _buildHelpButtonArea(BuildContext context) {
    if (isTriggering) {
      return _buildTriggeringState();
    } else {
      return _buildIdleState(context);
    }
  }

  /// 触发中的状态（倒计时）
  Widget _buildTriggeringState() {
    return Column(
      children: [
        Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.shade100,
            border: Border.all(color: Colors.red, width: 4),
          ),
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.2, end: 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              builder: (context, scale, child) => Transform.scale(
                scale: scale,
                child: Text(
                  '$countdown',
                  key: ValueKey(countdown),
                  style: TextStyle(
                    fontSize: 70,
                    fontWeight: FontWeight.bold,
                    color: countdown <= 2 ? Colors.red.shade900 : Colors.red.shade700,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: ZaiNeSpacing.lg),
        Text(
          '正在发送求助...',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.red.shade700,
          ),
        ),
        const SizedBox(height: ZaiNeSpacing.md),
        TextButton(
          onPressed: onCancelHelp,
          child: Text(
            '取消',
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }

  /// 未触发状态（求助按钮）
  Widget _buildIdleState(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTriggerHelp,
          onTapDown: (_) => Feedback.forTap(context),
          child: AnimatedBuilder(
            animation: pulseController,
            builder: (context, child) => Transform.scale(
              scale: 1.0 + (pulseController.value * 0.08),
              child: child,
            ),
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.red.shade400, Colors.red.shade600],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emergency, size: 56, color: Colors.white),
                  SizedBox(height: ZaiNeSpacing.md),
                  Text(
                    '求助',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: ZaiNeSpacing.md),
        Text(
          '点击触发紧急求助',
          style: TextStyle(fontSize: 14, color: ZaiNeColors.textSecondary()),
        ),
      ],
    );
  }

  /// 体验演示按钮
  Widget _buildDemoButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Feedback.forTap(context);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const HelpDemoMode()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.xl, vertical: ZaiNeSpacing.md),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.orange.shade200),
        
          boxShadow: ZaiNeShadows.card,),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_outline, color: Colors.orange.shade700, size: 18),
            const SizedBox(width: ZaiNeSpacing.sm),
            Text(
              '体验演示',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(width: ZaiNeSpacing.xs),
            Icon(Icons.chevron_right, color: Colors.orange.shade400, size: 16),
          ],
        ),
      ),
    );
  }
}
