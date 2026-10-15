import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../utils/streak_util.dart';
import 'dart:async';
import 'contacts_page.dart';
import 'guardian_card_page.dart';
import 'health_overview_page.dart'; // 新增
import '../config/feature_flags.dart';
import 'social_page.dart';
import 'package:intl/intl.dart';
import '../theme/theme_helper.dart';
import '../utils/contact_parser.dart';
import '../services/api/peace_service.dart';
import '../services/api/user_service.dart';
import '../services/api/contact_service.dart';
import '../services/api/card_service.dart';
import '../services/api_service.dart';
import '../services/api/notify_service.dart';
import '../data/app_constants.dart';
import '../utils/wechat_helper.dart';
import '../config/app_config.dart';
import '../services/platform/health_service.dart';
import '../services/safety/vitals_assessment.dart';
import '../services/database/circle_event_dao.dart';
import '../l10n/i18n.dart';
import '../services/debug_log.dart'; // [192] 守护圈同步诊断（双通道，文件兜底）

/// 蓝色调：用于「我守护的人」专区，与橙色「守护我的人」严格区分
const Color _kGuardedBlue = Color(0xFF3F7CFF);

/// 【v1.97.3+167 今天时间流】今日事件流条目（纯本地聚合，不涉后端）
class _FeedItem {
  final String type;
  final String title;
  final String subtitle;
  final DateTime ts;
  final IconData icon;
  final Color accent;

  _FeedItem({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.ts,
    required this.icon,
    required this.accent,
  });
}

/// 「我守护的人」管理面板（备注名 + 重新邀请，无解除）
class _GuardedByMeManagerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> people;
  final Map<int, String> remarks;
  final String Function(Map<String, dynamic>) displayName;
  final Widget Function(Map<String, dynamic>) avatarBuilder;
  final Future<void> Function(int, String) onEditRemark;
  /// 【CN合规】可为 null：CN 版传 null 以彻底移除"重新邀请"入口（主动拉人=鼓励传播）
  final Future<void> Function(Map<String, dynamic>)? onReinvite;

  const _GuardedByMeManagerSheet({
    required this.people,
    required this.remarks,
    required this.displayName,
    required this.avatarBuilder,
    required this.onEditRemark,
    required this.onReinvite,
  });

  @override
  State<_GuardedByMeManagerSheet> createState() =>
      _GuardedByMeManagerSheetState();
}

class _GuardedByMeManagerSheetState extends State<_GuardedByMeManagerSheet> {
  late Map<int, String> _remarks;

  @override
  void initState() {
    super.initState();
    _remarks = Map<int, String>.from(widget.remarks);
  }

  Future<void> _edit(int receiverId, String current) async {
    final controller = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (dctx) => AlertDialog(
        title:  Text(tr.s364),
        content: TextField(
          controller: controller,
          decoration:  InputDecoration(hintText: tr.s365),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dctx).pop(), child:  Text(tr.s016)),
          TextButton(
              onPressed: () => Navigator.of(dctx).pop(controller.text.trim()),
              child:  Text(tr.s366)),
        ],
      ),
    );
    if (result != null) {
      await widget.onEditRemark(receiverId, result);
      setState(() => _remarks[receiverId] = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _kGuardedBlue;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 16,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.favorite_rounded, color: color),
            const SizedBox(width: 8),
             Text(tr.s367,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(tr.s540(widget.people.length),
                style: TextStyle(color: Colors.grey[500])),
          ]),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: widget.people.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final p = widget.people[i];
                final rid = p['receiver_id'];
                final name = _remarks[rid]?.isNotEmpty == true
                    ? _remarks[rid]!
                    : widget.displayName(p);
                final isPending = p['last_signin_at'] == null;
                final checkedIn = p['checked_in_today'] == true;
                return ListTile(
                  leading: widget.avatarBuilder(p),
                  title: Text(name),
                  subtitle: Row(children: [
                    Icon(
                      isPending
                          ? Icons.bedtime_outlined
                          : (checkedIn
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked),
                      size: 14,
                      color: isPending
                          ? Colors.orange
                          : (checkedIn ? Colors.green : Colors.grey),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPending
                          ? tr.s369
                          : (checkedIn ? tr.signInButtonCheckedIn : tr.s370),
                      style: TextStyle(
                        fontSize: 12,
                        color: isPending
                            ? Colors.orange
                            : (checkedIn ? Colors.green : Colors.grey),
                      ),
                    ),
                  ]),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isPending && widget.onReinvite != null)
                        TextButton(
                          onPressed: () => widget.onReinvite!(p),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child:  Text(
                            tr.s371,
                            style: TextStyle(fontSize: 13, color: Color(0xFF667EEA)),
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _edit(rid is int ? rid : 0, name),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class GuardianPage extends StatefulWidget {
  const GuardianPage({super.key});

  @override
  State<GuardianPage> createState() => _GuardianPageState();
}

class _GuardianPageState extends State<GuardianPage> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _guardians = [];
  // 【2026-07-12 议题B】我守护的人：我发出的已绑定普通守护卡（无人数上限），与「守护我的人」严格分区
  List<Map<String, dynamic>> _guardedByMe = [];
  // 【2026-07-15 修复】用 String 作 key 兼容 int/String 类型，存储「我守护的人」的签到状态，用于覆盖「守护我的人」同一 user 的显示状态
  Map<String, bool> _guardedByMeCheckedIn = {};
  // 「我守护的人」备注名（本地存储，key=guarded_by_me_remark_<receiver_id>）
  Map<int, String> _guardedRemarks = {};
  // 【v1.97.3+166 双向视觉】互相守护的用户 id 集合（「守护我的人」userId 与「我守护的人」receiver_id 的交集）
  Set<String> _mutualUserIds = {};
  // 【C4 方案C合并版】守护人端平安确认响应状态：receiver_id(string) -> status(0待确认/1已确认/2需要帮助)
  Map<String, int> _peaceStatusByReceiver = {};
  // 【方案三 v1.97.1+160】receiver_id -> 最新 request_id（「已联系」标记已处理用）
  Map<String, int> _peaceRequestIdByReceiver = {};
  // 【留言功能 v1】receiver_id -> 「需要帮助」时附带的选填留言（status=2 且非空时展示）
  Map<String, String> _peaceMessageByReceiver = {};
  Timer? _refreshTimer; // 定期刷新定时器

  // 【v1.97.4 状态引擎上提】生命体征守护状态卡数据
  VitalsAssessment? _safetySignal;
  Map<String, dynamic>? _healthSummary;
  bool _healthAuthorized = false;
  // 【v1.97.3+176 诊断】最近一次 HealthKit 授权检测结论（应用内直接可见，免开控制台）
  String _healthAuthDiag = tr.s372;
  bool _autoAlertEnabled = true;
  // 【v1.97.3+169】最近一次体征同步时间戳(ms)，用于卡片显示「同步 X 分钟前」
  int _lastHealthSyncAt = 0;

  // 【v1.97.3+167 今天时间流】本地聚合的今日事件流
  List<_FeedItem> _todayFeed = [];
  bool _feedLoading = true;

  // 【v1.97.5 修复】头部计数就绪标志：仅在「守护我的人 / 我守护的人 / 互为守护」三源全部
  // 填充完成后才显示详细计数，消除进入页面时数字逐步跳变的级联刷新。
  bool _headerReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadGuardians();
    _loadTodayFeed();
    // 【v1.97.3+192 修复】进页面即加载生命体征守护状态：此前仅在 batchLookup 失败兜底分支
    // 才调 _loadSafetyStatus，成功路径(532 行提前 return)直接跳过 → 进页面恒显「未监测」，
    // 必须手动点刷新(_refreshHealthAuth)才显示「守护中」。这里保证每次进页都加载。
    unawaited(_loadSafetyStatus());
    // 【v1.95.0】定期刷新缩短为 30 秒，确保守护圈状态以服务端为准、及时纠正偶发错乱
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) _loadGuardians(isSilent: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 当 App 从后台回到前台时，自动刷新数据
    if (state == AppLifecycleState.resumed) {
      if (kDebugMode) debugPrint('[GuardianPage] App resumed, refreshing guardians...');
      _loadGuardians(isSilent: true);
      // 【v1.97.3+171】从系统设置/体征页完成 HealthKit 授权后回 App，守护圈需要重新读 health_last_authorized
      // 否则「守护中」绿色角标不会即时显示
      _loadSafetyStatus();
    }
  }

  /// 按手机号去重守护者列表（规避后端补偿重复调用产生的脏数据）
  List<Map<String, dynamic>> _dedupGuardians(List<Map<String, dynamic>> list) {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final c in list) {
      final phone = (c['phone']?.toString() ?? '').trim();
      if (phone.isEmpty) {
        out.add(c);
        continue;
      }
      if (seen.contains(phone)) continue;
      seen.add(phone);
      out.add(c);
    }
    return out;
  }

  Future<void> _loadGuardians({bool isSilent = false}) async {
    // 【C4】非阻塞拉取平安确认响应状态（守护人端看被守护人回复），独立于联系人加载
    unawaited(_loadPeaceStatus());
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final userId = prefs.getString('user_id');
    final contactsKey = (userId != null && userId.isNotEmpty)
        ? 'emergency_contacts_$userId'
        : 'emergency_contacts';

    // 第1步：立即从本地缓存加载联系人列表（秒显）
    List<Map<String, dynamic>> contacts = await _loadContactsFromCache(prefs, contactsKey);

    // 已有缓存数据 → 立即渲染（从缓存恢复状态，避免硬编码 false）
    if (contacts.isNotEmpty && mounted) {
      final initialGuardians = contacts.map((c) {
        final name = (c['name'] ?? tr.s373).toString();
        final phone = (c['phone'] ?? '').toString();
        final relation = (c['relation'] == null || c['relation'].toString().isEmpty) ? tr.s374 : c['relation'].toString();

        final cachedAvatar = prefs.getString('contact_avatar_phone_$phone') ?? '';
        final cachedCheckedIn =
            prefs.getBool('contact_checked_in_today_phone_$phone') ?? false;
        final cachedLastSigninAt =
            prefs.getString('contact_last_signin_at_phone_$phone');
        final isActive =
            cachedLastSigninAt != null && cachedLastSigninAt.isNotEmpty;
        // 【修复 v1.76.0】从缓存读取注册状态，不再硬编码 false
        final cachedIsRegistered =
            prefs.getBool('contact_is_registered_phone_$phone') ?? false;
        // 【v1.95.0 B方案】本地缓存秒显：进页面立即显示缓存的已注册/未注册，
        // 后台静默 batchLookup 校正；仅当真实查询失败才显示错误提示
        const initialStatusError = null;
        final cachedUserId = prefs.getInt('contact_user_id_phone_$phone');

        return <String, dynamic>{
          'name': name,
          'phone': phone,
          'relation': relation,
          'isRegistered': cachedIsRegistered,
          'userId': cachedUserId,
          'checkedInToday': cachedCheckedIn,
          'statusError': initialStatusError,
          'avatarBase64': cachedAvatar,
          'lastSigninAt': cachedLastSigninAt,
          'isActive': isActive,
        };
      }).toList();
      setState(() {
        _guardians = _dedupGuardians(initialGuardians);
      });
    }

    // 第2步：后台异步从后端拉取最新联系人列表
    try {
      // 并行加载联系人列表、邀请统计、以及「我守护的人」列表（议题B，无上限）
      final results = await Future.wait([
        ContactService.getContacts(),
        // 【CN合规】CN 版不拉取邀请（裂变）统计，去除传播相关基础设施调用
        kIsChinaBuild
            ? Future<Map<String, dynamic>>.value(<String, dynamic>{'success': false})
            : CardService.getInviteStats(),
        CardService.getGuardedByMe(),
      ]);

      final res = results[0];
      final statsRes = results[1];
      final guardedRes = results[2];

      if (res['success'] == true && res['contacts'] != null) {
        final serverContacts = <Map<String, dynamic>>[];
        for (final item in res['contacts'] as List<dynamic>) {
          if (item is Map<String, dynamic>) {
            serverContacts.add(item);
          } else if (item is Map) {
            serverContacts.add(Map<String, dynamic>.from(item));
          }
        }
        if (serverContacts.isNotEmpty) contacts = serverContacts;
        // 更新本地缓存
        await prefs.setString(contactsKey, jsonEncode(contacts));
        if (kDebugMode) debugPrint('[GuardianPage] ✅ 从后端加载 ${contacts.length} 个联系人');
      }

      if (statsRes['success'] == true) {
        if (kDebugMode) {
          debugPrint('[GuardianPage] ✅ 获取邀请统计: total_registered=${statsRes['total_registered']}');
        }
      }

      // 【2026-07-12 议题B】我守护的人（我发出的已绑定普通守护卡）
      if (guardedRes['success'] == true && guardedRes['guarded'] is List) {
        final list = (guardedRes['guarded'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
        // 【v1.97.5 修复】仅赋值，延迟到 batchLookup 完成后(行516/521 统一 setState)再刷新，
        // 避免头部「已成功守护 N 位」先于「X 位守护者 / 与 K 位互为守护」出现 → 数字级联跳动。
        _guardedByMe = list;
        // 【2026-07-15 修复】构建 user_id -> 今日是否已签到的映射，用于覆盖「守护我的人」显示状态
        // 用 .toString() 作 key，兼容后端 int/String 两种返回类型
        _guardedByMeCheckedIn = {
          for (final p in list)
            if (p['receiver_id'] != null)
              p['receiver_id'].toString(): (p['checked_in_today'] == true),
        };
        if (kDebugMode) debugPrint('[GuardianPage] ✅ 我守护的人: ${list.length} 位');

        // 加载「我守护的人」备注名（本地存储，key=guarded_by_me_remark_<receiver_id>）
        final remarks = <int, String>{};
        for (final p in list) {
          final rid = p['receiver_id'];
          if (rid is int) {
            final r = prefs.getString('guarded_by_me_remark_$rid');
            if (r != null && r.isNotEmpty) remarks[rid] = r;
          }
        }
        _guardedRemarks = remarks;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[GuardianPage] ⚠️ 后端拉取失败: $e');
    }

    if (!mounted) return;
    if (contacts.isEmpty) {
      _headerReady = true; // 无联系人 → 直接显示空态，无需等待
      if (mounted) setState(() {});
      return;
    }

    // 第3步：批量查询所有联系人的状态（v2.0 性能优化，消除 N+1 请求）
    try {
      final List<String> phones = contacts.map((c) => (c['phone'] ?? '').toString()).toList();
      // 【v1.97.3+193】记录实际发往后端的 phone 列表，避免「手机号格式归一化」一类无声问题
      try { await DebugLog.write('193 G', 'batchLookup REQ phones=$phones'); } catch (_) {}
      final batchRes = await UserService.batchLookup(phones);
      
      if (batchRes['success'] == true && batchRes['results'] != null) {
        final Map<String, dynamic> resultsMap = batchRes['results'];
        final updatedGuardians = <Map<String, dynamic>>[];
        for (final c in contacts) {
          final phone = (c['phone'] ?? '').toString();
          final name = (c['name'] ?? tr.s373).toString();
          final relation = (c['relation'] == null || c['relation'].toString().isEmpty) ? tr.s374 : c['relation'].toString();

      final status = resultsMap[phone];
      if (status != null && status['found'] == true) {
        // 【已注册】原逻辑保持不变
        final foundUserId = status['user_id'] as int?;
        final avatarBase64 = status['avatar_base64']?.toString() ?? '';
        final lastSigninAt = status['last_signin_at']?.toString() ?? '';
        var checkedInToday = status['checked_in_today'] == true;
        final todayMood = status['today_mood'] as int?;  // 1-5，null 表示未签到

        // 【v1.97.4 修复】双向守护侧「明确已签到(true)」才升级；绝不用其(恒为 false，
        // 因 getGuardedByMe 不返回可靠 checked_in_today) 覆盖 batchLookup(user.py，已用今日中国日期)的正确结果，
        // 否则会导致「好友已签到却显示未签到」。batchLookup 的 true 保持 true，false 保持 false。
        if (foundUserId != null &&
            _guardedByMeCheckedIn.containsKey(foundUserId.toString()) &&
            _guardedByMeCheckedIn[foundUserId.toString()] == true) {
          checkedInToday = true;
        }

        // 【v1.97.3+191 修复】无条件以 batchLookup 返回值为准覆盖本地缓存：
        // 服务端已是成员最新头像的真相源，空值表示用户未设头像（UI 回退默认首字母），
        // 不再因本地旧值残留导致「几个月前的头像」一直显示。
        await prefs.setString('contact_avatar_phone_$phone', avatarBase64);
        if (foundUserId != null) {
          await prefs.setString('contact_avatar_$foundUserId', avatarBase64);
        }
        await prefs.setBool('contact_checked_in_today_phone_$phone', checkedInToday);
        await prefs.setInt('contact_today_mood_phone_$phone', todayMood ?? 0);  // 0 表示未签到
        await prefs.setString('contact_last_signin_at_phone_$phone', lastSigninAt);
        // 【修复 v1.76.0】将注册状态写入缓存，避免下次加载时显示错误
        await prefs.setBool('contact_is_registered_phone_$phone', true);
        await prefs.setInt('contact_user_id_phone_$phone', foundUserId!);

        updatedGuardians.add(<String, dynamic>{
          'name': name,
          'phone': phone,
          'relation': relation,
          'isRegistered': true,
          'userId': foundUserId,
          'checkedInToday': checkedInToday,
          'todayMood': todayMood,  // 今日心情（1-5，null 或 0 表示未签到）
          'statusError': null,
          'avatarBase64': avatarBase64.isNotEmpty
              ? avatarBase64
              : (prefs.getString('contact_avatar_phone_$phone') ?? ''),
          'lastSigninAt': lastSigninAt,
          'isActive': lastSigninAt.isNotEmpty,
        });
      } else if (status != null && status['found'] == false) {
        // 【明确未注册】服务端确认未注册，写缓存 + 显示未注册
        await prefs.setBool('contact_is_registered_phone_$phone', false);
        await prefs.remove('contact_user_id_phone_$phone');
        updatedGuardians.add(<String, dynamic>{
          'name': name,
          'phone': phone,
          'relation': relation,
          'isRegistered': false,
          'userId': null,
          'checkedInToday': prefs.getBool('contact_checked_in_today_phone_$phone') ?? false,
          'statusError': null,
          'avatarBase64': prefs.getString('contact_avatar_phone_$phone') ?? '',
          'lastSigninAt': prefs.getString('contact_last_signin_at_phone_$phone'),
          'isActive': (prefs.getString('contact_last_signin_at_phone_$phone') ?? '').isNotEmpty,
        });
      } else {
        // 【v1.95.0 修复】batchLookup 结果缺失（网络抖动/该联系人未在返回中）：
        // 不武断标记为未注册，降级使用缓存值并保留原状态，避免污染缓存导致偶发错乱
        final cachedIsReg = prefs.getBool('contact_is_registered_phone_$phone') ?? false;
        final cachedUid = prefs.getInt('contact_user_id_phone_$phone');
        updatedGuardians.add(<String, dynamic>{
          'name': name,
          'phone': phone,
          'relation': relation,
          'isRegistered': cachedIsReg,
          'userId': cachedUid,
          'checkedInToday': prefs.getBool('contact_checked_in_today_phone_$phone') ?? false,
          'statusError': null,
          'avatarBase64': prefs.getString('contact_avatar_phone_$phone') ?? '',
          'lastSigninAt': prefs.getString('contact_last_signin_at_phone_$phone'),
          'isActive': (prefs.getString('contact_last_signin_at_phone_$phone') ?? '').isNotEmpty,
        });
      }
        }

        if (mounted) {
          setState(() {
            _guardians = updatedGuardians;
          });
        }
        // 【v1.97.3+192 诊断】记录 batchLookup 实际返回的签到/头像/活跃，确认守护圈同步是否到位
        try {
          final sb = StringBuffer();
          for (final g in updatedGuardians) {
            final ph = (g['phone'] ?? '').toString();
            final ci = g['checkedInToday'] == true;
            final av = (g['avatarBase64']?.toString() ?? '').length;
            // 【v1.97.3+193】额外记录 lastSigninAt 与 isActive，供「待激活」一类故障定位
            final la = (g['lastSigninAt']?.toString() ?? '');
            sb.write(tr.s541(ph, ci, av, la.isEmpty ? "空" : la, g['isActive']));
          }
          await DebugLog.write('193 G', tr.s542((batchRes['results'] as Map?)?.keys.toList(), sb));
          // 【v1.97.3+193】原始 response.body 在 ApiService 层可能未暴露，这里从 batchRes 全 dump 一份（含 statusCode/raw 字段）
          await DebugLog.write('193 G', 'batchRes full=${batchRes.toString()}');
        } catch (e) {
          await DebugLog.write('193 G', tr.s543(e));
        }
        _loadTodayFeed();
        // 【v1.97.3+168 修复】batchLookup 主路径也需重算互相守护（与 fallback 路径 L612-615 对齐）
        _recomputeMutual();
        _headerReady = true; // 【v1.97.5】三源已齐，允许显示详细计数
        if (mounted) setState(() {});
        return;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[GuardianPage] 批量状态查询异常: $e');
      try { await DebugLog.write('193 G', tr.s544(e)); } catch (_) {}
    }

    // 兜底方案：如果批量查询失败，使用原有的并行单点查询逻辑（保持鲁棒性）
    // 第4步：并行查询所有联系人的注册状态 + 签到状态
    final statusFutures = contacts.map((c) async {
      final name = (c['name'] ?? tr.s373).toString();
      final phone = (c['phone'] ?? '').toString();
      final relation = (c['relation'] ?? tr.s374).toString();
      bool isRegistered = false;
      int? foundUserId;
      bool checkedInToday = false;
      bool isActive = false;
      String? statusError;
      String? avatarBase64;
      String? lastSigninAt;

      try {
        final lookupRes = await UserService.lookupByPhone(phone);
        // 【v1.97.3+193】dump 兜底 lookup 原始返回（含 last_signin_at / avatar_base64 长度）
        try { await DebugLog.write('193 G', 'FALLBACK lookupByPhone($phone): found=${lookupRes['found']}, user_id=${lookupRes['user_id']}, avatar_len=${lookupRes['avatar_base64']?.toString().length ?? 0}, last_signin=${lookupRes['last_signin_at']}, raw=${lookupRes.toString()}'); } catch (_) {}
        if (lookupRes['success'] == true && lookupRes['found'] == true) {
          isRegistered = true;
          foundUserId = lookupRes['user_id'] as int?;
          // 【v1.9.73】提取联系人头像 base64 并缓存到本地
          avatarBase64 = lookupRes['avatar_base64']?.toString();
          // 【调试】记录头像查询结果
          if (kDebugMode) debugPrint('[GuardianPage] lookupByPhone($phone): found=$foundUserId, avatar_len=${avatarBase64?.length ?? 0}, avatar_empty=${avatarBase64?.isEmpty ?? true}');
          // 【v1.9.77】提取最后签到时间，判断活跃度
          lastSigninAt = lookupRes['last_signin_at']?.toString();
          isActive = lastSigninAt != null && lastSigninAt.isNotEmpty;
          if (avatarBase64 != null && avatarBase64.isNotEmpty && foundUserId != null) {
            await prefs.setString('contact_avatar_$foundUserId', avatarBase64);
          }
          // 【修复 v1.76.0】将注册状态写入缓存
          await prefs.setBool('contact_is_registered_phone_$phone', true);
          await prefs.setInt('contact_user_id_phone_$phone', foundUserId!);
        } else if (lookupRes['found'] == false) {
          // 【修复 v1.76.0】服务端明确返回未注册，写入缓存
          await prefs.setBool('contact_is_registered_phone_$phone', false);
          await prefs.remove('contact_user_id_phone_$phone');
        } else if (lookupRes['offline'] == true) {
          statusError = tr.s379;
        }
      } catch (e) {
        statusError = tr.s380;
        if (kDebugMode) debugPrint('[GuardianPage] lookupByPhone($phone) 异常: $e');
      }

      if (isRegistered && foundUserId != null) {
        try {
          final checkinRes = await UserService.queryCheckinStatus(foundUserId);
          // 【v1.97.3+193】dump 兜底 queryCheckinStatus 原始返回
          try { await DebugLog.write('193 G', 'FALLBACK queryCheckinStatus($foundUserId): success=${checkinRes['success']}, checked_in_today=${checkinRes['checked_in_today']}, raw=${checkinRes.toString()}'); } catch (_) {}
          if (checkinRes['success'] == true) {
            checkedInToday = checkinRes['checked_in_today'] == true;
          }
          // 【v1.97.4 修复】仅当双向守护侧明确已签到(true)时升级；绝不降级覆盖 batchLookup 正确结果
          if (foundUserId != null &&
              _guardedByMeCheckedIn.containsKey(foundUserId.toString()) &&
              _guardedByMeCheckedIn[foundUserId.toString()] == true) {
            checkedInToday = true;
          }
        } catch (e) {
          if (kDebugMode) debugPrint('[GuardianPage] 签到状态查询失败: $e');
        }
        // 如果 lookup 未返回头像，尝试从本地缓存读取
        if (avatarBase64 == null || avatarBase64.isEmpty) {
          avatarBase64 = prefs.getString('contact_avatar_$foundUserId');
        }
      }
      await prefs.setBool(
          'contact_checked_in_today_phone_$phone', checkedInToday);
      if (lastSigninAt != null) {
        await prefs.setString('contact_last_signin_at_phone_$phone', lastSigninAt);
      }
      if (avatarBase64 != null && avatarBase64.isNotEmpty) {
        await prefs.setString('contact_avatar_phone_$phone', avatarBase64);
      }

      return <String, dynamic>{
        'name': name,
        'phone': phone,
        'relation': relation,
        'isRegistered': isRegistered,
        'userId': foundUserId,
        'checkedInToday': checkedInToday,
        'statusError': statusError,
        'avatarBase64': avatarBase64 ?? '',
        'lastSigninAt': lastSigninAt,
        'isActive': isActive,
      };
    }).toList();

    // 并行执行所有查询（不再串行）
    final results = await Future.wait(statusFutures);
    if (mounted) {
      setState(() {
        _guardians = _dedupGuardians(results);
      });
    }
    _loadTodayFeed();

    // 【2026-07-15 修复】最终兜底：再次确保「守护我的人」与「我守护的人」签到状态一致
    // 因为前序分支可能因异常/类型不匹配等原因没有覆盖成功
    _finalSyncGuardianCheckInStatus();
    // 【v1.97.3+166 双向视觉】重算「互相守护」集合（userId == receiver_id 交集），并触发重建
    _recomputeMutual();
    _headerReady = true; // 【v1.97.5】三源已齐，允许显示详细计数
    if (mounted) setState(() {});
    // 【v1.97.4 状态引擎上提】并行加载生命体征守护状态（纯判定，不触发外发）
    unawaited(_loadSafetyStatus());
  }

  /// 加载生命体征守护状态卡数据
  /// 【v1.97.4 关键修复】授权态以「粘性标记」(HealthService.isAuthorized) 为单一真相源：
  ///   - 一旦用户完成 HealthKit 授权（弹框同意 或 实测有真实样本），即持久化 true；
  ///   - 实时查询(HealthKit 偶发失败/无样本)只用于刷新安全信号数据，**绝不反向推翻**标记。
  /// 根除此前「守护中 ↔ 尚未检测」的跳动（原先每次进页实时查 HealthKit，失败即回落 false）。
  Future<void> _loadSafetyStatus() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();

    // 粘性标记：已授权则恒为「守护中」，不受实时查询抖动影响
    bool sticky = await HealthService.isAuthorized();

    if (!sticky) {
      // 【v1.97.6 破冰修复】若当前标记 false，但历史上曾成功授权过(health_authorized_at 存在)，
      // 直接认定「守护中」——iOS HealthKit 隐私模型下实时探测(read 状态)不可靠、常失败，
      // 绝不能让偶发探测失败把"曾授权"的事实推翻回「尚未检测」。这是跳动的根治点。
      final everAuthorized = await HealthService.hasEverAuthorized();
      if (everAuthorized) {
        sticky = true;
      } else {
        // 从未授权过：用真实样本探测一次（仅用于"探测是否已授权"）
        Map<String, dynamic> authResult;
        try {
          authResult = await HealthService.checkRealAuthStatus();
        } catch (e) {
          debugPrint('[GuardianPage] checkRealAuthStatus 抛异常: $e');
          authResult = {'authorized': false, 'hr_count': 0, 'bo_count': 0, 'sleep_count': 0, 'source': 'none'};
        }
        if (authResult['authorized'] == true) {
          await HealthService.markAuthorized();
          sticky = true;
        }
      }
    }

    final now = DateTime.now();
    final ts = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    if (!sticky) {
      _healthAuthorized = false;
      _healthAuthDiag = tr.s545(ts);
      debugPrint('[GuardianPage] _loadSafetyStatus → 未授权, diag=$_healthAuthDiag');
      if (mounted) setState(() {
        _safetySignal = null;
        _healthSummary = null;
      });
      return;
    }

    // 已授权（粘性恒定）：拉取实时体征用于安全信号展示；失败只影响信号，不推翻「守护中」
    _healthAuthorized = true;
    _autoAlertEnabled = prefs.getBool('safety_auto_alert_enabled') ?? true;
    try {
      final summary = await HealthService.getHealthSummary();
      if (!mounted) return;
      final hr = summary['heart_rate']?.toString() ?? '--';
      final bo = summary['blood_oxygen']?.toString() ?? '--';
      final signal = evaluateVitals(summary);
      _lastHealthSyncAt = DateTime.now().millisecondsSinceEpoch; // v1.97.3+169 同步时间反馈
      if (kDebugMode) {
        debugPrint('[GuardianPage] getHealthSummary 成功，summary keys: ${summary?.keys.toList()}');
      }
      if (mounted) setState(() {
        _healthSummary = summary;
        _safetySignal = signal;
        _healthAuthDiag = tr.s546(hr, bo, ts);
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[GuardianPage] 安全信号加载失败(不影响守护中状态): $e');
      if (mounted) setState(() {
        _healthAuthDiag = tr.s547(ts);
      });
    }
  }

  /// 【v1.97.4】手动重新检测健康授权（P0 守护卡修复②）
  /// 未授权时拉起 HealthKit 授权弹框（成功后内部 markAuthorized 写入粘性标记）；
  /// 已授权则直接重载。不再反复调用 checkRealAuthStatus 推翻状态。
  Future<void> _refreshHealthAuth() async {
    debugPrint('[GuardianPage] 手动重新检测健康授权 → 开始');
    final sticky = await HealthService.isAuthorized();
    if (!sticky) {
      debugPrint('[GuardianPage] 拉起 HealthKit 授权弹框');
      await HealthService.requestPermissions();
    }
    await _loadSafetyStatus();
    if (mounted) setState(() {});
    debugPrint('[GuardianPage] 手动重新检测健康授权 → 结束');
  }

  /// 【v1.97.3+166 双向视觉】计算「互相守护」用户集合：
  /// 同一人同时出现在「守护我的人」(userId) 与「我守护的人」(receiver_id) 中。
  void _recomputeMutual() {
    final guardianIds = _guardians
        .map((g) => g['userId']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    final guardedIds = _guardedByMe
        .map((p) => p['receiver_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    _mutualUserIds = guardianIds.intersection(guardedIds);
  }

  /// 【v1.97.3+166 双向视觉】互护优先排序：互相守护的排到列表最前（各自原相对顺序保持不变）
  List<Map<String, dynamic>> _sortByMutual(
      List<Map<String, dynamic>> list, String idKey) {
    final sorted = List<Map<String, dynamic>>.from(list);
    sorted.sort((a, b) {
      final am = _mutualUserIds.contains(a[idKey]?.toString() ?? '');
      final bm = _mutualUserIds.contains(b[idKey]?.toString() ?? '');
      if (am == bm) return 0;
      return am ? -1 : 1;
    });
    return sorted;
  }

  // 【v1.97.3+166 双向视觉】互护优先排序后的列表（getter，避免在外层 sliver 列表里声明变量）
  List<Map<String, dynamic>> get _sortedGuardians =>
      _sortByMutual(_guardians, 'userId');
  List<Map<String, dynamic>> get _sortedGuardedByMe =>
      _sortByMutual(_guardedByMe, 'receiver_id');

  /// 用「我守护的人」权威签到状态，强制同步「守护我的人」列表中同一 user 的显示状态
  void _finalSyncGuardianCheckInStatus() {
    if (_guardedByMeCheckedIn.isEmpty || _guardians.isEmpty) return;
    bool changed = false;
    final synced = _guardians.map((g) {
      final uid = g['userId']?.toString();
      if (uid != null &&
          uid.isNotEmpty &&
          _guardedByMeCheckedIn.containsKey(uid) &&
          g['checkedInToday'] != _guardedByMeCheckedIn[uid]) {
        changed = true;
        return {...g, 'checkedInToday': _guardedByMeCheckedIn[uid]};
      }
      return g;
    }).toList();
    if (changed && mounted) {
      setState(() {
        _guardians = synced;
      });
      _loadTodayFeed();
    }
  }

  /// 从本地缓存读取联系人列表
  Future<List<Map<String, dynamic>>> _loadContactsFromCache(
      SharedPreferences prefs, String contactsKey) async {
    final contactsJson = prefs.getString(contactsKey);
    if (contactsJson == null || contactsJson.isEmpty) return [];

    try {
      final decoded = jsonDecode(contactsJson);
      if (decoded is List) {
        final contacts = <Map<String, dynamic>>[];
        bool hasMigration = false;
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            // 【v1.93.1 修复】迁移旧关系"兄弟姐妹" → "家人"
            if (item['relation'] == tr.s307) {
              item['relation'] = tr.s299;
              hasMigration = true;
            }
            final name = (item['name'] ?? '').toString().trim();
            final phone = (item['phone'] ?? '').toString().trim();
            if (name.isNotEmpty && phone.isNotEmpty) contacts.add(item);
          } else if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            if (map['relation'] == tr.s307) {
              map['relation'] = tr.s299;
              hasMigration = true;
            }
            final name = (map['name'] ?? '').toString().trim();
            final phone = (map['phone'] ?? '').toString().trim();
            if (name.isNotEmpty && phone.isNotEmpty) contacts.add(map);
          }
        }
        // 迁移后持久化保存
        if (hasMigration) {
          await prefs.setString(contactsKey, jsonEncode(contacts));
          if (kDebugMode) debugPrint('[GuardianPage] ✅ 已迁移"兄弟姐妹"→"家人"并保存');
        }
        return contacts;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[GuardianPage] 本地缓存解析失败，尝试兼容模式: $e');
      return ContactParser.parse(contactsJson);
    }
    return [];
  }

  // ====== 社交互动功能 ======

  /// 打开社交页面
  void _openSocialPage({int tab = 0}) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? 'guest';
    String userName = tr.s320;
    final profileJson = prefs.getString('user_profile');
    if (profileJson != null) {
      try {
        final profile = jsonDecode(profileJson);
        userName = (profile['name'] as String?)?.isNotEmpty == true
            ? profile['name'] as String
            : tr.s320;
      } catch (_) {}
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          body: SocialPage(
            currentUserId: userId,
            currentUserName: userName,
          ),
        ),
      ),
    );
  }

  /// 构建社交快捷操作按钮
  Widget _buildSocialQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(ZaiNeRadius.small),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZaiNeRadius.small),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: ZaiNeSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: ZaiNeSpacing.xs),
              Text(
                label,
                style: TextStyle(
                  fontSize: ZaiNeFontSize.caption,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建三态状态标签
  Widget _buildStatusLabel(Map<String, dynamic> guardian) {
    final isRegistered = guardian['isRegistered'] == true;
    final isActive = guardian['isActive'] == true;
    final checkedInToday = guardian['checkedInToday'] == true;
    final statusError = guardian['statusError'] as String?;

    // 【修复】网络错误时显示灰色提示，避免误导性"未注册"
    if (statusError != null) {
      return Row(
        children: [
          Icon(Icons.help_outline, size: 10, color: Colors.grey[400]),
          const SizedBox(width: ZaiNeSpacing.xs),
          Text(statusError, style: TextStyle(fontSize: ZaiNeFontSize.micro, color: Colors.grey[400])),
        ],
      );
    }

    if (!isRegistered) {
      return Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.grey),
          ),
          const SizedBox(width: ZaiNeSpacing.xs),
          Text(tr.s384, style: TextStyle(fontSize: ZaiNeFontSize.micro, color: Colors.grey[500])),
        ],
      );
    }

    // 【v1.9.77】已注册但从未签到 → 待激活状态
    if (!isActive) {
      return Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey.shade400),
          ),
          const SizedBox(width: ZaiNeSpacing.xs),
          Text(tr.s369, style: TextStyle(fontSize: ZaiNeFontSize.micro, color: ZaiNeColors.textSecondary(), fontWeight: FontWeight.w500)),
        ],
      );
    }

    if (checkedInToday) {
      // 心情 emoji 映射（1-5）
      final moodEmoji = {
        1: '😢',  // 很差
        2: '😟',  // 不好
        3: '😐',  // 一般
        4: '😊',  // 不错
        5: '🥰',  // 非常好
      };
      final todayMood = guardian['todayMood'] as int? ?? 0;
      final emoji = moodEmoji[todayMood] ?? '';

      return Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green),
          ),
          const SizedBox(width: ZaiNeSpacing.xs),
          Text(tr.s548(emoji.isNotEmpty ? ' $emoji' : ''), style: TextStyle(fontSize: ZaiNeFontSize.micro, color: Colors.green.shade700, fontWeight: FontWeight.w500)),
        ],
      );
    }
    return Row(
      children: [
        Container(
          width: 8, height: 8,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.orange),
        ),
        const SizedBox(width: ZaiNeSpacing.xs),
        Text(tr.s370, style: TextStyle(fontSize: ZaiNeFontSize.micro, color: Colors.orange.shade700, fontWeight: FontWeight.w500)),
      ],
    );
  }

  /// 邀请未注册联系人注册
  /// 【修复 v1.9.77】创建免费守护卡，让对方注册后能互为守护人
  Future<void> _inviteToRegister(Map<String, dynamic> guardian) async {
    final phone = guardian['phone']?.toString() ?? '';
    final name = guardian['name']?.toString() ?? tr.s300;
    if (phone.isEmpty) return;

    // 先创建免费守护卡，并取回卡专属落地页链接（含 card_code）
    // 方式二（小人头邀请）必须带 card_code，打开后才是注册页；建卡失败则不应退到通用邀请页。
    String? shareUrl;
    String? failureReason;
    try {
      final freeRes = await CardService.createFreeCard(
        receiverPhone: phone,
        receiverName: name,
      );
      if (freeRes['success'] == true) {
        final su = freeRes['share_url']?.toString();
        if (su != null && su.isNotEmpty) shareUrl = su;
      } else {
        failureReason = freeRes['message']?.toString() ?? tr.s386;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[GuardianPage] 创建免费守护卡失败: $e');
      failureReason = tr.s387;
    }

    if (shareUrl == null || shareUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failureReason ?? tr.s388),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // 【修复 v1.16.0】统一使用 landing 页链接
    // ICP 备案已完成，引导接收者先看 H5 落地页，再决定是否下载
    // 注意：此函数没有 userId 变量，使用通用守护圈落地页
    // 【方案 C v1.95】邀请短信改用后端短链：长落地页 URL 在 iOS→安卓 MMS 跨段后会被吞掉，
    // 缩短为 zaine.love/s/{code} 后单条 SMS 必能识别为可点链接（邀请链接丢失问题根治）。
    // 【信任增强 v1.95.3】邀请短信带邀请人姓名 + 一句话说清是什么（独居安全App），
    // 让接收人第一眼认出是谁、明白干嘛、敢点链接。单条 SMS 段 ≤70 字（含短链）。
    // 短链 target 带 ?from=邀请人（URL 编码），供落地页顶部大字个性化显示"谁邀的你"。
    final safeName = name.length > 6 ? name.substring(0, 6) : name;
    // 短链 target 带 ?from=邀请人（落地页顶部大字个性化显示"谁邀的你"）。
    // 【v1.95.4 加固】短链接口异常时的兜底用「无 ?from= 的短落地页」，
    // 保证即使短链失败，短信仍是单段 SMS（≤70字）且带可点链接，
    // 避免回退长 URL → iOS→安卓转 MMS → 安卓网关把链接丢弃。
    // 【修复 2026-07-12】优先用卡专属落地页链接（含 card_code），
    // 对方注册即带卡号自动核销 + 单向绑定（免费卡仅单向；普通守护卡 is_free=0 才双向）。
    // 短链失败兜底必须退回「卡专属长链」(含注册页 /landing/{card_code})，
    // 绝不能退回通用邀请页 /landing/guardian_invite（无注册流程，会导致对方打开后看不到注册界面）。
    final inviteTarget = shareUrl; // shareUrl 已判空 return，此处必非空
    final inviteFallback = shareUrl; // 兜底 = 卡专属落地页（含注册流程）
    String inviteUrl = inviteTarget;
    try {
      final res = await ApiService.createShortLink(
        targetUrl: inviteTarget,
        linkType: 'invite',
      );
      final su = res['short_url']?.toString();
      if (su != null && su.trim().isNotEmpty) inviteUrl = su;
    } catch (e) {
      if (kDebugMode) debugPrint('[GuardianPage] 生成邀请短链失败，退回卡专属长链: $e');
      inviteUrl = inviteFallback;
    }
    final landingUrl = inviteUrl;

    final message = tr.s549(safeName, landingUrl);
    // 【修复 2026-07-12】Uri(queryParameters) 会把空格编码成「+」，iOS 短信可能原样显示成「+」号。
    // 统一把「+」还原为 %20，iOS 必能解码为空格，且不影响链接识别（链接本身无空格/+）。
    final smsUri = Uri(scheme: 'sms', path: phone, queryParameters: {'body': message});
    final smsUriFixed = Uri.parse(smsUri.toString().replaceAll('+', '%20'));
    if (await canLaunchUrl(smsUriFixed)) {
      await launchUrl(smsUriFixed);
      // 【v1.95.4 加固】短信打开后把带链接的完整文案复制到剪贴板，
      // 若对方（安卓）收不到可点链接，可手动粘贴补发，确保链接永不真正丢失。
      try {
        await Clipboard.setData(ClipboardData(text: message));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
              content: Text(tr.s390),
              duration: Duration(seconds: 4),
            ),
          );
        }
      } catch (_) {}
    }
  }

  /// 【v1.9.77】提醒待激活用户下载APP并签到
  Future<void> _remindToDownload(Map<String, dynamic> guardian) async {
    final userId = guardian['userId'] as int?;
    final name = guardian['name']?.toString() ?? 'TA';
    if (userId == null) return;

    try {
      final res = await NotifyService.remindDownload(userId);
      if (!mounted) return;
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr.s550(name)),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      } else {
        final error = res['error']?.toString() ?? '';
        final msg = res['message']?.toString() ?? tr.s392;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: error == 'RATE_LIMITED' ? Colors.orange : Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr.s551(e)),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZaiNeColors.scaffoldBg(),
      body: FutureBuilder<SharedPreferences>(
        future: SharedPreferences.getInstance(),
        builder: (context, snapshot) {
          final prefs = snapshot.data;
          return SafeArea(
            bottom: true,
            child: RefreshIndicator(
            onRefresh: () async {
              await _loadGuardians(isSilent: false);
              await _loadTodayFeed();
              // 模拟短暂延迟，让用户看到刷新动画
              await Future.delayed(const Duration(milliseconds: 500));
            },
            color: const Color(0xFF7C4DFF),
            backgroundColor: ZaiNeColors.cardBg(),
            child: CustomScrollView(
            slivers: [
              // ====== 紫色渐变头部 ======
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 52, 20, 28),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF7C4DFF),
                        Color(0xFF9C27B0),
                        Color(0xFFE040FB),
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text(
                        tr.s394,
                        style: TextStyle(
                          fontSize: ZaiNeFontSize.title,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: ZaiNeSpacing.sm),
                      Row(
                        children: [
                          if (_headerReady) ...[
                            Text(
                              _guardians.isNotEmpty
                                  ? tr.s552(_guardians.length)
                                  : tr.s396,
                              style: TextStyle(
                                fontSize: ZaiNeFontSize.caption,
                                color: Colors.white.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (_guardedByMe.isNotEmpty) ...[
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.sm),
                                width: 1,
                                height: 10,
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                              Text(
                                tr.s553(_guardedByMe.length),
                                style: TextStyle(
                                  fontSize: ZaiNeFontSize.caption,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            if (_mutualUserIds.isNotEmpty) ...[
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.sm),
                                width: 1,
                                height: 10,
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                              Text(
                                tr.s554(_mutualUserIds.length),
                                style: TextStyle(
                                  fontSize: ZaiNeFontSize.caption,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ] else
                            Text(
                              tr.s399,
                              style: TextStyle(
                                fontSize: ZaiNeFontSize.caption,
                                color: Colors.white.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: ZaiNeSpacing.xs),
                      Text(
                        _guardians.isNotEmpty
                            ? tr.s400
                            : tr.s401,
                        style: TextStyle(
                          fontSize: ZaiNeFontSize.caption,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: ZaiNeSpacing.lg),
                      // ====== 社交互动快捷入口（v1.0 隐藏）=====
                      if (FeatureFlags.enableSocial)
                        Row(
                        children: [
                          Expanded(
                            child: _buildSocialQuickAction(
                              icon: Icons.chat_bubble_outline,
                              label: tr.s402,
                              color: Colors.white,
                              onTap: () => _openSocialPage(),
                            ),
                          ),
                          const SizedBox(width: ZaiNeSpacing.md),
                          Expanded(
                            child: _buildSocialQuickAction(
                              icon: Icons.emoji_emotions_outlined,
                              label: tr.s403,
                              color: Colors.white,
                              onTap: () => _openSocialPage(tab: 1),
                            ),
                          ),
                          const SizedBox(width: ZaiNeSpacing.md),
                          Expanded(
                            child: _buildSocialQuickAction(
                              icon: Icons.emoji_events_outlined,
                              label: tr.s404,
                              color: Colors.white,
                              onTap: () => _openSocialPage(tab: 2),
                            ),
                          ),
                        ],
                      ),
                      // end FeatureFlags.enableSocial
                    ],
                  ),
                ),
              ),

              // ====== 发送守护卡引导卡片（醒目 CTA） ======
              // 【CN 合规】守护卡本身就是"facilitates 邀请建立守护关系"的传播机制，
              // CN 下从入口处隐藏（不渲染入口卡片）。
              if (!kIsChinaBuild)
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.xl),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const GuardianCardPage(),
                          ),
                        ).then((_) => _loadGuardians());
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.xl, vertical: ZaiNeSpacing.xl),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Color(0xFFFF6A88),
                              Color(0xFFFF9A8B),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(ZaiNeRadius.card),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6A88).withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // 左侧图标
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(ZaiNeRadius.card),
                              ),
                              child: const Icon(
                                Icons.card_giftcard,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: ZaiNeSpacing.lg),
                            // 中间文字
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                   Text(
                                    tr.s405,
                                    style: TextStyle(
                                      fontSize: ZaiNeFontSize.subtitle,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: ZaiNeSpacing.xs),
                                  Text(
                                    tr.s406,
                                    style: TextStyle(
                                      fontSize: ZaiNeFontSize.caption,
                                      color: Colors.white.withValues(alpha: 0.85),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // 右侧箭头
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.chevron_right,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ====== 统计卡片 ======
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.xl),
                    child: Container(
                      padding: const EdgeInsets.all(ZaiNeSpacing.lg),
                      decoration: BoxDecoration(
                        color: ZaiNeColors.cardBg(),
                        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Builder(builder: (context) {
                        // 【修复 v1.9.78】使用用户隔离 key，防止切换账号后数据污染
                        final uid = prefs?.getString('user_id') ?? '';
                        final totalKey = uid.isNotEmpty ? 'total_check_in_days_$uid' : 'total_check_in_days';
                        final lastDateKey = uid.isNotEmpty ? 'last_check_in_date_$uid' : 'last_check_in_date';
                        final isCheckedInToday = prefs?.getString(lastDateKey) ==
                            DateFormat('yyyy-MM-dd').format(DateTime.now());
                        return Row(
                          children: [
                            _buildStatItem(
                              icon: Icons.local_fire_department,
                              value: tr.s555(prefs != null ? StreakUtil.readStreak(prefs, uid) : 0),
                              label: tr.s408,
                              color: Colors.orange,
                              bgColor: Colors.orange.shade50,
                            ),
                            const SizedBox(width: ZaiNeSpacing.md),
                            _buildStatItem(
                              icon: isCheckedInToday ? Icons.check_circle : Icons.radio_button_unchecked,
                              value: isCheckedInToday ? tr.s409 : tr.s410,
                              label: tr.s411,
                              color: isCheckedInToday ? Colors.green : Colors.grey,
                              bgColor: isCheckedInToday ? Colors.green.shade50 : Colors.grey.shade100,
                            ),
                            const SizedBox(width: ZaiNeSpacing.md),
                            _buildStatItem(
                              icon: Icons.calendar_today,
                              value: tr.s556(prefs != null ? prefs.getInt(totalKey) ?? 0 : 0),
                              label: tr.s413,
                              color: Colors.blue,
                              bgColor: Colors.blue.shade50,
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ),

              // ====== 生命体征守护 状态引擎卡（v1.97.4 状态引擎上提）======
              _buildVitalSignsCard(),

              // ====== 二·今天时间流（v1.97.3+167 新增区块，本地聚合）======
              _buildTodayFeed(),

              const SliverToBoxAdapter(child: SizedBox(height: ZaiNeSpacing.xl)),

              // ====== 守护者列表 ======
              if (_guardians.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.xl),
                    child: Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: ZaiNeColors.cardBg(),
                        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.people_outline,
                              size: 48, color: Colors.grey[300]),
                          const SizedBox(height: ZaiNeSpacing.md),
                          Text(
                            tr.s414,
                            style: TextStyle(
                              fontSize: ZaiNeFontSize.body,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(height: ZaiNeSpacing.sm),
                          Text(
                            tr.s415,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: ZaiNeFontSize.caption,
                              color: Colors.grey[400],
                            ),
                          ),
                          const SizedBox(height: ZaiNeSpacing.lg),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ContactsPage(),
                                ),
                              ).then((_) => _loadGuardians());
                            },
                            icon: const Icon(Icons.person_add, size: 18),
                            label:  Text(tr.s416),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C4DFF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.xl, vertical: ZaiNeSpacing.md),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.xl),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final guardian = _sortedGuardians[index];
                        return _buildGuardianCard(guardian, index);
                      },
                      childCount: _sortedGuardians.length,
                    ),
                  ),
                ),

              // ====== 我守护的人（议题B：与「守护我的人」严格分区，无人数上限） ======
              _buildGuardedByMeSection(),

              // ====== 功能入口 ======
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Text(
                    tr.s417,
                    style: TextStyle(
                      fontSize: ZaiNeFontSize.body,
                      fontWeight: FontWeight.w700,
                      color: ZaiNeColors.textPrimary(),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(ZaiNeSpacing.section),
                  child: Column(
                    children: [
                      _buildFunctionEntry(
                        icon: Icons.person_add_rounded,
                        title: tr.s418,
                        subtitle: tr.s419,
                        color: ZaiNeColors.brandOrange,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const ContactsPage()),
                          ).then((_) => _loadGuardians());
                        },
                      ),
                      const SizedBox(height: ZaiNeSpacing.md),
                      _buildFunctionEntry(
                        icon: Icons.favorite_rounded,
                        title: tr.s367,
                        subtitle: _guardedByMe.isEmpty
                            ? tr.s420
                            : tr.s557(_guardedByMe.length),
                        color: _kGuardedBlue,
                        onTap: () => _showGuardedByMeManager(),
                      ),
                      const SizedBox(height: ZaiNeSpacing.md),
                      _buildFunctionEntry(
                        icon: Icons.check_circle_outline,
                        title: tr.s422,
                        subtitle: tr.s423,
                        color: Colors.green,
                        onTap: () {
                          _showPeaceConfirmation();
                        },
                      ),
                      const SizedBox(height: ZaiNeSpacing.md),
                      _buildFunctionEntry(
                        icon: Icons.help_outline,
                        title: tr.s424,
                        subtitle: tr.s425,
                        color: Colors.blue,
                        onTap: () {
                          _showGuardianInfo();
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: ZaiNeSpacing.xl)),
            ],
          ),
          ),
          );
        },
      ),
    );
  }

  /// 统计项（图标+数字+文字）
  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required Color bgColor,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: ZaiNeSpacing.sm),
          Text(
            value,
            style: const TextStyle(
              fontSize: ZaiNeFontSize.body,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: ZaiNeSpacing.xs),
          Text(
            label,
            style: TextStyle(
              fontSize: ZaiNeFontSize.micro,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  /// 生命体征守护 状态引擎卡（v1.97.4 状态引擎上提）
  /// 把产品真正引擎（安全信号）提到守护圈主页顶部，作为整页数据生产方与状态入口。
  /// 纯展示 + 导航，不触发外发；CN 版不显示自动外发相关文案。
  // ════════════════════════════════════════════════════════════
  // 【v1.97.3+167 今天时间流】本地聚合「今天圈内发生了什么」
  // ════════════════════════════════════════════════════════════

  /// 聚合今日事件（纯本地，不涉后端）：
  /// ① 我 今日签到（实时派生）② 守护者 今日签到（实时派生）
  /// ③ 体征异常预警（circle_events）④ 报平安（circle_events）
  Future<void> _loadTodayFeed() async {
    try {
      final items = <_FeedItem>[];

      // ① 我 今日签到
      // 【v1.97.3+169 修复】改用本地签到历史 checkin_history（与首页签到环同一真相源），
      // 原 CheckinDao.getToday() 依赖的 checkin_records 表在 App 内从未被写入，导致「我今日签到」永远为空。
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('user_id') ?? '';
      final history = prefs.getStringList(StreakUtil.historyKeyOf(uid)) ?? const <String>[];
      final todayStr = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
      final checkedInToday = history.any((d) {
        final parsed = DateTime.tryParse(d);
        if (parsed == null) return d == todayStr;
        final ds = '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
        return ds == todayStr;
      });
      if (checkedInToday) {
        items.add(_FeedItem(
          type: 'checkin_me',
          title: tr.s426,
          subtitle: tr.s427,
          ts: DateTime.now(),
          icon: Icons.check_circle_rounded,
          accent: const Color(0xFF4CAF50),
        ));
      }

      // ② 守护者 今日签到（依赖已加载的 _guardians 缓存）
      for (final g in _guardians) {
        if (g['checkedInToday'] != true) continue;
        final name = (g['name'] ?? tr.s374).toString();
        items.add(_FeedItem(
          type: 'checkin_guardian',
          title: tr.s558(name),
          subtitle: tr.s429,
          ts: _parseSigninTs(g['lastSigninAt']),
          icon: Icons.verified_user_rounded,
          accent: _kGuardedBlue,
        ));
      }

      // ③④ 体征异常 + 报平安（来自 circle_events 本地表）
      final events = await CircleEventDao.getToday();
      for (final ev in events) {
        if (ev.type == CircleEventType.vitalAnomaly) {
          items.add(_FeedItem(
            type: ev.type,
            title: ev.summary,
            subtitle: ev.detail,
            ts: DateTime.fromMillisecondsSinceEpoch(ev.ts),
            icon: Icons.warning_amber_rounded,
            accent: ZaiNeColors.danger(),
          ));
        } else if (ev.type == CircleEventType.peace) {
          items.add(_FeedItem(
            type: ev.type,
            title: ev.summary,
            subtitle: ev.detail,
            ts: DateTime.fromMillisecondsSinceEpoch(ev.ts),
            icon: Icons.favorite_rounded,
            accent: const Color(0xFFEC407A),
          ));
        }
      }

      items.sort((a, b) => b.ts.compareTo(a.ts));

      if (mounted) {
        setState(() {
          _todayFeed = items;
          _feedLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[GuardianPage] 加载今日事件流失败: $e');
      if (mounted) setState(() => _feedLoading = false);
    }
  }

  /// 解析守护者签到时间戳（服务端 last_signin_at 可能为 unix 秒/毫秒或 ISO 字符串）
  DateTime _parseSigninTs(dynamic raw) {
    if (raw == null) return DateTime.now();
    final s = raw.toString();
    if (s.isEmpty) return DateTime.now();
    final asInt = int.tryParse(s);
    if (asInt != null) {
      // 10 位=秒，13 位=毫秒
      return DateTime.fromMillisecondsSinceEpoch(asInt < 1e12 ? asInt * 1000 : asInt);
    }
    final parsed = DateTime.tryParse(s);
    if (parsed != null) return parsed;
    return DateTime.now();
  }

  /// 事件时间相对/绝对格式化
  String _formatFeedTime(DateTime ts) {
    final now = DateTime.now();
    final diff = now.difference(ts);
    if (diff.inMinutes < 1) return tr.s430;
    if (diff.inMinutes < 60) return tr.s559(diff.inMinutes);
    if (ts.year == now.year && ts.month == now.month && ts.day == now.day) {
      return DateFormat('HH:mm').format(ts);
    }
    return DateFormat('MM/dd HH:mm').format(ts);
  }

  /// 今天时间流区块（Sliver）
  Widget _buildTodayFeed() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
        decoration: BoxDecoration(
          color: ZaiNeColors.cardBg(),
          borderRadius: BorderRadius.circular(ZaiNeRadius.card),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C4DFF).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.timeline_rounded,
                        color: Color(0xFF7C4DFF), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(tr.s164,
                      style: TextStyle(
                          fontSize: ZaiNeFontSize.subtitle,
                          fontWeight: FontWeight.bold,
                          color: ZaiNeColors.textPrimary())),
                  const SizedBox(width: 6),
                  Text(tr.s432,
                      style: TextStyle(
                          fontSize: ZaiNeFontSize.caption,
                          color: ZaiNeColors.textSecondary())),
                ],
              ),
            ),
            // 【v1.97.3+175】删互护常驻 pin（顶部 banner 已显示"与 N 位互为守护"，重复）
            // 事件列表
            if (_feedLoading)
              _buildFeedLoading()
            else if (_todayFeed.isEmpty)
              _buildFeedEmpty()
            else
              for (final item in _todayFeed) _buildFeedRow(item),
            const SizedBox(height: ZaiNeSpacing.md),
          ],
        ),
      ),
    );
  }

  /// 单条事件行（微信对话列表风格）
  Widget _buildFeedRow(_FeedItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
              color: ZaiNeColors.dividerColor().withValues(alpha: 0.6)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: item.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: item.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: TextStyle(
                        fontSize: ZaiNeFontSize.body,
                        fontWeight: FontWeight.w600,
                        color: ZaiNeColors.textPrimary())),
                const SizedBox(height: 3),
                Text(item.subtitle,
                    style: TextStyle(
                        fontSize: ZaiNeFontSize.caption,
                        color: ZaiNeColors.textSecondary()),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(_formatFeedTime(item.ts),
              style: TextStyle(
                  fontSize: ZaiNeFontSize.micro,
                  color: ZaiNeColors.textHint())),
        ],
      ),
    );
  }

  Widget _buildFeedLoading() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: CircularProgressIndicator(
            strokeWidth: 2, color: Color(0xFF7C4DFF)),
      ),
    );
  }

  Widget _buildFeedEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
      child: Column(
        children: [
          Icon(Icons.auto_awesome_outlined,
              size: 32, color: Colors.grey),
          const SizedBox(height: ZaiNeSpacing.sm),
          Text(tr.s433,
              style: TextStyle(
                  fontSize: ZaiNeFontSize.body,
                  color: ZaiNeColors.textSecondary(),
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(tr.s434,
              style: TextStyle(
                  fontSize: ZaiNeFontSize.caption,
                  color: ZaiNeColors.textHint())),
        ],
      ),
    );
  }

  Widget _buildVitalSignsCard() {
    final signal = _safetySignal;
    final summary = _healthSummary;
    final authorized = _healthAuthorized;

    // 未授权：引导开启（点按进体征页，由体征页负责拉起授权，避免在守护圈被弹框）
    if (!authorized) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HealthOverviewPage()),
            ),
            child: Container(
              padding: const EdgeInsets.all(ZaiNeSpacing.lg),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(ZaiNeRadius.card),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.health_and_safety_outlined, color: Colors.grey[600], size: 22),
                  ),
                  const SizedBox(width: ZaiNeSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Text(tr.s435,
                            style: TextStyle(fontSize: ZaiNeFontSize.subtitle, fontWeight: FontWeight.w500)),
                        const SizedBox(height: ZaiNeSpacing.xs),
                         Text(tr.s436,
                            style: TextStyle(fontSize: ZaiNeFontSize.caption, color: Colors.grey)),
                        // 【v1.97.3+176 诊断】直接显示 HealthKit 检测结论，免开控制台
                        const SizedBox(height: ZaiNeSpacing.xs),
                        Text(tr.s560(_healthAuthDiag),
                            style: TextStyle(fontSize: ZaiNeFontSize.micro, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                  // 【v1.97.3+174②】手动重新检测授权按钮（逃离"已授权但 UI 待开启"死循环）
                  GestureDetector(
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      await _refreshHealthAuth();
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2EEFF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF7C4DFF)),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // 已授权但数据尚未返回：骨架占位（v1.97.3+169 强化状态文案）
    if (signal == null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Container(
            padding: const EdgeInsets.all(ZaiNeSpacing.lg),
            decoration: BoxDecoration(
              color: ZaiNeColors.cardBg(),
              borderRadius: BorderRadius.circular(ZaiNeRadius.card),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green)),
                ),
                 SizedBox(width: ZaiNeSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:  [
                      Text(tr.s438,
                          style: TextStyle(fontSize: ZaiNeFontSize.subtitle, fontWeight: FontWeight.w500)),
                      SizedBox(height: ZaiNeSpacing.xs),
                      Text(tr.s439,
                          style: TextStyle(fontSize: ZaiNeFontSize.caption, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 已授权且数据就绪：状态引擎卡
    final color = signal.color;
    final metrics = <Map<String, String>>[];
    if (summary != null) {
      final hr = summary['heart_rate'];
      if (hr != null) metrics.add({tr.s440: '$hr bpm'});
      final spo2 = summary['blood_oxygen'];
      if (spo2 != null) {
        final spo2v = spo2 is num ? spo2.round() : spo2;
        metrics.add({tr.s441: '$spo2v%'});
      }
      final sleepMin = summary['sleep_total'];
      if (sleepMin != null) {
        final mins = (sleepMin is num)
            ? sleepMin.toDouble()
            : double.tryParse(sleepMin.toString()) ?? 0;
        if (mins > 0) metrics.add({tr.s442: '${(mins / 60).toStringAsFixed(1)} h'});
      }
    }

    final isCN = AppConfig.isChinaRegion;
    final actionHint = isCN
        ? tr.s443
        : (_autoAlertEnabled
            ? tr.s444
            : tr.s445);

    // 【v1.97.3+169】同步时间反馈：根据最近一次体征同步时间显示「同步 X 分钟前」
    String syncHint = tr.s446;
    if (_lastHealthSyncAt > 0) {
      final diffMin = (DateTime.now().millisecondsSinceEpoch - _lastHealthSyncAt) ~/ 60000;
      if (diffMin < 1) {
        syncHint = tr.s446;
      } else if (diffMin < 60) {
        syncHint = tr.s561(diffMin);
      } else {
        final diffH = diffMin ~/ 60;
        syncHint = tr.s562(diffH);
      }
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
        child: GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const HealthOverviewPage()),
          ),
          child: Container(
            padding: const EdgeInsets.all(ZaiNeSpacing.lg),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(ZaiNeRadius.card),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(signal.icon, color: color, size: 22),
                    ),
                    const SizedBox(width: ZaiNeSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(signal.headline,
                                    style: TextStyle(
                                      fontSize: ZaiNeFontSize.subtitle,
                                      fontWeight: FontWeight.w500,
                                      color: ZaiNeColors.textPrimary(),
                                    )),
                              ),
                              const SizedBox(width: ZaiNeSpacing.sm),
                              // 守护中角标（绿色实心，强化已开启反馈）
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                                ),
                                child:  Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified_rounded, color: Colors.white, size: 12),
                                    SizedBox(width: 3),
                                    Text(tr.s449,
                                        style: TextStyle(
                                          fontSize: ZaiNeFontSize.micro,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        )),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: ZaiNeSpacing.xs),
                          Text(signal.detail,
                              style: TextStyle(
                                fontSize: ZaiNeFontSize.caption,
                                color: Colors.grey[600],
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
                if (metrics.isNotEmpty) ...[
                  const SizedBox(height: ZaiNeSpacing.md),
                  Row(
                    children: metrics
                        .map(
                          (m) => Expanded(
                            child: Container(
                              margin: const EdgeInsets.only(right: ZaiNeSpacing.sm),
                              padding: const EdgeInsets.symmetric(vertical: ZaiNeSpacing.sm),
                              decoration: BoxDecoration(
                                color: ZaiNeColors.cardBg(),
                                borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                              ),
                              child: Column(
                                children: [
                                  Text(m.values.first,
                                      style: const TextStyle(
                                        fontSize: ZaiNeFontSize.body,
                                        fontWeight: FontWeight.w500,
                                      )),
                                  const SizedBox(height: 2),
                                  Text(m.keys.first,
                                      style: TextStyle(
                                        fontSize: ZaiNeFontSize.micro,
                                        color: Colors.grey[500],
                                      )),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: ZaiNeSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(actionHint,
                          style: TextStyle(
                            fontSize: ZaiNeFontSize.micro,
                            color: color,
                            fontWeight: FontWeight.w500,
                          )),
                    ),
                    Text(syncHint,
                        style: TextStyle(
                          fontSize: ZaiNeFontSize.micro,
                          color: Colors.grey[500],
                        )),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 守护者卡片
  /// 【2026-07-12 议题B】「我守护的人」专区
  /// 与上方橙色「守护我的人」（紧急联系人，5/10 上限）严格区分：
  /// - 蓝色调（indigo/蓝）视觉独立，避免用户混淆两类方向相反的守护关系
  /// - 无人数上限，展示我发出的已绑定普通守护卡，并显示对方每日签到状态
  // ===== 「我守护的人」管理：备注名 + 重新邀请（无解除） =====
  String _guardedDisplayName(Map<String, dynamic> person) {
    final rid = person['receiver_id'];
    if (rid is int && _guardedRemarks[rid]?.isNotEmpty == true) {
      return _guardedRemarks[rid]!;
    }
    final nick = (person['nickname']?.toString() ?? '').trim();
    final recv = (person['receiver_name']?.toString() ?? '').trim();
    return nick.isNotEmpty ? nick : (recv.isNotEmpty ? recv : tr.s373);
  }

  Future<void> _editGuardedRemark(int receiverId, String remark) async {
    final prefs = await SharedPreferences.getInstance();
    if (remark.isEmpty) {
      await prefs.remove('guarded_by_me_remark_$receiverId');
      _guardedRemarks.remove(receiverId);
    } else {
      await prefs.setString('guarded_by_me_remark_$receiverId', remark);
      _guardedRemarks[receiverId] = remark;
    }
    if (mounted) setState(() {});
  }

  // 【复用现有提醒逻辑】待激活用户：复制走心文案 + 唤起微信，不新增独立机制
  Future<void> _reinviteGuarded(Map<String, dynamic> person) async {
    final name = _guardedDisplayName(person);
    final url = AppConstants.guardianInviteUrl;
    final message =
        tr.z0289(name) +
        tr.z0290 +
        tr.z0291(url);
    // 先关闭管理弹窗，避免遮挡 SnackBar
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    // 复制 + 打开微信（不可用时自动降级到系统分享面板）
    await copyAndOpenWeChat(context, message);
  }

  // 注：原「微信分享面板」重邀模式已移除 —— iOS 系统分享面板对纯文本亦拒收（"不支持的分享类型"），
  // 现统一走「复制链接发微信」(_reinviteGuarded)，与守护卡提醒TA 体验一致。

  void _showGuardedByMeManager() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _GuardedByMeManagerSheet(
        people: _guardedByMe,
        remarks: _guardedRemarks,
        displayName: _guardedDisplayName,
        avatarBuilder: (p) => _buildContactAvatar(
          {
            'avatarBase64': p['avatar_base64']?.toString() ?? '',
            'isActive': p['last_signin_at'] != null,
            'isRegistered': true,
            'name': _guardedDisplayName(p),
          },
          _kGuardedBlue,
        ),
        onEditRemark: _editGuardedRemark,
        onReinvite: kIsChinaBuild ? null : _reinviteGuarded,
      ),
    ).then((_) => _loadGuardians());
  }

  /// 【C4 方案C合并版】平安确认响应状态小标签
  /// status: 0=待确认(平安确认中) / 1=已确认(已报平安) / 2=需要帮助
  Widget _buildPeaceStatusChip(int status) {
    IconData icon;
    Color color;
    String label;
    if (status == 2) {
      icon = Icons.warning_amber_rounded;
      color = Colors.red;
      label = tr.z0904; // 需要帮助
    } else if (status == 1) {
      icon = Icons.verified_user_rounded;
      color = Colors.green;
      label = tr.z0909; // 已报平安
    } else {
      icon = Icons.hourglass_empty_rounded;
      color = const Color(0xFF757575); // grey 600
      label = tr.z0908; // 平安确认中
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: ZaiNeFontSize.micro,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuardedByMeSection() {
    final guardedColor = _kGuardedBlue; // 蓝：我守护的人
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 分区标题（带说明，强调与守护我的人不同）
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: guardedColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.volunteer_activism_rounded,
                      size: 18, color: guardedColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr.s367,
                        style: TextStyle(
                          fontSize: ZaiNeFontSize.body,
                          fontWeight: FontWeight.w700,
                          color: ZaiNeColors.textPrimary(),
                        ),
                      ),
                      Text(
                        tr.s450,
                        style: TextStyle(
                          fontSize: ZaiNeFontSize.micro,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                // 【v1.97.3+172】移除「N」数字徽标——subtitle 已表达方向，徽标多余
              ],
            ),
            const SizedBox(height: 12),
            // 列表
            if (_guardedByMe.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: ZaiNeColors.cardBg(),
                  borderRadius: BorderRadius.circular(ZaiNeRadius.card),
                ),
                child: Column(
                  children: [
                    Icon(Icons.favorite_outline, size: 32, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Text(
                      tr.s451,
                      style: TextStyle(
                        fontSize: ZaiNeFontSize.caption,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr.s452,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: ZaiNeFontSize.micro,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._sortedGuardedByMe.map((person) {
                final name = _guardedDisplayName(person);
                final checkedIn = person['checked_in_today'] == true;
                final isPending = person['last_signin_at'] == null; // 待激活：已注册但未登录 App
                final boundAt = person['bound_at']?.toString() ?? '';
                final rid = person['receiver_id']?.toString() ?? '';
                final isMutual = _mutualUserIds.contains(rid);
                // 【留言功能 v1】该被守护人「需要帮助」时附带的选填留言（有则展示）
                final peaceMsg = _peaceMessageByReceiver[rid];
                // 【C4】该被守护人对我发起的平安确认的响应状态（0待确认/1已确认/2需要帮助）
                final peaceStatus = _peaceStatusByReceiver[rid];
                return Container(
                  margin: const EdgeInsets.only(bottom: ZaiNeSpacing.cardXs),
                  padding: const EdgeInsets.all(ZaiNeSpacing.lg),
                  decoration: BoxDecoration(
                    color: ZaiNeColors.cardBg(),
                    borderRadius: BorderRadius.circular(ZaiNeRadius.card),
                    border: Border.all(
                      color: isMutual
                          ? const Color(0xFF1D9E75)
                          : guardedColor.withValues(alpha: 0.18),
                      width: isMutual ? 1.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // 头像（优先真实头像，否则首字；待激活加蒙版，复用 _buildContactAvatar）
                      _buildContactAvatar(
                        {
                          'avatarBase64': person['avatar_base64']?.toString() ?? '',
                          'isActive': person['last_signin_at'] != null,
                          'isRegistered': true,
                          'name': name,
                        },
                        guardedColor,
                      ),
                      const SizedBox(width: ZaiNeSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 【v1.97.3+175】双心紧贴姓名：名字 Flexible（不强制占满）双心紧跟；不再被推右
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: const TextStyle(
                                      fontSize: ZaiNeFontSize.body,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: ZaiNeSpacing.xs),
                                _buildMutualBadge(isMutual),
                                // 【方案A v1.97.1+160】chip 挪到名字行末尾，避免被 Row 末尾挤截
                                // 【方案三 v1.97.1+160】status=0（待确认/已处理归零）不渲染 chip，处理完更"安静"
                                if (peaceStatus != null && peaceStatus != 0) ...[
                                  const SizedBox(width: 8),
                                  _buildPeaceStatusChip(peaceStatus),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            // 状态行：仅签到态（chip 已挪走、boundAt 下移独立行）
                            Row(
                              children: [
                                Icon(
                                  isPending
                                      ? Icons.bedtime_outlined
                                      : (checkedIn
                                          ? Icons.check_circle_rounded
                                          : Icons.radio_button_unchecked_rounded),
                                  size: 14,
                                  color: isPending
                                      ? Colors.orange[500]
                                      : (checkedIn ? Colors.green : Colors.grey[400]),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isPending
                                      ? tr.s369
                                      : (checkedIn ? tr.signInButtonCheckedIn : tr.s370),
                                  style: TextStyle(
                                    fontSize: ZaiNeFontSize.micro,
                                    color: isPending
                                        ? Colors.orange[700]
                                        : (checkedIn ? Colors.green : Colors.grey[500]),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            // 绑定日期独立行（小字灰，避免与签到态挤一行）
                            if (boundAt.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                tr.s563(boundAt),
                                style: TextStyle(
                                  fontSize: ZaiNeFontSize.micro,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                            // 【留言功能 v1 + V2】任一状态下含留言/轻量状态均展示气泡（仅发送给守护者，合规）
                            // 需要帮助(status=2)用警示红；我没事/其他(status=1)用沉静蓝
                            if (peaceMsg != null && peaceMsg.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: peaceStatus == 2
                                      ? const Color(0xFFA32D2D).withValues(alpha: 0.08)
                                      : Colors.blue.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: peaceStatus == 2
                                        ? const Color(0xFFA32D2D).withValues(alpha: 0.18)
                                        : Colors.blue.withValues(alpha: 0.16),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      peaceStatus == 2 ? tr.z0917 : tr.z0924, // 留言 / 状态
                                      style: TextStyle(
                                        fontSize: ZaiNeFontSize.micro,
                                        fontWeight: FontWeight.w600,
                                        color: peaceStatus == 2
                                            ? const Color(0xFFA32D2D)
                                            : Colors.blue[700],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      peaceMsg,
                                      style: TextStyle(
                                        fontSize: ZaiNeFontSize.micro,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            // 【方案A v1.97.1+160】"请求报平安" 主按钮（向被守护人发起）
                            // 【方案三 v1.97.1+160】status=2（需要帮助）时前置「已联系」按钮，标记已处理归零
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Builder(builder: (context) {
                                final rid = person['receiver_id']?.toString() ?? '';
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (peaceStatus == 2) ...[
                                      GestureDetector(
                                        onTap: () => _acknowledgePeace(rid, name),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.check_circle_rounded,
                                                  size: 14, color: Colors.white),
                                              const SizedBox(width: 4),
                                              Text(
                                                tr.z0910, // 已联系
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    GestureDetector(
                                      onTap: () {
                                        HapticFeedback.mediumImpact();
                                        if (rid.isEmpty) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(tr.s471),
                                              backgroundColor: Colors.orange,
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                          return;
                                        }
                                        // 【方案A】直接从我守护的人卡片发起（receiver_id 即 userId）
                                        _doSendPeace(int.parse(rid), name);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF7C4DFF),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.favorite_border,
                                                size: 14, color: Colors.white),
                                            const SizedBox(width: 4),
                                            Text(
                                              tr.s456, // "平安" 文案（与原守护我的人胶囊同文案）
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  /// 【v1.97.3+166 双向视觉】互为守护徽标（无文字，仅双心图标+tooltip）
  /// 非互为守护返回空占位以保持布局稳定
  ///
  /// 【v1.97.3+173】图标换成"双心相扣"（A 候选）：两心错位重叠，左深紫右浅紫，
  /// 28×20 固定尺寸，配 Tooltip "互为守护"；不再用 handshake_rounded（语义偏商务握手）。
  /// 位置（173）：从状态行尾移到姓名行紧贴名字，状态行不再放这个徽标。
  Widget _buildMutualBadge(bool isMutual) {
    if (!isMutual) return const SizedBox.shrink();
    return Tooltip(
      message: tr.s454,
      child: SizedBox(
        width: 28,
        height: 18,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // 左心：深品牌紫，外移 -4 让出重叠空间
            Transform.translate(
              offset: const Offset(-4, 0),
              child: const Icon(
                Icons.favorite,
                size: 18,
                color: Color(0xFF7C4DFF),
              ),
            ),
            // 右心：浅紫 0.6 透，外移 +4 与左心错位形成"相扣"感
            Transform.translate(
              offset: const Offset(4, 0),
              child: Icon(
                Icons.favorite,
                size: 18,
                color: const Color(0xFFA78DFF).withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 【v1.97.3+171】次按钮：仅图标圆形（电话/消息），浅紫底+0.5px 紫描边
  Widget _buildIconOnlyButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF7C4DFF).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF7C4DFF).withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF7C4DFF)),
        ),
      ),
    );
  }

  // 【v1.97.3+171】主按钮：实心紫胶囊（图+2字），用于平安/提醒/邀请
  Widget _buildPrimaryActionPill({
    required IconData icon,
    required String label,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          // 【v1.97.3+175】缩窄缩矮：height 32→30、padding 12→8、icon 14→13、spacing 5→4、字号 12→11、radius 16→15
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF7C4DFF),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuardianCard(Map<String, dynamic> guardian, int index) {
    final colors = [
      ZaiNeColors.brandOrange,
      const Color(0xFF7C4DFF),
      Colors.teal,
      Colors.blue,
    ];
    final accentColor = colors[index % colors.length];
    final isMutual = _mutualUserIds.contains(guardian['userId']?.toString() ?? '');

    return GestureDetector(
      onLongPress: () => _showRemoveGuardianDialog(guardian),
      child: Container(
        margin: const EdgeInsets.only(bottom: ZaiNeSpacing.cardXs),
        padding: const EdgeInsets.all(ZaiNeSpacing.lg),
        decoration: BoxDecoration(
          color: ZaiNeColors.cardBg(),
          borderRadius: BorderRadius.circular(ZaiNeRadius.card),
          border: isMutual
              ? Border.all(color: const Color(0xFF1D9E75), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // 头像
            ClipOval(
              child: _buildContactAvatar(guardian, accentColor),
            ),
            const SizedBox(width: ZaiNeSpacing.lg),
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 【v1.93.5 修复】Row 布局加 overflow 保护 + relation 空字符串兜底
                  // 【v1.97.3+169 修复】互护徽标移出名字行，避免挤压名字导致互护 item 名字不可见
                  // 【v1.97.3+173】互护徽标改回"姓名右侧"（紧贴名字），双心相扣图标
                  // 【v1.97.3+174】删关系 chip（添加时已选，冗余）
                  // 【v1.97.3+175】双心紧贴姓名：名字改 Flexible，双心不再被操作列推右
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          guardian['name'] ?? tr.s373,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: ZaiNeFontSize.body,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: ZaiNeSpacing.xs),
                      _buildMutualBadge(isMutual), // 28×18 双心图，isMutual=false 返回 SizedBox.shrink 不挤压
                    ],
                  ),
                  const SizedBox(height: ZaiNeSpacing.xs),
                  // 【v1.97.3+173】互护徽标已挪到名字行，状态行只剩状态标签、不再 spaceBetween
                  // 状态标签占满，padding 用 padding-left 视觉对齐
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(child: _buildStatusLabel(guardian)),
                    ],
                  ),
                ],
              ),
            ),
            // 【v1.97.3+171 操作列】电话/消息 次按钮（仅图标圆形）
            // 【方案A v1.97.1+160】移除多态胶囊：平安/提醒/邀请动作统一迁到「我守护的人」卡片
            //   原因：原设计按钮在「守护我的人」但响应 chip 在「我守护的人」，错位
            //   「守护我的人」= 别人主动守护我，保留电话/短信即可，不需要我主动发请求
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildIconOnlyButton(
                  icon: Icons.phone,
                  tooltip: tr.s455,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _callGuardian((guardian['name'] ?? tr.s374).toString(),
                        (guardian['phone'] ?? '').toString());
                  },
                ),
                const SizedBox(width: 6),
                _buildIconOnlyButton(
                  icon: Icons.sms,
                  tooltip: tr.s331,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _sendSMSToGuardian((guardian['name'] ?? tr.s374).toString(),
                        (guardian['phone'] ?? '').toString());
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 功能入口
  Widget _buildFunctionEntry({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(ZaiNeSpacing.lg),
        decoration: BoxDecoration(
          color: ZaiNeColors.cardBg(),
          borderRadius: BorderRadius.circular(ZaiNeRadius.card),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(ZaiNeRadius.small),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: ZaiNeSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: ZaiNeFontSize.body,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: ZaiNeSpacing.xs),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: ZaiNeFontSize.caption,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[300], size: 20),
          ],
        ),
      ),
    );
  }

  /// 拨打守护者电话
  Future<void> _callGuardian(String name, String phone) async {
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
          content: Text(tr.s462),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.card)),
        title: Row(
          children: [
            const Icon(Icons.phone, color: ZaiNeColors.brandOrange),
            const SizedBox(width: ZaiNeSpacing.sm),
            Expanded(
              child: Text(tr.s564(name)),
            ),
          ],
        ),
        content: Text(tr.s565(_maskPhone(phone))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:  Text(tr.s016),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: ZaiNeColors.brandOrange),
            child:  Text(tr.s465),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        final uri = Uri(scheme: 'tel', path: phone);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
              content: Text(tr.s466),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr.s566(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// 发送短信给守护者（长按触发）
  Future<void> _sendSMSToGuardian(String name, String phone) async {
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
          content: Text(tr.s462),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    try {
      final uri = Uri(scheme: 'sms', path: phone);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {
      // 短信功能不可用时静默忽略
    }
  }

  /// 【P2】请求平安确认弹窗
  void _showRequestPeaceDialog(Map<String, dynamic> guardian) {
    final name = guardian['name'] ?? tr.s374;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.card)),
        title: Row(
          children: [
            Icon(Icons.favorite_border, color: Colors.blue.shade600),
            const SizedBox(width: ZaiNeSpacing.sm),
            Expanded(
              child: Text(tr.s567(name)),
            ),
          ],
        ),
        content: Text(
          tr.s568(name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:  Text(tr.s016),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _sendPeaceRequest(guardian);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
            ),
            child:  Text(tr.s470),
          ),
        ],
      ),
    );
  }

  /// 发送平安确认请求
  Future<void> _sendPeaceRequest(Map<String, dynamic> guardian) async {
    final phone = guardian['phone']?.toString() ?? '';
    final name = guardian['name']?.toString() ?? tr.s374;
    final userId = guardian['userId'] as int?;

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
          content: Text(tr.s471),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 如果已经加载数据时查到了userId，直接使用
    if (userId != null) {
      await _doSendPeace(userId, name);
      return;
    }

    // 兜底：通过手机号查询
    try {
      final lookupRes = await UserService.lookupByPhone(phone);
      if (lookupRes['success'] != true || lookupRes['found'] != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr.s569(name)),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      final foundUserId = lookupRes['user_id'] as int;
      await _doSendPeace(foundUserId, name);
    } catch (e) {
      if (kDebugMode) debugPrint('[GuardianPage] 平安确认失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
            content: Text(tr.s473),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    _loadTodayFeed();
  }

  /// 【C4 方案C合并版】拉取「我守护的人」对平安确认的响应状态
  /// 调用 /api/peace/sent，按 user_id 取每人最新一条请求的 status：
  /// 0=待确认(平安确认中) / 1=已确认(已报平安) / 2=需要帮助
  Future<void> _loadPeaceStatus() async {
    try {
      final res = await PeaceService.getSentRequests();
      if (res['success'] != true) return;
      final list = res['requests'];
      if (list is! List) return;
      final Map<String, int> map = {};
      final Map<String, int> reqMap = {};
      final Map<String, String> msgMap = {};
      // get_sent 已按 requested_at desc，故同一 user 取最先遇到（最新）的状态
      for (final item in list) {
        if (item is! Map) continue;
        final uid = item['user_id']?.toString();
        final st = item['status'];
        if (uid == null || st is! int) continue;
        map.putIfAbsent(uid, () => st);
        // 【方案三】记录最新一条的 request_id（已联系按钮用）
        final rid = item['request_id'];
        if (rid is int) {
          reqMap.putIfAbsent(uid, () => rid);
        }
        // 【留言功能 v1】记录最新一条的留言（仅 status=2 且有内容时展示）
        final msg = item['message'];
        if (msg != null && msg.toString().isNotEmpty) {
          msgMap.putIfAbsent(uid, () => msg.toString());
        }
      }
      if (!mounted) return;
      setState(() {
        _peaceStatusByReceiver = map;
        _peaceRequestIdByReceiver = reqMap;
        _peaceMessageByReceiver = msgMap;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[GuardianPage] 平安确认响应状态加载失败(忽略): $e');
    }
  }

  /// 【方案三】守护者标记"需要帮助"为已处理（status 2 → 0 归零）
  Future<void> _acknowledgePeace(String rid, String name) async {
    final requestId = _peaceRequestIdByReceiver[rid];
    if (requestId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr.z0911),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    try {
      final res = await PeaceService.acknowledgePeace(requestId);
      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr.z0912),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        // 归零后立即刷新，chip 从「需要帮助」恢复
        unawaited(_loadPeaceStatus());
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr.z0913),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[GuardianPage] 标记已处理失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr.z0913),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// 执行平安确认API调用
  Future<void> _doSendPeace(int targetUserId, String name) async {
    try {
      final peaceRes = await PeaceService.requestPeace(targetUserId);
      if (peaceRes['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr.s570(name)),
              backgroundColor: Colors.blue,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        // 【C4】发送成功后立即刷新响应状态，让卡片即时显示「平安确认中」
        unawaited(_loadPeaceStatus());
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr.s571(peaceRes['error'] ?? '请稍后重试')),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[GuardianPage] 平安确认API异常: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
            content: Text(tr.s473),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// 手机号脱敏
  String _maskPhone(String phone) {
    if (phone.length == 11) {
      return '${phone.substring(0, 3)}****${phone.substring(7)}';
    }
    return phone;
  }

  /// 【新增】解除守护关系确认弹窗
  void _showRemoveGuardianDialog(Map<String, dynamic> guardian) {
    final name = guardian['name'] ?? tr.s374;
    final phone = guardian['phone'] ?? '';
    final isRegistered = guardian['isRegistered'] == true;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.card)),
        title:  Row(
          children: [
            Icon(Icons.person_remove_outlined, color: Colors.red),
            SizedBox(width: ZaiNeSpacing.sm),
            Text(tr.s476),
          ],
        ),
        content: Text(
          (isRegistered ? tr.s572(name, phone) : tr.s573(name, phone)) +
              // 【CN合规】明示"随时退出、退出即停"，无需对方同意
              // （《个人信息保护法》：个人撤回同意应当便捷，且不得设置不合理条件）
              (kIsChinaBuild ? '\n\n解除后，您与对方的信息共享将立即停止，无需对方同意。' : ''),
         ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:  Text(tr.s016),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _removeGuardian(guardian);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child:  Text(tr.s479),
          ),
        ],
      ),
    );
  }

  /// 执行解除守护关系
  Future<void> _removeGuardian(Map<String, dynamic> guardian) async {
    try {
      // 1. 获取联系人 ID
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';
      final contactsKey = userId.isNotEmpty ? 'emergency_contacts_$userId' : 'emergency_contacts';
      final contactsJson = prefs.getString(contactsKey) ?? '[]';
      final List<dynamic> contacts = jsonDecode(contactsJson);
      
      String? contactId;
      for (var c in contacts) {
        if (c['phone'] == guardian['phone']) {
          contactId = c['id']?.toString();
          break;
        }
      }

      if (contactId == null) {
        throw Exception(tr.s480);
      }

      // 2. 调用后端接口删除
      final res = await ContactService.deleteContact(contactId);
      if (res['success'] == true) {
        // 【修复 v1.19.1】清理该守护者的本地缓存（防止重新添加时读到旧数据）
        final phone = guardian['phone']?.toString() ?? '';
        if (phone.isNotEmpty) {
          await prefs.remove('contact_is_registered_phone_$phone');
          await prefs.remove('contact_user_id_phone_$phone');
          await prefs.remove('contact_avatar_phone_$phone');
          await prefs.remove('contact_checked_in_today_phone_$phone');
          await prefs.remove('contact_last_signin_at_phone_$phone');
          if (kDebugMode) debugPrint('[GuardianPage] 已清理 $phone 的本地缓存');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr.s574(guardian['name'])), backgroundColor: Colors.blue),
          );
          _loadGuardians(isSilent: false);
        }
      } else {
        throw Exception(res['message'] ?? tr.s482);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr.s575(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// 守护圈说明弹窗
  void _showGuardianInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.card)),
        title:  Row(
          children: [
            Icon(Icons.shield, color: Color(0xFF7C4DFF)),
            SizedBox(width: ZaiNeSpacing.sm),
            Text(tr.s424),
          ],
        ),
        content:  Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr.s484),
            SizedBox(height: ZaiNeSpacing.sm),
            Text(tr.s485),
            SizedBox(height: ZaiNeSpacing.xs),
            Text(tr.s486),
            SizedBox(height: ZaiNeSpacing.xs),
            Text(tr.s487),
            SizedBox(height: ZaiNeSpacing.xs),
            Text(tr.s488),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:  Text(tr.s489),
          ),
        ],
      ),
    );
  }

  /// 平安确认弹窗（真正打开短信界面发送）
  void _showPeaceConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.card)),
        title:  Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: ZaiNeSpacing.sm),
            Text(tr.s422),
          ],
        ),
        content:  Text(
          tr.s490,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:  Text(tr.s016),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _sendPeaceMessageToAll();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child:  Text(tr.s491),
          ),
        ],
      ),
    );
  }

  /// 向所有守护者发送平安消息（通过系统短信界面）
  Future<void> _sendPeaceMessageToAll() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    final contactsKey = (userId != null && userId.isNotEmpty)
        ? 'emergency_contacts_$userId'
        : 'emergency_contacts';
    final contactsJson = prefs.getString(contactsKey);
    if (contactsJson == null || contactsJson.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar( SnackBar(
        content: Text(tr.s492),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    // 解析联系人列表
    List<Map<String, dynamic>> contacts = [];
    try {
      contacts = List<Map<String, dynamic>>.from(
          // 兼容两种格式：标准JSON和自定义格式
          contactsJson.startsWith('[')
              ? jsonDecode(contactsJson)
              : ContactParser.parse(contactsJson),
      );
    } catch (_) {}

    if (contacts.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar( SnackBar(
        content: Text(tr.s493),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    // 取第一个有电话的守护者打开短信
    String? firstPhone;
    for (final c in contacts) {
      if ((c['phone'] ?? '').toString().isNotEmpty) {
        firstPhone = c['phone'].toString();
        break;
      }
    }

    if (firstPhone == null || !mounted) return;

    // 读取用户姓名用于短信内容
    String senderName = tr.s320;
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString('user_profile');
      if (profileJson != null) {
        final profile = jsonDecode(profileJson);
        senderName = (profile['name'] as String?)?.isNotEmpty == true ? profile['name'] as String : tr.s320;
      }
    } catch (_) {}

    try {
      final uri = Uri(
        scheme: 'sms',
        path: firstPhone,
        queryParameters: {'body': tr.s576(senderName)},
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        // 【v1.97.3+167 今天时间流】报平安落本地事件表（仅记录，不影响短信发送流程）
        try {
          await CircleEventDao.insert(CircleEvent(
            type: CircleEventType.peace,
            actor: 'me',
            summary: tr.s495,
            detail: tr.s577(contacts.length),
            ts: DateTime.now().millisecondsSinceEpoch,
          ));
        } catch (logErr) {
          if (kDebugMode) debugPrint('[GuardianPage] 写报平安事件失败(忽略): $logErr');
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr.s578(contacts.length)),
          backgroundColor: Colors.teal,
          behavior: SnackBarBehavior.floating,
        ));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar( SnackBar(
          content: Text(tr.s498),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr.s579(e)),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  /// 构建联系人头像（有缓存头像时显示图片，否则显示首字母渐变圆）
  /// 【v1.9.77】待激活用户头像加灰色蒙版
  Widget _buildContactAvatar(Map<String, dynamic> guardian, Color accentColor) {
    String avatarBase64 = guardian['avatarBase64']?.toString() ?? '';
    final isActive = guardian['isActive'] == true;
    Widget avatar;

    if (avatarBase64.isNotEmpty) {
      try {
        // 【修复】去掉 data:image/xxx;base64, 前缀后再解码
        if (avatarBase64.contains(',')) {
          avatarBase64 = avatarBase64.split(',').last;
        }
        // 【修复 v1.9.78】清理 base64 中的空白字符（换行符、空格、制表符等）
        // 根因：后端 Text 字段存储的 base64 可能包含换行符，Dart base64Decode 对空白字符敏感
        avatarBase64 = avatarBase64.replaceAll(RegExp(r'\s'), '');
        final bytes = base64Decode(avatarBase64);
        if (kDebugMode) debugPrint('[GuardianPage] 头像解码成功: ${guardian['name']}, bytes=${bytes.length}');
        avatar = SizedBox(
          width: 48,
          height: 48,
          child: ClipOval(
            child: Image.memory(
              bytes,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                if (kDebugMode) debugPrint('[GuardianPage] Image.memory 加载失败: ${guardian['name']}');
                return _buildInitialAvatar(guardian, accentColor);
              },
            ),
          ),
        );
      } catch (e) {
        if (kDebugMode) debugPrint('[GuardianPage] 头像解码失败: ${guardian['name']}, error=$e, raw_len=${guardian['avatarBase64']?.toString().length ?? 0}');
        avatar = _buildInitialAvatar(guardian, accentColor);
      }
    } else {
      avatar = _buildInitialAvatar(guardian, accentColor);
    }

    // 待激活用户：头像外罩灰色半透明层
    if (!isActive && guardian['isRegistered'] == true) {
      return Stack(
        alignment: Alignment.center,
        children: [
          avatar,
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bedtime_outlined,
              size: 18,
              color: Colors.white70,
            ),
          ),
        ],
      );
    }
    return avatar;
  }

  /// 首字母渐变圆（无头像时的降级显示）
  Widget _buildInitialAvatar(Map<String, dynamic> guardian, Color accentColor) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accentColor.withValues(alpha: 0.2), accentColor.withValues(alpha: 0.1)],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          (guardian['name'] ?? tr.s373).toString().substring(0, 1),
          style: TextStyle(
            fontSize: ZaiNeFontSize.title,
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ),
      ),
    );
  }

}
