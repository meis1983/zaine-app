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

/// 定时确认状态
enum CheckInReminderStatus {
  disabled,
  daily,
  weekly,
  custom,
}

/// 定时确认提醒配置
class CheckInReminder {
  final bool enabled;
  final CheckInReminderStatus status;
  final List<int> reminderHours; // 提醒小时列表，如 [9, 14, 21] 表示早中晚
  final DateTime? lastCheckIn;
  final DateTime? nextReminder;
  final int missedCount; // 连续未确认次数

  const CheckInReminder({
    this.enabled = false,
    this.status = CheckInReminderStatus.disabled,
    this.reminderHours = const [9, 21],
    this.lastCheckIn,
    this.nextReminder,
    this.missedCount = 0,
  });

  CheckInReminder copyWith({
    bool? enabled,
    CheckInReminderStatus? status,
    List<int>? reminderHours,
    DateTime? lastCheckIn,
    DateTime? nextReminder,
    int? missedCount,
  }) {
    return CheckInReminder(
      enabled: enabled ?? this.enabled,
      status: status ?? this.status,
      reminderHours: reminderHours ?? this.reminderHours,
      lastCheckIn: lastCheckIn ?? this.lastCheckIn,
      nextReminder: nextReminder ?? this.nextReminder,
      missedCount: missedCount ?? this.missedCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'status': status.name,
        'reminder_hours': reminderHours,
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

  const FallEvent({
    required this.id,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.confidence,
    this.acknowledged = false,
    this.acknowledgedAt,
    this.notes,
  });

  FallEvent copyWith({
    String? id,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    double? confidence,
    bool? acknowledged,
    DateTime? acknowledgedAt,
    String? notes,
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
    if (config.enabled) {
      _startReminderTimer(config);
    } else {
      _stopReminderTimer();
    }
  }

  /// 启用定时确认
  Future<void> enableReminder(CheckInReminderStatus status, {List<int>? hours}) async {
    final config = CheckInReminder(
      enabled: true,
      status: status,
      reminderHours: hours ?? [9, 21],
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
    _showReminderNotification();
    onReminderDue?.call(const _CheckInReminderImpl(enabled: true, status: CheckInReminderStatus.daily));
  }

  Future<void> _handleMissedReminder(CheckInReminder config) async {
    final updated = config.copyWith(missedCount: config.missedCount + 1);
    await saveReminderConfig(updated);

    // 如果连续错过3次，发送通知给守护人
    if (updated.missedCount >= 3) {
      await _notifyGuardiansAboutMissedCheckIn(updated.missedCount);
    }
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

  Future<void> _notifyGuardiansAboutMissedCheckIn(int missedCount) async {
    if (kDebugMode) debugPrint('[SafetyService] 连续$missedCount次未确认，通知守护人');
    // TODO: 调用通知服务通知守护人
  }

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
  Timer? _locationTimer; // 位置记录定时器

  /// 开始位置跟踪（每5分钟记录一次）
  Future<bool> startLocationTracking() async {
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

    // 4. 立即记录一次位置
    await _recordLocation();

    // 5. 启动定时器（每5分钟记录一次）
    _locationTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      await _recordLocation();
    });

    if (kDebugMode) debugPrint('[SafetyService] 位置跟踪已启动（每5分钟记录一次）');
    return true;
  }

  /// 停止位置跟踪
  void stopLocationTracking() {
    _stopLocationTimer();
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
  Future<void> recordFallEvent(FallEvent event) async {
    await _ensureInitialized();
    final events = await getFallEvents();
    events.insert(0, event);

    await _prefs!.setString(
      _fallEventsKey,
      jsonEncode(events.map((e) => e.toJson()).toList()),
    );

    if (kDebugMode) debugPrint('[SafetyService] 跌倒事件已记录: ${event.id}');
    onFallDetected?.call(event);
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
    DateTime? lastCheckIn,
    DateTime? nextReminder,
    int? missedCount,
  }) {
    return CheckInReminder(
      enabled: enabled ?? this.enabled,
      status: status ?? this.status,
      reminderHours: reminderHours ?? this.reminderHours,
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
        'last_check_in': lastCheckIn?.toIso8601String(),
        'next_reminder': nextReminder?.toIso8601String(),
        'missed_count': missedCount,
      };
}
