import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/theme_helper.dart';
import '../services/social/guardian_message_service.dart';
import '../l10n/i18n.dart';
import '../config/app_config.dart';
import '../utils/emergency_call.dart';

/// 求助演示模式 — 让用户无需真出事就能体验完整求助流程
///
/// 设计原则：
/// - 30秒沉浸式演示，模拟真实求助触发全过程
/// - 纯本地动画（不需要后端）
/// - 结束后明确标注"以上为演示"，避免混淆
/// - 底部进度条让用户知道进度
class HelpDemoMode extends StatefulWidget {
  HelpDemoMode({super.key});

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
  String _statusText = tr.z0465;
  String _subText = '';
  bool _isRunning = false;
  double _progress = 0.0;

  // 倒计时
  int _countdown = 5;
  bool _showCountdown = false;

  // 模拟数据
  final String _demoAddress = tr.z0466;

  // 步骤完成状态
  final List<bool> _stepCompleted = [false, false, false, false, false, false];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);

    // 自动开始演示
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(Duration(milliseconds: 500), _startDemo);
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
    await _setStep(0, tr.z0467, tr.z0468, 0.0);
    HapticFeedback.heavyImpact();
    if (!mounted) return;

    // ===== 步骤 2：5 秒倒计时 =====
    setState(() => _showCountdown = true);
    for (int i = 5; i > 0; i--) {
      if (!mounted) return;
      setState(() => _countdown = i);
      HapticFeedback.mediumImpact();
      await Future.delayed(Duration(seconds: 1));
    }
    setState(() => _showCountdown = false);
    if (!mounted) return;

    // ===== 步骤 3：获取位置 =====
    await _setStep(1, tr.z0469, tr.z0470, 0.17);
    await Future.delayed(Duration(seconds: 2));
    if (!mounted) return;
    await _setStep(1, tr.z0471, _demoAddress, 0.25);
    await Future.delayed(Duration(milliseconds: 800));

    // ===== 步骤 4：发送求救短信 =====
    await _setStep(2, tr.z0472, tr.z0473, 0.35);
    HapticFeedback.heavyImpact();
    await Future.delayed(Duration(seconds: 2));
    if (!mounted) return;
    await _setStep(2, tr.z0474, tr.z0475, 0.5);
    await Future.delayed(Duration(milliseconds: 800));

    // ===== 步骤 5：拨打当地急救号码 =====
    final emergencyNum = EmergencyCall.localEmergencyNumber();
    await _setStep(3, tr.z0476(emergencyNum), tr.z0021, 0.6);
    HapticFeedback.heavyImpact();
    await Future.delayed(Duration(seconds: 2));
    if (!mounted) return;
    await _setStep(3, tr.z0477(emergencyNum), tr.z0478, 0.75);
    await Future.delayed(Duration(milliseconds: 800));

    // ===== 步骤 6：通知紧急联系人 =====
    // 【CN 合规】演示文案去掉"实时/守护圈"等监控暗示，改为一次性"当前位置"。
    await _setStep(4, tr.z0479,
        kIsChinaBuild ? '向紧急联系人发送当前位置' : tr.z0480, 0.85);
    await Future.delayed(Duration(seconds: 1));
    if (!mounted) return;
    await _setStep(4, tr.z0481, tr.z0482, 0.95);
    await Future.delayed(Duration(milliseconds: 800));

    // ===== 完成 =====
    await _setStep(5, tr.z0483, '', 1.0);
    if (!mounted) return;
    setState(() {
      _statusText = tr.z0484;
      _subText = tr.z0485;
      _isRunning = false;
    });

    // 🔴【v1.97.3 (162) 修复 Bug #1】演示完成 → 解锁「未雨绸缪」成就
    // 异步 fire-and-forget，失败也不影响演示 UI
    unawaited(_unlockEmergencyTestedAchievement());
  }

  /// 演示完成时主动写入 emergency_tested 成就（之前 SOS 测试入口未实装 → 0/1 永远不解锁）
  Future<void> _unlockEmergencyTestedAchievement() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('user_id') ?? '';
      if (uid.isEmpty) return;
      await SocialService().updateAchievementProgress(uid, 'emergency_tested', 1);
      if (kDebugMode) debugPrint('[HelpDemo] ✅ emergency_tested 已解锁（uid=$uid）');
    } catch (e) {
      if (kDebugMode) debugPrint('[HelpDemo] 解锁 emergency_tested 失败(忽略): $e');
    }
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
    final bgColor = isDark ? Color(0xFF1A1A2E) : Color(0xFFF8F9FF);
    final cardColor = isDark ? Color(0xFF16213E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Color(0xFF1A1A2E);
    final textSecondary = isDark ? Colors.white60 : Colors.grey[600]!;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部导航
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.close, color: textPrimary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tr.z0486,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange),
                    ),
                  ),
                  Spacer(),
                  SizedBox(width: 48), // 平衡
                ],
              ),
            ),

            // 进度条
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 4,
                  backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                ),
              ),
            ),

            SizedBox(height: 8),

            // 进度百分比
            Text(
              '${(_progress * 100).toInt()}%',
              style: TextStyle(fontSize: 11, color: textSecondary, fontWeight: FontWeight.w500),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    // ====== 倒计时或求助按钮动画 ======
                    if (_showCountdown)
                      Container(
                        margin: EdgeInsets.only(bottom: 24),
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
                        margin: EdgeInsets.only(bottom: 24),
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
                                  offset: Offset(0, 10),
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
                                SizedBox(height: 4),
                                Text(
                                  _currentStep >= 5 ? tr.z0487 : tr.z0005,
                                  style: TextStyle(
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
                        padding: EdgeInsets.all(ZaiNeSpacing.section),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                              blurRadius: 12,
                              offset: Offset(0, 4),
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
                              SizedBox(height: 8),
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

                    SizedBox(height: 20),

                    // ====== 步骤时间线 ======
                    _buildTimelineStep(
                      index: 0,
                      icon: Icons.touch_app,
                      label: tr.z0488,
                      detail: tr.z0489,
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
                      label: tr.z0490,
                      detail: _stepCompleted[1] ? _demoAddress : tr.z0491,
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
                      label: tr.z0492,
                      detail: _stepCompleted[2] ? tr.z0493 : tr.z0494,
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
                      label: tr.z0495(EmergencyCall.localEmergencyNumber()),
                      detail: _stepCompleted[3] ? tr.z0496 : tr.z0021,
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
                      label: tr.z0497,
                      // 【CN 合规】去掉"实时/守护圈"监控暗示，改为一次性"当前位置"。
                      detail: _stepCompleted[4]
                          ? tr.z0498
                          : (kIsChinaBuild
                              ? '向紧急联系人发送当前位置'
                              : tr.z0499),
                      color: Colors.purple,
                      isActive: _currentStep == 4 && _isRunning,
                      isCompleted: _stepCompleted[4],
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      cardColor: cardColor,
                    ),

                    // ====== 演示提示 ======
                    if (_currentStep >= 5) ...[
                      SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(ZaiNeSpacing.lg),
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
                                SizedBox(width: 8),
                                Text(
                                  tr.z0500,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              tr.z0501,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.green.shade800,
                                height: 1.5,
                              ),
                            ),
                            SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  tr.z0502,
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    SizedBox(height: 32),
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
      duration: Duration(milliseconds: 300),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                ? Icon(Icons.check, color: Colors.white, size: 20)
                : Icon(icon, color: isCompleted ? Colors.white : (isActive ? color : Colors.grey), size: 18),
          ),
          SizedBox(width: 12),
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
                SizedBox(height: 2),
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
      padding: EdgeInsets.only(left: 31),
      child: Container(
        width: 2,
        height: 10,
        color: isActive ? Colors.green.shade400 : Colors.grey.shade300,
      ),
    );
  }
}
