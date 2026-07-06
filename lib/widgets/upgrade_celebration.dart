// lib/widgets/upgrade_celebration.dart
// 升级成功庆祝动画组件 —— 紫色+金色纸屑飘落 + 成功卡片

import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/theme_helper.dart';

/// 展示升级成功的庆祝动画
/// 调用方式：UpgradeCelebration.show(context);
class UpgradeCelebration extends StatefulWidget {
  const UpgradeCelebration({super.key});

  /// 便捷展示方法
  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (_) => const UpgradeCelebration(),
    );
  }

  @override
  State<UpgradeCelebration> createState() => _UpgradeCelebrationState();
}

class _UpgradeCelebrationState extends State<UpgradeCelebration>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _scaleIn;

  // 纸屑粒子
  final List<ConfettiParticle> _particles = [];

  @override
  void initState() {
    super.initState();

    // 生成纸屑粒子
    final rng = Random();
    for (int i = 0; i < 60; i++) {
      _particles.add(ConfettiParticle(
        x: rng.nextDouble(),
        delay: rng.nextDouble() * 0.8,
        speed: 0.3 + rng.nextDouble() * 0.5,
        size: 4 + rng.nextDouble() * 6,
        color: rng.nextBool()
            ? const Color(0xFF667EEA) // 紫色
            : const Color(0xFFFFD700), // 金色
        rotation: rng.nextDouble() * pi * 2,
        rotationSpeed: 1 + rng.nextDouble() * 3,
      ));
    }

    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _fadeIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.3, curve: Curves.easeOut),
    );

    _scaleIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.1, 0.4, curve: Curves.elasticOut),
    );

    _controller.forward();

    // 2.8 秒后自动关闭
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // 禁止用户手动关闭
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            children: [
              // 纸屑层
              ...List.generate(_particles.length, (i) {
                final p = _particles[i];
                // 计算纸屑位置：从屏幕顶部 ≈ 0 到屏幕底部 ≈ 1.2
                final progress =
                    ((_controller.value - p.delay) / (1 - p.delay))
                        .clamp(0.0, 1.0);
                final y = -0.1 + progress * p.speed * 1.3;
                final x = p.x + sin(progress * pi * 4) * 0.05;
                final opacity = progress < 0.1
                    ? progress / 0.1
                    : (1 - progress) / 0.9;
                final rotation = p.rotation + progress * p.rotationSpeed;

                return Positioned(
                  left: x * MediaQuery.of(context).size.width,
                  top: y * MediaQuery.of(context).size.height + 30,
                  child: Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
                    child: Transform.rotate(
                      angle: rotation,
                      child: Container(
                        width: p.size,
                        height: p.size * 1.5,
                        decoration: BoxDecoration(
                          color: p.color,
                          borderRadius: BorderRadius.circular(ZaiNeRadius.tiny),
                        
                          boxShadow: ZaiNeShadows.card,),
                      ),
                    ),
                  ),
                );
              }),

              // 中心卡片
              Center(
                child: FadeTransition(
                  opacity: _fadeIn,
                  child: ScaleTransition(
                    scale: _scaleIn,
                    child: _buildSuccessCard(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSuccessCard() {
    return Container(
      width: 240,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ZaiNeRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: const Color(0xFF667EEA).withValues(alpha: 0.15),
            blurRadius: 60,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 大图标
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            
              boxShadow: ZaiNeShadows.card,),
            child: const Center(
              child: Icon(Icons.auto_awesome, color: Colors.white, size: 32),
            ),
          ),
          const SizedBox(height: ZaiNeSpacing.xl),
          const Text(
            '🎉',
            style: TextStyle(fontSize: 28),
          ),
          const SizedBox(height: ZaiNeSpacing.md),
          const Text(
            '智能版已激活！',
            style: TextStyle(
              fontSize: ZaiNeFontSize.title,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: ZaiNeSpacing.md),
          Text(
            '现在可同时通知3位守护人',
            style: TextStyle(
              fontSize: ZaiNeFontSize.body,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

/// 纸屑粒子数据模型
class ConfettiParticle {
  final double x;
  final double delay;
  final double speed;
  final double size;
  final Color color;
  final double rotation;
  final double rotationSpeed;

  const ConfettiParticle({
    required this.x,
    required this.delay,
    required this.speed,
    required this.size,
    required this.color,
    required this.rotation,
    required this.rotationSpeed,
  });
}
