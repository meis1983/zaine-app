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
}
