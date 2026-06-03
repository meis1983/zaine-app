// lib/services/api/peace_service.dart
// 平安确认 API 服务

import '../api_service.dart';

/// 平安确认服务
/// 守护者 → 被守护者：请求平安确认 / 查看状态
/// 被守护者 → 守护者：确认平安
class PeaceService {
  /// 守护者：向被守护者发送平安确认请求
  static Future<Map<String, dynamic>> requestPeace(int userId) async {
    return ApiService.post(
      '/api/peace/request',
      body: {'user_id': userId},
    );
  }

  /// 被守护者：获取待确认的平安确认请求列表
  static Future<Map<String, dynamic>> getPendingRequests() async {
    return ApiService.get('/api/peace/pending');
  }

  /// 被守护者：确认平安
  static Future<Map<String, dynamic>> confirmPeace(int requestId) async {
    return ApiService.post(
      '/api/peace/confirm',
      body: {'request_id': requestId},
    );
  }

  /// 守护者：查看已发送的请求及状态
  static Future<Map<String, dynamic>> getSentRequests() async {
    return ApiService.get('/api/peace/sent');
  }
}
