import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:image/image.dart' as img;
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/theme_helper.dart';
import '../utils/badge_generator.dart';
import '../utils/share_card_generator.dart';
import '../data/app_constants.dart';

/// 签到里程碑弹窗 — v1.3（精美徽章 + 渐变背景保存到相册 + 二维码）
class CheckinMilestoneDialog extends StatefulWidget {
  final int continuousDays;
  final int totalDays;
  final int moodIndex;
  final String userName;
  final bool isReturnCheckin;
  /// 断签天数（仅当 isReturnCheckin=true 时使用）
  final int absentDays;

  const CheckinMilestoneDialog({
    super.key,
    required this.continuousDays,
    this.totalDays = 0,
    required this.moodIndex,
    required this.userName,
    this.isReturnCheckin = false,
    this.absentDays = 0,
  });

  @override
  State<CheckinMilestoneDialog> createState() => _CheckinMilestoneDialogState();
}

class _CheckinMilestoneDialogState extends State<CheckinMilestoneDialog>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late AnimationController _badgePulseController;
  final GlobalKey _badgeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _badgePulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _badgePulseController.dispose();
    super.dispose();
  }

  // ========== 分享动作 ==========

  /// 保存图片到相册
  /// 【修复 v1.9.62】Canvas GPU 裁切圆角 + 饱和度增强 + CPU边缘采样圆角 + JPEG 编码
  /// 三阶段圆角处理：①GPU画布填白色底(消透明) ②clipRRect裁切 ③CPU逐像素采样边缘色填四角
  Future<void> _saveBadgeImage() async {
    try {
      final boundary = _badgeKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        _showError('图片生成失败');
        return;
      }

      // 1. 以 4x 像素比捕获原始渲染（矩形，四角透明）
      final image = await boundary.toImage(pixelRatio: 4.0);
      const cornerRadius = 28.0 * 4.0; // UI borderRadius × pixelRatio

      // 2. GPU 加速：画布填白底 + clipRRect 裁切 → 消除透明但仍有直角边
      final roundedImage = await _clipRoundedCorners(image, cornerRadius);

      // 3. 转 PNG → 解码 → CPU 逐像素采样边缘色填充四角（让四角自然过渡）
      final byteData = await roundedImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        _showError('图片生成失败');
        return;
      }
      var src = img.decodeImage(byteData.buffer.asUint8List());
      if (src == null) {
        _showError('图片解码失败');
        return;
      }

      // CPU 阶段：用边缘最近颜色填充四角外侧像素（关键！解决直角问题）
      _fillRoundedCorners(src, cornerRadius);

      // 4. 饱和度增强 1.25x → JPEG 编码
      final adjusted = img.adjustColor(src, saturation: 1.25);
      final jpegBytes = Uint8List.fromList(img.encodeJpg(adjusted, quality: 100));

      // 5. 保存到相册
      final result = await ImageGallerySaver.saveImage(jpegBytes,
          name: 'zaine_badge_${widget.continuousDays}d', quality: 100);

      if (result['isSuccess'] == true) {
        if (mounted) {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 18),
                  SizedBox(width: ZaiNeSpacing.sm),
                  Text('徽章图片已保存到相册'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        _showError('保存失败');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Save image error: $e');
      _showError('保存失败：$e');
    }
  }

  /// Canvas GPU 加速裁切圆角 —— 填充白色底 + clipRRect
  /// 阶段①：消除四角透明像素（阶段②CPU会做精细边缘采样）
  static Future<ui.Image> _clipRoundedCorners(ui.Image image, double radius) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final size = Size(image.width.toDouble(), image.height.toDouble());

    // ① 填充整个画布为白色（消除所有透明区域）
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFFFFFFF),
    );

    // ② 裁切 + 绘制原图
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    canvas.clipRRect(rrect);
    canvas.drawImage(image, Offset.zero, Paint());

    final picture = recorder.endRecording();
    return picture.toImage(image.width, image.height);
  }

  /// 在图片级用边界颜色填充四角，模拟圆角效果
  /// 将四角超出 radius 圆的像素替换为圆边界上最近的像素颜色
  void _fillRoundedCorners(img.Image image, double radius) {
    final r = radius.round();
    final w = image.width;
    final h = image.height;
    if (r <= 0) return;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        num cx = 0, cy = 0; // 圆角圆心
        bool inCorner = false;

        if (x < r && y < r) {
          cx = r;
          cy = r;
          inCorner = true;
        } else if (x >= w - r && y < r) {
          cx = w - r;
          cy = r;
          inCorner = true;
        } else if (x < r && y >= h - r) {
          cx = r;
          cy = h - r;
          inCorner = true;
        } else if (x >= w - r && y >= h - r) {
          cx = w - r;
          cy = h - r;
          inCorner = true;
        }

        if (inCorner) {
          final dx = x - cx;
          final dy = y - cy;
          final dist = dx * dx + dy * dy;
          if (dist > r * r) {
            // 在圆外，采样圆边界上最近点的颜色
            final scale = r / sqrt(dist);
            final bx = (cx + dx * scale).round();
            final by = (cy + dy * scale).round();
            final srcColor = image.getPixel(bx.clamp(0, w - 1), by.clamp(0, h - 1));
            image.setPixelRgba(x, y, srcColor.r, srcColor.g, srcColor.b, srcColor.a);
          }
        }
      }
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final badge = BadgeGenerator.generate(widget.continuousDays,
        isReturnCheckin: widget.isReturnCheckin,
        absentDays: widget.absentDays);
    final gradient = ShareCardGenerator.getGradientByDays(widget.continuousDays);

    // 【修复 v1.9.9】计算安全最大高度，防止小屏设备 BOTTOM OVERFLOWED
    final screenHeight = MediaQuery.of(context).size.height;
    final maxDialogHeight = screenHeight * 0.88; // 最多占屏幕88%

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.xl, vertical: ZaiNeSpacing.lg),
      child: FadeTransition(
        opacity: _fadeAnim,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxDialogHeight),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 50),
                    decoration: BoxDecoration(
                      color: ZaiNeColors.cardBg(),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: badge.badgeColor.withValues(alpha: 0.2),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 6)),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ====== 徽章主体（RepaintBoundary 用于截图保存） ======
                        // 【v1.3】将渐变头部也包入 RepaintBoundary，保存到相册的图片更精美
                        RepaintBoundary(
                          key: _badgeKey,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  gradient.colors.first,
                                  gradient.colors.first.withValues(alpha: 0.06),
                                  ZaiNeColors.cardBg(),
                                ],
                                stops: const [0.0, 0.35, 0.45],
                              ),
                              borderRadius: BorderRadius.circular(28),
                            
                              boxShadow: ZaiNeShadows.card,),
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                            child: Stack(
                              children: [
                                // 背景图案（每日不同）
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(28),
                                    child: CustomPaint(
                                      painter: BadgeGenerator.bgPainter(
                                        badge.bgStyle, badge.badgeColor,
                                        badge.bgOpacity, badge.particleCount,
                                      ),
                                    ),
                                  ),
                                ),
                                Column(
                                  children: [
                                    // ====== 渐变头部文字 ======
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Column(
                                    children: [
                                      Text(badge.emoji, style: const TextStyle(fontSize: 30)),
                                      const SizedBox(height: ZaiNeSpacing.xs),
                                      const Text(
                                        '签到成功 ✓',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: ZaiNeSpacing.xs),
                                      Text(
                                        badge.title,
                                        style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9)),
                                      ),
                      // 【P3】等级描述 — 统一使用 BadgeGenerator.getLevel
                      if (!badge.isMilestone && !badge.isFestival && !badge.isReturnCheckin && !badge.isSolarTerm) ...[
                        const SizedBox(height: ZaiNeSpacing.xs),
                        Text(
                          BadgeGenerator.getLevel(widget.continuousDays).desc,
                          style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7)),
                        ),
                      ],
                                    ],
                                  ),
                                ),
                                // 徽章圆形图标（悬浮效果）
                                Transform.translate(
                                  offset: const Offset(0, -10),
                                  child: AnimatedBuilder(
                                    animation: _badgePulseController,
                                    builder: (context, child) {
                                      final glow = 1.0 + (_badgePulseController.value * 0.08);
                                      return Transform.scale(scale: glow, child: child!);
                                    },
                                    child: Stack(
                                      children: [
                                        Container(
                                          width: 72,
                                          height: 72,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(colors: [
                                              badge.badgeColor.withValues(alpha: 0.15),
                                              badge.badgeColor.withValues(alpha: 0.05),
                                            ]),
                                            border: Border.all(
                                              color: badge.badgeColor.withValues(alpha: 0.3),
                                              width: 2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: badge.badgeColor.withValues(alpha: 0.15),
                                                blurRadius: 20,
                                                spreadRadius: 4,
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text('${widget.continuousDays}', style: TextStyle(
                                                  fontSize: 26, fontWeight: FontWeight.w900,
                                                  color: badge.badgeColor,
                                                )),
                                                Text('天', style: TextStyle(
                                                  fontSize: 11, fontWeight: FontWeight.w600,
                                                  color: badge.badgeColor.withValues(alpha: 0.7),
                                                )),
                                              ],
                                            ),
                                          ),
                                        ),
                                        // 圆环纹样（每日不同）
                                        Positioned.fill(
                                          child: IgnorePointer(
                                            child: CustomPaint(
                                              painter: _RingStylePainter(
                                                badge.ringStyle, badge.badgeColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: ZaiNeSpacing.sm),

                                // 副标题
                                Text(
                                  '你已连续守护自己 ${widget.continuousDays} 天',
                                  style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.w500),
                                ),

                                const SizedBox(height: ZaiNeSpacing.xs),

                                Text(
                                  widget.userName.isEmpty ? '在呢用户' : widget.userName,
                                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                ),

                                // 装饰元素 + 每日文案
                                const SizedBox(height: ZaiNeSpacing.xs),
                                if (badge.message.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.md),
                                    child: Text(
                                      '${BadgeGenerator.decoChars[badge.decoType]} ${badge.message}',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: badge.badgeColor.withValues(alpha: 0.7),
                                        fontWeight: FontWeight.w500,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),

                                const SizedBox(height: ZaiNeSpacing.md),

                                // ====== 二维码/邀请卡片区 ======
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.grey.shade50.withValues(alpha: 0.5), Colors.grey.shade100.withValues(alpha: 0.3)],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: ZaiNeColors.borderColor()),
                                  
                                    boxShadow: ZaiNeShadows.card,),
                                  child: Row(
                                    children: [
                                      // iOS 显示真二维码，Android 显示敬请期待
                                      if (Platform.isIOS)
                                        Container(
                                          padding: const EdgeInsets.all(5),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: badge.badgeColor.withValues(alpha: 0.2)),
                                            boxShadow: [
                                              BoxShadow(
                                                color: badge.badgeColor.withValues(alpha: 0.08),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: QrImageView(
                                            data: AppConstants.checkinMilestoneUrl,
                                            version: QrVersions.auto,
                                            size: 58,
                                            backgroundColor: Colors.white,
                                            eyeStyle: QrEyeStyle(
                                              eyeShape: QrEyeShape.square,
                                              color: badge.badgeColor,
                                            ),
                                            dataModuleStyle: QrDataModuleStyle(
                                              dataModuleShape: QrDataModuleShape.square,
                                              color: Colors.grey.shade800,
                                            ),
                                          ),
                                        )
                                      else
                                        Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade50,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: Colors.orange.shade200),
                                          
                                            boxShadow: ZaiNeShadows.card,),
                                          child: Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.android, size: 22, color: Colors.orange.shade400),
                                                const SizedBox(height: ZaiNeSpacing.xs),
                                                Text('敬请', style: TextStyle(fontSize: 8, color: Colors.orange.shade600, fontWeight: FontWeight.w600)),
                                                Text('期待', style: TextStyle(fontSize: 8, color: Colors.orange.shade600, fontWeight: FontWeight.w600)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      const SizedBox(width: ZaiNeSpacing.md),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('扫码下载「在呢」', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[800])),
                                            const SizedBox(height: ZaiNeSpacing.xs),
                                            Text(
                                              Platform.isIOS
                                                  ? '独居安全守护 App\n让在乎的人知道你很好'
                                                  : 'Android 版本即将上线\n敬请期待',
                                              style: TextStyle(fontSize: 11, color: Colors.grey[500], height: 1.3),
                                            ),
                                            const SizedBox(height: ZaiNeSpacing.xs),
                                            Row(
                                              children: [
                                                Icon(Icons.people_outline, size: 12, color: Colors.orange.shade600),
                                                const SizedBox(width: ZaiNeSpacing.xs),
                                                Text('已守护 ${widget.continuousDays} 天', style: TextStyle(fontSize: 10, color: Colors.orange.shade700, fontWeight: FontWeight.w600)),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: ZaiNeSpacing.lg),

                                // ====== 操作按钮（仅关闭 + 保存徽章） ======
                                IntrinsicHeight(
                                  child: Row(
                                    children: [
                                      // 关闭
                                      Expanded(
                                        flex: 1,
                                        child: GestureDetector(
                                          onTap: () => Navigator.of(context).pop(),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: ZaiNeSpacing.lg),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(14),
                                            
                                              boxShadow: ZaiNeShadows.card,),
                                            child: const Text('关闭', textAlign: TextAlign.center,
                                              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 14)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: ZaiNeSpacing.sm),
                                      // 保存徽章
                                      Expanded(
                                        flex: 1,
                                        child: GestureDetector(
                                          onTap: () async {
                                            // 【修复 v1.18】黑屏问题：先保存 Navigator 引用，异步操作后检查 mounted
                                            final navigator = Navigator.of(context);
                                            await _saveBadgeImage();
                                            if (mounted) navigator.pop();
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: ZaiNeSpacing.lg),
                                            decoration: BoxDecoration(
                                              color: Colors.teal.shade50,
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(color: Colors.teal.shade200),
                                            
                                              boxShadow: ZaiNeShadows.card,),
                                            child: Center(
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.download_rounded, color: Colors.teal.shade600, size: 17),
                                                  const SizedBox(width: ZaiNeSpacing.xs),
                                                  Text('保存徽章', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.teal.shade700, fontSize: 14)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],   // Column children (inner content)
                            ),     // Column (inside Stack)
                          ],       // Stack children
                        ),         // Stack
                      ),             // Container (decoration)
                    ),               // RepaintBoundary
                      ],
                    ),
                  ),

                  // 浮动的徽章图标（顶部）
                  Positioned(
                    top: 8,
                    child: AnimatedBuilder(
                      animation: _badgePulseController,
                      builder: (context, child) {
                        final glow = 1.0 + (_badgePulseController.value * 0.1);
                        return Transform.scale(scale: glow, child: child!);
                      },
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [
                            (badge.badgeColor),
                            badge.badgeColor.withValues(alpha: 0.7),
                          ]),
                          boxShadow: [
                            BoxShadow(
                              color: badge.badgeColor.withValues(alpha: 0.4),
                              blurRadius: 20,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(badge.emoji, style: const TextStyle(fontSize: 28)),
                              Text('${widget.continuousDays}天', style: const TextStyle(
                                fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white70,
                              )),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 右上角关闭
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)],
                        ),
                        child: const Icon(Icons.close, size: 16, color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 圆环风格画家（7种纹样）
class _RingStylePainter extends CustomPainter {
  final int style; // 0-6
  final Color color;
  _RingStylePainter(this.style, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2, r = size.shortestSide / 2 - 1;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color.withValues(alpha: 0.4);

    switch (style) {
      case 0: // 实线 — 已有Border.all，不画额外
        break;
      case 1: // 虚线
        paint.strokeWidth = 1.5;
        final path = Path();
        for (double a = 0; a < 2 * pi; a += 0.15) {
          if ((a / 0.15).round() % 2 == 0) {
            path.addArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), a, 0.1);
          }
        }
        canvas.drawPath(path, paint);
        break;
      case 2: // 双圈
        paint.strokeWidth = 1;
        canvas.drawCircle(Offset(cx, cy), r - 3, paint);
        canvas.drawCircle(Offset(cx, cy), r + 1, paint..color = color.withValues(alpha: 0.2));
        break;
      case 3: // 点阵
        paint.strokeWidth = 2;
        for (double a = 0; a < 2 * pi; a += 0.25) {
          final px = cx + cos(a) * r;
          final py = cy + sin(a) * r;
          canvas.drawCircle(Offset(px, py), 1.2, paint);
        }
        break;
      case 4: // 锯齿
        paint.strokeWidth = 1.2;
        final path2 = Path();
        for (double a = 0; a < 2 * pi; a += 0.08) {
          final ri = r + sin(a * 12) * 3;
          final px = cx + cos(a) * ri;
          final py = cy + sin(a) * ri;
          if (a == 0) {
            path2.moveTo(px, py);
          } else {
            path2.lineTo(px, py);
          }
        }
        path2.close();
        canvas.drawPath(path2, paint);
        break;
      case 5: // 花边
        paint.strokeWidth = 1;
        final path3 = Path();
        for (double a = 0; a < 2 * pi; a += 0.04) {
          final ri = r + sin(a * 8) * 2;
          final px = cx + cos(a) * ri;
          final py = cy + sin(a) * ri;
          if (a == 0) {
            path3.moveTo(px, py);
          } else {
            path3.lineTo(px, py);
          }
        }
        path3.close();
        canvas.drawPath(path3, paint);
        break;
      case 6: // 编织
        paint.strokeWidth = 1.2;
        final path4 = Path();
        for (double a = 0; a < 2 * pi * 3; a += 0.04) {
          final w = a / 3;
          final ri = r + sin(w * 6) * 1.5;
          final px = cx + cos(w) * ri;
          final py = cy + sin(w) * ri;
          if (a == 0) {
            path4.moveTo(px, py);
          } else {
            path4.lineTo(px, py);
          }
        }
        canvas.drawPath(path4, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) =>
      (oldDelegate as _RingStylePainter).style != style;
}
