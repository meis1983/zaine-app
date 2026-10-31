// lib/pages/redeem_card_page.dart
// 输入守护码兑换页面 — 守护码兜底绑定方案

import 'package:flutter/material.dart';
import '../theme/theme_helper.dart';
import '../config/app_config.dart';
import '../services/api/card_service.dart';
import '../services/api/sync_service.dart';
import 'scan_guardian_code_page.dart';
import '../l10n/i18n.dart';
import '../widgets/guardian_consent_dialog.dart';

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

  /// 【CN合规 177·P2】打开扫码页，扫描对方守护码后自动回填并走兑换流程
  Future<void> _scanCode() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScanGuardianCodePage()),
    );
    if (!mounted || result == null || result.isEmpty) return;
    _codeController.text = result;
    _redeem();
  }

  Future<void> _redeem() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _errorText = tr.s1010);
      return;
    }
    if (code.length < 4) {
      setState(() => _errorText = tr.s939);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      // 【CN合规】被添加方"单独同意"门禁（个保法第29条：敏感个人信息需单独同意）
      // 先查卡信息获取邀请人，展示独立同意弹窗；用户拒绝则不建立关系。
      // 全球版（kIsChinaBuild=false）跳过此门禁，沿用原流程。
      if (kIsChinaBuild) {
        final check = await CardService.checkCard(code);
        if (!mounted) return;
        if (check['success'] != true) {
          final message = check['message']?.toString() ?? tr.s1011;
          setState(() => _errorText = message);
          return;
        }
        final senderName = check['sender_name']?.toString() ?? 'TA';
        // 共享合规组件，与登录页渐进披露入口同一份实现
        final agreed = await showGuardianConsentDialog(context, senderName);
        if (!mounted) return;
        if (!agreed) {
          // 用户拒绝，不建立守护关系，不调用 redeemCard
          setState(() => _errorText = '您已拒绝，未建立守护关系');
          return;
        }
      }

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
        final message = res['message']?.toString() ?? tr.s1011;
        setState(() {
          _errorText = message;
        });
      }
    } catch (e) {
      setState(() {
        _errorText = tr.s387;
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.card)),
        contentPadding: const EdgeInsets.all(ZaiNeSpacing.xl),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: ZaiNeColors.brandOrange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: ZaiNeColors.brandOrange, size: 36),
            ),
            const SizedBox(height: ZaiNeSpacing.xl),
            Text(
              tr.s1012,
              style: TextStyle(
                fontSize: ZaiNeFontSize.subtitle,
                fontWeight: FontWeight.bold,
                color: ZaiNeColors.textPrimary(),
              ),
            ),
            const SizedBox(height: ZaiNeSpacing.md),
            Text(
              kIsChinaBuild
                  ? '$senderName 已成功成为您的守护者'
                  : tr.s1013(senderName),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: ZaiNeFontSize.bodySm,
                color: ZaiNeColors.textSecondary(),
                height: 1.5,
              ),
            ),
            const SizedBox(height: ZaiNeSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  // 【新增 v1.9.78】绑定成功后刷新联系人列表
                  // 后端 redeem 已建立守护关系（CN 为单向 A→B），需要拉取到本地
                  try {
                    await SyncService.pullFromServer();
                  } catch (_) {
                    // 静默失败，不影响用户体验
                  }
                  if (!context.mounted) return;
                  Navigator.of(ctx).pop();
                  if (mounted) Navigator.of(context).pop(); // 返回上一页
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZaiNeColors.brandOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.small)),
                  padding: const EdgeInsets.symmetric(vertical: ZaiNeSpacing.lg),
                ),
                child:  Text(tr.s087, style: TextStyle(fontSize: ZaiNeFontSize.body, fontWeight: FontWeight.w600)),
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
          tr.s205,
          style: TextStyle(color: ZaiNeColors.textPrimary(), fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(ZaiNeSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 说明文字
              Container(
                padding: const EdgeInsets.all(ZaiNeSpacing.lg),
                decoration: BoxDecoration(
                  color: ZaiNeColors.brandOrangeLight,
                  borderRadius: BorderRadius.circular(ZaiNeRadius.card),
                  border: Border.all(color: ZaiNeColors.brandOrange.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 20, color: ZaiNeColors.brandOrange),
                    const SizedBox(width: ZaiNeSpacing.md),
                    Expanded(
                      child: Text(
                        tr.s1014,
                        style: TextStyle(
                          fontSize: ZaiNeFontSize.caption,
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: ZaiNeSpacing.lg),

              // 【CN合规 177·P2】扫码建关系入口：扫描对方守护码，自动回填并兑换
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _scanCode,
                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                  label: const Text('扫描对方的守护码'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ZaiNeColors.brandOrange,
                    side: BorderSide(color: ZaiNeColors.brandOrange.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.card)),
                    padding: const EdgeInsets.symmetric(vertical: ZaiNeSpacing.lg),
                  ),
                ),
              ),
              const SizedBox(height: ZaiNeSpacing.xxl),

              // 输入框
              Text(
                tr.s1015,
                style: TextStyle(
                  fontSize: ZaiNeFontSize.bodySm,
                  fontWeight: FontWeight.w600,
                  color: ZaiNeColors.textPrimary(),
                ),
              ),
              const SizedBox(height: ZaiNeSpacing.md),
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                maxLength: 16,
                style: const TextStyle(
                  fontSize: ZaiNeFontSize.title,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                  fontFamily: 'Courier',
                ),
                decoration: InputDecoration(
                  hintText: tr.s1016,
                  hintStyle: TextStyle(
                    fontSize: ZaiNeFontSize.title,
                    color: ZaiNeColors.textHint(),
                    letterSpacing: 3,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ZaiNeRadius.card),
                    borderSide: BorderSide(color: ZaiNeColors.borderColor()),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ZaiNeRadius.card),
                    borderSide: BorderSide(color: ZaiNeColors.borderColor()),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ZaiNeRadius.card),
                    borderSide: const BorderSide(color: ZaiNeColors.brandOrange, width: 1.5),
                  ),
                  errorText: _errorText,
                  contentPadding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.xl, vertical: ZaiNeSpacing.lg),
                  counterText: '',
                ),
                onSubmitted: (_) => _redeem(),
              ),
              const SizedBox(height: ZaiNeSpacing.sm),
              Text(
                tr.s1017,
                style: TextStyle(fontSize: ZaiNeFontSize.caption, color: ZaiNeColors.textSecondary()),
              ),

              const Spacer(),

              // 确认按钮
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _redeem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ZaiNeColors.brandOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.card)),
                    elevation: 4,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      :  Text(
                          tr.s1018,
                          style: TextStyle(fontSize: ZaiNeFontSize.body, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: ZaiNeSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
