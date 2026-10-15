/// 安全区域（原地理围栏）数据模型与抽象服务
///
/// 【v1.93.0】允许用户设置安全区域，离开时（经你确认后）通知守护者。
///
/// 【CN 合规设计】本文件为**中性命名**的共享层（模型 + 抽象接口），不含有任何
/// 敏感关键词；具体实现 `SafeZoneService` 仅 global 构建编译
/// （条件导入），CN 构建不链接，故 `SafeZoneService` 类在 CN 二进制中不存在。
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../l10n/i18n.dart';

/// 安全区域类型
enum SafeZoneType {
  home, // 家
  work, // 公司
  custom, // 自定义
}

/// 安全区域状态
enum SafeZoneStatus {
  inside, // 在安全区域内
  outside, // 在安全区域外
  unknown, // 未检查
}

/// 安全区域数据模型
class SafeZone {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radius; // 半径（米）
  final SafeZoneType type;
  final bool enabled;
  final DateTime createdAt;
  final SafeZoneStatus status;

  const SafeZone({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.radius = 200,
    this.type = SafeZoneType.custom,
    this.enabled = true,
    required this.createdAt,
    this.status = SafeZoneStatus.unknown,
  });

  /// 检查坐标是否在安全区域内
  bool containsCoord(double lat, double lng) {
    final distance = Geolocator.distanceBetween(latitude, longitude, lat, lng);
    return distance <= radius;
  }

  String get typeLabel {
    switch (type) {
      case SafeZoneType.home:
        return tr.s666;
      case SafeZoneType.work:
        return tr.s667;
      case SafeZoneType.custom:
        return tr.z0015;
    }
  }

  String get statusLabel {
    switch (status) {
      case SafeZoneStatus.inside:
        return tr.z0326;
      case SafeZoneStatus.outside:
        return tr.z0327;
      case SafeZoneStatus.unknown:
        return tr.z0328;
    }
  }

  SafeZone copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    double? radius,
    SafeZoneType? type,
    bool? enabled,
    DateTime? createdAt,
    SafeZoneStatus? status,
  }) {
    return SafeZone(
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

  factory SafeZone.fromJson(Map<String, dynamic> json) {
    return SafeZone(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radius: (json['radius'] as num?)?.toDouble() ?? 200,
      type: SafeZoneType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => SafeZoneType.custom,
      ),
      enabled: json['enabled'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      status: SafeZoneStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SafeZoneStatus.unknown,
      ),
    );
  }
}

/// 安全区域服务抽象基类（常驻 CN 与 global 二进制，中性命名）。
///
/// 具体实现 `SafeZoneService` 仅 global 构建编译（条件导入），CN 构建不链接。
abstract class SafeZoneMonitor {
  /// 离开安全区域时触发
  void Function(SafeZone fence)? onZoneExited;

  /// 全局安全区域退出回调（与实例无关，供 SafetyService 场景触发注册）
  static void Function(SafeZone fence)? onZoneExitedGlobal;

  Future<void> init();

  /// 获取所有安全区域
  Future<List<SafeZone>> getAllFences();

  /// 添加安全区域
  Future<void> addFence({
    required String name,
    required double latitude,
    required double longitude,
    double radius = 200,
    SafeZoneType type = SafeZoneType.custom,
  });

  /// 删除安全区域
  Future<void> removeFence(String id);

  /// 更新安全区域
  Future<void> updateFence(SafeZone updated);

  /// 切换安全区域启用状态
  Future<void> toggleFence(String id);

  /// 检查所有安全区域状态，返回离开的列表
  Future<List<SafeZone>> checkAllFences();

  /// 用户手动确认后，主动通知守护人（安全区域离开场景）
  Future<void> notifyGuardiansSafeZoneExitManually(Map<String, dynamic> fence);

  /// 启动定时安全区域检查
  void startPeriodicCheck({Duration interval = const Duration(minutes: 2)});

  /// 停止定时安全区域检查
  void stopPeriodicCheck();

  /// 获取启用的安全区域数量
  Future<int> getEnabledCount();

  /// 清除所有安全区域
  Future<void> clearAll();

  void dispose();
}
