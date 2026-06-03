/// Watch 数据推送服务
///
/// 负责将 iPhone 端的健康数据、守护圈信息等推送到 Apple Watch。
/// 同时更新 Widget Complications 数据到共享 UserDefaults。
/// 使用 watch_connectivity 插件实现双向通信。
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:watch_connectivity/watch_connectivity.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WatchDataService {
  static final WatchDataService _instance = WatchDataService._();
  factory WatchDataService() => _instance;
  WatchDataService._();

  final WatchConnectivity _wc = WatchConnectivity();
  bool _isSupported = false;
  bool _isPaired = false;
  bool _isReachable = false;

  /// 初始化监听
  Future<void> init() async {
    try {
      _isSupported = await _wc.isSupported;
      if (!_isSupported) {
        debugPrint('[WatchData] WatchConnectivity 不支持');
        return;
      }

      // 注意: watch_connectivity 0.2.8 版本不支持 connectivityStream
      // 连接状态变化需要通过其他方式检测（如定时轮询或在相关页面手动调用）

      await _updateState();
      debugPrint('[WatchData] 初始化完成, paired=$_isPaired, reachable=$_isReachable');
    } catch (e) {
      debugPrint('[WatchData] 初始化失败: $e');
    }
  }

  Future<void> _updateState() async {
    _isPaired = await _wc.isPaired;
    _isReachable = await _wc.isReachable;
  }

  /// 推送健康数据摘要到 Watch
  ///
  /// [summary] 来自 HealthService.getHealthSummary() 的数据
  Future<bool> pushHealthSummary(Map<String, dynamic> summary) async {
    if (!_isSupported || !_isPaired) return false;

    try {
      // 过滤出 Watch 需要的关键指标
      final watchData = <String, dynamic>{};

      if (summary.containsKey('heart_rate')) {
        watchData['heart_rate'] = summary['heart_rate'];
      }
      if (summary.containsKey('blood_oxygen')) {
        watchData['blood_oxygen'] = (double.tryParse(
                summary['blood_oxygen'].toString()) ?? 0)
            .toStringAsFixed(0);
      }
      if (summary.containsKey('steps')) {
        watchData['steps'] = summary['steps'];
      }
      if (summary.containsKey('resting_heart_rate')) {
        watchData['resting_heart_rate'] = summary['resting_heart_rate'];
      }
      if (summary.containsKey('hrv')) {
        watchData['hrv'] = summary['hrv'];
      }
      if (summary.containsKey('body_temperature')) {
        watchData['body_temperature'] =
            (double.tryParse(summary['body_temperature'].toString()) ?? 0)
                .toStringAsFixed(1);
      }
      if (summary.containsKey('sleep_total')) {
        watchData['sleep_total'] = summary['sleep_total'];
      }
      if (summary.containsKey('has_menstruation')) {
        watchData['has_menstruation'] = summary['has_menstruation'];
      }

      // 添加推送时间戳
      watchData['push_timestamp'] = DateTime.now().millisecondsSinceEpoch;
      watchData['push_type'] = 'health_summary';

      // 使用 sendMessage（实时推送，Watch 必须可达）
      if (_isReachable) {
        await _wc.sendMessage(watchData);
        debugPrint('[WatchData] 健康数据已推送到 Watch (实时)');
        return true;
      }

      // 使用 transferUserInfo（后台传输，Watch 不需要可达）
      // 使用 applicationContext 以确保数据不重复累积
      await _wc.updateApplicationContext(watchData);
      debugPrint('[WatchData] 健康数据已传输到 Watch (后台)');
      return true;
    } catch (e) {
      debugPrint('[WatchData] 推送健康数据失败: $e');
      return false;
    }
  }

  /// 推送守护圈信息到 Watch
  Future<bool> pushGuardianInfo({
    required int guardianCount,
    String? membershipLevel,
  }) async {
    if (!_isSupported || !_isPaired) return false;

    try {
      final data = <String, dynamic>{
        'push_type': 'guardian_info',
        'guardian_count': guardianCount,
        'membership_level': membershipLevel ?? 'free',
        'push_timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      if (_isReachable) {
        await _wc.sendMessage(data);
      } else {
        await _wc.updateApplicationContext(data);
      }
      debugPrint('[WatchData] 守护圈信息已推送: $guardianCount 人');
      return true;
    } catch (e) {
      debugPrint('[WatchData] 推送守护圈信息失败: $e');
      return false;
    }
  }

  /// 推送经期状态到 Watch
  Future<bool> pushMenstruationStatus({
    required bool isInPeriod,
    required int cycleDay,
    String? predictedNextDate,
  }) async {
    if (!_isSupported || !_isPaired) return false;

    try {
      final data = <String, dynamic>{
        'push_type': 'menstruation_status',
        'is_in_period': isInPeriod,
        'cycle_day': cycleDay,
        'predicted_next_date': predictedNextDate ?? '',
        'push_timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      if (_isReachable) {
        await _wc.sendMessage(data);
      } else {
        await _wc.updateApplicationContext(data);
      }
      debugPrint('[WatchData] 经期状态已推送: cycleDay=$cycleDay');
      return true;
    } catch (e) {
      debugPrint('[WatchData] 推送经期状态失败: $e');
      return false;
    }
  }

  // ==================== Widget Complications 数据同步 ====================

  /// 缓存的 Widget 数据
  Map<String, dynamic> _cachedWidgetData = {};

  /// 更新 Widget Complications 数据
  ///
  /// 将数据保存到共享 UserDefaults，供 Watch Widget 读取
  Future<bool> updateWidgetData({
    int? heartRate,
    int? bloodOxygen,
    int? sleepMinutes,
    bool? isInMenstruation,
    int? cycleDay,
    int? guardianCount,
    DateTime? lastCheckinTime,
    bool? hasAlert,
    String? alertType,
  }) async {
    try {
      // 更新缓存
      if (heartRate != null) _cachedWidgetData['heart_rate'] = heartRate;
      if (bloodOxygen != null) _cachedWidgetData['blood_oxygen'] = bloodOxygen;
      if (sleepMinutes != null) _cachedWidgetData['sleep_minutes'] = sleepMinutes;
      if (isInMenstruation != null) _cachedWidgetData['is_in_menstruation'] = isInMenstruation;
      if (cycleDay != null) _cachedWidgetData['cycle_day'] = cycleDay;
      if (guardianCount != null) _cachedWidgetData['guardian_count'] = guardianCount;
      if (lastCheckinTime != null) {
        _cachedWidgetData['last_checkin_time'] = lastCheckinTime.millisecondsSinceEpoch;
      }
      if (hasAlert != null) _cachedWidgetData['has_alert'] = hasAlert;
      if (alertType != null) _cachedWidgetData['alert_type'] = alertType;

      _cachedWidgetData['update_timestamp'] = DateTime.now().millisecondsSinceEpoch;

      // 保存到 SharedPreferences（使用 app group 共享）
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_cachedWidgetData);
      await prefs.setString('widget_data', jsonStr);

      debugPrint('[WatchData] Widget 数据已更新: ${jsonStr.substring(0, jsonStr.length > 100 ? 100 : jsonStr.length)}...');
      return true;
    } catch (e) {
      debugPrint('[WatchData] 更新 Widget 数据失败: $e');
      return false;
    }
  }

  /// 从健康摘要批量更新 Widget 数据
  Future<bool> syncWidgetFromHealthSummary(Map<String, dynamic> summary, {
    int? guardianCount,
    bool? hasAlert,
    String? alertType,
  }) async {
    return updateWidgetData(
      heartRate: summary['heart_rate'] != null
          ? int.tryParse(summary['heart_rate'].toString())
          : null,
      bloodOxygen: summary['blood_oxygen'] != null
          ? (double.tryParse(summary['blood_oxygen'].toString())?.toInt())
          : null,
      sleepMinutes: summary['sleep_total'] != null
          ? (summary['sleep_total'] is int ? summary['sleep_total'] : int.tryParse(summary['sleep_total'].toString()))
          : null,
      isInMenstruation: summary['has_menstruation'] == true,
      cycleDay: summary['cycle_day'] != null
          ? (summary['cycle_day'] is int ? summary['cycle_day'] : int.tryParse(summary['cycle_day'].toString()))
          : null,
      guardianCount: guardianCount ?? _cachedWidgetData['guardian_count'] ?? 0,
      hasAlert: hasAlert ?? _cachedWidgetData['has_alert'] ?? false,
      alertType: alertType ?? _cachedWidgetData['alert_type'],
    );
  }

  /// 触发 Widget 刷新（通过更新 timeline）
  ///
  /// 在 iOS 端调用此方法后，Watch Widget 会在下次刷新时读取新数据
  Future<void> reloadWidgetTimelines() async {
    // Widget 会自动根据 timeline 策略刷新
    // 这里可以添加额外的刷新逻辑
    debugPrint('[WatchData] Widget timelines 刷新请求已发送');
  }

  /// 推送订阅状态到 Watch
  Future<bool> pushSubscriptionStatus({
    required String level,
    String? expiresAt,
  }) async {
    if (!_isSupported || !_isPaired) return false;

    try {
      final data = <String, dynamic>{
        'push_type': 'subscription_status',
        'membership_level': level,
        'expires_at': expiresAt ?? '',
        'push_timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      if (_isReachable) {
        await _wc.sendMessage(data);
      } else {
        await _wc.updateApplicationContext(data);
      }
      return true;
    } catch (e) {
      debugPrint('[WatchData] 推送订阅状态失败: $e');
      return false;
    }
  }
}
