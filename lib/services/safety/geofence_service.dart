/// 安全围栏（地理围栏）服务
///
/// 【v1.93.0】允许用户设置安全区域，离开时（经你确认后）通知守护者
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../api/notify_service.dart';
import '../../config/app_config.dart';

/// 围栏类型
enum GeoFenceType {
  home,    // 家
  work,    // 公司
  custom,  // 自定义
}

/// 围栏状态
enum GeoFenceStatus {
  inside,   // 在围栏内
  outside,  // 在围栏外
  unknown,  // 未检查
}

/// 地理围栏数据模型
class GeoFence {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radius; // 半径（米）
  final GeoFenceType type;
  final bool enabled;
  final DateTime createdAt;
  final GeoFenceStatus status;

  const GeoFence({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.radius = 200,
    this.type = GeoFenceType.custom,
    this.enabled = true,
    required this.createdAt,
    this.status = GeoFenceStatus.unknown,
  });

  /// 检查坐标是否在围栏内
  bool containsCoord(double lat, double lng) {
    final distance = Geolocator.distanceBetween(latitude, longitude, lat, lng);
    return distance <= radius;
  }

  String get typeLabel {
    switch (type) {
      case GeoFenceType.home:
        return '家';
      case GeoFenceType.work:
        return '公司';
      case GeoFenceType.custom:
        return '自定义';
    }
  }

  String get statusLabel {
    switch (status) {
      case GeoFenceStatus.inside:
        return '在安全区';
      case GeoFenceStatus.outside:
        return '已离开';
      case GeoFenceStatus.unknown:
        return '未检查';
    }
  }

  GeoFence copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    double? radius,
    GeoFenceType? type,
    bool? enabled,
    DateTime? createdAt,
    GeoFenceStatus? status,
  }) {
    return GeoFence(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radius: radius ?? this.radius,
      type: type ?? this.type,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
        'type': type.name,
        'enabled': enabled,
        'created_at': createdAt.toIso8601String(),
        'status': status.name,
      };

  factory GeoFence.fromJson(Map<String, dynamic> json) {
    return GeoFence(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radius: (json['radius'] as num?)?.toDouble() ?? 200,
      type: GeoFenceType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => GeoFenceType.custom,
      ),
      enabled: json['enabled'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      status: GeoFenceStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => GeoFenceStatus.unknown,
      ),
    );
  }
}

/// 安全围栏服务
class GeoFenceService {
  static const String _fencesKey = 'geo_fences';
  SharedPreferences? _prefs;
  Timer? _checkTimer;
  bool _isInitialized = false;

  // 【P2】本地通知（用户离开围栏时手机弹提醒）
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  // 回调
  void Function(GeoFence fence)? onFenceExited; // 离开围栏时触发

  /// 【P3】全局围栏退出回调（与实例无关，供 SafetyService 场景触发注册）
  static void Function(GeoFence fence)? onFenceExitedGlobal;

  Future<void> init() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();
    await _initNotifications();
    _isInitialized = true;
  }

  /// 【P2】初始化本地通知
  Future<void> _initNotifications() async {
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
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// 获取所有围栏
  Future<List<GeoFence>> getAllFences() async {
    if (!_isInitialized) await init();
    final jsonStr = _prefs!.getString(_fencesKey);
    if (jsonStr == null) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((j) => GeoFence.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[GeoFence] 解析围栏失败: $e');
      return [];
    }
  }

  /// 保存围栏列表
  Future<void> _saveFences(List<GeoFence> fences) async {
    if (!_isInitialized) await init();
    await _prefs!.setString(
      _fencesKey,
      jsonEncode(fences.map((f) => f.toJson()).toList()),
    );
  }

  /// 添加围栏
  Future<void> addFence({
    required String name,
    required double latitude,
    required double longitude,
    double radius = 200,
    GeoFenceType type = GeoFenceType.custom,
  }) async {
    final fences = await getAllFences();
    final fence = GeoFence(
      id: 'gf_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      latitude: latitude,
      longitude: longitude,
      radius: radius,
      type: type,
      createdAt: DateTime.now(),
    );
    fences.add(fence);
    await _saveFences(fences);

    // 立即检查状态
    await checkAllFences();

    if (kDebugMode) debugPrint('[GeoFence] 围栏已添加: $name (${radius}m)');
  }

  /// 删除围栏
  Future<void> removeFence(String id) async {
    var fences = await getAllFences();
    fences = fences.where((f) => f.id != id).toList();
    await _saveFences(fences);
    if (kDebugMode) debugPrint('[GeoFence] 围栏已删除: $id');
  }

  /// 更新围栏
  Future<void> updateFence(GeoFence updated) async {
    var fences = await getAllFences();
    final index = fences.indexWhere((f) => f.id == updated.id);
    if (index != -1) {
      fences[index] = updated;
      await _saveFences(fences);
    }
  }

  /// 切换围栏启用状态
  Future<void> toggleFence(String id) async {
    var fences = await getAllFences();
    final index = fences.indexWhere((f) => f.id == id);
    if (index != -1) {
      fences[index] = fences[index].copyWith(enabled: !fences[index].enabled);
      await _saveFences(fences);
    }
  }

  /// 检查所有围栏状态
  /// 返回离开的围栏列表（用于通知）
  Future<List<GeoFence>> checkAllFences() async {
    if (!_isInitialized) await init();
    final fences = await getAllFences();
    if (fences.isEmpty) return [];

    // 获取当前位置
    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[GeoFence] 获取位置失败，跳过围栏检查: $e');
      return [];
    }

    final exitedFences = <GeoFence>[];

    for (var i = 0; i < fences.length; i++) {
      final fence = fences[i];
      if (!fence.enabled) continue;

      final newStatus = fence.containsCoord(position.latitude, position.longitude)
          ? GeoFenceStatus.inside
          : GeoFenceStatus.outside;

      // 检测状态变化：从 inside → outside
      if (fence.status == GeoFenceStatus.inside && newStatus == GeoFenceStatus.outside) {
        exitedFences.add(fences[i].copyWith(status: newStatus));
      }

      fences[i] = fences[i].copyWith(status: newStatus);
    }

    await _saveFences(fences);

    // 通知
    for (final exited in exitedFences) {
      await _notifyFenceExited(exited);
      onFenceExited?.call(exited);
      onFenceExitedGlobal?.call(exited); // 【P3】场景化确认（离开安全区后确认签到）
    }

    if (kDebugMode && exitedFences.isNotEmpty) {
      debugPrint('[GeoFence] 检测到离开围栏: ${exitedFences.map((f) => f.name).join(', ')}');
    }

    return exitedFences;
  }

  /// 通知守护者：用户离开安全围栏
  Future<void> _notifyFenceExited(GeoFence fence) async {
    // 1. 本地通知（提醒用户本人"你离开了XX安全区"）
    try {
      const androidDetails = AndroidNotificationDetails(
        'geofence_exit',
        '安全围栏提醒',
        channelDescription: '离开安全区域时提醒',
        importance: Importance.high,
        priority: Priority.high,
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
      await _notifications.show(
        fence.id.hashCode,
        '已离开${fence.name}安全区',
        '你已离开「${fence.name}」安全区域',
        details,
      );
      if (kDebugMode) debugPrint('[GeoFence] 本地通知: 离开 ${fence.name}');
    } catch (e) {
      if (kDebugMode) debugPrint('[GeoFence] 本地通知失败: $e');
    }

    // 2. 通知守护者（App 内 + 后端推送）
    // 【中国合规版整改】关闭"自动通知第三方亲友"（dead-man switch 核心之一）：
    // cn 区仅本地提醒用户本人，由用户手动确认后才通知守护人（见 notifyGuardiansFenceExitManually）。
    if (AppConfig.isChinaRegion) {
      if (kDebugMode) {
        debugPrint('[GeoFence][CN] 离开围栏本地提醒（未自动通知守护人）: ${fence.name}');
      }
    } else {
      try {
        await NotifyService.notifyGuardiansAboutFenceExit(
          fence: fence.toJson(),
        );
        if (kDebugMode) debugPrint('[GeoFence] 已通知守护者: 离开 ${fence.name}');
      } catch (e) {
        if (kDebugMode) debugPrint('[GeoFence] 通知守护者失败: $e');
      }
    }
  }

  /// 【中国合规版】用户手动确认后，主动通知守护人（围栏离开场景）
  ///
  /// UI 在用户明确确认时调用，守护人才可见。
  Future<void> notifyGuardiansFenceExitManually(Map<String, dynamic> fence) async {
    await NotifyService.notifyGuardiansAboutFenceExit(fence: fence);
  }

  /// 启动定时围栏检查
  void startPeriodicCheck({Duration interval = const Duration(minutes: 2)}) {
    // 中国区首版隐藏地理围栏：即便位置共享开启也不启动围栏检查
    if (AppConfig.isChinaRegion) return;
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(interval, (_) async {
      await checkAllFences();
    });
    if (kDebugMode) debugPrint('[GeoFence] 定时围栏检查已启动 (${interval.inMinutes}分钟)');
  }

  /// 停止定时围栏检查
  void stopPeriodicCheck() {
    _checkTimer?.cancel();
    _checkTimer = null;
    if (kDebugMode) debugPrint('[GeoFence] 定时围栏检查已停止');
  }

  /// 获取启用的围栏数量
  Future<int> getEnabledCount() async {
    final fences = await getAllFences();
    return fences.where((f) => f.enabled).length;
  }

  /// 清除所有围栏
  Future<void> clearAll() async {
    if (!_isInitialized) await init();
    await _prefs!.remove(_fencesKey);
    if (kDebugMode) debugPrint('[GeoFence] 所有围栏已清除');
  }

  void dispose() {
    stopPeriodicCheck();
  }
}
