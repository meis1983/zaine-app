import 'package:health/health.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../api/checkin_service.dart';
import '../api/user_service.dart';
import '../api/notify_service.dart';
import '../api/sync_service.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'watch_data_service.dart';
import '../safety/safety_service.dart';
import '../safety/safety_signal_engine.dart';
import '../database/circle_event_dao.dart';
import '../../config/app_config.dart';
import '../../utils/streak_util.dart';

/// 健康数据服务 (Apple Watch / HealthKit 集成)
/// 实现「多维度生命体征监测」的核心逻辑
class HealthService {
  static final Health _health = Health();

  // 【v1.97.2 修复】手腕温度原生桥（health 包未暴露该类型，改走 iOS 原生读取）
  static const MethodChannel _hkChannel = MethodChannel('zaine/healthkit');

  // ==================== 授权态「粘性」标记 (v1.97.4 修复) ====================
  //
  // 【根因】_loadSafetyStatus 每次进页都调 checkRealAuthStatus() 实时查 HealthKit，
  // 实时查询偶发失败(无网络/HealthKit 瞬时无响应/样本为空)就回落 false → UI 在
  // 「守护中 ↔ 尚未检测」之间跳动。用户已两次授权，状态必须恒定。
  //
  // 【解法】引入持久化粘性标记 health_authorized：一旦用户完成 HealthKit 授权
  // （弹框同意 或 实测有真实样本），即写入 true，作为「是否已开启生命体征守护」的
  // 单一真相源。实时查询只用于刷新安全信号数据，**绝不反向推翻**此标记。
  static const String _kAuthorized = 'health_authorized';

  /// 标记已授权（持久化）。授权成功路径(requestPermissions 成功 / checkRealAuthStatus 实测有数据)调用。
  /// 【v1.97.6 修复】同时写入 health_authorized_at 时间戳，作为「历史上曾授权」的破冰证据，
  /// 使 _loadSafetyStatus 在 iOS 实时探测偶发失败时仍能维持「守护中」，根除跳动。
  static Future<void> markAuthorized() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAuthorized, true);
    await prefs.setString('health_authorized_at', DateTime.now().toIso8601String());
  }

  /// 读取授权态粘性标记（单一真相源）
  static Future<bool> isAuthorized() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAuthorized) ?? false;
  }

  /// 【v1.97.6 修复】是否「历史上曾成功授权过」(设备级事实，不随实时探测抖动)。
  /// 用于 _loadSafetyStatus 的破冰兜底：只要用户走过的配对(哪怕更早版本)，
  /// 就恒定显示「守护中」，不再因 iOS HealthKit 隐私模型下的探测失败回落「尚未检测」。
  static Future<bool> hasEverAuthorized() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('health_authorized_at') != null;
  }

  /// 清除授权态标记 + HealthKit 镜像缓存（登出时调用，避免下一账号误判已授权 / 读到旧镜像）
  static Future<void> clearAuthorized() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAuthorized);
    _mirrorCache = null;
    _mirrorCacheAt = null;
  }

  /// 【v1.97.4 修复】仅清除 HealthKit 镜像缓存（按账号的健康数据），保留授权态粘性标记。
  /// 原因：HealthKit 授权是「设备级」(iOS 对 App 整体授权，与登录账号无关)，
  /// 同一台手机上任意账号都应视为已授权。原先 logout 调用 clearAuthorized() 把标记也清掉，
  /// 导致切账号后守护卡先闪「未检测」再靠实时探测回「守护中」——这正是跳动根因之一。
  /// 登出只需清掉「旧账号的健康数据镜像」，授权标记应常驻。
  static Future<void> clearHealthMirror() async {
    _mirrorCache = null;
    _mirrorCacheAt = null;
  }

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
    HealthDataType.STEPS,                // 步数
    HealthDataType.DISTANCE_WALKING_RUNNING, // 行走+跑步距离
    HealthDataType.ACTIVE_ENERGY_BURNED, // 活跃能量
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
  ///
  /// 【v1.97.6 根本性修复】用户主动点按「开启生命体征守护」即代表设备级配对意图。
  /// iOS HealthKit 隐私模型下 requestAuthorization 的**返回值与异常均不可靠**（常返回 false、
  /// 个别设备/版本甚至会抛异常），但只要用户走过配对流程（弹窗拉起或已授权），就应**恒定**
  /// 标记「已授权」。故 markAuthorized() 置于 finally 中，无论返回值/异常都执行，确保
  /// 切界面/切账号回来恒为「守护中」，彻底根除「守护中↔尚未检测」跳动。
  static Future<bool> requestPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    bool authorized = false;
    try {
      // 在部分旧版本或模拟器上，某些类型可能不可用，这里使用 try-catch
      authorized = await _health.requestAuthorization(_types, permissions: _permissions);
      if (kDebugMode) debugPrint('[HealthService] HealthKit 深度授权结果: $authorized');
      await prefs.setBool('health_last_authorized', authorized);
    } catch (e) {
      if (kDebugMode) debugPrint('[HealthService] 请求权限异常: $e');
      try {
        final core = _coreTypes();
        final corePerms = core.map((_) => HealthDataAccess.READ).toList();
        authorized = await _health.requestAuthorization(core, permissions: corePerms);
        await prefs.setBool('health_last_authorized', authorized);
        if (kDebugMode) debugPrint('[HealthService] HealthKit 核心授权结果: $authorized');
      } catch (e2) {
        await prefs.setBool('health_last_authorized', false);
        if (kDebugMode) debugPrint('[HealthService] 核心授权亦异常: $e2');
      }
    } finally {
      // 设备级配对意图 = 恒定标记（根剔除跳动的关键）
      await markAuthorized();
      await prefs.setString('health_last_auth_error', '');
      await prefs.setString('health_last_auth_time', DateTime.now().toIso8601String());
    }
    return authorized;
  }

  /// 【v1.97.3+172 直接读 HealthKit；+173 子集修正】
  /// 直接读 HealthKit 真实权限态，绕过 prefs 时序问题。
  ///
  /// 【+173 关键修正】改用 _coreTypes()（心率/血氧/睡眠 6 项）而非 _types（14 项）：
  /// _types 里的 BODY_TEMPERATURE / BLOOD_PRESSURE_SYSTOLIC/_DIASTOLIC 在普通 iPhone +
  /// Apple Watch 上**没有数据源**，iOS HealthKit 弹窗里根本不显示让用户授权的项
  /// → 这些 type 的 authorizationStatus 永远是 .notDetermined
  /// → 插件 `hasPermissions` 因含 notDetermined 整体返回 false，UI 误判"待开启"。
  ///
  /// _coreTypes() 的 6 项在所有 iPhone/Apple Watch 都可见，弹窗里可正常授权，
  /// 体感副标题"同步 Apple Watch 心率、血氧与睡眠"也吻合。
  ///
  /// Apple 因隐私不会披露具体 read 授权状态，但只要任一 type 已被弹过授权框，
  /// 插件视为已触发授权；返回 true。
  /// 【v1.97.3+176 诊断】无条件日志（release 也输出到系统日志，不再被 kDebugMode 编译剔除）
  /// 【v1.97.4 重要】此方法在 iOS 上**永远返回 false**：
  ///   health 插件 iOS 端 SwiftHealthPlugin.hasPermission() 对 READ 权限 case 0
  ///   直接 `return nil`（Apple 隐私模型），外层循环任一 type 返回 nil/false 即 result(nil)。
  ///   整段代码无任何修改能让插件在 iOS READ 上返回真值。请改用 checkRealAuthStatus()。
  @Deprecated('iOS HealthKit 隐私模型下永远 false，请使用 checkRealAuthStatus()')
  static Future<bool> hasPermissions() async {
    try {
      final core = _coreTypes();
      final corePerms = core.map((_) => HealthDataAccess.READ).toList();
      debugPrint('[HealthService] hasPermissions 请求类型(${core.length}项): '
          '${core.map((e) => e.name).join(', ')}');
      // 【v1.97.3+176 诊断】逐项单类型检测，定位是哪个 type 把整体拖成 false
      for (var i = 0; i < core.length; i++) {
        try {
          final r = await _health.hasPermissions([core[i]], permissions: [HealthDataAccess.READ]);
          debugPrint('[HealthService]   单类型[$i] ${core[i].name} = $r');
        } catch (e) {
          debugPrint('[HealthService]   单类型[$i] ${core[i].name} 检测异常: $e');
        }
      }
      final result = await _health.hasPermissions(core, permissions: corePerms);
      debugPrint('[HealthService] hasPermissions 整体结果: $result (类型: ${result.runtimeType})');
      return result ?? false;
    } catch (e, stack) {
      debugPrint('[HealthService] hasPermissions 异常: $e');
      debugPrint('[HealthService] hasPermissions 异常栈: $stack');
      // 异常时回退到 prefs，避免 UI 在边缘情况下闪动
      final prefs = await SharedPreferences.getInstance();
      final fallback = prefs.getBool('health_last_authorized') ?? false;
      debugPrint('[HealthService] hasPermissions 回退 prefs: $fallback');
      return fallback;
    }
  }

  // ==================== 真实授权判定 (v1.97.4 修复) ====================
  //
  // 【根因】iOS HealthKit 因隐私模型**不向 App 披露读权限状态**。
  // health 插件 iOS 端 SwiftHealthPlugin.hasPermission() 对 READ 权限：
  //   case 0:  // READ
  //     return nil   ← 永远 nil，导致外层 result(nil) = 假 false
  // 173/174/175/176 一直在和这个必然 false 搏斗，全部失败。
  //
  // 【正确做法】用「真实样本数」作为授权证据——
  // 能读到数据 = 已授权（隐私底线下的最佳代理）。
  // 用 health 插件的 getHealthDataFromTypes 数 24h 内 3 类核心 type 的条数；
  // 同时调原生桥 getFullHealthSummary 看 mirror 是否有合理 key（兜底）。
  //
  // 返回 Map（保持向后兼容 + 携带诊断信息）：
  //   {
  //     'authorized': bool,        // 是否有任一 type 拿到数据 → 视为已连接
  //     'hr_count': int,           // 24h 内心率样本数
  //     'bo_count': int,           // 24h 内血氧样本数
  //     'sleep_count': int,        // 24h 内睡眠样本数
  //     'plugin_perm': bool,       // 插件 hasPermissions 真实值（iOS 必为 false，调试用）
  //     'source': String,          // 'data' / 'bridge' / 'none'
  //   }
  static Future<Map<String, dynamic>> checkRealAuthStatus() async {
    final result = <String, dynamic>{
      'authorized': false,
      'hr_count': 0,
      'bo_count': 0,
      'sleep_count': 0,
      'plugin_perm': false,
      'source': 'none',
    };

    // 第一层：插件 getHealthDataFromTypes 数 24h 内真实样本
    try {
      final now = DateTime.now();
      final startTime = now.subtract(const Duration(hours: 24));
      final core = _coreTypes();
      int hr = 0, bo = 0, sl = 0;
      for (final t in core) {
        try {
          final part = await _health.getHealthDataFromTypes(
            types: [t],
            startTime: startTime,
            endTime: now,
          );
          final n = part.length;
          if (t == HealthDataType.HEART_RATE) {
            hr += n;
          } else if (t == HealthDataType.BLOOD_OXYGEN) {
            bo += n;
          } else if (_isSleepType(t)) {
            sl += n;
          }
        } catch (e) {
          debugPrint('[HealthService] checkRealAuthStatus 单类型 ${t.name} 读取异常: $e');
        }
      }
      result['hr_count'] = hr;
      result['bo_count'] = bo;
      result['sleep_count'] = sl;
      if (hr + bo + sl > 0) {
        result['authorized'] = true;
        result['source'] = 'data';
        await markAuthorized(); // 【v1.97.4】实测有真实样本 → 粘性标记(自动检测到授权)
      }
    } catch (e, stack) {
      debugPrint('[HealthService] checkRealAuthStatus 插件读取异常: $e');
      debugPrint('[HealthService] checkRealAuthStatus 插件读取异常栈: $stack');
    }

    // 第二层：原生桥 getFullHealthSummary 兜底（即便插件 get 失败，原生桥仍能直读）
    if (!(result['authorized'] as bool)) {
      try {
        final mirror = await getFullMirror(forceRefresh: true);
        bool hasReasonable = false;
        // 心率 30-200、血氧 80-100、睡眠分钟 > 0 → 任一合理即视为已连接
        final hr = mirror['heart_rate'];
        final bo = mirror['blood_oxygen'];
        final sl = mirror['sleep_asleep'];
        if (hr is num && hr >= 30 && hr <= 200) hasReasonable = true;
        if (bo is num && bo >= 80 && bo <= 100) hasReasonable = true;
        if (sl is num && sl > 0) hasReasonable = true;
        if (hasReasonable) {
          result['authorized'] = true;
          result['source'] = 'bridge';
          await markAuthorized(); // 【v1.97.4】原生桥兜底确认有数据 → 粘性标记
        }
        debugPrint('[HealthService] checkRealAuthStatus 原生桥 mirror keys: ${mirror.length}, hasReasonable=$hasReasonable');
      } catch (e) {
        debugPrint('[HealthService] checkRealAuthStatus 原生桥读取异常: $e');
      }
    }

    // 调试用：插件 hasPermissions 真实值（iOS 必为 false，标注便于理解）
    try {
      final r = await _health.hasPermissions(
        [HealthDataType.HEART_RATE],
        permissions: [HealthDataAccess.READ],
      );
      result['plugin_perm'] = r ?? false;
    } catch (_) {
      // 忽略
    }

    debugPrint('[HealthService] checkRealAuthStatus 最终: $result');
    return result;
  }

  static bool _isSleepType(HealthDataType t) {
    return t == HealthDataType.SLEEP_ASLEEP ||
        t == HealthDataType.SLEEP_AWAKE ||
        t == HealthDataType.SLEEP_DEEP ||
        t == HealthDataType.SLEEP_REM;
      }

      /// 判断数据点是否来自 Apple Watch（优先采用 Watch 数据源，使 App 与 Watch 端显示一致）
      static bool _isFromWatch(HealthDataPoint p) {
        final name = p.sourceName.toLowerCase();
        final id = p.sourceId.toLowerCase();
        return name.contains('watch') || id.contains('watch');
      }

      /// 【2026-07-15 修复】合并重叠睡眠区间，返回总分钟数。
      /// HealthKit 常因多 App/多源写入产生重叠区间，简单求和会重复计入导致时长虚高；
      /// 此处按开始时间排序后合并重叠段，仅累加不重叠部分，得到准确总睡眠时长。
      static int _mergeSleepMinutes(List<Map<String, int>> intervals) {
        if (intervals.isEmpty) return 0;
        final sorted = [...intervals]
          ..sort((a, b) => (a['from'] ?? 0).compareTo(b['from'] ?? 0));
        int total = 0;
        int curFrom = sorted[0]['from'] ?? 0;
        int curTo = sorted[0]['to'] ?? 0;
        for (int i = 1; i < sorted.length; i++) {
          final f = sorted[i]['from'] ?? 0;
          final t = sorted[i]['to'] ?? 0;
          if (f <= curTo) {
            // 与当前区间重叠，合并（仅扩展结束时间）
            if (t > curTo) curTo = t;
          } else {
            // 不重叠，结算上一段并开启新段
            total += curTo - curFrom;
            curFrom = f;
            curTo = t;
          }
        }
    total += curTo - curFrom;
    // 区间差是毫秒(ms)，但外部按「分钟」使用，此处统一换算为分钟
    return total ~/ 60000;
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
      // 【v1.97.2 修复】睡眠窗口收窄为「昨晚 18:00 起」，只取最近一夜，
      // 避免 48h 宽窗把前晚+午睡累加导致睡眠时长虚高（与 Apple Watch 睡眠监测一致）
      final yesterday = now.subtract(const Duration(days: 1));
      final startSleep = DateTime(yesterday.year, yesterday.month, yesterday.day, 18, 0);

      final typeCounts = <String, int>{};
      final typeErrors = <String, String>{};
      final all = <HealthDataPoint>[];
      // 【2026-07-15 修复】睡眠区间收集，稍后合并重叠区间再计算时长，避免多源/多段重叠导致虚高
      final sleepIntervals = <String, List<Map<String, int>>>{
        'SLEEP_ASLEEP': <Map<String, int>>[],
        'SLEEP_DEEP': <Map<String, int>>[],
        'SLEEP_REM': <Map<String, int>>[],
      };

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

      // 【修复 v1.96】优先采用 Apple Watch 数据源，使 App 体征与 Watch 端一致；
      // 某类型无 Watch 数据时回退使用全部数据源（避免丢失 iPhone 独有指标）
      final preferred = <HealthDataPoint>[];
      for (final t in _types) {
        final watchOfType = all.where((p) => p.type == t && _isFromWatch(p)).toList();
        if (watchOfType.isNotEmpty) {
          preferred.addAll(watchOfType);
        } else {
          preferred.addAll(all.where((p) => p.type == t));
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
      for (var point in preferred) {
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
          sleepIntervals['SLEEP_ASLEEP']!.add({
            'from': point.dateFrom.millisecondsSinceEpoch,
            'to': point.dateTo.millisecondsSinceEpoch,
          });
        } else if (type == HealthDataType.SLEEP_AWAKE) {
          summary['sleep_awake'] = (summary['sleep_awake'] ?? 0) + numVal.round();
        } else if (type == HealthDataType.SLEEP_DEEP) {
          sleepIntervals['SLEEP_DEEP']!.add({
            'from': point.dateFrom.millisecondsSinceEpoch,
            'to': point.dateTo.millisecondsSinceEpoch,
          });
        } else if (type == HealthDataType.SLEEP_REM) {
          sleepIntervals['SLEEP_REM']!.add({
            'from': point.dateFrom.millisecondsSinceEpoch,
            'to': point.dateTo.millisecondsSinceEpoch,
          });
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
        } else if (type == HealthDataType.STEPS) {
          // 步数：累加今天的所有数据点
          final today = DateTime.now();
          final todayDate = DateTime(today.year, today.month, today.day);
          final pointDate = DateTime(point.dateFrom.year, point.dateFrom.month, point.dateFrom.day);
          if (pointDate == todayDate) {
            summary['steps'] = (summary['steps'] ?? 0) + (numVal?.round() ?? 0); // numVal 可能为 null，保留 ?.
          }
        } else if (type == HealthDataType.DISTANCE_WALKING_RUNNING) {
          // 【修复 v1.96】行走+跑步距离：health 包统一以「米(METER)」返回，直接累加即可；
          // 旧逻辑用 >1000 猜测单位，导致短距离(米制<1000)被误乘 1000 → 显示几百 km。
          // 为兼容潜在其它单位，按 point.unit 精确换算。
          final today = DateTime.now();
          final todayDate = DateTime(today.year, today.month, today.day);
          final pointDate = DateTime(point.dateFrom.year, point.dateFrom.month, point.dateFrom.day);
          if (pointDate == todayDate) {
            double distanceInMeters = 0;
            if (numVal != null && numVal > 0) {
              final unitStr = point.unit.toString().toLowerCase();
              if (unitStr.contains('kilometer') || unitStr.contains('km')) {
                distanceInMeters = numVal * 1000;
              } else if (unitStr.contains('mile') || unitStr.contains('mi')) {
                distanceInMeters = numVal * 1609.34;
              } else {
                // 默认按米处理（health 包 DISTANCE_WALKING_RUNNING 标准单位为 METER）
                distanceInMeters = numVal;
              }
            }
            summary['distance_m'] = (summary['distance_m'] ?? 0) + distanceInMeters.round();
          }
        } else if (type == HealthDataType.ACTIVE_ENERGY_BURNED) {
          // 活跃能量：累加今天的所有数据点（单位：千卡）
          final today = DateTime.now();
          final todayDate = DateTime(today.year, today.month, today.day);
          final pointDate = DateTime(point.dateFrom.year, point.dateFrom.month, point.dateFrom.day);
          if (pointDate == todayDate) {
            summary['active_energy'] = (summary['active_energy'] ?? 0) + ((numVal ?? 0).round());
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
      
      // 【2026-07-15 修复】合并重叠睡眠区间后再计算时长，避免多源/多段重叠导致虚高
      summary['sleep_asleep'] = _mergeSleepMinutes(sleepIntervals['SLEEP_ASLEEP'] ?? []);
      summary['sleep_deep'] = _mergeSleepMinutes(sleepIntervals['SLEEP_DEEP'] ?? []);
      summary['sleep_rem'] = _mergeSleepMinutes(sleepIntervals['SLEEP_REM'] ?? []);

      // 【修复 v1.93.9】计算总睡眠（合并重叠区间后即为准确总睡眠）
      // 核心睡眠 = 总睡眠 - 深度睡眠 - REM 睡眠（核心睡眠是总睡眠中既非深度也非REM的部分）
      if (summary.containsKey('sleep_asleep')) {
        final asleep = (summary['sleep_asleep'] ?? 0) as int;
        final deep = (summary['sleep_deep'] ?? 0) as int;
        final rem = (summary['sleep_rem'] ?? 0) as int;
        summary['sleep_total'] = asleep;

        // 核心睡眠，确保非负且不超过总睡眠
        final core = asleep - deep - rem;
        summary['sleep_core'] = core > 0 ? core : 0;

        // 验证数据合理性：如果总睡眠超过 12 小时（720分钟），标记为异常
        final totalSleep = summary['sleep_total'] ?? 0;
        if (totalSleep > 720) { // 12 小时
          if (kDebugMode) debugPrint('[HealthService] ⚠️ 睡眠时间异常: ${totalSleep} 分钟');
          // 尝试使用 sleep_deep + sleep_rem 的总和作为参考值
          final estimatedTotal = deep + rem + ((summary['sleep_awake'] ?? 0) as int);
          if (estimatedTotal > 0 && estimatedTotal < 720) {
            summary['sleep_total'] = estimatedTotal;
            summary['sleep_core'] = (estimatedTotal - deep - rem) > 0 ? (estimatedTotal - deep - rem) : 0;
            if (kDebugMode) debugPrint('[HealthService] 使用修正后的睡眠时间: $estimatedTotal 分钟');
          }
        }
      }

      // 计算经期状态
      if (summary['has_menstruation'] == true) {
        final menstruationInfo = _calculateMenstruationStatus(
          summary['menstruation_records'] as List<Map<String, dynamic>>?,
        );
        summary.addAll(menstruationInfo);
      }

      // 【v1.97.2】全量健康镜像叠加：把 iOS 原生桥读到的全部 HealthKit 指标覆盖/补齐进 summary。
      // 原生桥是权威源（直读 Apple Watch 同步进 iPhone HealthKit 的原始样本），
      // health 包路径退化为兜底——原生失败时仍保留原有数据，零回归风险。
      final mirror = await getFullMirror();
      if (mirror.isNotEmpty) {
        summary.addAll(mirror);
        // 兼容旧 UI：以下三个 key 历史上是字符串（'72'），原生返回 double，需回填为整数字符串
        for (final k in ['heart_rate', 'respiratory_rate', 'resting_heart_rate']) {
          final v = summary[k];
          if (v is num) summary[k] = v.toStringAsFixed(0);
        }
      }

      if (kDebugMode) debugPrint('[HealthService] 获取到健康摘要: ${summary.keys.length} 项');
    } catch (e) {
      if (kDebugMode) debugPrint('[HealthService] 获取健康摘要失败: $e');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('health_last_fetch_error', e.toString());
      await prefs.setString('health_last_fetch_time', DateTime.now().toIso8601String());
    }
    return summary;
  }

  // ==================== 全量健康镜像 HealthMirror (v1.97.2) ====================

  /// 内存缓存：健康页与签到流程可能在数秒内多次触发，避免重复全量查询 HealthKit
  static Map<String, dynamic>? _mirrorCache;
  static DateTime? _mirrorCacheAt;
  static const Duration _mirrorTtl = Duration(seconds: 60);

  /// 读取 Apple Watch 同步进 iPhone HealthKit 的**全部可读**健康指标（约 70 项）。
  ///
  /// 唯一数据源：iOS 原生 MethodChannel `zaine/healthkit#getFullHealthSummary`。
  ///
  /// ⚠️ 设计约束（勿改）：
  /// 全读 ≠ 全展示。本方法读全量是为了喂给「安全信号引擎」做异常判定
  /// （例：判断「长时间无活动」需同时看步数 / 运动时长 / 站立小时 / 心率波动），
  /// UI 层只展示 L1 守护级指标，保持克制。详见 SafetySignalEngine。
  ///
  /// 任一指标缺失 → 对应 key 不存在，调用方按 '--' 处理，绝不抛错。
  static Future<Map<String, dynamic>> getFullMirror({bool forceRefresh = false}) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return const {};
    if (!forceRefresh &&
        _mirrorCache != null &&
        _mirrorCacheAt != null &&
        DateTime.now().difference(_mirrorCacheAt!) < _mirrorTtl) {
      return _mirrorCache!;
    }
    try {
      final raw = await _hkChannel.invokeMethod('getFullHealthSummary');
      if (raw is Map) {
        final data = <String, dynamic>{};
        raw.forEach((k, v) => data[k.toString()] = v);
        // 规范化训练列表：platform channel 回传 List<Object?> / Map<Object?, Object?>
        final w = data['workouts'];
        if (w is List) {
          data['workouts'] = w.whereType<Map>().map((e) {
            final m = <String, dynamic>{};
            e.forEach((k, v) => m[k.toString()] = v);
            return m;
          }).toList();
        }
        _mirrorCache = data;
        _mirrorCacheAt = DateTime.now();
        if (kDebugMode) debugPrint('[HealthMirror] ✅ 原生返回 ${data.length} 项指标');
        return data;
      }
    } catch (e) {
      // 原生桥失败不影响既有 health 包路径，健康页照常显示旧数据
      if (kDebugMode) debugPrint('[HealthMirror] ⚠️ 原生读取失败(降级): $e');
    }
    return const {};
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
  ///
  /// 🔴【v1.97.3 修复 Bug 8】即使 HealthKit 未授权（summary 为空）也**仍**调用一次 API，
  /// 让后端记录「用户尝试同步但未授权」状态，便于前端 UI 拿到这个状态显示引导 banner。
  /// 之前：summary 空 → return false → 前端 UI 显示「同步中」→「看似成功」→ 实际没数据
  static Future<bool> syncHealthData() async {
    try {
      // 1. 获取最新健康摘要（加 8s 超时防止被 HealthKit 永久阻塞）
      Map<String, dynamic> summary;
      try {
        summary = await getHealthSummary().timeout(
          const Duration(seconds: 8),
          onTimeout: () => <String, dynamic>{},
        );
      } catch (e) {
        if (kDebugMode) debugPrint('[HealthService] getHealthSummary 异常: $e');
        summary = <String, dynamic>{};
      }
      if (summary.isEmpty) {
        if (kDebugMode) debugPrint('[HealthService] 健康摘要为空（HealthKit 未授权或查询失败），仍调用 API 记录状态');
        // 【Bug 8 修复】即使空也调用 API，让后端记一次心跳 + 返回 not_authorized 状态
        try {
          await UserService.syncHealthMetrics({
            'metrics': <String, dynamic>{},
            'sync_status': 'not_authorized',
            'synced_at': DateTime.now().toIso8601String(),
          }).timeout(const Duration(seconds: 5));
        } catch (e) {
          if (kDebugMode) debugPrint('[HealthService] API 兜底同步失败(忽略): $e');
        }
        // 写本地标记，让前端 UI 显示 banner
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('health_last_sync_status', 'not_authorized');
        await prefs.setString('health_last_sync_time', DateTime.now().toIso8601String());
        return false;
      }
      // 成功拿到 summary，清除未授权标记
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('health_last_sync_status', 'ok');
      await prefs.setString('health_last_sync_time', DateTime.now().toIso8601String());

      // 2. 推送健康数据到 Apple Watch（修复：本地 HealthKit 授权成功即推送，不再依赖服务端同步结果）
      unawaited(WatchDataService().pushHealthSummary(summary));
      // 2.1 推送经期状态到 Watch
      if (summary['has_menstruation'] == true) {
        unawaited(WatchDataService().pushMenstruationStatus(
          isInPeriod: summary['is_in_period'] == true,
          cycleDay: (summary['cycle_day'] as int?) ?? 0,
          predictedNextDate: summary['predicted_next_date'] as String?,
        ));
      }

      // 3. 调用 API 同步（失败不影响手表推送）
      final res = await UserService.syncHealthMetrics(summary);
      if (res['success'] == true) {
        if (kDebugMode) debugPrint('[HealthService] 健康数据同步成功');
      } else {
        if (kDebugMode) debugPrint('[HealthService] 健康数据服务端同步未成功（不影响手表推送）');
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
            // 🔴【v1.97.2 合规修复】此前本调用**无区域闸门**，CN 版会自动向守护圈外发
            // 健康异常报警 —— 正是 Apple 判定 dead-man switch 的行为。现补上闸门：
            //   - 海外版：自动外发（保持原有能力）
            //   - CN 版：只写本地待确认队列，由用户在 App 内手动确认后才外发
            if (AppConfig.isChinaRegion) {
              if (kDebugMode) debugPrint('[HealthService] [CN] 检测到异常体征，已拦截自动外发，转本地待确认: $alerts');
              await prefs.setStringList('pending_health_alerts', alerts);
              await prefs.setString('pending_health_alert_time', DateTime.now().toIso8601String());
            } else {
              if (kDebugMode) debugPrint('[HealthService] 检测到异常体征，且通过冷静期校验，准备报警: $alerts');
              await NotifyService.sendHealthAlert(alerts);
            }

            // 更新缓存
            await prefs.setStringList('last_health_alerts', alerts);
            await prefs.setString('last_health_alert_time', DateTime.now().toIso8601String());
          } else {
            if (kDebugMode) debugPrint('[HealthService] 检测到异常但处于冷静期内且内容未变，跳过重复报警');
          }
        }

        // 【v1.97.2 新增】安全信号引擎判定：长时间无活动等「安全」维度异常
        // 与上方 checkAnomalies（纯生理指标越界）互补，二者独立冷静期、互不覆盖。
        await _evaluateSafetySignal(summary);

        return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[HealthService] 同步健康数据异常: $e');
    }
    return false;
  }

  // ==================== 安全信号自动守护 (v1.97.2) ====================

  /// 安全信号外发冷静期：同一等级 6 小时内不重复打扰守护圈
  static const Duration _safetyAlertCooldown = Duration(hours: 6);

  /// 用户开关键：异常时是否自动通知守护圈（仅海外版有效）
  static const String kSafetyAutoAlertKey = 'safety_auto_alert_enabled';

  /// 读取「异常自动通知守护圈」开关。
  /// CN 版恒为 false（合规硬闸门，不受用户设置影响）。
  static Future<bool> isSafetyAutoAlertEnabled() async {
    if (AppConfig.isChinaRegion) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kSafetyAutoAlertKey) ?? true; // 海外版默认开启
  }

  /// 设置「异常自动通知守护圈」开关（CN 版调用无效）
  static Future<void> setSafetyAutoAlertEnabled(bool v) async {
    if (AppConfig.isChinaRegion) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kSafetyAutoAlertKey, v);
  }

  /// 依据安全信号引擎结论，决定是否惊动守护圈。
  ///
  /// 【与 checkAnomalies 的分工】
  ///   - checkAnomalies：单项生理指标越界（心率/血氧/体温…）
  ///   - 本方法：**安全维度**判定，核心是「长时间无活动」——
  ///     独居风险最强的信号，Apple 健康 App 永远不会做，是本 App 的差异化能力。
  ///
  /// 🔴【中国合规版红线】
  /// CN 版**绝不自动外发**，仅写入本地待确认队列 + 本机通知提醒用户本人，
  /// 由用户手动确认后守护人才可见。这正是当初被判定 dead-man switch 下架的红线。
  static Future<void> _evaluateSafetySignal(Map<String, dynamic> summary) async {
    try {
      final signal = SafetySignalEngine.evaluate(summary);

      // 仅 alert 级别才考虑惊动守护圈；attention 级只在 App 内展示，不外发
      if (signal.level != SafetyLevel.alert) return;

      final prefs = await SharedPreferences.getInstance();
      final lastStr = prefs.getString('last_safety_alert_time');
      final last = lastStr != null ? DateTime.tryParse(lastStr) : null;
      if (last != null && DateTime.now().difference(last) < _safetyAlertCooldown) {
        if (kDebugMode) debugPrint('[SafetySignal] 处于冷静期内，跳过重复外发');
        return;
      }

      final reasons = signal.reasons
          .where((r) => r.level == SafetyLevel.alert)
          .map((r) => r.text)
          .toList();
      if (reasons.isEmpty) return;

      // 双重闸门：① 区域合规（CN 恒关，用户不可开）② 用户自主开关（海外版可关）
      final autoAlertOn = await isSafetyAutoAlertEnabled();
      if (!autoAlertOn) {
        final why = AppConfig.isChinaRegion ? '[CN 合规闸门]' : '[用户已关闭]';
        if (kDebugMode) debugPrint('[SafetySignal] $why 拦截自动外发，转本地待确认: $reasons');
        await prefs.setStringList('pending_safety_alerts', reasons);
        await prefs.setString('pending_safety_alert_time', DateTime.now().toIso8601String());
      } else {
        // 海外版且用户开启：自动通知守护圈
        if (kDebugMode) debugPrint('[SafetySignal] 触发自动外发: $reasons');
        await NotifyService.sendHealthAlert(reasons);
      }

      await prefs.setString('last_safety_alert_time', DateTime.now().toIso8601String());

      // 【v1.97.3+167 今天时间流】体征异常落本地事件表（仅记录，不影响外发闸门逻辑）
      try {
        await CircleEventDao.insert(CircleEvent(
          type: CircleEventType.vitalAnomaly,
          actor: 'me',
          summary: '体征异常预警',
          detail: reasons.join('；'),
          ts: DateTime.now().millisecondsSinceEpoch,
        ));
      } catch (logErr) {
        if (kDebugMode) debugPrint('[SafetySignal] 写今日事件失败(忽略): $logErr');
      }
    } catch (e) {
      // 守护判定失败绝不影响主同步流程
      if (kDebugMode) debugPrint('[SafetySignal] 判定异常(忽略): $e');
    }
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
      // 【2026-07-15 修复】统一归一化为百分比：0.0-1.0 分数 → ×100；>1 视为已是百分比
      final boPct = bo <= 1.0 ? bo * 100 : bo;
      if (boPct > 0 && boPct < 90) {
        alerts.add('血氧饱和度偏低 (${boPct.toStringAsFixed(0)}%)');
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
  /// [fromWatch] = true 时表示来自 Apple Watch 的**明确用户签到动作**（手动点击），
  ///   此时跳过 HealthKit 权限 / 心跳门禁，直接执行签到，手机端弹 🔥 横幅 + 回包 Watch 庆祝
  /// [fromHeartbeat] = true 时表示来自 Apple Watch 的**自动心率检测签到**（零操作），
  ///   此时跳过门禁直接执行，手机端弹 💓 横幅（不回包 Watch，不打断用户）
  /// [clientId] 来自 Watch 的本次签到唯一 ID，用于把成功回包(streak/total)精准送回对应的 Watch
  static Future<void> performSilentHeartbeatCheckin({bool fromWatch = false, bool fromHeartbeat = false, String? clientId}) async {
    // ====== 中国合规版整改 ======
    // 关闭「传感器/信号自动代操作签到」（dead-man switch 核心之一）：
    // cn 区仅允许用户在 Watch 上明确手动点击（fromWatch）触发的签到；
    // 自动心率检测（fromHeartbeat，零操作）与基于最近心跳的自动签到（isAlive）一律不执行，
    // 改由用户手动确认平安，杜绝「无响应/传感器触发 → 系统自动代操作」。
    if (AppConfig.isChinaRegion && !fromWatch) {
      if (kDebugMode) debugPrint('[HealthService][CN] 已禁用自动心跳/信号签到（手动确认模式）');
      return;
    }

    // ====== 新增：检查来自 Watch App 的主动签到信号 ======
    final prefs = await SharedPreferences.getInstance();
    bool hasWatchSignal = prefs.getBool('pending_watch_checkin') ?? false;

    // 【P0】来自 Watch 的自动心率签到：直接执行，source='heartbeat'（弹💓横幅，不回包Watch）
    if (fromHeartbeat) {
      if (kDebugMode) debugPrint('[HealthService] 💓 来自 Watch 的心跳自动签到，跳过门禁直接执行 (clientId=$clientId)');
      await _executeCheckIn(prefs, source: 'heartbeat', clientId: clientId);
      return;
    }

    // 【v1.94.0 修复】来自 Watch 的明确签到：直接执行，不依赖健康权限/心跳
    if (fromWatch) {
      if (kDebugMode) debugPrint('[HealthService] 📱 来自 Watch 的明确签到，跳过门禁直接执行 (clientId=$clientId)');
      await _executeCheckIn(prefs, source: 'watch', clientId: clientId);
      return;
    }

    // 1. 检查权限
    bool hasPermission = await requestPermissions();
    if (!hasPermission && !hasWatchSignal) return;

    // 2. 检查最近心跳 或 检查是否有 Watch 信号
    bool isAlive = hasWatchSignal || await checkRecentHeartbeat();

    if (isAlive) {
      if (kDebugMode) debugPrint('[HealthService] 触发静默签到 (Watch信号: $hasWatchSignal)...');
      await _executeCheckIn(prefs, source: hasWatchSignal ? 'watch' : 'heartbeat', clientId: clientId);
    }
  }

  /// 【v1.94.0 抽取】真正执行一次签到并刷新本地/UI
  static Future<void> _executeCheckIn(SharedPreferences prefs, {required String source, String? clientId}) async {
    // 执行同步健康数据（顺便带上去）
    try {
      await syncHealthData();
    } catch (e) {
      if (kDebugMode) debugPrint('[HealthService] 同步健康数据失败(不影响签到): $e');
    }

    // 获取当前日期
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // 【v1.97.0 修复】用户隔离 key：连续 / 累计天数按 uid 后缀存储，
    // 回包 Watch 必须读取同名 key，否则 Watch 端显示的天数与手机不一致（历史 bug）。
    final uid = prefs.getString('user_id') ?? '';
    final streakKey = uid.isNotEmpty ? 'continuous_days_$uid' : 'continuous_days';
    final totalKey = uid.isNotEmpty ? 'total_check_in_days_$uid' : 'total_check_in_days';

    // 调用现有的签到接口 (心情默认为 0，代表静默签到)
    // 【v1.97.0 修复】包 try-catch：CheckinService.checkIn 在登录失效 / 网络异常时会抛异常，
    // 若未捕获会导致整个 _executeCheckIn 中断 —— 既不回包 Watch（手表卡「签到中」），
    // 也不刷新手机 UI（手机显示未签到）。这里无论成功 / 失败 / 异常都确保回包 + 刷新。
    Map<String, dynamic> res;
    try {
      res = await CheckinService.checkIn(
        date: today,
        mood: 0,
      ).timeout(const Duration(seconds: 10));
    } on TimeoutException catch (e) {
      if (kDebugMode) debugPrint('[HealthService] ⚠️ Watch 签到请求超时(10s，避免永久卡死): $e');
      if (source == 'watch' && clientId != null && clientId.isNotEmpty) {
        _sendWatchAck(
          clientId: clientId,
          streak: StreakUtil.readStreak(prefs, uid),
          total: prefs.getInt(totalKey) ?? 0,
          success: false,
          alreadyDone: false,
        );
      }
      watchCheckinCompleteSignal.value++;
      return;
    } catch (e) {
      if (kDebugMode) debugPrint('[HealthService] ⚠️ Watch 签到请求异常(登录失效/网络错误): $e');
      // 异常兜底：让 Watch 不卡死，但诚实回包「失败」（不再假绿为已签到），
      // 手机端刷新最新状态
      if (source == 'watch' && clientId != null && clientId.isNotEmpty) {
        _sendWatchAck(
          clientId: clientId,
          streak: StreakUtil.readStreak(prefs, uid),
          total: prefs.getInt(totalKey) ?? 0,
          success: false,
          alreadyDone: false,
        );
      }
      watchCheckinCompleteSignal.value++;
      return;
    }

    if (res['success'] == true) {
      if (kDebugMode) debugPrint('[HealthService] ✅ 签到成功 (source=$source)');
      final lastDateKey = uid.isNotEmpty ? 'last_check_in_date_$uid' : 'last_check_in_date';
      // 【v1.97.2 彻底修复】以「本地签到历史」为单一真相源重算连续天数，
      // 不再直接信任后端易错的 streak 字段（曾导致手表签到后手机首屏显示 6 而非真实 3，
      // 需等后台 SyncService.pullFromServer 二次合并才纠正）。
      // 把今天并入本地历史后用 StreakUtil 统一计算，与手机端 _handleCheckIn 完全一致，
      // 保证「第一次签到连续天数就准确」，且回包 Watch 的值也一致。
      final historyKey = uid.isNotEmpty ? 'checkin_history_$uid' : 'checkin_history';
      final historyList = List<String>.from(prefs.getStringList(historyKey) ?? []);
      if (!historyList.contains(today)) historyList.add(today);
      final newDays = StreakUtil.calculateStreak(historyList);
      // 累计天数：优先取服务端 total_days（含跨设备历史），否则以本地历史条数为准（只增不减）
      final serverTotal = res['total_days'] as int?;
      final newTotal = (serverTotal != null && serverTotal > historyList.length)
          ? serverTotal
          : historyList.length;

      await prefs.setStringList(historyKey, historyList);
      await prefs.setInt(streakKey, newDays);
      await prefs.setInt(totalKey, newTotal);
      await prefs.setString(lastDateKey, today);
      await prefs.setString('last_check_in_date', today);

      // 【v1.93.1 修复】通知 HomePage 刷新签到 UI（Watch 签到后手机端有视觉反馈）
      watchCheckinCompleteSignal.value++;

      // 【v1.94.0 新增】手机端酷炫确认横幅
      // source == 'watch' → 🔥 手动签到，弹横幅 + 回包 Watch 庆祝
      // source == 'heartbeat' → 💓 自动心率签到，弹横幅（不回包，不打断用户）
      if (source == 'watch' || source == 'heartbeat') {
        watchCheckinCelebration.value = {
          'success': true,
          'source': source,
          'streak': newDays,
          'total': newTotal,
          'clientId': clientId ?? '',
        };

        // 【P3】场景化确认：真实签到（手表/心跳）视为已确认平安，
        // 同步更新定时确认状态（重置未确认计数）；若用户选择对应触发方式则弹主动通知
        try {
          await SafetyService.onSceneCheckIn?.call(source);
        } catch (e) {
          if (kDebugMode) debugPrint('[HealthService] 场景化确认同步失败(不影响签到): $e');
        }
      }

      unawaited(SyncService.pullFromServer());

      // 清除 Watch 信号
      await prefs.remove('pending_watch_checkin');

      // 【v1.94.0 新增】把成功回包(streak/total)精准送回对应的 Apple Watch（仅手动签到需要庆祝回包）
      if (source == 'watch' && clientId != null && clientId.isNotEmpty) {
        _sendWatchAck(clientId: clientId, streak: newDays, total: newTotal);
      }
    } else {
      if (kDebugMode) debugPrint('[HealthService] ⚠️ 签到返回未成功: ${res['error']}');
      // 即使服务端返回未成功(例如已签到)，也尝试回包让 Watch 显示已签到状态
      if (source == 'watch' && clientId != null && clientId.isNotEmpty) {
        _sendWatchAck(clientId: clientId, streak: StreakUtil.readStreak(prefs, uid), total: prefs.getInt(totalKey) ?? 0, alreadyDone: true);
      }
    }
  }

  /// 【v1.94.0】把签到结果回包给对应的 Apple Watch（streak/total 用于 Watch 端庆祝动画）
  /// [success] 签到你真正是否成功（异常时为 false，便于 Watch 诚实显示失败而非假绿）
  static void _sendWatchAck({required String clientId, required int streak, required int total, bool alreadyDone = false, bool success = true}) {
    try {
      _watchChannel.invokeMethod('ackWatchCheckin', {
        'client_id': clientId,
        'success': success,
        'already_done': alreadyDone,
        'streak': streak,
        'total': total,
      });
      if (kDebugMode) debugPrint('[HealthService] 📤 已回包 Watch 签到结果 (clientId=$clientId, streak=$streak)');
    } catch (e) {
      if (kDebugMode) debugPrint('[HealthService] ⚠️ 回包 Watch 失败: $e');
    }
  }

  /// 【v1.97.0 修复】查询当前用户(已登录 uid 隔离)的连续/累计签到天数，
  /// 供 Apple Watch 通过 status_query 主动拉取，确保每天打开手表都显示与手机一致的最新值。
  static Future<Map<String, int>> _queryWatchStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('user_id') ?? '';
    final totalKey = uid.isNotEmpty ? 'total_check_in_days_$uid' : 'total_check_in_days';
    return {
      'streak': StreakUtil.readStreak(prefs, uid),
      'total': prefs.getInt(totalKey) ?? 0,
    };
  }

  // ==================== HealthKit 跌倒检测 MethodChannel ====================

  static const MethodChannel _healthKitChannel = MethodChannel('zaine/healthkit');

  /// 【v1.91.0】Watch 签到 MethodChannel — AppDelegate 收到 Watch 签到后立即通知 Flutter
  static const MethodChannel _watchChannel = MethodChannel('zaine/watch');
  static bool _watchChannelInitialized = false;

  /// 【v1.93.0 修复】Watch SOS 信号 — ValueNotifier 通知 UI 层触发紧急求助
  /// MainNavigation 监听此信号切换到求助 Tab，HelpPage 监听此信号自动触发倒计时
  static final ValueNotifier<int> watchSOSSignal = ValueNotifier(0);
  static bool pendingWatchSOS = false;

  /// 【v1.93.1 修复】Watch 签到完成信号 — HomePage 监听此信号刷新签到 UI
  /// 修复：Watch 点击确认签到后，手机端无任何视觉反馈
  static final ValueNotifier<int> watchCheckinCompleteSignal = ValueNotifier<int>(0);

  /// 【v1.94.0 新增】Watch 签到酷炫确认信号 — HomePage 监听后弹出庆祝横幅
  /// value: {'success': true, 'source': 'watch'|'heartbeat', 'streak': int, 'total': int, 'clientId': String}
  static final ValueNotifier<Map<String, dynamic>> watchCheckinCelebration =
      ValueNotifier<Map<String, dynamic>>({});

  /// 初始化 Watch MethodChannel 监听（在 App 启动时调用一次）
  static void initWatchChannel() {
    if (_watchChannelInitialized) {
      if (kDebugMode) debugPrint('[HealthService] ⚠️ Watch MethodChannel 已初始化，跳过');
      return;
    }
    _watchChannelInitialized = true;
    if (kDebugMode) debugPrint('[HealthService] 📱 initWatchChannel() 被调用，开始注册 MethodChannel 监听...');
    _watchChannel.setMethodCallHandler((call) async {
      // 【2026-07-15 修复】handler 整体包 try-catch：任何异常都被隔离，绝不中断 MethodChannel，
      // 保证后续 Watch 消息（签到/SOS）仍能正常处理，手表不会因一次异常永久卡死。
      try {
        if (kDebugMode) debugPrint('[HealthService] 📨 MethodChannel 收到调用: method=${call.method}, arguments=${call.arguments}');
        if (call.method == 'watchCheckin') {
          if (kDebugMode) debugPrint('[HealthService] 📱 收到 Watch 签到通知，立即执行签到...');
          // 【P0】区分手动签到(watch)与自动心率签到(heartbeat)，两者都跳过健康权限/心跳门禁
          final args = call.arguments as Map<dynamic, dynamic>?;
          final clientId = args?['client_id'] as String?;
          final fromWatch = args?['fromWatch'] as bool? ?? false;
          final fromHeartbeat = args?['fromHeartbeat'] as bool? ?? false;
          await performSilentHeartbeatCheckin(fromWatch: fromWatch, fromHeartbeat: fromHeartbeat, clientId: clientId);
          if (kDebugMode) debugPrint('[HealthService] ✅ Watch 签到执行完成 (fromWatch=$fromWatch, fromHeartbeat=$fromHeartbeat)');
        } else if (call.method == 'watchSOS') {
          // 【v1.93.0 修复】Watch SOS — 通知 Flutter 端触发紧急求助流程
          if (kDebugMode) debugPrint('[HealthService] 🚨 收到 Watch SOS 通知，触发紧急求助...');
          pendingWatchSOS = true;
          watchSOSSignal.value++;
          if (kDebugMode) debugPrint('[HealthService] ✅ Watch SOS 信号已发出 (watchSOSSignal=${watchSOSSignal.value})');
        } else if (call.method == 'queryWatchStatus') {
          // 【v1.97.0 修复】Watch 主动拉取当前连续/累计天数，确保每天打开手表与手机一致
          if (kDebugMode) debugPrint('[HealthService] 📱 Watch 请求当前签到状态(queryWatchStatus)');
          final status = await _queryWatchStatus();
          return status;
        } else if (call.method == 'requestHealthData') {
          // 【v1.97.3 修复 Issue A】手表健康速览主动拉取：同步健康并推送到 Watch
          if (kDebugMode) debugPrint('[HealthService] 📱 Watch 请求健康数据(requestHealthData)，同步并推送');
          unawaited(syncHealthData());
        } else {
          if (kDebugMode) debugPrint('[HealthService] ❓ 未知的 MethodChannel 调用: ${call.method}');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[HealthService] ⚠️ Watch MethodChannel 处理异常(已隔离，不影响后续消息): $e');
      }
    });
    if (kDebugMode) debugPrint('[HealthService] ✅ Watch MethodChannel 已初始化（含 SOS 监听）, _watchChannelInitialized=$_watchChannelInitialized');

    // 【2026-07-16 修复】轮询兜底：即使 native→Flutter 的 invokeMethod 因冷启动/后台/messenger
    // 路由问题未送达，也通过监听 UserDefaults 的 pending_watch_checkin 主动补发签到。
    // 这是彻底解决「手表签到手机无反应」的最后一道保险。
    _startWatchCheckinPolling();
    // 立即检查一次（覆盖 cold start 期间已到达的签到）
    _pollWatchCheckin();
  }

  /// 【2026-07-16 修复】轮询兜底：检测 native 写入的 pending_watch_checkin + watch_pending_client_id，
  /// 主动补发 Watch 签到，彻底绕过 native→Flutter invokeMethod 的路由不确定性。
  static final Set<String> _polledWatchClientIds = {};
  static Timer? _watchCheckinPoller;
  static void _startWatchCheckinPolling() {
    _watchCheckinPoller?.cancel();
    _watchCheckinPoller = Timer.periodic(const Duration(seconds: 2), (_) => _pollWatchCheckin());
    if (kDebugMode) debugPrint('[HealthService] 🔄 Watch 签到轮询兜底已启动(每2s)');
  }
  static Future<void> _pollWatchCheckin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getBool('pending_watch_checkin') ?? false;
      if (!pending) return;
      final cid = prefs.getString('watch_pending_client_id');
      if (cid == null || cid.isEmpty) {
        if (kDebugMode) debugPrint('[HealthService] 🔄 轮询发现待处理 Watch 签到(无 clientId)，直接补发');
        await performSilentHeartbeatCheckin(fromWatch: true);
        await prefs.setBool('pending_watch_checkin', false);
        return;
      }
      if (_polledWatchClientIds.contains(cid)) return; // 防重复处理同一签到
      _polledWatchClientIds.add(cid);
      if (kDebugMode) debugPrint('[HealthService] 🔄 轮询发现待处理 Watch 签到 (clientId=$cid)');
      await performSilentHeartbeatCheckin(fromWatch: true, clientId: cid);
    } catch (e) {
      if (kDebugMode) debugPrint('[HealthService] ⚠️ 轮询 Watch 签到异常: $e');
    }
  }

  /// 请求跌倒检测授权
  static Future<bool> requestFallDetectionAuthorization() async {
    try {
      final bool? result = await _healthKitChannel.invokeMethod<bool>('requestFallDetectionAuthorization');
      if (kDebugMode) debugPrint('[HealthService] 跌倒检测授权结果: $result');
      return result ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('[HealthService] 请求跌倒检测授权失败: $e');
      return false;
    }
  }

  /// 获取最近 N 小时的跌倒事件
  static Future<List<Map<String, dynamic>>> getRecentFallEvents({int hours = 24}) async {
    try {
      final List<dynamic>? result = await _healthKitChannel.invokeMethod<List<dynamic>>(
        'getRecentFallEvents',
        {'hours': hours},
      );
      if (result == null) return [];
      return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[HealthService] 获取跌倒事件失败: $e');
      return [];
    }
  }

  /// 检查是否有新的跌倒事件，并记录到 SafetyService
  /// [onNewFall] 发现新事件时的回调
  static Future<List<Map<String, dynamic>>> checkForNewFallEvents({
    void Function(Map<String, dynamic>)? onNewFall,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheckStr = prefs.getString('last_fall_check_time');
    final lastCheck = lastCheckStr != null
        ? DateTime.tryParse(lastCheckStr)
        : null;
    
    // 请求授权（首次会弹出权限框）
    await requestFallDetectionAuthorization();
    
    // 拉取过去 7 天的跌倒事件（避免遗漏）
    final events = await getRecentFallEvents(hours: 24 * 7);
    final now = DateTime.now();
    final newEvents = <Map<String, dynamic>>[];
    
    for (final event in events) {
      final ts = DateTime.tryParse(event['timestamp']?.toString() ?? '');
      if (ts == null) continue;
      if (lastCheck == null || ts.isAfter(lastCheck)) {
        newEvents.add(event);
      }
    }
    
    // 更新时间戳
    await prefs.setString('last_fall_check_time', now.toIso8601String());
    
    if (newEvents.isNotEmpty) {
      if (kDebugMode) debugPrint('[HealthService] 发现 ${newEvents.length} 个新的跌倒事件');
      if (onNewFall != null) {
        for (final event in newEvents) {
          onNewFall(event);
        }
      }
    }
    
    return newEvents;
  }
}
