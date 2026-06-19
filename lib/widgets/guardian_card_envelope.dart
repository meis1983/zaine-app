import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 触觉反馈
import 'guardian_card_painter.dart';
import '../utils/season_theme.dart';

/// 守护卡信封组件 — 提供 3D 翻盖开封动画效果
/// v4.1 季节配色 + 手写签名 + 开封粒子效果 + 触觉反馈
class GuardianCardEnvelope extends StatefulWidget {
  final String senderName;
  final String? senderAvatar;
  final String message;
  final String appStoreUrl;
  final String? recipientName;
  final int? totalGuardians;
  final String? cardCode;
  final VoidCallback? onComplete;
  final SeasonTheme? customTheme; // 自定义主题（可选）
  final bool isWelcomeMode; // 【修复 v1.17.1】是否为欢迎卡模式

  const GuardianCardEnvelope({
    super.key,
    required this.senderName,
    this.senderAvatar,
    required this.message,
    required this.appStoreUrl,
    this.recipientName,
    this.totalGuardians,
    this.cardCode,
    this.onComplete,
    this.customTheme,
    this.isWelcomeMode = false,
  });

  @override
  State<GuardianCardEnvelope> createState() => _GuardianCardEnvelopeState();
}

class _GuardianCardEnvelopeState extends State<GuardianCardEnvelope>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _flapAnimation;
  late Animation<double> _cardSlideAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _particleAnimation;

  bool _isOpened = false;
  List<_Particle> _particles = [];

  // 季节主题
  late SeasonTheme _theme;

  @override
  void initState() {
    super.initState();
    _theme = widget.customTheme ?? SeasonThemeManager.getCurrentTheme();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // 1. 翻盖动画 (0.0 - 0.35)
    _flapAnimation = Tween<double>(begin: 0.0, end: math.pi).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.easeInOut),
      ),
    );

    // 2. 卡片滑出动画 (0.35 - 0.85)
    _cardSlideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.85, curve: Curves.easeOutBack),
      ),
    );

    // 3. 整体淡入
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.15, curve: Curves.easeIn),
      ),
    );

    // 4. 粒子效果 (0.5 - 1.0)
    _particleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    // 生成粒子
    _generateParticles();

    // 监听动画更新粒子 + 触觉反馈
    _controller.addListener(() {
      if (_controller.value > 0.5 && _particles.isNotEmpty) {
        setState(() {});
      }
      // 触觉反馈：关键帧触发
      _handleHapticFeedback(_controller.value);
    });

    // 自动播放
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        _controller.forward().then((_) {
          setState(() => _isOpened = true);
          if (widget.onComplete != null) widget.onComplete!();
        });
      }
    });
  }

  void _generateParticles() {
    final random = math.Random();
    _particles = List.generate(20, (i) {
      return _Particle(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: 4 + random.nextDouble() * 8,
        speed: 0.5 + random.nextDouble() * 1.5,
        color: _theme.accentColor.withValues(alpha: 0.3 + random.nextDouble() * 0.4),
        type: random.nextBool() ? _ParticleType.circle : _ParticleType.star,
      );
    });
  }

  // 触觉反馈状态（避免重复触发）
  bool _hapticStartTriggered = false;
  bool _hapticFlapTriggered = false;
  bool _hapticCardTriggered = false;
  bool _hapticCompleteTriggered = false;

  /// 根据动画进度触发触觉反馈
  void _handleHapticFeedback(double value) {
    // 0.0 - 开始时轻触
    if (value > 0.05 && !_hapticStartTriggered) {
      _hapticStartTriggered = true;
      HapticFeedback.lightImpact();
    }
    // 0.2 - 翻盖开始翻动
    if (value > 0.2 && !_hapticFlapTriggered) {
      _hapticFlapTriggered = true;
      HapticFeedback.mediumImpact();
    }
    // 0.5 - 翻盖完全打开，卡片开始滑出
    if (value > 0.5 && !_hapticCardTriggered) {
      _hapticCardTriggered = true;
      HapticFeedback.heavyImpact();
    }
    // 0.9 - 动画接近完成
    if (value > 0.9 && !_hapticCompleteTriggered) {
      _hapticCompleteTriggered = true;
      HapticFeedback.selectionClick();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double cardWidth = 320.0;
    const double cardHeight = 460.0;
    const double envelopeWidth = cardWidth + 20;
    const double envelopeHeight = 240.0;

    return FadeTransition(
      opacity: _opacityAnimation,
      child: Center(
        child: SizedBox(
          width: envelopeWidth + 40,
          height: cardHeight + 120,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // 0. 粒子效果层
              if (_controller.value > 0.5)
                ..._buildParticles(envelopeWidth, cardHeight),

              // 1. 卡片 (在信封后面/里面)
              AnimatedBuilder(
                animation: _cardSlideAnimation,
                builder: (context, child) {
                  double slideValue = _cardSlideAnimation.value;
                  return Transform.translate(
                    offset: Offset(0, -slideValue * (cardHeight * 0.6)),
                    child: Transform.scale(
                      scale: 0.8 + (slideValue * 0.2),
                      child: child,
                    ),
                  );
                },
                child: GuardianCardPainter.buildCard(
                  senderName: widget.senderName,
                  senderAvatar: widget.senderAvatar,
                  message: widget.message,
                  appStoreUrl: widget.appStoreUrl,
                  recipientName: widget.recipientName,
                  totalGuardians: widget.totalGuardians,
                  cardCode: widget.cardCode,
                  isWelcomeMode: widget.isWelcomeMode,
                ),
              ),

              // 2. 信封背面
              Container(
                width: envelopeWidth,
                height: envelopeHeight,
                decoration: BoxDecoration(
                  color: _theme.envelopeColor,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _theme.primaryColor.withValues(alpha: 0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
              ),

              // 3. 信封正面 (左右斜边)
              CustomPaint(
                size: const Size(envelopeWidth, envelopeHeight),
                painter: EnvelopeFrontPainter(theme: _theme),
              ),

              // 4. 信封翻盖 (3D 旋转)
              AnimatedBuilder(
                animation: _flapAnimation,
                builder: (context, child) {
                  double angle = _flapAnimation.value;
                  return Transform(
                    alignment: Alignment.topCenter,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..translateByDouble(0.0, envelopeHeight - 240.0, 0.0, 1.0)
                      ..rotateX(angle),
                    child: CustomPaint(
                      size: const Size(envelopeWidth, 120),
                      painter: EnvelopeFlapPainter(
                        theme: _theme,
                        isBackside: angle > math.pi / 2,
                      ),
                    ),
                  );
                },
              ),

              // 5. 季节封印
              Positioned(
                top: envelopeHeight - 60,
                child: _buildSeasonSeal(),
              ),

              // 6. 发送者签名（信封背面）
              if (!_isOpened)
                Positioned(
                  bottom: 20,
                  child: _buildSignature(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建粒子效果
  List<Widget> _buildParticles(double width, double height) {
    final progress = _particleAnimation.value;
    return _particles.map((p) {
      final x = p.x * width + (p.x - 0.5) * progress * 100;
      final y = p.y * height - progress * p.speed * 150;
      final opacity = (1 - progress) * p.color.a;

      return Positioned(
        left: x,
        top: y,
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: p.type == _ParticleType.star
              ? Icon(Icons.star, size: p.size, color: p.color.withValues(alpha: 1))
              : Container(
                  width: p.size,
                  height: p.size,
                  decoration: BoxDecoration(
                    color: p.color.withValues(alpha: 1),
                    shape: BoxShape.circle,
                  ),
                ),
        ),
      );
    }).toList();
  }

  /// 季节封印
  Widget _buildSeasonSeal() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: _theme.sealColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _theme.sealColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          _theme.emoji,
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }

  /// 手写签名效果
  Widget _buildSignature() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _theme.accentColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 手写签名曲线
          CustomPaint(
            size: const Size(60, 24),
            painter: SignatureCurvePainter(color: _theme.accentColor),
          ),
          const SizedBox(width: 8),
          Text(
            widget.senderName,
            style: TextStyle(
              fontSize: 14,
              color: _theme.accentColor,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

/// 粒子数据类
class _Particle {
  final double x;
  final double y;
  final double size;
  final double speed;
  final Color color;
  final _ParticleType type;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.color,
    required this.type,
  });
}

enum _ParticleType { circle, star }

/// 信封正面绘制器 (U形口袋感)
class EnvelopeFrontPainter extends CustomPainter {
  final SeasonTheme theme;

  EnvelopeFrontPainter({required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = theme.envelopeFlapColor
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.5, size.height * 0.6)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);

    // 阴影线
    final strokePaint = Paint()
      ..color = theme.primaryColor.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant EnvelopeFrontPainter oldDelegate) =>
      oldDelegate.theme != theme;
}

/// 信封翻盖绘制器 (三角形)
class EnvelopeFlapPainter extends CustomPainter {
  final SeasonTheme theme;
  final bool isBackside;

  EnvelopeFlapPainter({required this.theme, required this.isBackside});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isBackside ? theme.primaryColor.withValues(alpha: 0.7) : theme.envelopeFlapColor
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width * 0.5, size.height)
      ..close();

    canvas.drawPath(path, paint);

    // 装饰线条
    if (!isBackside) {
      final linePaint = Paint()
        ..color = theme.accentColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      // 在盖子上画一个小爱心或印章感
      canvas.drawCircle(
        Offset(size.width * 0.5, size.height * 0.4),
        15,
        linePaint,
      );

      // 季节装饰线
      final decorPaint = Paint()
        ..color = theme.accentColor.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      canvas.drawLine(
        Offset(size.width * 0.3, size.height * 0.2),
        Offset(size.width * 0.7, size.height * 0.2),
        decorPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant EnvelopeFlapPainter oldDelegate) =>
      oldDelegate.isBackside != isBackside || oldDelegate.theme != theme;
}

/// 手写签名曲线绘制器
class SignatureCurvePainter extends CustomPainter {
  final Color color;

  SignatureCurvePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    // 绘制一条类似手写签名的曲线
    final path = Path();
    path.moveTo(0, size.height * 0.6);
    path.quadraticBezierTo(
      size.width * 0.2, size.height * 0.2,
      size.width * 0.4, size.height * 0.5,
    );
    path.quadraticBezierTo(
      size.width * 0.6, size.height * 0.8,
      size.width * 0.8, size.height * 0.4,
    );
    path.quadraticBezierTo(
      size.width * 0.9, size.height * 0.2,
      size.width, size.height * 0.5,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant SignatureCurvePainter oldDelegate) =>
      oldDelegate.color != color;
}
