import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
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

class GuardianPage extends StatefulWidget {
  const GuardianPage({super.key});

  @override
  State<GuardianPage> createState() => _GuardianPageState();
}

class _GuardianPageState extends State<GuardianPage> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _guardians = [];
  int _totalRegistered = 0; // 新增：已注册的守护成员数
  Timer? _refreshTimer; // 定期刷新定时器

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadGuardians();
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
    }
  }

  Future<void> _loadGuardians({bool isSilent = false}) async {
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
        final name = (c['name'] ?? '未命名').toString();
        final phone = (c['phone'] ?? '').toString();
        final relation = (c['relation'] == null || c['relation'].toString().isEmpty) ? '守护者' : c['relation'].toString();

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
        _guardians = initialGuardians;
      });
    }

    // 第2步：后台异步从后端拉取最新联系人列表
    try {
      // 并行加载联系人列表和邀请统计
      final results = await Future.wait([
        ContactService.getContacts(),
        CardService.getInviteStats(),
      ]);

      final res = results[0];
      final statsRes = results[1];

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
        if (mounted) {
          setState(() {
            _totalRegistered = (statsRes['total_registered'] as int?) ?? 0;
          });
        }
        if (kDebugMode) debugPrint('[GuardianPage] ✅ 获取邀请统计: total_registered=$_totalRegistered');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[GuardianPage] ⚠️ 后端拉取失败: $e');
    }

    if (!mounted || contacts.isEmpty) {
      return;
    }

    // 第3步：批量查询所有联系人的状态（v2.0 性能优化，消除 N+1 请求）
    try {
      final List<String> phones = contacts.map((c) => (c['phone'] ?? '').toString()).toList();
      final batchRes = await UserService.batchLookup(phones);
      
      if (batchRes['success'] == true && batchRes['results'] != null) {
        final Map<String, dynamic> resultsMap = batchRes['results'];
        final updatedGuardians = <Map<String, dynamic>>[];
        for (final c in contacts) {
          final phone = (c['phone'] ?? '').toString();
          final name = (c['name'] ?? '未命名').toString();
          final relation = (c['relation'] == null || c['relation'].toString().isEmpty) ? '守护者' : c['relation'].toString();

      final status = resultsMap[phone];
      if (status != null && status['found'] == true) {
        // 【已注册】原逻辑保持不变
        final foundUserId = status['user_id'] as int?;
        final avatarBase64 = status['avatar_base64']?.toString() ?? '';
        final lastSigninAt = status['last_signin_at']?.toString() ?? '';
        final checkedInToday = status['checked_in_today'] == true;
        final todayMood = status['today_mood'] as int?;  // 1-5，null 表示未签到

        if (avatarBase64.isNotEmpty && foundUserId != null) {
          await prefs.setString('contact_avatar_$foundUserId', avatarBase64);
          await prefs.setString('contact_avatar_phone_$phone', avatarBase64);
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
        return;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[GuardianPage] 批量状态查询异常: $e');
    }

    // 兜底方案：如果批量查询失败，使用原有的并行单点查询逻辑（保持鲁棒性）
    // 第4步：并行查询所有联系人的注册状态 + 签到状态
    final statusFutures = contacts.map((c) async {
      final name = (c['name'] ?? '未命名').toString();
      final phone = (c['phone'] ?? '').toString();
      final relation = (c['relation'] ?? '守护者').toString();
      bool isRegistered = false;
      int? foundUserId;
      bool checkedInToday = false;
      bool isActive = false;
      String? statusError;
      String? avatarBase64;
      String? lastSigninAt;

      try {
        final lookupRes = await UserService.lookupByPhone(phone);
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
          statusError = '网络异常';
        }
      } catch (e) {
        statusError = '查询失败';
        if (kDebugMode) debugPrint('[GuardianPage] lookupByPhone($phone) 异常: $e');
      }

      if (isRegistered && foundUserId != null) {
        try {
          final checkinRes = await UserService.queryCheckinStatus(foundUserId);
          if (checkinRes['success'] == true) {
            checkedInToday = checkinRes['checked_in_today'] == true;
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
        _guardians = results;
      });
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
            if (item['relation'] == '兄弟姐妹') {
              item['relation'] = '家人';
              hasMigration = true;
            }
            final name = (item['name'] ?? '').toString().trim();
            final phone = (item['phone'] ?? '').toString().trim();
            if (name.isNotEmpty && phone.isNotEmpty) contacts.add(item);
          } else if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            if (map['relation'] == '兄弟姐妹') {
              map['relation'] = '家人';
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
    String userName = '我';
    final profileJson = prefs.getString('user_profile');
    if (profileJson != null) {
      try {
        final profile = jsonDecode(profileJson);
        userName = (profile['name'] as String?)?.isNotEmpty == true
            ? profile['name'] as String
            : '我';
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
          Text('未注册', style: TextStyle(fontSize: ZaiNeFontSize.micro, color: Colors.grey[500])),
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
          Text('待激活', style: TextStyle(fontSize: ZaiNeFontSize.micro, color: ZaiNeColors.textSecondary(), fontWeight: FontWeight.w500)),
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
          Text('今日已签到${emoji.isNotEmpty ? ' $emoji' : ''}', style: TextStyle(fontSize: ZaiNeFontSize.micro, color: Colors.green.shade700, fontWeight: FontWeight.w500)),
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
        Text('今日未签到', style: TextStyle(fontSize: ZaiNeFontSize.micro, color: Colors.orange.shade700, fontWeight: FontWeight.w500)),
      ],
    );
  }

  /// 邀请未注册联系人注册
  /// 【修复 v1.9.77】创建免费守护卡，让对方注册后能互为守护人
  Future<void> _inviteToRegister(Map<String, dynamic> guardian) async {
    final phone = guardian['phone']?.toString() ?? '';
    final name = guardian['name']?.toString() ?? '朋友';
    if (phone.isEmpty) return;

    // 先创建免费守护卡
    try {
      await CardService.createFreeCard(
        receiverPhone: phone,
        receiverName: name,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[GuardianPage] 创建免费守护卡失败: $e');
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
    final inviteTarget = '${AppConstants.guardianInviteUrl}?from=${Uri.encodeComponent(safeName)}';
    final inviteFallback = AppConstants.guardianInviteUrl;
    String inviteUrl = inviteTarget;
    try {
      final res = await ApiService.createShortLink(
        targetUrl: inviteTarget,
        linkType: 'invite',
      );
      final su = res['short_url']?.toString();
      if (su != null && su.trim().isNotEmpty) inviteUrl = su;
    } catch (e) {
      if (kDebugMode) debugPrint('[GuardianPage] 生成邀请短链失败，使用短落地页兜底: $e');
      inviteUrl = inviteFallback;
    }
    final landingUrl = inviteUrl;

    final message = '【在呢】$safeName 邀请你加入我们的互助守护圈 🛡️ 我们都是独居青年，每天在 App 里互相报个平安。点下方链接下载，一起守护彼此的安全： $landingUrl';
    final uri = Uri(scheme: 'sms', path: phone, queryParameters: {'body': message});
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      // 【v1.95.4 加固】短信打开后把带链接的完整文案复制到剪贴板，
      // 若对方（安卓）收不到可点链接，可手动粘贴补发，确保链接永不真正丢失。
      try {
        await Clipboard.setData(ClipboardData(text: message));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('短信已打开，完整链接已复制。若对方收不到链接可长按粘贴补发'),
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
          content: Text('已提醒 $name 下载并签到 ✅'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      } else {
        final error = res['error']?.toString() ?? '';
        final msg = res['message']?.toString() ?? '提醒失败';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: error == 'RATE_LIMITED' ? Colors.orange : Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('提醒发送失败: $e'),
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
                      const Text(
                        '我的守护圈',
                        style: TextStyle(
                          fontSize: ZaiNeFontSize.title,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: ZaiNeSpacing.sm),
                      Row(
                        children: [
                          Text(
                            _guardians.isNotEmpty
                                ? '${_guardians.length} 位守护者'
                                : '暂无守护者',
                            style: TextStyle(
                              fontSize: ZaiNeFontSize.caption,
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (_totalRegistered > 0) ...[
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.sm),
                              width: 1,
                              height: 10,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            Text(
                              '已成功守护 $_totalRegistered 位朋友',
                              style: TextStyle(
                                fontSize: ZaiNeFontSize.caption,
                                color: Colors.white.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: ZaiNeSpacing.xs),
                      Text(
                        _guardians.isNotEmpty
                            ? '紧急联系人自动成为你的守护者'
                            : '添加紧急联系人，让他们守护你',
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
                              label: '消息',
                              color: Colors.white,
                              onTap: () => _openSocialPage(),
                            ),
                          ),
                          const SizedBox(width: ZaiNeSpacing.md),
                          Expanded(
                            child: _buildSocialQuickAction(
                              icon: Icons.emoji_emotions_outlined,
                              label: '表情',
                              color: Colors.white,
                              onTap: () => _openSocialPage(tab: 1),
                            ),
                          ),
                          const SizedBox(width: ZaiNeSpacing.md),
                          Expanded(
                            child: _buildSocialQuickAction(
                              icon: Icons.emoji_events_outlined,
                              label: '成就',
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
                                  const Text(
                                    '💌 发送守护卡',
                                    style: TextStyle(
                                      fontSize: ZaiNeFontSize.subtitle,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: ZaiNeSpacing.xs),
                                  Text(
                                    '邀请在乎的人，让他们也受到保护',
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
                        final streakKey = uid.isNotEmpty ? 'continuous_days_$uid' : 'continuous_days';
                        final totalKey = uid.isNotEmpty ? 'total_check_in_days_$uid' : 'total_check_in_days';
                        final lastDateKey = uid.isNotEmpty ? 'last_check_in_date_$uid' : 'last_check_in_date';
                        final isCheckedInToday = prefs?.getString(lastDateKey) ==
                            DateFormat('yyyy-MM-dd').format(DateTime.now());
                        return Row(
                          children: [
                            _buildStatItem(
                              icon: Icons.local_fire_department,
                              value: '${prefs != null ? prefs.getInt(streakKey) ?? 0 : 0} 天',
                              label: '连续守护',
                              color: Colors.orange,
                              bgColor: Colors.orange.shade50,
                            ),
                            const SizedBox(width: ZaiNeSpacing.md),
                            _buildStatItem(
                              icon: isCheckedInToday ? Icons.check_circle : Icons.radio_button_unchecked,
                              value: isCheckedInToday ? '已签到' : '未签到',
                              label: '今日状态',
                              color: isCheckedInToday ? Colors.green : Colors.grey,
                              bgColor: isCheckedInToday ? Colors.green.shade50 : Colors.grey.shade100,
                            ),
                            const SizedBox(width: ZaiNeSpacing.md),
                            _buildStatItem(
                              icon: Icons.calendar_today,
                              value: '${prefs != null ? prefs.getInt(totalKey) ?? 0 : 0} 天',
                              label: '累计签到',
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
                            '还没有守护者',
                            style: TextStyle(
                              fontSize: ZaiNeFontSize.body,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(height: ZaiNeSpacing.sm),
                          Text(
                            '添加紧急联系人\n让他们成为你的守护者',
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
                            label: const Text('添加守护者'),
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
                        final guardian = _guardians[index];
                        return _buildGuardianCard(guardian, index);
                      },
                      childCount: _guardians.length,
                    ),
                  ),
                ),

              // ====== 功能入口 ======
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Text(
                    '常用功能',
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
                        title: '紧急联系人管理',
                        subtitle: '添加、修改、排序你的守护者（最多 10 位）',
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
                        icon: Icons.check_circle_outline,
                        title: '平安确认',
                        subtitle: '让守护者知道你一切平安',
                        color: Colors.green,
                        onTap: () {
                          _showPeaceConfirmation();
                        },
                      ),
                      const SizedBox(height: ZaiNeSpacing.md),
                      _buildFunctionEntry(
                        icon: Icons.health_and_safety_outlined,
                        title: '生命体征守护',
                        subtitle: '同步 Apple Watch 心率、血氧与睡眠',
                        color: Colors.red.shade400,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const HealthOverviewPage()),
                          );
                        },
                      ),
                      const SizedBox(height: ZaiNeSpacing.md),
                      _buildFunctionEntry(
                        icon: Icons.help_outline,
                        title: '什么是守护圈',
                        subtitle: '了解守护圈的工作原理',
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

  /// 守护者卡片
  Widget _buildGuardianCard(Map<String, dynamic> guardian, int index) {
    final colors = [
      ZaiNeColors.brandOrange,
      const Color(0xFF7C4DFF),
      Colors.teal,
      Colors.blue,
    ];
    final accentColor = colors[index % colors.length];

    return GestureDetector(
      onLongPress: () => _showRemoveGuardianDialog(guardian),
      child: Container(
        margin: const EdgeInsets.only(bottom: ZaiNeSpacing.cardXs),
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
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          guardian['name'] ?? '未命名',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: ZaiNeFontSize.body,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: ZaiNeSpacing.sm),
                      // 关系标签
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.sm, vertical: ZaiNeSpacing.xs),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                          ),
                          child: Text(
                            (guardian['relation'] == null || guardian['relation'].toString().isEmpty)
                                ? '守护者'
                                : guardian['relation'].toString(),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: ZaiNeFontSize.micro,
                              color: accentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: ZaiNeSpacing.xs),
                  // 三态状态标签
                  _buildStatusLabel(guardian),
                ],
              ),
            ),
            // 电话 + 短信 + 平安确认按钮（并排）
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 电话按钮
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _callGuardian((guardian['name'] ?? '守护者').toString(), (guardian['phone'] ?? '').toString());
                  },
                  child: Tooltip(
                    message: '拨打电话',
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.phone, color: accentColor, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: ZaiNeSpacing.sm),
                // 短信按钮
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _sendSMSToGuardian((guardian['name'] ?? '守护者').toString(), (guardian['phone'] ?? '').toString());
                  },
                  child: Tooltip(
                    message: '发送短信',
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.sms, color: Colors.green.shade600, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: ZaiNeSpacing.sm),
                // 第三按钮：已注册+已激活→平安确认 / 已注册+待激活→提醒TA / 未注册→邀请注册
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    if (guardian['isRegistered'] == true && guardian['isActive'] == true) {
                      _showRequestPeaceDialog(guardian);
                    } else if (guardian['isRegistered'] == true && guardian['isActive'] != true) {
                      _remindToDownload(guardian);
                    } else {
                      _inviteToRegister(guardian);
                    }
                  },
                  child: Tooltip(
                    message: (guardian['isRegistered'] == true && guardian['isActive'] == true)
                        ? '请求平安确认'
                        : (guardian['isRegistered'] == true && guardian['isActive'] != true)
                            ? '提醒TA下载'
                            : '邀请注册',
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: (guardian['isRegistered'] == true && guardian['isActive'] == true)
                            ? Colors.blue.shade50
                            : (guardian['isRegistered'] == true && guardian['isActive'] != true)
                                ? Colors.purple.shade50
                                : Colors.orange.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        (guardian['isRegistered'] == true && guardian['isActive'] == true)
                            ? Icons.favorite_border
                            : (guardian['isRegistered'] == true && guardian['isActive'] != true)
                                ? Icons.notifications_active_outlined
                                : Icons.person_add_alt_1,
                        color: (guardian['isRegistered'] == true && guardian['isActive'] == true)
                            ? Colors.blue.shade600
                            : (guardian['isRegistered'] == true && guardian['isActive'] != true)
                                ? Colors.purple.shade600
                                : Colors.orange.shade700,
                        size: 18,
                      ),
                    ),
                  ),
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
        const SnackBar(
          content: Text('该守护者未设置电话号码'),
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
              child: Text('拨打给 $name'),
            ),
          ],
        ),
        content: Text('即将拨打：${_maskPhone(phone)}\n\n点击确认后打开拨号界面。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: ZaiNeColors.brandOrange),
            child: const Text('拨打'),
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
            const SnackBar(
              content: Text('无法打开拨号界面，请手动拨打'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拨号失败：$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// 发送短信给守护者（长按触发）
  Future<void> _sendSMSToGuardian(String name, String phone) async {
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('该守护者未设置电话号码'),
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
    final name = guardian['name'] ?? '守护者';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.card)),
        title: Row(
          children: [
            Icon(Icons.favorite_border, color: Colors.blue.shade600),
            const SizedBox(width: ZaiNeSpacing.sm),
            Expanded(
              child: Text('向 $name 发平安确认请求'),
            ),
          ],
        ),
        content: Text(
          '将向 $name 发送一条平安确认请求，\n对方打开在呢App后可点击"平安"确认。\n\n是否继续？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _sendPeaceRequest(guardian);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
            ),
            child: const Text('发送请求'),
          ),
        ],
      ),
    );
  }

  /// 发送平安确认请求
  Future<void> _sendPeaceRequest(Map<String, dynamic> guardian) async {
    final phone = guardian['phone']?.toString() ?? '';
    final name = guardian['name']?.toString() ?? '守护者';
    final userId = guardian['userId'] as int?;

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('该守护者未绑定手机号，无法发送平安确认'),
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
              content: Text('$name 尚未注册「在呢」，无法发送平安确认'),
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
          const SnackBar(
            content: Text('网络请求失败，请检查网络后重试'),
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
              content: Text('已向 $name 发送平安确认请求'),
              backgroundColor: Colors.blue,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('发送失败：${peaceRes['error'] ?? '请稍后重试'}'),
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
          const SnackBar(
            content: Text('网络请求失败，请检查网络后重试'),
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
    final name = guardian['name'] ?? '守护者';
    final phone = guardian['phone'] ?? '';
    final isRegistered = guardian['isRegistered'] == true;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.card)),
        title: const Row(
          children: [
            Icon(Icons.person_remove_outlined, color: Colors.red),
            SizedBox(width: ZaiNeSpacing.sm),
            Text('解除守护关系'),
          ],
        ),
        content: Text(
           isRegistered
               ? '确定要解除与 $name ($phone) 的守护关系吗？\n\n解除后，对方将不再接收你的 SOS 通知，你也无法再看到对方的签到状态。'
               : '确定要将 $name ($phone) 从守护圈移除吗？',
         ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _removeGuardian(guardian);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('解除守护'),
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
        throw Exception('找不到该联系人的记录');
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
            SnackBar(content: Text('已解除与 ${guardian['name']} 的守护关系'), backgroundColor: Colors.blue),
          );
          _loadGuardians(isSilent: false);
        }
      } else {
        throw Exception(res['message'] ?? '解除失败');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e'), backgroundColor: Colors.red),
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
        title: const Row(
          children: [
            Icon(Icons.shield, color: Color(0xFF7C4DFF)),
            SizedBox(width: ZaiNeSpacing.sm),
            Text('什么是守护圈'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('守护圈是你的专属安全网络。'),
            SizedBox(height: ZaiNeSpacing.sm),
            Text('🛡️ 添加信任的家人和朋友作为守护者'),
            SizedBox(height: ZaiNeSpacing.xs),
            Text('🔔 你每天的签到状态守护者可见'),
            SizedBox(height: ZaiNeSpacing.xs),
            Text('🆘 紧急求助触发时守护者会立即收到通知'),
            SizedBox(height: ZaiNeSpacing.xs),
            Text('❤️ 让关心你的人安心'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('我知道了'),
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
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: ZaiNeSpacing.sm),
            Text('平安确认'),
          ],
        ),
        content: const Text(
          '向你的守护者发送一条平安消息，让他们知道你一切安好。\n\n"我很好，不用担心 ❤️"',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _sendPeaceMessageToAll();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('发送确认'),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('还没有添加守护者，请先添加紧急联系人'),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('守护者信息异常，请重新添加联系人'),
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
    String senderName = '我';
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString('user_profile');
      if (profileJson != null) {
        final profile = jsonDecode(profileJson);
        senderName = (profile['name'] as String?)?.isNotEmpty == true ? profile['name'] as String : '我';
      }
    } catch (_) {}

    try {
      final uri = Uri(
        scheme: 'sms',
        path: firstPhone,
        queryParameters: {'body': '【在呢】$senderName 一切平安，请放心 ❤️'},
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('已为 ${contacts.length} 位守护者准备短信，请在短信App中发送'),
          backgroundColor: Colors.teal,
          behavior: SnackBarBehavior.floating,
        ));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('无法打开短信界面，请手动发送平安消息'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('短信功能不可用：$e'),
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
          (guardian['name'] ?? '未命名').toString().substring(0, 1),
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
