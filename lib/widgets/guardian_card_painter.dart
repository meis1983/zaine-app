import 'dart:io';
import 'dart:math' show Random;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// 守护卡模板配置
class GuardianCardTemplate {
  final Color bgColor;
  final Color textColor;
  final Color accentColor;
  final String paperTexture;
  final String fontName;

  const GuardianCardTemplate({
    required this.bgColor,
    required this.textColor,
    required this.accentColor,
    required this.paperTexture,
    this.fontName = 'STKaiti',
  });

  static const List<GuardianCardTemplate> themes = [
    // 暖阳米 (默认)
    GuardianCardTemplate(
      bgColor: Color(0xFFFCFAF2),
      textColor: Color(0xFF444444),
      accentColor: Color(0xFF8B4513),
      paperTexture: 'https://www.transparenttextures.com/patterns/natural-paper.png',
    ),
    // 月光蓝 (宁静守护)
    GuardianCardTemplate(
      bgColor: Color(0xFFF0F4F8),
      textColor: Color(0xFF2C3E50),
      accentColor: Color(0xFF34495E),
      paperTexture: 'https://www.transparenttextures.com/patterns/pinstriped-suit.png',
    ),
    // 森林绿 (生机温情)
    GuardianCardTemplate(
      bgColor: Color(0xFFF2F5F0),
      textColor: Color(0xFF2F4F4F),
      accentColor: Color(0xFF556B2F),
      paperTexture: 'https://www.transparenttextures.com/patterns/sandpaper.png',
    ),
    // 晚霞粉 (柔和关怀)
    GuardianCardTemplate(
      bgColor: Color(0xFFF9F0F2),
      textColor: Color(0xFF5D4037),
      accentColor: Color(0xFF8D6E63),
      paperTexture: 'https://www.transparenttextures.com/patterns/handmade-paper.png',
    ),
  ];
}

class GuardianCardPainter {
  static Widget buildCard({
    required String senderName,
    String? senderAvatar,
    required String message,
    required String appStoreUrl,
    String? recipientName,
    int? totalGuardians,
    String? cardCode,
  }) {
    // 根据安全码的首字母或随机数决定模板，确保同一张卡模板固定
    final int themeIdx = (cardCode != null && cardCode.isNotEmpty) 
        ? cardCode.codeUnitAt(0) % GuardianCardTemplate.themes.length
        : Random().nextInt(GuardianCardTemplate.themes.length);
    
    return _GuardianCardWidget(
      senderName: senderName,
      senderAvatar: senderAvatar,
      message: message,
      appStoreUrl: appStoreUrl,
      recipientName: recipientName,
      totalGuardians: totalGuardians,
      cardCode: cardCode,
      template: GuardianCardTemplate.themes[themeIdx],
    );
  }
}

class _GuardianCardWidget extends StatefulWidget {
  final String senderName;
  final String? senderAvatar;
  final String message;
  final String appStoreUrl;
  final String? recipientName;
  final int? totalGuardians;
  final String? cardCode;
  final GuardianCardTemplate template;

  const _GuardianCardWidget({
    required this.senderName,
    this.senderAvatar,
    required this.message,
    required this.appStoreUrl,
    this.recipientName,
    this.totalGuardians,
    this.cardCode,
    required this.template,
  });

  @override
  State<_GuardianCardWidget> createState() => _GuardianCardWidgetState();
}

class _GuardianCardWidgetState extends State<_GuardianCardWidget> {
  ImageProvider _getAvatarImageProvider(String path) {
    if (path.startsWith('/') || path.startsWith('file://')) {
      return FileImage(File(path));
    }
    return NetworkImage(path);
  }

  Widget _buildAvatarFallback() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Text(
          widget.senderName.isNotEmpty ? widget.senderName[0] : '?',
          style: TextStyle(fontSize: 32, color: widget.template.accentColor.withOpacity(0.5), fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.template;
    return Container(
      width: 340,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.bgColor,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
        image: DecorationImage(
          image: NetworkImage(theme.paperTexture),
          repeat: ImageRepeat.repeat,
          opacity: 0.25,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '· 在呢 · 守护卡 ·',
            style: TextStyle(
              fontSize: 14,
              color: theme.accentColor,
              letterSpacing: 4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 32),

          // 发送者头像（复古相片）
          Transform.rotate(
            angle: 0.04,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(2, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 115,
                    height: 115,
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade100)),
                    child: widget.senderAvatar != null && widget.senderAvatar!.isNotEmpty
                        ? Image(
                            image: _getAvatarImageProvider(widget.senderAvatar!),
                            fit: BoxFit.cover,
                          )
                        : _buildAvatarFallback(),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.senderName,
                    style: TextStyle(fontSize: 13, color: theme.textColor.withOpacity(0.6), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),

          Text(
            widget.recipientName != null && widget.recipientName!.isNotEmpty
                ? '致 ${widget.recipientName}'
                : '见信如晤',
            style: TextStyle(
              fontSize: 24,
              color: theme.textColor,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 20),

          Text(
            '“${widget.message}”',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              color: theme.textColor.withOpacity(0.85),
              fontStyle: FontStyle.italic,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 24),

          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(
                data: widget.appStoreUrl.isNotEmpty ? widget.appStoreUrl : 'https://apps.apple.com/app/zaine/id6763441206',
                size: 96,
                eyeStyle: QrEyeStyle(color: theme.accentColor, eyeShape: QrEyeShape.square),
                dataModuleStyle: QrDataModuleStyle(color: theme.accentColor, dataModuleShape: QrDataModuleShape.square),
              ),
              const SizedBox(height: 10),
              Text(
                '扫一扫，开启守护',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.accentColor.withOpacity(0.9),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '在呢+ · 跨越距离的守护',
                style: TextStyle(fontSize: 12, color: theme.textColor.withOpacity(0.55)),
              ),
            ],
          ),

          const SizedBox(height: 18),

          if (widget.cardCode != null && widget.cardCode!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.65),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.accentColor.withOpacity(0.18)),
              ),
              child: Column(
                children: [
                  Text(
                    '24 小时内完成绑定',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: theme.accentColor.withOpacity(0.9),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '扫码下载在呢+ → 自动建立守护关系\n如扫码失败，再使用备用守护码绑定',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textColor.withOpacity(0.7),
                      height: 1.4,
                    ),
                  ),
                  if ((widget.totalGuardians ?? 0) > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      '已有 ${widget.totalGuardians} 人加入守护圈',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.textColor.withOpacity(0.55),
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ],
              ),
            ),

          if (widget.cardCode != null && widget.cardCode!.isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.45), width: 1.2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '备用守护码：',
                    style: TextStyle(fontSize: 12, color: theme.textColor.withOpacity(0.6)),
                  ),
                  Text(
                    widget.cardCode!.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD4AF37),
                      letterSpacing: 3,
                      fontFamily: 'Courier',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
