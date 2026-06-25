import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api/auth_service.dart';
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
  /// 【修复 v1.12.0】本地写入初始额度后不立即同步后端，
  /// 避免新用户后端无记录返回0覆盖本地默认值。
  /// 后端同步由进入发卡页面时触发 syncQuotaFromBackend() 负责。
  static Future<void> initGiftCards() async {
    final prefs = await SharedPreferences.getInstance();
    final syncId = await _getCurrentSyncIdAsync();
    final firstLaunchKey = 'guardian_card_first_launch_date_$syncId';
    final hasInitialized = prefs.getString(firstLaunchKey) != null;

    if (!hasInitialized) {
      final today = DateTime.now().toString().split(' ')[0];
      await prefs.setString(firstLaunchKey, today);
      // 使用用户特定的键存储额度（新用户初始 3 张）
      await prefs.setInt('guardian_card_gift_remaining_$syncId', giftCardCount);
      if (kDebugMode) debugPrint('[GuardianCard] 新用户赠送 $giftCardCount 张守护卡 (syncId=$syncId)');
      // 不再立即调用 syncQuotaFromBackend()，避免后端返回 0 覆盖本地值
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
    if (kDebugMode) debugPrint('[GuardianCard] 裂变解锁 +1 张，当前剩余: ${remaining + 1} (syncId=$syncId)');
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

    // 【修复 v1.75.0】发请求前先检查 token 是否存在，避免无意义请求
    // 使用 AuthService.getToken() 统一获取（支持 Keychain + SP 多重来源）
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      if (kDebugMode) debugPrint('[GuardianCard] token 不存在，判定为未登录');
      return {'success': false, 'error': 'not_logged_in'};
    }

    if (kDebugMode) debugPrint('[GuardianCard] 准备发送守护卡：message=$message, recipientName=$recipientName');

    final res = await CardService.sendCard(
      message: message,
      recipientName: recipientName,
    );

    if (kDebugMode) debugPrint('[GuardianCard] 后端返回：$res');

    if (res['success'] == true) {
      // 【修复 v1.9.5】后端已扣减 available_cards，直接使用返回值更新本地缓存
      // 如果后端未返回，则从本地获取作为 fallback
      int? backendAvailable = res['available_cards'] as int?;
      final newAvailable = backendAvailable ?? (await getGiftRemaining());
      await updateLocalCache(newAvailable);

      if (kDebugMode) debugPrint('[GuardianCard] 发卡成功，剩余: $newAvailable 张');

      return {
        'success': true,
        'cardCode': res['card_code'] ?? '',
        'shareUrl': res['share_url'] ?? res['landing_url'] ?? '',
        'available_cards': newAvailable,
      };
    } else if (res['offline'] == true) {
      // 【修复】离线模式：仅本地记录，不扣减余额
      // 联网后 syncQuotaFromBackend() 会同步后端真实状态
      if (kDebugMode) debugPrint('[GuardianCard] 离线模式：本地记录发卡请求');
      return {'success': true, 'cardCode': '', 'shareUrl': '', 'offline': true};
    } else {
      // 发卡失败（后端返回 success=false）
      if (kDebugMode) debugPrint('[GuardianCard] 后端发卡失败: ${res['error'] ?? res['message']}');
      if (kDebugMode) debugPrint('[GuardianCard] 完整响应: $res');

      // 【新增 v1.9.6】拦截 422 + missing Authorization → 未登录
      // 兜底保护：防止后端 Header 必填校验导致 422 而非 401
      final statusCode = res['statusCode'] as int?;
      if (statusCode == 422) {
        final detail = res['detail'] as List?;
        final isMissingAuth = detail != null &&
            detail.any((e) => (e is Map) &&
                (e['loc'] as List?)?.contains('Authorization') == true);
        if (isMissingAuth) {
          if (kDebugMode) debugPrint('[GuardianCard] 422 missing Authorization，判定为未登录');
          return {'success': false, 'error': 'not_logged_in'};
        }
      }

      // 【新增 v1.9.6】401 + detail 说明缺少 token → 未登录
      // ApiService._parse 在非 2xx 时会返回 {success: false, statusCode, detail}
      if (statusCode == 401) {
        final detail = res['detail'];
        if (detail != null) {
          if (kDebugMode) debugPrint('[GuardianCard] 401 + detail，判定为未登录/Token失效');
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
    if (kDebugMode) debugPrint('[GuardianCard] updateLocalCache: $availableCards 张 (syncId=$syncId)');
  }

  /// 启动时从后端同步额度
  /// 【重要】优先使用 /card/list 返回的权威数据（包含过期检查）
  /// 返回最新的可用卡片数（若失败则为本地缓存值）
  /// 【修复 v1.84.0】增加 forceSync 参数，清除缓存后强制从后端同步
  static Future<int> syncQuotaFromBackend({bool forceSync = false}) async {
    // 【修复 v1.84.0】如果本地为0但 forceSync=true，先尝试后端同步（即使上一次缓存了0）
    final prefs = await SharedPreferences.getInstance();
    final syncId = await _getCurrentSyncIdAsync();
    final cached = prefs.getInt('guardian_card_gift_remaining_$syncId') ?? 0;

    try {
      // 方案1：优先使用 /card/list（后端会懒检查过期卡并退回）
      final cardListRes = await CardService.listMyCards();
      if (cardListRes['success'] == true) {
        final stats = cardListRes['stats'] as Map<String, dynamic>?;
        if (stats != null) {
          final backendAvailable = (stats['available_cards'] as int?) ?? 0;
          await updateLocalCache(backendAvailable);
          if (kDebugMode) debugPrint('[GuardianCard] syncQuotaFromBackend (card/list): $backendAvailable 张 (forceSync=$forceSync)');
          return backendAvailable;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[GuardianCard] syncQuotaFromBackend (card/list) 失败: $e');
    }

    // 方案2：备用 /invite/stats
    try {
      final res = await CardService.getInviteStats();
      if (res['success'] == true) {
        final backendAvailable = (res['available_cards'] as int?) ?? 0;
        await updateLocalCache(backendAvailable);
        if (kDebugMode) debugPrint('[GuardianCard] syncQuotaFromBackend (invite/stats): $backendAvailable 张 (forceSync=$forceSync)');
        return backendAvailable;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[GuardianCard] syncQuotaFromBackend (invite/stats) 失败: $e');
    }

    // 失败时返回本地缓存值
    if (kDebugMode) debugPrint('[GuardianCard] syncQuotaFromBackend 失败，使用本地缓存: $cached 张 (syncId=$syncId, forceSync=$forceSync)');
    return cached;
  }

  /// 【新增 v1.84.0】强制从后端同步额度（清除缓存后调用）
  static Future<int> forceSyncFromBackend() async {
    if (kDebugMode) debugPrint('[GuardianCard] forceSyncFromBackend() 开始强制同步...');
    final result = await syncQuotaFromBackend(forceSync: true);
    if (kDebugMode) debugPrint('[GuardianCard] forceSyncFromBackend() 完成，后端返回: $result 张');
    return result;
  }

  /// 【新增 v1.84.0】保存发送失败的守护卡到重试队列
  static Future<void> saveFailedCard(Map<String, dynamic> cardData) async {
    final prefs = await SharedPreferences.getInstance();
    final syncId = await _getCurrentSyncIdAsync();
    final key = 'guardian_card_failed_queue_$syncId';
    final existing = prefs.getString(key) ?? '[]';
    try {
      final List<dynamic> queue = jsonDecode(existing);
      queue.add({
        ...cardData,
        'retry_count': 0,
        'saved_at': DateTime.now().toIso8601String(),
      });
      await prefs.setString(key, jsonEncode(queue));
      if (kDebugMode) debugPrint('[GuardianCard] saveFailedCard: 已保存到重试队列 (${queue.length}条)');
    } catch (e) {
      if (kDebugMode) debugPrint('[GuardianCard] saveFailedCard 失败: $e');
    }
  }

  /// 【新增 v1.84.0】获取重试队列
  static Future<List<Map<String, dynamic>>> getFailedQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final syncId = await _getCurrentSyncIdAsync();
    final key = 'guardian_card_failed_queue_$syncId';
    final existing = prefs.getString(key) ?? '[]';
    try {
      final List<dynamic> queue = jsonDecode(existing);
      return queue.map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[GuardianCard] getFailedQueue 失败: $e');
      return [];
    }
  }

  /// 【新增 v1.84.0】重试发送失败的守护卡
  static Future<Map<String, dynamic>> retryFailedCards() async {
    final prefs = await SharedPreferences.getInstance();
    final syncId = await _getCurrentSyncIdAsync();
    final key = 'guardian_card_failed_queue_$syncId';
    final existing = prefs.getString(key) ?? '[]';
    try {
      final List<dynamic> queue = jsonDecode(existing);
      if (queue.isEmpty) {
        return {'success': true, 'retried': 0, 'succeeded': 0};
      }

      int succeeded = 0;
      final List<dynamic> remaining = [];
      for (final item in queue) {
        final card = Map<String, dynamic>.from(item);
        final message = card['message']?.toString() ?? '';
        final recipientName = card['recipientName']?.toString();
        if (message.isEmpty) continue;
        final result = await sendCardWithBackend(
          message: message,
          recipientName: recipientName,
        );
        if (result['success'] == true) {
          succeeded++;
        } else {
          remaining.add(card);
        }
      }
      await prefs.setString(key, jsonEncode(remaining));
      if (kDebugMode) {
        debugPrint('[GuardianCard] retryFailedCards: 重试${queue.length}条，成功$succeeded条，剩余${remaining.length}条');
      }
      return {
        'success': true,
        'retried': queue.length,
        'succeeded': succeeded,
        'remaining': remaining.length,
      };
    } catch (e) {
      if (kDebugMode) debugPrint('[GuardianCard] retryFailedCards 失败: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 【新增 v1.84.0】清空重试队列
  static Future<void> clearFailedQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final syncId = await _getCurrentSyncIdAsync();
    final key = 'guardian_card_failed_queue_$syncId';
    await prefs.remove(key);
    if (kDebugMode) debugPrint('[GuardianCard] clearFailedQueue: 已清空重试队列');
  }
}
