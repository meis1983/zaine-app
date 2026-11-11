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
import 'package:shared_preferences/shared_preferences.dart';

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

  // 【CN合规 177 + v1.98.2 方案A】配对码缓存：
  // - _cachedCode：会话内内存缓存（同一次 App 运行秒显、不闪烁）；
  // - 持久化到 SharedPreferences（按 user_id 隔离）：App 重启 / 重装后仍能秒显同一个码，
  //   不再回服务端新建卡片（旧逻辑因 status 比较写错，每次都新建 → 每次变码、还撞码）。
  static String? _cachedCode;

  @override
  void initState() {
    super.initState();
    _loadCode();
  }

  /// 取本地持久化缓存键（按账号隔离，切号不串码）
  static Future<String> _cacheKey() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('user_id');
    return (uid != null && uid.isNotEmpty) ? 'my_guardian_code_$uid' : 'my_guard_code';
  }

  Future<void> _persistCode(String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(await _cacheKey(), code);
    } catch (_) {}
  }

  // 【v1.98.2 方案A】优先复用稳定守护码，避免每次打开都新建卡片导致变码/撞码
  Future<void> _loadCode() async {
    // 1) 命中内存缓存：秒显（防闪烁），但仍需与服务器对账，确保显示的是当前有效码
    if (_cachedCode != null && _cachedCode!.isNotEmpty) {
      _code = _cachedCode;
      _loading = false;
      if (mounted) setState(() {});
      _syncFromServer();
      return;
    }
    // 2) 命中本地持久化缓存：App 重启后秒显、不闪烁、不变码
    try {
      final prefs = await SharedPreferences.getInstance();
      final localCode = prefs.getString(await _cacheKey());
      if (localCode != null && localCode.isNotEmpty) {
        _code = localCode;
        _cachedCode = localCode;
        _loading = false;
        if (mounted) setState(() {});
        // 后台静默向服务端核对（保证与 30 天稳定码一致），不一致则更新缓存
        _syncFromServer();
        return;
      }
    } catch (_) {}

    // 3) 本地无缓存 → 向服务端获取（服务端保证每用户一个稳定码）
    try {
      final res = await CardService.getMySecurityCode();
      if (res['success'] == true) {
        final code = (res['code'] ?? '').toString();
        if (code.isNotEmpty) {
          _code = code;
          _cachedCode = code;
          await _persistCode(code);
        } else {
          _error = tr.s1196;
        }
      } else {
        _error = tr.s1196;
      }
    } catch (_) {
      _error = tr.s1197;
    }
    if (mounted) {
      _loading = false;
      setState(() {});
    }
  }

  /// 【v1.98.2 修复C】本地缓存不再神圣：始终以服务器当前有效码为准。
  /// 拉到服务器码后与本地比对，不一致（本地为过期/失效旧码）则更新显示与缓存，
  /// 保证扫码与手输使用的是同一个服务器活码，消除"扫码成、手输败"的错位。
  Future<void> _syncFromServer() async {
    try {
      final res = await CardService.getMySecurityCode();
      if (res['success'] == true) {
        final serverCode = (res['code'] ?? '').toString();
        if (serverCode.isNotEmpty && serverCode != _code) {
          _code = serverCode;
          _cachedCode = serverCode;
          await _persistCode(serverCode);
          if (mounted) setState(() {});
        }
      }
      // 服务器码与本地一致则保持；服务器异常则保留本地缓存（仍可展示）
    } catch (_) {
      // 静默失败：本地缓存仍可用
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
        SnackBar(content: Text(tr.s1198), duration: Duration(seconds: 2)),
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
      if (mounted) _snack(tr.s1199, Colors.orange);
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
      appBar: AppBar(title: Text(tr.s1190)),
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
              child: Text(
                '${tr.s1202}\n\n${tr.s1203}',
                style: const TextStyle(fontSize: 14, height: 1.6),
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
                    child: Text(tr.s1200),
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
                label: Text(tr.s1201),
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
