// lib/pages/scan_guardian_code_page.dart
// 【CN合规 177·P2】扫码建立守护关系
//
// 扫描对方在「我的守护码」页出示的配对码 / 二维码，解析出 6-8 位字母数字守护码后，
// 回填 redeem 流程（与手动输入走完全相同的 CardService.redeemCard 逻辑，仅入口不同）。
// 不依赖全球版「守护卡裂变落地页」短链，纯本地扫码，符合 CN 私下配对合规范式。

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';

class ScanGuardianCodePage extends StatefulWidget {
  const ScanGuardianCodePage({super.key});

  @override
  State<ScanGuardianCodePage> createState() => _ScanGuardianCodePageState();
}

class _ScanGuardianCodePageState extends State<ScanGuardianCodePage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  // 守护码白名单：6-8 位字母数字（与后端 _generate_unique_card_code 对齐）
  static final RegExp _codeRe = RegExp(r'^[a-zA-Z0-9]{6,8}$');

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final raw = barcodes.first.rawValue?.trim().toUpperCase();
    if (raw == null || raw.isEmpty) return;

    final candidate = _extractCode(raw);
    if (candidate == null) return;

    _handled = true;
    _controller.stop();
    if (mounted) Navigator.of(context).pop(candidate);
  }

  /// 从扫码结果中提取守护码：
  ///  - 纯码（如 ABC123）直接命中；
  ///  - 若二维码编码了完整 URL（如 https://zaine.love/.../ABC123 或 landing/ABC123），
  ///    逐段回退匹配最后一段符合白名单的路径。
  String? _extractCode(String raw) {
    final trimmed = raw.trim();
    if (_codeRe.hasMatch(trimmed)) return trimmed;
    final segments = trimmed.split(RegExp(r'[/\\]'));
    for (final seg in segments.reversed) {
      final s = seg.trim();
      if (_codeRe.hasMatch(s)) return s;
    }
    return null;
  }

  // 【CN 178·P2】从相册选取截图，识别其中守护码二维码
  Future<void> _pickFromAlbum() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    if (_handled) return;
    final capture = await _controller.analyzeImage(picked.path);
    final candidate = _extractFromCapture(capture);
    if (candidate == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未能从图片中识别守护码，请手动输入或重新选择')),
        );
      }
      return;
    }
    _handled = true;
    _controller.stop();
    if (mounted) Navigator.of(context).pop(candidate);
  }

  // 从相机/相册识别结果中提取守护码（与 _onDetect 共用 _extractCode）
  String? _extractFromCapture(BarcodeCapture? capture) {
    if (capture == null || capture.barcodes.isEmpty) return null;
    final raw = capture.barcodes.first.rawValue?.trim().toUpperCase();
    if (raw == null || raw.isEmpty) return null;
    return _extractCode(raw);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫描守护码'),
        centerTitle: true,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // 取景框
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.orange, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            bottom: 48,
            left: 24,
            right: 24,
            child: Text(
              '将对方出示的守护码 / 二维码置于框内',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14, shadows: [
                Shadow(color: Colors.black54, blurRadius: 4),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _handled ? null : _pickFromAlbum,
        icon: const Icon(Icons.photo_library),
        label: const Text('从相册选取'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}
