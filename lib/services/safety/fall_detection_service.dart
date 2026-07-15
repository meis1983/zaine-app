import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../config/app_config.dart';
import 'safety_service.dart';

/// 手机端跌倒检测服务（简化版）
///
/// 使用手机加速度传感器检测可能的跌倒事件。
/// 精度不如 Apple Watch，但为没有 Watch 的用户提供基础保护。
class FallDetectionService {
  static final FallDetectionService _instance = FallDetectionService._internal();
  factory FallDetectionService() => _instance;
  FallDetectionService._internal();

  SafetyService? _safetyService;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  bool _isRunning = false;
  bool _phoneDetectionEnabled = false;

  // 跌倒检测参数
  static const double _fallThreshold = 3.5;   // g-force 冲击阈值
  static const double _lowerBound = 0.8;      // 低加速度阈值（安静期判定）
  static const Duration _quietPeriod = Duration(seconds: 2); // 安静期时长
  static const int _impactDebounceSeconds = 5; // 冲击去重间隔

  DateTime? _lastImpactTime;
  DateTime? _lastQuietStart;
  bool _potentialFall = false;
  Timer? _cancelTimer;
  FallEvent? _pendingFallEvent;
  Timer? _quietPeriodTimer;

  // 回调
  void Function()? onFallDetected;
  void Function()? onFallCancelled;
  void Function()? onFallTimeout; // 【v1.93.0】超时未响应回调

  bool get isRunning => _isRunning;
  bool get isPhoneDetectionEnabled => _phoneDetectionEnabled;

  /// 初始化服务
  Future<void> init() async {
    if (_isRunning) return;
    if (kDebugMode) debugPrint('[FallDetection] 📱 手机端跌倒检测服务已初始化');
  }

  /// 开启手机端跌倒检测
  void startPhoneDetection({SafetyService? safetyService}) {
    // 中国区首版隐藏跌倒检测：不注册加速度计监听
    if (AppConfig.isChinaRegion) return;
    if (_isRunning) return;

    _safetyService = safetyService;
    _phoneDetectionEnabled = true;
    _isRunning = true;

    _accelerometerSubscription = accelerometerEventStream().listen(
      _onAccelerometerData,
      onError: (error) {
        if (kDebugMode) debugPrint('[FallDetection] 加速度传感器错误: $error');
      },
    );

    if (kDebugMode) debugPrint('[FallDetection] 📱 手机端跌倒检测已开启');
  }

  /// 停止手机端跌倒检测
  void stopPhoneDetection() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _cancelTimer?.cancel();
    _cancelTimer = null;
    _quietPeriodTimer?.cancel();
    _quietPeriodTimer = null;
    _isRunning = false;
    _phoneDetectionEnabled = false;
    _potentialFall = false;

    if (kDebugMode) debugPrint('[FallDetection] 📱 手机端跌倒检测已停止');
  }

  /// 处理加速度传感器数据
  void _onAccelerometerData(AccelerometerEvent event) {
    // 计算总加速度（g-force）
    final double magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    final now = DateTime.now();

    // 阶段 1：检测高冲击力（潜在的跌倒）
    if (magnitude > _fallThreshold) {
      if (_lastImpactTime == null ||
          now.difference(_lastImpactTime!).inSeconds > _impactDebounceSeconds) {
        _lastImpactTime = now;
        _potentialFall = true;
        _lastQuietStart = null;

        if (kDebugMode) {
          debugPrint('[FallDetection] ⚠️ 检测到高冲击力: ${magnitude.toStringAsFixed(2)}g');
        }

        // 开始安静期计时
        _startQuietPeriodCheck(now);
      }
    }

    // 阶段 2：高冲击后加速度骤降（安静期）
    if (_potentialFall && _lastImpactTime != null) {
      if (magnitude < _lowerBound) {
        if (_lastQuietStart == null) {
          _lastQuietStart = now;
        }

        // 检查安静期是否持续足够长
        if (now.difference(_lastQuietStart!) >= _quietPeriod) {
          _onFallConfirmed(magnitude);
        }
      } else if (magnitude > 2.0) {
        // 如果再次出现大加速度，重置安静期
        _lastQuietStart = null;
      }
    }
  }

  /// 开始检查安静期
  void _startQuietPeriodCheck(DateTime impactTime) {
    _quietPeriodTimer?.cancel();
    _quietPeriodTimer = Timer(const Duration(seconds: 5), () {
      if (_potentialFall && _lastQuietStart != null) {
        // 如果5秒内没有复位，视为确认跌倒
        // 但通常 _onAccelerometerData 中的检查会更早触发
        _potentialFall = false;
        _lastImpactTime = null;
        _lastQuietStart = null;
      }
    });
  }

  /// 确认跌倒事件
  void _onFallConfirmed(double magnitude) {
    _potentialFall = false;
    _lastImpactTime = null;
    _lastQuietStart = null;

    if (kDebugMode) {
      debugPrint('[FallDetection] 🚨 确认跌倒事件！冲击力: ${magnitude.toStringAsFixed(2)}g');
    }

    // 记录跌倒事件
    _recordFallEvent();

    // 触发回调
    onFallDetected?.call();

    // 30秒内等待用户取消
    _startCancelTimer();
  }

  /// 记录跌倒事件到 SafetyService
  Future<void> _recordFallEvent() async {
    if (_safetyService == null) return;

    try {
      // 获取当前位置
      final location = await _safetyService!.getCurrentLocation();

      final event = FallEvent(
        id: 'phone_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        latitude: location?.latitude ?? 0.0,
        longitude: location?.longitude ?? 0.0,
        confidence: 0.6, // 手机端检测置信度较低
        acknowledged: false,
        source: 'phone', // 【修复 v1.93.0】明确标记为手机端检测
      );

      _pendingFallEvent = event;
      await _safetyService!.recordFallEvent(event, notifyGuardians: false);
    } catch (e) {
      if (kDebugMode) debugPrint('[FallDetection] 记录跌倒事件失败: $e');
    }
  }

  /// 启动取消计时器（60秒内等待用户响应）【v1.93.0】扩展为 60 秒
  void _startCancelTimer() {
    _cancelTimer?.cancel();
    _cancelTimer = Timer(const Duration(seconds: 60), () {
      // 60秒无响应：cn 区不自动确认/不自动外发（dead-man switch 核心），等用户手动处理
      if (kDebugMode) {
        debugPrint(AppConfig.isChinaRegion
            ? '[FallDetection] ⏰ 60秒无响应（cn 不自动外发，等待用户手动确认）'
            : '[FallDetection] ⏰ 60秒无响应，超时自动确认');
      }
      _onTimeoutNoResponse();
    });
  }

  /// 超时无响应处理
  /// - global 区：沿用原行为，超时自动确认事件。
  /// - cn 区（中国合规版）：用户无响应时【不】自动确认、【不】自动外发，
  ///   仅保留事件待用户手动处理（确认后通知守护者 / 或取消误报），规避 dead-man switch。
  void _onTimeoutNoResponse() {
    if (_pendingFallEvent == null) return;

    // 【中国合规版整改】仅 global 区超时自动确认；cn 区保持事件 pending，等用户手动操作
    if (!AppConfig.isChinaRegion) {
      if (_safetyService != null) {
        _safetyService!.acknowledgeFallEvent(
          _pendingFallEvent!.id,
          notes: '超时自动确认 — 已通知守护者',
        );
      }
    }

    // 触发超时回调（UI 层可据此显示后续操作界面）
    onFallTimeout?.call();

    _pendingFallEvent = null;
    if (kDebugMode) {
      debugPrint(AppConfig.isChinaRegion
          ? '[FallDetection] 跌倒超时（cn 不自动外发，等待用户手动确认）'
          : '[FallDetection] 🆘 跌倒超时，守护者已通知');
    }
  }

  /// 用户取消跌倒警报（误报）
  void cancelFallAlert() {
    _cancelTimer?.cancel();
    _cancelTimer = null;

    if (_pendingFallEvent != null && _safetyService != null) {
      _safetyService!.acknowledgeFallEvent(
        _pendingFallEvent!.id,
        notes: '用户确认为误报',
      );
      _pendingFallEvent = null;
    }

    onFallCancelled?.call();

    if (kDebugMode) debugPrint('[FallDetection] ✅ 用户取消了跌倒警报');
  }

  /// 确认跌倒（用户主动确认需要帮助）
  void confirmFall() {
    _cancelTimer?.cancel();
    _cancelTimer = null;

    // 更新事件为确认需要帮助
    if (_pendingFallEvent != null && _safetyService != null) {
      _safetyService!.acknowledgeFallEvent(
        _pendingFallEvent!.id,
        notes: '用户确认需要帮助 — 已通知守护者',
      );

      // 【中国合规版整改】用户手动确认后，才通知守护人（不再自动外发）
      if (AppConfig.isChinaRegion) {
        unawaited(_safetyService!.notifyGuardiansAboutFallManually(
          timestamp: _pendingFallEvent!.timestamp,
          latitude: _pendingFallEvent!.latitude.toString(),
          longitude: _pendingFallEvent!.longitude.toString(),
        ));
      }
    }
    _pendingFallEvent = null;

    if (kDebugMode) debugPrint('[FallDetection] 🆘 用户确认跌倒，需要帮助');
  }

  /// 释放资源
  void dispose() {
    stopPhoneDetection();
  }
}
