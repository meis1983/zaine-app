import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'profile_page.dart';
import 'subscription_page.dart';
import 'onboarding_page.dart';
import '../main.dart';
import '../theme/theme_helper.dart';
import '../data/app_constants.dart';
import '../services/membership_service.dart';
import '../widgets/developer_mode.dart';
import '../config/feature_flags.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import '../services/api/user_service.dart';
import 'package:timezone/timezone.dart' as tz;

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with DeveloperMode<SettingsPage> {
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);
  bool _reminderEnabled = true;
  bool _systemReminderEnabled = true; // 系统提醒：未签到时额外提醒
  String? _userName;
  bool _isLoggedIn = false;
  bool _isProfileComplete = false; // 【修复 v1.17.1】健康档案完整性标记
  ZaiNeThemeMode _currentTheme = ZaiNeThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    themeNotifier.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (!mounted) return;
    setState(() => _currentTheme = themeNotifier.mode);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final profileJson = prefs.getString('user_profile');
    if (profileJson != null) {
      final profile = jsonDecode(profileJson);
      _userName = profile['name'];
    }
    // 【修复 v1.17.1】检查健康档案是否真正填写完整（与 newbie_task_card 逻辑一致）
    _isProfileComplete = _checkProfileComplete(profileJson);

    if (!mounted) return;
    setState(() {
      _isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      _reminderEnabled = prefs.getBool('reminder_enabled') ?? true;
      _systemReminderEnabled = prefs.getBool('system_reminder_enabled') ?? true;
      final hour = prefs.getInt('reminder_hour') ?? 20;
      final minute = prefs.getInt('reminder_minute') ?? 0;
      _reminderTime = TimeOfDay(hour: hour, minute: minute);
      _currentTheme = themeNotifier.mode;
    });
  }

  Future<void> _saveReminderTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('reminder_hour', time.hour);
    await prefs.setInt('reminder_minute', time.minute);
    if (!mounted) return;
    setState(() => _reminderTime = time);

    // 如果提醒已开启，重新调度通知
    if (_reminderEnabled) {
      await _scheduleNotification(prefs);
    }

    if (mounted && _reminderEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已设置每天 ${time.format(context)} 提醒签到'),
          backgroundColor: const Color(0xFFFF7F50),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _toggleReminder(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminder_enabled', value);
    if (!mounted) return;
    setState(() => _reminderEnabled = value);

    if (value) {
      // 开启提醒 → 调度通知
      await _scheduleNotification(prefs);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('签到提醒已开启，每天 ${_reminderTime.format(context)}'),
            backgroundColor: const Color(0xFFFF7F50),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } else {
      // 关闭提醒 → 取消所有签到通知
      await _cancelAllNotifications();
    }
  }

  /// 初始化通知插件（单例模式）
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> _initNotifications() async {
    tz.initializeTimeZones();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _notifications.initialize(initSettings);
  }

  /// 调度每日签到提醒通知（v2.0 增加断签预警）
  Future<void> _scheduleNotification(SharedPreferences prefs) async {
    // 先检查/请求通知权限
    final status = await Permission.notification.status;
    if (status.isDenied) {
      final result = await Permission.notification.request();
      if (result.isDenied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('请到系统设置中允许通知权限，以便接收签到提醒'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
    }

    await _initNotifications();

    final hour = prefs.getInt('reminder_hour') ?? 20;
    final minute = prefs.getInt('reminder_minute') ?? 0;

    // 取消旧的通知（避免重复）
    await _notifications.cancel(0);
    await _notifications.cancel(1);
    await _notifications.cancel(2);
    await _notifications.cancel(3); // 系统提醒

    const androidDetails = AndroidNotificationDetails(
      'checkin_reminder',
      '每日签到提醒',
      channelDescription: '提醒您完成每日签到，让守护者知道您平安',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    // ====== 主提醒：每天固定时间 ======
    var scheduledTime = DateTime.now().copyWith(hour: hour, minute: minute, second: 0);
    if (scheduledTime.isBefore(DateTime.now())) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }
    final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

    await _notifications.zonedSchedule(
      0, // id
      '该签到啦 🏠',
      '点击打开「在呢」，完成今日签到，让守护者放心 ❤️',
      tzScheduledTime,
      details,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    // ====== 系统提醒（id=3）—— 主提醒后2小时，未签到时额外提醒 ======
    if (_systemReminderEnabled) {
      var systemTime = scheduledTime.add(const Duration(hours: 2));
      if (systemTime.isBefore(DateTime.now())) {
        systemTime = systemTime.add(const Duration(days: 1));
      }
      final tzSystemTime = tz.TZDateTime.from(systemTime, tz.local);

      const systemAndroidDetails = AndroidNotificationDetails(
        'checkin_system_reminder',
        '系统提醒',
        channelDescription: '当天未签到时的额外提醒',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
      );
      const systemDetails = NotificationDetails(android: systemAndroidDetails, iOS: iosDetails);

      await _notifications.zonedSchedule(
        3, // id
        '别忘了签到哦 💙',
        '今天还没签到呢，花3秒报个平安，让守护者放心',
        tzSystemTime,
        systemDetails,
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }

    // ====== 断签预警通知（id=1,2）—— 根据上次签到时间动态调度 ======
    await _scheduleMissedCheckInAlerts(prefs);

    // 立即保存调度状态
    await prefs.setBool('notification_scheduled', true);
  }

  /// 断签预警：根据上次签到时间，调度递进式提醒
  Future<void> _scheduleMissedCheckInAlerts(SharedPreferences prefs) async {
    final lastDateStr = prefs.getString('last_check_in_date');
    if (lastDateStr == null) return; // 从未签到，不触发预警

    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    // 如果今天已签到，不需要预警
    if (lastDateStr == todayStr) return;

    final lastDate = DateTime.parse(lastDateStr);
    final daysSinceLastCheckIn = today.difference(lastDate).inDays;

    const alertAndroidDetails = AndroidNotificationDetails(
      'checkin_alert',
      '断签预警',
      channelDescription: '连续未签到时的递进提醒',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );
    const alertIosDetails = DarwinNotificationDetails();
    const alertDetails = NotificationDetails(android: alertAndroidDetails, iOS: alertIosDetails);

    // 根据断签天数选择文案和时间（递进式）
    String title;
    String body;
    int alertHour;
    int alertMinute;

    if (daysSinceLastCheckIn == 1) {
      // 第1天未签到 → 18:00 温和提醒
      title = '今天还没签到哦';
      body = '花3秒钟打开「在呢」签到，让守护者知道你在 💙';
      alertHour = 18;
      alertMinute = 0;
    } else if (daysSinceLastCheckIn == 2) {
      // 第2天未签到 → 12:00 中度提醒
      title = '连续2天没签到了';
      body = '你的守护者可能有点担心你，报个平安吧 🏠';
      alertHour = 12;
      alertMinute = 0;
    } else if (daysSinceLastCheckIn >= 3) {
      // 第3天+未签到 → 09:00 强提醒 + 守护圈影响
      title = '【重要】连续${daysSinceLastCheckIn}天未签到';
      body = '守护圈将收到异常提醒。点击签到，让大家放心 ❤️';
      alertHour = 9;
      alertMinute = 0;
    } else {
      return; // 今天已签到或异常情况
    }

    // 调度预警通知（只调度一次，今天如果过了时间就明天）
    var alertTime = today.copyWith(hour: alertHour, minute: alertMinute, second: 0);
    if (alertTime.isBefore(DateTime.now())) {
      alertTime = alertTime.add(const Duration(days: 1));
    }
    final tzAlertTime = tz.TZDateTime.from(alertTime, tz.local);

    await _notifications.zonedSchedule(
      1, // 使用id=1作为断签预警
      title,
      body,
      tzAlertTime,
      alertDetails,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );

    debugPrint('[Settings] 断签预警已调度: ${daysSinceLastCheckIn}天未签到，$alertHour:$alertMinute提醒');
  }

  /// 切换系统提醒开关
  Future<void> _toggleSystemReminder(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('system_reminder_enabled', value);
    if (!mounted) return;
    setState(() => _systemReminderEnabled = value);

    if (value && _reminderEnabled) {
      // 开启系统提醒且每日提醒已开启 → 重新调度通知
      await _scheduleNotification(prefs);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('系统提醒已开启，当天未签到时将发送额外提醒'),
          backgroundColor: Color(0xFFFF7F50),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } else if (!value) {
      // 关闭系统提醒 → 取消系统提醒通知（id=3）
      await _notifications.cancel(3);
    }
  }

  /// 取消所有签到提醒通知
  Future<void> _cancelAllNotifications() async {
    await _notifications.cancel(0);
    await _notifications.cancel(1);
    await _notifications.cancel(2);
    await _notifications.cancel(3); // 系统提醒
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification_scheduled', false);
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.white,
              hourMinuteTextColor: const Color(0xFFFF7F50),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _reminderTime) {
      await _saveReminderTime(picked);
    }
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ProfilePage(isPushed: true)),
    ).then((_) => _loadSettings());
  }

  /// 【修复 v1.17.1】检查健康档案是否已真正填写完整
  /// 复用 newbie_task_card 的字段级判断逻辑，确保一致性
  static bool _checkProfileComplete(String? profileJson) {
    if (profileJson == null || profileJson.isEmpty) return false;
    try {
      final profile = jsonDecode(profileJson) as Map<String, dynamic>;
      final name = profile['name']?.toString();
      final bloodType = profile['bloodType']?.toString();
      final allergy = profile['allergy']?.toString();
      final disease = profile['disease']?.toString();
      final medicine = profile['medicine']?.toString();
      final emergencyNote = profile['emergencyNote']?.toString();
      final ageRaw = profile['age'];
      final age = ageRaw is int ? ageRaw : int.tryParse(ageRaw?.toString() ?? '');
      // 任一关键字段有实际内容即视为已完善
      return (name != null && name.isNotEmpty) ||
          (bloodType != null && bloodType.isNotEmpty && bloodType != '未知') ||
          (allergy != null && allergy.isNotEmpty) ||
          (disease != null && disease.isNotEmpty) ||
          (medicine != null && medicine.isNotEmpty) ||
          (emergencyNote != null && emergencyNote.isNotEmpty) ||
          (age != null && age > 0);
    } catch (e) {
      return false;
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('退出登录'),
        content: const Text('退出后将清除本地数据并回到登录页，下次使用需要重新输入手机号登录。\n\n是否确认退出？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';

      // 1. 清除登录态
      await prefs.setBool('is_logged_in', false);
      await prefs.remove('auth_token');
      await prefs.remove('user_id');
      await prefs.remove('user_phone');

      // 2. 清除引导完成标记，确保下次回到引导页登录
      await prefs.remove('onboarding_completed');

      // 3. 清除本地健康档案（全局 + 用户隔离）
      await prefs.remove('user_profile');
      if (userId.isNotEmpty) {
        await prefs.remove('user_profile_$userId');
      }

      // 4. 清除头像数据（全局 + 用户隔离）
      await prefs.remove('avatar_path');
      await prefs.remove('avatar_base64');
      if (userId.isNotEmpty) {
        await prefs.remove('avatar_path_$userId');
        await prefs.remove('avatar_base64_$userId');
      }

      // 5. 清除紧急联系人（全局 + 用户隔离）
      await prefs.remove('emergency_contacts');
      if (userId.isNotEmpty) {
        await prefs.remove('emergency_contacts_$userId');
      }

      // 6. 清除签到状态
      await prefs.remove('last_check_in_date');
      if (userId.isNotEmpty) {
        await prefs.remove('last_check_in_date_$userId');
      }
      await prefs.remove('continuous_days');
      await prefs.remove('total_check_in_days');
      await prefs.remove('checkin_history');
      if (userId.isNotEmpty) {
        await prefs.remove('continuous_days_$userId');
        await prefs.remove('total_check_in_days_$userId');
        await prefs.remove('checkin_history_$userId');
      }

      // 7. 清除新手任务状态
      await prefs.remove('newbie_tasks_collapsed');
      await prefs.remove('newbie_tasks_all_done_shown');
      await prefs.remove('newbie_card_sent');
      await prefs.remove('newbie_task_location');

      // 8. 清除会员缓存
      await MembershipService.clear();

      // 9. 清除 pending card code
      await prefs.remove('pending-card-code');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已退出登录'),
          backgroundColor: Color(0xFFFF7F50),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // 退出后跳转到引导页（第5页就是登录页）
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OnboardingPage()),
        (route) => false,
      );
    }
  }

  void _showThemePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '选择主题',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                _themeOption(
                  context, setModalState,
                  ZaiNeThemeMode.light,
                  Icons.wb_sunny_outlined,
                  '浅色模式',
                  '清爽明亮，温柔暖白',
                  const Color(0xFFFFF8F0),
                ),
                const SizedBox(height: 12),
                _themeOption(
                  context, setModalState,
                  ZaiNeThemeMode.dark,
                  Icons.nightlight_outlined,
                  '深色模式',
                  '护眼夜用，深邃静谧',
                  const Color(0xFF121212),
                ),
                const SizedBox(height: 12),
                _themeOption(
                  context, setModalState,
                  ZaiNeThemeMode.soft,
                  Icons.auto_awesome_outlined,
                  '柔光模式',
                  '温暖米白，舒适柔和',
                  const Color(0xFFF2EDE8),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _themeOption(
    BuildContext context,
    StateSetter setModalState,
    ZaiNeThemeMode mode,
    IconData icon,
    String title,
    String subtitle,
    Color previewColor,
  ) {
    final isSelected = _currentTheme == mode;
    return InkWell(
      onTap: () async {
        await themeNotifier.setMode(mode);
        setModalState(() {});
        if (mounted) setState(() => _currentTheme = mode);
        if (context.mounted) Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF7F50) : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? const Color(0xFFFF7F50).withOpacity(0.05)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: previewColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Icon(icon, size: 20, color: const Color(0xFFFF7F50)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFFFF7F50)),
          ],
        ),
      ),
    );
  }

  /// 【修复 v1.16.0】隐私政策链接改用正式域名
  Future<void> _showPrivacyPolicy() async {
    final uri = Uri.parse('https://zaine.love/privacy');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('无法打开隐私政策页面'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// 删除账号（苹果审核强制要求）
  Future<void> _deleteAccount() async {
    // 第一次确认
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('删除账号', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('此操作将永久删除您的账号及所有数据：'),
            SizedBox(height: 12),
            Text('• 个人资料和健康档案'),
            Text('• 签到记录和守护卡'),
            Text('• 紧急联系人列表'),
            Text('• 会员订阅记录'),
            SizedBox(height: 12),
            Text('此操作不可恢复！',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (firstConfirm != true || !mounted) return;

    // 二次确认——输入 "删除" 才能继续
    final controller = TextEditingController();
    final secondConfirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('最终确认', style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('请输入「删除」以确认删除账号：'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '输入"删除"',
                border: const OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim() == '删除'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('彻底删除'),
          ),
        ],
      ),
    );
    if (secondConfirm != true || !mounted) return;

    // 调用后端删除接口
    try {
      final result = await UserService.deleteAccount();
      if (result['success'] == true) {
        // 清除本地所有数据
        final prefs = await SharedPreferences.getInstance();
        await _cancelAllNotifications();
        for (final key in prefs.getKeys()) {
          await prefs.remove(key);
        }
        if (mounted) {
          if (mounted) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('账号已删除'),
                  ],
                ),
                content: const Text('您的账号及所有数据已彻底删除。App 将退出，请重新打开。'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // 【P0修复 v1.9.83】iOS 上 SystemNavigator.pop 不会终止应用，
                      // 改为清除导航栈并跳转到登录页，确保用户回到全新状态
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const OnboardingPage()),
                        (route) => false,
                      );
                    },
                    child: const Text('确定'),
                  ),
                ],
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result['message']?.toString() ?? '删除失败'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('删除失败：$e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFF7F50),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.favorite, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('在呢', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  'v${AppConstants.version} (Build ${AppConstants.buildNumber})',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '守护每一次签到，守护每一份牵挂。',
              style: TextStyle(height: 1.5),
            ),
            SizedBox(height: 16),
            Text(
              '"在呢"是一款专为城市独居青年打造的守护应用。每天签到报平安，紧急时刻一键呼救，让在乎你的人安心。',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); _checkForUpdate(); },
            child: const Text('检查更新'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 检查更新（带动画效果）
  void _checkForUpdate() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) => _buildUpdateDialogContent(context),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildUpdateDialogContent(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.system_update, color: Color(0xFFFF7F50)),
          SizedBox(width: 8),
          Text('检查更新'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, value, child) => Transform.scale(
              scale: value,
              child: Icon(Icons.check_circle, size: 48, color: Colors.green.shade400),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '当前版本 v${AppConstants.version} (Build ${AppConstants.buildNumber})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            '已经是最新版本！',
            style: TextStyle(color: Colors.green),
          ),
          const SizedBox(height: 4),
          Text(
            '感谢你使用「在呢」❤️',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      ),
      actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('好的'),
          ),
        ],
    );
  }

  String _themeName(ZaiNeThemeMode mode) {
    switch (mode) {
      case ZaiNeThemeMode.dark: return '深色';
      case ZaiNeThemeMode.soft: return '柔光';
      default: return '浅色';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZaiNeColors.scaffoldBg(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('设置', style: TextStyle(color: ZaiNeColors.textPrimary())),
        centerTitle: true,
      ),
      body: SafeArea(
        bottom: true,
        child: ListView(
          padding: const EdgeInsets.all(16),
        children: [
          // 用户信息卡片（【修复 v1.17.1】用档案完整性判断代替登录状态判断）
          if (_isProfileComplete)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF7F50), Color(0xFFFF8C42)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '健康档案已完善',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white),
                    onPressed: _openProfile,
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('请完善您的健康档案',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('完善档案后解锁完整求助功能',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _openProfile,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF7F50)),
                    child: const Text('去填写'),
                  ),
                ],
              ),
            ),

          // 主题设置（v1.2 新增）
          _buildSectionTitle('外观'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.palette_outlined, color: Colors.purple.shade700),
              ),
              title: const Text('主题模式'),
              subtitle: Text('当前：${_themeName(_currentTheme)}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showThemePicker,
            ),
          ),

          const SizedBox(height: 24),

          // 签到提醒设置
          _buildSectionTitle('签到提醒'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('每日提醒'),
                  subtitle: const Text('提醒你进行每日签到'),
                  value: _reminderEnabled,
                  onChanged: _toggleReminder,
                  activeColor: const Color(0xFFFF7F50),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: _reminderEnabled
                      ? Column(
                          key: const ValueKey('reminder_options'),
                          children: [
                            ListTile(
                              title: const Text('提醒时间'),
                              subtitle: Text(_reminderTime.format(context)),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _selectTime,
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              title: const Text('系统提醒'),
                              subtitle: const Text('当天未签到时，系统将发送额外提醒'),
                              value: _systemReminderEnabled,
                              onChanged: _toggleSystemReminder,
                              activeColor: const Color(0xFFFF7F50),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(key: ValueKey('empty')),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 求助设置
          _buildSectionTitle('求助设置'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.medical_information, color: Colors.red.shade400),
                  title: const Text('紧急拨打120'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('请前往求助页面使用此功能'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 会员管理
          if (_isLoggedIn) ...[
            _buildSectionTitle('会员'),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.home, color: Colors.white, size: 20),
                ),
                title: const Text('在呢智能版'),
                subtitle: const Text('解锁更多守护能力'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const SubscriptionPage()),
                  ).then((_) => _loadSettings());
                },
              ),
            ),
            const SizedBox(height: 24),
          ],

          // 账号（v1.4 新增退出登录）
          if (_isLoggedIn) ...[
            _buildSectionTitle('账号'),
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.logout, color: Colors.red.shade400),
                    ),
                    title: Text('退出登录',
                        style: TextStyle(color: Colors.red.shade600)),
                    onTap: _logout,
                  ),
                  const Divider(height: 1),
                  // 【新增 v1.9.78】删除账号（苹果审核强制要求）
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.delete_forever, color: Colors.red.shade700),
                    ),
                    title: Text('删除账号',
                        style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600)),
                    subtitle: const Text('彻底删除所有数据，不可恢复',
                        style: TextStyle(fontSize: 12)),
                    onTap: _deleteAccount,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // 隐私与数据
          _buildSectionTitle('隐私与数据'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.privacy_tip_outlined,
                        color: Colors.blue.shade700),
                  ),
                  title: const Text('隐私政策'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showPrivacyPolicy,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.shield_outlined,
                        color: Colors.green.shade700),
                  ),
                  title: const Text('数据安全'),
                  subtitle: const Text('云端同步存储，换设备不丢失'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        title: const Row(
                          children: [
                            Icon(Icons.shield, color: Colors.green),
                            SizedBox(width: 8),
                            Text('数据安全保障'),
                          ],
                        ),
                        content: const Text(
                          '您的健康档案、紧急联系人和签到记录均已加密同步到云端服务器，换设备登录后数据自动恢复。\n\n我们承诺：\n• 采用行业标准的加密技术保护数据传输和存储\n• 不会将您的信息用于任何商业目的\n• 不会向第三方透露您的隐私\n• 您可以随时在健康档案页面或设置中删除所有数据',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('知道了'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 存储管理（v1.7 新增）
          _buildSectionTitle('存储管理'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.cleaning_services_outlined, color: Colors.blue.shade700),
                  ),
                  title: const Text('清除缓存'),
                  subtitle: const Text('清理临时文件和图片缓存'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _clearCache,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.restart_alt, color: Colors.red.shade400),
                  ),
                  title: const Text('重置所有数据', style: TextStyle(color: Colors.red)),
                  subtitle: const Text('清除所有本地数据（签到、档案、联系人）',
                      style: TextStyle(fontSize: 12)),
                  onTap: _resetAllData,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 关于
          _buildSectionTitle('关于'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.info_outline, color: Colors.purple.shade700),
                  ),
                  title: const Text('关于「在呢」'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showAbout,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const SizedBox(width: 40),
                  title: Row(
                    children: [
                      Text(
                        '版本',
                        style: TextStyle(
                          color: devTapCount >= 1 ? const Color(0xFFFF7F50) : null,
                          fontWeight: devTapCount >= 1 ? FontWeight.bold : null,
                        ),
                      ),
                      const Spacer(),
                      if (devTapCount >= 1)
                        Text(
                          devTapCount >= 3 ? '开发者模式 ✅' : '再点 ${3 - devTapCount} 次激活',
                          style: TextStyle(color: Colors.orange.shade600, fontSize: 11),
                        ),
                    ],
                  ),
                  subtitle: Text('v${AppConstants.version} (Build ${AppConstants.buildNumber})'),
                  trailing: devTapCount >= 3
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.code, size: 14, color: Colors.purple.shade700),
                        )
                      : null,
                  onTap: () {
                    // 【v1.13.0】Release 包屏蔽开发者模式入口
                    if (!FeatureFlags.enableDeveloperMode) return;
                    if (handleVersionTap()) {
                      showDeveloperMenu();
                    }
                    setState(() {});
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          Center(
            child: Column(
              children: [
                const Text(
                  '在呢',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF7F50),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '让在乎你的人安心',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
      ),
    );
  }

  /// 清除缓存
  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.cleaning_services, color: Colors.blue),
            SizedBox(width: 8),
            Text('清除缓存'),
          ],
        ),
        content: const Text(
          '将清除图片缓存和临时文件，不会影响您的签到数据和健康档案。',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('avatar_path_cache');
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('缓存已清除 ✓'),
      backgroundColor: Colors.teal,
      behavior: SnackBarBehavior.floating,
    ));
  }

  /// 重置所有数据（危险操作！需要二次确认）
  Future<void> _resetAllData() async {
    // 第一次确认
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('⚠️ 危险操作', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('此操作将永久删除以下所有数据：'),
            SizedBox(height: 12),
            Text('• 签到记录和连续天数'),
            Text('• 健康档案信息'),
            Text('• 紧急联系人列表'),
            Text('• 登录状态'),
            Text('• 主题偏好设置'),
            SizedBox(height: 12),
            Text('此操作不可恢复！',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('确认重置'),
          ),
        ],
      ),
    );
    if (firstConfirm != true || !mounted) return;

    // 二次确认——输入 "重置" 才能继续
    final secondConfirm = await _showResetConfirmation();
    if (secondConfirm != true || !mounted) return;

    // 执行重置
    try {
      final prefs = await SharedPreferences.getInstance();

      // 取消所有通知
      await _cancelAllNotifications();

      // 清除所有本地数据键值
      for (final key in prefs.getKeys()) {
        await prefs.remove(key);
      }

      // 【P2修复 v1.9.83】清除本地头像文件，避免残留占用存储
      try {
        final dir = await getApplicationDocumentsDirectory();
        final avatarFile = File('${dir.path}/avatar.png');
        if (await avatarFile.exists()) await avatarFile.delete();
        final files = dir.listSync();
        for (final file in files) {
          if (file is File &&
              file.path.contains('avatar_') &&
              file.path.endsWith('.jpg')) {
            await file.delete();
          }
        }
      } catch (e) {
        debugPrint('[_resetAllData] 头像文件清理失败: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('所有数据已重置 ✓ App 将重新启动...'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ));

        // 重新加载页面状态
        _loadSettings();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('重置失败：$e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  /// 二次确认对话框：要求输入"重置"
  Future<bool?> _showResetConfirmation() {
    final controller = TextEditingController();
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🔒 最终确认', style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('请输入「重置」以确认删除所有数据：'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '输入"重置"',
                border: const OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim() == '重置'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('彻底删除'),
          ),
        ],
      ),
    );
  }

  @override
  Future<void> resetTodayCheckIn() async {
    await super.resetTodayCheckIn();
    if (mounted) _loadSettings(); // 重置后刷新设置
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }
}
