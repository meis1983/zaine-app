// lib/pages/subscription_page.dart
// 订阅管理页面 — 智能版购买/续费/状态展示（StoreKit 2 真实 IAP）
// 视觉升级 v3：守护温度 × 品牌质感 — 不只是支付，是爱的承诺

import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/theme_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../services/membership_service.dart';
import '../services/api/subscription_service.dart';
import '../services/iap_service.dart';
import '../data/app_constants.dart';
import '../widgets/upgrade_celebration.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage>
    with TickerProviderStateMixin {
  final IapService _iapService = IapService();
  bool _isLoading = true;
  bool _isPurchasing = false;

  // 订阅状态
  String _membershipLevel = 'free';
  String? _expiresAt;

  // IAP 状态
  bool _iapAvailable = false;
  List<ProductDetails> _products = [];
  String _selectedPlan = 'yearly'; // 默认选中年度（锚点策略）

  // 错误信息
  String? _errorMessage;

  // 交易监听
  StreamSubscription<PurchaseResult>? _purchaseSubscription;

  // 动画
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -3.0, end: 3.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );
    _initIap();
    _loadSubscriptionStatus();
  }

  @override
  void dispose() {
    // 【修复 v1.84.0】dispose 时取消监听，防止重复订阅
    _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
    _pulseController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _initIap({bool forceReload = false}) async {
    await _iapService.init();
    _purchaseSubscription ??= _iapService.purchaseResultStream.listen(_onPurchaseResult);
    final available = await _iapService.isAvailable();
    setState(() => _iapAvailable = available);

    if (available) {
      final products = forceReload
          ? await _iapService.reloadProducts()
          : await _iapService.loadProducts();
      setState(() => _products = products);
    }

    if (kDebugMode) debugPrint('[IAP] 可用=$available, 产品数=${_products.length}');
  }

  Future<void> _loadSubscriptionStatus() async {
    setState(() => _isLoading = true);
    _errorMessage = null;

    final result = await SubscriptionService.getStatus();

    if (result['success'] == true) {
      setState(() {
        _membershipLevel = result['membership_level'] ?? 'free';
        _expiresAt = result['expires_at'];
      });
      await MembershipService.syncFromLoginResponse(result);
    } else {
      setState(() {
        _membershipLevel = MembershipService.getLevel();
        _errorMessage = result['error']?.toString();
      });
    }

    setState(() => _isLoading = false);
  }

  /// 发起购买
  Future<void> _purchaseSmart() async {
    if (kDebugMode) debugPrint('[IAP] 购买流程开始，_products长度=${_products.length}');
    setState(() { _isPurchasing = true; _errorMessage = null; });

    // 【v1.13.0】产品未加载时自动刷新一次
    if (_products.isEmpty) {
      if (kDebugMode) debugPrint('[IAP] 产品未加载，自动刷新...');
      await _initIap(forceReload: true);
      if (_products.isEmpty) {
        if (mounted) {
          setState(() {
            _isPurchasing = false;
            _errorMessage = '订阅产品尚未就绪，请稍后再试';
          });
          // 用 SnackBar 让错误更明显
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⏰ 订阅产品正在准备中\nApple 审核通过后需 2-24 小时生效'),
                duration: Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
        if (kDebugMode) debugPrint('[IAP] 刷新后产品仍为空，中止购买');
        return;
      }
    }

    if (!_iapAvailable) {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
          _errorMessage = 'App Store 购买服务不可用，请稍后再试';
        });
      }
      return;
    }

    final productId = _selectedPlan == 'monthly'
        ? IapService.productIdMonthly
        : IapService.productIdYearly;

    // 显式查找产品，失败时给出明确错误
    final matching = _products.where((p) => p.id == productId).toList();
    final product = matching.isNotEmpty ? matching.first : null;
    if (product == null) {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
          _errorMessage = '未找到订阅产品（$productId），请稍后重试或联系客服';
        });
      }
      if (kDebugMode) debugPrint('[IAP] 未找到产品: $productId，可用产品: ${_products.map((p) => p.id).toList()}');
      return;
    }

    if (kDebugMode) debugPrint('[IAP] 发起购买: ${product.id}, 价格: ${product.price}');
    final error = await _iapService.purchaseProduct(product);
    if (error != null) {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
          _errorMessage = error;
        });
        // 【修复 v1.85.0】网络错误时显示重试按钮 SnackBar
        if (context.mounted && error.contains('网络')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.white, size: 20),
                  SizedBox(width: ZaiNeSpacing.md),
                  Expanded(child: Text('购买失败：网络不稳定，请检查后重试\n（沙盒测试建议关闭 VPN）')),
                ],
              ),
              duration: const Duration(seconds: 6),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: '重试',
                textColor: ZaiNeColors.brandOrange,
                onPressed: () {
                  // 清除错误状态，让用户可以再次点击
                  setState(() {
                    _errorMessage = '';
                    _isPurchasing = false;
                  });
                },
              ),
            ),
          );
        } else if (context.mounted) {
          // 非网络错误的普通提示
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ $error'),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
      if (kDebugMode) debugPrint('[IAP] 购买发起失败: $error');
    }
  }

  /// 处理购买结果
  Future<void> _onPurchaseResult(PurchaseResult result) async {
    if (!mounted) return;

    if (result.success) {
      try {
        final verifyResult = await SubscriptionService.verifyReceipt(
          transactionId: result.transactionId ?? '',
          originalTransactionId: result.originalTransactionId ?? '',
          productId: result.productId,
          purchaseDateMs: result.purchaseDateMs,
        );

        if (verifyResult['success'] == true) {
          // ✅ 验证成功 → 先标记交易完成（防止异常中断导致交易卡死）
          IapService().completePurchase(result.purchaseDetails);
          // 再更新本地状态
          await MembershipService.syncFromLoginResponse(verifyResult);
          await _loadSubscriptionStatus();
          if (mounted) {
            setState(() => _isPurchasing = false);  // ✅ 停止 loading
            UpgradeCelebration.show(context);            // ✅ 弹庆祝
          }
        } else {
          // ⚠️ 验证失败 → 给机会让用户手动重试
          setState(() {
            _errorMessage = verifyResult['detail']?.toString() ?? '验证失败，请重启App重试';
            _isPurchasing = false;
          });
          // 不调 completePurchase，让交易保留（重启后 StoreKit 会自动重试）
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ 支付验证失败\n请重启App自动重试，或联系客服'),
                duration: Duration(seconds: 5),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } catch (e) {
        setState(() {
          _errorMessage = '验证失败：$e';
          _isPurchasing = false;
        });
        // ⚠️ 异常 → 不调 completePurchase，让交易保留
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ 网络异常，请重启App自动重试'),
              duration: Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } else {
      setState(() {
        _errorMessage = result.error ?? '购买已取消';
        _isPurchasing = false;
      });
    }
  }

  /// 恢复购买
  Future<void> _restorePurchase() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await _iapService.restorePurchases();
    final result = await SubscriptionService.restorePurchase();

    if (result['success'] == true) {
      await MembershipService.syncFromLoginResponse(result);
      await _loadSubscriptionStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('购买记录已恢复'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error']?.toString() ?? '未找到可恢复的购买记录'),
            backgroundColor: ZaiNeColors.brandOrangeSwatch,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('yyyy年M月d日').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmart = _membershipLevel == 'smart';

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F5), // 温暖的米白色
      appBar: AppBar(
        title: const Text(
          '在呢守护',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFFFDF8F5),
        foregroundColor: const Color(0xFF2D2D3A),
      ),
      body: SafeArea(
        bottom: true,
        child: _isLoading
            ? _buildSkeletonLoading()
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.xl, vertical: ZaiNeSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeroBanner(isSmart),
                    const SizedBox(height: ZaiNeSpacing.xl),
                    if (!isSmart) ...[
                      _buildEmotionalQuote(),
                      const SizedBox(height: ZaiNeSpacing.xl),
                    ],
                    _buildValueProposition(),
                    const SizedBox(height: ZaiNeSpacing.xl),
                    _buildComparisonCard(),
                    const SizedBox(height: ZaiNeSpacing.xl),
                    if (isSmart)
                      _buildActiveInfoCard()
                    else
                      _buildPurchaseCard(),
                    const SizedBox(height: ZaiNeSpacing.xl),
                    if (isSmart) _buildManageSubscriptionCard(),
                    const SizedBox(height: ZaiNeSpacing.xl),
                    _buildTrustPromise(),
                    const SizedBox(height: ZaiNeSpacing.xl),
                    _buildRestoreButton(),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: ZaiNeSpacing.md),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: ZaiNeFontSize.caption,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: ZaiNeSpacing.xxl),
                  ],
                ),
              ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  骨架屏 Loading
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSkeletonLoading() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.xl, vertical: ZaiNeSpacing.sm),
      child: Column(
        children: [
          _skeletonContainer(height: 180, radius: 28),
          const SizedBox(height: ZaiNeSpacing.xl),
          _skeletonContainer(height: 80, radius: 20),
          const SizedBox(height: ZaiNeSpacing.xl),
          _skeletonContainer(height: 280, radius: 20),
          const SizedBox(height: ZaiNeSpacing.xl),
          _skeletonContainer(height: 200, radius: 20),
        ],
      ),
    );
  }

  Widget _skeletonContainer({required double height, required double radius}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  顶部 Hero Banner — 温暖守护之光
  // ═══════════════════════════════════════════════════════════════
  Widget _buildHeroBanner(bool isSmart) {
    return AnimatedBuilder(
      animation: _floatAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnimation.value),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
            decoration: BoxDecoration(
              gradient: isSmart
                  ? const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF6366F1), Color(0xFF3B82F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFFFF8A65), Color(0xFFFF7043), Color(0xFFFF5722)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(ZaiNeRadius.card),
              boxShadow: [
                BoxShadow(
                  color: isSmart
                      ? const Color(0xFF6366F1).withValues(alpha: 0.3)
                      : const Color(0xFFFF7043).withValues(alpha: 0.3),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              children: [
                // 守护图标
                Container(
                  padding: const EdgeInsets.all(ZaiNeSpacing.cardSm),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(ZaiNeRadius.card),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    isSmart ? Icons.favorite_rounded : Icons.shield_moon_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: ZaiNeSpacing.lg),
                Text(
                  isSmart ? '你的守护圈，已被点亮' : '点亮你的守护圈',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: ZaiNeFontSize.title,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(color: Color(0x40FF5722), blurRadius: 8, offset: Offset(0, 2)),
                    ],
                  ),
                ),
                const SizedBox(height: ZaiNeSpacing.sm),
                Text(
                  isSmart
                      ? '那些在乎你的人，此刻更安心了'
                      : '让在乎你的人，时刻知道你在',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: ZaiNeFontSize.bodySm,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    shadows: [
                      Shadow(color: Color(0x60FF5722), blurRadius: 6, offset: Offset(0, 1)),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                if (isSmart && _expiresAt != null) ...[
                  const SizedBox(height: ZaiNeSpacing.lg),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.lg, vertical: ZaiNeSpacing.sm),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(ZaiNeRadius.card),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '守护有效期至 ${_formatDate(_expiresAt)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: ZaiNeFontSize.caption,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                if (!isSmart) ...[
                  const SizedBox(height: ZaiNeSpacing.xl),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildValuePill(Icons.call, '快捷拨打3人'),
                      _buildValuePill(Icons.sms_rounded, '快捷短信3人'),
                      _buildValuePill(Icons.people_rounded, '10位守护人'),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildValuePill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.lg, vertical: ZaiNeSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: ZaiNeSpacing.sm),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: ZaiNeFontSize.caption,
              fontWeight: FontWeight.w700,
              shadows: [
                Shadow(color: Color(0x60FF5722), blurRadius: 4, offset: Offset(0, 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  情感引言 — 为什么守护很重要
  // ═══════════════════════════════════════════════════════════════
  Widget _buildEmotionalQuote() {
    return Container(
      padding: const EdgeInsets.all(ZaiNeSpacing.section),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F2),
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        border: Border.all(
          color: const Color(0xFFFFE0D6),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.format_quote_rounded, size: 16, color: ZaiNeColors.brandOrangeSwatch[300]),
              const SizedBox(width: ZaiNeSpacing.md),
              Text(
                '一句"我在呢"，胜过千言万语',
                style: TextStyle(
                  fontSize: ZaiNeFontSize.body,
                  fontWeight: FontWeight.w600,
                  color: ZaiNeColors.brandOrangeSwatch[800],
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: ZaiNeSpacing.md),
              Icon(Icons.format_quote_rounded, size: 16, color: ZaiNeColors.brandOrangeSwatch[300]),
            ],
          ),
          const SizedBox(height: ZaiNeSpacing.md),
          Text(
            '父母深夜等你报平安，爱人担心你独自出行，孩子希望你早点回家。'
            '在呢，不只是App，是你和在乎的人之间，一条永远在线的守护线。',
            style: TextStyle(
              fontSize: ZaiNeFontSize.caption,
              color: ZaiNeColors.brandOrangeSwatch[700]?.withValues(alpha: 0.8),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  价值主张（守护场景化）
  // ═══════════════════════════════════════════════════════════════
  Widget _buildValueProposition() {
    final items = [
      _PropItem(
        icon: Icons.health_and_safety_rounded,
        color: const Color(0xFFFF6B6B),
        title: '紧急时刻，快捷通知3位联系人',
        subtitle: '一键求助，快捷拨打并短信通知前3位联系人，分秒必争',
      ),
      _PropItem(
        icon: Icons.family_restroom_rounded,
        color: const Color(0xFF8B5CF6),
        title: '最多10位守护人，全家都放心',
        subtitle: '父母、伴侣、挚友……每个重要的人，都不会被遗漏',
      ),
      _PropItem(
        icon: Icons.card_giftcard_rounded,
        color: const Color(0xFFFF8A65),
        title: '守护卡，把关心传递给更多人',
        subtitle: '初始3张守护卡，邀请亲友加入你的守护圈，让爱流动',
      ),
    ];

    return Column(
      children: items.map((item) {
        return Container(
          margin: const EdgeInsets.only(bottom: ZaiNeSpacing.cardXs),
          padding: const EdgeInsets.all(ZaiNeSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ZaiNeRadius.card),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              const SizedBox(width: ZaiNeSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: ZaiNeFontSize.body,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D2D3A),
                      ),
                    ),
                    const SizedBox(height: ZaiNeSpacing.xs),
                    Text(
                      item.subtitle,
                      style: TextStyle(
                        fontSize: ZaiNeFontSize.caption,
                        color: Colors.grey[500],
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  版本对比卡片
  // ═══════════════════════════════════════════════════════════════
  Widget _buildComparisonCard() {
    return Container(
      padding: const EdgeInsets.all(ZaiNeSpacing.section),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7043),
                  borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                ),
              ),
              const SizedBox(width: ZaiNeSpacing.sm),
              const Text(
                '守护力对比',
                style: TextStyle(
                  fontSize: ZaiNeFontSize.subtitle,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D2D3A),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZaiNeSpacing.lg),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  '守护能力',
                  style: TextStyle(
                    fontSize: ZaiNeFontSize.caption,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[400],
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '体验版',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: ZaiNeFontSize.caption,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[400],
                  ),
                ),
              ),
              const Expanded(
                child: Text(
                  '智能版',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: ZaiNeFontSize.caption,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF7043),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZaiNeSpacing.md),
          Container(height: 1, color: const Color(0xFFF0F0F5)),
          const SizedBox(height: ZaiNeSpacing.lg),
          _buildComparisonRow('紧急联系人上限', '5位', '10位', highlightSmart: true),
          const Divider(height: 22, color: Color(0xFFF5F5F7)),
          _buildComparisonRow('紧急快捷拨打', '1位', '3位', highlightSmart: true),
          const Divider(height: 22, color: Color(0xFFF5F5F7)),
          _buildComparisonRow('紧急快捷短信', '1位', '3位', highlightSmart: true),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(
    String label,
    String freeValue,
    String smartValue, {
    required bool highlightSmart,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: ZaiNeFontSize.bodySm,
              color: Color(0xFF555567),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            freeValue,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: ZaiNeFontSize.bodySm,
              color: Colors.grey[500],
            ),
          ),
        ),
        Expanded(
          child: highlightSmart
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFFFF7043),
                      size: 16,
                    ),
                    const SizedBox(width: ZaiNeSpacing.xs),
                    Text(
                      smartValue,
                      style: const TextStyle(
                        fontSize: ZaiNeFontSize.bodySm,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF7043),
                      ),
                    ),
                  ],
                )
              : Text(
                  smartValue,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: ZaiNeFontSize.bodySm,
                    color: Colors.grey[500],
                  ),
                ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  购买区卡片（核心转化）
  // ═══════════════════════════════════════════════════════════════
  Widget _buildPurchaseCard() {
    // 【v1.13.0】始终显示价格购买区（不再因产品未加载而隐藏）
    // 产品未就绪时使用默认价格显示，购买时再提示刷新
    final bool productsReady = _products.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(ZaiNeSpacing.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 标题
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(ZaiNeSpacing.sm),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5F2),
                  borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                ),
                child: const Icon(
                  Icons.shield_moon_rounded,
                  color: Color(0xFFFF7043),
                  size: 20,
                ),
              ),
              const SizedBox(width: ZaiNeSpacing.md),
              const Text(
                '智能守护',
                style: TextStyle(
                  fontSize: ZaiNeFontSize.title,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D2D3A),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZaiNeSpacing.sm),
          Text(
            '一份小小的订阅，一份大大的安心',
            style: TextStyle(
              fontSize: ZaiNeFontSize.bodySm,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: ZaiNeSpacing.xl),
          // 月度/年度切换
          _buildPlanToggle(),
          const SizedBox(height: ZaiNeSpacing.xl),
          // 价格
          _buildPriceDisplay(),
          const SizedBox(height: ZaiNeSpacing.sm),
          // 锚点文案
          Text(
            _selectedPlan == 'monthly' ? '每天仅需 0.3 元' : '每天仅需 0.24 元，省 ¥20',
            style: TextStyle(
              fontSize: ZaiNeFontSize.caption,
              color: const Color(0xFFFF7043).withValues(alpha: 0.85),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: ZaiNeSpacing.sm),
          Text(
            '通过 Apple 订阅管理自动续费',
            style: TextStyle(
              fontSize: ZaiNeFontSize.micro,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: ZaiNeSpacing.xl),
          // 购买按钮
          _buildGradientButton(),
          const SizedBox(height: ZaiNeSpacing.lg),
          _buildSubscriptionTerms(),
          if (!productsReady)
            Padding(
              padding: const EdgeInsets.only(top: ZaiNeSpacing.cardXs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 14, color: ZaiNeColors.brandOrangeSwatch[400]),
                  const SizedBox(width: ZaiNeSpacing.xs),
                  Text(
                    '订阅产品加载中，点击购买将自动刷新',
                    style: TextStyle(
                      fontSize: ZaiNeFontSize.micro,
                      color: ZaiNeColors.brandOrangeSwatch[600],
                    ),
                  ),
                ],
              ),
            ),
          if (!_iapAvailable && productsReady)
            Padding(
              padding: const EdgeInsets.only(top: ZaiNeSpacing.cardXs),
              child: Text(
                '⚠ App Store 暂不可用，请稍后再试',
                style: TextStyle(
                  fontSize: ZaiNeFontSize.caption,
                  color: ZaiNeColors.brandOrangeSwatch[600],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPriceDisplay() {
    // 【修复 v1.77.0】从 IAP 产品动态获取价格，避免硬编码导致价格不准确
    ProductDetails? product;
    try {
      final productId = _selectedPlan == 'monthly'
          ? IapService.productIdMonthly
          : IapService.productIdYearly;
      product = _products.firstWhere((p) => p.id == productId);
    } catch (_) {
      // 产品未加载，返回加载指示器
    }

    if (product == null) {
      // 产品未加载，显示加载状态
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(ZaiNeColors.brandOrangeSwatch[600]!),
            ),
          ),
          const SizedBox(width: ZaiNeSpacing.sm),
          Text(
            '加载中...',
            style: TextStyle(
              fontSize: ZaiNeFontSize.body,
              color: Colors.grey[500],
            ),
          ),
        ],
      );
    }

    // 使用 ProductDetails.price（已包含本地化货币符号）
    final price = product.price;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          price,
          style: const TextStyle(
            fontSize: ZaiNeFontSize.title,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFF7043),
            height: 1.0,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: ZaiNeSpacing.xxs),
          child: Text(
            _selectedPlan == 'monthly' ? '/月' : '/年',
            style: TextStyle(
              fontSize: ZaiNeFontSize.body,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  月度/年度切换 Tab
  // ═══════════════════════════════════════════════════════════════
  Widget _buildPlanToggle() {
    return Container(
      padding: const EdgeInsets.all(ZaiNeSpacing.xs),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0ED),
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildPlanTab(
              label: '月度',
              price: '¥9',
              unit: '/月',
              isSelected: _selectedPlan == 'monthly',
              onTap: () => setState(() => _selectedPlan = 'monthly'),
            ),
          ),
          Expanded(
            child: _buildPlanTab(
              label: '年度',
              price: '${IapService().getYearlyPrice()}/年',
              unit: '≈¥7.3/月',
              isSelected: _selectedPlan == 'yearly',
              onTap: () => setState(() => _selectedPlan = 'yearly'),
              badge: '省18%',
              isRecommended: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanTab({
    required String label,
    required String price,
    required String unit,
    required bool isSelected,
    required VoidCallback onTap,
    String? badge,
    bool isRecommended = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: ZaiNeSpacing.lg),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(ZaiNeRadius.card),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
          border: isSelected
              ? Border.all(
                  color: const Color(0xFFFF7043).withValues(alpha: 0.2),
                  width: 1.5,
                )
              : null,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: ZaiNeFontSize.body,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? const Color(0xFFFF7043) : const Color(0xFF9999AA),
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: ZaiNeSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.sm, vertical: ZaiNeSpacing.xs),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF8A65), Color(0xFFFF5722)],
                      ),
                      borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        fontSize: ZaiNeFontSize.micro,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: ZaiNeSpacing.sm),
            Text(
              price,
              style: TextStyle(
                fontSize: ZaiNeFontSize.subtitle,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? const Color(0xFFFF7043) : const Color(0xFF9999AA),
              ),
            ),
            const SizedBox(height: ZaiNeSpacing.xs),
            Text(
              unit,
              style: TextStyle(
                fontSize: ZaiNeFontSize.micro,
                color: isSelected ? const Color(0xFFFF7043).withValues(alpha: 0.7) : const Color(0xFFBBBBCC),
                decoration: label == '年度' && !isSelected ? TextDecoration.lineThrough : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  渐变购买按钮（守护之光）
  // ═══════════════════════════════════════════════════════════════
  Widget _buildGradientButton() {
    return GestureDetector(
      onTapDown: (_) { if (!_isPurchasing) HapticFeedback.mediumImpact(); },
      onTap: _isPurchasing ? null : _purchaseSmart,
      child: AnimatedScale(
        scale: _isPurchasing ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _isPurchasing ? 1.0 : _pulseAnimation.value,
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF8A65), Color(0xFFFF7043)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(ZaiNeRadius.card),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF7043).withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: _isPurchasing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.favorite_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: ZaiNeSpacing.sm),
                            Text(
                              _selectedPlan == 'monthly'
                                  ? '立即开启守护'
                                  : '立即开启守护 · 年付更省',
                              style: const TextStyle(
                                fontSize: ZaiNeFontSize.subtitle,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  已激活权益卡片
  // ═══════════════════════════════════════════════════════════════
  Widget _buildActiveInfoCard() {
    return Container(
      padding: const EdgeInsets.all(ZaiNeSpacing.section),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7043),
                  borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                ),
              ),
              const SizedBox(width: ZaiNeSpacing.sm),
              const Text(
                '你的守护已点亮',
                style: TextStyle(
                  fontSize: ZaiNeFontSize.subtitle,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D2D3A),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZaiNeSpacing.lg),
          _buildFeatureItem(
            icon: Icons.favorite_rounded,
            gradientColors: const [Color(0xFFFF8A65), Color(0xFFFF7043)],
            title: '紧急时刻，快捷守护3位联系人',
            subtitle: '一键求助，快捷拨打并短信通知前3位联系人',
          ),
          const SizedBox(height: ZaiNeSpacing.lg),
          _buildFeatureItem(
            icon: Icons.people_rounded,
            gradientColors: const [Color(0xFF8B5CF6), Color(0xFF6366F1)],
            title: '最多10位守护人',
            subtitle: '父母、伴侣、挚友，每个重要的人都不会遗漏',
          ),
          const SizedBox(height: ZaiNeSpacing.lg),
          _buildFeatureItem(
            icon: Icons.card_giftcard_rounded,
            gradientColors: const [Color(0xFFEC4899), Color(0xFFFF6B6B)],
            title: '守护卡传递关心',
            subtitle: '邀请亲友加入守护圈，让爱流动起来',
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required List<Color> gradientColors,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(ZaiNeRadius.small),
            boxShadow: [
              BoxShadow(
                color: gradientColors[1].withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: ZaiNeSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: ZaiNeFontSize.body,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D2D3A),
                ),
              ),
              const SizedBox(height: ZaiNeSpacing.xs),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: ZaiNeFontSize.caption,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  管理订阅卡片
  // ═══════════════════════════════════════════════════════════════
  Widget _buildManageSubscriptionCard() {
    return Container(
      padding: const EdgeInsets.all(ZaiNeSpacing.section),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.manage_accounts_outlined,
                size: 20,
                color: Colors.grey[600],
              ),
              const SizedBox(width: ZaiNeSpacing.sm),
              Text(
                '管理守护订阅',
                style: TextStyle(
                  fontSize: ZaiNeFontSize.body,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: ZaiNeSpacing.md),
          Text(
            '通过 Apple ID 管理你的守护订阅，可随时调整',
            style: TextStyle(
              fontSize: ZaiNeFontSize.caption,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: ZaiNeSpacing.lg),
          InkWell(
            onTap: () async {
              final uri = Uri.parse('https://apps.apple.com/account/subscriptions');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            borderRadius: BorderRadius.circular(ZaiNeRadius.small),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: ZaiNeSpacing.lg),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(ZaiNeRadius.small),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '前往 Apple ID 管理',
                    style: TextStyle(
                      fontSize: ZaiNeFontSize.bodySm,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFF7043),
                    ),
                  ),
                  SizedBox(width: ZaiNeSpacing.sm),
                  Icon(
                    Icons.open_in_new,
                    size: 16,
                    color: Color(0xFFFF7043),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  信任承诺（有温度的安全保障）
  // ═══════════════════════════════════════════════════════════════
  Widget _buildTrustPromise() {
    return Container(
      padding: const EdgeInsets.all(ZaiNeSpacing.section),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F2),
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        border: Border.all(
          color: const Color(0xFFFFE0D6),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_user_outlined, size: 18, color: ZaiNeColors.brandOrangeSwatch[400]),
              const SizedBox(width: ZaiNeSpacing.sm),
              Text(
                '你的信任，我们用心守护',
                style: TextStyle(
                  fontSize: ZaiNeFontSize.bodySm,
                  fontWeight: FontWeight.w600,
                  color: ZaiNeColors.brandOrangeSwatch[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: ZaiNeSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTrustItem(Icons.apple, 'Apple 官方支付'),
              _buildTrustItem(Icons.cancel_outlined, '随时可取消'),
              _buildTrustItem(Icons.privacy_tip_outlined, '隐私安全'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrustItem(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, size: 22, color: const Color(0xFFFF7043)),
        const SizedBox(height: ZaiNeSpacing.sm),
        Text(
          label,
          style: TextStyle(
            fontSize: ZaiNeFontSize.micro,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  恢复购买
  // ═══════════════════════════════════════════════════════════════
  Widget _buildRestoreButton() {
    return Center(
      child: TextButton(
        onPressed: _restorePurchase,
        child: const Text(
          '恢复购买',
          style: TextStyle(
            fontSize: ZaiNeFontSize.bodySm,
            color: Color(0xFF9999AA),
            decoration: TextDecoration.underline,
            decorationColor: Color(0xFFCCCCDD),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  Apple 审核要求的完整订阅条款（Guideline 3.1.2(c) 合规）
  //  ═══════════════════════════════════════════════════════════════
  Widget _buildSubscriptionTerms() {
    return Container(
      padding: const EdgeInsets.all(ZaiNeSpacing.cardSm),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(ZaiNeRadius.small),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 标题行：订阅名称 + 时长 + 价格 ──
          Row(
            children: [
              Text(
                '在呢智能版',
                style: TextStyle(
                  fontSize: ZaiNeFontSize.caption,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[800],
                ),
              ),
              Text(
                _selectedPlan == 'monthly' ? ' · 月度 ¥9/月' : ' · 年度 ¥88/年',
                style: TextStyle(
                  fontSize: ZaiNeFontSize.caption,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: ZaiNeSpacing.md),

          // ── 订阅条款详情 ──
          Text(
            '• 订阅名称：在呢智能版\n'
            '• 订阅时长：${_selectedPlan == 'monthly' ? '每月自动续费' : '每年自动续费'}\n'
            '• 订阅价格：${_selectedPlan == 'monthly' ? '¥9/月（约合 ¥0.30/天）' : '¥88/年（约合 ¥0.24/天）'}\n'
            '• 自动续费：当前计费周期结束前24小时自动扣款\n'
            '• 取消方式：随时可在 Apple ID 设置中取消，取消后当前周期仍可用',
            style: TextStyle(
              fontSize: ZaiNeFontSize.micro,
              color: Colors.grey[600],
              height: 1.7,
            ),
            textAlign: TextAlign.left,
          ),
          const SizedBox(height: ZaiNeSpacing.md),

          // ── 隐私政策 + 服务条款 链接（Apple 审核 3.1.2(c) 必需）──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.md, vertical: ZaiNeSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ZaiNeRadius.small),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.privacy_tip_outlined, size: 15, color: Colors.blue[600]),
                    const SizedBox(width: ZaiNeSpacing.sm),
                    GestureDetector(
                      onTap: () => _openUrl(AppConstants.privacyUrl),
                      child: Text(
                        '查看隐私政策',
                        style: TextStyle(
                          fontSize: ZaiNeFontSize.caption,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right, size: 16, color: Colors.blue[300]),
                  ],
                ),
                const Divider(height: 16, color: Color(0xFFF0F0F0)),
                Row(
                  children: [
                    Icon(Icons.gavel_outlined, size: 15, color: ZaiNeColors.brandOrangeSwatch[700]),
                    const SizedBox(width: ZaiNeSpacing.sm),
                    GestureDetector(
                      onTap: () => _openUrl(AppConstants.termsUrl),
                      child: Text(
                        '查看服务条款（用户协议）',
                        style: TextStyle(
                          fontSize: ZaiNeFontSize.caption,
                          color: ZaiNeColors.brandOrangeSwatch[700],
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right, size: 16, color: ZaiNeColors.brandOrangeSwatch[300]),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 打开外部 URL
  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('无法打开页面：$url'),
          backgroundColor: ZaiNeColors.brandOrangeSwatch,
        ),
      );
    }
  }
}

// 价值主张数据模型
class _PropItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  _PropItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
}
