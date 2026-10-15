// lib/pages/my_guardian_code_page.dart
// 【CN 合规】"我的守护码" —— 守护关系建立的「发卡端」（轻量 1:1 配对码，非分享卡片）
//
// 与全球版 GuardianCardPage（精美可分享守护卡 + 落地页短链 + 裂变奖励）不同：
// 本页【不】生成可分享链接、【不】触发任何邀请奖励，
// 仅在 App 内出示配对码 / 二维码，由对方在「输入守护码」录入并单独同意后，
// 完成两个互相认识的人之间的私下配对。这是家庭配对 / 联系人配对的标准合规范式，
// 不属于"鼓励分享传播"的增长裂变。
//
// 【CN 179】升级为「海报」形态：
//   - 一张图里同时有二维码 + 守护码明文，保存到相册或发给微信好友，对方扫/抄都行；
//   - 二维码内容仍是**纯 6 位守护码**，不含任何 URL、不含落地页短链，
//     所以扫出来只是个字符串，不构成"分享传播/裂变"，也不触发外链跳转；
//   - 保存/分享都是**用户主动点按钮**才发生，App 不读取通讯录、不自动群发；
//   - 对方扫码后仍需走 RedeemCardPage 的「单独同意」弹窗才会建立关系。

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../services/api/card_service.dart';
import '../theme/theme_helper.dart';
import '../l10n/i18n.dart';

class MyGuardianCodePage extends StatefulWidget {
  const MyGuardianCodePage({super.key});

  @override
  State<MyGuardianCodePage> createState() => _MyGuardianCodePageState();
}

class _MyGuardianCodePageState extends State<MyGuardianCodePage> {
  String? _code;
  bool _loading = true;
  String? _error;

  // 海报截图用
  final GlobalKey _posterKey = GlobalKey();
  bool _busy = false;

  // 【CN合规 177】静态内存缓存：配对码一经生成即固化为本会话常量，
  // 后续每次进入本页直接命中缓存，不再查询服务端、不再新建卡片，
  // 保证「我的守护码」每次打开都展示同一个码（可复用），且进入即显示不闪烁。
  static String? _cachedCode;

  @override
  void initState() {
    super.initState();
    _loadCode();
  }

  // 优先复用已有未过期配对码，避免每次打开都新建卡片污染列表
  Future<void> _loadCode() async {
    // 命中内存缓存：直接展示，跳过一切网络请求
    if (_cachedCode != null && _cachedCode!.isNotEmpty) {
      _code = _cachedCode;
      _loading = false;
      if (mounted) setState(() {});
      return;
    }
    try {
      final list = await CardService.listMyCards();
      final cards = (list['cards'] as List?) ?? [];
      for (final c in cards) {
        final code = (c['card_code'] ?? '').toString();
        final status = (c['status'] ?? '').toString();
        if (code.isNotEmpty && (status == 'pending' || status == 'activated')) {
          _code = code;
          _cachedCode = code;
          break;
        }
      }
    } catch (_) {
      // 列表获取失败不阻断，继续尝试新建
    }
    if (_code == null || _code!.isEmpty) {
      try {
        final res = await CardService.sendCard(message: '想和你建立守护关系');
        _code = (res['card_code'] ?? '').toString();
        _cachedCode = _code;
      } catch (_) {
        _error = '生成守护码失败，请稍后重试';
      }
    }
    if (mounted) {
      _loading = false;
      setState(() {});
    }
  }

  /// 展示用码：后端生成的是小写，展示/二维码统一大写，与「输入守护码」页
  /// 的 toUpperCase() 保持一致（后端 DB 为 utf8mb4_unicode_ci，大小写不敏感）。
  String get _displayCode => (_code ?? '').toUpperCase();

  Future<void> _copy() async {
    if (_code == null) return;
    await Clipboard.setData(ClipboardData(text: _displayCode));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('守护码已复制'), duration: Duration(seconds: 2)),
      );
    }
  }

  /// 截取海报为 PNG 字节流
  Future<List<int>?> _capturePoster() async {
    try {
      final ctx = _posterKey.currentContext;
      if (ctx == null) return null;
      final boundary = ctx.findRenderObject();
      if (boundary == null || boundary is! RenderRepaintBoundary) return null;
      // 等一帧，确保布局/字体已稳定
      await Future.delayed(const Duration(milliseconds: 80));
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      return byteData.buffer.asUint8List();
    } catch (e) {
      debugPrint('[MyGuardianCode] 截图失败: $e');
      return null;
    }
  }

  Future<void> _savePoster() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _capturePoster();
      if (!mounted) return;
      if (bytes == null) {
        _snack(tr.s596, Colors.red);
        return;
      }
      final result = await ImageGallerySaver.saveImage(
        Uint8List.fromList(bytes),
        quality: 100,
        name: 'zaine_guardian_code',
      );
      if (!mounted) return;
      final ok = result != null && result['isSuccess'] == true;
      _snack(ok ? tr.s705 : tr.s706, ok ? Colors.green : Colors.red);
    } catch (e) {
      if (mounted) _snack(tr.s706, Colors.red);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sharePoster() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _capturePoster();
      if (!mounted) return;
      if (bytes == null) {
        _snack(tr.s596, Colors.red);
        return;
      }
      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/zaine_guardian_code_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], subject: tr.s1190);
    } catch (e) {
      if (mounted) _snack('分享失败，请重试', Colors.orange);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的守护码')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ZaiNeColors.brandOrangeLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '将此守护码出示给您想守护的亲友。对方在 App 内「输入守护码」录入并确认后，即与您建立守护关系。\n\n'
                '建立后，仅在对方主动发起求助时，您可获取其当时的位置；您可随时在守护人列表中解除关系。',
                style: TextStyle(fontSize: 14, height: 1.6),
              ),
            ),
            const SizedBox(height: 24),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              )
            else if (_error != null)
              Column(
                children: [
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _loading = true;
                        _error = null;
                      });
                      _loadCode();
                    },
                    child: const Text('重试'),
                  ),
                ],
              )
            else ...[
              _buildPoster(),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _savePoster,
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: Text(tr.s775),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ZaiNeColors.brandOrange,
                        side: BorderSide(
                            color: ZaiNeColors.brandOrange.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : _sharePoster,
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: Text(tr.s1189),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ZaiNeColors.brandOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _copy,
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('复制守护码'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 海报本体：二维码 + 守护码明文，一图两用（可扫 / 可抄）
  Widget _buildPoster() {
    return RepaintBoundary(
      key: _posterKey,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF8A5C), Color(0xFFFF6B6B)],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 【CN 180】品牌头：换成 App Store listing 上的手捧心图标，强化品牌一致性
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/guardian_logo.png',
                  width: 88,
                  height: 88,
                  fit: BoxFit.contain,
                  // 兜底：万一资源加载失败，回退到原来的几何符号
                  errorBuilder: (ctx, err, st) => Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.favorite_rounded,
                        size: 36, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '在呢',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '让在乎的人，知道你很好',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.9),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 22),
            // 白色内卡：二维码 + 码
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  QrImageView(
                    data: _displayCode,
                    size: 176,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tr.s1190,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _displayCode,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                      fontFamily: 'monospace',
                      color: Color(0xFF2B2B2B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              tr.s1191,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Colors.white.withValues(alpha: 0.95),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
