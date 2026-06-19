// lib/services/database/location_dao.dart
// 位置追踪历史 DAO
// 用途：记录 SOS/签到时的位置信息，支持事后查看和轨迹回放

import 'package:flutter/foundation.dart';
import 'database_service.dart';

/// 位置记录模型
class LocationRecord {
  final int? id;
  final double latitude;
  final double longitude;
  final String? address;         // 逆地理编码地址
  final double? accuracy;        // 精度（米）
  final String? triggerReason;   // sos / checkin / manual
  final String createdAt;

  LocationRecord({
    this.id,
    required this.latitude,
    required this.longitude,
    this.address,
    this.accuracy,
    this.triggerReason,
    this.createdAt = '',
  });

  factory LocationRecord.fromMap(Map<String, dynamic> map) => LocationRecord(
        id: map['id'] as int?,
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        address: map['address'] as String?,
        accuracy: map['accuracy'] != null
            ? (map['accuracy'] as num).toDouble()
            : null,
        triggerReason: map['trigger_reason'] as String?,
        createdAt: map['created_at'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'accuracy': accuracy,
        'trigger_reason': triggerReason,
      };
}

/// 位置历史 DAO
class LocationDao {
  /// 插入位置记录
  static Future<int> insert(LocationRecord record) async {
    final db = await DatabaseService.database;
    final id = await db.insert('location_history', record.toMap());
    if (kDebugMode) {
      debugPrint('[LocationDao] 记录位置: ${record.latitude}, ${record.longitude}');
    }
    return id;
  }

  /// 获取最近 N 条位置记录
  static Future<List<LocationRecord>> getRecent(int limit) async {
    final db = await DatabaseService.database;
    final result = await db.query(
      'location_history',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return result.map((e) => LocationRecord.fromMap(e)).toList();
  }

  /// 获取某原因的位置记录
  static Future<List<LocationRecord>> getByReason(String reason) async {
    final db = await DatabaseService.database;
    final result = await db.query(
      'location_history',
      where: 'trigger_reason = ?',
      whereArgs: [reason],
      orderBy: 'created_at DESC',
    );
    return result.map((e) => LocationRecord.fromMap(e)).toList();
  }

  /// 获取今日位置记录
  static Future<List<LocationRecord>> getToday() async {
    final today = _formatDate(DateTime.now());
    final db = await DatabaseService.database;
    final result = await db.query(
      'location_history',
      where: 'created_at LIKE ?',
      whereArgs: ['$today%'],
      orderBy: 'created_at DESC',
    );
    return result.map((e) => LocationRecord.fromMap(e)).toList();
  }

  /// 删除某条记录
  static Future<int> delete(int id) async {
    final db = await DatabaseService.database;
    return await db.delete(
      'location_history',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 清空旧记录（保留最近 N 条）
  static Future<int> clearOld({int keep = 50}) async {
    final db = await DatabaseService.database;
    final result = await db.query(
      'location_history',
      orderBy: 'created_at DESC',
      limit: 1,
      offset: keep,
    );
    if (result.isEmpty) return 0;

    final thresholdId = result.first['id'] as int;
    return await db.delete(
      'location_history',
      where: 'id <= ?',
      whereArgs: [thresholdId],
    );
  }

  /// 清空所有
  static Future<int> clearAll() async {
    final db = await DatabaseService.database;
    return await db.delete('location_history');
  }

  // ── 工具方法 ──────────────────────────

  static String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
