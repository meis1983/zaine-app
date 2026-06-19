// lib/services/database/health_dao.dart
// 健康数据缓存 DAO
// 用途：缓存 HealthKit 数据，减少频繁读取，支持历史趋势查询

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'database_service.dart';

/// 健康数据记录模型
class HealthRecord {
  final int? id;
  final String dataType;   // steps / heart_rate / distance / sleep
  final double value;
  final String? unit;
  final String date;       // YYYY-MM-DD
  final int timestamp;
  final String? source;

  HealthRecord({
    this.id,
    required this.dataType,
    required this.value,
    this.unit,
    required this.date,
    required this.timestamp,
    this.source,
  });

  factory HealthRecord.fromMap(Map<String, dynamic> map) => HealthRecord(
        id: map['id'] as int?,
        dataType: map['data_type'] as String,
        value: (map['value'] as num).toDouble(),
        unit: map['unit'] as String?,
        date: map['date'] as String,
        timestamp: map['timestamp'] as int,
        source: map['source'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'data_type': dataType,
        'value': value,
        'unit': unit,
        'date': date,
        'timestamp': timestamp,
        'source': source,
      };
}

/// 健康数据 DAO
class HealthDao {
  /// 插入或更新（按 data_type + date 唯一）
  static Future<int> upsert(HealthRecord record) async {
    final db = await DatabaseService.database;
    final id = await db.insert(
      'health_cache',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return id;
  }

  /// 批量插入
  static Future<void> upsertBatch(List<HealthRecord> records) async {
    final db = await DatabaseService.database;
    await db.transaction((txn) async {
      for (final r in records) {
        await txn.insert(
          'health_cache',
          r.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    if (kDebugMode) debugPrint('[HealthDao] 批量缓存 ${records.length} 条健康数据');
  }

  /// 查询某日某类型数据
  static Future<HealthRecord?> getByDate(String dataType, String date) async {
    final db = await DatabaseService.database;
    final result = await db.query(
      'health_cache',
      where: 'data_type = ? AND date = ?',
      whereArgs: [dataType, date],
      limit: 1,
    );
    return result.isNotEmpty ? HealthRecord.fromMap(result.first) : null;
  }

  /// 查询某类型最近 N 天的数据（用于趋势图）
  static Future<List<HealthRecord>> getRecent(
    String dataType,
    int days,
  ) async {
    final db = await DatabaseService.database;
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days - 1));

    final result = await db.query(
      'health_cache',
      where: 'data_type = ? AND date BETWEEN ? AND ?',
      whereArgs: [
        dataType,
        _formatDate(startDate),
        _formatDate(endDate),
      ],
      orderBy: 'date ASC',
    );
    return result.map((e) => HealthRecord.fromMap(e)).toList();
  }

  /// 获取今日步数
  static Future<double> getTodaySteps() async {
    final today = _formatDate(DateTime.now());
    final record = await getByDate('steps', today);
    return record?.value ?? 0.0;
  }

  /// 获取今日心率（平均）
  static Future<double?> getTodayHeartRate() async {
    final today = _formatDate(DateTime.now());
    final record = await getByDate('heart_rate', today);
    return record?.value;
  }

  /// 获取本周总步数
  static Future<double> getWeekSteps() async {
    final List<HealthRecord> records = await getRecent('steps', 7);
    return records.fold<double>(0.0, (sum, r) => sum + r.value);
  }

  /// 删除某类型某日期数据
  static Future<int> delete(String dataType, String date) async {
    final db = await DatabaseService.database;
    return await db.delete(
      'health_cache',
      where: 'data_type = ? AND date = ?',
      whereArgs: [dataType, date],
    );
  }

  /// 清空某类型所有数据
  static Future<int> clearByType(String dataType) async {
    final db = await DatabaseService.database;
    return await db.delete(
      'health_cache',
      where: 'data_type = ?',
      whereArgs: [dataType],
    );
  }

  /// 清空所有缓存
  static Future<int> clearAll() async {
    final db = await DatabaseService.database;
    return await db.delete('health_cache');
  }

  // ── 工具方法 ──────────────────────────

  static String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
