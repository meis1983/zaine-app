import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/theme_helper.dart';
import '../pages/promotional_showcase_page.dart'; // 新增
import 'checkin_milestone_dialog.dart';
import '../services/api_service.dart';
import '../services/membership_service.dart';
import '../services/api/checkin_service.dart';
import '../services/api/auth_service.dart';
import '../services/platform/health_service.dart';
import '../services/api/sync_service.dart';
import '../pages/onboarding_page.dart';
import '../l10n/i18n.dart';

/// 开发者模式 Mixin
/// 封装版本号连击检测 + 开发者菜单 + 重置签到逻辑
/// profile_page 和 settings_page 共用，消除 DRY 违规
mixin DeveloperMode<T extends StatefulWidget> on State<T> {
  int devTapCount = 0;
  DateTime? devLastTapTime;

  /// 版本号连击处理 —— 快速连击3次激活开发者调试菜单
  /// 返回 true 表示已激活，调用方应弹出开发者菜单
  /// 【正式版安全】Release 模式下完全屏蔽，防止用户绕过订阅/签到体系
  bool handleVersionTap() {
    // 🔒 Release 模式下：连击版本号无任何反应
    if (kReleaseMode) return false;

    final now = DateTime.now();
    if (devLastTapTime != null && now.difference(devLastTapTime!).inSeconds > 3) {
      devTapCount = 0; // 超过3秒重置
    }
    devLastTapTime = now;
    devTapCount++;

    if (devTapCount >= 3) {
      devTapCount = 0;
      HapticFeedback.mediumImpact();
      return true; // 激活开发者菜单
    }
    return false;
  }

  /// 显示开发者菜单 —— 完整版，包含所有调试工具
  /// 【正式版安全】Release 模式下直接返回，不弹出任何内容
  void showDeveloperMenu() {
    // 🔒 Release 模式下：完全屏蔽开发者菜单
    if (kReleaseMode) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottomSafe = MediaQuery.of(ctx).padding.bottom;
        return DraggableScrollableSheet(
          initialChildSize: 0.75,  // 初始高度 75%
          minChildSize: 0.4,        // 最小 40%
          maxChildSize: 0.95,       // 最大 95%（可拖拽拉高）
          builder: (_, controller) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: ListView(
              controller: controller,
              padding: EdgeInsets.only(bottom: 24 + bottomSafe),
              children: [
                const SizedBox(height: 12),
                // 拖动条
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(ZaiNeRadius.tiny),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 标题
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text(tr.z0776, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                      Spacer(),
                      Text('DEV', style: TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // 3D 宣传录制模式
                ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(ZaiNeRadius.input)),
                    child: Icon(Icons.videocam_rounded, color: Colors.purple.shade700, size: 20),
                  ),
                  title: Text(tr.z0777, style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(tr.z0778),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PromotionalShowcasePage()));
                  },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                const Divider(height: 1, indent: 24, endIndent: 24),
                // 签到模拟器
                ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.science_rounded, color: Colors.amber.shade700, size: 20),
                  ),
                  title: Text(tr.s212, style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(tr.s213),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () { Navigator.pop(ctx); showCheckInSimulator(); },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                const Divider(height: 1, indent: 24, endIndent: 24),
                // 重置今日签到
                ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.refresh, color: Colors.teal.shade700, size: 20),
                  ),
                  title: Text(tr.z0779, style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(tr.z0780),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async { Navigator.pop(ctx); await resetTodayCheckIn(); },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                const Divider(height: 1, indent: 24, endIndent: 24),
                // 重置守护卡
                ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.pink.shade50, borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.card_giftcard, color: Colors.pink.shade700, size: 20),
                  ),
                  title: Text(tr.s214, style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(tr.z0781),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async { Navigator.pop(ctx); await resetGuardianCard(); },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                const Divider(height: 1, indent: 24, endIndent: 24),
                // 切换会员等级
                ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.workspace_premium_rounded, color: Colors.orange.shade700, size: 20),
                  ),
                  title: Text(tr.s222, style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(tr.z0782),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () { Navigator.pop(ctx); showMembershipSwitchDialog(); },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                const Divider(height: 1, indent: 24, endIndent: 24),
                // 模拟会员过期降级
                ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.timer_off_rounded, color: Colors.red.shade400, size: 20),
                  ),
                  title: Text(tr.s224, style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(tr.z0783),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () { Navigator.pop(ctx); showMembershipExpiryDialog(); },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                const Divider(height: 1, indent: 24, endIndent: 24),
                ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.location_searching_rounded, color: Colors.green.shade700, size: 20),
                  ),
                  title: Text(tr.z0032, style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(tr.z0784),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () { Navigator.pop(ctx); showGeocodeDiagnostics(); },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                const Divider(height: 1, indent: 24, endIndent: 24),
                ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.watch_rounded, color: Colors.indigo.shade700, size: 20),
                  ),
                  title: Text(tr.z0033, style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(tr.z0785),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () { Navigator.pop(ctx); showWatchDiagnostics(); },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                const Divider(height: 1, indent: 24, endIndent: 24),
                ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.favorite_rounded, color: Colors.green.shade700, size: 20),
                  ),
                  title: Text(tr.z0034, style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(tr.z0786),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () { Navigator.pop(ctx); showHealthDiagnostics(); },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                const Divider(height: 1, indent: 24, endIndent: 24),
                ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.storage_rounded, color: Colors.blueGrey.shade700, size: 20),
                  ),
                  title: Text(tr.z0787, style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(tr.z0788),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () { Navigator.pop(ctx); showWorkMemoryExport(); },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                const Divider(height: 1, indent: 24, endIndent: 24),
                // 重新显示引导页
                ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.replay_rounded, color: Colors.blue.shade700, size: 20),
                  ),
                  title: Text(tr.s216, style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(tr.s217),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('onboarding_completed', false);
                    if (!mounted || !ctx.mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(tr.s218),
                      backgroundColor: Colors.purple,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                    ));
                  },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> showGeocodeDiagnostics() async {
    final prefs = await SharedPreferences.getInstance();
    final provider = prefs.getString('geocode_last_provider') ?? 'unknown';
    final time = prefs.getString('geocode_last_time') ?? '';
    final address = prefs.getString('geocode_last_address') ?? '';

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(tr.z0032),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr.z0789(provider)),
              const SizedBox(height: 6),
              Text(tr.z0790(time.isEmpty ? "无" : time)),
              const SizedBox(height: 6),
              Text(tr.z0791(address.isEmpty ? "无" : address)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final text = 'provider=$provider\ntime=$time\naddress=$address';
                await Clipboard.setData(ClipboardData(text: text));
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(tr.z0794),
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              },
              child: Text(tr.s210),
            ),
            TextButton(
              onPressed: () async {
                await prefs.remove('geocode_last_provider');
                await prefs.remove('geocode_last_time');
                await prefs.remove('geocode_last_address');
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(tr.s100),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr.s048),
            ),
          ],
        );
      },
    );
  }

  Future<void> showWatchDiagnostics() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getBool('pending_watch_checkin') ?? false;
    final lastAction = prefs.getString('watch_last_action') ?? '';
    final lastTs = prefs.getDouble('watch_last_action_ts');
    final lastTime = lastTs != null
        ? DateTime.fromMillisecondsSinceEpoch((lastTs * 1000).round()).toLocal().toString()
        : '';

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(tr.z0033),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('pending_watch_checkin：${pending ? "true" : "false"}'),
              const SizedBox(height: 6),
              Text(tr.z0795(lastAction.isEmpty ? "无" : lastAction)),
              const SizedBox(height: 6),
              Text(tr.z0796(lastTime.isEmpty ? "无" : lastTime)),
              const SizedBox(height: 12),
              Text(tr.z0797),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await prefs.setBool('pending_watch_checkin', true);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(tr.z0798),
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              },
              child: Text(tr.z0799),
            ),
            TextButton(
              onPressed: () async {
                await HealthService.performSilentHeartbeatCheckin();
                unawaited(SyncService.pullFromServer());
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(tr.z0800),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr.s048),
            ),
          ],
        );
      },
    );
  }

  Future<void> showHealthDiagnostics() async {
    final prefs = await SharedPreferences.getInstance();
    final authorized = prefs.getBool('health_last_authorized');
    final authErr = prefs.getString('health_last_auth_error') ?? '';
    final authTime = prefs.getString('health_last_auth_time') ?? '';
    final fetchCount = prefs.getInt('health_last_fetch_count');
    final fetchErr = prefs.getString('health_last_fetch_error') ?? '';
    final fetchTime = prefs.getString('health_last_fetch_time') ?? '';
    final typeCounts = prefs.getString('health_last_fetch_type_counts') ?? '';
    final typeErrors = prefs.getString('health_last_fetch_type_errors') ?? '';

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(tr.z0034),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr.z0801(authorized == null ? "未知" : (authorized ? "true" : "false"))),
                const SizedBox(height: 6),
                Text(tr.z0802(authTime.isEmpty ? "无" : authTime)),
                const SizedBox(height: 6),
                Text(tr.z0803(authErr.isEmpty ? "无" : authErr)),
                const SizedBox(height: 12),
                Text(tr.z0804(fetchCount == null ? "未知" : fetchCount.toString())),
                const SizedBox(height: 6),
                Text(tr.z0805(fetchTime.isEmpty ? "无" : fetchTime)),
                const SizedBox(height: 6),
                Text(tr.z0806(fetchErr.isEmpty ? "无" : fetchErr)),
                const SizedBox(height: 12),
                Text(tr.z0807(typeCounts.isEmpty ? "无" : typeCounts), style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 6),
                Text(tr.z0808(typeErrors.isEmpty ? "无" : typeErrors), style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await HealthService.requestPermissions();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(tr.z0809),
            ),
            TextButton(
              onPressed: () async {
                await HealthService.getHealthSummary();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(tr.z0810),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr.s048),
            ),
          ],
        );
      },
    );
  }

  Future<void> showWorkMemoryExport() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('user_id') ?? '';
    final keys = prefs.getKeys().toList()..sort();

    bool shouldIncludeKey(String k) {
      if (k == 'auth_token') return false;
      if (k.startsWith('iap_')) return false;
      if (k.contains('transaction') || k.contains('receipt')) return false;
      return k.startsWith('user_profile') ||
          k.startsWith('emergency_contacts') ||
          k.startsWith('continuous_days') ||
          k.startsWith('total_check_in_days') ||
          k.startsWith('last_check_in_date') ||
          k.startsWith('checkin_history') ||
          k.startsWith('membership_') ||
          k.startsWith('guardian_card') ||
          k.startsWith('contact_') ||
          k.startsWith('geocode_') ||
          k.startsWith('watch_') ||
          k == 'user_id' ||
          k == 'user_phone' ||
          k == 'is_logged_in' ||
          k == 'onboarding_completed';
    }

    final export = <String, dynamic>{
      'exported_at': DateTime.now().toIso8601String(),
      'user_id': uid,
      'keys': <String, dynamic>{},
    };

    final out = export['keys'] as Map<String, dynamic>;
    for (final k in keys) {
      if (!shouldIncludeKey(k)) continue;
      final v = prefs.get(k);
      if (v is String && (k.contains('avatar') || k.contains('base64'))) {
        out[k] = {'type': 'string', 'len': v.length};
      } else if (v is String && v.length > 4096) {
        out[k] = {'type': 'string', 'len': v.length};
      } else if (v is List<String> && v.length > 500) {
        out[k] = {'type': 'string_list', 'len': v.length};
      } else {
        out[k] = v;
      }
    }

    final text = const JsonEncoder.withIndent('  ').convert(export);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(tr.z0811),
          content: SingleChildScrollView(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(tr.z0812),
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              },
              child: Text(tr.s210),
            ),
            TextButton(
              onPressed: () async {
                await AuthService.logout();
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const OnboardingPage()),
                  (route) => false,
                );
              },
              child: Text(tr.s014),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr.s048),
            ),
          ],
        );
      },
    );
  }



  /// 签到模拟器：设置连续天数 → 触发里程碑弹窗
  void showCheckInSimulator() {
    final TextEditingController daysController = TextEditingController();

    // 预设快捷按钮对应的天数和标签
    final quickOptions = [
      (1, tr.z0813),
      (6, tr.z0814),
      (7, tr.z0815),
      (29, tr.z0816),
      (30, tr.z0817),
      (99, tr.z0818),
      (100, tr.z0819),
      (364, tr.z0820),
      (365, tr.z0821),
      (1825, tr.z0822),
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.science_rounded, color: Colors.amber),
          SizedBox(width: 8),
          Text(tr.s212),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr.z0823,
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 16),
              TextField(
                controller: daysController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: tr.z0824,
                  hintText: tr.z0825,
                  prefixIcon: const Icon(Icons.calendar_today, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 12),
              Text(tr.z0826,
                  style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: quickOptions.map((opt) {
                  return GestureDetector(
                    onTap: () {
                      daysController.text = opt.$1.toString();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Text(
                        opt.$2,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.amber.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr.s016)),
          ElevatedButton(
            onPressed: () async {
              final days = int.tryParse(daysController.text.trim());
              if (days == null || days < 1 || days > 1825) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(tr.z0827),
                  backgroundColor: Colors.orange,
                  behavior: SnackBarBehavior.floating,
                ));
                return;
              }
              Navigator.pop(ctx);
              await applySimulatedCheckIn(days);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700),
            child: Text(tr.z0828),
          ),
        ],
      ),
    );
  }

  /// 应用模拟签到数据
  Future<void> applySimulatedCheckIn(int days) async {
    final prefs = await SharedPreferences.getInstance();

    // 【修复 v1.9.78】使用用户隔离 key，与 home_page.dart 保持一致
    final uid = prefs.getString('user_id') ?? '';
    final streakKey = uid.isNotEmpty ? 'continuous_days_$uid' : 'continuous_days';
    final totalKey = uid.isNotEmpty ? 'total_check_in_days_$uid' : 'total_check_in_days';
    final historyKey = uid.isNotEmpty ? 'checkin_history_$uid' : 'checkin_history';
    final lastDateKey = uid.isNotEmpty ? 'last_check_in_date_$uid' : 'last_check_in_date';

    // 【P3】设置连续签到天数和累计签到天数（保持一致）
    await prefs.setInt(streakKey, days);
    await prefs.setInt(totalKey, days);
    // 设置最后签到日期为今天
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    await prefs.setString(lastDateKey, todayStr);

    // 构建签到历史：从今天往前推 days 天
    final history = <String>[];
    for (int i = days - 1; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      history.add(dateStr);
    }
    await prefs.setStringList(historyKey, history);

    // 同步到后端（开发者也能真实测试守护圈签到可见）
    try {
      final res = await CheckinService.checkIn(date: todayStr, mood: -1);
      if (res['success'] == true) {
        if (kDebugMode) debugPrint('[DevMode] 签到模拟器后端同步成功');
      } else if (res['error'] == 'already_checked_in') {
        if (kDebugMode) debugPrint('[DevMode] 今日已在后端签过到，本地模拟数据已设置');
      } else {
        if (kDebugMode) debugPrint('[DevMode] 签到模拟器后端同步: ${res['error']}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[DevMode] 签到模拟器后端同步失败（不影响本地）: $e');
    }

    if (!mounted) return;
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(tr.z0829(days)),
      backgroundColor: Colors.amber.shade700,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10))),
    ));

    // 触发里程碑弹窗
    showMilestonePreview(days);
  }

  /// 显示里程碑弹窗预览
  void showMilestonePreview(int days) async {
    final prefs = await SharedPreferences.getInstance();
    // 【修复 v1.9.73】与 home_page 保持一致的姓名读取逻辑
    String? userName;
    final uid = prefs.getString('user_id');
    if (uid != null && uid.isNotEmpty) {
      String? profileJson = prefs.getString('user_profile_$uid');
      profileJson ??= prefs.getString('user_profile');
      if (profileJson != null) {
        try {
          final profile = jsonDecode(profileJson);
          userName = profile['name']?.toString();
        } catch (_) {}
      }
    }
    userName ??= prefs.getString('user_name');
    userName ??= prefs.getString('user_phone');
    final displayName = userName ?? tr.s057;
    // 【修复 v1.9.8】等待底部弹窗关闭动画完成，避免 context 层级冲突
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    // 【修复 v1.9.72】添加异常捕获，防止弹窗构建失败时静默消失
    try {
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => CheckinMilestoneDialog(
          continuousDays: days,
          totalDays: days,
          moodIndex: -1,
          userName: displayName,
        ),
      );
    } catch (e, stack) {
      if (kDebugMode) debugPrint('[DevMode] 里程碑弹窗显示异常: $e');
      if (kDebugMode) debugPrint(stack.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr.z0830(e)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// 重置今日签到（子类可覆写以添加额外刷新逻辑）
  Future<void> resetTodayCheckIn() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          SizedBox(width: 8),
          Text(tr.z0831),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr.z0832),
              SizedBox(height: 8),
              Text(tr.z0833,
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr.s016)),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child: Text(tr.s110),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_check_in_date');
      final history = prefs.getStringList('checkin_history') ?? [];
      final today = DateTime.now().toString().split(' ')[0];
      history.remove(today);
      await prefs.setStringList('checkin_history', history);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr.z0834),
        backgroundColor: Colors.teal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10))),
      ));
    }
  }

  /// 重置守护卡（完整链路测试）
  /// 清除本地所有守护卡缓存，恢复为初始3张卡状态
  /// 注意：仅清除本地缓存，后端已发出的卡需等过期自动退回
  Future<void> resetGuardianCard() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.card_giftcard, color: Colors.pink),
          SizedBox(width: 8),
          Text(tr.s214),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr.z0835),
              SizedBox(height: 8),
              Text(tr.z0836,
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text(tr.z0837,
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text(tr.z0838,
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              SizedBox(height: 8),
              Text(tr.z0839,
                  style: TextStyle(fontSize: 11, color: Colors.orange)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr.s016)),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
            child: Text(tr.s110),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final prefs = await SharedPreferences.getInstance();

      // 第一步：调后端 API 重置配额（带 JWT 认证）
      final token = prefs.getString('auth_token');
      bool backendOk = false;
      if (token != null && token.isNotEmpty) {
        try {
          final apiRes = await ApiService.post(
            '/api/cards/reset-quota',
            auth: true,
          );
          if (apiRes['success'] == true) {
            backendOk = true;
            if (kDebugMode) debugPrint('[DeveloperMode] ✅ 后端配额已重置: available_cards=${apiRes['available_cards']}');
          } else {
            if (kDebugMode) debugPrint('[DeveloperMode] ⚠️ 后端配额重置失败: ${apiRes['error']}');
          }
        } catch (e) {
          if (kDebugMode) debugPrint('[DeveloperMode] ⚠️ 后端配额重置异常: $e');
        }
      }

      // 第二步：重置本地 SharedPreferences
      final userId = prefs.getString('user_id');
      final phone = prefs.getString('user_phone');
      final syncId = (userId != null && userId.isNotEmpty)
          ? userId
          : (phone ?? 'anonymous');

      // 清除所有守护卡相关的本地缓存（包括 syncId 后缀的 key）
      final keysToRemove = <String>[];
      for (final key in prefs.getKeys()) {
        if (key.contains('guardian_card')) {
          keysToRemove.add(key);
        }
      }
      for (final key in keysToRemove) {
        await prefs.remove(key);
      }

      // 重新初始化赠送卡（3张，30天有效期）
      final today = DateTime.now().toString().split(' ')[0];
      await prefs.setString('guardian_card_first_launch_date_$syncId', today);
      await prefs.setInt('guardian_card_gift_remaining_$syncId', 3);

      // 设置标记：下次打开守护卡页时跳过后端同步，避免后端0张覆盖本地3张
      await prefs.setBool('guardian_card_skip_sync_once', true);

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      final msg = backendOk
          ? tr.z0840
          : tr.z0841;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: Colors.pink,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10))),
      ));
    }
  }

  /// 模拟会员过期确认弹窗
  void showMembershipExpiryDialog() {
    final isSmart = MembershipService.isSmartMember();

    if (!isSmart) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr.z0842),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.timer_off_rounded, color: Colors.red),
          SizedBox(width: 8),
          Text(tr.z0843),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr.z0844),
              SizedBox(height: 8),
              Text(tr.z0845,
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text(tr.z0846,
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text(tr.z0847,
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text(tr.z0848,
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              SizedBox(height: 8),
              Text(tr.z0035,
                  style: TextStyle(fontSize: 11, color: Colors.orange)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr.s016),
          ),
          ElevatedButton(
            onPressed: () async {
              // 先设为智能版（确保有过期时间字段），再把过期时间设为昨天
              await MembershipService.setMembershipForDebug(MembershipService.levelSmart);
              final prefs = await SharedPreferences.getInstance();
              // 将过期时间设为昨天，触发自动降级
              final yesterday = DateTime.now().subtract(const Duration(days: 1)).toIso8601String();
              await prefs.setString('membership_expire_at', yesterday);
              // 手动设为体验版，模拟降级后的状态
              await MembershipService.setMembershipForDebug(MembershipService.levelFree);

              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (!mounted) return;
              HapticFeedback.heavyImpact();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(tr.z0849),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
              ));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400),
            child: Text(tr.z0850),
          ),
        ],
      ),
    );
  }

  /// 会员等级切换确认弹窗
  void showMembershipSwitchDialog() {
    final isSmart = MembershipService.isSmartMember();
    final targetLevel = isSmart ? MembershipService.levelFree : MembershipService.levelSmart;
    final targetLabel = isSmart ? tr.z0851 : tr.z0852;
    final targetDesc = isSmart
        ? tr.z0853
        : tr.z0854;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.workspace_premium_rounded, color: Colors.orange),
          SizedBox(width: 8),
          Text(tr.s222),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr.z0855(isSmart ? '智能版' : '体验版')),
              const SizedBox(height: 4),
              Text(tr.z0856(targetLabel),
                  style: TextStyle(fontWeight: FontWeight.w600,
                      color: isSmart ? Colors.grey.shade800 : Colors.orange.shade800)),
              const SizedBox(height: 4),
              Text(targetDesc, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Text(tr.z0035,
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade700)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr.s016),
          ),
          ElevatedButton(
            onPressed: () async {
              await MembershipService.setMembershipForDebug(targetLevel);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (!mounted) return;
              HapticFeedback.mediumImpact();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(tr.z0857(targetLabel)),
                backgroundColor: isSmart ? Colors.grey.shade700 : Colors.orange.shade700,
                behavior: SnackBarBehavior.floating,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isSmart ? Colors.grey : Colors.orange.shade700,
            ),
            child: Text(tr.z0858),
          ),
        ],
      ),
    );
  }
}
