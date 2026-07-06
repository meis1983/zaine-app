import 'package:flutter/material.dart';
import '../theme/theme_helper.dart';
import 'dart:math' as math;
import '../widgets/guardian_card_envelope.dart';

class PromotionalShowcasePage extends StatefulWidget {
  const PromotionalShowcasePage({super.key});

  @override
  State<PromotionalShowcasePage> createState() => _PromotionalShowcasePageState();
}

class _PromotionalShowcasePageState extends State<PromotionalShowcasePage> with TickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _stepController;

  @override
  void initState() {
    super.initState();
    _stepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _stepController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      setState(() => _currentStep = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 动态背景
          _buildAnimatedBackground(),
          
          // 步骤内容
          Center(
            child: _buildStepContent(),
          ),

          // 底部控制（录制时可隐藏）
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStepIndicator(0),
                const SizedBox(width: ZaiNeSpacing.md),
                _buildStepIndicator(1),
                const SizedBox(width: ZaiNeSpacing.md),
                _buildStepIndicator(2),
              ],
            ),
          ),
          
          // 浮动按钮切换
          Positioned(
            right: 20,
            bottom: 40,
            child: FloatingActionButton(
              onPressed: _nextStep,
              backgroundColor: Colors.white24,
              child: const Icon(Icons.play_arrow, color: Colors.white),
            ),
          ),
          
          Positioned(
            left: 20,
            top: 50,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white54),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: _currentStep == step ? Colors.white : Colors.white24,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          colors: [Color(0xFF1A1A1A), Colors.black],
          center: Alignment.center,
          radius: 1.5,
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildEnvelopeStep();
      case 1:
        return _buildHealthStep();
      case 2:
        return _buildGuardianStep();
      default:
        return const SizedBox.shrink();
    }
  }

  // 步骤 0: 3D 信封开启
  Widget _buildEnvelopeStep() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '跨越距离的温情传递',
          style: TextStyle(color: Colors.white, fontSize: ZaiNeFontSize.title, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
        SizedBox(height: ZaiNeSpacing.xxl),
        GuardianCardEnvelope(
          senderName: '梅先生',
          message: '见字如面，愿你平安喜乐。',
          appStoreUrl: '',
          recipientName: '亲爱的',
          totalGuardians: 12,
          cardCode: 'LOVE2026',
        ),
      ],
    );
  }

  // 步骤 1: 健康体征飞入
  Widget _buildHealthStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '全天候生命体征守护',
            style: TextStyle(color: Colors.white, fontSize: ZaiNeFontSize.title, fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
          const SizedBox(height: ZaiNeSpacing.md),
          const Text(
            '心率、血压、睡眠，一切尽在掌握',
            style: TextStyle(color: Colors.white70, fontSize: ZaiNeFontSize.bodySm),
          ),
          const SizedBox(height: ZaiNeSpacing.xxl),
          _buildHealthGrid(),
        ],
      ),
    );
  }

  Widget _buildHealthGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        _buildShowcaseMetric('心率', '72 bpm', Icons.favorite, Colors.red),
        _buildShowcaseMetric('血压', '120/80', Icons.speed, Colors.deepPurple),
        _buildShowcaseMetric('血氧', '98%', Icons.bloodtype, Colors.blue),
        _buildShowcaseMetric('HRV', '45 ms', Icons.bolt, Colors.amber),
      ],
    );
  }

  Widget _buildShowcaseMetric(String title, String value, IconData icon, Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      builder: (context, val, child) {
        return Transform.scale(
          scale: val,
          child: Opacity(
            opacity: val,
            child: Container(
              padding: const EdgeInsets.all(ZaiNeSpacing.lg),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(ZaiNeRadius.card),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(height: ZaiNeSpacing.sm),
                  Text(value, style: const TextStyle(color: Colors.white, fontSize: ZaiNeFontSize.title, fontWeight: FontWeight.bold)),
                  Text(title, style: const TextStyle(color: Colors.white70, fontSize: ZaiNeFontSize.caption)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 步骤 2: 守护圈
  Widget _buildGuardianStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          '你的专属安全网络',
          style: TextStyle(color: Colors.white, fontSize: ZaiNeFontSize.title, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
        const SizedBox(height: ZaiNeSpacing.xxl),
        _buildGuardianCircle(),
        const SizedBox(height: ZaiNeSpacing.xxl),
        const Text(
          '紧急时刻，自动通知所有守护者',
          style: TextStyle(color: Colors.white70, fontSize: ZaiNeFontSize.bodySm),
        ),
      ],
    );
  }

  Widget _buildGuardianCircle() {
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 呼吸光晕
          _buildPulseCircle(260, Colors.orange.withValues(alpha: 0.1)),
          _buildPulseCircle(200, Colors.orange.withValues(alpha: 0.2)),
          
          // 中心用户
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.orange, width: 3),
              image: const DecorationImage(
                image: NetworkImage('https://api.dicebear.com/7.x/avataaars/png?seed=Felix'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          
          // 周围守护者 (模拟 4 个)
          ...List.generate(4, (i) {
            final angle = (i * 90) * (math.pi / 180);
            return Transform.translate(
              offset: Offset(math.cos(angle) * 100, math.sin(angle) * 100),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white30, width: 2),
                  image: DecorationImage(
                    image: NetworkImage('https://api.dicebear.com/7.x/avataaars/png?seed=Guard$i'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPulseCircle(double size, Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: 1.2),
      duration: const Duration(seconds: 2),
      builder: (context, val, child) {
        return Container(
          width: size * val,
          height: size * val,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        );
      },
      onEnd: () {}, // 自动循环需要额外逻辑，这里简化
    );
  }
}
