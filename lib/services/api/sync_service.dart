// lib/services/api/sync_service.dart
// 数据同步 API（v1.4）
// 策略：后端优先 + 本地降级，双写保证，非阻塞同步

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../api_service.dart';

class SyncService {
  static String _formatYyyyMmDd(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// 同步所有本地数据到后端（非阻塞，在后台静默执行）
  static Future<void> syncAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      if (!isLoggedIn) return;

      // 同步用户档案（优先读用户隔离键，兼容全局键）
      final userId = prefs.getString('user_id');
      String? profileJson;
      if (userId != null && userId.isNotEmpty) {
        profileJson = prefs.getString('user_profile_$userId');
      }
      profileJson ??= prefs.getString('user_profile');
      if (profileJson != null) {
        final profile = jsonDecode(profileJson) as Map<String, dynamic>;
        // 【修复 v1.9.78】移除头像 base64，避免请求体过大导致字段截断/同步失败
        profile.remove('avatar');
        await ApiService.put('/api/user/profile', body: profile);
      }

      // 同步联系人（与 contacts_page.dart 保持一致的 key 规则）
      final contactsKey = (userId != null && userId.isNotEmpty)
          ? 'emergency_contacts_$userId'
          : 'emergency_contacts';
      final contactsJson = prefs.getString(contactsKey);
      if (contactsJson != null) {
        final contacts = jsonDecode(contactsJson) as List;
        await ApiService.post('/api/contacts/batch',
            body: {'contacts': contacts});
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SyncService.syncAll error: $e');
    }
  }

  /// 从后端拉取数据到本地（登录后调用）
  static Future<void> pullFromServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final contactsKey = (userId != null && userId.isNotEmpty)
          ? 'emergency_contacts_$userId'
          : 'emergency_contacts';

      // 拉取用户档案
      final profileRes = await ApiService.get('/api/user/profile');
      if (profileRes['success'] == true && profileRes['profile'] != null) {
        final profileStr = jsonEncode(profileRes['profile']);
        await prefs.setString('user_profile', profileStr);
        // 【v1.9.73】同时写入用户隔离键，确保签到徽章等地方能读到姓名
        if (userId != null && userId.isNotEmpty) {
          await prefs.setString('user_profile_$userId', profileStr);
        }

        // 【v1.9.72】从服务器档案中提取头像 base64 并保存到本地
        final serverProfile = profileRes['profile'] as Map<String, dynamic>;
        // 【v1.9.73】同步保存用户名到独立 key，供 _checkLoginStatus 降级读取
        final name = serverProfile['name']?.toString();
        if (name != null && name.isNotEmpty) {
          await prefs.setString('user_name', name);
        }
        if (serverProfile.containsKey('avatar') && serverProfile['avatar'] != null) {
          final avatarStr = serverProfile['avatar'].toString();
          if (avatarStr.isNotEmpty) {
            final uid = prefs.getString('user_id') ?? '';
            // 【修复 v1.9.79】先保存 base64，即使文件解码失败也不丢失
            await prefs.setString('avatar_base64${uid.isNotEmpty ? '_$uid' : ''}', avatarStr);
            // 再尝试保存为文件，供 FileImage 使用
            try {
              final bytes = base64Decode(avatarStr);
              final dir = await getApplicationDocumentsDirectory();
              final path = '${dir.path}/avatar_remote.png';
              await File(path).writeAsBytes(bytes);
              await prefs.setString('avatar_path${uid.isNotEmpty ? '_$uid' : ''}', path);
            } catch (e) {
              if (kDebugMode) debugPrint('[SyncService] ⚠️ 保存远端头像文件失败（base64 已保留）: $e');
            }
          }
        }

        await prefs.setBool('is_logged_in', true);
      }

      // 拉取联系人 — 【修复 v1.80.0】空数据保护：服务器返回空列表时不覆盖本地非空缓存
      final contactsRes = await ApiService.get('/api/contacts');
      if (contactsRes['success'] == true && contactsRes['contacts'] != null) {
        final serverContacts = contactsRes['contacts'] as List;
        final localContacts = prefs.getString(contactsKey);
        if (serverContacts.isNotEmpty || localContacts == null || localContacts.isEmpty) {
          await prefs.setString(contactsKey, jsonEncode(serverContacts));
        } else {
          if (kDebugMode) debugPrint('[SyncService] ⚠️ 服务器返回空联系人列表，保留本地 $contactsKey 缓存');
        }
      }

      // 【修复】拉取签到状态（streak + total_days），使用用户隔离 key
      final uid = prefs.getString('user_id') ?? '';
      final streakKey = uid.isNotEmpty ? 'continuous_days_$uid' : 'continuous_days';
      final totalKey = uid.isNotEmpty ? 'total_check_in_days_$uid' : 'total_check_in_days';
      final historyKey = uid.isNotEmpty ? 'checkin_history_$uid' : 'checkin_history';

      try {
        final statusRes = await ApiService.get('/api/checkin/status');
        if (statusRes['success'] == true) {
          if (statusRes['streak'] != null) {
            await prefs.setInt(streakKey, statusRes['streak'] as int);
          }
          if (statusRes['total_days'] != null) {
            await prefs.setInt(totalKey, statusRes['total_days'] as int);
          }
          final lastIso = statusRes['last_checkin_date']?.toString();
          if (lastIso != null && lastIso.isNotEmpty) {
            final parsed = DateTime.tryParse(lastIso);
            if (parsed != null) {
              final lastDateKey = uid.isNotEmpty
                  ? 'last_check_in_date_$uid'
                  : 'last_check_in_date';
              final dateStr = _formatYyyyMmDd(parsed.toLocal());
              await prefs.setString(lastDateKey, dateStr);
              await prefs.setString('last_check_in_date', dateStr);
            }
          } else if (statusRes['checked_in_today'] == true) {
            final lastDateKey = uid.isNotEmpty
                ? 'last_check_in_date_$uid'
                : 'last_check_in_date';
            final dateStr = _formatYyyyMmDd(DateTime.now());
            await prefs.setString(lastDateKey, dateStr);
            await prefs.setString('last_check_in_date', dateStr);
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[SyncService] ⚠️ 拉取签到状态失败: $e');
      }

      // 【v1.9.72】拉取签到历史列表（供日历视图 + 周统计使用）
      try {
        final historyRes = await ApiService.get('/api/checkin/history?page=1&page_size=365');
        if (historyRes['success'] == true && historyRes['history'] != null) {
          final history = historyRes['history'] as List<dynamic>;
          final dateStrings = history
              .map((e) => e is Map ? (e['date']?.toString() ?? '') : e.toString())
              .where((s) => s.isNotEmpty)
              .toList();
          await prefs.setStringList(historyKey, dateStrings);
          if (kDebugMode) debugPrint('[SyncService] ✅ 拉取签到历史 ${dateStrings.length} 条');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[SyncService] ⚠️ 拉取签到历史失败: $e');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SyncService.pullFromServer error: $e');
    }
  }
}
