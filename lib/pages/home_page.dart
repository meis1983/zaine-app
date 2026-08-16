import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async'; // unawaited
import 'dart:developer' as developer; // 【186】诊断日志改用 developer.log 保证进 iOS OSLog（release 包 print 被吞）
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
import '../services/debug_log.dart'; // [190] 双通道调试日志（屏幕 SnackBar + 文件兜底）
import '../services/platform/watch_data_service.dart'; // [155] 签到状态同步到 Watch
import '../services/api/checkin_service.dart';
import '../services/api/peace_service.dart';
import '../services/api/card_service.dart';
import '../services/deep_link_service.dart';
import '../services/platform/health_service.dart'; // 新增
import '../widgets/guardian_ritual.dart'; // 【修复 v1.9.95】统一守护仪式封装
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
import '../utils/streak_util.dart';
import '../config/app_config.dart';
import '../services/social/guardian_message_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _checkedInToday = false;
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

  /// 【修复 v1.9.95】守护仪式队列（DeepLink 待处理码 + welcome-pending 新绑定）
  /// 替代原 _hasShownCardRitual bool：按 card_code 去重，新关系才弹，且不会因切后台永久丢失
  final List<Map<String, dynamic>> _ritualQueue = [];
  bool _isRitualShowing = false;
  final Set<String> _seenRitualKeys = {};

  /// 【P2修复 v1.9.83】缓存 SharedPreferences 实例，避免日历组件重复IO
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 【修复 ③】前台收到守护卡 Deep Link 即时展示仪式
    DeepLinkService.onCardCodeReceived = () {
      if (mounted) _checkAndShowGuardianRituals();
    };
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    // 【v1.93.1 修复】监听 Watch 签到完成信号，刷新签到 UI
    HealthService.watchCheckinCompleteSignal.addListener(_onWatchCheckinComplete);
    // 【v1.94.0 新增】监听 Watch 签到酷炫确认横幅
    HealthService.watchCheckinCelebration.addListener(_onWatchCheckinCelebration);
    _initialize();
  }

  /// 【v1.93.1 修复】Watch 签到完成后刷新 UI
  void _onWatchCheckinComplete() {
    if (!mounted) return;
    if (kDebugMode) debugPrint('[HomePage] 🔔 收到 Watch 签到完成信号，刷新签到 UI');
    _loadCheckInStatus();
  }

  /// 【v1.94.0 新增】Watch / 心跳签到成功时弹出酷炫确认横幅
  void _onWatchCheckinCelebration() {
    if (!mounted) return;
    final data = HealthService.watchCheckinCelebration.value;
    if (data.isEmpty || data['success'] != true) return;
    final streak = data['streak'] as int? ?? 0;
    final total = data['total'] as int? ?? 0;
    final source = data['source'] as String? ?? 'watch';
    if (kDebugMode) debugPrint('[HomePage] 🔔 签到酷炫确认: source=$source, streak=$streak, total=$total');
    final isWatch = source == 'watch';
    final isHeartbeat = source == 'heartbeat';
    final title = isHeartbeat
        ? '💓 手表检测到你，已自动打卡'
        : (isWatch ? '⌚ Apple Watch 签到成功' : '签到成功');
    final subtitle = isHeartbeat
        ? '零操作守护 · 连续 $streak 天'
        : '🔥 连续 $streak 天 · 累计 $total 天';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 3),
        content: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isHeartbeat
                  ? [const Color(0xFFF857A6), const Color(0xFFFF5858)]
                  : [const Color(0xFF11998E), const Color(0xFF38EF7D)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(isHeartbeat ? '💓' : (isWatch ? '⌚' : '✅'), style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

      // 【P0 修复 v1.93.9】同步离线签到队列（断网时签到会保存到离线队列）
      try {
        if (kDebugMode) debugPrint('[HomePage] 开始同步离线签到队列...');
        final syncedCount = await CheckinService.syncOfflineQueue();
        if (syncedCount > 0) {
          if (kDebugMode) debugPrint('[HomePage] ✅ 离线队列同步完成，成功=$syncedCount');
          // 同步成功后，重新加载签到状态（获取最新的连续天数）
          await _loadCheckInStatus();
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[HomePage] ⚠️ 同步离线队列失败: $e');
      }
    }
    
    await _loadPendingPeaceRequests();
    await _loadInviteStats();
    
    // ====== 新增：检查并展示 DeepLink / welcome-pending 带来的守护卡仪式感 ======
    _checkAndShowGuardianRituals();

    // ====== 新增：执行健康数据静默同步（有心跳即签到） ======
    _syncHealthData();
  }

  /// 健康数据同步并发锁（防止前后台切换/初始化并发触发重复签到）
  bool _healthSyncInFlight = false;

  /// 同步健康数据（Apple Watch 心跳检测）
  Future<void> _syncHealthData() async {
    if (!_isLoggedIn) return;
    // 【修复 v1.95】防并发重复签到：初始化与 App 前后台切换均可能调用本方法
    if (_healthSyncInFlight) {
      if (kDebugMode) debugPrint('[HomePage] 健康同步进行中，跳过重复调用');
      return;
    }
    _healthSyncInFlight = true;
    try {
      // 延迟几秒执行，避免抢占首页初始化资源
      await Future.delayed(const Duration(seconds: 3));

      if (kDebugMode) debugPrint('[HomePage] 开始静默同步 HealthKit 数据...');
      await HealthService.performSilentHeartbeatCheckin();
      // 如果签到成功，刷新一下首页状态
      _loadCheckInStatus();
    } catch (e) {
      if (kDebugMode) debugPrint('[HomePage] 健康数据同步失败: $e');
    } finally {
      _healthSyncInFlight = false;
    }
  }

  /// 检查并展示守护卡欢迎仪式
  ///
  /// 【修复 ②+③】原逻辑仅依赖 App 内 pending_card_code 且用 bool 防重入，导致：
  ///  - 网页注册用户无待处理码 → 永不弹（②）
  ///  - App 后台被 DeepLink 唤起时仪式不触发（③）
  ///  - 先清 pending 再延时 1s、中途退后台 → 永久跳过（③）
  /// 新逻辑：
  ///  - 同时检查「DeepLink 待处理码」与「后端 welcome-pending 新绑定」两个来源
  ///  - 用本地 seen 集合（按 card_code）去重，新关系才弹，已弹过不重复
  ///  - 仪式排队展示，mounted 不可用时延后到 resume 再弹，不再因切后台永久丢失
  ///  - 热启动通过 DeepLinkService.onCardCodeReceived 即时触发
  Future<void> _checkAndShowGuardianRituals() async {
    if (!_isLoggedIn || !mounted) return;

    // 载入已见证集合（本地去重真相源）
    _seenRitualKeys.clear();
    _seenRitualKeys.addAll(await loadSeenRitualKeys());

    // 1) DeepLink 待处理码（App 内扫码/链接唤起）
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final code = prefs.getString('pending_card_code') ?? '';
    if (code.isNotEmpty) {
      try {
        final res = await CardService.checkCard(code);
        if (res['success'] == true) {
          _enqueueRitual({
            'cardCode': code,
            'senderName': res['sender_name']?.toString() ?? '你的好友',
            'senderAvatar': res['sender_avatar']?.toString(),
            'message': res['message']?.toString() ?? '想和你建立守护关系',
            'mode': 'welcome',
            'role': 'receiver',
          });
        }
      } catch (_) {
        // 检查失败忽略，等待下次重试
      }
    }

    // 2) 后端 welcome-pending（无 App 内码的来源，修复 ②+④）
    //    - receiver：我是收卡人 → 接收方欢迎仪式
    //    - sender：我是发卡人 → 守护成功正向激励飞轮
    for (final role in ['receiver', 'sender']) {
      try {
        final res = await CardService.welcomePending(role: role);
        if (res['success'] == true) {
          final list = (res['guardians'] as List<dynamic>?) ?? [];
          for (final g in list) {
            final gMap = g as Map<String, dynamic>;
            final gCode = (gMap['card_code']?.toString() ?? '').trim();
            if (gCode.isEmpty) continue;
            _enqueueRitual({
              'cardCode': gCode,
              'senderName': gMap['peer_name']?.toString() ?? '你的好友',
              'senderAvatar': gMap['peer_avatar']?.toString(),
              'message': gMap['message']?.toString() ?? '想和你建立守护关系',
              'mode': role == 'sender' ? 'success' : 'welcome',
              'role': role,
            });
          }
        }
      } catch (_) {
        // 网络失败忽略，等待下次重试（resume 时会再查）
      }
    }

    // 3) 展示队列
    _showNextRitual();
  }

  /// 将候选仪式入队（按 card_code 去重，已见证/已入队则跳过）
  void _enqueueRitual(Map<String, dynamic> cand) {
    final code = (cand['cardCode'] as String? ?? '').trim().toUpperCase();
    if (code.isEmpty) return;
    if (isRitualSeen(_seenRitualKeys, code)) return;
    if (_ritualQueue.any(
        (e) => (e['cardCode'] as String).trim().toUpperCase() == code)) {
      return;
    }
    _ritualQueue.add(cand);
  }

  /// 依次展示队列中的仪式；
  /// mounted 不可用时直接返回（由 resume 重试，不丢仪式）；
  /// 正在展示时也被拦截，防止后台/重复调用叠加弹窗。
  Future<void> _showNextRitual() async {
    if (!mounted || _isRitualShowing) return;
    if (_ritualQueue.isEmpty) return;
    // 在首个 await 前捕获 context，避免跨异步使用 BuildContext 的 lint / 隐患
    final ctx = context;

    _isRitualShowing = true;
    final cand = _ritualQueue.removeAt(0);
    final code = (cand['cardCode'] as String? ?? '').trim();
    final role = (cand['role'] as String?) ?? 'receiver';

    // 立即标记为已见证（落盘），即使中途被打断也不会重复弹
    await markRitualSeen(code);
    _seenRitualKeys.add('code:${code.toUpperCase()}');

    // 消费 DeepLink 待处理码
    await DeepLinkService.clearPendingCardCode();
    if (_prefs != null) await _prefs!.remove('pending_card_code');

    await showGuardianWelcomeRitual(
      ctx,
      senderName: cand['senderName'] as String,
      senderAvatar: cand['senderAvatar'] as String?,
      message: cand['message'] as String,
      cardCode: code,
      mode: (cand['mode'] as String?) ?? 'welcome',
      onClosed: () {
        _isRitualShowing = false;
        // 【修复 2026-07-12】服务端标记该关系已见证，防跨设备/重装重复弹
        CardService.welcomeAck(cardCode: code, role: role).catchError((_) {});
        _loadInviteStats();
        _showNextRitual(); // 继续展示队列中的下一个
      },
    );
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
    // 【修复 ③】注销前台 Deep Link 回调
    DeepLinkService.onCardCodeReceived = null;
    _animationController.dispose();
    HealthService.watchCheckinCompleteSignal.removeListener(_onWatchCheckinComplete);
    HealthService.watchCheckinCelebration.removeListener(_onWatchCheckinCelebration);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (kDebugMode) debugPrint('[HomePage] App resumed, triggering health sync...');
      _syncHealthData();
      // 【v1.97.3+191】回到前台即重载平安确认请求，避免切后台后请求横幅丢失
      _loadPendingPeaceRequests();
      // 【修复 ③】热启动：App 在后台被 DeepLink 唤起后回到前台，补查守护仪式
      _checkAndShowGuardianRituals();
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
      // TODO: 后续可用于显示守护人数量
      // int guardianCount = 0;
      // String? phone;
      // final contactsKey = (userId != null && userId.isNotEmpty)
      //     ? 'emergency_contacts_$userId'
      //     : 'emergency_contacts';
      // final contactsJson = prefs.getString(contactsKey);
      // if (contactsJson != null && contactsJson.isNotEmpty) {
      //   final contacts = jsonDecode(contactsJson) as List<dynamic>?;
      //   guardianCount = contacts?.length ?? 0;
      // }
      // phone = await AuthService.getUserPhone();
    } catch (_) {}

    setState(() {
      _isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      // 【修复 v1.90.1】立即设置签到状态，避免首次渲染闪现"未签到"
      _checkedInToday = checkedInToday;
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

    // 尝试获取用户 ID（异步），但不阻塞第一次 setState
    try {
      uid = (await AuthService.getUserId()) ?? '';
      // 如果用户已登录，优先使用用户隔离的键值
      if (uid.isNotEmpty) {
        final userSpecificDate = prefs.getString('last_check_in_date_$uid');
        if (userSpecificDate != null) {
          lastDate = userSpecificDate;
        }
      }
    } catch (_) {
      // 忽略，lastDate 已从全局缓存读取
    }

    if (!mounted) return;
    setState(() {
      // 【修复 v1.91.0】先设置本地读取的状态，避免闪烁
      _checkedInToday = lastDate == today;
      // 使用用户隔离的键值（如果已读取到）
      final totalKey = uid.isNotEmpty ? 'total_check_in_days_$uid' : 'total_check_in_days';
      final historyKey = uid.isNotEmpty ? 'checkin_history_$uid' : 'checkin_history';
      // 🔴【v1.97.2 根治首屏跳变】不再直接读 `continuous_days_$uid` 缓存。
      //
      // 旧行为：读缓存 → 缓存已被后端漂移值污染（如 6）→ 首屏渲染 6
      //        → 约 1s 后网络重算得到 3 → setState 跳变（用户可见闪烁）。
      // 新行为：直接用本地签到历史重算。SharedPreferences 是内存镜像、同步可读，
      //        **零延迟、首帧即正确**，从源头消除跳变；历史为空时才回退缓存（新用户 0）。
      _continuousDays = StreakUtil.readStreak(prefs, uid);
      _totalDays = prefs.getInt(totalKey) ?? 0;
      _weeklyDays = _calculateWeeklyDays(prefs, historyKey);
      // 【v1.97.2 根治首屏跳变】只在本地签到历史非空时标记就绪——
      // 有历史 = 有可靠数据可直算 streak，首帧即正确，无跳变。
      // 历史为空（新登录 / 首装 / 历史未同步）→ 保持 loading，
      // 等网络同步拉到历史后直接显示正确值，绝不闪现错误数字。
      final localHistory = prefs.getStringList(historyKey) ?? const <String>[];
      if (localHistory.isNotEmpty) _isCheckinDataReady = true;
    });

        // 同步服务器获取断签天数和签到状态（覆盖本地状态，确保准确性）
    if (_isLoggedIn) {
      try {
        final res = await CheckinService.getTodayStatus();
        if (res['success'] == true && mounted) {
          // 【P0 修复 v1.93.10】后端 streak 不可信时，强制从服务器拉取完整签到历史，再计算连续天数
          final serverStreak = res['streak'];
          int? localStreak;
          // 重新获取 uid 并构建 key（因为 streakKey 在 setState 内部定义，这里需要重新构建）
          final currentUid = (await AuthService.getUserId()) ?? '';
          final streakKey2 = currentUid.isNotEmpty ? 'continuous_days_$currentUid' : 'continuous_days';

          // 【v1.95.x 彻底修复】后端 streak 字段历史上多次返回 0（易错），不再作为可信来源。
          // 改为：无论后端 streak 是否可信，都先拉取并合并服务器签到历史到本地，
          // 再以"本地历史(已合并服务器)"为单一真相源重算连续天数。
          {
            if (kDebugMode) {
              debugPrint('=' * 60);
              debugPrint('[HomePage] 🔍 重新计算连续签到天数（后端 streak 不可信）');
              debugPrint('  [后端返回] streak=$serverStreak');
            }

            // 从服务器拉取完整签到历史（最多 365 天）
            try {
              if (kDebugMode) debugPrint('[HomePage] 📡 调用 getHistory(page=1, pageSize=365)...');
              final historyRes = await CheckinService.getHistory(page: 1, pageSize: 100);
              if (kDebugMode) {
                debugPrint('[HomePage] 📥 getHistory 响应:');
                debugPrint('  [success] ${historyRes['success']}');
                debugPrint('  [history] 类型=${historyRes['history']?.runtimeType}, 长度=${historyRes['history'] is List ? (historyRes['history'] as List).length : 'N/A'}');
                if (historyRes['history'] is List && (historyRes['history'] as List).isNotEmpty) {
                  debugPrint('  [history 前3条] ${(historyRes['history'] as List).take(3).toList()}');
                }
              }
              if (historyRes['success'] == true && historyRes['history'] != null) {
                final history = historyRes['history'] as List<dynamic>;
                if (kDebugMode) debugPrint('[HomePage] 📥 已拉取服务器签到历史 ${history.length} 条');

                // 归一化为 yyyy-MM-dd（兼容 '2026-07-10' 与 '2026-07-10T00:00:00' 两种格式，避免时区/格式差异导致解析失败）
                final serverDates = <String>{};
                for (final item in history) {
                  if (item is Map && item['date'] != null) {
                    final parsed = DateTime.tryParse(item['date'].toString());
                    if (parsed != null) {
                      serverDates.add(DateFormat('yyyy-MM-dd').format(parsed));
                    }
                  }
                }

                // 【稳健修复 v1.95.x】MERGE 而非覆盖：保留本地已有签到日期，
                // 仅当服务器非空时合并，避免"服务器空/缺历史"把本地记录清空→连续天数归零（历史反复回归根因）
                final uid = (await AuthService.getUserId()) ?? '';
                final historyKey = uid.isNotEmpty ? 'checkin_history_$uid' : 'checkin_history';
                final localDates = (prefs.getStringList(historyKey) ?? []).toSet();
                if (serverDates.isNotEmpty) {
                  localDates.addAll(serverDates);
                  await prefs.setStringList(historyKey, localDates.toList());
                  if (kDebugMode) debugPrint('[HomePage] ✅ 合并签到历史(本地+服务器) 共 ${localDates.length} 条');
                } else {
                  if (kDebugMode) debugPrint('[HomePage] ⚠️ 服务器历史为空，保留本地 ${localDates.length} 条，不清空');
                }
              } else {
                if (kDebugMode) debugPrint('[HomePage] ⚠️ 服务器签到历史返回失败: $historyRes（保留本地历史）');
              }
            } catch (e) {
              if (kDebugMode) debugPrint('[HomePage] ⚠️ 拉取签到历史失败: $e');
            }

            // 🔴【v1.97.2 根治】本地历史已 MERGE 服务器数据，以其为单一真相源重算并落盘对齐。
            // recalcAndPersist 语义：历史非空 → 无条件写回（含降低值，用于洗掉被后端污染的偏高缓存）；
            //                       历史为空 → 不写，返回原缓存（避免网络失败时把缓存毒化为 0）。
            final before = prefs.getInt(streakKey2) ?? 0;
            localStreak = await StreakUtil.recalcAndPersist(prefs, currentUid);
            if (kDebugMode && before != localStreak) {
              debugPrint('[HomePage] ✅ 连续天数已对齐真相源: 缓存 $before → 重算 $localStreak');
            }

            if (kDebugMode) debugPrint('=' * 60);
          }

          if (mounted) {
            setState(() {
              _totalDays = res['total_days'] ?? _totalDays;
              if (kDebugMode) {
                debugPrint('[HomePage] 📊 签到状态处理结果：');
                debugPrint('  [服务器 streak] $serverStreak');
                debugPrint('  [本地重新计算 streak] $localStreak');
                debugPrint('  [最终使用 streak] ${((serverStreak != null && (serverStreak as int) > 0) ? serverStreak : (localStreak ?? 0))}');
              }
              // 【v1.95.x 彻底修复】不再信任后端易错的 streak 字段，
              // 一律以本地签到历史(已合并服务器)重算值为准，根除天数偶发归零/显示 0
              _continuousDays = localStreak ?? 0;
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
          }
          // 同步到本地缓存（用户隔离 key）【修复 v1.77.0】
          // 注：连续天数缓存已由上方 StreakUtil.recalcAndPersist 落盘，此处不再重复写入，
          //     避免两处写入语义分叉（历史根因之一）。
          final totalKey = uid.isNotEmpty ? 'total_check_in_days_$uid' : 'total_check_in_days';
          final lastDateKey = uid.isNotEmpty ? 'last_check_in_date_$uid' : 'last_check_in_date';
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

  /// 【v1.95.0 彻底同步】委托 StreakUtil 统一计算，确保全 App 连续天数算法一致
  Future<int> _calculateStreakFromHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = (await AuthService.getUserId()) ?? '';
      final historyKey = uid.isNotEmpty ? 'checkin_history_$uid' : 'checkin_history';
      final history = prefs.getStringList(historyKey);
      if (history == null || history.isEmpty) return 0;
      return StreakUtil.calculateStreak(history);
    } catch (e) {
      if (kDebugMode) debugPrint('[HomePage] 本地计算连续天数失败: $e');
      return 0;
    }
  }

  /// 【修复 v1.97.2】与服务端对账签到状态：拉取服务端今日状态 + 签到历史，
  /// MERGE 到本地后从「本地历史」单一真相源重算连续天数，确保展示天数准确。
  /// 用于「今日已签到」弹窗等需在点击瞬间拿到准确天数的场景（首屏后台对账可能尚未完成）。
  Future<void> _reconcileCheckInFromServer() async {
    try {
      if (!_isLoggedIn) {
        final localStreak = await _calculateStreakFromHistory();
        if (mounted) setState(() => _continuousDays = localStreak);
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final uid = (await AuthService.getUserId()) ?? '';
      final streakKey = uid.isNotEmpty ? 'continuous_days_$uid' : 'continuous_days';
      final totalKey = uid.isNotEmpty ? 'total_check_in_days_$uid' : 'total_check_in_days';
      final historyKey = uid.isNotEmpty ? 'checkin_history_$uid' : 'checkin_history';

      final res = await CheckinService.getTodayStatus().timeout(const Duration(seconds: 3));
      if (res['success'] == true) {
        // 合并服务端历史到本地（MERGE 而非覆盖，保留本地已签到日期）
        try {
          final histRes = await CheckinService.getHistory(page: 1, pageSize: 100)
              .timeout(const Duration(seconds: 3));
          if (histRes['success'] == true && histRes['history'] != null) {
            final localDates = (prefs.getStringList(historyKey) ?? []).toSet();
            for (final item in histRes['history'] as List<dynamic>) {
              if (item is Map && item['date'] != null) {
                final parsed = DateTime.tryParse(item['date'].toString());
                if (parsed != null) localDates.add(DateFormat('yyyy-MM-dd').format(parsed));
              }
            }
            await prefs.setStringList(historyKey, localDates.toList());
          }
        } catch (e) {
          if (kDebugMode) debugPrint('[HomePage] 合并服务端历史失败（保留本地）: $e');
        }

        final localStreak = await _calculateStreakFromHistory();
        if (mounted) {
          setState(() {
            _continuousDays = localStreak;
            // 累计天数以服务端为准，但只增不减，避免偶发回退
            if (res['total_days'] != null && (res['total_days'] as int) > _totalDays) {
              _totalDays = res['total_days'] as int;
            }
            if (res.containsKey('checked_in_today')) {
              _checkedInToday = res['checked_in_today'] == true ? true : _checkedInToday;
            }
            _daysSinceLastCheckin = res['days_since_last_checkin'] ?? _daysSinceLastCheckin;
          });
        }
        await prefs.setInt(streakKey, localStreak);
        if (res['total_days'] != null) await prefs.setInt(totalKey, res['total_days'] as int);
      }
    } catch (e) {
      // 网络超时/失败：退化到本地历史重算，保证弹窗仍显示本地最优值
      if (kDebugMode) debugPrint('[HomePage] 对账失败，退化本地重算: $e');
      try {
        final localStreak = await _calculateStreakFromHistory();
        if (mounted) setState(() => _continuousDays = localStreak);
      } catch (_) {}
    }
  }

  Future<void> _handleCheckIn() async {
    // ===== [191] 双通道入口日志（收口：删除侵入式 SnackBar，保留文件/控制台通道）=====
    const _entryTag = '190 SIGN';
    final _entryMsg = '$_entryTag 入口 _isLoggedIn=$_isLoggedIn _checkedInToday=$_checkedInToday';
    await DebugLog.write(_entryTag, '入口 _isLoggedIn=$_isLoggedIn _checkedInToday=$_checkedInToday');
    developer.log(_entryMsg, name: 'zaine.sign');

    // 🔴【v1.97.7 根治，185 落地】不要让任何本地状态/prefs 残留/_isLoggedIn 假阴 阻塞 do_checkin。
    // FC 日志铁证：用户装 184 后仍是 0 条 do_checkin。说明仅靠 184 的 _checkedInToday && historySaysChecked
    // 还没覆盖全部场景：可能 _isLoggedIn=false 命中 line 908 if 跳过、或异常走入离线队列。
    // 新原则：**永远调用 do_checkin（仅做最弱的 UI 立即反馈），让服务端做唯一真相源**。
    // 服务端 already_checked_in = 正常已签到；其他错误才是真正的失败。
    // 用 print() 而非 debugPrint()：release 包也能在 Xcode 控制台看到诊断。
    final dbgPrefs0 = await SharedPreferences.getInstance();
    final dbgUid0 = (await AuthService.getUserId()) ?? '';
    final dbgLastKey0 = dbgUid0.isNotEmpty ? 'last_check_in_date_$dbgUid0' : 'last_check_in_date';
    final dbgHistKey0 = dbgUid0.isNotEmpty ? 'checkin_history_$dbgUid0' : 'checkin_history';
    developer.log('[190 SIGN] 入口 _isLoggedIn=$_isLoggedIn _checkedInToday=$_checkedInToday lastDate=${dbgPrefs0.getString(dbgLastKey0)} historyLen=${(dbgPrefs0.getStringList(dbgHistKey0) ?? const []).length}');

    // 若 _isLoggedIn=false，先尝试从 prefs 紧急重读 login 状态（避免状态滞后导致跳过）
    if (!_isLoggedIn) {
      developer.log('[190 SIGN] ⚠️ _isLoggedIn=false，尝试从 prefs 重读 is_logged_in...');
      try {
        final reloadPrefs = await SharedPreferences.getInstance();
        final reloadLoggedIn = reloadPrefs.getBool('is_logged_in') ?? false;
        if (reloadLoggedIn && mounted) {
          setState(() { _isLoggedIn = true; });
        }
        developer.log('[190 SIGN] 重读后 _isLoggedIn=$_isLoggedIn');
      } catch (e) {
        developer.log('[190 SIGN] 重读 prefs 异常: $e');
      }
    }

    // 仍未登录：弹提示并 return
    if (!_isLoggedIn) {
      developer.log('[190 SIGN] ❌ 仍未登录，do_checkin 跳过');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请先登录后再签到'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // ✅ 立即更新 UI —— 让用户第一时间看到已签到（不依赖任何后端结果）
    HapticFeedback.mediumImpact();

    // 【修复 v1.9.7】动画加异常保护
    try {
      _animationController.forward().then((_) {
        if (mounted) _animationController.reverse();
      });
    } catch (e) {
      // ignore
    }

    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);

    // 【v1.95.0 彻底同步】提前读取本地存储，连续天数从签到历史整体重算（单一真相源）
    final prefs = await SharedPreferences.getInstance();
    final uid = (await AuthService.getUserId()) ?? '';
    final streakKey = uid.isNotEmpty ? 'continuous_days_$uid' : 'continuous_days';
    final totalKey = uid.isNotEmpty ? 'total_check_in_days_$uid' : 'total_check_in_days';
    final historyKey = uid.isNotEmpty ? 'checkin_history_$uid' : 'checkin_history';
    final lastDateKey = uid.isNotEmpty ? 'last_check_in_date_$uid' : 'last_check_in_date';

    // [194 S] 解码 token，看后端会认成哪个 uid —— 直接戳穿多账号 token 错乱
    String _tokenUid = '未知';
    try {
      final _tk = await AuthService.getToken();
      if (_tk != null && _tk.contains('.')) {
        String _b = _tk.split('.')[1];
        while (_b.length % 4 != 0) _b += '=';
        final _p = jsonDecode(utf8.decode(base64Url.decode(_b))) as Map<String, dynamic>;
        _tokenUid = _p['user_id']?.toString() ?? '无user_id';
      } else {
        _tokenUid = '无token';
      }
    } catch (e) {
      _tokenUid = '解码异常:$e';
    }
    await DebugLog.write('194 S', '签到前 uid(本地)=${uid.isNotEmpty ? uid : "空"} tokenUid(后端将认)=$_tokenUid');

    int newTotal = _totalDays + 1;
    final historyList = List<String>.from(prefs.getStringList(historyKey) ?? []);
    if (!historyList.contains(today)) historyList.add(today);
    final newDays = StreakUtil.calculateStreak(historyList);

    // 【187 修复】不再本地乐观更新 UI / 不再提前持久化：
    // UI 与本地存储仅以服务端 do_checkin 响应为准，避免"本地显示已签到但云端没收到"的假象。
    // 持久化逻辑已移至下方 success 分支。

    // 📨 调用 do_checkin（**唯一真相源**）—— 不再做 if (_isLoggedIn) 包裹
    developer.log('[190 SIGN] 📨 调用 do_checkin date=$today uid=$uid');
    await DebugLog.write('194 S', '调用 do_checkin date=$today uid=$uid');
    try {
      final res = await CheckinService.checkIn(date: today, mood: -1);
      developer.log('[190 SIGN] 📨 do_checkin 响应: $res');
      await DebugLog.write('194 S', 'do_checkin 响应: $res');

      if (res['success'] == true) {
        developer.log('[190 SIGN] ✅ do_checkin 成功');
        await DebugLog.write('194 S', 'do_checkin 成功 res=$res');
        // 【187 修复】服务端确认后才更新 UI + 持久化（替代原本地乐观更新）
        if (mounted) setState(() {
          _checkedInToday = true;
          _continuousDays = newDays;
          _totalDays = newTotal;
          _weeklyDays++;
        });
        await prefs.setString(lastDateKey, today);
        await prefs.setString('last_check_in_date', today);
        // 【v1.97.1+155】手机签到成功后，同步签到状态到 Watch（修手表仍显示"可打卡"）
        unawaited(WatchDataService().pushCheckinStatus(checkedInToday: true, checkinDate: today));
        await prefs.setInt(streakKey, newDays);
        await prefs.setInt(totalKey, newTotal);
        await prefs.setStringList(historyKey, historyList);
        final serverTotal = res['total_days'] as int?;
        final serverStreak = res['streak'] as int? ?? res['continuous_days'] as int?;
        if (serverTotal != null && serverTotal > _totalDays) {
          await prefs.setInt(totalKey, serverTotal);
          if (mounted) setState(() => _totalDays = serverTotal);
        }
        if (serverStreak != null && serverStreak > 0 && newDays == 0) {
          await prefs.setInt(streakKey, serverStreak);
          if (mounted) setState(() => _continuousDays = serverStreak);
        }
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
        developer.log('[190 SIGN] ⚠️ do_checkin 业务错误: $errorMsg');
        await DebugLog.write('194 S', '业务错误: $errorMsg');
        if (errorMsg.contains('already_checked_in')) {
          // 服务端确认今日已签到，正常
          if (mounted) {
            setState(() => _checkedInToday = true);
            // 【v1.97.1+155】同步签到状态到 Watch
            unawaited(WatchDataService().pushCheckinStatus(checkedInToday: true, checkinDate: today));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('☀️ 今日已签到'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('签到已记录，云端同步失败: $errorMsg'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e, stack) {
      developer.log('[190 SIGN] ❌ do_checkin 异常: $e');
      await DebugLog.write('194 S', '异常: $e');
      developer.log(stack.toString(), name: 'zaine');
      // 【P0 修复 v1.93.9】签到失败时保存到离线队列
      try {
        await CheckinService.saveToOfflineQueue(date: today, mood: -1);
        developer.log('[190 SIGN] ✅ 已保存到离线队列');
      } catch (queueError) {
        developer.log('[190 SIGN] ⚠️ 离线队列保存失败: $queueError');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('签到已记录，已保存到离线队列，联网后自动同步 ☁️'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    // 签到成功：取消断签预警通知（id=1）
    try {
      final notifications = FlutterLocalNotificationsPlugin();
      await notifications.cancel(1);
    } catch (e) {
      // ignore
    }

    // 【养成闭环 v1.97.2】把签到天数同步到成就进度（仅海外版）
    if (!AppConfig.isChinaRegion && uid.isNotEmpty) {
      try {
        final svc = SocialService();
        await svc.updateAchievementProgress(uid, 'checkin_7', _continuousDays);
        await svc.updateAchievementProgress(uid, 'checkin_30', _continuousDays);
        await svc.updateAchievementProgress(uid, 'checkin_100', _totalDays);
      } catch (e) {
        // ignore
      }
    }

    // 弹出签到成功弹窗（断签回归时传 isReturnCheckin）
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
    } catch (e) {
      developer.log('[190 SIGN] 弹窗异常: $e');
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.pill)),
        title: const Row(
          children: [
            Icon(Icons.login, color: ZaiNeColors.brandOrange),
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
              backgroundColor: ZaiNeColors.brandOrange,
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
                onTap: () {
                  // [191] 收口：移除临时 TAP 诊断 SnackBar，仅保留文件日志（_handleCheckIn 内已含）
                  _handleCheckIn();
                },
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
                      borderRadius: BorderRadius.circular(ZaiNeRadius.card),
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
                            borderRadius: BorderRadius.circular(ZaiNeRadius.input),
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
        padding: EdgeInsets.all(ZaiNeSpacing.section),
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
                      // 月份标题（可点击，弹出月份选择器）
                      GestureDetector(
                        onTap: _showMonthPicker,
                        child: Column(
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
                  // 右侧按钮组
                  Row(
                    children: [
                      // 今天按钮（快速跳转到今天）
                      if (!_isTodayInCurrentMonth())
                        GestureDetector(
                          onTap: _jumpToToday,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.sm, vertical: ZaiNeSpacing.xs),
                            decoration: BoxDecoration(
                              color: ZaiNeColors.brandOrange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(ZaiNeRadius.input),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.today, size: 14, color: ZaiNeColors.brandOrange),
                                const SizedBox(width: 4),
                                Text(
                                  '今天',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                      color: ZaiNeColors.brandOrange),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // 今月按钮（回到当月）
                      if (_calendarMonthOffset != 0) ...[
                        if (!_isTodayInCurrentMonth()) const SizedBox(width: ZaiNeSpacing.xs),
                        GestureDetector(
                          onTap: () => setState(() => _calendarMonthOffset = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.md, vertical: ZaiNeSpacing.xs),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(ZaiNeRadius.input),
                            ),
                            child: Text(
                              '今月',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                  color: Colors.teal.shade700),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
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
                      borderRadius: BorderRadius.circular(ZaiNeRadius.button),
                      border: isToday
                          ? Border.all(color: ZaiNeColors.brandOrange, width: 1.5)
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

  /// 检查今天是否在当前显示的月份中
  bool _isTodayInCurrentMonth() {
    final now = DateTime.now();
    final targetDate = DateTime(now.year, now.month + _calendarMonthOffset);
    return targetDate.year == now.year && targetDate.month == now.month;
  }

  /// 跳转到今天所在的月份
  void _jumpToToday() {
    setState(() {
      _calendarMonthOffset = 0;
    });
  }

  /// 显示月份选择器
  Future<void> _showMonthPicker() async {
    final now = DateTime.now();
    int selectedYear = now.year + (_calendarMonthOffset > 0 ? 1 : 0);
    int selectedMonth = now.month + _calendarMonthOffset;
    
    // 修正年份和月份
    while (selectedMonth > 12) {
      selectedMonth -= 12;
      selectedYear++;
    }
    while (selectedMonth < 1) {
      selectedMonth += 12;
      selectedYear--;
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('选择月份', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 年份选择
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: selectedYear > now.year - 2
                        ? () => setDialogState(() => selectedYear--)
                        : null,
                  ),
                  Text('$selectedYear年', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: selectedYear < now.year + 1
                        ? () => setDialogState(() => selectedYear++)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: ZaiNeSpacing.md),
              // 月份选择网格
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                childAspectRatio: 1.5,
                children: List.generate(12, (index) {
                  final month = index + 1;
                  final isSelected = month == selectedMonth && selectedYear == now.year + (_calendarMonthOffset > 0 ? 1 : 0)
                      ? (now.month + _calendarMonthOffset == month)
                      : false;
                  final isCurrentMonth = month == now.month && selectedYear == now.year;
                  
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      final newOffset = (selectedYear - now.year) * 12 + month - now.month;
                      setState(() => _calendarMonthOffset = newOffset);
                    },
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? ZaiNeColors.brandOrange
                            : (isCurrentMonth ? ZaiNeColors.brandOrange.withValues(alpha: 0.1) : Colors.transparent),
                        borderRadius: BorderRadius.circular(ZaiNeRadius.button),
                      ),
                      child: Center(
                        child: Text(
                          '$month月',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected || isCurrentMonth ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? Colors.white : ZaiNeColors.textPrimary(),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
          ],
        ),
      ),
    );
  }

  Color? _getHeatmapColor(bool isCheckedIn) {
    if (!isCheckedIn) return null; // 透明/无背景
    // 简单的绿色深浅——后续可按连续天数做渐变
    return Colors.teal.shade400;
  }

  Widget _buildLegendItem(String text, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(
        color: color, borderRadius: BorderRadius.circular(ZaiNeRadius.tiny))),
      const SizedBox(width: ZaiNeSpacing.xs),
      Text(text, style: TextStyle(fontSize: 10, color: themeNotifier.mode == ZaiNeThemeMode.dark ? Colors.grey[400] : Colors.grey[500])),
      const SizedBox(width: ZaiNeSpacing.sm),
    ]);
  }

  Widget _buildLegendDot(Color color) {
    return Container(
      width: 10, height: 10,
      margin: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.xs),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(ZaiNeRadius.tiny)),
    );
  }

}
