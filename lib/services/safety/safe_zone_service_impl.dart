/// 安全区域（原地理围栏）服务实现
///
/// 【CN 合规设计】本文件 **仅 global 构建** 经条件导入编译（见 safe_zone_service.dart），
/// CN 构建不链接，故 `SafeZoneService` 类在 CN 二进制中不存在（类名彻底消失，表里如一）。
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../api/notify_service.dart';
import '../../config/app_config.dart';
import '../../l10n/i18n.dart';
import 'safe_zone_service_base.dart';

/// 安全区域服务（global 构建专用实现）
class SafeZoneService extends SafeZoneMonitor {
  static const String _fencesKey = 'safe_zones';
  SharedPreferences? _prefs;
  Timer? _checkTimer;
  bool _isInitialized = false;

  // 本地通知（用户离开安全区域时手机弹提醒）
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  // 回调
  @override
  void Function(SafeZone fence)? onZoneExited;

  Future<void> init() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();
    await _initNotifications();
    _isInitialized = true;
  }

  /// 初始化本地通知
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

  /// 获取所有安全区域
  @override
  Future<List<SafeZone>> getAllFences() async {
    if (!_isInitialized) await init();
    final jsonStr = _prefs!.getString(_fencesKey);
    if (jsonStr == null) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((j) => SafeZone.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[SafeZone] 解析安全区域失败: $e');
      return [];
    }
  }

  /// 保存安全区域列表
  Future<void> _saveFences(List<SafeZone> fences) async {
    if (!_isInitialized) await init();
    await _prefs!.setString(
      _fencesKey,
      jsonEncode(fences.map((f) => f.toJson()).toList()),
    );
  }

  /// 添加安全区域
  @override
  Future<void> addFence({
    required String name,
    required double latitude,
    required double longitude,
    double radius = 200,
    SafeZoneType type = SafeZoneType.custom,
  }) async {
    final fences = await getAllFences();
    final fence = SafeZone(
      id: 'sz_${DateTime.now().millisecondsSinceEpoch}',
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

    if (kDebugMode) debugPrint('[SafeZone] 安全区域已添加: $name (${radius}m)');
  }

  /// 删除安全区域
  @override
  Future<void> removeFence(String id) async {
    var fences = await getAllFences();
    fences = fences.where((f) => f.id != id).toList();
    await _saveFences(fences);
    if (kDebugMode) debugPrint('[SafeZone] 安全区域已删除: $id');
  }

  /// 更新安全区域
  @override
  Future<void> updateFence(SafeZone updated) async {
    var fences = await getAllFences();
    final index = fences.indexWhere((f) => f.id == updated.id);
    if (index != -1) {
      fences[index] = updated;
      await _saveFences(fences);
    }
  }

  /// 切换安全区域启用状态
  @override
  Future<void> toggleFence(String id) async {
    var fences = await getAllFences();
    final index = fences.indexWhere((f) => f.id == id);
    if (index != -1) {
      fences[index] = fences[index].copyWith(enabled: !fences[index].enabled);
      await _saveFences(fences);
    }
  }

  /// 检查所有安全区域状态
  /// 返回离开的安全区域列表（用于通知）
  @override
  Future<List<SafeZone>> checkAllFences() async {
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
      if (kDebugMode) debugPrint('[SafeZone] 获取位置失败，跳过安全区域检查: $e');
      return [];
    }

    final exitedFences = <SafeZone>[];

    for (var i = 0; i < fences.length; i++) {
      final fence = fences[i];
      if (!fence.enabled) continue;

      final newStatus = fence.containsCoord(position.latitude, position.longitude)
          ? SafeZoneStatus.inside
          : SafeZoneStatus.outside;

      // 检测状态变化：从 inside → outside
      if (fence.status == SafeZoneStatus.inside && newStatus == SafeZoneStatus.outside) {
        exitedFences.add(fences[i].copyWith(status: newStatus));
      }

      fences[i] = fences[i].copyWith(status: newStatus);
    }

    await _saveFences(fences);

    // 通知
    for (final exited in exitedFences) {
      await _notifyZoneExited(exited);
      onZoneExited?.call(exited);
      SafeZoneMonitor.onZoneExitedGlobal?.call(exited); // 场景化确认（离开安全区后确认签到）
    }

    if (kDebugMode && exitedFences.isNotEmpty) {
      debugPrint('[SafeZone] 检测到离开安全区域: ${exitedFences.map((f) => f.name).join(', ')}');
    }

    return exitedFences;
  }

  /// 通知守护者：用户离开安全区域
  Future<void> _notifyZoneExited(SafeZone fence) async {
    // 1. 本地通知（提醒用户本人"你离开了XX安全区"）
    try {
      final androidDetails = AndroidNotificationDetails(
        'safe_zone_exit',
        tr.z0329,
        channelDescription: tr.z0330,
        importance: Importance.high,
        priority: Priority.high,
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      final details = NotificationDetails(android: androidDetails, iOS: iosDetails);
      await _notifications.show(
        fence.id.hashCode,
        tr.z0331(fence.name),
        tr.z0332(fence.name),
        details,
      );
      if (kDebugMode) debugPrint('[SafeZone] 本地通知: 离开 ${fence.name}');
    } catch (e) {
      if (kDebugMode) debugPrint('[SafeZone] 本地通知失败: $e');
    }

    // 2. 通知守护者（App 内 + 后端推送）
    // 【中国合规版整改】关闭"自动通知第三方亲友"（dead-man switch 核心之一）：
    // cn 区仅本地提醒用户本人，由用户手动确认后才通知守护人（见 notifyGuardiansSafeZoneExitManually）。
    // 注：本实现文件仅 global 构建编译，CN 区不会链接此文件，下方分支在 global 构建中恒走 else。
    if (AppConfig.isChinaRegion) {
      if (kDebugMode) {
        debugPrint('[SafeZone] 离开安全区本地提醒（未自动通知守护人）: ${fence.name}');
      }
    } else {
      try {
        await NotifyService.notifyGuardiansAboutFenceExit(
          fence: fence.toJson(),
        );
        if (kDebugMode) debugPrint('[SafeZone] 已通知守护者: 离开 ${fence.name}');
      } catch (e) {
        if (kDebugMode) debugPrint('[SafeZone] 通知守护者失败: $e');
      }
    }
  }

  /// 【中国合规版】用户手动确认后，主动通知守护人（安全区域离开场景）
  ///
  /// UI 在用户明确确认时调用，守护人才可见。
  @override
  Future<void> notifyGuardiansSafeZoneExitManually(Map<String, dynamic> fence) async {
    await NotifyService.notifyGuardiansAboutFenceExit(fence: fence);
  }

  /// 启动定时安全区域检查
  @override
  void startPeriodicCheck({Duration interval = const Duration(minutes: 2)}) {
    // 中国区首版隐藏安全区域：即便位置共享开启也不启动区域检查
    if (AppConfig.isChinaRegion) return;
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(interval, (_) async {
      await checkAllFences();
    });
    if (kDebugMode) debugPrint('[SafeZone] 定时安全区域检查已启动 (${interval.inMinutes}分钟)');
  }

  /// 停止定时安全区域检查
  @override
  void stopPeriodicCheck() {
    _checkTimer?.cancel();
    _checkTimer = null;
    if (kDebugMode) debugPrint('[SafeZone] 定时安全区域检查已停止');
  }

  /// 获取启用的安全区域数量
  @override
  Future<int> getEnabledCount() async {
    final fences = await getAllFences();
    return fences.where((f) => f.enabled).length;
  }

  /// 清除所有安全区域
  @override
  Future<void> clearAll() async {
    if (!_isInitialized) await init();
    await _prefs!.remove(_fencesKey);
    if (kDebugMode) debugPrint('[SafeZone] 所有安全区域已清除');
  }

  @override
  void dispose() {
    stopPeriodicCheck();
  }
}

/// 全局工厂函数（详见 safe_zone_service.dart 条件导入；CN 构建返回 null）
SafeZoneMonitor? createSafeZoneService() => SafeZoneService();
