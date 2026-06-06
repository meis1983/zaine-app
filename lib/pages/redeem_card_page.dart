// lib/pages/redeem_card_page.dart
// 输入守护码兑换页面 — 安全码兜底绑定方案

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/theme_helper.dart';
import '../services/api/card_service.dart';
import '../services/api/sync_service.dart';

class RedeemCardPage extends StatefulWidget {
  const RedeemCardPage({super.key});

  @override
  State<RedeemCardPage> createState() => _RedeemCardPageState();
}

class _RedeemCardPageState extends State<RedeemCardPage> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _errorText = '请输入守护安全码');
      return;
    }
    if (code.length < 4) {
      setState(() => _errorText = '安全码至少4位');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final res = await CardService.redeemCard(cardCode: code);
      if (!mounted) return;

      if (res['success'] == true) {
        final senderName = res['sender_name']?.toString() ?? 'TA';

        // 【修改 v1.17.1】去掉信封动画，兑换成功后直接弹出确认框
        // 信封动画保留在 onboarding（落地页注册）和 home_page（DeepLink唤醒）两个场景
        try {
          await SyncService.pullFromServer();
        } catch (_) {
          // 静默失败，不影响用户体验
        }
        if (!mounted) return;

        // 直接弹出确认框
        _showSuccessDialog(senderName);
      } else {
        final message = res['message']?.toString() ?? '兑换失败';
        setState(() {
          _errorText = message;
        });
      }
    } catch (e) {
      setState(() {
        _errorText = '网络异常，请稍后重试';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(String senderName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFF7F50).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Color(0xFFFF7F50), size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              '守护关系已建立',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ZaiNeColors.textPrimary(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '你已成为 $senderName 的守护人\n你们可以互相守护彼此的安全',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: ZaiNeColors.textSecondary(),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  // 【新增 v1.9.78】绑定成功后刷新联系人列表
                  // 后端 redeem 已创建双向紧急联系人，需要拉取到本地
                  try {
                    await SyncService.pullFromServer();
                  } catch (_) {
                    // 静默失败，不影响用户体验
                  }
                  if (!context.mounted) return;
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop(); // 返回上一页
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7F50),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('知道了', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZaiNeColors.scaffoldBg(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: ZaiNeColors.textPrimary()),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '输入守护码',
          style: TextStyle(color: ZaiNeColors.textPrimary(), fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 说明文字
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5F0),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFF7F50).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: const Color(0xFFFF7F50)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '如果有人发给你守护卡，但你无法扫码或打开链接，可以在这里输入安全码完成绑定',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 输入框
              Text(
                '守护安全码',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: ZaiNeColors.textPrimary(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                maxLength: 16,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                  fontFamily: 'Courier',
                ),
                decoration: InputDecoration(
                  hintText: '例如: ABC123',
                  hintStyle: TextStyle(
                    fontSize: 20,
                    color: Colors.grey.shade400,
                    letterSpacing: 3,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFFF7F50), width: 1.5),
                  ),
                  errorText: _errorText,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  counterText: '',
                ),
                onSubmitted: (_) => _redeem(),
              ),
              const SizedBox(height: 8),
              Text(
                '安全码由发卡人提供，通常在守护卡卡片上显示',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),

              const Spacer(),

              // 确认按钮
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _redeem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7F50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 4,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          '确认绑定',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
