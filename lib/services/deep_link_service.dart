// lib/services/deep_link_service.dart
// Deep Link 处理服务（v1.9.x）
//
// 处理深度链接打开 App 的情况：
//   1. 冷启动：main() 中调用 getInitialAppLink() 拿到初始链接
//   2. 热启动：uriLinkStream 监听后台唤起的链接
//   3. /landing/{card_code} → 保存 card_code（守护卡邀请）
//   4. /download?token=xxx → 保存静默登录凭证
//   5. onboarding quickLogin 成功后检查 pending card_code → 调用裂变绑定接口

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'api/card_service.dart';
import 'api/sync_service.dart';
import 'silent_login_service.dart';

class DeepLinkService {
  static const _pendingCardKey = 'pending_card_code';
  static const _pendingCardKeyCompat = 'pending-card-code';

  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _sub;

  /// 初始化（在 main() 中调用一次）
  ///
  /// 处理冷启动时的初始链接，并监听热启动链接。
  static Future<void> init() async {
    // 处理冷启动链接（App 从未运行，通过链接打开）
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        debugPrint('[DeepLink] 冷启动链接: $initial');
        await _handleLink(initial);
      }
    } catch (e) {
      debugPrint('[DeepLink] 获取初始链接失败: $e');
    }

    // 监听热启动链接（App 在后台，通过链接唤起）
    _sub = _appLinks.uriLinkStream.listen(
      (uri) async {
        debugPrint('[DeepLink] 热启动链接: $uri');
        await _handleLink(uri);
      },
      onError: (e) => debugPrint('[DeepLink] 链接监听错误: $e'),
    );
  }

  /// 停止监听（App 销毁时调用，通常可忽略）
  static void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  /// 解析 URI 并处理不同类型的深度链接
  ///
  /// 支持格式：
  ///   - https://zaine.love/landing/abc123xyz → 保存 card_code
  ///   - zaine://download?token=xxx&phone=xxx → 保存静默登录凭证
  static Future<void> _handleLink(Uri uri) async {
    final path = uri.path;

    // 检查是否是下载链接（静默登录）
    if (path.endsWith('/download') || path.contains('download')) {
      final (token, phone) = SilentLoginService.parseDownloadParams(uri);
      if (token != null && phone != null) {
        debugPrint('[DeepLink] 发现下载链接登录凭证: phone=$phone');
        await SilentLoginService.savePendingAuth(token, phone);
        return;
      }
    }

    // 原有的守护卡逻辑
    final cardCode = _extractCardCode(uri);
    if (cardCode == null || cardCode.isEmpty) {
      debugPrint('[DeepLink] 链接中未包含有效参数，忽略');
      return;
    }

    debugPrint('[DeepLink] 提取到 card_code: $cardCode');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingCardKey, cardCode);
  }

  /// 从 URI 中提取 card_code
  ///
  /// 路径格式：/landing/{card_code}
  static String? _extractCardCode(Uri uri) {
    final segments = uri.pathSegments;
    // 路径形如 ['landing', 'abc123xyz'] 或 ['', 'landing', 'abc123xyz']
    final idx = segments.indexOf('landing');
    if (idx >= 0 && idx + 1 < segments.length) {
      final code = segments[idx + 1];
      return code.isNotEmpty ? code : null;
    }
    return null;
  }

  /// 检查是否有待处理的裂变 card_code
  ///
  /// 在 onboarding quickLogin 成功后调用（verifyAndDownload 流程已由后端处理，无需再调用）。
  /// 有 card_code 则调用 verify-and-link 完成绑定。
  static Future<void> processPendingCardCode(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    final cardCode = prefs.getString(_pendingCardKey) ?? prefs.getString(_pendingCardKeyCompat);
    if (cardCode == null || cardCode.isEmpty) return;
    await prefs.setString(_pendingCardKey, cardCode);

    debugPrint('[DeepLink] 发现待处理 card_code: $cardCode，执行裂变绑定...');

    final normalized = cardCode.trim().replaceAll(' ', '').toUpperCase();
    final res = await CardService.redeemCard(cardCode: normalized);

    if (res['success'] == true) {
      debugPrint('[DeepLink] ✅ 守护卡自动绑定成功');
      await SyncService.pullFromServer();
      await prefs.remove(_pendingCardKey);
      await prefs.remove(_pendingCardKeyCompat);
      return;
    }

    if (res['offline'] == true || res['statusCode'] == 401) {
      debugPrint('[DeepLink] ⚠️ 守护卡自动绑定失败（离线或未登录），保留 card_code 下次重试');
      return;
    }

    debugPrint('[DeepLink] ❌ 守护卡自动绑定失败: ${res['error'] ?? res['message']}');
    await prefs.remove(_pendingCardKey);
    await prefs.remove(_pendingCardKeyCompat);
  }

  /// 是否有待处理的 card_code（用于 UI 判断是否展示欢迎礼包提示）
  static Future<bool> hasPendingCardCode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_pendingCardKey) ?? prefs.getString(_pendingCardKeyCompat);
    if (code != null && code.isNotEmpty && (prefs.getString(_pendingCardKey) == null || prefs.getString(_pendingCardKey)!.isEmpty)) {
      await prefs.setString(_pendingCardKey, code);
    }
    return code != null && code.isNotEmpty;
  }
}
