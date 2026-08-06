// lib/services/api/subscription_service.dart
// 订阅管理 API（StoreKit 2 凭证验证）

import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../api_service.dart';

class SubscriptionService {
  // 签名密钥优先从编译时环境变量读取；未设置时默认与后端 _MVP_SIGN_SECRET 一致，
  // 保证标准构建命令下 IAP 验证可正常工作。如需覆盖，构建时传入：
  // flutter build ios --dart-define=ZAINE_SIGN_SECRET=your_secret
  static const _signSecret = String.fromEnvironment(
    'ZAINE_SIGN_SECRET',
    defaultValue: 'zaine-storekit-mvp-v1',
  );

  /// 验证签名密钥是否已配置
  static bool get isSignSecretConfigured => _signSecret.isNotEmpty;

  /// 生成 IAP 请求签名（HMAC-SHA256）
  ///
  /// 签名规则（与后端 _verify_iap_signature 一致）：
  /// 1. 构造明文: "{transaction_id}:{purchase_date_ms}:{product_id}"
  /// 2. HMAC-SHA256(secret, 明文) → 十六进制字符串
  static String _generateSignature({
    required String transactionId,
    required int purchaseDateMs,
    required String productId,
  }) {
    final message = '$transactionId:$purchaseDateMs:$productId';
    final bytes = utf8.encode(message);
    final hmac = Hmac(sha256, utf8.encode(_signSecret));
    final digest = hmac.convert(bytes);
    return digest.toString(); // 十六进制字符串
  }

  /// 获取订阅状态
  static Future<Map<String, dynamic>> getStatus() async {
    return await ApiService.get('/api/subscription/status');
  }

  /// 验证 StoreKit 2 购买凭证
  static Future<Map<String, dynamic>> verifyReceipt({
    required String transactionId,
    required String originalTransactionId,
    required String productId,
    required int purchaseDateMs,
    int? expiresDateMs,
    bool isInIntroPeriod = false,
  }) async {
    // 生成 HMAC-SHA256 签名（防伪造）
    final signature = _generateSignature(
      transactionId: transactionId,
      purchaseDateMs: purchaseDateMs,
      productId: productId,
    );

    return await ApiService.post('/api/subscription/verify-receipt', body: {
      'transaction_id': transactionId,
      'original_transaction_id': originalTransactionId,
      'product_id': productId,
      'purchase_date_ms': purchaseDateMs,
      'expires_date_ms': expiresDateMs,
      'is_in_intro_period': isInIntroPeriod,
      'signature': signature,
    });
  }

  /// 恢复购买
  static Future<Map<String, dynamic>> restorePurchase() async {
    return await ApiService.post('/api/subscription/restore');
  }
}
