import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/theme_helper.dart';

/// 求助演示模式 — 让用户无需真出事就能体验完整求助流程
///
/// 设计原则：
/// - 30秒沉浸式演示，模拟真实求助触发全过程
/// - 纯本地动画（不需要后端）
/// - 结束后明确标注"以上为演示"，避免混淆
/// - 底部进度条让用户知道进度
class HelpDemoMode extends StatefulWidget {
  const HelpDemoMode({super.key});

  @override
  State<HelpDemoMode> createState() => _HelpDemoModeState();
}

class _HelpDemoModeState extends State<HelpDemoMode> with TickerProviderStateMixin {
  // 动画控制器
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  // 演示阶段
  int _currentStep = 0;
  String _statusText = '准备开始演示...';
  String _subText = '';
  bool _isRunning = false;
  double _progress = 0.0;

  // 倒计时
  int _countdown = 5;
  bool _showCountdown = false;

  // 模拟数据
  final String _demoAddress = '北京市朝阳区建国路88号SOHO现代城';

  // 步骤完成状态
  final List<bool> _stepCompleted = [false, false, false, false, false, false];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);

    // 自动开始演示
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), _startDemo);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _startDemo() async {
    if (!mounted) return;
    setState(() => _isRunning = true);

    // ===== 步骤 1：触发求助 =====
    await _setStep(0, '正在发起求救...', '用户手动触发求助', 0.0);
    HapticFeedback.heavyImpact();
    if (!mounted) return;

    // ===== 步骤 2：5 秒倒计时 =====
    setState(() => _showCountdown = true);
    for (int i = 5; i > 0; i--) {
      if (!mounted) return;
      setState(() => _countdown = i);
      HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(seconds: 1));
    }
    setState(() => _showCountdown = false);
    if (!mounted) return;

    // ===== 步骤 3：获取位置 =====
    await _setStep(1, '正在获取位置信息...', 'GPS 定位中', 0.17);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    await _setStep(1, '✅ 位置已获取', _demoAddress, 0.25);
    await Future.delayed(const Duration(milliseconds: 800));

    // ===== 步骤 4：发送求救短信 =====
    await _setStep(2, '正在发送求救短信...', '通知 3 位紧急联系人', 0.35);
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    await _setStep(2, '✅ 求救短信已发送', '已通知：妈妈、爸爸、李医生', 0.5);
    await Future.delayed(const Duration(milliseconds: 800));

    // ===== 步骤 5：拨打 120 =====
    await _setStep(3, '正在拨打 120 急救电话...', '跳转到系统拨号界面', 0.6);
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    await _setStep(3, '✅ 120 拨号界面已打开', '用户可手动拨打急救电话', 0.75);
    await Future.delayed(const Duration(milliseconds: 800));

    // ===== 步骤 6：通知紧急联系人 =====
    await _setStep(4, '正在通知紧急联系人...', '向守护圈成员发送实时位置', 0.85);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    await _setStep(4, '✅ 所有联系人已通知', '妈妈正在赶来', 0.95);
    await Future.delayed(const Duration(milliseconds: 800));

    // ===== 完成 =====
    await _setStep(5, '🎉 演示完成', '', 1.0);
    if (!mounted) return;
    setState(() {
      _statusText = '以上为演示，未发送任何真实信息';
      _subText = '真实求助将自动联系您的紧急联系人并发送位置';
      _isRunning = false;
    });
  }

  Future<void> _setStep(int step, String status, String sub, double progress) async {
    if (!mounted) return;
    _fadeController.reset();
    setState(() {
      _currentStep = step;
      _stepCompleted[step] = true;
      _statusText = status;
      _subText = sub;
      _progress = progress;
    });
    await _fadeController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF8F9FF);
    final cardColor = isDark ? const Color(0xFF16213E) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final textSecondary = isDark ? Colors.white60 : Colors.grey[600]!;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部导航
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.close, color: textPrimary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '🎬 演示模式',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48), // 平衡
                ],
              ),
            ),

            // 进度条
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 4,
                  backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // 进度百分比
            Text(
              '${(_progress * 100).toInt()}%',
              style: TextStyle(fontSize: 11, color: textSecondary, fontWeight: FontWeight.w500),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    // ====== 倒计时或求助按钮动画 ======
                    if (_showCountdown)
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) => Transform.scale(
                            scale: 1.0 + (_pulseController.value * 0.1),
                            child: child,
                          ),
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red.shade50,
                              border: Border.all(color: Colors.red, width: 3),
                            ),
                            child: Center(
                              child: Text(
                                '$_countdown',
                                style: TextStyle(
                                  fontSize: 64,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    else if (_currentStep < 5)
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) => Transform.scale(
                            scale: 1.0 + (_pulseController.value * 0.05),
                            child: child,
                          ),
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: _currentStep >= 5
                                    ? [Colors.green.shade400, Colors.green.shade600]
                                    : [Colors.red.shade400, Colors.red.shade600],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (_currentStep >= 5 ? Colors.green : Colors.red).withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _currentStep >= 5 ? Icons.check_circle : Icons.emergency,
                                  size: 40,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _currentStep >= 5 ? '完成' : '求助',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // ====== 当前状态 ======
                    FadeTransition(
                      opacity: _fadeAnim,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(ZaiNeSpacing.section),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              _statusText,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _currentStep >= 5 ? Colors.green.shade700 : textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_subText.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                _subText,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _currentStep >= 5 ? Colors.green.shade600 : textSecondary,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ====== 步骤时间线 ======
                    _buildTimelineStep(
                      index: 0,
                      icon: Icons.touch_app,
                      label: '触发求助',
                      detail: '用户手动点击求助按钮发起求救',
                      color: Colors.red,
                      isActive: _currentStep == 0 && _isRunning,
                      isCompleted: _stepCompleted[0],
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      cardColor: cardColor,
                    ),
                    _buildTimelineConnector(0, textSecondary),
                    _buildTimelineStep(
                      index: 1,
                      icon: Icons.gps_fixed,
                      label: '获取位置',
                      detail: _stepCompleted[1] ? _demoAddress : 'GPS 定位中...',
                      color: Colors.teal,
                      isActive: _currentStep == 1 && _isRunning,
                      isCompleted: _stepCompleted[1],
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      cardColor: cardColor,
                    ),
                    _buildTimelineConnector(1, textSecondary),
                    _buildTimelineStep(
                      index: 2,
                      icon: Icons.message,
                      label: '发送求救短信',
                      detail: _stepCompleted[2] ? '已通知 3 位联系人' : '通知紧急联系人',
                      color: Colors.orange,
                      isActive: _currentStep == 2 && _isRunning,
                      isCompleted: _stepCompleted[2],
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      cardColor: cardColor,
                    ),
                    _buildTimelineConnector(2, textSecondary),
                    _buildTimelineStep(
                      index: 3,
                      icon: Icons.phone_in_talk,
                      label: '拨打 120',
                      detail: _stepCompleted[3] ? '已打开拨号界面' : '跳转到系统拨号界面',
                      color: Colors.blue,
                      isActive: _currentStep == 3 && _isRunning,
                      isCompleted: _stepCompleted[3],
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      cardColor: cardColor,
                    ),
                    _buildTimelineConnector(3, textSecondary),
                    _buildTimelineStep(
                      index: 4,
                      icon: Icons.group,
                      label: '通知守护圈',
                      detail: _stepCompleted[4] ? '所有成员已收到通知' : '向守护圈发送实时位置',
                      color: Colors.purple,
                      isActive: _currentStep == 4 && _isRunning,
                      isCompleted: _stepCompleted[4],
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      cardColor: cardColor,
                    ),

                    // ====== 演示提示 ======
                    if (_currentStep >= 5) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(ZaiNeSpacing.lg),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.verified_user, color: Colors.green.shade700, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  '以上为演示',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '演示过程中没有发送任何真实短信或拨打电话。\n真实求助会自动联系您的紧急联系人并获取您的精确位置。',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.green.shade800,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  '我已了解，返回求助页面',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineStep({
    required int index,
    required IconData icon,
    required String label,
    required String detail,
    required Color color,
    required bool isActive,
    required bool isCompleted,
    required Color textPrimary,
    required Color textSecondary,
    required Color cardColor,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isCompleted
            ? color.withValues(alpha: 0.08)
            : (isActive ? color.withValues(alpha: 0.06) : cardColor),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted
              ? color.withValues(alpha: 0.3)
              : (isActive ? color.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isCompleted
                  ? color
                  : (isActive ? color.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1)),
              shape: BoxShape.circle,
            ),
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Icon(icon, color: isCompleted ? Colors.white : (isActive ? color : Colors.grey), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? color : (isActive ? textPrimary : textSecondary),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 12,
                    color: isCompleted ? color.withValues(alpha: 0.8) : textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isActive && !_showCountdown)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineConnector(int stepIndex, Color color) {
    final isActive = _stepCompleted[stepIndex];
    return Padding(
      padding: const EdgeInsets.only(left: 31),
      child: Container(
        width: 2,
        height: 10,
        color: isActive ? Colors.green.shade400 : Colors.grey.shade300,
      ),
    );
  }
}
