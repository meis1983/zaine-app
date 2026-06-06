import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pages/promotional_showcase_page.dart'; // 新增
import 'checkin_milestone_dialog.dart';
import '../services/api_service.dart';
import '../services/membership_service.dart';
import '../services/api/checkin_service.dart';
import '../services/api/auth_service.dart';
import '../services/platform/health_service.dart';
import '../services/api/sync_service.dart';
import '../pages/onboarding_page.dart';

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
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 标题
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text('开发者模式 v2.0', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
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
                    decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.videocam_rounded, color: Colors.purple.shade700, size: 20),
                  ),
                  title: const Text('3D 宣传录制模式', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('进入电影感动画秀，用于录制宣传视频'),
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
                  title: const Text('签到模拟器', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('设置连续签到天数，测试徽章和里程碑弹窗'),
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
                  title: const Text('重置今日签到', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('清除今天的签到记录，可重新签到'),
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
                  title: const Text('重置守护卡', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('恢复为初始3张卡状态'),
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
                  title: const Text('切换会员等级', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('体验版 ↔ 智能版'),
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
                  title: const Text('模拟会员过期降级', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('测试智能版过期后自动降级为体验版'),
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
                  title: const Text('逆地理诊断', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('查看本次地址来源（高德/系统）及错误码'),
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
                  title: const Text('Apple Watch 测试', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('查看 Watch 信号 & 触发一次静默签到'),
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
                  title: const Text('HealthKit 诊断', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('查看授权/错误/最近一次拉取，并可一键触发读取'),
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
                  title: const Text('导出工作记忆 / 切换账号', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('导出本机调试数据（不含token）并退出登录'),
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
                  title: const Text('重新显示引导页', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('下次启动App时再次显示开机引导'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('onboarding_completed', false);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('已设置，下次启动将显示引导页 ✓'),
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
    final amapInfo = prefs.getString('geocode_last_amap_info') ?? '';
    final amapInfoCode = prefs.getString('geocode_last_amap_infocode') ?? '';

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('逆地理诊断'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('来源：$provider'),
              const SizedBox(height: 6),
              Text('时间：${time.isEmpty ? "无" : time}'),
              const SizedBox(height: 6),
              Text('地址：${address.isEmpty ? "无" : address}'),
              const SizedBox(height: 12),
              Text('高德 info：${amapInfo.isEmpty ? "无" : amapInfo}'),
              const SizedBox(height: 6),
              Text('高德 infocode：${amapInfoCode.isEmpty ? "无" : amapInfoCode}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final text = 'provider=$provider\ntime=$time\naddress=$address\namap_info=$amapInfo\namap_infocode=$amapInfoCode';
                await Clipboard.setData(ClipboardData(text: text));
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('诊断信息已复制'),
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              },
              child: const Text('复制'),
            ),
            TextButton(
              onPressed: () async {
                await prefs.remove('geocode_last_provider');
                await prefs.remove('geocode_last_time');
                await prefs.remove('geocode_last_address');
                await prefs.remove('geocode_last_amap_info');
                await prefs.remove('geocode_last_amap_infocode');
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('清除'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('关闭'),
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
          title: const Text('Apple Watch 测试'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('pending_watch_checkin：${pending ? "true" : "false"}'),
              const SizedBox(height: 6),
              Text('最后一次 Watch action：${lastAction.isEmpty ? "无" : lastAction}'),
              const SizedBox(height: 6),
              Text('最后一次 Watch 时间：${lastTime.isEmpty ? "无" : lastTime}'),
              const SizedBox(height: 12),
              const Text('提示：健康数据读取不依赖 Watch App，Apple Watch 佩戴数据会自动写入 iPhone 健康。'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await prefs.setBool('pending_watch_checkin', true);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('已写入 Watch 签到信号（pending_watch_checkin=true）'),
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              },
              child: const Text('模拟信号'),
            ),
            TextButton(
              onPressed: () async {
                await HealthService.performSilentHeartbeatCheckin();
                unawaited(SyncService.pullFromServer());
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('触发静默签到'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('关闭'),
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
          title: const Text('HealthKit 诊断'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('最近授权：${authorized == null ? "未知" : (authorized ? "true" : "false")}'),
                const SizedBox(height: 6),
                Text('授权时间：${authTime.isEmpty ? "无" : authTime}'),
                const SizedBox(height: 6),
                Text('授权错误：${authErr.isEmpty ? "无" : authErr}'),
                const SizedBox(height: 12),
                Text('最近拉取条数：${fetchCount == null ? "未知" : fetchCount.toString()}'),
                const SizedBox(height: 6),
                Text('拉取时间：${fetchTime.isEmpty ? "无" : fetchTime}'),
                const SizedBox(height: 6),
                Text('拉取错误：${fetchErr.isEmpty ? "无" : fetchErr}'),
                const SizedBox(height: 12),
                Text('按类型条数：${typeCounts.isEmpty ? "无" : typeCounts}', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 6),
                Text('按类型错误：${typeErrors.isEmpty ? "无" : typeErrors}', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await HealthService.requestPermissions();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('重新授权'),
            ),
            TextButton(
              onPressed: () async {
                await HealthService.getHealthSummary();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('触发读取'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('关闭'),
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
          title: const Text('导出工作记忆'),
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
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('已复制工作记忆（不含token）'),
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              },
              child: const Text('复制'),
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
              child: const Text('退出登录'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('关闭'),
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
      (1, '第1天'),
      (6, '第6天'),
      (7, '第7天'),
      (29, '第29天'),
      (30, '第30天'),
      (99, '第99天'),
      (100, '第100天'),
      (364, '第364天'),
      (365, '第365天'),
      (1825, '第1825天'),
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.science_rounded, color: Colors.amber),
          SizedBox(width: 8),
          Text('签到模拟器'),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('设置连续签到天数，然后点击"模拟签到"。',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 16),
              TextField(
                controller: daysController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: '连续签到天数',
                  hintText: '输入 1-1825 之间的天数',
                  prefixIcon: const Icon(Icons.calendar_today, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 12),
              const Text('快捷选择：',
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
              child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              final days = int.tryParse(daysController.text.trim());
              if (days == null || days < 1 || days > 1825) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('请输入 1-1825 之间的有效天数'),
                  backgroundColor: Colors.orange,
                  behavior: SnackBarBehavior.floating,
                ));
                return;
              }
              Navigator.pop(ctx);
              await applySimulatedCheckIn(days);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700),
            child: const Text('模拟签到'),
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
        debugPrint('[DevMode] 签到模拟器后端同步成功');
      } else if (res['error'] == 'already_checked_in') {
        debugPrint('[DevMode] 今日已在后端签过到，本地模拟数据已设置');
      } else {
        debugPrint('[DevMode] 签到模拟器后端同步: ${res['error']}');
      }
    } catch (e) {
      debugPrint('[DevMode] 签到模拟器后端同步失败（不影响本地）: $e');
    }

    if (!mounted) return;
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('已模拟连续签到 $days 天 ✓'),
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
    final displayName = userName ?? '在呢用户';
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
      debugPrint('[DevMode] 里程碑弹窗显示异常: $e');
      debugPrint(stack.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('弹窗显示失败: $e'),
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
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          SizedBox(width: 8),
          Text('重置签到'),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('这将清除今天的签到记录，你可以重新签到。'),
              const SizedBox(height: 8),
              const Text('连续天数不会受影响。',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child: const Text('确认重置'),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('今日签到已重置 ✓'),
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
        title: const Row(children: [
          Icon(Icons.card_giftcard, color: Colors.pink),
          SizedBox(width: 8),
          Text('重置守护卡'),
        ]),
        content: SingleChildScrollView(
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('这将重置守护卡为初始状态：'),
              SizedBox(height: 8),
              Text('• 后端配额重置为 3 张（30天有效期）',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text('• 清除本地所有守护卡缓存数据',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text('• 重置首次发卡日期',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              SizedBox(height: 8),
              Text('后端已发出的卡片不受影响，仍可被注册',
                  style: TextStyle(fontSize: 11, color: Colors.orange)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
            child: const Text('确认重置'),
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
            debugPrint('[DeveloperMode] ✅ 后端配额已重置: available_cards=${apiRes['available_cards']}');
          } else {
            debugPrint('[DeveloperMode] ⚠️ 后端配额重置失败: ${apiRes['error']}');
          }
        } catch (e) {
          debugPrint('[DeveloperMode] ⚠️ 后端配额重置异常: $e');
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
          ? '守护卡已重置为初始状态 ✓（3张，30天有效）'
          : '本地守护卡已重置 ✓（后端未登录未重置）';
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('请先切换为智能版，再测试过期降级'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.timer_off_rounded, color: Colors.red),
          SizedBox(width: 8),
          Text('模拟会员过期'),
        ]),
        content: SingleChildScrollView(
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('模拟智能版过期后自动降级为体验版：'),
              SizedBox(height: 8),
              Text('• 紧急求助快捷拨打上限：3位 → 1位',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text('• 联系人上限：10位 → 5位',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text('• 超出限制的联系人显示锁定图标',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text('• 已添加的联系人数据保留',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              SizedBox(height: 8),
              Text('⚠️ 仅开发测试用，不影响后端数据',
                  style: TextStyle(fontSize: 11, color: Colors.orange)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
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
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('已模拟会员过期降级 → 体验版 ✓'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
              ));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400),
            child: const Text('模拟过期'),
          ),
        ],
      ),
    );
  }

  /// 会员等级切换确认弹窗
  void showMembershipSwitchDialog() {
    final isSmart = MembershipService.isSmartMember();
    final targetLevel = isSmart ? MembershipService.levelFree : MembershipService.levelSmart;
    final targetLabel = isSmart ? '体验版（免费）' : '智能版（¥9/月）';
    final targetDesc = isSmart
        ? '紧急求助快捷拨打 1 位 · 最多 5 位联系人'
        : '紧急求助快捷拨打 3 位 · 最多 10 位联系人';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.workspace_premium_rounded, color: Colors.orange),
          SizedBox(width: 8),
          Text('切换会员等级'),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前：${isSmart ? '智能版' : '体验版'}'),
              const SizedBox(height: 4),
              Text('切换为：$targetLabel',
                  style: TextStyle(fontWeight: FontWeight.w600,
                      color: isSmart ? Colors.grey.shade800 : Colors.orange.shade800)),
              const SizedBox(height: 4),
              Text(targetDesc, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Text('⚠️ 仅开发测试用，不影响后端数据',
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade700)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              await MembershipService.setMembershipForDebug(targetLevel);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (!mounted) return;
              HapticFeedback.mediumImpact();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('已切换为 $targetLabel ✓'),
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
            child: const Text('确认切换'),
          ),
        ],
      ),
    );
  }
}
