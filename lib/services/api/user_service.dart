// lib/services/api/user_service.dart
// 用户档案 API（v1.4）

import '../api_service.dart';

class UserService {
  /// 获取用户档案
  static Future<Map<String, dynamic>> getProfile() async {
    return await ApiService.get('/api/user/profile');
  }

  /// 更新用户档案
  static Future<Map<String, dynamic>> updateProfile(
      Map<String, dynamic> profile) async {
    return await ApiService.put('/api/user/profile', body: profile);
  }

  /// 同步健康体征指标 (v2.0)
  static Future<Map<String, dynamic>> syncHealthMetrics(
      Map<String, dynamic> metrics) async {
    return await ApiService.put('/api/user/health', body: {'metrics': metrics});
  }

  /// 通过手机号查找用户（用于平安确认等场景）
  static Future<Map<String, dynamic>> lookupByPhone(String phone) async {
    return ApiService.get('/api/users/lookup?phone=$phone');
  }

  /// 批量查询联系人状态（守护圈性能优化 v2.0）
  static Future<Map<String, dynamic>> batchLookup(List<String> phones) async {
    return ApiService.post('/api/users/batch-lookup', body: {'phones': phones});
  }

  /// 查询指定用户今日是否已签到（用于守护圈联系人状态）
  static Future<Map<String, dynamic>> queryCheckinStatus(int targetUserId) async {
    return ApiService.get('/api/checkin/user-status?target_user_id=$targetUserId');
  }

  /// 删除当前用户账号（苹果审核强制要求）
  static Future<Map<String, dynamic>> deleteAccount() async {
    return await ApiService.delete('/api/user/account');
  }
}
