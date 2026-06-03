// lib/services/api/checkin_service.dart
// 签到相关 API（v1.4）

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
  static Future<Map<String, dynamic>> getHistory({int page = 1}) async {
    return await ApiService.get('/api/checkin/history?page=$page');
  }

  /// 【P2】获取历史最高连续签到天数
  static Future<Map<String, dynamic>> getMaxStreak() async {
    return await ApiService.get('/api/checkin/max-streak');
  }
}
