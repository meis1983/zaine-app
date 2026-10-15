import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../theme/theme_helper.dart';
import '../services/safety/safety_service.dart';
import '../services/safety/motion_monitor_service.dart';
import '../services/safety/safe_zone_service.dart';
import '../services/platform/watch_data_service.dart';
import '../widgets/safety_features.dart';
import '../widgets/motion_confirmation_dialog.dart';
import 'location_map_page.dart';
import 'motion_event_history_page.dart';
import 'safe_zone_page.dart';
import '../config/feature_flags.dart';
import '../config/app_config.dart';
import '../l10n/i18n.dart';

/// 安全设置页面
///
/// 整合定时确认、位置共享、跌倒检测等功能
class SafetySettingsPage extends StatefulWidget {
  const SafetySettingsPage({super.key});

  @override
  State<SafetySettingsPage> createState() => _SafetySettingsPageState();
}

class _SafetySettingsPageState extends State<SafetySettingsPage> {
  final SafetyService _safetyService = SafetyService();
  final _motionMonitor = getMotionMonitor();
  final SafeZoneMonitor? _safeZoneService = getSafeZoneService(); // 【v1.93.0】
  CheckInReminder _reminderConfig = const CheckInReminder();
  List<LocationRecord> _todayTrack = [];
  List<MotionEvent> _fallEvents = [];
  DateTime? _lastRecordTime;
  bool _isLocationTracking = false;
  LocationTrackingMode _trackingMode = LocationTrackingMode.normal; // 【v1.93.0】
  bool _isLoading = true;
  int _safeZoneRefreshToken = 0; // 【v1.95.0】安全区域刷新令牌：_loadData 时自增，强制 SafeZoneCard 重建以重新加载
  bool _watchPaired = false;
  bool _watchReachable = false;
  bool _phoneDetectionEnabled = false;
  Timer? _watchTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startWatchTimer();
    _setupMotionMonitorCallbacks();
  }

  /// 【v1.93.0】设置运动监测回调
  /// CN 版（kIsChinaBuild）下 _motionMonitor 为 null，直接跳过。
  void _setupMotionMonitorCallbacks() {
    final fd = _motionMonitor;
    if (fd == null) return;
    fd.onTriggered = () {
      if (kDebugMode) debugPrint('[SafetySettings] 运动监测回调触发');
      _showMotionConfirmationDialog();
    };
    fd.onTimeout = () {
      if (kDebugMode) debugPrint('[SafetySettings] 运动监测超时回调触发');
      // 超时后由用户手动确认再通知，已在 service 中处理，这里刷新数据并提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
            content: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.white),
                SizedBox(width: ZaiNeSpacing.sm),
                Expanded(child: Text(tr.s1019)),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 5),
          ),
        );
        _loadData();
      }
    };
    fd.onCancelled = () {
      if (kDebugMode) debugPrint('[SafetySettings] 运动监测取消回调触发');
      if (mounted) _loadData();
    };
  }

  /// 【v1.93.0】显示跌倒确认对话框
  void _showMotionConfirmationDialog() {
    if (!mounted || !_phoneDetectionEnabled) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => MotionConfirmationDialog(
          onCancel: () {
            _loadData();
          },
          onConfirm: () {
            _loadData();
          },
        ),
      ),
    );
  }

  void _startWatchTimer() {
    _watchTimer?.cancel();
    _watchTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final state = await WatchDataService().refreshWatchState();
        if (mounted) {
          setState(() {
            _watchPaired = state['paired'] ?? false;
            _watchReachable = state['reachable'] ?? false;
          });
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _watchTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _safetyService.initialize();
    if (_motionMonitor != null) await _motionMonitor!.init();
    final reminder = await _safetyService.getReminderConfig();
    final track = await _safetyService.getLocationTrackForDay(DateTime.now());
    final falls = await _safetyService.getMotionEvents();
    final lastRecordTime = await _safetyService.getLastRecordTime();

    // 检查 Apple Watch 连接状态 - 使用 refreshWatchState 确保状态最新
    try {
      final watch = WatchDataService();
      await watch.init();
      final state = await watch.refreshWatchState();
      _watchPaired = state['paired'] ?? false;
      _watchReachable = state['reachable'] ?? false;
      if (kDebugMode) {
        debugPrint('[SafetySettings] Watch 状态: paired=$_watchPaired, reachable=$_watchReachable');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[SafetySettings] 读取 Watch 状态失败: $e');
    }

    // 加载已保存的追踪模式 【v1.93.0】
    final savedMode = await _safetyService.getSavedTrackingMode();

    if (mounted) {
      setState(() {
        _reminderConfig = reminder;
        _todayTrack = track;
        _fallEvents = falls;
        _lastRecordTime = lastRecordTime;
        _trackingMode = savedMode;
        _isLocationTracking = _safetyService.isLocationTracking;
        _isLoading = false;
        _safeZoneRefreshToken++; // 【v1.95.0】触发 SafeZoneCard 重建并重新加载安全区域
      });
    }
  }

  Future<void> _performCheckIn() async {
    await _safetyService.performCheckIn();
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: ZaiNeSpacing.sm),
              Text(tr.s1020),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// 切换手机端跌倒检测
  void _togglePhoneDetection() {
    setState(() {
      _phoneDetectionEnabled = !_phoneDetectionEnabled;
    });
    if (_phoneDetectionEnabled) {
      if (_motionMonitor != null) {
        _motionMonitor!.startMonitoring(safetyService: _safetyService);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:  Text(tr.s1021),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (_motionMonitor != null) _motionMonitor!.stopMonitoring();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:  Text(tr.s1022),
            backgroundColor: Colors.grey.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZaiNeColors.scaffoldBg(),
      appBar: AppBar(
        title:  Text(tr.s235),
        backgroundColor: ZaiNeColors.cardBg(),
        foregroundColor: ZaiNeColors.textPrimary(),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(ZaiNeSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 安全状态总览（仅海外版；CN 合规版按监管要求隐藏）
                    if (!AppConfig.isChinaRegion) ...[
                      _buildSafetyOverview(),
                      const SizedBox(height: ZaiNeSpacing.xl),
                    ],

                    // 功能卡片
                    if (FeatureFlags.enableCheckInReminderCn || !AppConfig.isChinaRegion) ...[
                      CheckInReminderCard(
                        config: _reminderConfig,
                        onConfigChanged: (config) async {
                          await _safetyService.saveReminderConfig(config);
                          await _loadData();
                        },
                        onPerformCheckIn: _performCheckIn,
                      ),
                      const SizedBox(height: ZaiNeSpacing.lg),
                    ],

                    // 【v1.97 中国合规】位置共享/持续定位属监控能力，CN 版彻底隐藏，不暴露任何入口
                    if (!AppConfig.isChinaRegion) ...[
                      LocationTrackCard(
                        todayTrack: _todayTrack,
                        isTracking: _isLocationTracking,
                        currentMode: _trackingMode,
                        lastRecordTime: _lastRecordTime,
                        onViewFullMap: _todayTrack.isNotEmpty
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => LocationMapPage(day: DateTime.now()),
                                  ),
                                ).then((_) => _loadData());
                              }
                            : null,
                        onStartTracking: () async {
                          final success = await _safetyService.startLocationTracking(mode: _trackingMode);
                          if (!mounted) return;
                          setState(() => _isLocationTracking = success);
                          if (success) {
                            // 【v1.93.0】启动安全区域定时检查（cn 首版已禁用）
                            _safeZoneService?.startPeriodicCheck();
                          }
                          if (!success && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                               SnackBar(
                                content: Text(tr.s1023),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        },
                        onStopTracking: () {
                          _safetyService.stopLocationTracking();
                          _safeZoneService?.stopPeriodicCheck(); // 【v1.93.0】
                          if (mounted) setState(() => _isLocationTracking = false);
                        },
                        onModeChanged: (mode) {
                          _safetyService.switchTrackingMode(mode);
                          setState(() => _trackingMode = mode);
                        },
                      ),
                      const SizedBox(height: ZaiNeSpacing.lg),
                    ],

                    if (FeatureFlags.enableSafeZoneCn || !AppConfig.isChinaRegion) ...[
                      // 【v1.93.0】安全区域
                      SafeZoneCard(
                        key: ValueKey(_safeZoneRefreshToken),
                        onManageFences: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SafeZonePage()),
                          ).then((_) => _loadData());
                        },
                      ),
                    ],
                    if (FeatureFlags.enableMotionCn || !AppConfig.isChinaRegion) ...[
                      const SizedBox(height: ZaiNeSpacing.lg),

                      MotionMonitorCard(
                        recentFalls: _fallEvents,
                        watchPaired: _watchPaired,
                        watchReachable: _watchReachable,
                        phoneDetectionEnabled: _phoneDetectionEnabled,
                        onTogglePhoneDetection: _togglePhoneDetection,
                        onViewHistory: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MotionEventHistoryPage(),
                            ),
                          ).then((_) => _loadData());
                        },
                      ),
                    ],
                    const SizedBox(height: ZaiNeSpacing.xl),

                    // 安全提示（仅海外版；CN 合规版按监管要求隐藏）
                    if (!AppConfig.isChinaRegion) _buildSafetyTips(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSafetyOverview() {
    int score = 0;
    if (_reminderConfig.enabled) score += 50;
    if (_isLocationTracking) score += 30;
    if (_lastRecordTime != null) score += 20;

    Color scoreColor;
    String scoreLabel;
    if (score >= 80) {
      scoreColor = Colors.green;
      scoreLabel = tr.s1024;
    } else if (score >= 50) {
      scoreColor = Colors.orange;
      scoreLabel = tr.s1025;
    } else {
      scoreColor = Colors.red;
      scoreLabel = tr.s1026;
    }

    return Container(
      padding: const EdgeInsets.all(ZaiNeSpacing.section),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scoreColor.withValues(alpha: 0.1),
            scoreColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: scoreColor.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 70,
                  height: 70,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 6,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$score',
                      style: TextStyle(
                        fontSize: ZaiNeFontSize.title,
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                    Text(
                      scoreLabel,
                      style: TextStyle(
                        fontSize: ZaiNeFontSize.micro,
                        color: scoreColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: ZaiNeSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text(
                  tr.s1027,
                  style: TextStyle(
                    fontSize: ZaiNeFontSize.subtitle,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: ZaiNeSpacing.sm),
                Text(
                  _getSafetyDescription(),
                  style: TextStyle(
                    fontSize: ZaiNeFontSize.caption,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: ZaiNeSpacing.sm),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (_reminderConfig.enabled && !AppConfig.isChinaRegion)
                      _buildStatusChip(tr.s1028, Colors.green),
                    if (_isLocationTracking)
                      _buildStatusChip(tr.s1029, Colors.blue),
                    if (_fallEvents.isNotEmpty && _fallEvents.any((e) => !e.acknowledged))
                      _buildStatusChip(tr.s1030, Colors.orange),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.sm, vertical: ZaiNeSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ZaiNeRadius.small),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: ZaiNeSpacing.xs),
          Text(
            label,
            style: TextStyle(
              fontSize: ZaiNeFontSize.micro,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _getSafetyDescription() {
    if (_reminderConfig.enabled && _isLocationTracking) {
      return tr.s1031;
    } else if (_reminderConfig.enabled) {
      return tr.s1032;
    } else {
      return tr.s1033;
    }
  }

  Widget _buildSafetyTips() {
    return Container(
      padding: const EdgeInsets.all(ZaiNeSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.blue.shade400, size: 20),
              const SizedBox(width: ZaiNeSpacing.sm),
              Text(
                tr.s1034,
                style: TextStyle(
                  fontSize: ZaiNeFontSize.bodySm,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZaiNeSpacing.md),
          _buildTipItem('1', tr.s1035),
          _buildTipItem('2', tr.s1036),
          _buildTipItem('3', tr.s1037),
          _buildTipItem('4', tr.s1038),
        ],
      ),
    );
  }

  Widget _buildTipItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZaiNeSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: Colors.blue.shade200,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  fontSize: ZaiNeFontSize.micro,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: ZaiNeSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: ZaiNeFontSize.caption,
                color: Colors.blue.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
