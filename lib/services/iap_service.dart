// lib/services/iap_service.dart
// StoreKit 2 真实 IAP 服务 — 产品加载、购买、恢复、交易监听

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class IapService {
  // 单例
  static final IapService _instance = IapService._();
  factory IapService() => _instance;
  IapService._();

  final InAppPurchase _iap = InAppPurchase.instance;

  /// 产品 ID（与 ASC 后台完全一致，使用点分隔）
  static const String productIdMonthly = 'com.zaine.smart.monthly';
  static const String productIdYearly = 'com.zaine.smart.yearly';
  static const Set<String> _productIds = {
    productIdMonthly,
    productIdYearly,
  };

  // 缓存的产品列表
  List<ProductDetails>? _products;

  // 交易流 — 供外部监听购买结果
  final StreamController<PurchaseResult> _purchaseResultController =
      StreamController<PurchaseResult>.broadcast();
  Stream<PurchaseResult> get purchaseResultStream =>
      _purchaseResultController.stream;

  // 交易更新订阅
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// 初始化 — 监听交易更新
  Future<void> init() async {
    // 取消旧订阅
    await _subscription?.cancel();
    _subscription = _iap.purchaseStream.listen(_handlePurchaseUpdates);
    if (kDebugMode) debugPrint('[IAP] 服务初始化完成');
  }

  /// 释放资源
  void dispose() {
    _subscription?.cancel();
    _purchaseResultController.close();
  }

  /// IAP 是否可用
  Future<bool> isAvailable() => _iap.isAvailable();

  /// 加载产品详情（带缓存）
  Future<List<ProductDetails>> loadProducts() async {
    if (_products != null && _products!.isNotEmpty) return _products!;

    final available = await _iap.isAvailable();
    if (!available) {
      if (kDebugMode) debugPrint('[IAP] ❌ StoreKit 不可用');
      return [];
    }

    if (kDebugMode) debugPrint('[IAP] 🔍 查询产品: $_productIds');

    final response = await _iap.queryProductDetails(_productIds);

    if (response.notFoundIDs.isNotEmpty) {
      if (kDebugMode) debugPrint('[IAP] ⚠️ 未找到的产品: ${response.notFoundIDs}');
      if (kDebugMode) debugPrint('[IAP] 💡 可能原因: 1)ASC后台产品未提交审核 2)审核未通过 3)刚通过审核尚未生效(需等2-24h) 4)沙盒测试员未配置)');
    }

    if (response.productDetails.isNotEmpty) {
      _products = response.productDetails;
      if (kDebugMode) {
        for (final p in response.productDetails) {
          debugPrint('[IAP] ✅ 产品: ${p.id} | ${p.title} | ${p.price}');
        }
      }
    } else {
      if (kDebugMode) debugPrint('[IAP] ❌ 产品加载为空! StoreKit 返回0个产品');
      if (kDebugMode) debugPrint('[IAP] 💡 请检查: 1)ASC后台产品状态是否为"已批准" 2)产品ID是否匹配 3)是否使用沙盒测试账号');
      return [];
    }

    return _products!;
  }

  /// 强制重新加载产品（忽略缓存）
  Future<List<ProductDetails>> reloadProducts() async {
    _products = null;
    return loadProducts();
  }

  /// 发起购买
  /// 【v1.85.0 增强】带自动重试 + 友好的错误分类
  Future<String?> purchaseProduct(ProductDetails product,
      {int maxRetries = 1}) async {
    final available = await _iap.isAvailable();
    if (!available) {
      if (kDebugMode) debugPrint('[IAP] StoreKit 不可用，无法购买');
      return 'StoreKit 不可用，请稍后再试';
    }

    // StoreKit 2 统一购买接口（支持订阅/非消耗/消耗型）
    final purchaseParam = PurchaseParam(
      productDetails: product,
      applicationUserName: null, // 可选：关联用户标识
    );

    // 【修复 v1.85.0】自动重试机制（处理沙盒网络波动）
    String? lastError;
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      if (attempt > 0) {
        if (kDebugMode) debugPrint('[IAP] 第 $attempt 次重试购买...');
        await Future.delayed(Duration(seconds: attempt * 2)); // 渐进延迟
      }

      try {
        final result = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
        if (result) {
          if (attempt > 0 && kDebugMode) {
            debugPrint('[IAP] ✅ 第 ${attempt + 1} 次尝试购买成功');
          }
          return null; // null 表示成功发起
        } else {
          lastError = '购买请求发起失败';
          if (kDebugMode) debugPrint('[IAP] 购买发起失败（返回 false），尝试: ${attempt + 1}/${maxRetries + 1}');
        }
      } catch (e) {
        lastError = e.toString();
        if (kDebugMode) debugPrint('[IAP] 购买异常(尝试 ${attempt + 1}/${maxRetries + 1}): $e');

        // 【新增 v1.85.0】判断是否为可重试的网络错误
        final errStr = e.toString().toLowerCase();
        final isNetworkError = errStr.contains('nsurlerror') ||
            errStr.contains('network') ||
            errStr.contains('socket') ||
            errStr.contains('connection') ||
            errStr.contains('timeout') ||
            errStr.contains('storekit2_failed');

        if (!isNetworkError || attempt >= maxRetries) {
          // 非网络错误或已达到最大重试次数 → 返回用户友好的错误信息
          return _classifyError(e);
        }
        // 网络错误且还有重试机会 → 继续循环
      }
    }
    return '购买失败：$lastError';
  }

  /// 【新增 v1.85.0】将原始异常转换为用户友好的错误信息（null=用户取消，不显示错误）
  String? _classifyError(dynamic e) {
    final errStr = e.toString();

    // 沙盒 SSL/网络错误（最常见）
    if (errStr.contains('storekit2_failed_to_fetch_product') ||
        errStr.contains('-1200') ||
        errStr.contains('nsurlerror')) {
      return '网络连接不稳定\n请检查网络后重试\n（沙盒测试环境可能需要关闭 VPN）';
    }

    // 用户取消
    if (errStr.contains('cancelled') || errStr.contains('canceled')) {
      return null; // 取消不算错误
    }

    // 沙盒未就绪
    if (errStr.contains('cloud_service') || errStr.contains('sandbox')) {
      return '沙盒服务暂不可用\n请稍后重试或重启 App';
    }

    // 其他未知错误
    if (errStr.length > 80) {
      return '购买遇到问题 (${errStr.substring(0, 60)}...)';
    }
    return '购买异常：$errStr';
  }

  /// 恢复购买
  Future<void> restorePurchases() async {
    final available = await _iap.isAvailable();
    if (!available) {
      if (kDebugMode) debugPrint('[IAP] StoreKit 不可用，无法恢复');
      return;
    }

    await _iap.restorePurchases();
    if (kDebugMode) debugPrint('[IAP] 恢复购买请求已发送');
  }

  /// 获取缓存的产品（已加载后调用）
  ProductDetails? getProduct(String productId) {
    return _products?.firstWhere(
      (p) => p.id == productId,
      orElse: () => throw Exception('产品未找到: $productId'),
    );
  }

  /// 获取月度产品价格描述
  String getMonthlyPrice() {
    try {
      final product = getProduct(productIdMonthly);
      return product!.price;
    } catch (_) {
      return '¥9';
    }
  }

  /// 获取年度产品价格描述
  String getYearlyPrice() {
    try {
      final product = getProduct(productIdYearly);
      return product!.price;
    } catch (_) {
      return '¥88';
    }
  }

  /// 处理交易更新（不直接调 completePurchase，让外部验证成功后再调）
  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        // 购买成功 → 通知外部（由外部在验证小票成功后再调 completePurchase）
        _purchaseResultController.add(PurchaseResult(
          success: true,
          productId: purchaseDetails.productID,
          transactionId: purchaseDetails.purchaseID,
          // 注意：in_app_purchase 插件未暴露 originalTransactionId
          // 后端会通过 App Store Server API 自动查询
          originalTransactionId: null,
          purchaseDateMs: purchaseDetails.transactionDate != null
              ? DateTime.parse(purchaseDetails.transactionDate!)
                  .millisecondsSinceEpoch
              : DateTime.now().millisecondsSinceEpoch,
          purchaseDetails: purchaseDetails,
        ));
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        // 购买失败
        _purchaseResultController.add(PurchaseResult(
          success: false,
          error: purchaseDetails.error?.message ?? '购买失败',
          productId: purchaseDetails.productID,
          transactionId: purchaseDetails.purchaseID,
          purchaseDateMs: DateTime.now().millisecondsSinceEpoch,
          purchaseDetails: purchaseDetails,
        ));
      } else if (purchaseDetails.pendingCompletePurchase) {
        // 【修复 v1.84.0】对于已经验证过但没调 completePurchase 的交易，自动完成
        // （防止异常情况下交易卡死）
        if (kDebugMode) debugPrint('[IAP] ⚠️ 发现 pending 交易，自动完成: ${purchaseDetails.productID}');
        _iap.completePurchase(purchaseDetails);
      }
    }
  }

  /// 标记交易完成（应在验证小票成功后再调用）
  void completePurchase(PurchaseDetails purchaseDetails) {
    if (purchaseDetails.pendingCompletePurchase) {
      _iap.completePurchase(purchaseDetails);
      if (kDebugMode) debugPrint('[IAP] 标记交易完成: ${purchaseDetails.productID}');
    }
  }
}

/// 购买结果
class PurchaseResult {
  final bool success;
  final String? error;
  final String productId;
  final String? transactionId;
  final String? originalTransactionId;
  final int purchaseDateMs;
  final PurchaseDetails purchaseDetails;

  PurchaseResult({
    required this.success,
    this.error,
    required this.productId,
    this.transactionId,
    this.originalTransactionId,
    required this.purchaseDateMs,
    required this.purchaseDetails,
  });
}
