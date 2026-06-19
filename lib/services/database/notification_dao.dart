// lib/services/database/notification_dao.dart
// 通知历史 DAO
// 用途：记录所有发送过的通知，用于审计和去重

import 'package:flutter/foundation.dart';
import 'database_service.dart';

/// 通知历史记录模型
class NotificationRecord {
  final int? id;
  final String type;       // sos / checkin / reminder / guardian
  final String? recipient; // 接收者（手机号或名称）
  final String? content;   // 内容摘要
  final String? status;    // sent / failed / pending
  final String sentAt;

  NotificationRecord({
    this.id,
    required this.type,
    this.recipient,
    this.content,
    this.status,
    this.sentAt = '',
  });

  factory NotificationRecord.fromMap(Map<String, dynamic> map) =>
      NotificationRecord(
        id: map['id'] as int?,
        type: map['type'] as String,
        recipient: map['recipient'] as String?,
        content: map['content'] as String?,
        status: map['status'] as String?,
        sentAt: map['sent_at'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'type': type,
        'recipient': recipient,
        'content': content,
        'status': status,
      };
}

/// 通知历史 DAO
class NotificationDao {
  /// 插入通知记录
  static Future<int> insert(NotificationRecord record) async {
    final db = await DatabaseService.database;
    final id = await db.insert('notification_history', record.toMap());
    if (kDebugMode) debugPrint('[NotificationDao] 记录通知: ${record.type}');
    return id;
  }

  /// 查询最近 N 条通知
  static Future<List<NotificationRecord>> getRecent(int limit) async {
    final db = await DatabaseService.database;
    final result = await db.query(
      'notification_history',
      orderBy: 'sent_at DESC',
      limit: limit,
    );
    return result.map((e) => NotificationRecord.fromMap(e)).toList();
  }

  /// 查询某类型的最近通知
  static Future<List<NotificationRecord>> getByType(
    String type, {
    int limit = 50,
  }) async {
    final db = await DatabaseService.database;
    final result = await db.query(
      'notification_history',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'sent_at DESC',
      limit: limit,
    );
    return result.map((e) => NotificationRecord.fromMap(e)).toList();
  }

  /// 查询今日通知数量
  static Future<int> getTodayCount() async {
    final today = _formatDate(DateTime.now());
    final db = await DatabaseService.database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM notification_history WHERE sent_at LIKE ?",
      ['$today%'],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// 查询某类型今日是否已发送（去重用）
  static Future<bool> hasSentToday(String type) async {
    final today = _formatDate(DateTime.now());
    final db = await DatabaseService.database;
    final result = await db.query(
      'notification_history',
      where: 'type = ? AND sent_at LIKE ?',
      whereArgs: [type, '$today%'],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// 删除某条记录
  static Future<int> delete(int id) async {
    final db = await DatabaseService.database;
    return await db.delete(
      'notification_history',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 清空历史（保留最近 N 条）
  static Future<int> clearOld({int keep = 100}) async {
    final db = await DatabaseService.database;
    // 先查询第 keep 条记录的 ID
    final result = await db.query(
      'notification_history',
      orderBy: 'sent_at DESC',
      limit: 1,
      offset: keep,
    );
    if (result.isEmpty) return 0;

    final thresholdId = result.first['id'] as int;
    return await db.delete(
      'notification_history',
      where: 'id <= ?',
      whereArgs: [thresholdId],
    );
  }

  /// 清空所有
  static Future<int> clearAll() async {
    final db = await DatabaseService.database;
    return await db.delete('notification_history');
  }

  // ── 工具方法 ──────────────────────────

  static String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
