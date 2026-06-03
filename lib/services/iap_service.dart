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

  /// 产品 ID
  static const String productIdMonthly = 'com.zaine.smart_monthly';
  static const String productIdYearly = 'com.zaine.smart_yearly';
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
    debugPrint('[IAP] 服务初始化完成');
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
      debugPrint('[IAP] StoreKit 不可用');
      return [];
    }

    final response = await _iap.queryProductDetails(_productIds);

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('[IAP] 未找到的产品: ${response.notFoundIDs}');
    }

    if (response.productDetails.isNotEmpty) {
      _products = response.productDetails;
      debugPrint('[IAP] 成功加载 ${response.productDetails.length} 个产品');
    } else {
      debugPrint('[IAP] 产品加载为空，不缓存，下次可重试');
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
  Future<bool> purchaseProduct(ProductDetails product) async {
    final available = await _iap.isAvailable();
    if (!available) {
      debugPrint('[IAP] StoreKit 不可用，无法购买');
      return false;
    }

    // StoreKit 2 推荐使用 SK2 方式
    final purchaseParam = PurchaseParam(
      productDetails: product,
      applicationUserName: null, // 可选：关联用户标识
    );

    final result = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    if (!result) {
      debugPrint('[IAP] 购买发起失败');
      return false;
    }
    return true;
  }

  /// 恢复购买
  Future<void> restorePurchases() async {
    final available = await _iap.isAvailable();
    if (!available) {
      debugPrint('[IAP] StoreKit 不可用，无法恢复');
      return;
    }

    await _iap.restorePurchases();
    debugPrint('[IAP] 恢复购买请求已发送');
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

  // ---- 内部 ----

  /// 处理交易更新
  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        // 购买成功 → 通知外部
        _purchaseResultController.add(PurchaseResult(
          success: true,
          productId: purchaseDetails.productID,
          transactionId: purchaseDetails.purchaseID,
          originalTransactionId: purchaseDetails.purchaseID, // MVP：用 transactionId 代替
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
      }

      // 标记交易已完成（对 StoreKit 1 和 2 都安全）
      if (purchaseDetails.pendingCompletePurchase) {
        _iap.completePurchase(purchaseDetails);
        debugPrint('[IAP] 标记交易完成: ${purchaseDetails.productID}');
      }
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
