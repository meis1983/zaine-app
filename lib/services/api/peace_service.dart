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

  /// 被守护者：确认平安（方案C 合并版，支持响应类型）
  /// [responseType]：'ok'(我没事) / 'checkin'(立即签到) / 'help'(需要帮助)
  /// [message]：仅 help 态可选留言（选填，最长100字，仅发送给守护者）
  static Future<Map<String, dynamic>> confirmPeace(
    int requestId, {
    String responseType = 'ok',
    String? message,
  }) async {
    final body = <String, dynamic>{
      'request_id': requestId,
      'response_type': responseType,
    };
    if (message != null) {
      body['message'] = message;
    }
    return ApiService.post(
      '/api/peace/confirm',
      body: body,
    );
  }

  /// 守护者：查看已发送的请求及状态
  static Future<Map<String, dynamic>> getSentRequests() async {
    return ApiService.get('/api/peace/sent');
  }

  /// 【方案三】守护者：标记"需要帮助"为已处理（status 2 → 0 归零）
  static Future<Map<String, dynamic>> acknowledgePeace(int requestId) async {
    return ApiService.post(
      '/api/peace/acknowledge',
      body: {'request_id': requestId},
    );
  }
}
