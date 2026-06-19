import 'dart:io';
import 'dart:math' show Random;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../data/app_constants.dart';

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
    bool isWelcomeMode = false,
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
      isWelcomeMode: isWelcomeMode,
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
  final bool isWelcomeMode; // 【修复 v1.17.1】欢迎卡模式（收卡人登录后）
  final GuardianCardTemplate template;

  const _GuardianCardWidget({
    required this.senderName,
    this.senderAvatar,
    required this.message,
    required this.appStoreUrl,
    this.recipientName,
    this.totalGuardians,
    this.cardCode,
    this.isWelcomeMode = false,
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
          style: TextStyle(fontSize: 32, color: widget.template.accentColor.withValues(alpha: 0.5), fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.template;
    if (widget.isWelcomeMode) {
      return _buildWelcomeCard(theme);
    }
    return _buildInvitationCard(theme);
  }

  /// 邀请卡（面向尚未领取守护卡的人）
  Widget _buildInvitationCard(GuardianCardTemplate theme) {
    return Container(
      width: 340,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.bgColor,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
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
                    color: Colors.black.withValues(alpha: 0.1),
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
                    style: TextStyle(fontSize: 13, color: theme.textColor.withValues(alpha: 0.6), fontWeight: FontWeight.w500),
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
            '"${widget.message}"',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              color: theme.textColor.withValues(alpha: 0.85),
              fontStyle: FontStyle.italic,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 24),

          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(
                data: widget.appStoreUrl.isNotEmpty ? widget.appStoreUrl : AppConstants.welcomeUrl,
                size: 90,
                eyeStyle: QrEyeStyle(color: theme.accentColor, eyeShape: QrEyeShape.square),
                dataModuleStyle: QrDataModuleStyle(color: theme.accentColor, dataModuleShape: QrDataModuleShape.square),
              ),
              const SizedBox(height: 10),
              Text(
                '扫一扫，领取守护',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.accentColor.withValues(alpha: 0.9),
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '在呢+ · 收到一份温暖的牵挂',
                style: TextStyle(fontSize: 12, color: theme.textColor.withValues(alpha: 0.55)),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 安全码（醒目展示 — 扫码失败时的备用绑定方案）
          if (widget.cardCode != null && widget.cardCode!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.accentColor.withValues(alpha: 0.35), width: 1.2),
              ),
              child: Column(
                children: [
                  Text(
                    '守护安全码',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: theme.accentColor.withValues(alpha: 0.9),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '扫码失败？在 App 内输入此码绑定',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textColor.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                  if ((widget.totalGuardians ?? 0) > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      '已有 ${widget.totalGuardians} 人加入守护圈',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.textColor.withValues(alpha: 0.55),
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // 安全码大字展示（金色醒目）
          if (widget.cardCode != null && widget.cardCode!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.5), width: 1.2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '安全码 ',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textColor.withValues(alpha: 0.7)),
                  ),
                  Text(
                    widget.cardCode!.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD4AF37),
                      letterSpacing: 3.5,
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

  /// 欢迎卡（面向已经领取守护卡的收卡人 — 登录后展示）
  Widget _buildWelcomeCard(GuardianCardTemplate theme) {
    return Container(
      width: 340,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.bgColor,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
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
          // 顶部装饰线
          Container(
            width: 40,
            height: 2,
            decoration: BoxDecoration(
              color: theme.accentColor.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(height: 20),

          // 发送者头像（居中、适中大小、无旋转 — 修复遮挡问题）
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: theme.accentColor.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: theme.accentColor.withValues(alpha: 0.3), width: 2),
            ),
            child: ClipOval(
              child: widget.senderAvatar != null && widget.senderAvatar!.isNotEmpty
                  ? Image(
                      image: _getAvatarImageProvider(widget.senderAvatar!),
                      fit: BoxFit.cover,
                    )
                  : Center(
                      child: Text(
                        widget.senderName.isNotEmpty ? widget.senderName[0] : '?',
                        style: TextStyle(fontSize: 24, color: theme.accentColor, fontWeight: FontWeight.bold),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),

          Text(
            widget.senderName,
            style: TextStyle(
              fontSize: 14,
              color: theme.textColor.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),

          // 标题
          Text(
            '· 在呢 · 守护已建立 ·',
            style: TextStyle(
              fontSize: 14,
              color: theme.accentColor,
              letterSpacing: 4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),

          // 主标题
          Text(
            '守护关系已建立',
            style: TextStyle(
              fontSize: 24,
              color: theme.textColor,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),

          // 副标题
          Text(
            '${widget.senderName} 想守护你',
            style: TextStyle(
              fontSize: 16,
              color: theme.textColor.withValues(alpha: 0.7),
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 20),

          // 发送者的消息
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '"${widget.message}"',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: theme.textColor.withValues(alpha: 0.85),
                fontStyle: FontStyle.italic,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 温馨说明
          Text(
            '从今天起，你们将互相收到每日签到提醒',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: theme.textColor.withValues(alpha: 0.55),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '让在乎的人知道你很好 💌',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: theme.accentColor.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),

          // 底部装饰线
          Container(
            width: 40,
            height: 2,
            decoration: BoxDecoration(
              color: theme.accentColor.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}
