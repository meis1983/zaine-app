import 'package:flutter/material.dart';
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
import '../utils/badge_generator.dart';

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
    await _loadCheckInStatus();
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
      debugPrint('[HomePage] 开始静默同步 HealthKit 数据...');
      await HealthService.performSilentHeartbeatCheckin();
      // 如果签到成功，刷新一下首页状态
      _loadCheckInStatus();
    } catch (e) {
      debugPrint('[HomePage] 健康数据同步失败: $e');
    }
  }

  /// 检查是否有待处理的守护卡（来自 Deep Link），并展示 3D 开封仪式
  Future<void> _checkPendingCardRitual() async {
    if (!_isLoggedIn) return;
    
    final hasPending = await DeepLinkService.hasPendingCardCode();
    if (!hasPending) return;

    final code = _prefs?.getString('pending_card_code') ?? '';
    if (code.isEmpty) return;

    try {
      final res = await CardService.checkCard(code);
      if (res['success'] == true && mounted) {
        final cardData = res;
        
        // 延迟 1 秒展示，等首页 UI 加载稳定
        await Future.delayed(const Duration(milliseconds: 1000));
        
        if (!mounted) return;
        
        await showGeneralDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black.withOpacity(0.9),
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
                onComplete: () {
                  // 【优化 v2.0】仪式感结束后，自动清理 pending 状态并刷新统计 (停留 3.5秒)
                  Future.delayed(const Duration(milliseconds: 3500), () {
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      _loadInviteStats();
                      // 仪式结束后，可以弹出一个简单的欢迎提示
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('守护关系已建立，感谢你的加入')),
                      );
                    }
                  });
                },
              ),
            );
          },
        );
      }
    } catch (e) {
      debugPrint('[HomePage] 仪式感加载失败: $e');
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
        debugPrint('[HomePage] ✅ 获取邀请统计: total_registered=$_totalRegistered');
      }
    } catch (e) {
      debugPrint('[HomePage] 加载邀请统计失败: $e');
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
      debugPrint('[HomePage] App resumed, triggering health sync...');
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
        debugPrint('[Home] 头像文件不存在，尝试从 base64 恢复...');
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
          debugPrint('[Home] ✅ 头像已从 base64 备份恢复');
        } catch (e) {
          debugPrint('[Home] ⚠️ base64 头像恢复失败: $e');
          await AvatarHelper.clear(prefs);
        }
      } else if (avatarPath != null && avatarPath.isNotEmpty) {
        debugPrint('[Home] 头像文件不存在，清除路径: $avatarPath');
        await AvatarHelper.clear(prefs);
      }
    }
    // 读取守护人数量（与 contacts_page.dart 保持一致的 key 规则）
    int guardianCount = 0;
    try {
      final userId = prefs.getString('user_id');
      final contactsKey = (userId != null && userId.isNotEmpty)
          ? 'emergency_contacts_$userId'
          : 'emergency_contacts';
      final contactsJson = prefs.getString(contactsKey);
      if (contactsJson != null && contactsJson.isNotEmpty) {
        final contacts = jsonDecode(contactsJson) as List<dynamic>?;
        guardianCount = contacts?.length ?? 0;
      }
    } catch (_) {}

    setState(() {
      _isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      // 【修复 v1.9.73】从 per‑user 档案读姓名，避免切账号串名
      String? userName;
      final uid = prefs.getString('user_id');
      if (uid != null && uid.isNotEmpty) {
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
      _userName = userName ?? prefs.getString('user_name') ?? prefs.getString('user_phone');
      _avatarPath = validAvatarPath;
      _guardianCount = guardianCount;
      _membershipLevel = MembershipService.getLevel();
    });
  }

  Future<void> _loadCheckInStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // 【修复】签到日期按用户隔离读取，与守护圈保持一致
    final uid = prefs.getString('user_id') ?? '';
    final lastDateKey = uid.isNotEmpty ? 'last_check_in_date_$uid' : 'last_check_in_date';
    final lastDate = prefs.getString(lastDateKey);

    if (!mounted) return;
    setState(() {
      // 【修复】签到数据按用户隔离读取，防止切换账号后状态污染
      final streakKey = uid.isNotEmpty ? 'continuous_days_$uid' : 'continuous_days';
      final totalKey = uid.isNotEmpty ? 'total_check_in_days_$uid' : 'total_check_in_days';
      final historyKey = uid.isNotEmpty ? 'checkin_history_$uid' : 'checkin_history';

      _checkedInToday = lastDate == today;
      if (lastDate != null) {
        try {
          _lastCheckIn = DateTime.parse(lastDate);
        } catch (_) {}
      }
      _continuousDays = prefs.getInt(streakKey) ?? 0;
      _totalDays = prefs.getInt(totalKey) ?? 0;
      // 计算本周签到天数
      _weeklyDays = _calculateWeeklyDays(prefs, historyKey);
    });

    // 同步服务器获取断签天数和签到状态
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
            // 【修复 v1.9.61】以服务端真实签到状态覆盖本地缓存（防止切换账号后状态污染）
            if (res.containsKey('checked_in_today')) {
              final serverChecked = res['checked_in_today'] == true;
              if (_checkedInToday != serverChecked) {
                _checkedInToday = serverChecked;
                debugPrint('[HomePage] ⚠️ 签到状态已修正: 本地=$_checkedInToday → 服务端=$serverChecked');
              }
            }
          });
          // 同步到本地缓存（用户隔离 key）
          final uid = prefs.getString('user_id') ?? '';
          final streakKey = uid.isNotEmpty ? 'continuous_days_$uid' : 'continuous_days';
          final totalKey = uid.isNotEmpty ? 'total_check_in_days_$uid' : 'total_check_in_days';
          final lastDateKey = uid.isNotEmpty ? 'last_check_in_date_$uid' : 'last_check_in_date';
          await prefs.setInt(streakKey, _continuousDays);
          await prefs.setInt(totalKey, _totalDays);
          if (_checkedInToday) {
            await prefs.setString(lastDateKey, today);
            await prefs.setString('last_check_in_date', today);
          }
          debugPrint('[HomePage] 服务器签到状态: totalDays=$_totalDays, daysSinceLastCheckin=$_daysSinceLastCheckin, checkedInToday=$_checkedInToday');
        }
      } catch (e) {
        debugPrint('[HomePage] 同步服务器签到状态失败: $e');
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
      debugPrint('[Home] 加载平安确认请求失败: $e');
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
      debugPrint('[Home] 确认平安失败: $e');
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
    if (_checkedInToday) {
      // 【修复 v1.9.72】服务端 UTC 时间与本地 UTC+8 可能存在日期偏差
      // 导致 _checkedInToday 被误设为 true，用户点击"签到"却无响应
      // 改为：仍弹出庆祝弹窗，不让用户体验断掉
      debugPrint('[HomePage] 今日已签到（可能为时区误判），显示庆祝弹窗');
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
            ),
          );
        }
      } catch (e, stack) {
        debugPrint('[HomePage] 弹窗显示异常: $e');
        debugPrint(stack.toString());
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
      debugPrint('[HomePage] 动画异常（忽略）: $e');
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
    final uid = prefs.getString('user_id') ?? '';
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
          debugPrint('[HomePage] 签到已同步到服务器: $res');
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
          debugPrint('[HomePage] 签到同步失败: $errorMsg');
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
        debugPrint('[HomePage] 签到同步异常（已本地保存）: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('签到已记录，网络异常暂未同步到云端'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
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
      debugPrint('[HomePage] 签到成功，已取消断签预警通知');
    } catch (e) {
      debugPrint('[HomePage] 取消断签预警通知失败（忽略）: $e');
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
          ),
        );
      }
    } catch (e, stack) {
      debugPrint('[HomePage] 弹窗显示异常: $e');
      debugPrint(stack.toString());
    }
  }

  void _openHelp() {
    debugPrint('[HomePage] 紧急求助卡片被点击，_isLoggedIn=$_isLoggedIn');
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
            SizedBox(width: 8),
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
              // ====== 顶部标题栏 ======
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 20),
                child: Row(
                  children: [
                    // Logo
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/images/zaine_logo_home.png',
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // 问候语 + 签到状态
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Text(
                                '在呢',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFF7F50),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // 签到状态胶囊
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _checkedInToday
                                      ? Colors.green.shade50
                                      : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _checkedInToday
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked,
                                      size: 12,
                                      color: _checkedInToday
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _checkedInToday ? '已签到' : '未签到',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: _checkedInToday
                                            ? Colors.green
                                            : Colors.orange,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              // 会员等级标签
                              GestureDetector(
                                onTap: _openSubscription,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    gradient: _membershipLevel == 'smart'
                                        ? const LinearGradient(
                                            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          )
                                        : LinearGradient(
                                            colors: [
                                              Colors.orange.shade300,
                                              Colors.orange.shade400,
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _membershipLevel == 'smart'
                                            ? Icons.auto_awesome
                                            : Icons.shield_outlined,
                                        size: 10,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        _membershipLevel == 'smart' ? '智能版' : '体验版',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 头像
                    GestureDetector(
                      onTap: _openProfile,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: _avatarPath == null
                              ? LinearGradient(
                                  colors: [
                                    const Color(0xFFFF7F50).withOpacity(0.2),
                                    const Color(0xFFFFB347).withOpacity(0.2),
                                  ],
                                )
                              : null,
                          color: _avatarPath == null ? null : null,
                          image: _avatarPath != null && _avatarPath!.isNotEmpty
                              ? DecorationImage(
                                  image: _avatarPath!.startsWith('/')
                                      ? FileImage(File(_avatarPath!))
                                      : AssetImage(_avatarPath!) as ImageProvider,
                                  fit: BoxFit.cover,
                                )
                              : null,
                          border: Border.all(
                            color: const Color(0xFFFF7F50).withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: _avatarPath == null
                            ? Icon(
                                _isLoggedIn ? Icons.person : Icons.person_add,
                                color: const Color(0xFFFF7F50),
                                size: 24,
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),

              // ====== 平安确认请求横幅（守护者发来的） ======
              if (_pendingPeaceRequests.isNotEmpty) ...[
                for (final req in _pendingPeaceRequests)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF7C4DFF), Color(0xFF9C27B0)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF7C4DFF).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.favorite, color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${req['guardian_name'] ?? "守护者"} 想确认你是否平安',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '点击下方按钮让他们安心',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => _confirmPeace(req['request_id'] ?? 0),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text('我平安', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _pendingPeaceRequests.removeWhere((r) => r['request_id'] == req['request_id']);
                            });
                          },
                          icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
              ],

              // ====== 健康档案提示（v1.9.8 隐藏）=====
              // 根因：与紧急求助卡片前置引导重复（点击紧急求助会自动引导完善档案/守护人/位置授权），
              //       视觉冗余且造成界面混乱。保留代码以便后续需要时恢复。
              // if (!_isLoggedIn)
              //   Container(
              //     margin: const EdgeInsets.only(bottom: 16),
              //     padding:
              //         const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              //     decoration: BoxDecoration(
              //       color: Colors.orange.shade50,
              //       borderRadius: BorderRadius.circular(12),
              //       border: Border.all(color: Colors.orange.shade200),
              //     ),
              //     child: Row(
              //       children: [
              //         Icon(Icons.info_outline,
              //             color: Colors.orange.shade700, size: 18),
              //         const SizedBox(width: 8),
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
              _buildHelpCard(),

              const SizedBox(height: 16),

              // ====== 守护状态 ======
              _buildGuardStatus(),

              const SizedBox(height: 20),

              // ====== 签到按钮 ======
              _buildCheckInButton(),

              const SizedBox(height: 20),

              // ====== 底部三列统计 ======
              _buildStatsRow(),

              const SizedBox(height: 20),

              // ====== 签到日历热力图 ======
              _buildCheckInCalendar(),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// 守护状态条
  Widget _buildGuardStatus() {
    // 【P2】显示历史最高连续纪录，减少断签心理落差
    String statusText = _isLoggedIn
        ? '守护已就绪 · $_continuousDays 天连续守护'
        : '请完善健康档案，开启守护';
    
    // 【v2.0 新增】显示守护圈人数
    if (_isLoggedIn && _totalRegistered > 0) {
      statusText += ' · $_totalRegistered 位守护成员';
    } else if (_isLoggedIn && _guardianCount > 0) {
      statusText += ' · $_guardianCount 位守护者';
    }

    final statusColor = _isLoggedIn ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, color: statusColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 13,
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (_isLoggedIn)
            Icon(Icons.check_circle, color: statusColor, size: 16),
        ],
      ),
    );
  }

  /// 紧急求助卡片
  Widget _buildHelpCard() {
    return GestureDetector(
      onTap: _openHelp,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFF4757),
              Color(0xFFFF6B81),
              Color(0xFFFF4757),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF4757).withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // 求助图标
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emergency,
                size: 32,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            // 文字
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '紧急求助',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isLoggedIn ? '点击发送紧急求助' : '请先完善健康档案',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            // 箭头
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withOpacity(0.6),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  /// 签到按钮
  Widget _buildCheckInButton() {
    // 【P3】统一使用 BadgeGenerator.getLevel，避免重复维护50级映射
    final badgeLevel = BadgeGenerator.getLevel(_continuousDays);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(90),
          onTap: _handleCheckIn,
          onTapDown: (_) => HapticFeedback.lightImpact(),
          child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            );
          },
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _checkedInToday
                    ? [Colors.teal.shade400, Colors.green.shade500]
                    : [const Color(0xFFFF7F50), const Color(0xFFFF6B3D)],
              ),
              boxShadow: [
                BoxShadow(
                  color: (_checkedInToday
                          ? Colors.teal.shade300
                          : const Color(0xFFFF7F50))
                      .withOpacity(_checkedInToday ? 0.25 : 0.4),
                  blurRadius: _checkedInToday ? 20 : 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 【P3】徽章等级图标 — 连续签到 >=1 天即显示徽章
                if (_continuousDays >= 1)
                  Text(
                    badgeLevel.emoji,
                    style: const TextStyle(fontSize: 28),
                  )
                else
                  Icon(
                    _checkedInToday ? Icons.check_circle : Icons.touch_app,
                    size: 44,
                    color: Colors.white,
                  ),
                const SizedBox(height: 4),
                Text(
                  _checkedInToday ? '今日已签到' : '点击签到',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                // 【P3】连续签到 >=1 天即显示徽章和天数
                if (_continuousDays >= 1) ...[
                  const SizedBox(height: 2),
                  Text(
                    badgeLevel.title,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.85),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '连续 $_continuousDays 天',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  /// 底部三列统计
  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatItem(
          icon: Icons.local_fire_department,
          iconColor: Colors.orange,
          label: '连续签到',
          value: '$_continuousDays 天',
          bgColor: Colors.orange.shade50,
        ),
        const SizedBox(width: 12),
        _buildStatItem(
          icon: Icons.calendar_today,
          iconColor: Colors.blue,
          label: '累计签到',
          value: '$_totalDays 天',
          bgColor: Colors.blue.shade50,
        ),
        const SizedBox(width: 12),
        _buildStatItem(
          icon: Icons.pie_chart,
          iconColor: Colors.teal,
          label: '本周进度',
          value: '$_weeklyDays/7',
          bgColor: Colors.teal.shade50,
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color bgColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: ZaiNeColors.cardBg(),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                color: Colors.black.withOpacity(0.03),
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
                      const SizedBox(width: 4),
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
                      const SizedBox(width: 4),
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
              const SizedBox(height: 14),

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
                        if (i < 6) const SizedBox(width: 4),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 日历网格
                  ..._buildCalendarRows(days, checkinHistory),
                ],
              ),

              const SizedBox(height: 10),

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
          cells.add(const Expanded(child: SizedBox(height: 28)));
        }
      }

      for (int col = 0; col < 7; col++) {
        final index = row * 7 + col - (firstWeekday - 1);
        if (index < 0 || index >= days.length) {
          cells.add(const Expanded(child: SizedBox(height: 28)));
        } else {
          final day = days[index];
          final dateStr = DateFormat('yyyy-MM-dd').format(day);
          final isCheckedIn = checkinHistory.contains(dateStr);
          final isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == dateStr;

          cells.add(
            Expanded(
              child: Container(
                height: 28,
                margin: const EdgeInsets.symmetric(horizontal: 1),
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
              if (i < cells.length - 1) const SizedBox(width: 4),
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
      const SizedBox(width: 3),
      Text(text, style: TextStyle(fontSize: 10, color: themeNotifier.mode == ZaiNeThemeMode.dark ? Colors.grey[400] : Colors.grey[500])),
      const SizedBox(width: 8),
    ]);
  }

  Widget _buildLegendDot(Color color) {
    return Container(
      width: 10, height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return '夜深了';
    if (hour < 12) return '早上好';
    if (hour < 14) return '中午好';
    if (hour < 18) return '下午好';
    return '晚上好';
  }
}
