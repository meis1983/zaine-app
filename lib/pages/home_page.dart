import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'help_page.dart';
import 'profile_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/membership_service.dart';
import '../pages/subscription_page.dart';
import '../widgets/checkin_milestone_dialog.dart';
import '../services/api/checkin_service.dart';
import '../services/api/peace_service.dart';
import '../services/api/card_service.dart';
import '../services/deep_link_service.dart';
import '../services/platform/health_service.dart'; // 新增
import '../widgets/guardian_card_envelope.dart'; // 新增
import '../main.dart';
import '../theme/theme_helper.dart';
import '../utils/avatar_helper.dart';
import '../widgets/stats_row_widget.dart';
import '../widgets/home_header.dart';
import '../widgets/peace_request_banner.dart';
import '../widgets/help_card_widget.dart';
import '../widgets/guard_status_widget.dart';
import '../widgets/check_in_button_widget.dart';
import '../services/api/auth_service.dart';
import '../services/api/sync_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _checkedInToday = false;
  DateTime? _lastCheckIn;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  int _continuousDays = 0;
  int _totalDays = 0;
  int _weeklyDays = 0;
  int _daysSinceLastCheckin = 0; // 断签天数，>0 表示回归
  /// 【修复 v1.91.0】签到数据是否就绪。
  /// 首次启动时如果本地无任何缓存，会立即渲染 0 出现"短暂显示 0 天"的视觉错。
  /// 引入这个标志位：在本地无缓存且服务端未返回前，签到数字区域显示占位 skeleton。
  bool _isCheckinDataReady = false;
  bool _isLoggedIn = false;
  String? _userName;
  int _guardianCount = 0;
  int _totalRegistered = 0; // 新增：已成功邀请并注册的人数
  /// 日历月份偏移量（0=当前月，-1=上个月，1=下个月）
  int _calendarMonthOffset = 0;
  String? _avatarPath;
  String _membershipLevel = 'free'; // 会员等级：free / smart

  /// 待确认的平安确认请求列表
  List<Map<String, dynamic>> _pendingPeaceRequests = [];

  /// 【修复 v1.76.0】防止守护卡弹窗重复弹出的标志位
  bool _hasShownCardRitual = false;

  /// 【P2修复 v1.9.83】缓存 SharedPreferences 实例，避免日历组件重复IO
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _initialize();
  }

  /// 【修复 v1.9.77】串行初始化，避免 _loadCheckInStatus 执行时 _isLoggedIn 仍为 false
  Future<void> _initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _checkLoginStatus();
    
    // 【修复 v1.80.0】登录后从服务器拉取数据到本地缓存（联系人/档案/签到状态）
    if (_isLoggedIn) {
      try {
        if (kDebugMode) debugPrint('[HomePage] 开始从服务器拉取数据...');
        await SyncService.pullFromServer();
        if (kDebugMode) debugPrint('[HomePage] ✅ 服务器数据拉取完成');
      } catch (e) {
        if (kDebugMode) debugPrint('[HomePage] ⚠️ 拉取服务器数据失败: $e');
      }
      // 拉取完成后重新加载本地缓存数据到 UI
      await _loadCheckInStatus();
    }
    
    await _loadPendingPeaceRequests();
    await _loadInviteStats();
    
    // ====== 新增：检查并展示 Deep Link 带来的守护卡仪式感 ======
    _checkPendingCardRitual();

    // ====== 新增：执行健康数据静默同步（有心跳即签到） ======
    _syncHealthData();
  }

  /// 同步健康数据（Apple Watch 心跳检测）
  Future<void> _syncHealthData() async {
    if (!_isLoggedIn) return;
    
    // 延迟几秒执行，避免抢占首页初始化资源
    await Future.delayed(const Duration(seconds: 3));
    
    try {
      if (kDebugMode) debugPrint('[HomePage] 开始静默同步 HealthKit 数据...');
      await HealthService.performSilentHeartbeatCheckin();
      // 如果签到成功，刷新一下首页状态
      _loadCheckInStatus();
    } catch (e) {
      if (kDebugMode) debugPrint('[HomePage] 健康数据同步失败: $e');
    }
  }

  /// 检查是否有待处理的守护卡（来自 Deep Link），并展示 3D 开封仪式
  Future<void> _checkPendingCardRitual() async {
    if (!_isLoggedIn) return;

    // 【修复 v1.76.0】防止重复弹出：单次会话只展示一次
    if (_hasShownCardRitual) return;
    final hasPending = await DeepLinkService.hasPendingCardCode();
    if (!hasPending) return;

    final code = _prefs?.getString('pending_card_code') ?? '';
    if (code.isEmpty) return;

    try {
      final res = await CardService.checkCard(code);
      if (res['success'] == true && mounted) {
        final cardData = res;

        // 【修复 v1.76.0】立即清理 pending_card_code，避免延迟期间页面重建导致重复弹出
        await _prefs?.remove('pending_card_code');
        await DeepLinkService.clearPendingCardCode();

        // 设置标志位，防止本次会话重复触发
        _hasShownCardRitual = true;

        // 延迟 1 秒展示，等首页 UI 加载稳定
        await Future.delayed(const Duration(milliseconds: 1000));

        if (!mounted) return;

        await showGeneralDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black.withValues(alpha: 0.9),
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (ctx, anim1, anim2) {
            return Scaffold(
              backgroundColor: Colors.transparent,
              body: GuardianCardEnvelope(
                senderName: cardData['sender_name'] ?? '你的好友',
                senderAvatar: cardData['sender_avatar'],
                message: cardData['message'] ?? '想和你建立守护关系',
                cardCode: code,
                appStoreUrl: '',
                isWelcomeMode: true,
                onComplete: () {
                  // 【修复】pending_card_code 已在弹窗前清理，这里只需关闭弹窗和刷新统计
                  Future.delayed(const Duration(milliseconds: 3500), () async {
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      _loadInviteStats();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('守护关系已建立，感谢你的加入')),
                        );
                      }
                    }
                  });
                },
              ),
            );
          },
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[HomePage] 仪式感加载失败: $e');
    }
  }

  /// 加载邀请统计（我的守护圈人数）
  Future<void> _loadInviteStats() async {
    if (!_isLoggedIn) return;
    try {
      final res = await CardService.getInviteStats();
      if (res['success'] == true && mounted) {
        setState(() {
          _totalRegistered = (res['total_registered'] as int?) ?? 0;
        });
        if (kDebugMode) debugPrint('[HomePage] ✅ 获取邀请统计: total_registered=$_totalRegistered');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[HomePage] 加载邀请统计失败: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (kDebugMode) debugPrint('[HomePage] App resumed, triggering health sync...');
      _syncHealthData();
    }
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final avatarPath = await AvatarHelper.getPath(prefs);
    // 验证头像文件是否真实存在，不存在则从 base64 恢复
    String? validAvatarPath;
    if (avatarPath != null && avatarPath.isNotEmpty) {
      if (await File(avatarPath).exists()) {
        validAvatarPath = avatarPath;
      } else {
        if (kDebugMode) debugPrint('[Home] 头像文件不存在，尝试从 base64 恢复...');
      }
    }

    // 【修复 v1.9.79】pullFromServer 中 base64Decode 失败时 path 不会被保存，
    // 导致 avatarPath 为 null，此处必须兜底从 base64 恢复
    if (validAvatarPath == null) {
      final base64Str = await AvatarHelper.getBase64(prefs);
      if (base64Str != null && base64Str.isNotEmpty) {
        try {
          final bytes = base64Decode(base64Str);
          final dir = await getApplicationDocumentsDirectory();
          final restorePath = '${dir.path}/avatar.png';
          await File(restorePath).writeAsBytes(bytes);
          await AvatarHelper.setPath(prefs, restorePath);
          validAvatarPath = restorePath;
          if (kDebugMode) debugPrint('[Home] ✅ 头像已从 base64 备份恢复');
        } catch (e) {
          if (kDebugMode) debugPrint('[Home] ⚠️ base64 头像恢复失败: $e');
          await AvatarHelper.clear(prefs);
        }
      } else if (avatarPath != null && avatarPath.isNotEmpty) {
        if (kDebugMode) debugPrint('[Home] 头像文件不存在，清除路径: $avatarPath');
        await AvatarHelper.clear(prefs);
      }
    }
    // 读取守护人数量（与 contacts_page.dart 保持一致的 key 规则）
    int guardianCount = 0;
    String? userId;
    String? phone;
    // 【修复 v1.90.1】提前读取签到状态，避免首次渲染显示"未签到"
    bool checkedInToday = false;
    DateTime? lastCheckIn;
    try {
      userId = await AuthService.getUserId();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final lastDate = prefs.getString('last_check_in_date');
      if (lastDate == today) {
        checkedInToday = true;
      }
      // 如果用户已登录，优先使用用户隔离的键值
      if (userId != null && userId.isNotEmpty) {
        final userSpecificDate = prefs.getString('last_check_in_date_$userId');
        if (userSpecificDate == today) {
          checkedInToday = true;
        }
      }
      if (lastDate != null) {
        try { lastCheckIn = DateTime.parse(lastDate); } catch (_) {}
      }
      // 读取守护人数量（与 contacts_page.dart 保持一致的 key 规则）
      int guardianCount = 0;
      String? phone;
      final contactsKey = (userId != null && userId.isNotEmpty)
          ? 'emergency_contacts_$userId'
          : 'emergency_contacts';
      final contactsJson = prefs.getString(contactsKey);
      if (contactsJson != null && contactsJson.isNotEmpty) {
        final contacts = jsonDecode(contactsJson) as List<dynamic>?;
        guardianCount = contacts?.length ?? 0;
      }
      phone = await AuthService.getUserPhone();
    } catch (_) {}

    setState(() {
      _isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      // 【修复 v1.90.1】立即设置签到状态，避免首次渲染闪现"未签到"
      _checkedInToday = checkedInToday;
      if (lastCheckIn != null) _lastCheckIn = lastCheckIn;
      // 【修复 v1.9.73】从 per‑user 档案读姓名，避免切账号串名
      String? userName;
      final uid = userId ?? '';
      if (uid.isNotEmpty) {
        // 优先读用户隔离键
        String? profileJson = prefs.getString('user_profile_$uid');
        // 降级到全局键（pullFromServer 保存到此键）
        profileJson ??= prefs.getString('user_profile');
        if (profileJson != null) {
          try {
            final profile = jsonDecode(profileJson);
            userName = profile['name']?.toString();
          } catch (_) {}
        }
      }
      _userName = userName ?? prefs.getString('user_name') ?? (phone ?? '');
      _avatarPath = validAvatarPath;
      _guardianCount = guardianCount;
      _membershipLevel = MembershipService.getLevel();
    });
  }

  Future<void> _loadCheckInStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // 【修复 v1.91.0】先读取全局 last_check_in_date，立即 setState，消除闪烁
    // 根因：之前先 await AuthService.getUserId() 导致第一次渲染时 _checkedInToday=false
    // 修复：读取到 prefs 后立即展示本地状态，不再等待用户 ID 解析
    String? lastDate = prefs.getString('last_check_in_date');
    String uid = '';
    bool hasLocalCache = false; // 【修复 v1.91.0】是否已有任何本地签到缓存

    // 尝试获取用户 ID（异步），但不阻塞第一次 setState
    try {
      uid = (await AuthService.getUserId()) ?? '';
      // 如果用户已登录，优先使用用户隔离的键值
      if (uid.isNotEmpty) {
        final userSpecificDate = prefs.getString('last_check_in_date_$uid');
        if (userSpecificDate != null) {
          lastDate = userSpecificDate;
          hasLocalCache = true;
        } else if (lastDate != null) {
          // 全局有缓存但用户隔离没有（新登录 / 切号），也认为有缓存
          hasLocalCache = true;
        }
      } else if (lastDate != null) {
        hasLocalCache = true;
      }
    } catch (_) {
      if (lastDate != null) hasLocalCache = true;
    }

    if (!mounted) return;
    setState(() {
      // 【修复 v1.91.0】先设置本地读取的状态，避免闪烁
      _checkedInToday = lastDate == today;
      if (lastDate != null) {
        try {
          _lastCheckIn = DateTime.parse(lastDate);
        } catch (_) {}
      }
      // 使用用户隔离的键值（如果已读取到）
      final streakKey = uid.isNotEmpty ? 'continuous_days_$uid' : 'continuous_days';
      final totalKey = uid.isNotEmpty ? 'total_check_in_days_$uid' : 'total_check_in_days';
      final historyKey = uid.isNotEmpty ? 'checkin_history_$uid' : 'checkin_history';
      // 【修复 v1.91.0】优先信任本地隔离缓存；首次登录时 continuousDays=0 是正确的（新用户）
      _continuousDays = prefs.getInt(streakKey) ?? 0;
      _totalDays = prefs.getInt(totalKey) ?? 0;
      _weeklyDays = _calculateWeeklyDays(prefs, historyKey);
      // 【修复 v1.91.0】如果有本地缓存，标记数据已就绪；否则保持未就绪，
      // 等服务端返回后再标记就绪，避免出现"短暂显示 0 天"的视觉错
      if (hasLocalCache) _isCheckinDataReady = true;
    });

    // 同步服务器获取断签天数和签到状态（覆盖本地状态，确保准确性）
    if (_isLoggedIn) {
      try {
        final res = await CheckinService.getTodayStatus();
        if (res['success'] == true && mounted) {
          setState(() {
            _totalDays = res['total_days'] ?? _totalDays;
            // 【P0】优先使用服务端 streak，确保签到圆圈正确显示
            final serverStreak = res['streak'];
            if (serverStreak != null) {
              _continuousDays = serverStreak as int;
            }
            _daysSinceLastCheckin = res['days_since_last_checkin'] ?? 0;
            // 【彻底修复 v1.90.1】如果本地已经是 true，不要覆盖为 false（防止服务器时区问题）
            if (res.containsKey('checked_in_today')) {
              final serverChecked = res['checked_in_today'] == true;
              if (_checkedInToday != serverChecked) {
                // 本地已签到，但服务器返回未签到：相信本地（可能是服务器时区问题）
                if (_checkedInToday && !serverChecked) {
                  if (kDebugMode) debugPrint('[HomePage] ⚠️ 本地已签到，但服务器返回未签到，相信本地状态（可能是服务器时区问题）');
                } else {
                  _checkedInToday = serverChecked;
                  if (kDebugMode) debugPrint('[HomePage] ⚠️ 签到状态已修正: 本地=$_checkedInToday → 服务端=$serverChecked');
                }
              }
            }
          });
          // 同步到本地缓存（用户隔离 key）【修复 v1.77.0】
          final streakKey = uid.isNotEmpty ? 'continuous_days_$uid' : 'continuous_days';
          final totalKey = uid.isNotEmpty ? 'total_check_in_days_$uid' : 'total_check_in_days';
          final lastDateKey = uid.isNotEmpty ? 'last_check_in_date_$uid' : 'last_check_in_date';
          await prefs.setInt(streakKey, _continuousDays);
          await prefs.setInt(totalKey, _totalDays);
          if (_checkedInToday) {
            await prefs.setString(lastDateKey, today);
            await prefs.setString('last_check_in_date', today);
          }
          if (kDebugMode) debugPrint('[HomePage] 服务器签到状态: totalDays=$_totalDays, daysSinceLastCheckin=$_daysSinceLastCheckin, checkedInToday=$_checkedInToday');
        }
        // 【修复 v1.91.0】无论服务端返回成功还是失败，都标记数据就绪
        if (mounted) setState(() => _isCheckinDataReady = true);
      } catch (e) {
        if (kDebugMode) debugPrint('[HomePage] 同步服务器签到状态失败: $e');
        // 【修复 v1.91.0】服务端失败也要标记就绪，否则会一直 loading
        if (mounted) setState(() => _isCheckinDataReady = true);
      }
    }
  }

  /// 加载待确认的平安确认请求
  Future<void> _loadPendingPeaceRequests() async {
    try {
      final res = await PeaceService.getPendingRequests();
      if (res['success'] == true && mounted) {
        final requests = (res['requests'] as List?) ?? [];
        setState(() {
          _pendingPeaceRequests = requests.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Home] 加载平安确认请求失败: $e');
    }
  }

  /// 确认平安
  Future<void> _confirmPeace(int requestId) async {
    try {
      final res = await PeaceService.confirmPeace(requestId);
      if (res['success'] == true && mounted) {
        HapticFeedback.mediumImpact();
        setState(() {
          _pendingPeaceRequests.removeWhere((r) => r['request_id'] == requestId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已确认平安 ❤️'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Home] 确认平安失败: $e');
    }
  }

  int _calculateWeeklyDays(SharedPreferences prefs, [String? historyKey]) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    int count = 0;
    final key = historyKey ?? 'checkin_history';
    for (int i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(day);
      // 简化：只检查本周到今天
      if (day.isAfter(now)) break;
      // 检查签到历史列表
      final history = prefs.getStringList(key) ?? [];
      if (history.contains(dateStr)) count++;
    }
    return count;
  }

  Future<void> _handleCheckIn() async {
    // 【修复 v1.83.0】双重防重复签到：
    // 1. 内存状态 _checkedInToday
    // 2. 本地存储 last_check_in_date（防止 Widget 重建后内存状态丢失导致重复签到）
    final guardPrefs = await SharedPreferences.getInstance();
    final guardUid = (await AuthService.getUserId()) ?? '';
    final guardLastDateKey = guardUid.isNotEmpty ? 'last_check_in_date_$guardUid' : 'last_check_in_date';
    final guardToday = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final guardLastDate = guardPrefs.getString(guardLastDateKey);
    final alreadyCheckedLocally = guardLastDate == guardToday;

    if (_checkedInToday || alreadyCheckedLocally) {
      // 【修复 v1.9.72】服务端 UTC 时间与本地 UTC+8 可能存在日期偏差
      // 导致 _checkedInToday 被误设为 true，用户点击"签到"却无响应
      // 改为：仍弹出庆祝弹窗，不让用户体验断掉
      if (kDebugMode) debugPrint('[HomePage] 今日已签到（可能为时区误判），显示庆祝弹窗');
      try {
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: true,
            builder: (context) => CheckinMilestoneDialog(
              continuousDays: _continuousDays,
              totalDays: _totalDays,
              moodIndex: -1,
              userName: _userName ?? '在呢用户',
              isReturnCheckin: _daysSinceLastCheckin > 0,
              absentDays: _daysSinceLastCheckin,
            ),
          );
        }
      } catch (e, stack) {
        if (kDebugMode) debugPrint('[HomePage] 弹窗显示异常: $e');
        if (kDebugMode) debugPrint(stack.toString());
      }
      return;
    }

    // ✅ 立即更新 UI —— 让用户第一时间看到已签到
    HapticFeedback.mediumImpact();

    // 【修复 v1.9.7】动画加异常保护，防止 controller 被 dispose 后抛异常中断方法
    try {
      _animationController.forward().then((_) {
        if (mounted) _animationController.reverse();
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[HomePage] 动画异常（忽略）: $e');
    }

    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);

    // 先计算新的天数
    int newDays = 1;
    int newTotal = _totalDays + 1;
    if (_lastCheckIn != null) {
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      final lastDate = DateTime(
          _lastCheckIn!.year, _lastCheckIn!.month, _lastCheckIn!.day);
      if (lastDate == yesterday) {
        newDays = (_continuousDays + 1).clamp(0, 999);
      } else if (lastDate != DateTime(now.year, now.month, now.day)) {
        newDays = 1;
      }
    }

    // 立即刷新 UI（不等待任何 IO）
    setState(() {
      _checkedInToday = true;
      _lastCheckIn = now;
      _continuousDays = newDays;
      _totalDays = newTotal;
      _weeklyDays++;
    });

    // 后台异步持久化（不阻塞 UI）
    // 【修复】签到数据按用户隔离存储
    final prefs = await SharedPreferences.getInstance();
    final uid = (await AuthService.getUserId()) ?? '';
    final streakKey = uid.isNotEmpty ? 'continuous_days_$uid' : 'continuous_days';
    final totalKey = uid.isNotEmpty ? 'total_check_in_days_$uid' : 'total_check_in_days';
    final historyKey = uid.isNotEmpty ? 'checkin_history_$uid' : 'checkin_history';
    final lastDateKey = uid.isNotEmpty ? 'last_check_in_date_$uid' : 'last_check_in_date';

    await prefs.setString(lastDateKey, today);
    // 兼容：同时保存全局 key（供未登录场景使用）
    await prefs.setString('last_check_in_date', today);
    await prefs.setInt(streakKey, newDays);
    await prefs.setInt(totalKey, newTotal);
    // 保存签到历史
    final history = prefs.getStringList(historyKey) ?? [];
    if (!history.contains(today)) {
      history.add(today);
      await prefs.setStringList(historyKey, history);
    }

    // 后台同步到服务器（如果已登录）
    if (_isLoggedIn) {
      try {
        final res = await CheckinService.checkIn(date: today, mood: -1);
        if (res['success'] == true) {
          if (kDebugMode) debugPrint('[HomePage] 签到已同步到服务器: $res');
          // 【修复 v1.9.7】后端 total_days 是累计总天数，不应覆盖 continuous_days（连续天数）
          final serverTotal = res['total_days'] as int?;
          final serverStreak = res['streak'] as int? ?? res['continuous_days'] as int?;
          if (serverTotal != null && serverTotal > _totalDays) {
            await prefs.setInt(totalKey, serverTotal);
            if (mounted) setState(() => _totalDays = serverTotal);
          }
          if (serverStreak != null && serverStreak > 0) {
            await prefs.setInt(streakKey, serverStreak);
            if (mounted) setState(() => _continuousDays = serverStreak);
          }
          // 显示同步成功反馈
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('☀️ 签到已同步'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          final errorMsg = res['error']?.toString() ?? res['message']?.toString() ?? '';
          if (kDebugMode) debugPrint('[HomePage] 签到同步失败: $errorMsg');
          if (mounted) {
            // 【修复 v1.9.75】already_checked_in 是正常状态，不显示警告
            final isAlreadyCheckedIn = errorMsg.contains('already_checked_in');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isAlreadyCheckedIn
                    ? '☀️ 今日已签到'
                    : '签到已记录，云端同步暂时失败: $errorMsg'),
                backgroundColor: isAlreadyCheckedIn ? Colors.green : Colors.orange,
                duration: Duration(seconds: isAlreadyCheckedIn ? 2 : 3),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[HomePage] 签到同步异常（已本地保存）: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('签到已记录，网络异常暂未同步到云端'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }

    // 签到成功：取消断签预警通知（id=1），因为已经签到了
    try {
      final notifications = FlutterLocalNotificationsPlugin();
      await notifications.cancel(1); // 取消断签预警
      if (kDebugMode) debugPrint('[HomePage] 签到成功，已取消断签预警通知');
    } catch (e) {
      if (kDebugMode) debugPrint('[HomePage] 取消断签预警通知失败（忽略）: $e');
    }

    // 弹出签到成功弹窗（断签回归时传 isReturnCheckin）
    // 【修复 v1.9.7】弹窗加异常保护，防止 dialog 构建异常导致弹窗不显示
    try {
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => CheckinMilestoneDialog(
            continuousDays: _continuousDays,
            totalDays: _totalDays,
            moodIndex: -1,
            userName: _userName ?? '在呢用户',
            isReturnCheckin: _daysSinceLastCheckin > 0,
            absentDays: _daysSinceLastCheckin,
          ),
        );
      }
    } catch (e, stack) {
      if (kDebugMode) debugPrint('[HomePage] 弹窗显示异常: $e');
      if (kDebugMode) debugPrint(stack.toString());
    }
  }

  void _openHelp() {
    if (kDebugMode) debugPrint('[HomePage] 紧急求助卡片被点击，_isLoggedIn=$_isLoggedIn');
    if (!_isLoggedIn) {
      _showLoginPrompt();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const HelpPage()),
    );
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ProfilePage(isPushed: true)),
    ).then((_) {
      _checkLoginStatus();
      _loadCheckInStatus();
    });
  }

  void _openSubscription() {
    if (!_isLoggedIn) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SubscriptionPage()),
    ).then((_) {
      // 从订阅页返回后刷新会员等级
      setState(() {
        _membershipLevel = MembershipService.getLevel();
      });
    });
  }

  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.login, color: Color(0xFFFF7F50)),
            SizedBox(width: ZaiNeSpacing.sm),
            Text('请先完善信息'),
          ],
        ),
        content: const Text(
          '使用紧急求助功能前，请先填写您的健康档案和紧急联系人信息。\n\n这确保在紧急情况下，救援人员能获取您的关键健康信息。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openProfile();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7F50),
            ),
            child: const Text('去填写'),
          ),
        ],
      ),
    );
  }

 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZaiNeColors.scaffoldBg(),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ====== 顶部标题栏（提取为 HomeHeaderWidget）======
              HomeHeaderWidget(
                key: ValueKey('home_header_${_avatarPath ?? _userName ?? 'default'}'),
                isLoggedIn: _isLoggedIn,
                checkedInToday: _checkedInToday,
                userName: _userName,
                avatarPath: _avatarPath,
                membershipLevel: _membershipLevel,
                totalRegistered: _totalRegistered,
                guardianCount: _guardianCount,
                continuousDays: _continuousDays,
                onTapAvatar: _openProfile,
                onTapMembership: _openSubscription,
              ),

              // ====== 平安确认请求横幅（守护者发来的） ======
              // 【P3-2 代码优化 v1.17.4】已提取为 PeaceRequestBannerWidget
              // 旧代码已注释，新组件在下方
              PeaceRequestBannerWidget(
                pendingRequests: _pendingPeaceRequests,
                onConfirm: _confirmPeace,
                onDismiss: (requestId) {
                  setState(() {
                    _pendingPeaceRequests.removeWhere((r) => r['request_id'] == requestId);
                  });
                },
              ),
              const SizedBox(height: ZaiNeSpacing.xs),

              // ====== 健康档案提示（v1.9.8 隐藏）=====
              // 根因：与紧急求助卡片前置引导重复（点击紧急求助会自动引导完善档案/守护人/位置授权），
              //       视觉冗余且造成界面混乱。保留代码以便后续需要时恢复。
              // if (!_isLoggedIn)
              //   Container(
              //     margin: const EdgeInsets.only(bottom: 16),
              //     padding:
              //         const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.md, vertical: ZaiNeSpacing.md),
              //     decoration: BoxDecoration(
              //       color: Colors.orange.shade50,
              //       borderRadius: BorderRadius.circular(12),
              //       border: Border.all(color: Colors.orange.shade200),
              //     ),
              //     child: Row(
              //       children: [
              //         Icon(Icons.info_outline,
              //             color: Colors.orange.shade700, size: 18),
              //         const SizedBox(width: ZaiNeSpacing.sm),
              //         Expanded(
              //           child: GestureDetector(
              //             onTap: _openProfile,
              //             child: const Text(
              //               '点击头像完善健康档案，开启全部功能 →',
              //               style: TextStyle(
              //                   fontSize: 12, color: Colors.black87),
              //             ),
              //           ),
              //         ),
              //       ],
              //     ),
              //   ),

              // ====== 新手任务清单（v1.9.5 临时隐藏）=====
              // 根因：新手任务与紧急求助前置条件逻辑重叠（完善档案/添加守护人/位置授权），
              //       各自维护独立 SP 状态导致架构冲突，bug 反复。
              //       先隐藏，待登录/发卡/权限三条主线稳定后再以轻量方式回归。
              // NewbieTaskCard(
              //   isLoggedIn: _isLoggedIn,
              //   continuousDays: _continuousDays,
              //   guardianCount: _guardianCount,
              //   onOpenProfile: _openProfile,
              //   onOpenGuardian: () {
              //     Navigator.of(context).push(
              //       MaterialPageRoute(builder: (_) => const GuardianPage()),
              //     ).then((_) {
              //       _checkLoginStatus();
              //       _loadInviteStats();
              //     });
              //   },
              //   onOpenCard: () {
              //     Navigator.of(context).push(
              //       MaterialPageRoute(builder: (_) => const GuardianCardPage()),
              //     ).then((_) {
              //       _checkLoginStatus();
              //       _loadInviteStats();
              //     });
              //   },
              // ),

              // ====== 紧急求助卡片 ======
              HelpCardWidget(
                isLoggedIn: _isLoggedIn,
                onTap: _openHelp,
              ),

              const SizedBox(height: ZaiNeSpacing.lg),

              // ====== 守护状态 ======
              GuardStatusWidget(
                isLoggedIn: _isLoggedIn,
                continuousDays: _continuousDays,
                totalRegistered: _totalRegistered,
                guardianCount: _guardianCount,
              ),

              const SizedBox(height: ZaiNeSpacing.xl),

              // ====== 签到按钮 ======
              CheckInButtonWidget(
                continuousDays: _continuousDays,
                checkedInToday: _checkedInToday,
                onTap: _handleCheckIn,
                scaleAnimation: _scaleAnimation,
                isDataReady: _isCheckinDataReady,
              ),

              const SizedBox(height: ZaiNeSpacing.xl),

              // ====== 底部三列统计 ======
              StatsRowWidget(
                continuousDays: _continuousDays,
                totalDays: _totalDays,
                weeklyDays: _weeklyDays,
              ),

              // ====== 【v1.17.3】明显的升级按钮（解决审核找不到订阅入口问题） ======
              if (_isLoggedIn && _membershipLevel == 'free') ...[
                const SizedBox(height: ZaiNeSpacing.lg),
                GestureDetector(
                  onTap: _openSubscription,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF8C42), Color(0xFFFF6B35)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: ZaiNeSpacing.sm),
                        const Text(
                          '升级到智能版',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: ZaiNeSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.sm, vertical: ZaiNeSpacing.xs),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '解锁全部功能',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: ZaiNeSpacing.xl),

              // ====== 签到日历热力图 ======
              _buildCheckInCalendar(),

              const SizedBox(height: ZaiNeSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  /// 紧急求助卡片
  /// 签到按钮
  /// 底部三列统计
  /// 签到日历热力图（支持月份切换）
  Widget _buildCheckInCalendar() {
    final now = DateTime.now();
    // 根据偏移量计算目标月份
    final targetDate = DateTime(now.year, now.month + _calendarMonthOffset);
    // 【P2修复 v1.9.83】使用缓存的 SharedPreferences 实例，避免重复IO
    if (_prefs == null) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(20),
        child: CircularProgressIndicator(strokeWidth: 2),
      ));
    }
    final prefs = _prefs!;
    // 【兼容 v1.77.0】同步方法中从 SP 读取 user_id（Keychain 的双写备份）
    final uid = prefs.getString('user_id') ?? '';
    final historyKey = uid.isNotEmpty ? 'checkin_history_$uid' : 'checkin_history';
    final checkinHistory = prefs.getStringList(historyKey) ?? [];

        // 计算目标月份的所有日期
        final lastDayOfMonth = DateTime(targetDate.year, targetDate.month + 1, 0);
        final daysInMonth = lastDayOfMonth.day;
        final days = <DateTime>[];
        for (int d = 1; d <= daysInMonth; d++) {
          days.add(DateTime(targetDate.year, targetDate.month, d));
        }

        // 统计目标月份签到天数
        int monthCheckInCount = 0;
        for (final d in checkinHistory) {
          try {
            final date = DateTime.parse(d);
            if (date.year == targetDate.year && date.month == targetDate.month) {
              monthCheckInCount++;
            }
          } catch (_) {}
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ZaiNeColors.cardBg(),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行：月份导航 + 统计
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // 上个月按钮
                      IconButton(
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.chevron_left, size: 20,
                            color: _calendarMonthOffset > -6 ? Colors.teal.shade600 : Colors.grey[300]),
                        onPressed: _calendarMonthOffset > -6
                            ? () => setState(() => _calendarMonthOffset--)
                            : null,
                      ),
                      const SizedBox(width: ZaiNeSpacing.xs),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${targetDate.year}年${targetDate.month}月',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: ZaiNeColors.textPrimary(),
                            ),
                          ),
                          Text(
                            '$monthCheckInCount/$daysInMonth 天已签',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.teal.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: ZaiNeSpacing.xs),
                      // 下个月按钮
                      IconButton(
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.chevron_right, size: 20,
                            color: _calendarMonthOffset < 1 ? Colors.teal.shade600 : Colors.grey[300]),
                        onPressed: _calendarMonthOffset < 1
                            ? () => setState(() => _calendarMonthOffset++)
                            : null,
                      ),
                    ],
                  ),
                  // 回到今天按钮
                  if (_calendarMonthOffset != 0)
                    GestureDetector(
                      onTap: () => setState(() => _calendarMonthOffset = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.md, vertical: ZaiNeSpacing.xs),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '今月',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                              color: Colors.teal.shade700),
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                ],
              ),
              const SizedBox(height: ZaiNeSpacing.lg),

              // 星期标题 + 日历网格（Expanded 自适应宽度）
              Column(
                children: [
                  // 星期标题行
                  Row(
                    children: [
                      for (int i = 0; i < 7; i++) ...[
                        Expanded(
                          child: Text(
                            ['一', '二', '三', '四', '五', '六', '日'][i],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: themeNotifier.mode == ZaiNeThemeMode.dark ? Colors.grey[500] : Colors.grey[400],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (i < 6) const SizedBox(width: ZaiNeSpacing.xs),
                      ],
                    ],
                  ),
                  const SizedBox(height: ZaiNeSpacing.sm),
                  // 日历网格
                  ..._buildCalendarRows(days, checkinHistory),
                ],
              ),

              const SizedBox(height: ZaiNeSpacing.md),

              // 图例
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem('少', Colors.teal.shade100),
                  _buildLegendDot(Colors.teal.shade300),
                  _buildLegendDot(Colors.teal.shade500),
                  _buildLegendDot(Colors.teal.shade700),
                  Text('  多', style: TextStyle(fontSize: 10, color: themeNotifier.mode == ZaiNeThemeMode.dark ? Colors.grey[400] : Colors.grey[500])),
                ],
              ),
            ],
          ),
        );
  }

  /// 构建日历行（按月动态计算行数）
  List<Widget> _buildCalendarRows(
      List<DateTime> days, List<String> checkinHistory) {
    final rows = <Widget>[];
    if (days.isEmpty) return rows;
    
    // 找到第一天是星期几，补齐前面的空位（1=周一 ... 7=周日）
    final firstWeekday = days[0].weekday;
    // 总格子数 = 前面空位 + 实际天数
    final totalSlots = (firstWeekday - 1) + days.length;
    // 需要的行数
    final rowCount = (totalSlots / 7).ceil();

    for (int row = 0; row < rowCount; row++) {
      final cells = <Widget>[];

      // 如果是第一行且不是从周一开始，前面补空
      if (row == 0 && firstWeekday > 1) {
        for (int i = 1; i < firstWeekday; i++) {
          cells.add(const Expanded(child: SizedBox(height: ZaiNeSpacing.xl)));
        }
      }

      for (int col = 0; col < 7; col++) {
        final index = row * 7 + col - (firstWeekday - 1);
        if (index < 0 || index >= days.length) {
          cells.add(const Expanded(child: SizedBox(height: ZaiNeSpacing.xl)));
        } else {
          final day = days[index];
          final dateStr = DateFormat('yyyy-MM-dd').format(day);
          final isCheckedIn = checkinHistory.contains(dateStr);
          final isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == dateStr;

          cells.add(
            Expanded(
              child: Container(
                height: 28,
                margin: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.xs),
                child: Tooltip(
                  message: '$dateStr ${isCheckedIn ? "✓ 已签到" : "未签到"}',
                  child: Container(
                    decoration: BoxDecoration(
                      color: _getHeatmapColor(isCheckedIn),
                      borderRadius: BorderRadius.circular(5),
                      border: isToday
                          ? Border.all(color: const Color(0xFFFF7F50), width: 1.5)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                          color: isCheckedIn
                              ? Colors.white
                              : (themeNotifier.mode == ZaiNeThemeMode.dark
                                  ? Colors.grey[400] : Colors.grey[600]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      }

      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < cells.length; i++) ...[
              cells[i],
              if (i < cells.length - 1) const SizedBox(width: ZaiNeSpacing.xs),
            ],
          ],
        ),
      ));
    }
    return rows;
  }

  Color? _getHeatmapColor(bool isCheckedIn) {
    if (!isCheckedIn) return null; // 透明/无背景
    // 简单的绿色深浅——后续可按连续天数做渐变
    return Colors.teal.shade400;
  }

  Widget _buildLegendItem(String text, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(
        color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: ZaiNeSpacing.xs),
      Text(text, style: TextStyle(fontSize: 10, color: themeNotifier.mode == ZaiNeThemeMode.dark ? Colors.grey[400] : Colors.grey[500])),
      const SizedBox(width: ZaiNeSpacing.sm),
    ]);
  }

  Widget _buildLegendDot(Color color) {
    return Container(
      width: 10, height: 10,
      margin: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.xs),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
    );
  }

}
