/// 安全服务模块
///
/// 提供定时安全确认、跌倒检测、位置共享等功能
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../api_service.dart';
import '../api/notify_service.dart';
import '../api/checkin_service.dart';
import '../../services/platform/health_service.dart';
import 'geofence_service.dart';
import '../../config/app_config.dart';
import 'package:intl/intl.dart';

/// 定时确认状态
enum CheckInReminderStatus {
  disabled,
  daily,
  weekly,
  custom,
}

/// 定时确认触发方式（【P3】智能场景触发）
enum CheckInTriggerMode {
  time, // 时间定时（默认）：在设定时间点提醒确认
  location, // 离开安全区时自动确认平安
  heartbeat, // Apple Watch 检测到你（心率）时自动确认平安
}

/// 定时确认提醒配置
class CheckInReminder {
  final bool enabled;
  final CheckInReminderStatus status;
  final List<int> reminderHours; // 提醒小时列表，如 [9, 14, 21] 表示早中晚
  final CheckInTriggerMode triggerMode; // 【P3】触发方式
  final DateTime? lastCheckIn;
  final DateTime? nextReminder;
  final int missedCount; // 连续未确认次数

  const CheckInReminder({
    this.enabled = false,
    this.status = CheckInReminderStatus.disabled,
    this.reminderHours = const [9, 21],
    this.triggerMode = CheckInTriggerMode.time,
    this.lastCheckIn,
    this.nextReminder,
    this.missedCount = 0,
  });

  CheckInReminder copyWith({
    bool? enabled,
    CheckInReminderStatus? status,
    List<int>? reminderHours,
    CheckInTriggerMode? triggerMode,
    DateTime? lastCheckIn,
    DateTime? nextReminder,
    int? missedCount,
  }) {
    return CheckInReminder(
      enabled: enabled ?? this.enabled,
      status: status ?? this.status,
      reminderHours: reminderHours ?? this.reminderHours,
      triggerMode: triggerMode ?? this.triggerMode,
      lastCheckIn: lastCheckIn ?? this.lastCheckIn,
      nextReminder: nextReminder ?? this.nextReminder,
      missedCount: missedCount ?? this.missedCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'status': status.name,
        'reminder_hours': reminderHours,
        'trigger_mode': triggerMode.name,
        'last_check_in': lastCheckIn?.toIso8601String(),
        'next_reminder': nextReminder?.toIso8601String(),
        'missed_count': missedCount,
      };

  factory CheckInReminder.fromJson(Map<String, dynamic> json) {
    return CheckInReminder(
      enabled: json['enabled'] as bool? ?? false,
      status: CheckInReminderStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => CheckInReminderStatus.disabled,
      ),
      reminderHours: (json['reminder_hours'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [9, 21],
      triggerMode: CheckInTriggerMode.values.firstWhere(
        (e) => e.name == json['trigger_mode'],
        orElse: () => CheckInTriggerMode.time,
      ),
      lastCheckIn: json['last_check_in'] != null
          ? DateTime.parse(json['last_check_in'] as String)
          : null,
      nextReminder: json['next_reminder'] != null
          ? DateTime.parse(json['next_reminder'] as String)
          : null,
      missedCount: json['missed_count'] as int? ?? 0,
    );
  }
}

/// 位置记录数据模型
class LocationRecord {
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? altitude;
  final String? address;
  final LocationActivityType? activityType;

  const LocationRecord({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.altitude,
    this.address,
    this.activityType,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'altitude': altitude,
        'address': address,
        'activity_type': activityType?.name,
      };

  factory LocationRecord.fromJson(Map<String, dynamic> json) {
    return LocationRecord(
      timestamp: DateTime.parse(json['timestamp'] as String),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
      address: json['address'] as String?,
      activityType: json['activity_type'] != null
          ? LocationActivityType.values.firstWhere(
              (e) => e.name == json['activity_type'],
              orElse: () => LocationActivityType.unknown,
            )
          : null,
    );
  }
}

/// 位置追踪模式
enum LocationTrackingMode {
  realtime,  // 实时追踪：每30秒
  normal,    // 普通模式：每5分钟
  powersave, // 省电模式：每15分钟
}

/// 位置活动类型
enum LocationActivityType {
  stationary,  // 静止
  walking,     // 行走
  running,     // 跑步
  cycling,     // 骑行
  driving,     // 驾驶
  unknown,     // 未知
}

/// 跌倒事件数据模型
class FallEvent {
  final String id;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double? confidence; // 置信度 0-1
  final bool acknowledged; // 是否已确认
  final DateTime? acknowledgedAt;
  final String? notes;
  final bool guardianNotified; // 【v1.92.0】是否已通知守护者
  final String source; // 【v1.92.0】检测来源: 'watch' / 'phone'

  const FallEvent({
    required this.id,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.confidence,
    this.acknowledged = false,
    this.acknowledgedAt,
    this.notes,
    this.guardianNotified = false,
    this.source = 'watch',
  });

  /// 是否来自手机端检测
  bool get isPhoneSource => source == 'phone';

  FallEvent copyWith({
    String? id,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    double? confidence,
    bool? acknowledged,
    DateTime? acknowledgedAt,
    String? notes,
    bool? guardianNotified,
    String? source,
  }) {
    return FallEvent(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      confidence: confidence ?? this.confidence,
      acknowledged: acknowledged ?? this.acknowledged,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      notes: notes ?? this.notes,
      guardianNotified: guardianNotified ?? this.guardianNotified,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'confidence': confidence,
        'acknowledged': acknowledged,
        'acknowledged_at': acknowledgedAt?.toIso8601String(),
        'notes': notes,
        'guardian_notified': guardianNotified,
        'source': source,
      };

  factory FallEvent.fromJson(Map<String, dynamic> json) {
    return FallEvent(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      confidence: (json['confidence'] as num?)?.toDouble(),
      acknowledged: json['acknowledged'] as bool? ?? false,
      acknowledgedAt: json['acknowledged_at'] != null
          ? DateTime.parse(json['acknowledged_at'] as String)
          : null,
      notes: json['notes'] as String?,
      guardianNotified: json['guardian_notified'] as bool? ?? false,
      source: json['source'] as String? ?? 'watch',
    );
  }
}

/// 安全服务 - 管理定时确认、位置共享、跌倒检测
class SafetyService {
  static const String _reminderKey = 'checkin_reminder';
  static const String _locationHistoryKey = 'location_history';
  static const String _fallEventsKey = 'fall_events';

  SharedPreferences? _prefs;
  Timer? _reminderTimer;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // 回调函数
  Function(CheckInReminder)? onReminderDue;
  Function(FallEvent)? onFallDetected;
  Function(LocationRecord)? onLocationUpdate;

  /// 【P3】场景化确认桥接：由 health_service（Watch 心跳签到）调用
  /// 签名为 Future 以便内部做异步持久化
  static Future<void> Function(String source, {String? fenceName})? onSceneCheckIn;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // 初始化通知
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _notifications.initialize(initSettings);
    await _notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    // 【P3】注册场景化确认桥接
    // 1) Watch 心跳签到 → 由 health_service 在 _executeCheckIn(source:'heartbeat') 触发
    onSceneCheckIn = _applySceneCheckIn;
    // 2) 离开安全围栏 → 由 geofence_service.checkAllFences 触发（全局回调，避免实例差异）
    GeoFenceService.onFenceExitedGlobal = (fence) {
      onSceneCheckIn?.call('location', fenceName: fence.name);
    };

    _isInitialized = true;
    if (kDebugMode) debugPrint('[SafetyService] 初始化完成');
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) await initialize();
    _prefs ??= await SharedPreferences.getInstance();
  }

  // ==================== 定时确认功能 ====================

  /// 获取定时确认配置（优先后端，兜底本地）
  Future<CheckInReminder> getReminderConfig() async {
    await _ensureInitialized();

    // 优先从后端拉取
    try {
      final res = await ApiService.get('/api/safety/reminder', auth: true);
      if (res['success'] == true) {
        // 去除 success 字段后直接用 CheckInReminder.fromJson 解析
        final data = Map<String, dynamic>.from(res);
        data.remove('success');
        data.remove('error');
        final config = CheckInReminder.fromJson(data);
        // 同步到本地缓存
        await _prefs!.setString(_reminderKey, jsonEncode(config.toJson()));
        return config;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[SafetyService] 后端获取提醒配置失败，使用本地缓存: $e');
    }

    // 兜底：从本地缓存读取
    final jsonStr = _prefs!.getString(_reminderKey);
    if (jsonStr == null) return const CheckInReminder();
    try {
      return CheckInReminder.fromJson(jsonDecode(jsonStr));
    } catch (e) {
      if (kDebugMode) debugPrint('[SafetyService] 解析提醒配置失败: $e');
      return const CheckInReminder();
    }
  }

  /// 保存定时确认配置（同步到后端 + 本地）
  Future<void> saveReminderConfig(CheckInReminder config) async {
    await _ensureInitialized();

    // 先同步到后端
    try {
      await ApiService.post(
        '/api/safety/reminder',
        body: {
          'enabled': config.enabled,
          'status': config.status.name,
          'reminder_hours': config.reminderHours,
        },
        auth: true,
      );
      if (kDebugMode) debugPrint('[SafetyService] 提醒配置已同步到后端');
    } catch (e) {
      if (kDebugMode) debugPrint('[SafetyService] 后端同步失败，仅保存到本地: $e');
    }

    // 保存到本地缓存
    await _prefs!.setString(_reminderKey, jsonEncode(config.toJson()));
    if (kDebugMode) debugPrint('[SafetyService] 提醒配置已保存: ${config.status}');

    // 更新定时器
    // 中国区首版隐藏定时确认：不启动漏签自动提醒定时器
    if (config.enabled && !AppConfig.isChinaRegion) {
      _startReminderTimer(config);
    } else {
      _stopReminderTimer();
    }
  }

  /// 启用定时确认
  Future<void> enableReminder(
    CheckInReminderStatus status, {
    List<int>? hours,
    CheckInTriggerMode triggerMode = CheckInTriggerMode.time,
  }) async {
    final config = CheckInReminder(
      enabled: true,
      status: status,
      reminderHours: hours ?? [9, 21],
      triggerMode: triggerMode,
      missedCount: 0,
    );
    await saveReminderConfig(config);
  }

  /// 禁用定时确认
  Future<void> disableReminder() async {
    final current = await getReminderConfig();
    await saveReminderConfig(current.copyWith(enabled: false));
  }

  /// 执行定时确认（同步到后端 + 本地）
  Future<void> performCheckIn() async {
    await _ensureInitialized();
    final current = await getReminderConfig();

    // 先同步到后端
    try {
      final res = await ApiService.post('/api/safety/checkin', auth: true);
      if (kDebugMode) debugPrint('[SafetyService] 定时确认已同步到后端: ${res['message']}');
    } catch (e) {
      if (kDebugMode) debugPrint('[SafetyService] 后端同步失败，仅本地保存: $e');
    }

    final now = DateTime.now();
    final nextReminder = _calculateNextReminder(now, current.reminderHours);

    final updated = current.copyWith(
      lastCheckIn: now,
      nextReminder: nextReminder,
      missedCount: 0, // 重置未确认计数
    );

    await saveReminderConfig(updated);
    if (kDebugMode) debugPrint('[SafetyService] 定时确认完成，下次提醒: $nextReminder');
  }

  /// 启动定时器
  void _startReminderTimer(CheckInReminder config) {
    _stopReminderTimer();
    
    // 每分钟检查一次
    _reminderTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      final now = DateTime.now();
      final currentConfig = await getReminderConfig();
      
      if (!currentConfig.enabled) {
        _stopReminderTimer();
        return;
      }

      // 检查是否到达提醒时间
      if (currentConfig.reminderHours.contains(now.hour) && now.minute == 0) {
        _triggerReminder();
      }

      // 检查是否错过提醒
      if (currentConfig.nextReminder != null && 
          now.isAfter(currentConfig.nextReminder!)) {
        await _handleMissedReminder(currentConfig);
      }
    });
    
    if (kDebugMode) debugPrint('[SafetyService] 定时器已启动');
  }

  void _stopReminderTimer() {
    _reminderTimer?.cancel();
    _reminderTimer = null;
  }

  void _triggerReminder() {
    if (kDebugMode) debugPrint('[SafetyService] 触发定时确认提醒');
    
    // 【v1.90.2】Apple Watch 辅助确认：检查 Watch 近期活动
    _tryWatchAuxiliaryCheckin();
    
    _showReminderNotification();
    onReminderDue?.call(const _CheckInReminderImpl(enabled: true, status: CheckInReminderStatus.daily));
  }

  /// 【v1.90.2】尝试通过 Apple Watch 数据辅助完成签到
  ///
  /// 【中国合规版整改】关闭"传感器自动代操作"（dead-man switch 核心之一）：
  /// cn 区不再自动完成签到，改为本地提醒用户本人决定是否确认平安。
  Future<void> _tryWatchAuxiliaryCheckin() async {
    if (AppConfig.isChinaRegion) {
      // 仅本地提示，绝不自动代操作
      await _showLocalPrompt(
        1004,
        '手表检测到你 💓',
        '是否已平安？点开 App 即可一键确认',
      );
      if (kDebugMode) {
        debugPrint('[SafetyService][CN] 手表检测本地提醒（未自动签到）');
      }
      return;
    }
    try {
      final hasRecentActivity = await HealthService.checkRecentHeartbeat();
      if (hasRecentActivity) {
        if (kDebugMode) debugPrint('[SafetyService] Watch 检测到近期活动，辅助完成签到');
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        await CheckinService.checkIn(date: today, mood: 0);
        if (kDebugMode) debugPrint('[SafetyService] Watch 辅助签到成功');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[SafetyService] Watch 辅助签到失败: $e');
    }
  }

  Future<void> _handleMissedReminder(CheckInReminder config) async {
    final updated = config.copyWith(missedCount: config.missedCount + 1);
    await saveReminderConfig(updated);

    // 通知守护人（App 内 Push，通过后端 APNs 推送）
    if (updated.missedCount >= 1) {
      if (AppConfig.isChinaRegion) {
        // 【中国合规版整改】关闭"自动通知第三方亲友"（dead-man switch 核心）：
        // 改为仅本地提醒用户本人，由用户手动确认后再通知守护人
        await _showLocalPrompt(
          1003,
          '已连续 ${updated.missedCount} 次未确认平安',
          '如需让守护人知道，请打开 App 手动通知守护人',
        );
        if (kDebugMode) {
          debugPrint('[SafetyService][CN] 漏签本地提醒（未自动通知守护人）: '
              '${updated.missedCount} 次');
        }
      } else {
        await NotifyService.notifyGuardiansAboutMissedCheckIn(updated.missedCount);
      }
    }
  }

  /// 【中国合规版】统一本地提醒用户本人（不自动外发、不自动代操作）
  Future<void> _showLocalPrompt(int id, String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'checkin_reminder',
      '定时确认提醒',
      channelDescription: '提醒您进行平安确认',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _notifications.show(id, title, body, details);
  }

  /// 【中国合规版】用户手动确认后，主动通知守护人（漏签场景）
  ///
  /// UI 在用户明确表示"要通知守护人"时调用，守护人才可见。
  Future<void> notifyGuardiansMissedCheckInManually(int missedCount) async {
    await NotifyService.notifyGuardiansAboutMissedCheckIn(missedCount);
  }

  Future<void> _showReminderNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'checkin_reminder',
      '定时确认提醒',
      channelDescription: '提醒您进行平安确认',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      1001,
      '平安确认提醒 💚',
      '您今天还没有确认平安，点击这里进行签到',
      details,
    );
  }

  // ==================== 【P3】智能场景触发 ====================

  /// 场景化确认：当发生真实签到事件（如离开安全区 / Watch 心跳检测到你）时调用
  ///
  /// [source] 'location'（离开安全区）或 'heartbeat'（Watch 检测到你）
  /// [fenceName] 离开的围栏名称（location 场景用）
  ///
  /// 逻辑：
  /// 1. 任何真实签到都视为「已确认平安」，更新 lastCheckIn / 重置 missedCount / 重算 nextReminder
  /// 2. 仅当用户在「对应触发方式」时，才弹场景化主动通知（time 模式保持原有时间提醒流）
  Future<void> _applySceneCheckIn(String source, {String? fenceName}) async {
    // 【中国合规版整改】关闭"传感器/场景自动代操作"（dead-man switch 核心之一）：
    // cn 区不自动签到，仅本地提醒用户本人，由用户手动确认平安。
    if (AppConfig.isChinaRegion) {
      final title = source == 'location' ? '已离开${fenceName ?? '安全区'}' : '手表检测到你';
      final body = source == 'location'
          ? '你已离开「${fenceName ?? '安全区'}」，请打开 App 确认平安'
          : '检测到你的心跳，请打开 App 确认平安';
      await _showLocalPrompt(1005, title, body);
      if (kDebugMode) {
        debugPrint('[SafetyService][CN] 场景化确认本地提醒（未自动签到）: source=$source');
      }
      return;
    }

    final current = await getReminderConfig();
    if (!current.enabled) return;

    final now = DateTime.now();
    final updated = current.copyWith(
      lastCheckIn: now,
      nextReminder: _calculateNextReminder(now, current.reminderHours),
      missedCount: 0, // 任何真实签到都清零未确认计数
    );
    await saveReminderConfig(updated);

    // 场景化主动通知：仅当用户明确选择该触发方式时
    final matchesMode = (source == 'location' &&
            current.triggerMode == CheckInTriggerMode.location) ||
        (source == 'heartbeat' &&
            current.triggerMode == CheckInTriggerMode.heartbeat);
    if (matchesMode) {
      await _showSceneCheckInNotification(source, fenceName: fenceName);
    }

    if (kDebugMode) {
      debugPrint('[SafetyService] 场景化确认已应用: source=$source, '
          'triggerMode=${current.triggerMode.name}, matchesMode=$matchesMode');
    }
  }

  /// 场景化确认本地通知
  Future<void> _showSceneCheckInNotification(String source, {String? fenceName}) async {
    const androidDetails = AndroidNotificationDetails(
      'checkin_reminder',
      '定时确认提醒',
      channelDescription: '提醒您进行平安确认',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    if (source == 'location') {
      await _notifications.show(
        1002,
        '已离开安全区，自动确认平安 🛡️',
        '离开「${fenceName ?? '安全区'}」，已自动为你签到平安',
        details,
      );
    } else {
      await _notifications.show(
        1002,
        '手表检测到你，自动确认平安 💓',
        '检测到你的心跳，已自动为你签到平安',
        details,
      );
    }
  }

  // TODO(v1.20.0+): 守护人通知功能（需营业执照申请短信模板或接入微信订阅消息）
  // Future<void> _notifyGuardiansAboutMissedCheckIn(int missedCount) async {
  //   if (kDebugMode) debugPrint('[SafetyService] 连续$missedCount次未确认，通知守护人');
  //   try {
  //     final res = await ApiService.post(
  //       '/safety/notify-guardians',
  //       body: {'missed_count': missedCount},
  //     );
  //     if (kDebugMode) {
  //       debugPrint('[SafetyService] 守护人通知结果: $res');
  //     }
  //   } catch (e) {
  //     if (kDebugMode) debugPrint('[SafetyService] 通知守护人失败: $e');
  //   }
  // }

  DateTime _calculateNextReminder(DateTime now, List<int> hours) {
    hours.sort();
    for (final hour in hours) {
      final reminderTime = DateTime(now.year, now.month, now.day, hour);
      if (reminderTime.isAfter(now)) {
        return reminderTime;
      }
    }
    // 所有今天的提醒都已过，明天第一个
    return DateTime(now.year, now.month, now.day + 1, hours.first);
  }

  // ==================== 位置共享功能 ====================
  
  static const String _lastLocationKey = 'last_location_record';
  static const String _trackingModeKey = 'location_tracking_mode'; // 【v1.93.0】
  static const String _locationTrackingEnabledKey = 'location_tracking_enabled'; // 【v1.95.0】持久化开关状态
  Timer? _locationTimer; // 位置记录定时器
  LocationTrackingMode _trackingMode = LocationTrackingMode.normal; // 【v1.93.0】

  /// 获取追踪间隔（根据模式）
  Duration _getTrackingInterval(LocationTrackingMode mode) {
    switch (mode) {
      case LocationTrackingMode.realtime:
        return const Duration(seconds: 30);
      case LocationTrackingMode.normal:
        return const Duration(minutes: 5);
      case LocationTrackingMode.powersave:
        return const Duration(minutes: 15);
    }
  }

  /// 获取当前追踪模式
  LocationTrackingMode get trackingMode => _trackingMode;

  /// 当前是否正在追踪位置
  /// 当前是否正在追踪位置（以持久化状态为准，避免 App 回后台/重进后定时器销毁导致误显示关闭）
  bool get isLocationTracking {
    final persisted = _prefs?.getBool(_locationTrackingEnabledKey);
    if (persisted != null) return persisted;
    return _locationTimer != null && _locationTimer!.isActive;
  }

  /// 开始位置跟踪
  /// [mode] 追踪模式，默认为普通模式
  Future<bool> startLocationTracking({LocationTrackingMode mode = LocationTrackingMode.normal}) async {
    // 1. 请求权限
    final status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) {
      if (kDebugMode) debugPrint('[SafetyService] 位置权限未授权');
      return false;
    }

    // 2. 检查位置服务是否开启
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (kDebugMode) debugPrint('[SafetyService] 位置服务未开启');
      return false;
    }

    // 3. 停止之前的定时器（如果有）
    _stopLocationTimer();

    // 4. 保存模式
    _trackingMode = mode;
    await _ensureInitialized();
    await _prefs!.setString(_trackingModeKey, mode.name);

    // 5. 立即记录一次位置
    await _recordLocation();

    // 6. 启动定时器（根据模式设置间隔）
    final interval = _getTrackingInterval(mode);
    _locationTimer = Timer.periodic(interval, (timer) async {
      await _recordLocation();
    });

    await _ensureInitialized();
    await _prefs!.setBool(_locationTrackingEnabledKey, true);
    if (kDebugMode) debugPrint('[SafetyService] 位置跟踪已启动（模式: ${mode.name}, 间隔: ${interval.inSeconds}s）');
    return true;
  }

  /// 切换追踪模式（不停止追踪）
  Future<void> switchTrackingMode(LocationTrackingMode mode) async {
    if (_locationTimer == null) return; // 没在追踪就别切
    _trackingMode = mode;
    await _ensureInitialized();
    await _prefs!.setString(_trackingModeKey, mode.name);

    _stopLocationTimer();
    final interval = _getTrackingInterval(mode);
    _locationTimer = Timer.periodic(interval, (timer) async {
      await _recordLocation();
    });

    if (kDebugMode) debugPrint('[SafetyService] 追踪模式已切换: ${mode.name} (间隔: ${interval.inSeconds}s)');
  }

  /// 加载上次保存的追踪模式
  Future<LocationTrackingMode> getSavedTrackingMode() async {
    await _ensureInitialized();
    final modeStr = _prefs!.getString(_trackingModeKey);
    if (modeStr == null) return LocationTrackingMode.normal;
    try {
      return LocationTrackingMode.values.firstWhere((e) => e.name == modeStr);
    } catch (_) {
      return LocationTrackingMode.normal;
    }
  }

  /// 停止位置跟踪
  Future<void> stopLocationTracking() async {
    _stopLocationTimer();
    // 【v1.95.0】持久化关闭状态，避免返回页面后误显示"已开启"
    await _ensureInitialized();
    await _prefs!.setBool(_locationTrackingEnabledKey, false);
    if (kDebugMode) debugPrint('[SafetyService] 位置跟踪已停止');
  }

  /// 停止位置定时器
  void _stopLocationTimer() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  /// 记录当前位置（本地 + 后端同步）
  Future<void> _recordLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final record = LocationRecord(
        timestamp: DateTime.now(),
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        altitude: position.altitude,
      );

      // 保存到本地历史记录
      await _saveLocationRecord(record);

      // 保存最后一次记录时间
      await _saveLastRecordTime(record.timestamp);

      // 触发回调
      onLocationUpdate?.call(record);

      // 【新增 v1.76.0】同步到后端
      _uploadLocationToBackend(record);

      if (kDebugMode) debugPrint('[SafetyService] 位置已记录: ${record.latitude}, ${record.longitude}');
    } catch (e) {
      if (kDebugMode) debugPrint('[SafetyService] 记录位置失败: $e');
    }
  }

  /// 后台上传位置到后端（静默失败，不阻塞主流程）
  Future<void> _uploadLocationToBackend(LocationRecord record) async {
    try {
      await ApiService.post(
        '/api/safety/location',
        body: {
          'latitude': record.latitude,
          'longitude': record.longitude,
          'accuracy': record.accuracy,
          'altitude': record.altitude,
          'activity_type': record.activityType?.name,
          'record_type': 'tracking',
        },
        auth: true,
      );
      if (kDebugMode) debugPrint('[SafetyService] 位置已同步到后端');
    } catch (e) {
      if (kDebugMode) debugPrint('[SafetyService] 位置同步到后端失败（已忽略）: $e');
    }
  }

  /// 保存最后一次记录时间
  Future<void> _saveLastRecordTime(DateTime time) async {
    await _ensureInitialized();
    await _prefs!.setString(_lastLocationKey, time.toIso8601String());
  }

  /// 获取最后一次记录时间
  Future<DateTime?> getLastRecordTime() async {
    await _ensureInitialized();
    final timeStr = _prefs!.getString(_lastLocationKey);
    if (timeStr == null) return null;
    try {
      return DateTime.parse(timeStr);
    } catch (e) {
      return null;
    }
  }

  /// 获取当前位置（用于SOS时记录）
  Future<LocationRecord?> getCurrentLocation() async {
    try {
      final status = await Permission.locationWhenInUse.request();
      if (!status.isGranted) return null;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best, // SOS时使用最佳精度
      );

      return LocationRecord(
        timestamp: DateTime.now(),
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        altitude: position.altitude,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[SafetyService] 获取位置失败: $e');
      return null;
    }
  }

  /// SOS时记录位置（只记录触发时的位置）
  Future<void> recordLocationOnSOS() async {
    final location = await getCurrentLocation();
    if (location == null) {
      if (kDebugMode) debugPrint('[SafetyService] SOS位置记录失败：无法获取位置');
      return;
    }

    // 保存到本地
    await _saveLocationRecord(location);

    // 同步到后端（紧急联系人可查看）
    try {
      await ApiService.post(
        '/api/safety/sos-location',
        body: {
          'latitude': location.latitude,
          'longitude': location.longitude,
          'accuracy': location.accuracy,
          'timestamp': location.timestamp.toIso8601String(),
        },
        auth: true,
      );
      if (kDebugMode) debugPrint('[SafetyService] SOS位置已上传到后端');
    } catch (e) {
      if (kDebugMode) debugPrint('[SafetyService] SOS位置上传失败: $e');
    }
  }

  Future<void> _saveLocationRecord(LocationRecord record) async {
    final history = await getLocationHistory();
    history.insert(0, record);
    
    // 只保留最近7天的记录
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final filtered = history.where((r) => r.timestamp.isAfter(cutoff)).toList();
    
    await _prefs!.setString(
      _locationHistoryKey,
      jsonEncode(filtered.map((r) => r.toJson()).toList()),
    );
  }

  /// 获取位置历史
  Future<List<LocationRecord>> getLocationHistory({int? days}) async {
    await _ensureInitialized();
    final jsonStr = _prefs!.getString(_locationHistoryKey);
    if (jsonStr == null) return [];

    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      var records = list
          .map((json) => LocationRecord.fromJson(json as Map<String, dynamic>))
          .toList();

      if (days != null) {
        final cutoff = DateTime.now().subtract(Duration(days: days));
        records = records.where((r) => r.timestamp.isAfter(cutoff)).toList();
      }

      return records;
    } catch (e) {
      if (kDebugMode) debugPrint('[SafetyService] 解析位置历史失败: $e');
      return [];
    }
  }

  /// 获取某天的轨迹（本地 + 后端合并）
  Future<List<LocationRecord>> getLocationTrackForDay(DateTime day) async {
    // 先读本地
    final history = await getLocationHistory();
    final localTrack = history.where((r) {
      return r.timestamp.year == day.year &&
          r.timestamp.month == day.month &&
          r.timestamp.day == day.day;
    }).toList();

    // 尝试从后端拉取（静默失败）
    try {
      final dateStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final res = await ApiService.get(
        '/api/safety/location?date=$dateStr',
        auth: true,
      );
      if (res['success'] == true && res['records'] is List) {
        final backendRecords = (res['records'] as List).map((json) =>
            LocationRecord.fromJson(json as Map<String, dynamic>)
        ).toList();
        // 合并：后端优先，去重
        final all = [...backendRecords, ...localTrack];
        final unique = <String, LocationRecord>{};
        for (final r in all) {
          unique['${r.timestamp.millisecondsSinceEpoch}'] = r;
        }
        return unique.values.toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[SafetyService] 后端位置记录获取失败（已忽略）: $e');
    }

    return localTrack;
  }

  /// 清除位置历史
  Future<void> clearLocationHistory() async {
    await _ensureInitialized();
    await _prefs!.remove(_locationHistoryKey);
    if (kDebugMode) debugPrint('[SafetyService] 位置历史已清除');
  }

  // ==================== 跌倒检测功能 ====================

  /// 获取跌倒事件列表
  Future<List<FallEvent>> getFallEvents() async {
    await _ensureInitialized();
    final jsonStr = _prefs!.getString(_fallEventsKey);
    if (jsonStr == null) return [];

    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((json) => FallEvent.fromJson(json as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      if (kDebugMode) debugPrint('[SafetyService] 解析跌倒事件失败: $e');
      return [];
    }
  }

  /// 记录跌倒事件
  ///
  /// [notifyGuardians] — 【v1.93.0】控制是否立即通知守护者。
  ///   手端跌倒检测设为 false，等用户确认或超时后再通知；
  ///   Apple Watch 端检测保持 true 立即通知。
  Future<void> recordFallEvent(FallEvent event, {bool notifyGuardians = true}) async {
    await _ensureInitialized();
    final events = await getFallEvents();
    events.insert(0, event);

    await _prefs!.setString(
      _fallEventsKey,
      jsonEncode(events.map((e) => e.toJson()).toList()),
    );

    if (kDebugMode) debugPrint('[SafetyService] 跌倒事件已记录: ${event.id}');
    onFallDetected?.call(event);

    // 【中国合规版整改】关闭"自动通知第三方亲友"（dead-man switch 核心之一）：
    // 任何自动外发（含 Watch 立即通知）在 cn 区均改为本地记录，
    // 由用户手动确认（见 notifyGuardiansAboutFallManually）后才通知守护人。
    final shouldAutoNotify = notifyGuardians && !AppConfig.isChinaRegion;
    if (shouldAutoNotify) {
      try {
        await NotifyService.notifyGuardiansAboutFall(
          timestamp: event.timestamp,
          latitude: event.latitude.toString(),
          longitude: event.longitude.toString(),
        );
      } catch (e) {
        if (kDebugMode) debugPrint('[SafetyService] 跌倒通知守护者失败: $e');
      }
    } else {
      if (kDebugMode) {
        debugPrint('[SafetyService] 跌倒事件已记录'
            '${AppConfig.isChinaRegion ? '[CN] 等待用户手动确认后再通知守护者' : ''}');
      }
    }
  }

  /// 【中国合规版】用户手动确认跌倒需要帮助后，主动通知守护人
  ///
  /// UI（跌倒确认弹窗"需要帮助"按钮）在用户明确确认时调用，守护人才可见。
  Future<void> notifyGuardiansAboutFallManually({
    required DateTime timestamp,
    String? latitude,
    String? longitude,
    Map<String, dynamic>? healthSummary,
  }) async {
    await NotifyService.notifyGuardiansAboutFall(
      timestamp: timestamp,
      latitude: latitude,
      longitude: longitude,
      healthSummary: healthSummary,
    );
  }

  /// 确认跌倒事件
  Future<void> acknowledgeFallEvent(String eventId, {String? notes}) async {
    await _ensureInitialized();
    final events = await getFallEvents();
    final index = events.indexWhere((e) => e.id == eventId);
    
    if (index != -1) {
      events[index] = events[index].copyWith(
        acknowledged: true,
        acknowledgedAt: DateTime.now(),
        notes: notes,
      );

      await _prefs!.setString(
        _fallEventsKey,
        jsonEncode(events.map((e) => e.toJson()).toList()),
      );
      if (kDebugMode) debugPrint('[SafetyService] 跌倒事件已确认: $eventId');
    }
  }

  /// 获取未确认的跌倒事件
  Future<List<FallEvent>> getUnacknowledgedFallEvents() async {
    final events = await getFallEvents();
    return events.where((e) => !e.acknowledged).toList();
  }

  /// 清除跌倒事件历史
  Future<void> clearFallEvents() async {
    await _ensureInitialized();
    await _prefs!.remove(_fallEventsKey);
    if (kDebugMode) debugPrint('[SafetyService] 跌倒事件历史已清除');
  }

  /// 计算两点之间的距离（米）
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// 释放资源
  void dispose() {
    _stopReminderTimer();
  }
}

/// CheckInReminder 的简单实现，用于回调
class _CheckInReminderImpl implements CheckInReminder {
  @override
  final bool enabled;
  @override
  final CheckInReminderStatus status;

  const _CheckInReminderImpl({
    required this.enabled,
    required this.status,
  });

  @override
  List<int> get reminderHours => [];
  @override
  CheckInTriggerMode get triggerMode => CheckInTriggerMode.time;
  @override
  DateTime? get lastCheckIn => null;
  @override
  DateTime? get nextReminder => null;
  @override
  int get missedCount => 0;

  @override
  CheckInReminder copyWith({
    bool? enabled,
    CheckInReminderStatus? status,
    List<int>? reminderHours,
    CheckInTriggerMode? triggerMode,
    DateTime? lastCheckIn,
    DateTime? nextReminder,
    int? missedCount,
  }) {
    return CheckInReminder(
      enabled: enabled ?? this.enabled,
      status: status ?? this.status,
      reminderHours: reminderHours ?? this.reminderHours,
      triggerMode: triggerMode ?? this.triggerMode,
      lastCheckIn: lastCheckIn ?? this.lastCheckIn,
      nextReminder: nextReminder ?? this.nextReminder,
      missedCount: missedCount ?? this.missedCount,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'status': status.name,
        'reminder_hours': reminderHours,
        'trigger_mode': triggerMode.name,
        'last_check_in': lastCheckIn?.toIso8601String(),
        'next_reminder': nextReminder?.toIso8601String(),
        'missed_count': missedCount,
      };
}
