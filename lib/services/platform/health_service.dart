import 'package:health/health.dart';
import 'package:flutter/foundation.dart';
import '../api/checkin_service.dart';
import '../api/user_service.dart';
import '../api/notify_service.dart';
import '../api/sync_service.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'watch_data_service.dart';

/// 健康数据服务 (Apple Watch / HealthKit 集成)
/// 实现「多维度生命体征监测」的核心逻辑
class HealthService {
  static final Health _health = Health();
  
  // 扩展后的健康数据类型
  static final List<HealthDataType> _types = [
    HealthDataType.HEART_RATE,           // 心率
    HealthDataType.BLOOD_OXYGEN,         // 血氧
    HealthDataType.SLEEP_ASLEEP,         // 睡眠状态
    HealthDataType.SLEEP_AWAKE,          // 清醒时长
    HealthDataType.SLEEP_DEEP,           // 深度睡眠
    HealthDataType.SLEEP_REM,            // REM 睡眠
    // HealthDataType.MENSTRUATION_FLOW,    // 经期流量（当前 health 包版本不支持，待升级后启用）
    HealthDataType.RESPIRATORY_RATE,     // 呼吸频率 (夜晚体征)
    HealthDataType.RESTING_HEART_RATE,   // 静息心率
    HealthDataType.HEART_RATE_VARIABILITY_SDNN, // 心率变异性 (HRV)
    HealthDataType.BODY_TEMPERATURE,     // 体温 (手腕温度)
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,  // 收缩压 (高压)
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC, // 舒张压 (低压)
  ];

  // 权限定义：只读
  static final List<HealthDataAccess> _permissions = _types.map((e) => HealthDataAccess.READ).toList();

  static List<HealthDataType> _coreTypes() => [
        HealthDataType.HEART_RATE,
        HealthDataType.BLOOD_OXYGEN,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_AWAKE,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_REM,
      ];

  static double? _extractNumeric(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is NumericHealthValue) return value.numericValue.toDouble();
    final str = value.toString();
    final match = RegExp(r'-?\d+(\.\d+)?').firstMatch(str);
    if (match == null) return null;
    return double.tryParse(match.group(0) ?? '');
  }

  /// 请求 HealthKit 全量权限
  static Future<bool> requestPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      // 在部分旧版本或模拟器上，某些类型可能不可用，这里使用 try-catch
      bool authorized = await _health.requestAuthorization(_types, permissions: _permissions);
      if (kDebugMode) debugPrint('[HealthService] HealthKit 深度授权结果: $authorized');
      await prefs.setBool('health_last_authorized', authorized);
      await prefs.setString('health_last_auth_error', '');
      await prefs.setString('health_last_auth_time', DateTime.now().toIso8601String());
      return authorized;
    } catch (e) {
      if (kDebugMode) debugPrint('[HealthService] 请求权限异常: $e');
      await prefs.setBool('health_last_authorized', false);
      await prefs.setString('health_last_auth_error', e.toString());
      await prefs.setString('health_last_auth_time', DateTime.now().toIso8601String());

      try {
        final core = _coreTypes();
        final corePerms = core.map((_) => HealthDataAccess.READ).toList();
        final coreAuthorized = await _health.requestAuthorization(core, permissions: corePerms);
        await prefs.setBool('health_last_authorized', coreAuthorized);
        await prefs.setString('health_last_auth_error', coreAuthorized ? '' : 'core_not_authorized');
        await prefs.setString('health_last_auth_time', DateTime.now().toIso8601String());
        if (kDebugMode) debugPrint('[HealthService] HealthKit 核心授权结果: $coreAuthorized');
        return coreAuthorized;
      } catch (e2) {
        await prefs.setBool('health_last_authorized', false);
        await prefs.setString('health_last_auth_error', e2.toString());
        await prefs.setString('health_last_auth_time', DateTime.now().toIso8601String());
        return false;
      }
    }
  }

  static bool _isSleepType(HealthDataType t) {
    return t == HealthDataType.SLEEP_ASLEEP ||
        t == HealthDataType.SLEEP_AWAKE ||
        t == HealthDataType.SLEEP_DEEP ||
        t == HealthDataType.SLEEP_REM;
  }

  /// 获取多维度健康摘要
  static Future<Map<String, dynamic>> getHealthSummary() async {
    final Map<String, dynamic> summary = {};
    try {
      final prefs = await SharedPreferences.getInstance();
      final authorized = await requestPermissions();
      if (!authorized) {
        await prefs.setString('health_last_fetch_error', 'not_authorized');
        await prefs.setString('health_last_fetch_time', DateTime.now().toIso8601String());
        return summary;
      }

      final now = DateTime.now();
      final startWide = now.subtract(const Duration(days: 7));
      final startSleep = now.subtract(const Duration(hours: 48));

      final typeCounts = <String, int>{};
      final typeErrors = <String, String>{};
      final all = <HealthDataPoint>[];

      for (final t in _types) {
        final startTime = _isSleepType(t) ? startSleep : startWide;
        try {
          final part = await _health.getHealthDataFromTypes(
            types: [t],
            startTime: startTime,
            endTime: now,
          );
          typeCounts[t.name] = part.length;
          all.addAll(part);
        } catch (e) {
          typeErrors[t.name] = e.toString();
        }
      }

      await prefs.setInt('health_last_fetch_count', all.length);
      await prefs.setString('health_last_fetch_time', DateTime.now().toIso8601String());
      await prefs.setString('health_last_fetch_type_counts', typeCounts.toString());
      await prefs.setString('health_last_fetch_type_errors', typeErrors.toString());

      if (all.isEmpty) {
        await prefs.setString('health_last_fetch_error', typeErrors.isNotEmpty ? 'type_errors' : 'no_data');
        return summary;
      }

      await prefs.setString('health_last_fetch_error', '');

      final latestAt = <String, DateTime>{};
      for (var point in all) {
        final type = point.type;
        final value = point.value;
        final numVal = _extractNumeric(value);
        if (numVal == null) continue;

        final pointTime = point.dateTo;
        
        // 复杂的分类聚合逻辑
        if (type == HealthDataType.HEART_RATE) {
          final prev = latestAt['heart_rate'];
          if (prev == null || pointTime.isAfter(prev)) {
            summary['heart_rate'] = numVal.toStringAsFixed(0);
            latestAt['heart_rate'] = pointTime;
          }
        } else if (type == HealthDataType.BLOOD_OXYGEN) {
          final prev = latestAt['blood_oxygen'];
          if (prev == null || pointTime.isAfter(prev)) {
            summary['blood_oxygen'] = numVal;
            latestAt['blood_oxygen'] = pointTime;
          }
        } else if (type == HealthDataType.SLEEP_ASLEEP) {
          summary['sleep_asleep'] = (summary['sleep_asleep'] ?? 0) + numVal.round();
        } else if (type == HealthDataType.SLEEP_AWAKE) {
          summary['sleep_awake'] = (summary['sleep_awake'] ?? 0) + numVal.round();
        } else if (type == HealthDataType.SLEEP_DEEP) {
          summary['sleep_deep'] = (summary['sleep_deep'] ?? 0) + numVal.round();
        } else if (type == HealthDataType.SLEEP_REM) {
          summary['sleep_rem'] = (summary['sleep_rem'] ?? 0) + numVal.round();
        } else if (type == HealthDataType.RESPIRATORY_RATE) {
          final prev = latestAt['respiratory_rate'];
          if (prev == null || pointTime.isAfter(prev)) {
            summary['respiratory_rate'] = numVal.toStringAsFixed(0);
            latestAt['respiratory_rate'] = pointTime;
          }
        } else if (type == HealthDataType.RESTING_HEART_RATE) {
          final prev = latestAt['resting_heart_rate'];
          if (prev == null || pointTime.isAfter(prev)) {
            summary['resting_heart_rate'] = numVal.toStringAsFixed(0);
            latestAt['resting_heart_rate'] = pointTime;
          }
        } else if (type == HealthDataType.HEART_RATE_VARIABILITY_SDNN) {
          final prev = latestAt['hrv'];
          if (prev == null || pointTime.isAfter(prev)) {
            summary['hrv'] = numVal;
            latestAt['hrv'] = pointTime;
          }
        } else if (type == HealthDataType.BODY_TEMPERATURE) {
          final prev = latestAt['body_temperature'];
          if (prev == null || pointTime.isAfter(prev)) {
            summary['body_temperature'] = numVal;
            latestAt['body_temperature'] = pointTime;
          }
        } else if (type == HealthDataType.BLOOD_PRESSURE_SYSTOLIC) {
          final prev = latestAt['bp_systolic'];
          if (prev == null || pointTime.isAfter(prev)) {
            summary['bp_systolic'] = numVal;
            latestAt['bp_systolic'] = pointTime;
          }
        } else if (type == HealthDataType.BLOOD_PRESSURE_DIASTOLIC) {
          final prev = latestAt['bp_diastolic'];
          if (prev == null || pointTime.isAfter(prev)) {
            summary['bp_diastolic'] = numVal;
            latestAt['bp_diastolic'] = pointTime;
          }
        }
        // 注意: MENSTRUATION_FLOW 在当前 health 包版本中不支持
        // 经期数据需要通过其他方式获取或使用不同的 HealthDataType
        /*
        else if (type == HealthDataType.MENSTRUATION_FLOW) {
          // 经期数据：记录所有经期数据点用于周期计算
          if (!summary.containsKey('menstruation_records')) {
            summary['menstruation_records'] = <Map<String, dynamic>>[];
          }
          (summary['menstruation_records'] as List<Map<String, dynamic>>).add({
            'date_from': point.dateFrom.toIso8601String(),
            'date_to': point.dateTo.toIso8601String(),
            'value': numVal,
          });
          summary['has_menstruation'] = true;
        }
        */
      }
      
      // 计算总睡眠
      if (summary.containsKey('sleep_asleep')) {
        summary['sleep_total'] = (summary['sleep_asleep'] ?? 0) + 
                                (summary['sleep_deep'] ?? 0) + 
                                (summary['sleep_rem'] ?? 0);
      }

      // 计算经期状态
      if (summary['has_menstruation'] == true) {
        final menstruationInfo = _calculateMenstruationStatus(
          summary['menstruation_records'] as List<Map<String, dynamic>>?,
        );
        summary.addAll(menstruationInfo);
      }

      if (kDebugMode) debugPrint('[HealthService] 获取到健康摘要: $summary');
    } catch (e) {
      if (kDebugMode) debugPrint('[HealthService] 获取健康摘要失败: $e');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('health_last_fetch_error', e.toString());
      await prefs.setString('health_last_fetch_time', DateTime.now().toIso8601String());
    }
    return summary;
  }

  /// 计算经期状态（是否在经期、周期天数、预测下次经期）
  ///
  /// [records] HealthKit 中的经期数据点列表
  /// 返回: { is_in_period, cycle_day, predicted_next_date, average_cycle_length }
  static Map<String, dynamic> _calculateMenstruationStatus(
    List<Map<String, dynamic>>? records,
  ) {
    final result = <String, dynamic>{
      'is_in_period': false,
      'cycle_day': 0,
      'predicted_next_date': '',
      'average_cycle_length': 28,
    };

    if (records == null || records.isEmpty) return result;

    try {
      // 解析所有经期数据点的时间
      final periodDays = <DateTime>{};
      for (final record in records) {
        final from = DateTime.tryParse(record['date_from'] as String);
        final to = DateTime.tryParse(record['date_to'] as String);
        if (from != null) {
          periodDays.add(DateTime(from.year, from.month, from.day));
        }
        if (to != null) {
          periodDays.add(DateTime(to.year, to.month, to.day));
        }
      }

      if (periodDays.isEmpty) return result;

      // 按日期排序
      final sortedDays = periodDays.toList()..sort();

      // 检查今天是否在经期（今天或昨天有记录）
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final yesterday = todayDate.subtract(const Duration(days: 1));

      result['is_in_period'] = periodDays.contains(todayDate) || periodDays.contains(yesterday);

      // 计算当前周期天数（从上次经期开始到今天）
      // 找到最近的经期开始日
      final latestPeriodDay = sortedDays.last;
      result['cycle_day'] = todayDate.difference(latestPeriodDay).inDays + 1;

      // 计算平均周期长度（需要至少2次经期记录）
      if (sortedDays.length >= 2) {
        // 找到经期"段落"：连续的经期日归为一段
        final periods = <DateTime>[];
        DateTime? segmentStart;
        DateTime? prevDay;

        for (final day in sortedDays) {
          if (segmentStart == null) {
            segmentStart = day;
          } else if (day.difference(prevDay!).inDays > 3) {
            // 间隔超过3天，视为新经期开始
            periods.add(segmentStart);
            segmentStart = day;
          }
          prevDay = day;
        }
        if (segmentStart != null) {
          periods.add(segmentStart);
        }

        // 计算平均周期
        if (periods.length >= 2) {
          int totalCycleDays = 0;
          int cycleCount = 0;
          for (int i = 1; i < periods.length; i++) {
            final diff = periods[i].difference(periods[i - 1]).inDays;
            if (diff > 15 && diff < 60) {
              // 合理的周期范围：15-60天
              totalCycleDays += diff;
              cycleCount++;
            }
          }
          if (cycleCount > 0) {
            final avgCycle = (totalCycleDays / cycleCount).round();
            result['average_cycle_length'] = avgCycle;

            // 预测下次经期
            final predictedDate = latestPeriodDay.add(Duration(days: avgCycle));
            result['predicted_next_date'] =
                '${predictedDate.year}-${predictedDate.month.toString().padLeft(2, '0')}-${predictedDate.day.toString().padLeft(2, '0')}';
          }
        }
      }

      if (kDebugMode) {
        debugPrint('[HealthService] 经期状态: inPeriod=${result['is_in_period']}, '
          'cycleDay=${result['cycle_day']}, avgCycle=${result['average_cycle_length']}, '
          'predictedNext=${result['predicted_next_date']}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[HealthService] 计算经期状态失败: $e');
    }

    return result;
  }

  /// 同步健康数据到后端
  static Future<bool> syncHealthData() async {
    try {
      // 1. 获取最新健康摘要
      final summary = await getHealthSummary();
      if (summary.isEmpty) {
        if (kDebugMode) debugPrint('[HealthService] 健康摘要为空，跳过同步');
        return false;
      }

      // 2. 调用 API 同步
      final res = await UserService.syncHealthMetrics(summary);
      if (res['success'] == true) {
        if (kDebugMode) debugPrint('[HealthService] 健康数据同步成功');
        
        // 3. 推送健康数据到 Apple Watch
        unawaited(WatchDataService().pushHealthSummary(summary));
        
        // 3.1 推送经期状态到 Watch
        if (summary['has_menstruation'] == true) {
          unawaited(WatchDataService().pushMenstruationStatus(
            isInPeriod: summary['is_in_period'] == true,
            cycleDay: (summary['cycle_day'] as int?) ?? 0,
            predictedNextDate: summary['predicted_next_date'] as String?,
          ));
        }
        
        // 4. 检查并发送异常报警 (带有去重冷静期逻辑)
        final anomalies = checkAnomalies(summary);
        if (anomalies != null) {
          final alerts = anomalies['alerts'] as List<String>;
          final prefs = await SharedPreferences.getInstance();
          
          // 获取上一次报警的内容和时间
          final lastAlerts = prefs.getStringList('last_health_alerts') ?? [];
          final lastAlertTimeStr = prefs.getString('last_health_alert_time');
          final lastAlertTime = lastAlertTimeStr != null ? DateTime.tryParse(lastAlertTimeStr) : null;
          
          // 判断是否需要报警：内容不同 OR 距离上次报警超过 4 小时
          bool shouldNotify = false;
          if (listEquals(lastAlerts, alerts)) {
            // 内容相同，检查冷静期（4小时）
            if (lastAlertTime == null || DateTime.now().difference(lastAlertTime).inHours >= 4) {
              shouldNotify = true;
            }
          } else {
            // 内容不同（新增了异常或指标变化），立即报警
            shouldNotify = true;
          }

          if (shouldNotify) {
            if (kDebugMode) debugPrint('[HealthService] 检测到异常体征，且通过冷静期校验，准备报警: $alerts');
            await NotifyService.sendHealthAlert(alerts);
            
            // 更新缓存
            await prefs.setStringList('last_health_alerts', alerts);
            await prefs.setString('last_health_alert_time', DateTime.now().toIso8601String());
          } else {
            if (kDebugMode) debugPrint('[HealthService] 检测到异常但处于冷静期内且内容未变，跳过重复报警');
          }
        }
        
        return true;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[HealthService] 同步健康数据异常: $e');
    }
    return false;
  }

  /// 检查是否存在异常体征
  static Map<String, dynamic>? checkAnomalies(Map<String, dynamic> summary) {
    List<String> alerts = [];
    
    // 1. 检查极端心率
    if (summary.containsKey('heart_rate')) {
      double hr = double.tryParse(summary['heart_rate'].toString()) ?? 0;
      if (hr > 120) alerts.add('心率过快 ($hr bpm)');
      if (hr > 0 && hr < 45) alerts.add('心率过缓 ($hr bpm)');
    }

    // 2. 检查低血氧
    if (summary.containsKey('blood_oxygen')) {
      double bo = double.tryParse(summary['blood_oxygen'].toString()) ?? 0;
      if (bo > 0 && bo < 0.90) { // HealthKit 血氧通常是 0.0-1.0
        alerts.add('血氧饱和度偏低 (${(bo * 100).toStringAsFixed(0)}%)');
      } else if (bo > 1.0 && bo < 90) { // 有些设备直接给百分比
        alerts.add('血氧饱和度偏低 ($bo%)');
      }
    }

    // 3. 检查高血压 (Hypertension)
    if (summary.containsKey('bp_systolic')) {
      double systolic = double.tryParse(summary['bp_systolic'].toString()) ?? 0;
      double diastolic = double.tryParse(summary['bp_diastolic']?.toString() ?? '0') ?? 0;
      if (systolic >= 140 || diastolic >= 90) {
        alerts.add('检测到血压偏高 ($systolic/$diastolic mmHg)');
      } else if (systolic > 0 && systolic < 90) {
        alerts.add('检测到血压偏低 ($systolic mmHg)');
      }
    }

    // 4. 检查呼吸频率 (夜晚体征)
    if (summary.containsKey('respiratory_rate')) {
      double rr = double.tryParse(summary['respiratory_rate'].toString()) ?? 0;
      if (rr > 25) {
        alerts.add('呼吸频率异常偏快 ($rr 次/分)');
      } else if (rr > 0 && rr < 8) {
        alerts.add('呼吸频率异常偏慢 ($rr 次/分)');
      }
    }

    // 5. 检查体温 (高烧预警)
    if (summary.containsKey('body_temperature')) {
      double temp = double.tryParse(summary['body_temperature'].toString()) ?? 0;
      if (temp > 38.0) {
        alerts.add('检测到体温偏高 ($temp°C)');
      }
    }

    // 6. 经期相关提醒
    if (summary['is_in_period'] == true) {
      // 经期中体温偏高提醒（经期基础体温通常升高 0.3-0.5°C）
      if (summary.containsKey('body_temperature')) {
        double temp = double.tryParse(summary['body_temperature'].toString()) ?? 0;
        if (temp > 37.0 && temp <= 38.0) {
          alerts.add('经期体温偏高 ($temp°C)，注意休息');
        }
      }
    }

    // 7. 经期即将到来提醒（周期天数接近平均周期）
    if (summary['has_menstruation'] == true && summary['is_in_period'] != true) {
      int cycleDay = (summary['cycle_day'] as int?) ?? 0;
      int avgCycle = (summary['average_cycle_length'] as int?) ?? 28;
      // 距离预测经期还有2天内
      if (cycleDay >= avgCycle - 2 && cycleDay <= avgCycle) {
        alerts.add('经期可能即将到来（周期第$cycleDay天）');
      }
      // 周期异常偏长
      if (cycleDay > avgCycle + 7) {
        alerts.add('经期周期偏长（已第$cycleDay天，平均$avgCycle天）');
      }
    }

    if (alerts.isNotEmpty) {
      return {
        'has_anomaly': true,
        'alerts': alerts,
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
    return null;
  }

  /// 执行基于心跳的「静默签到」
  /// [windowMinutes] 检查过去多少分钟内的数据，默认 10 分钟
  static Future<bool> checkRecentHeartbeat({int windowMinutes = 10}) async {
    try {
      final now = DateTime.now();
      final startTime = now.subtract(Duration(minutes: windowMinutes));
      
      // 从 HealthKit 获取数据
      List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: startTime,
        endTime: now,
      );

      if (healthData.isNotEmpty) {
        if (kDebugMode) debugPrint('[HealthService] 检测到最近心跳数据: ${healthData.length} 条');
        return true;
      }
      
      if (kDebugMode) debugPrint('[HealthService] 过去 $windowMinutes 分钟内未检测到心跳数据');
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('[HealthService] 读取心跳数据失败: $e');
      return false;
    }
  }

  /// 执行基于心跳的「静默签到」
  static Future<void> performSilentHeartbeatCheckin() async {
    // ====== 新增：检查来自 Watch App 的主动签到信号 ======
    final prefs = await SharedPreferences.getInstance();
    bool hasWatchSignal = prefs.getBool('pending_watch_checkin') ?? false;
    
    // 1. 检查权限
    bool hasPermission = await requestPermissions();
    if (!hasPermission && !hasWatchSignal) return;

    // 2. 检查最近心跳 或 检查是否有 Watch 信号
    bool isAlive = hasWatchSignal || await checkRecentHeartbeat();
    
    if (isAlive) {
      if (kDebugMode) debugPrint('[HealthService] 触发静默签到 (Watch信号: $hasWatchSignal)...');
      
      // 执行同步健康数据（顺便带上去）
      await syncHealthData();
      
      // 获取当前日期
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      // 调用现有的签到接口 (心情默认为 0，代表静默自动签到)
      final res = await CheckinService.checkIn(
        date: today,
        mood: 0,
      );
      
      if (res['success'] == true) {
        if (kDebugMode) debugPrint('[HealthService] 静默签到成功');
        final uid = prefs.getString('user_id') ?? '';
        final lastDateKey =
            uid.isNotEmpty ? 'last_check_in_date_$uid' : 'last_check_in_date';
        await prefs.setString(lastDateKey, today);
        await prefs.setString('last_check_in_date', today);
        unawaited(SyncService.pullFromServer());
        // 清除 Watch 信号
        if (hasWatchSignal) {
          await prefs.remove('pending_watch_checkin');
        }
      }
    }
  }
}
