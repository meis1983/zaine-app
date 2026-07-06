// lib/services/api/checkin_service.dart
// 签到相关 API（v1.4）

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_service.dart';

class CheckinService {
  /// 提交签到
  static Future<Map<String, dynamic>> checkIn({
    required String date,
    required int mood,
  }) async {
    return await ApiService.post('/api/checkin/do', body: {
      'date': date,
      'mood': mood,
    });
  }

  /// 获取今日签到状态
  static Future<Map<String, dynamic>> getTodayStatus() async {
    return await ApiService.get('/api/checkin/status');
  }

  /// 获取签到历史
  static Future<Map<String, dynamic>> getHistory({int page = 1, int? pageSize}) async {
    final size = pageSize ?? 20;
    return await ApiService.get('/api/checkin/history?page=$page&page_size=$size');
  }

  /// 【P2】获取历史最高连续签到天数
  static Future<Map<String, dynamic>> getMaxStreak() async {
    return await ApiService.get('/api/checkin/max-streak');
  }

  // ==================== 离线队列管理（v1.93.9） ====================

  static const String _offlineQueueKey = 'checkin_offline_queue';

  /// 保存签到请求到离线队列
  static Future<void> saveToOfflineQueue({
    required String date,
    required int mood,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_offlineQueueKey) ?? '[]';
      final queue = jsonDecode(queueJson) as List<dynamic>;

      // 添加新请求（包含时间戳，用于按顺序同步）
      queue.add({
        'date': date,
        'mood': mood,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      // 限制队列长度（最多保存 30 条）
      if (queue.length > 30) {
        queue.removeAt(0);
      }

      await prefs.setString(_offlineQueueKey, jsonEncode(queue));

      if (kDebugMode) {
        debugPrint('[CheckinService] ✅ 已保存到离线队列，队列长度=${queue.length}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CheckinService] ❌ 保存离线队列失败: $e');
      }
    }
  }

  /// 同步离线队列到服务器
  /// 返回：成功同步的数量
  static Future<int> syncOfflineQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_offlineQueueKey) ?? '[]';
      final queue = jsonDecode(queueJson) as List<dynamic>;

      if (queue.isEmpty) {
        if (kDebugMode) debugPrint('[CheckinService] 离线队列为空，无需同步');
        return 0;
      }

      if (kDebugMode) {
        debugPrint('[CheckinService] 开始同步离线队列，共 ${queue.length} 条');
      }

      int successCount = 0;
      final failedItems = <dynamic>[];

      for (final item in queue) {
        try {
          final date = item['date'] as String;
          final mood = item['mood'] as int;

          final res = await checkIn(date: date, mood: mood);

          if (res['success'] == true) {
            successCount++;
            if (kDebugMode) {
              debugPrint('[CheckinService] ✅ 离线签到同步成功: date=$date');
            }
          } else {
            // 服务端返回失败（可能是重复签到等），也算成功（避免无限重试）
            failedItems.add(item);
            if (kDebugMode) {
              debugPrint('[CheckinService] ⚠️ 离线签到同步失败（服务端拒绝）: date=$date, error=${res['error']}');
            }
          }
        } catch (e) {
          // 网络错误，保留到失败列表，下次重试
          failedItems.add(item);
          if (kDebugMode) {
            debugPrint('[CheckinService] ❌ 离线签到同步异常: $e');
          }
        }
      }

      // 保存失败的条目（用于下次重试）
      await prefs.setString(_offlineQueueKey, jsonEncode(failedItems));

      if (kDebugMode) {
        debugPrint('[CheckinService] ✅ 离线队列同步完成: 成功=$successCount, 失败=${failedItems.length}');
      }

      return successCount;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CheckinService] ❌ 同步离线队列异常: $e');
      }
      return 0;
    }
  }

  /// 获取离线队列长度（用于调试和 UI 提示）
  static Future<int> getOfflineQueueCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_offlineQueueKey) ?? '[]';
      final queue = jsonDecode(queueJson) as List<dynamic>;
      return queue.length;
    } catch (e) {
      return 0;
    }
  }
}
