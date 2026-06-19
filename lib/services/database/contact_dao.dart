// lib/services/database/contact_dao.dart
// 联系人 DAO（Data Access Object）
// 用途：本地缓存联系人，支持离线查看和复杂查询

import 'package:flutter/foundation.dart';
import 'database_service.dart';

/// 联系人模型
class ContactRecord {
  final int? id;
  final String? serverId;
  final String name;
  final String phone;
  final String? relation;
  final String? avatarPath;
  final bool isLocal;
  final bool isEmergency;
  final int sortOrder;
  final String createdAt;
  final String updatedAt;

  ContactRecord({
    this.id,
    this.serverId,
    required this.name,
    required this.phone,
    this.relation,
    this.avatarPath,
    this.isLocal = false,
    this.isEmergency = false,
    this.sortOrder = 0,
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory ContactRecord.fromMap(Map<String, dynamic> map) => ContactRecord(
        id: map['id'] as int?,
        serverId: map['server_id'] as String?,
        name: map['name'] as String,
        phone: map['phone'] as String,
        relation: map['relation'] as String?,
        avatarPath: map['avatar_path'] as String?,
        isLocal: (map['is_local'] as int?) == 1,
        isEmergency: (map['is_emergency'] as int?) == 1,
        sortOrder: map['sort_order'] as int? ?? 0,
        createdAt: map['created_at'] as String? ?? '',
        updatedAt: map['updated_at'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'server_id': serverId,
        'name': name,
        'phone': phone,
        'relation': relation,
        'avatar_path': avatarPath,
        'is_local': isLocal ? 1 : 0,
        'is_emergency': isEmergency ? 1 : 0,
        'sort_order': sortOrder,
      };
}

/// 联系人 DAO
class ContactDao {
  /// 插入联系人
  static Future<int> insert(ContactRecord contact) async {
    final db = await DatabaseService.database;
    final id = await db.insert('contacts', contact.toMap());
    if (kDebugMode) debugPrint('[ContactDao] 插入联系人: ${contact.name}');
    return id;
  }

  /// 批量插入（同步服务器数据时用）
  static Future<void> insertBatch(List<ContactRecord> contacts) async {
    final db = await DatabaseService.database;
    await db.transaction((txn) async {
      for (final c in contacts) {
        await txn.insert('contacts', c.toMap());
      }
    });
    if (kDebugMode) debugPrint('[ContactDao] 批量插入 ${contacts.length} 个联系人');
  }

  /// 更新联系人
  static Future<int> update(ContactRecord contact) async {
    if (contact.id == null) return 0;
    final db = await DatabaseService.database;
    return await db.update(
      'contacts',
      {
        ...contact.toMap(),
        'updated_at': _now(),
      },
      where: 'id = ?',
      whereArgs: [contact.id],
    );
  }

  /// 删除联系人
  static Future<int> delete(int id) async {
    final db = await DatabaseService.database;
    return await db.delete(
      'contacts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 获取所有联系人（按 sort_order 排序）
  static Future<List<ContactRecord>> getAll() async {
    final db = await DatabaseService.database;
    final result = await db.query(
      'contacts',
      orderBy: 'sort_order ASC, created_at DESC',
    );
    return result.map((e) => ContactRecord.fromMap(e)).toList();
  }

  /// 获取紧急联系人
  static Future<List<ContactRecord>> getEmergencyContacts() async {
    final db = await DatabaseService.database;
    final result = await db.query(
      'contacts',
      where: 'is_emergency = 1',
      orderBy: 'sort_order ASC',
    );
    return result.map((e) => ContactRecord.fromMap(e)).toList();
  }

  /// 根据手机号查找
  static Future<ContactRecord?> findByPhone(String phone) async {
    final db = await DatabaseService.database;
    final result = await db.query(
      'contacts',
      where: 'phone = ?',
      whereArgs: [phone],
      limit: 1,
    );
    return result.isNotEmpty ? ContactRecord.fromMap(result.first) : null;
  }

  /// 根据 server_id 查找
  static Future<ContactRecord?> findByServerId(String serverId) async {
    final db = await DatabaseService.database;
    final result = await db.query(
      'contacts',
      where: 'server_id = ?',
      whereArgs: [serverId],
      limit: 1,
    );
    return result.isNotEmpty ? ContactRecord.fromMap(result.first) : null;
  }

  /// 清空所有联系人（同步前清理旧数据）
  static Future<int> clearAll() async {
    final db = await DatabaseService.database;
    return await db.delete('contacts');
  }

  /// 获取联系人数量
  static Future<int> getCount() async {
    final db = await DatabaseService.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM contacts');
    return (result.first['count'] as int?) ?? 0;
  }

  // ── 工具方法 ──────────────────────────

  static String _now() {
    final dt = DateTime.now();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}
