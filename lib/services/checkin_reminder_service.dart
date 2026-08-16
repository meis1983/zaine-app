import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// 【v1.97.1+157】签到提醒排程服务（单一真相源）
///
/// 修复「已签到仍收到定时签到提醒」的根因：
///   settings_page 原先用 zonedSchedule + matchDateTimeComponents(time) 每日重复排程
///   id=0(主提醒)/id=3(系统提醒)，该方式由系统准时触发，**无法在触发瞬间判断「今日是否已签到」**，
///   故即使用户早已签到仍会提醒（CN 155/156 只修了 safety_service 的运行时定时器，未触达此路径）。
///
/// 本服务改为：
///   1) 排程前读取本地 last_check_in_date，今日已签到则跳过（闸门）；
///   2) 改为单次排程（去掉每日重复），由 App 启动/前台（home_page）重排，次日继续提醒；
///   3) 签到成功后调用 cancelReminders() 即时撤销当日提醒。
///
/// 注意：cancel/zonedSchedule 均按通知 id 在 native 侧生效，跨 FlutterLocalNotificationsPlugin
/// 实例安全（settings_page 的 _notifications 与这里的 notifications 互不干扰，按 id 协同）。
class CheckInReminderService {
  static final FlutterLocalNotificationsPlugin notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    // 权限已在 settings_page 申请，这里不再重复请求，避免重复弹窗
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await notifications.initialize(initSettings);
    _initialized = true;
  }

  /// 今日是否已签到（以本地 last_check_in_date 为准，与 _scheduleMissedCheckInAlerts 同口径）
  static bool isCheckedInToday(SharedPreferences prefs) {
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return prefs.getString('last_check_in_date') == todayStr;
  }

  /// 排程主提醒(id=0) + 系统提醒(id=3)，单次排程（不再每日重复）。
  /// [systemReminderEnabled] 来自设置页开关；[prefs] 提供提醒时间/签到状态。
  static Future<void> scheduleReminders(
    SharedPreferences prefs, {
    required bool systemReminderEnabled,
  }) async {
    await init();

    final hour = prefs.getInt('reminder_hour') ?? 20;
    final minute = prefs.getInt('reminder_minute') ?? 0;
    final checkedInToday = isCheckedInToday(prefs);

    // 先撤销旧的 id=0/id=3，避免重复/残留
    await notifications.cancel(0);
    await notifications.cancel(3);

    if (checkedInToday) {
      if (kDebugMode) {
        debugPrint('[ReminderSvc] 今日已签到，跳过 id=0/id=3 排程');
      }
      return;
    }

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

    // ====== 主提醒：下一次提醒时刻（今天未过则今天，已过则明天）======
    var scheduledTime =
        DateTime.now().copyWith(hour: hour, minute: minute, second: 0);
    if (scheduledTime.isBefore(DateTime.now())) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }
    final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

    await notifications.zonedSchedule(
      0, // id
      '该签到啦 🏠',
      '点击打开「在呢」，完成今日签到，让守护者放心 ❤️',
      tzScheduledTime,
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );

    // ====== 系统提醒（id=3）—— 主提醒后2小时，未签到时额外提醒 ======
    if (systemReminderEnabled) {
      var systemTime =
          DateTime.now().copyWith(hour: hour, minute: minute, second: 0);
      if (systemTime.isBefore(DateTime.now())) {
        systemTime = systemTime.add(const Duration(days: 1));
      }
      systemTime = systemTime.add(const Duration(hours: 2));
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
      const systemDetails =
          NotificationDetails(android: systemAndroidDetails, iOS: iosDetails);

      await notifications.zonedSchedule(
        3, // id
        '别忘了签到哦 💙',
        '今天还没签到呢，花3秒报个平安，让守护者放心',
        tzSystemTime,
        systemDetails,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }

    if (kDebugMode) {
      debugPrint(
        '[ReminderSvc] 已单次排程 id=0(主提醒)+'
        '${systemReminderEnabled ? 'id=3(系统提醒)' : '(系统提醒关)'} @ $hour:${minute.toString().padLeft(2, '0')}',
      );
    }
  }

  /// 签到成功后即时撤销当日 id=0/id=3 提醒（防止「已签到仍提醒」）
  static Future<void> cancelReminders() async {
    await notifications.cancel(0);
    await notifications.cancel(3);
    if (kDebugMode) debugPrint('[ReminderSvc] 已撤销当日 id=0/id=3 提醒');
  }
}
