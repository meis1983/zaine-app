// lib/services/database/database_service.dart
// 本地 SQLite 数据库服务（v1.17.4 新增）
// 用途：替代 SharedPreferences 存储结构化数据，支持复杂查询和事务

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

/// 数据库单例服务
class DatabaseService {
  static Database? _db;
  static const String _dbName = 'zaine_app.db';
  static const int _dbVersion = 1;

  /// 获取数据库实例（单例）
  static Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  /// 初始化数据库
  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    if (kDebugMode) debugPrint('[DatabaseService] 数据库路径: $path');

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// 首次创建数据库表
  static Future<void> _onCreate(Database db, int version) async {
    if (kDebugMode) debugPrint('[DatabaseService] 创建数据库 v$version');

    // ── 1. 签到记录表 ──────────────────────────────
    // 用途：替代 SharedPreferences 存储签到记录，支持按时间范围查询
    await db.execute('''
      CREATE TABLE checkin_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        checkin_date TEXT NOT NULL,
        checkin_time TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_checkin_date ON checkin_records(checkin_date)',
    );

    // ── 2. 联系人表（本地缓存）───────────────────────
    // 用途：缓存服务器联系人列表，离线时仍可查看
    await db.execute('''
      CREATE TABLE contacts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id TEXT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        relation TEXT,
        avatar_path TEXT,
        is_local INTEGER DEFAULT 0,
        is_emergency INTEGER DEFAULT 0,
        sort_order INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_contacts_phone ON contacts(phone)',
    );

    // ── 3. 健康数据缓存表 ──────────────────────────
    // 用途：缓存 HealthKit 步数、心率等数据，减少频繁读取
    await db.execute('''
      CREATE TABLE health_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data_type TEXT NOT NULL,
        value REAL NOT NULL,
        unit TEXT,
        date TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        source TEXT,
        UNIQUE(data_type, date) ON CONFLICT REPLACE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_health_date ON health_cache(date)',
    );

    // ── 4. 通知历史表 ──────────────────────────────
    // 用途：记录所有发送过的通知，用于审计和去重
    await db.execute('''
      CREATE TABLE notification_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        recipient TEXT,
        content TEXT,
        status TEXT,
        sent_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // ── 5. 位置追踪历史表 ──────────────────────────
    // 用途：记录 SOS 时的位置信息，用于事后查看
    await db.execute('''
      CREATE TABLE location_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        address TEXT,
        accuracy REAL,
        trigger_reason TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    if (kDebugMode) debugPrint('[DatabaseService] 所有表创建完成 ✅');
  }

  /// 数据库升级（未来版本用）
  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (kDebugMode) {
      debugPrint('[DatabaseService] 升级数据库 $oldVersion → $newVersion');
    }
    // 未来版本在这里添加迁移逻辑
  }

  /// 关闭数据库
  static Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
      if (kDebugMode) debugPrint('[DatabaseService] 数据库已关闭');
    }
  }

  /// 删除数据库（调试用）
  static Future<void> deleteDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    await databaseFactory.deleteDatabase(path);
    _db = null;
    if (kDebugMode) debugPrint('[DatabaseService] 数据库已删除');
  }
}
