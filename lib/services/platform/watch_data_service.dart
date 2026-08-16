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

  /// 公开访问器
  bool get isSupported => _isSupported;
  bool get isPaired => _isPaired;
  bool get isReachable => _isReachable;

  /// 初始化监听
  Future<void> init() async {
    try {
      _isSupported = await _wc.isSupported;
      if (!_isSupported) {
        if (kDebugMode) debugPrint('[WatchData] WatchConnectivity 不支持');
        return;
      }

      // 注意: watch_connectivity 0.2.8 版本不支持 connectivityStream
      // 连接状态变化需要通过其他方式检测（如定时轮询或在相关页面手动调用）

      await _updateState();
      if (kDebugMode) debugPrint('[WatchData] 初始化完成, paired=$_isPaired, reachable=$_isReachable');
    } catch (e) {
      if (kDebugMode) debugPrint('[WatchData] 初始化失败: $e');
    }
  }

  Future<void> _updateState() async {
    _isPaired = await _wc.isPaired;
    _isReachable = await _wc.isReachable;
  }

  /// 主动刷新 Watch 连接状态（供 UI 层调用）
  Future<Map<String, bool>> refreshWatchState() async {
    try {
      _isSupported = await _wc.isSupported;
      if (!_isSupported) {
        return {'supported': false, 'paired': false, 'reachable': false};
      }
      _isPaired = await _wc.isPaired;
      _isReachable = await _wc.isReachable;
      if (kDebugMode) {
        debugPrint('[WatchData] 刷新状态: supported=$_isSupported, paired=$_isPaired, reachable=$_isReachable');
      }
      return {
        'supported': _isSupported,
        'paired': _isPaired,
        'reachable': _isReachable,
      };
    } catch (e) {
      if (kDebugMode) debugPrint('[WatchData] 刷新状态失败: $e');
      return {'supported': false, 'paired': false, 'reachable': false};
    }
  }

  /// 推送健康数据摘要到 Watch
  ///
  /// [summary] 来自 HealthService.getHealthSummary() 的数据
  ///
  /// 🔴【v1.97.3 (162) 修复 Bug 5】冷启动时 WCSession 可能尚未激活，_isPaired 在
  /// init() 阶段读到 false 后便不再重查 → 首帧 push 直接 return false 且此后无重试
  /// → Apple Watch 健康速览永远空白。
  /// 修复：① 推送前先 refreshWatchState() 刷新一次配对/可达状态；
  /// ② 若刷新后仍不配对，延迟 5s 自动重试一次（仅一次，不阻塞调用方）。
  Future<bool> pushHealthSummary(Map<String, dynamic> summary) =>
      _pushHealthSummary(summary, allowRetry: true);

  Future<bool> _pushHealthSummary(
    Map<String, dynamic> summary, {
    required bool allowRetry,
  }) async {
    if (!_isSupported) return false;

    // 🔴【v1.97.3 (162)】冷启动保护：未配对时先刷新一次状态
    if (!_isPaired) {
      await refreshWatchState();
    }

    if (!_isPaired) {
      // 延迟 5s 后重试一次（仅一次，避免无限递归）
      if (allowRetry) {
        unawaited(Future.delayed(const Duration(seconds: 5), () async {
          try {
            await refreshWatchState();
            if (_isPaired) {
              await _pushHealthSummary(summary, allowRetry: false);
            }
          } catch (e) {
            if (kDebugMode) debugPrint('[WatchData] 健康数据延迟重试失败(忽略): $e');
          }
        }));
      }
      if (kDebugMode) {
        debugPrint('[WatchData] 健康数据推送跳过：Watch 未配对'
            '（${allowRetry ? "已安排 5s 重试" : "重试后仍不配对"}）');
      }
      return false;
    }

    try {
      // 过滤出 Watch 需要的关键指标
      // 🔴【v1.97.3 修复 Issue A】字段名必须与手表 HealthDetailView 读取的 key 完全一致：
      //   手表读 temperature / sleep / menstrual，手机原发 body_temperature / sleep_total / has_menstruation
      //   → 永远对不上，故此处映射；且手表按 String 读取，统一转 String；睡眠原始单位为分钟 → 转小时。
      // 🔴【v1.97.3 修复】watch UI 实测出现 [11.65, 0.396, 28.73, 64.93, 4] 这类 5 元素串值（HRV 单元）
      //   根因：summary['hrv'] 上游某环节被赋为 List<num>（疑似 health 包版本对 HRV SDNN 数组包装），
      //   直接 .toString() 得到 "[a, b, c, d, e]"，传到手表剥掉 [ ] , 空格后就是看到的串。
      //   修法：所有数值字段统一走 _toWatchScalar() 归一为单个 num，再按字段格式化 String，
      //   即使上游是 List 也只取首个有效元素，避免手表 UI 显示乱码。
      final watchData = <String, dynamic>{};

      if (summary.containsKey('heart_rate')) {
        final v = _toWatchScalar(summary['heart_rate']);
        if (v != null) watchData['heart_rate'] = v.toStringAsFixed(0);
      }
      if (summary.containsKey('blood_oxygen')) {
        final v = _toWatchScalar(summary['blood_oxygen']);
        if (v != null) watchData['blood_oxygen'] = v.toStringAsFixed(0);
      }
      if (summary.containsKey('steps')) {
        final v = _toWatchScalar(summary['steps']);
        if (v != null) watchData['steps'] = v.toStringAsFixed(0);
      }
      if (summary.containsKey('resting_heart_rate')) {
        final v = _toWatchScalar(summary['resting_heart_rate']);
        if (v != null) watchData['resting_heart_rate'] = v.toStringAsFixed(0);
      }
      if (summary.containsKey('hrv')) {
        // HRV SDNN 单位 ms，单值
        final v = _toWatchScalar(summary['hrv']);
        if (v != null) watchData['hrv'] = v.toStringAsFixed(0);
      }
      if (summary.containsKey('body_temperature')) {
        final v = _toWatchScalar(summary['body_temperature']);
        if (v != null) watchData['temperature'] = v.toStringAsFixed(1);
      } else if (summary.containsKey('temperature')) {
        final v = _toWatchScalar(summary['temperature']);
        if (v != null) watchData['temperature'] = v.toStringAsFixed(1);
      }
      if (summary.containsKey('sleep_total')) {
        // 睡眠原始单位为分钟 → 转换为小时字符串（手表 UI 以 h 显示）
        final minutes = _toWatchScalar(summary['sleep_total']) ?? 0;
        watchData['sleep'] = (minutes / 60.0).toStringAsFixed(1);
      } else if (summary.containsKey('sleep')) {
        final v = _toWatchScalar(summary['sleep']);
        if (v != null) watchData['sleep'] = v.toStringAsFixed(1);
      }
      if (summary.containsKey('has_menstruation')) {
        watchData['menstrual'] = (summary['has_menstruation'] == true) ? '经期中' : '未记录';
      } else if (summary.containsKey('menstrual')) {
        watchData['menstrual'] = summary['menstrual'].toString();
      }
      // 🔴【v1.97.3 修复】Apple Watch S9+/iOS26 原生血压趋势写回 HealthKit 标准血压样本，
      //   手机侧已在 health_service 采集 bp_systolic/bp_diastolic → 此处推到 Watch 速览。
      //   无硬件血压计也可读（Watch 自身后台采样）；旧 iOS 设备无此数据则跳过，Watch 显示"未测"。
      if (summary.containsKey('bp_systolic') && summary.containsKey('bp_diastolic')) {
        final sys = _toWatchScalar(summary['bp_systolic']);
        final dia = _toWatchScalar(summary['bp_diastolic']);
        if (sys != null && dia != null) {
          watchData['blood_pressure'] = '${sys.toStringAsFixed(0)}/${dia.toStringAsFixed(0)}';
        }
      }

      // 添加推送时间戳
      watchData['push_timestamp'] = DateTime.now().millisecondsSinceEpoch;
      watchData['push_type'] = 'health_summary';

      // 使用 sendMessage（实时推送，Watch 必须可达）
      if (_isReachable) {
        await _wc.sendMessage(watchData);
        if (kDebugMode) debugPrint('[WatchData] 健康数据已推送到 Watch (实时)');
        return true;
      }

      // 使用 transferUserInfo（后台传输，Watch 不需要可达）
      // 使用 applicationContext 以确保数据不重复累积
      await _wc.updateApplicationContext(watchData);
      if (kDebugMode) debugPrint('[WatchData] 健康数据已传输到 Watch (后台)');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[WatchData] 推送健康数据失败: $e');
      return false;
    }
  }

  /// 🔴【v1.97.3 修复】把 summary 字段归一为单个 double。
  /// 背景：iPhone 端 push 字段历史上曾直接 .toString()，当上游 health 包返回 List<num> 时
  /// （实测 hrv 出现 [11.65, 0.396, 28.73, 64.93, 4]）会输出 "[a, b, c, d, e]" 串到手表，
  /// UI 剥掉 [ ] 后呈现为多数字串。统一入口收口后，所有数值字段都强制走单值归一。
  /// - num → 直接 .toDouble()
  /// - List → 取首个 num 元素（保留首个 SDNN 样本，避免 watch 乱码）
  /// - String → 尝试解析为 double，失败回 null（由调用方判 null 跳过）
  static double? _toWatchScalar(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is List) {
      for (final e in v) {
        if (e is num) return e.toDouble();
      }
      return null;
    }
    final s = v.toString();
    return double.tryParse(s);
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
      if (kDebugMode) debugPrint('[WatchData] 守护圈信息已推送: $guardianCount 人');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[WatchData] 推送守护圈信息失败: $e');
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
      if (kDebugMode) debugPrint('[WatchData] 经期状态已推送: cycleDay=$cycleDay');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[WatchData] 推送经期状态失败: $e');
      return false;
    }
  }

  // ==================== Widget Complications 数据同步 ====================

  /// 缓存的 Widget 数据
  final Map<String, dynamic> _cachedWidgetData = {};

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

      if (kDebugMode) debugPrint('[WatchData] Widget 数据已更新: ${jsonStr.substring(0, jsonStr.length > 100 ? 100 : jsonStr.length)}...');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[WatchData] 更新 Widget 数据失败: $e');
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
    if (kDebugMode) debugPrint('[WatchData] Widget timelines 刷新请求已发送');
  }

  /// 推送签到状态到 Watch（手机端主动签到后同步，让手表「已签到」状态实时一致）
  ///
  /// 【v1.97.1+155 修复】此前手机端签到成功后没有任何 push 给 Watch，
  /// 手表仍显示「可打卡」（因手表 hasCheckedInToday 只在自己发起签到收到 checkin_ack 时才更新）。
  /// 现手机签到后立即推送 checkin_status，Watch 端收到后 markCheckedInToday()。
  Future<bool> pushCheckinStatus({
    required bool checkedInToday,
    String? checkinDate,
  }) async {
    if (!_isSupported || !_isPaired) return false;

    try {
      final data = <String, dynamic>{
        'action': 'checkin_status',
        'checked_in_today': checkedInToday,
        'last_check_in': checkinDate ?? '',
        'push_timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      if (_isReachable) {
        await _wc.sendMessage(data);
      } else {
        await _wc.updateApplicationContext(data);
      }
      if (kDebugMode) debugPrint('[WatchData] 签到状态已推送: checkedInToday=$checkedInToday');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[WatchData] 推送签到状态失败: $e');
      return false;
    }
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
      if (kDebugMode) debugPrint('[WatchData] 推送订阅状态失败: $e');
      return false;
    }
  }
}
