// lib/services/home_arrival_service.dart
// 到家位置提醒（v1.98.0）
//
// 两种模式（用户自行选择，默认全关）：
//   模式 A：到家提醒本人报平安（本地通知，不联网、不通知他人）
//   模式 B：到家自动通知守护人（调后端 /api/notify/home-arrival，
//           APNs 推送守护人「已安全到家」）。【绝不】自动记签到——
//           签到是用户主动行为，系统不替用户确认（避免稀释签到习惯/连续天数，
//           也避免守护人收到被系统"代签"的虚假平安信号）。
//
// 家位置设置：一键用当前位置（LocationService）或 苹果地图选点（openMapPicker）。
//
// 围栏检测：iOS 走原生 CLCircularRegion（region monitoring，后台/杀进程可触发）；
//           Android 暂未接入（本版本 iOS 先上），Platform.isIOS 守卫后 no-op。

import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/i18n.dart';
import 'api/notify_service.dart';
import 'platform/location_service.dart';

class HomeArrivalService {
  static const MethodChannel _channel = MethodChannel('zaine/geofence');

  /// 授权状态变更回调（原生 didChangeAuthorization → onAuthChanged）。
  /// 设置页在 initState 注册，dispose 置空；用于「开启时拦截非 Always」。
  static VoidCallback? onAuthChanged;

  // —— SharedPreferences 键 ——
  static const String _kEnabled = 'home_arrival_enabled';
  static const String _kModeB = 'home_arrival_mode_b';
  static const String _kLat = 'home_arrival_lat';
  static const String _kLng = 'home_arrival_lng';
  static const String _kRadius = 'home_arrival_radius';
  static const String _kAddress = 'home_arrival_address';
  static const String _kNewUserPrompted = 'home_arrival_newuser_prompted';

  static bool _listening = false;

  /// App 启动时调用：注册原生回调 + 拉取「被杀后由系统投递」的待处理到达事件。
  static Future<void> init() async {
    if (!Platform.isIOS) return; // Android 后上
    if (_listening) return;
    _channel.setMethodCallHandler(_onNativeCall);
    _listening = true;
    // 拉取启动时缓冲的到达事件（App 被杀后系统重启投递，native 写入后由 Dart 拉取）
    try {
      final pending = await _channel.invokeMethod<dynamic>('getPendingArrival');
      if (pending != null) {
        await _handleArrival();
      }
    } catch (e) {
      debugPrint('[HomeArrival] 拉取待处理到达事件失败(非致命): $e');
    }
    // 【v1.98.2 修复D】每次启动用当前代码参数重注册家围栏。
    // iOS 会缓存已监控区域，若不在启动时重注册，旧区域（旧参数，如 notifyOnExit=false）
    // 会残留，导致升级后 native 的新设置不生效——这正是"装了新包也不触发"的隐患。
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_kEnabled) ?? false;
      if (enabled && prefs.getDouble(_kLat) != null && prefs.getDouble(_kLng) != null) {
        await _startMonitoring(prefs);
        debugPrint('[HomeArrival] ✅ 启动时重注册家围栏（应用最新 notifyOnExit 等参数）');
      }
    } catch (e) {
      debugPrint('[HomeArrival] 启动时重注册围栏失败(非致命): $e');
    }
  }

  static Future<dynamic> _onNativeCall(MethodCall call) async {
    if (call.method == 'onArrival') {
      await _handleArrival();
      // 【v1.98.2 修复】前台 onArrival 已真正处理（模式B POST / 模式A 原生已弹），
      // 清掉原生 pending，避免诊断页「待上报守护人事件」残留历史时间戳。
      // 引擎未就绪时 onArrival 不会被触达，此时 pending 保留给 getPendingArrival 冷启动补发。
      try {
        await _channel.invokeMethod('clearPendingArrival');
      } catch (e) {
        debugPrint('[HomeArrival] 清除 pending 失败(非致命): $e');
      }
    } else if (call.method == 'onAuthChanged') {
      // 【v1.98.2 修复B】授权变更后若已升 Always 且功能已开，自动重启围栏。
      // 解决"用户先开功能（此时 WhenInUse 围栏哑）→ 后升 Always → 围栏不会自动激活"。
      final arg = (call.arguments as String?) ?? '';
      debugPrint('[HomeArrival] onAuthChanged: $arg');
      if (arg == 'always') {
        final prefs = await SharedPreferences.getInstance();
        final enabled = prefs.getBool(_kEnabled) ?? false;
        if (enabled && Platform.isIOS) {
          await _startMonitoring(prefs);
          debugPrint('[HomeArrival] ✅ Always 授权 + 功能已开，围栏已重启');
        }
      }
      onAuthChanged?.call();
    }
    return null;
  }

  /// 【v1.98.2 诊断页】拉取原生围栏诊断信息（纯只读，不触发任何行为）。
  /// 返回字段含 authStatus / homeRegionRegistered / savedLat/Lng / enabled / modeB /
  /// lastEnterTs / lastNotifTs / pendingArrivalTs 等，供诊断页直读，免去 Mac 控制台。
  static Future<Map<String, dynamic>?> getDiagnostics() async {
    if (!Platform.isIOS) return null;
    try {
      final res = await _channel.invokeMethod<dynamic>('getDiagnostics');
      if (res is Map) {
        return Map<String, dynamic>.from(
          res.map((k, v) => MapEntry(k.toString(), v)),
        );
      }
    } catch (e) {
      return <String, dynamic>{'error': e.toString()};
    }
    return null;
  }

  /// 【v1.98.2 诊断】读取最近一次 /home-arrival 上报响应（含 apns_enabled/guardian_ids/device_tokens），
  /// 供诊断页展示后端推送链路事实。返回 null 表示尚未上报过。
  static Future<Map<String, dynamic>?> getLastArrivalResult() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('home_arrival_last_result');
      if (raw == null) return null;
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (e) {
      debugPrint('[HomeArrival] 读取上次上报结果失败(非致命): $e');
      return null;
    }
  }

  /// 当前定位授权是否为「始终允许」（Only Always 才能让围栏在 App 关闭时触发）。
  static Future<bool> isLocationAlways() async {
    final p = await Geolocator.checkPermission();
    return p == LocationPermission.always;
  }

  /// 触发系统「始终允许」授权弹窗（第二个系统弹窗，带『始终允许』选项）。
  static Future<void> requestLocationAlways() async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod('requestLocationAlways');
    } catch (e) {
      debugPrint('[HomeArrival] 请求始终定位失败(非致命): $e');
    }
  }

  /// 打开系统「设置」App 中本 App 的位置权限页（供用户手动升级为始终允许）。
  static Future<void> openAppSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (e) {
      debugPrint('[HomeArrival] 打开系统设置失败(非致命): $e');
    }
  }

  // —— 配置读写 ——
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabled) ?? false;
  }

  static Future<bool> isModeB() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kModeB) ?? false;
  }

  static Future<String?> getHomeAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kAddress);
  }

  static Future<bool> hasHomeSet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_kLat) != null && prefs.getDouble(_kLng) != null;
  }

  static Future<bool> shouldShowNewUserPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getBool(_kNewUserPrompted) ?? false) == false;
  }

  static Future<void> markNewUserPrompted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNewUserPrompted, true);
  }

  /// 设置家的位置（一键用当前位置），并依开关启停围栏。
  static Future<void> setHomeByCurrentLocation() async {
    final result = await LocationService.getCurrentLocation();
    if (!result.isSuccess ||
        result.latitude == null ||
        result.longitude == null) {
      throw Exception(result.errorMessage ?? tr.homeArrivalLocationFailed);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kLat, result.latitude!);
    await prefs.setDouble(_kLng, result.longitude!);
    if (result.address != null) {
      await prefs.setString(_kAddress, result.address!);
    }
    if (prefs.getDouble(_kRadius) == null) {
      await prefs.setDouble(_kRadius, 50.0);
    }
    // 若已开启，则重启围栏以应用新坐标
    if ((prefs.getBool(_kEnabled) ?? false) && Platform.isIOS) {
      await _startMonitoring(prefs);
    }
  }

  /// 打开原生苹果地图选点页，返回用户选中的家位置。
  /// 返回 {'lat': double, 'lng': double, 'address': String?}；用户取消则抛异常。
  static Future<Map<String, dynamic>> openMapPicker() async {
    if (!Platform.isIOS) {
      throw Exception('地图选点仅支持 iOS');
    }
    final result = await _channel.invokeMethod<dynamic>('openMapPicker');
    if (result is! Map) {
      throw Exception('地图选点返回格式异常');
    }
    final map = result.cast<String, dynamic>();
    return {
      'lat': (map['lat'] as num).toDouble(),
      'lng': (map['lng'] as num).toDouble(),
      'address': map['address'] as String?,
    };
  }

  /// 通过苹果地图选点设置家的位置，并依开关启停围栏。
  static Future<void> setHomeByMapPicker() async {
    final picked = await openMapPicker();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kLat, picked['lat'] as double);
    await prefs.setDouble(_kLng, picked['lng'] as double);
    if (picked['address'] != null) {
      await prefs.setString(_kAddress, picked['address'] as String);
    }
    if (prefs.getDouble(_kRadius) == null) {
      await prefs.setDouble(_kRadius, 50.0);
    }
    if ((prefs.getBool(_kEnabled) ?? false) && Platform.isIOS) {
      await _startMonitoring(prefs);
    }
  }

  /// 开启/关闭 + 设定模式，并同步原生围栏。
  static Future<void> setEnabled({
    required bool enabled,
    required bool modeB,
    double? radiusMeters,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, enabled);
    await prefs.setBool(_kModeB, modeB);
    if (radiusMeters != null) await prefs.setDouble(_kRadius, radiusMeters);
    if (!Platform.isIOS) return;
    if (enabled) {
      await _startMonitoring(prefs);
    } else {
      await _channel.invokeMethod('stopMonitoring');
    }
  }

  static Future<void> _startMonitoring(SharedPreferences prefs) async {
    final lat = prefs.getDouble(_kLat);
    final lng = prefs.getDouble(_kLng);
    if (lat == null || lng == null) {
      debugPrint('[HomeArrival] 未设置家位置，无法开启围栏');
      return;
    }
    final radius = prefs.getDouble(_kRadius) ?? 50.0;
    final enabled = prefs.getBool(_kEnabled) ?? false;
    final modeB = prefs.getBool(_kModeB) ?? false;
    // 【v1.98.2 修复C】传 enabled/modeB 到 native，native 镜像到 UserDefaults，
    // 供 didEnterRegion 独立判断（不依赖 Flutter 引擎存活），兑现"App 被杀也能弹通知"。
    await _channel.invokeMethod('startMonitoring', {
      'lat': lat,
      'lng': lng,
      'radius': radius,
      'enabled': enabled,
      'modeB': modeB,
      'identifier': 'home',
    });
  }

  /// 抵达家围栏后的处理（两种模式分流）。
  static Future<void> _handleArrival() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_kEnabled) ?? false;
    if (!enabled) return;
    final modeB = prefs.getBool(_kModeB) ?? false;

    if (modeB) {
      // 模式 B：仅通知守护人（后端不自动签到）
      try {
        final resp = await NotifyService.notifyGuardiansAboutHomeArrival(
          tzOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
        );
        // 【v1.98.2 诊断】存储最近一次到家上报响应，供诊断页展示后端链路事实
        // （apns_enabled / guardian_ids / device_tokens），无需 curl 即可定位收不到推送的根因。
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('home_arrival_last_result', jsonEncode(resp));
        } catch (_) {}
        debugPrint('[HomeArrival] 模式B 已通知守护人（到家）: $resp');
      } catch (e) {
        debugPrint('[HomeArrival] 模式B 上报失败: $e');
      }
    } else {
      // 模式 A 的本地通知由原生 didEnterRegion → _fireHomeArrivalLocalNotification 统一发送
      // （覆盖 App 被杀/前台/后台，且带每日去重），此处不再发，避免与上一步双发。
      debugPrint('[HomeArrival] 模式A 由原生统一弹本地通知（Dart 侧不重复发）');
    }
  }
}
