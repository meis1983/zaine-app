// lib/services/database/circle_event_dao.dart
// 守护圈今日事件本地表（v1.97.3+167 新增）
// 用途：纯本地聚合「今天圈内发生了什么」——体征异常预警 / 报平安等由 App 内动作或
//       安全引擎触发写库的事件。签到类事件由 checkin_dao / 守护者缓存实时派生，不在此表。
// 建表策略：惰性 CREATE TABLE IF NOT EXISTS，不 bump 数据库版本，兼容已发布版本升级。

import 'package:flutter/foundation.dart';
import 'database_service.dart';

/// 事件类型常量
class CircleEventType {
  static const String vitalAnomaly = 'vital_anomaly'; // 体征异常预警
  static const String peace = 'peace';                // 报平安
}

/// 守护圈今日事件模型
class CircleEvent {
  final int? id;
  final String type;   // 见 CircleEventType
  final String actor;  // 触发者标识（'me' / 手机号）
  final String summary; // 主标题（如 "体征异常预警" / "你 报平安"）
  final String detail; // 副标题/说明
  final int ts;        // Unix 毫秒时间戳
  final String extra;  // JSON 扩展字段

  CircleEvent({
    this.id,
    required this.type,
    required this.actor,
    required this.summary,
    required this.detail,
    required this.ts,
    this.extra = '',
  });

  factory CircleEvent.fromMap(Map<String, dynamic> map) => CircleEvent(
        id: map['id'] as int?,
        type: map['type'] as String,
        actor: map['actor'] as String,
        summary: map['summary'] as String,
        detail: map['detail'] as String? ?? '',
        ts: map['ts'] as int,
        extra: map['extra'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'type': type,
        'actor': actor,
        'summary': summary,
        'detail': detail,
        'ts': ts,
        'extra': extra,
      };
}

/// 守护圈事件 DAO（本地 SQLite）
class CircleEventDao {
  static const String _table = 'circle_events';
  static bool _initialized = false;

  /// 惰性建表（幂等），避免升级已发布版本时因未 bump DB 版本而缺表
  static Future<void> _ensureTable() async {
    if (_initialized) return;
    final db = await DatabaseService.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        actor TEXT NOT NULL,
        summary TEXT NOT NULL,
        detail TEXT,
        ts INTEGER NOT NULL,
        extra TEXT DEFAULT ''
      )
    ''');
    _initialized = true;
    if (kDebugMode) debugPrint('[CircleEventDao] 表已就绪: $_table');
  }

  /// 插入一条事件
  static Future<int> insert(CircleEvent ev) async {
    await _ensureTable();
    final db = await DatabaseService.database;
    final id = await db.insert(_table, ev.toMap());
    if (kDebugMode) {
      debugPrint('[CircleEventDao] 插入事件: ${ev.type} | ${ev.summary}');
    }
    return id;
  }

  /// 今日（本地 0 点起）所有事件，按时间倒序
  static Future<List<CircleEvent>> getToday() async {
    await _ensureTable();
    final db = await DatabaseService.database;
    final start = _startOfTodayMs();
    final result = await db.query(
      _table,
      where: 'ts >= ?',
      whereArgs: [start],
      orderBy: 'ts DESC',
    );
    return result.map((e) => CircleEvent.fromMap(e)).toList();
  }

  /// 最近 N 条事件（不限日期），按时间倒序
  static Future<List<CircleEvent>> getRecent(int n) async {
    await _ensureTable();
    final db = await DatabaseService.database;
    final result = await db.query(
      _table,
      orderBy: 'ts DESC',
      limit: n,
    );
    return result.map((e) => CircleEvent.fromMap(e)).toList();
  }

  /// 工具：本地今天 0 点的毫秒时间戳
  static int _startOfTodayMs() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return start.millisecondsSinceEpoch;
  }
}
