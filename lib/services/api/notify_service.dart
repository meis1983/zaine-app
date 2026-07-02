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
  ///
  /// 【v1.93.0 C-2】支持附带生命体征数据（心率、血氧、体温、血压等），
  /// 帮助守护者在收到通知时判断跌倒的严重程度。
  static Future<Map<String, dynamic>> notifyGuardiansAboutFall({
    required DateTime timestamp,
    String? latitude,
    String? longitude,
    Map<String, dynamic>? healthSummary, // 生命体征数据
  }) async {
    final body = <String, dynamic>{
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
    };

    if (healthSummary != null && healthSummary.isNotEmpty) {
      body['health_summary'] = _extractVitalSigns(healthSummary);
    }

    return await ApiService.post('/api/notify/guardians-fall', body: body);
  }

  /// 从健康摘要中提取跌倒通知需要的生命体征
  static Map<String, dynamic> _extractVitalSigns(Map<String, dynamic> summary) {
    final vitals = <String, dynamic>{};

    if (summary.containsKey('heart_rate')) {
      vitals['heart_rate'] = summary['heart_rate'];
    }
    if (summary.containsKey('blood_oxygen')) {
      final bo = double.tryParse(summary['blood_oxygen'].toString()) ?? 0;
      vitals['blood_oxygen'] = bo > 1.0 ? bo : (bo * 100).toStringAsFixed(0);
    }
    if (summary.containsKey('body_temperature')) {
      vitals['body_temperature'] = summary['body_temperature'];
    }
    if (summary.containsKey('bp_systolic') && summary.containsKey('bp_diastolic')) {
      vitals['bp_systolic'] = summary['bp_systolic'];
      vitals['bp_diastolic'] = summary['bp_diastolic'];
    }
    if (summary.containsKey('resting_heart_rate')) {
      vitals['resting_heart_rate'] = summary['resting_heart_rate'];
    }
    if (summary.containsKey('hrv')) {
      vitals['hrv'] = summary['hrv'];
    }
    if (summary.containsKey('respiratory_rate')) {
      vitals['respiratory_rate'] = summary['respiratory_rate'];
    }

    return vitals;
  }

  /// 通知守护人：用户离开安全围栏
  static Future<Map<String, dynamic>> notifyGuardiansAboutFenceExit({
    required Map<String, dynamic> fence,
  }) async {
    return await ApiService.post('/api/notify/guardians-fence-exit', body: {
      'fence_name': fence['name'] ?? '安全区域',
      'fence_type': fence['type'] ?? 'custom',
      'latitude': fence['latitude'],
      'longitude': fence['longitude'],
      'radius': fence['radius'],
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
