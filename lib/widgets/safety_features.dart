import 'package:flutter/material.dart';
import '../services/safety/safety_service.dart';
import 'package:intl/intl.dart';

/// 定时确认设置卡片
class CheckInReminderCard extends StatelessWidget {
  final CheckInReminder config;
  final Function(CheckInReminder) onConfigChanged;
  final VoidCallback onPerformCheckIn;

  const CheckInReminderCard({
    super.key,
    required this.config,
    required this.onConfigChanged,
    required this.onPerformCheckIn,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.alarm_on,
                    color: Colors.green.shade400,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '定时平安确认',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _getStatusText(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: config.enabled,
                  activeColor: Colors.green,
                  onChanged: (value) {
                    if (value) {
                      onConfigChanged(config.copyWith(enabled: true));
                    } else {
                      onConfigChanged(config.copyWith(enabled: false));
                    }
                  },
                ),
              ],
            ),

            if (config.enabled) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              // 提醒频率选择
              const Text(
                '提醒频率',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _buildFrequencySelector(context),
              const SizedBox(height: 16),

              // 提醒时间选择
              const Text(
                '提醒时间',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _buildTimeChips(context),

              if (config.lastCheckIn != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade400, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '上次确认: ${_formatLastCheckIn(config.lastCheckIn!)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (config.missedCount > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange.shade400, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '连续 ${config.missedCount} 次未确认',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onPerformCheckIn,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('立即确认平安'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getStatusText() {
    if (!config.enabled) return '未开启';
    switch (config.status) {
      case CheckInReminderStatus.daily:
        return '每天提醒';
      case CheckInReminderStatus.weekly:
        return '每周提醒';
      case CheckInReminderStatus.custom:
        return '自定义时间';
      default:
        return '已开启';
    }
  }

  Widget _buildFrequencySelector(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        _buildFrequencyChip(
          context,
          '每天',
          CheckInReminderStatus.daily,
        ),
        _buildFrequencyChip(
          context,
          '每周',
          CheckInReminderStatus.weekly,
        ),
        _buildFrequencyChip(
          context,
          '自定义',
          CheckInReminderStatus.custom,
        ),
      ],
    );
  }

  Widget _buildFrequencyChip(
    BuildContext context,
    String label,
    CheckInReminderStatus status,
  ) {
    final isSelected = config.status == status;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          onConfigChanged(config.copyWith(status: status));
        }
      },
      selectedColor: Colors.green.shade100,
      labelStyle: TextStyle(
        color: isSelected ? Colors.green.shade700 : Colors.grey.shade600,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildTimeChips(BuildContext context) {
    final defaultHours = {
      7: '早7点',
      9: '上午9点',
      12: '中午12点',
      18: '下午6点',
      21: '晚9点',
      22: '晚10点',
    };

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: defaultHours.entries.map((entry) {
        final isSelected = config.reminderHours.contains(entry.key);
        return FilterChip(
          label: Text(entry.value),
          selected: isSelected,
          onSelected: (selected) {
            final hours = List<int>.from(config.reminderHours);
            if (selected) {
              hours.add(entry.key);
            } else {
              hours.remove(entry.key);
            }
            hours.sort();
            onConfigChanged(config.copyWith(reminderHours: hours));
          },
          selectedColor: Colors.green.shade100,
          checkmarkColor: Colors.green.shade700,
          labelStyle: TextStyle(
            color: isSelected ? Colors.green.shade700 : Colors.grey.shade600,
          ),
        );
      }).toList(),
    );
  }

  String _formatLastCheckIn(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return DateFormat('MM/dd HH:mm').format(time);
  }
}

/// 位置轨迹卡片
class LocationTrackCard extends StatelessWidget {
  final List<LocationRecord> todayTrack;
  final VoidCallback? onViewFullMap;
  final VoidCallback? onStartTracking;
  final bool isTracking;

  const LocationTrackCard({
    super.key,
    required this.todayTrack,
    this.onViewFullMap,
    this.onStartTracking,
    this.isTracking = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.location_on,
                    color: Colors.blue.shade400,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '位置共享',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isTracking ? '正在追踪...' : '保护您的行踪安全',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isTracking ? Colors.green.shade100 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isTracking ? Colors.green : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isTracking ? '开启' : '关闭',
                        style: TextStyle(
                          fontSize: 12,
                          color: isTracking ? Colors.green.shade700 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 今日轨迹摘要
            if (todayTrack.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timeline, color: Colors.blue.shade400, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '今日轨迹',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          Text(
                            '${todayTrack.length} 个位置记录',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: onViewFullMap,
                      child: const Text('查看详情'),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey.shade400, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '暂无今日轨迹记录',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onStartTracking,
                    icon: Icon(isTracking ? Icons.stop : Icons.play_arrow),
                    label: Text(isTracking ? '停止追踪' : '开始追踪'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isTracking ? Colors.red : Colors.blue,
                      side: BorderSide(
                        color: isTracking ? Colors.red : Colors.blue,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 跌倒检测卡片
class FallDetectionCard extends StatelessWidget {
  final List<FallEvent> recentFalls;
  final bool isEnabled;
  final VoidCallback? onToggle;
  final Function(String)? onAcknowledge;

  const FallDetectionCard({
    super.key,
    required this.recentFalls,
    this.isEnabled = false,
    this.onToggle,
    this.onAcknowledge,
  });

  @override
  Widget build(BuildContext context) {
    final unacknowledged = recentFalls.where((e) => !e.acknowledged).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.sensors,
                    color: Colors.orange.shade400,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '跌倒检测',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isEnabled ? '已启用 Apple Watch 检测' : '需要 Apple Watch',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onToggle != null)
                  Switch(
                    value: isEnabled,
                    activeColor: Colors.orange,
                    onChanged: (_) => onToggle?.call(),
                  ),
              ],
            ),

            if (!isEnabled) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey.shade400, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '佩戴 Apple Watch 可自动检测跌倒，检测到跌倒会自动通知守护人',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 未确认的跌倒事件
            if (unacknowledged.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                '待确认事件',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...unacknowledged.take(3).map((event) => _buildFallEventItem(context, event)),
            ],

            // 最近事件
            if (recentFalls.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                '最近事件',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...recentFalls.take(5).map((event) => _buildFallEventItem(context, event)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFallEventItem(BuildContext context, FallEvent event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: event.acknowledged ? Colors.grey.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: event.acknowledged
            ? null
            : Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(
            event.acknowledged ? Icons.check_circle : Icons.warning_amber,
            color: event.acknowledged ? Colors.green : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatTime(event.timestamp),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (event.confidence != null)
                  Text(
                    '置信度: ${(event.confidence! * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
              ],
            ),
          ),
          if (!event.acknowledged && onAcknowledge != null)
            TextButton(
              onPressed: () => onAcknowledge?.call(event.id),
              child: const Text('确认'),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return DateFormat('MM/dd HH:mm').format(time);
  }
}

/// 安全功能设置页面
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

    setState(() {
      _reminderConfig = reminder;
      _todayTrack = track;
      _fallEvents = falls;
      _isLoading = false;
    });
  }

  Future<void> _performCheckIn() async {
    await _safetyService.performCheckIn();
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ 平安确认完成！'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('安全设置'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 定时确认
                  CheckInReminderCard(
                    config: _reminderConfig,
                    onConfigChanged: (config) async {
                      await _safetyService.saveReminderConfig(config);
                      await _loadData();
                    },
                    onPerformCheckIn: _performCheckIn,
                  ),
                  const SizedBox(height: 16),

                  // 位置共享
                  LocationTrackCard(
                    todayTrack: _todayTrack,
                    isTracking: _isLocationTracking,
                    onStartTracking: () async {
                      if (_isLocationTracking) {
                        // 停止追踪
                        setState(() => _isLocationTracking = false);
                      } else {
                        // 开始追踪
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

                  // 跌倒检测
                  FallDetectionCard(
                    recentFalls: _fallEvents,
                    isEnabled: false, // 需要 Apple Watch
                    onAcknowledge: (id) async {
                      await _safetyService.acknowledgeFallEvent(id);
                      await _loadData();
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
