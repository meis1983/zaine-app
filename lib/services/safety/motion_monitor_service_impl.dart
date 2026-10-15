import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../config/app_config.dart';
import 'motion_monitor_service_base.dart';
import 'safety_service.dart';
import '../../l10n/i18n.dart';

/// 手机端运动监测服务（简化版，global 构建专属）
///
/// 使用手机加速度传感器检测可能的跌倒事件。
/// 精度不如 Apple Watch，但为没有 Watch 的用户提供基础保护。
///
/// 【CN 合规】本实现**仅 global 构建编译**。CN 构建通过条件导入使用 stub，
/// 不编译本文件，故 `MotionMonitorService` 类在 CN 二进制中不存在。
class MotionMonitorService extends MotionMonitor {
  static final MotionMonitorService _instance = MotionMonitorService._internal();
  factory MotionMonitorService() => _instance;
  MotionMonitorService._internal();

  SafetyService? _safetyService;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  bool _isRunning = false;
  bool _phoneDetectionEnabled = false;

  // 监测参数
  static const double _fallThreshold = 3.5;   // g-force 冲击阈值
  static const double _lowerBound = 0.8;      // 低加速度阈值（安静期判定）
  static const Duration _quietPeriod = Duration(seconds: 2); // 安静期时长
  static const int _impactDebounceSeconds = 5; // 冲击去重间隔

  DateTime? _lastImpactTime;
  DateTime? _lastQuietStart;
  bool _potentialFall = false;
  Timer? _cancelTimer;
  MotionEvent? _pendingMotionEvent;
  Timer? _quietPeriodTimer;

  // 回调
  void Function()? onTriggered;
  void Function()? onTimeout; // 【v1.93.0】超时未响应回调
  void Function()? onCancelled;

  bool get isRunning => _isRunning;
  bool get isPhoneDetectionEnabled => _phoneDetectionEnabled;

  /// 初始化服务
  Future<void> init() async {
    if (_isRunning) return;
    if (kDebugMode) debugPrint('[MotionMonitor] 📱 手机端运动监测服务已初始化');
  }

  /// 开启手机端监测
  void startMonitoring({SafetyService? safetyService}) {
    if (_isRunning) return;
    _safetyService = safetyService;
    _phoneDetectionEnabled = true;
    _isRunning = true;

    _accelerometerSubscription = accelerometerEventStream().listen(
      _onAccelerometerData,
      onError: (error) {
        if (kDebugMode) debugPrint('[MotionMonitor] 加速度传感器错误: $error');
      },
    );

    if (kDebugMode) debugPrint('[MotionMonitor] 📱 手机端运动监测已开启');
  }

  /// 停止手机端监测
  void stopMonitoring() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _cancelTimer?.cancel();
    _cancelTimer = null;
    _quietPeriodTimer?.cancel();
    _quietPeriodTimer = null;
    _isRunning = false;
    _phoneDetectionEnabled = false;
    _potentialFall = false;

    if (kDebugMode) debugPrint('[MotionMonitor] 📱 手机端运动监测已停止');
  }

  /// 处理加速度传感器数据
  void _onAccelerometerData(AccelerometerEvent event) {
    final double magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    final now = DateTime.now();

    if (magnitude > _fallThreshold) {
      if (_lastImpactTime == null ||
          now.difference(_lastImpactTime!).inSeconds > _impactDebounceSeconds) {
        _lastImpactTime = now;
        _potentialFall = true;
        _lastQuietStart = null;

        if (kDebugMode) {
          debugPrint('[MotionMonitor] ⚠️ 检测到高冲击力: ${magnitude.toStringAsFixed(2)}g');
        }

        _startQuietPeriodCheck(now);
      }
    }

    if (_potentialFall && _lastImpactTime != null) {
      if (magnitude < _lowerBound) {
        if (_lastQuietStart == null) {
          _lastQuietStart = now;
        }

        if (now.difference(_lastQuietStart!) >= _quietPeriod) {
          _onMotionConfirmed(magnitude);
        }
      } else if (magnitude > 2.0) {
        _lastQuietStart = null;
      }
    }
  }

  /// 开始检查安静期
  void _startQuietPeriodCheck(DateTime impactTime) {
    _quietPeriodTimer?.cancel();
    _quietPeriodTimer = Timer(const Duration(seconds: 5), () {
      if (_potentialFall && _lastQuietStart != null) {
        _potentialFall = false;
        _lastImpactTime = null;
        _lastQuietStart = null;
      }
    });
  }

  /// 确认监测事件
  void _onMotionConfirmed(double magnitude) {
    _potentialFall = false;
    _lastImpactTime = null;
    _lastQuietStart = null;

    if (kDebugMode) {
      debugPrint('[MotionMonitor] 🚨 确认监测事件！冲击力: ${magnitude.toStringAsFixed(2)}g');
    }

    _recordMotionEvent();

    onTriggered?.call();

    _startCancelTimer();
  }

  /// 记录监测事件到 SafetyService
  Future<void> _recordMotionEvent() async {
    if (_safetyService == null) return;

    try {
      final location = await _safetyService!.getCurrentLocation();

      final event = MotionEvent(
        id: 'phone_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        latitude: location?.latitude ?? 0.0,
        longitude: location?.longitude ?? 0.0,
        confidence: 0.6,
        acknowledged: false,
        source: 'phone',
      );

      _pendingMotionEvent = event;
      await _safetyService!.recordMotionEvent(event, notifyGuardians: false);
    } catch (e) {
      if (kDebugMode) debugPrint('[MotionMonitor] 记录监测事件失败: $e');
    }
  }

  /// 启动取消计时器（60秒内等待用户响应）【v1.93.0】扩展为 60 秒
  void _startCancelTimer() {
    _cancelTimer?.cancel();
    _cancelTimer = Timer(const Duration(seconds: 60), () {
      _onTimeoutNoResponse();
    });
  }

  /// 超时无响应处理
  void _onTimeoutNoResponse() {
    if (_pendingMotionEvent == null) return;

    if (!AppConfig.isChinaRegion) {
      if (_safetyService != null) {
        _safetyService!.acknowledgeMotionEvent(
          _pendingMotionEvent!.id,
          notes: tr.z0323,
        );
      }
    }

    onTimeout?.call();

    _pendingMotionEvent = null;
    if (kDebugMode) {
      debugPrint(AppConfig.isChinaRegion
          ? '[MotionMonitor] 监测超时（cn 不自动外发，等待用户手动确认）'
          : '[MotionMonitor] 🆘 监测超时，守护者已通知');
    }
  }

  /// 用户取消监测警报（误报）
  void cancelMotionAlert() {
    _cancelTimer?.cancel();
    _cancelTimer = null;

    if (_pendingMotionEvent != null && _safetyService != null) {
      _safetyService!.acknowledgeMotionEvent(
        _pendingMotionEvent!.id,
        notes: tr.z0324,
      );
      _pendingMotionEvent = null;
    }

    onCancelled?.call();

    if (kDebugMode) debugPrint('[MotionMonitor] ✅ 用户取消了监测警报');
  }

  /// 确认监测事件（用户主动确认需要帮助）
  void confirmMotion() {
    _cancelTimer?.cancel();
    _cancelTimer = null;

    if (_pendingMotionEvent != null && _safetyService != null) {
      _safetyService!.acknowledgeMotionEvent(
        _pendingMotionEvent!.id,
        notes: tr.z0325,
      );

      if (AppConfig.isChinaRegion) {
        unawaited(_safetyService!.notifyGuardiansAboutMotionManually(
          timestamp: _pendingMotionEvent!.timestamp,
          latitude: _pendingMotionEvent!.latitude.toString(),
          longitude: _pendingMotionEvent!.longitude.toString(),
        ));
      }
    }
    _pendingMotionEvent = null;

    if (kDebugMode) debugPrint('[MotionMonitor] 🆘 用户确认监测事件，需要帮助');
  }

  /// 释放资源
  void dispose() {
    stopMonitoring();
  }
}

/// 工厂：global 构建返回完整实现；CN 构建返回 null（见 stub）。
MotionMonitor? createMotionMonitor() => MotionMonitorService();
