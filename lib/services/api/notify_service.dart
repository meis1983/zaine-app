// lib/services/api/notify_service.dart
// 通知提醒 API（v1.9.77）

import '../api_service.dart';

class NotifyService {
  /// 提醒待激活用户下载APP并签到
  static Future<Map<String, dynamic>> remindDownload(int receiverUserId) async {
    return await ApiService.post('/api/notify/remind-download', body: {
      'receiver_user_id': receiverUserId,
    });
  }

  /// 发送健康异常报警到守护圈 (v2.0)
  static Future<Map<String, dynamic>> sendHealthAlert(List<dynamic> alerts) async {
    return await ApiService.post('/api/notify/health-alert', body: {
      'alerts': alerts,
    });
  }

  /// 通知守护人：定时平安确认超时未确认
  static Future<Map<String, dynamic>> notifyGuardiansAboutMissedCheckIn(int missedCount) async {
    return await ApiService.post('/api/notify/guardians-missed-checkin', body: {
      'missed_count': missedCount,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// 通知守护人：检测到跌倒事件
  static Future<Map<String, dynamic>> notifyGuardiansAboutFall({
    required DateTime timestamp,
    String? latitude,
    String? longitude,
  }) async {
    return await ApiService.post('/api/notify/guardians-fall', body: {
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
    });
  }
}
