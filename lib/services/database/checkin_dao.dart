// lib/services/database/checkin_dao.dart
// 签到记录 DAO（Data Access Object）
// 用途：替代 SharedPreferences 签到记录存储，支持复杂查询

import 'package:flutter/foundation.dart';
import 'database_service.dart';

/// 签到记录模型
class CheckinRecord {
  final int? id;
  final String date;      // YYYY-MM-DD
  final String time;      // HH:MM:SS
  final int timestamp;    // Unix ms
  final String createdAt;

  CheckinRecord({
    this.id,
    required this.date,
    required this.time,
    required this.timestamp,
    this.createdAt = '',
  });

  factory CheckinRecord.fromMap(Map<String, dynamic> map) => CheckinRecord(
        id: map['id'] as int?,
        date: map['checkin_date'] as String,
        time: map['checkin_time'] as String,
        timestamp: map['timestamp'] as int,
        createdAt: map['created_at'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'checkin_date': date,
        'checkin_time': time,
        'timestamp': timestamp,
      };
}

/// 签到记录 DAO
class CheckinDao {
  /// 插入签到记录
  static Future<int> insert(CheckinRecord record) async {
    final db = await DatabaseService.database;
    final id = await db.insert('checkin_records', record.toMap());
    if (kDebugMode) debugPrint('[CheckinDao] 插入签到记录: ${record.date} ${record.time}');
    return id;
  }

  /// 查询某日是否已签到
  static Future<bool> hasCheckinOn(String date) async {
    final db = await DatabaseService.database;
    final result = await db.query(
      'checkin_records',
      where: 'checkin_date = ?',
      whereArgs: [date],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// 获取今日签到记录
  static Future<CheckinRecord?> getToday() async {
    final today = _formatDate(DateTime.now());
    final db = await DatabaseService.database;
    final result = await db.query(
      'checkin_records',
      where: 'checkin_date = ?',
      whereArgs: [today],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    return result.isNotEmpty ? CheckinRecord.fromMap(result.first) : null;
  }

  /// 获取最近 N 天的签到记录
  static Future<List<CheckinRecord>> getRecentDays(int days) async {
    final db = await DatabaseService.database;
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days - 1));

    final result = await db.query(
      'checkin_records',
      where: 'checkin_date BETWEEN ? AND ?',
      whereArgs: [_formatDate(startDate), _formatDate(endDate)],
      orderBy: 'checkin_date DESC',
    );
    return result.map((e) => CheckinRecord.fromMap(e)).toList();
  }

  /// 获取连续签到天数
  static Future<int> getConsecutiveDays() async {
    final db = await DatabaseService.database;
    final result = await db.rawQuery('''
      SELECT checkin_date FROM checkin_records
      ORDER BY checkin_date DESC
    ''');

    if (result.isEmpty) return 0;

    int consecutive = 0;
    DateTime? lastDate;
    for (final row in result) {
      final date = DateTime.parse(row['checkin_date'] as String);
      if (lastDate == null) {
        lastDate = date;
        consecutive = 1;
      } else {
        final diff = lastDate.difference(date).inDays;
        if (diff == 1) {
          consecutive++;
          lastDate = date;
        } else {
          break;
        }
      }
    }
    return consecutive;
  }

  /// 获取本月签到次数
  static Future<int> getMonthCount(int year, int month) async {
    final db = await DatabaseService.database;
    final prefix = '$year-${month.toString().padLeft(2, '0')}';
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM checkin_records WHERE checkin_date LIKE ?",
      ['$prefix%'],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// 获取总签到次数
  static Future<int> getTotalCount() async {
    final db = await DatabaseService.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM checkin_records',
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// 删除某条记录
  static Future<int> delete(int id) async {
    final db = await DatabaseService.database;
    return await db.delete(
      'checkin_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 清空所有记录（调试用）
  static Future<int> clearAll() async {
    final db = await DatabaseService.database;
    return await db.delete('checkin_records');
  }

  // ── 工具方法 ──────────────────────────

  static String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
