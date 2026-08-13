// lib/services/api/sync_service.dart
// 数据同步 API（v1.4）
// 策略：后端优先 + 本地降级，双写保证，非阻塞同步

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../api_service.dart';
import '../../utils/streak_util.dart';

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
              // 【v1.97.4 修复】按用户隔离文件名，杜绝多账号共用 avatar_remote.png 导致头像串号
              final path = '${dir.path}/avatar_remote_$uid.png';
              await File(path).writeAsBytes(bytes);
              await prefs.setString('avatar_path${uid.isNotEmpty ? '_$uid' : ''}', path);
            } catch (e) {
              if (kDebugMode) debugPrint('[SyncService] ⚠️ 保存远端头像文件失败（base64 已保留）: $e');
            }
          }
        }

        await prefs.setBool('is_logged_in', true);
      }

      // 拉取联系人 — 【修复 v1.93.10】合并策略：保留本地的 relation，防止后端未保存时被覆盖
      final contactsRes = await ApiService.get('/api/contacts');
      if (contactsRes['success'] == true && contactsRes['contacts'] != null) {
        final serverContacts = contactsRes['contacts'] as List;
        final localContactsJson = prefs.getString(contactsKey);
        
        if (serverContacts.isNotEmpty || localContactsJson == null || localContactsJson.isEmpty) {
          // 【关键修复】合并本地和服务器数据：优先使用本地 relation
          if (localContactsJson != null && localContactsJson.isNotEmpty) {
            try {
              final localContacts = jsonDecode(localContactsJson) as List;
              final mergedContacts = <Map<String, dynamic>>[];
              
              for (final serverContact in serverContacts) {
                if (serverContact is! Map) continue;
                final serverId = serverContact['id']?.toString() ?? '';
                final serverPhone = serverContact['phone']?.toString() ?? '';
                
                // 【修复 v1.93.10】用 phone 匹配本地联系人（因为本地 id 可能是临时 ID）
                Map<String, dynamic>? localMatch;
                try {
                  for (final local in localContacts) {
                    if (local is Map) {
                      final localPhone = local['phone']?.toString() ?? '';
                      // 优先用 phone 匹配，其次用 id 匹配
                      if ((serverPhone.isNotEmpty && localPhone == serverPhone) ||
                          (serverId.isNotEmpty && local['id']?.toString() == serverId)) {
                        localMatch = local as Map<String, dynamic>;
                        break;
                      }
                    }
                  }
                } catch (_) {}
                
                // 合并：使用服务器数据，但保留本地的 relation（如果服务器的 relation 为空或为默认值）
                final merged = Map<String, dynamic>.from(serverContact);
                if (localMatch != null) {
                  final localRelation = localMatch['relation']?.toString() ?? '';
                  final serverRelation = serverContact['relation']?.toString() ?? '';
                  
                  // 如果本地有 relation 且服务器的 relation 为空或为默认值"守护人"，保留本地值
                  if (localRelation.isNotEmpty && 
                      (serverRelation.isEmpty || serverRelation == '守护人')) {
                    merged['relation'] = localRelation;
                    if (kDebugMode) {
                      debugPrint('[SyncService] ✅ 保留本地 relation: id=$serverId, relation=$localRelation');
                    }
                  }
                }
                
                mergedContacts.add(merged);
              }
              
              await prefs.setString(contactsKey, jsonEncode(mergedContacts));
              if (kDebugMode) {
                debugPrint('[SyncService] ✅ 已合并服务器联系人和本地 relation');
              }
            } catch (e) {
              // 合并失败，降级为直接覆盖
              if (kDebugMode) debugPrint('[SyncService] ⚠️ 合并失败，直接覆盖: $e');
              await prefs.setString(contactsKey, jsonEncode(serverContacts));
            }
          } else {
            await prefs.setString(contactsKey, jsonEncode(serverContacts));
          }
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
          // 🔴【v1.97.2 根治】**不再把后端 streak 写入本地缓存**。
          //
          // 根因：后端 `signin_streak` 是独立累加计数器（checkin_service.py L59-75），
          // 不是从 checkin_history 表算出来的，已知会漂移偏高
          // （实测：后端 6 / 本地按后端自己的历史重算 3，后端两套数据自相矛盾）。
          // 旧代码在此无条件写入 → 每次启动都把缓存污染成错值 → 首屏渲染错误天数
          // → 随后本地重算再跳变（用户可见「先 6 后 3」闪烁）。
          //
          // 现策略：连续天数唯一真相源 = 本地签到历史（已 MERGE 服务器 history）。
          // 后端 streak 仅在 debug 日志中作对账参考，绝不落盘。
          if (kDebugMode) {
            final serverStreak = statusRes['streak'] ?? statusRes['signin_streak'] ?? 0;
            debugPrint('[SyncService] ℹ️ 后端 streak=$serverStreak（仅参考，不写缓存；以本地历史重算为准）');
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
        final historyRes = await ApiService.get('/api/checkin/history?page=1&page_size=100');
        if (historyRes['success'] == true && historyRes['history'] != null) {
          final history = historyRes['history'] as List<dynamic>;
          // 归一化为 yyyy-MM-dd（兼容 '2026-07-10' 与 '2026-07-10T00:00:00'）
          final serverDates = history
              .map((e) {
                final raw = e is Map ? (e['date']?.toString() ?? '') : e.toString();
                if (raw.isEmpty) return null;
                final parsed = DateTime.tryParse(raw);
                return parsed != null ? _formatYyyyMmDd(parsed.toLocal()) : null;
              })
              .where((s) => s != null)
              .cast<String>()
              .toSet();
          if (serverDates.isNotEmpty) {
            // 【稳健修复 v1.95.x】MERGE 而非覆盖：保留本地已有日期，避免服务器空/缺数据清空本地→连续天数归零
            final localDates = (prefs.getStringList(historyKey) ?? []).toSet();
            localDates.addAll(serverDates);
            await prefs.setStringList(historyKey, localDates.toList());
            if (kDebugMode) debugPrint('[SyncService] ✅ 合并签到历史(本地+服务器) 共 ${localDates.length} 条');

            // 用合并后的完整历史重算连续天数（单一真相源）
            // 🔴【v1.97.2 根治】改为**无条件写回**（含降低值）。
            // 旧代码 `if (calculatedStreak > cachedStreak)` 的「只升不降」保护，
            // 本意是防网络失败把缓存打成 0，实际后果是：一旦缓存被后端错值抬高（如 6），
            // 正确的重算值（3）因为「更小」而永远无法写回 → 污染值终身驻留。
            // 现在写入前已确认 `localDates.isNotEmpty`（历史非空），不存在误写 0 的风险。
            final calculatedStreak = StreakUtil.calculateStreak(localDates.toList());
            final cachedStreak = prefs.getInt(streakKey) ?? 0;
            if (calculatedStreak != cachedStreak) {
              await prefs.setInt(streakKey, calculatedStreak);
              if (kDebugMode) {
                debugPrint('[SyncService] ✅ 连续天数已对齐真相源: 缓存 $cachedStreak → 重算 $calculatedStreak');
              }
            }
          } else {
            if (kDebugMode) debugPrint('[SyncService] ⚠️ 服务器历史为空，保留本地，不清空');
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[SyncService] ⚠️ 拉取签到历史失败: $e');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SyncService.pullFromServer error: $e');
    }
  }
  
}
