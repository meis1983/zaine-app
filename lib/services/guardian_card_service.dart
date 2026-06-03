import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api/card_service.dart';

/// 守护卡服务 — 管理守护卡额度（v2.0 单池模型）
///
/// 额度规则（已对齐后端）：
/// - 新用户注册赠送 3 张（永久有效）
/// - 无每日免费额度 —— 核心激励靠裂变解锁
/// - 发出的卡被注册后，发卡人自动解锁 +1 张
/// - 手上始终 2-3 张在流转，每张都珍贵
class GuardianCardService {
  /// 异步获取当前用户的同步标识（优先用 user_id，其次用 phone）
  /// 【修复 v1.9.x】每次调用时实时从 SharedPreferences 读取，确保当前登录用户正确
  static Future<String> _getCurrentSyncIdAsync() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    final phone = prefs.getString('user_phone');
    if (userId != null && userId.isNotEmpty) {
      return userId;
    } else if (phone != null && phone.isNotEmpty) {
      return phone;
    }
    return 'anonymous';
  }

  /// 新用户赠送数量
  static const int giftCardCount = 3;

  /// 发出卡等待注册小时数
  static const int sentCardWaitHours = 24;

  /// 获取赠送卡剩余数量（新用户初始3张 + 裂变解锁）
  static Future<int> getGiftRemaining() async {
    final prefs = await SharedPreferences.getInstance();
    final syncId = await _getCurrentSyncIdAsync();
    return prefs.getInt('guardian_card_gift_remaining_$syncId') ?? 0;
  }

  /// 初始化新用户赠送（仅在首次启动时调用）
  /// 【修复 v1.9.6】初始化后立即同步后端，避免本地默认值与后端不一致
  static Future<void> initGiftCards() async {
    final prefs = await SharedPreferences.getInstance();
    final syncId = await _getCurrentSyncIdAsync();
    final firstLaunchKey = 'guardian_card_first_launch_date_$syncId';
    final hasInitialized = prefs.getString(firstLaunchKey) != null;

    if (!hasInitialized) {
      final today = DateTime.now().toString().split(' ')[0];
      await prefs.setString(firstLaunchKey, today);
      // 使用用户特定的键存储额度
      await prefs.setInt('guardian_card_gift_remaining_$syncId', giftCardCount);
      debugPrint('[GuardianCard] 新用户赠送 $giftCardCount 张守护卡 (syncId=$syncId)');
      // 初始化后立即同步后端真实额度（覆盖本地默认值）
      await syncQuotaFromBackend();
    }
  }

  /// 消耗一张守护卡（返回 true 表示消耗成功）
  static Future<bool> consumeCard() async {
    final prefs = await SharedPreferences.getInstance();
    final syncId = await _getCurrentSyncIdAsync();
    final giftKey = 'guardian_card_gift_remaining_$syncId';
    final remaining = prefs.getInt(giftKey) ?? 0;

    if (remaining > 0) {
      await prefs.setInt(giftKey, remaining - 1);
      return true;
    }
    return false;
  }

  /// 解锁一张守护卡（裂变注册回调时调用）
  static Future<void> unlockCard() async {
    final prefs = await SharedPreferences.getInstance();
    final syncId = await _getCurrentSyncIdAsync();
    final giftKey = 'guardian_card_gift_remaining_$syncId';
    final remaining = prefs.getInt(giftKey) ?? 0;
    await prefs.setInt(giftKey, remaining + 1);
    debugPrint('[GuardianCard] 裂变解锁 +1 张，当前剩余: ${remaining + 1} (syncId=$syncId)');
  }

  /// 获取已发送的守护卡列表
  static Future<List<Map<String, dynamic>>> getSentCards() async {
    final prefs = await SharedPreferences.getInstance();
    final syncId = await _getCurrentSyncIdAsync();
    final sentKey = 'guardian_card_sent_cards_$syncId';
    final sentData = prefs.getString(sentKey);
    if (sentData == null || sentData.isEmpty) return [];

    final result = <Map<String, dynamic>>[];
    final lines = sentData.split('\n');
    for (final line in lines) {
      if (line.isEmpty) continue;
      final parts = line.split('|');
      if (parts.length >= 3) {
        result.add({
          'name': parts[0],
          'message': parts[1],
          'timestamp': parts[2],
        });
      }
    }
    return result;
  }

  /// 记录一张发出的守护卡
  static Future<void> recordSentCard({
    required String recipientName,
    required String message,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final syncId = await _getCurrentSyncIdAsync();
    final sentKey = 'guardian_card_sent_cards_$syncId';
    final now = DateTime.now().toIso8601String();

    final existing = prefs.getString(sentKey) ?? '';
    final newEntry = '$recipientName|$message|$now';
    final updated = existing.isEmpty ? newEntry : '$existing\n$newEntry';
    await prefs.setString(sentKey, updated);
  }

  /// 发送守护卡到后端
  /// 【重要】后端是权威源：成功时返回扣减后的 available_cards
  /// 前端直接使用后端返回值，不额外扣减本地余额
  static Future<Map<String, dynamic>> sendCardWithBackend({
    required String message,
    String? recipientName,
  }) async {
    // 【修复 v1.9.5】移除本地 pre-check，直接调后端
    // 原因：新安装/清缓存后 SharedPreferences 为0，但后端有额度
    // 后端是权威源，以后端返回为准

    // 【修复 v1.9.6】发请求前先检查 token 是否存在，避免无意义请求
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      debugPrint('[GuardianCard] auth_token 不存在，判定为未登录');
      return {'success': false, 'error': 'not_logged_in'};
    }

    debugPrint('[GuardianCard] 准备发送守护卡：message=$message, recipientName=$recipientName');

    final res = await CardService.sendCard(
      message: message,
      recipientName: recipientName,
    );

    debugPrint('[GuardianCard] 后端返回：$res');

    if (res['success'] == true) {
      // 【修复 v1.9.5】后端已扣减 available_cards，直接使用返回值更新本地缓存
      // 如果后端未返回，则从本地获取作为 fallback
      int? backendAvailable = res['available_cards'] as int?;
      final newAvailable = backendAvailable ?? (await getGiftRemaining());
      await updateLocalCache(newAvailable);

      debugPrint('[GuardianCard] 发卡成功，剩余: $newAvailable 张');

      return {
        'success': true,
        'cardCode': res['card_code'] ?? '',
        'shareUrl': res['share_url'] ?? res['landing_url'] ?? '',
        'available_cards': newAvailable,
      };
    } else if (res['offline'] == true) {
      // 【修复】离线模式：仅本地记录，不扣减余额
      // 联网后 syncQuotaFromBackend() 会同步后端真实状态
      debugPrint('[GuardianCard] 离线模式：本地记录发卡请求');
      return {'success': true, 'cardCode': '', 'shareUrl': '', 'offline': true};
    } else {
      // 发卡失败（后端返回 success=false）
      debugPrint('[GuardianCard] 后端发卡失败: ${res['error'] ?? res['message']}');
      debugPrint('[GuardianCard] 完整响应: $res');

      // 【新增 v1.9.6】拦截 422 + missing Authorization → 未登录
      // 兜底保护：防止后端 Header 必填校验导致 422 而非 401
      final statusCode = res['statusCode'] as int?;
      if (statusCode == 422) {
        final detail = res['detail'] as List?;
        final isMissingAuth = detail != null &&
            detail.any((e) => (e is Map) &&
                (e['loc'] as List?)?.contains('Authorization') == true);
        if (isMissingAuth) {
          debugPrint('[GuardianCard] 422 missing Authorization，判定为未登录');
          return {'success': false, 'error': 'not_logged_in'};
        }
      }

      // 【新增 v1.9.6】401 + detail 说明缺少 token → 未登录
      // ApiService._parse 在非 2xx 时会返回 {success: false, statusCode, detail}
      if (statusCode == 401) {
        final detail = res['detail'];
        if (detail != null) {
          debugPrint('[GuardianCard] 401 + detail，判定为未登录/Token失效');
          return {'success': false, 'error': 'not_logged_in'};
        }
      }

      return {'success': false, 'error': res['error'] ?? res['message'] ?? 'unknown'};
    }
  }

  /// 更新本地缓存的可用卡片数
  /// 供 _shareCard 成功后同步最新值
  static Future<void> updateLocalCache(int availableCards) async {
    final prefs = await SharedPreferences.getInstance();
    final syncId = await _getCurrentSyncIdAsync();
    await prefs.setInt('guardian_card_gift_remaining_$syncId', availableCards);
    debugPrint('[GuardianCard] updateLocalCache: $availableCards 张 (syncId=$syncId)');
  }

  /// 启动时从后端同步额度
  /// 【重要】优先使用 /card/list 返回的权威数据（包含过期检查）
  /// 返回最新的可用卡片数（若失败则为本地缓存值）
  static Future<int> syncQuotaFromBackend() async {
    try {
      // 方案1：优先使用 /card/list（后端会懒检查过期卡并退回）
      final cardListRes = await CardService.listMyCards();
      if (cardListRes['success'] == true) {
        final stats = cardListRes['stats'] as Map<String, dynamic>?;
        if (stats != null) {
          final backendAvailable = (stats['available_cards'] as int?) ?? 0;
          await updateLocalCache(backendAvailable);
          debugPrint('[GuardianCard] syncQuotaFromBackend (card/list): $backendAvailable 张');
          return backendAvailable;
        }
      }
    } catch (e) {
      debugPrint('[GuardianCard] syncQuotaFromBackend (card/list) 失败: $e');
    }

    // 方案2：备用 /invite/stats
    try {
      final res = await CardService.getInviteStats();
      if (res['success'] == true) {
        final backendAvailable = (res['available_cards'] as int?) ?? 0;
        await updateLocalCache(backendAvailable);
        debugPrint('[GuardianCard] syncQuotaFromBackend (invite/stats): $backendAvailable 张');
        return backendAvailable;
      }
    } catch (e) {
      debugPrint('[GuardianCard] syncQuotaFromBackend (invite/stats) 失败: $e');
    }

    // 失败时返回本地缓存值
    final prefs = await SharedPreferences.getInstance();
    final syncId = await _getCurrentSyncIdAsync();
    final cached = prefs.getInt('guardian_card_gift_remaining_$syncId') ?? 0;
    debugPrint('[GuardianCard] syncQuotaFromBackend 失败，使用本地缓存: $cached 张 (syncId=$syncId)');
    return cached;
  }

  /// 获取守护卡总数（v2.0 单池，直接返回 giftRemaining）
  static Future<int> getTotalAvailable() async {
    return getGiftRemaining();
  }
}
