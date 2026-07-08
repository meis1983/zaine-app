import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../theme/theme_helper.dart';
import '../services/safety/safety_service.dart';
import '../services/safety/fall_detection_service.dart';
import '../services/safety/geofence_service.dart';
import '../services/platform/watch_data_service.dart';
import '../widgets/safety_features.dart';
import '../widgets/fall_confirmation_dialog.dart';
import 'location_map_page.dart';
import 'fall_event_history_page.dart';
import 'geofence_page.dart';

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
  final FallDetectionService _fallDetectionService = FallDetectionService();
  final GeoFenceService _geoFenceService = GeoFenceService(); // 【v1.93.0】
  CheckInReminder _reminderConfig = const CheckInReminder();
  List<LocationRecord> _todayTrack = [];
  List<FallEvent> _fallEvents = [];
  DateTime? _lastRecordTime;
  bool _isLocationTracking = false;
  LocationTrackingMode _trackingMode = LocationTrackingMode.normal; // 【v1.93.0】
  bool _isLoading = true;
  int _geoFenceRefreshToken = 0; // 【v1.95.0】围栏刷新令牌：_loadData 时自增，强制 GeoFenceCard 重建以重新加载
  bool _watchPaired = false;
  bool _watchReachable = false;
  bool _phoneDetectionEnabled = false;
  Timer? _watchTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startWatchTimer();
    _setupFallDetectionCallbacks();
  }

  /// 【v1.93.0】设置跌倒检测回调
  void _setupFallDetectionCallbacks() {
    _fallDetectionService.onFallDetected = () {
      if (kDebugMode) debugPrint('[SafetySettings] 跌倒检测回调触发');
      _showFallConfirmationDialog();
    };
    _fallDetectionService.onFallTimeout = () {
      if (kDebugMode) debugPrint('[SafetySettings] 跌倒超时回调触发');
      // 超时后自动通知已在 service 中处理，这里可选择性刷新数据
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.white),
                SizedBox(width: ZaiNeSpacing.sm),
                Expanded(child: Text('跌倒未响应，已自动通知守护者')),
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
    _fallDetectionService.onFallCancelled = () {
      if (kDebugMode) debugPrint('[SafetySettings] 跌倒取消回调触发');
      if (mounted) _loadData();
    };
  }

  /// 【v1.93.0】显示跌倒确认对话框
  void _showFallConfirmationDialog() {
    if (!mounted || !_phoneDetectionEnabled) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => FallConfirmationDialog(
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
    await _fallDetectionService.init();
    final reminder = await _safetyService.getReminderConfig();
    final track = await _safetyService.getLocationTrackForDay(DateTime.now());
    final falls = await _safetyService.getFallEvents();
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
        _geoFenceRefreshToken++; // 【v1.95.0】触发 GeoFenceCard 重建并重新加载围栏
      });
    }
  }

  Future<void> _performCheckIn() async {
    await _safetyService.performCheckIn();
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: ZaiNeSpacing.sm),
              Text('✅ 平安确认完成！'),
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
      _fallDetectionService.startPhoneDetection(safetyService: _safetyService);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('📱 手机端跌倒检测已开启（简化版）'),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      _fallDetectionService.stopPhoneDetection();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('📱 手机端跌倒检测已关闭'),
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
        title: const Text('安全中心'),
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
                    // 安全状态总览
                    _buildSafetyOverview(),
                    const SizedBox(height: ZaiNeSpacing.xl),

                    // 功能卡片
                    CheckInReminderCard(
                      config: _reminderConfig,
                      onConfigChanged: (config) async {
                        await _safetyService.saveReminderConfig(config);
                        await _loadData();
                      },
                      onPerformCheckIn: _performCheckIn,
                    ),
                    const SizedBox(height: ZaiNeSpacing.lg),

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
                          // 【v1.93.0】启动围栏定时检查
                          _geoFenceService.startPeriodicCheck();
                        }
                        if (!success && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('请开启位置权限'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      },
                      onStopTracking: () {
                        _safetyService.stopLocationTracking();
                        _geoFenceService.stopPeriodicCheck(); // 【v1.93.0】
                        if (mounted) setState(() => _isLocationTracking = false);
                      },
                      onModeChanged: (mode) {
                        _safetyService.switchTrackingMode(mode);
                        setState(() => _trackingMode = mode);
                      },
                    ),
                    const SizedBox(height: ZaiNeSpacing.lg),

                    // 【v1.93.0】安全围栏
                    GeoFenceCard(
                      key: ValueKey(_geoFenceRefreshToken),
                      onManageFences: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const GeoFencePage()),
                        ).then((_) => _loadData());
                      },
                    ),
                    const SizedBox(height: ZaiNeSpacing.lg),

                    FallDetectionCard(
                      recentFalls: _fallEvents,
                      watchPaired: _watchPaired,
                      watchReachable: _watchReachable,
                      phoneDetectionEnabled: _phoneDetectionEnabled,
                      onTogglePhoneDetection: _togglePhoneDetection,
                      onViewHistory: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FallEventHistoryPage(),
                          ),
                        ).then((_) => _loadData());
                      },
                    ),
                    const SizedBox(height: ZaiNeSpacing.xl),

                    // 安全提示
                    _buildSafetyTips(),
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
      scoreLabel = '安全';
    } else if (score >= 50) {
      scoreColor = Colors.orange;
      scoreLabel = '一般';
    } else {
      scoreColor = Colors.red;
      scoreLabel = '需关注';
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
                const Text(
                  '安全状态',
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
                    if (_reminderConfig.enabled)
                      _buildStatusChip('定时确认', Colors.green),
                    if (_isLocationTracking)
                      _buildStatusChip('位置追踪', Colors.blue),
                    if (_fallEvents.isNotEmpty && _fallEvents.any((e) => !e.acknowledged))
                      _buildStatusChip('有未确认事件', Colors.orange),
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
      return '您的安全保护已全面开启，让我们一起守护您的平安。';
    } else if (_reminderConfig.enabled) {
      return '定时确认已开启，建议开启位置追踪获得更全面的保护。';
    } else {
      return '建议开启定时确认和位置追踪，构建更完善的保护体系。';
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
                '安全小贴士',
                style: TextStyle(
                  fontSize: ZaiNeFontSize.bodySm,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZaiNeSpacing.md),
          _buildTipItem('1', '建议每天至少确认一次平安'),
          _buildTipItem('2', '开启位置追踪可在紧急时快速定位'),
          _buildTipItem('3', '佩戴 Apple Watch 可自动检测跌倒'),
          _buildTipItem('4', '记得定期检查紧急联系人是否正确'),
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
