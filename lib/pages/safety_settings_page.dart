import 'package:flutter/material.dart';
import '../services/safety/safety_service.dart';
import '../widgets/safety_features.dart';

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
  CheckInReminder _reminderConfig = const CheckInReminder();
  List<LocationRecord> _todayTrack = [];
  List<FallEvent> _fallEvents = [];
  bool _isLocationTracking = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _safetyService.initialize();
    final reminder = await _safetyService.getReminderConfig();
    final track = await _safetyService.getLocationTrackForDay(DateTime.now());
    final falls = await _safetyService.getFallEvents();

    if (mounted) {
      setState(() {
        _reminderConfig = reminder;
        _todayTrack = track;
        _fallEvents = falls;
        _isLoading = false;
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
              SizedBox(width: 8),
              Text('✅ 平安确认完成！'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('安全中心'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 安全状态总览
                    _buildSafetyOverview(),
                    const SizedBox(height: 20),

                    // 功能卡片
                    CheckInReminderCard(
                      config: _reminderConfig,
                      onConfigChanged: (config) async {
                        await _safetyService.saveReminderConfig(config);
                        await _loadData();
                      },
                      onPerformCheckIn: _performCheckIn,
                    ),
                    const SizedBox(height: 16),

                    LocationTrackCard(
                      todayTrack: _todayTrack,
                      isTracking: _isLocationTracking,
                      onStartTracking: () async {
                        if (_isLocationTracking) {
                          setState(() => _isLocationTracking = false);
                        } else {
                          final success = await _safetyService.startLocationTracking();
                          setState(() => _isLocationTracking = success);
                          if (!success && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('请开启位置权限'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    FallDetectionCard(
                      recentFalls: _fallEvents,
                      isEnabled: false,
                      onAcknowledge: (id) async {
                        await _safetyService.acknowledgeFallEvent(id);
                        await _loadData();
                      },
                    ),
                    const SizedBox(height: 20),

                    // 安全提示
                    _buildSafetyTips(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSafetyOverview() {
    // 计算安全评分
    int score = 0;
    if (_reminderConfig.enabled) score += 30;
    if (_isLocationTracking) score += 20;
    if (_fallEvents.isEmpty || _fallEvents.every((e) => e.acknowledged)) score += 50;

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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scoreColor.withOpacity(0.1),
            scoreColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scoreColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // 评分圆环
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: scoreColor.withOpacity(0.2),
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
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                    Text(
                      scoreLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: scoreColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // 安全状态说明
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '安全状态',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getSafetyDescription(),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
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
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.blue.shade400, size: 20),
              const SizedBox(width: 8),
              Text(
                '安全小贴士',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
      padding: const EdgeInsets.only(bottom: 8),
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
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.blue.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
