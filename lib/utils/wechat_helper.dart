import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

/// 复制邀请/关心文案并尝试打开微信。
///
/// 行为：
/// 1. 复制文案到剪贴板；
/// 2. 显示 SnackBar 提示「已复制，去微信粘贴发送」，并带「打开微信」按钮；
/// 3. 点击「打开微信」优先用 `weixin://` 拉起微信 App 主界面；
///    若微信未安装/无法拉起（canLaunchUrl 失败），自动降级到系统分享面板
///    （Share.share），用户可在面板中手动选择微信。
///
/// 用于「守护卡提醒TA」「我守护的人-重新邀请」等场景，保证跳转体验一致。
Future<void> copyAndOpenWeChat(BuildContext context, String message) async {
  await Clipboard.setData(ClipboardData(text: message));
  HapticFeedback.lightImpact();
  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: const Color(0xFF323232),
      content: const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '已复制，去微信粘贴发送 💬',
              style: TextStyle(fontSize: 14, color: Colors.white),
            ),
          ),
        ],
      ),
      action: SnackBarAction(
        label: '打开微信',
        textColor: const Color(0xFF667EEA),
        onPressed: () async {
          final wechat = Uri.parse('weixin://');
          if (await canLaunchUrl(wechat)) {
            await launchUrl(wechat, mode: LaunchMode.externalApplication);
          } else {
            // 微信拉不起，降级到系统分享面板，用户可手动选微信
            await Share.share(message, subject: '在呢');
          }
        },
      ),
    ),
  );
}

/// 「我守护的人」重新邀请 - 微信分享面板模式。
///
/// 完整文案(含链接)先复制到剪贴板；分享面板只发送**剥离裸 URL**的纯文本，
/// 规避 iOS 系统分享面板抓取 FC 落地页 URL 预览卡死
/// （*.fcapp.run 强制 Content-Disposition: attachment，预览抓取失败会一直转圈）。
/// 用户在微信里粘贴剪贴板中的完整链接即可。
Future<void> shareWeChatPanel(BuildContext context, String fullMessage) async {
  await Clipboard.setData(ClipboardData(text: fullMessage));
  HapticFeedback.lightImpact();
  if (!context.mounted) return;
  final stripped = fullMessage
      .replaceAll(RegExp(r'https?://\S+'), '')
      .replaceAll(RegExp(r'\n{2,}'), '\n')
      .trim();
  await Share.share(stripped, subject: '在呢');
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('已复制完整链接，去微信粘贴发送 💬'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
