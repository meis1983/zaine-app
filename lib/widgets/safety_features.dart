import 'package:flutter/material.dart';
import '../services/safety/safety_service.dart';
import 'package:intl/intl.dart';
import '../theme/theme_helper.dart';

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
        side: BorderSide(color: ZaiNeColors.borderColor()),
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
                  
                    boxShadow: ZaiNeShadows.card,),
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
                          color: ZaiNeColors.textSecondary(),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: config.enabled,
                  activeThumbColor: Colors.green,
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
                  
                    boxShadow: ZaiNeShadows.card,),
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
                  
                    boxShadow: ZaiNeShadows.card,),
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
  final DateTime? lastRecordTime;

  const LocationTrackCard({
    super.key,
    required this.todayTrack,
    this.onViewFullMap,
    this.onStartTracking,
    this.isTracking = false,
    this.lastRecordTime,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: ZaiNeColors.borderColor()),
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
                  
                    boxShadow: ZaiNeShadows.card,),
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
                          color: ZaiNeColors.textSecondary(),
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
                  
                    boxShadow: ZaiNeShadows.card,),
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
                
                  boxShadow: ZaiNeShadows.card,),
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
                
                  boxShadow: ZaiNeShadows.card,),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: ZaiNeColors.textSecondary(), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '暂无今日轨迹记录',
                        style: TextStyle(
                          fontSize: 13,
                          color: ZaiNeColors.textSecondary(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // 上次记录时间
            if (lastRecordTime != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                
                  boxShadow: ZaiNeShadows.card,),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: Colors.green.shade400, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '上次记录',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.green.shade700,
                            ),
                          ),
                          Text(
                            _formatLastRecordTime(lastRecordTime!),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

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

  String _formatLastRecordTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return DateFormat('MM/dd HH:mm').format(time);
  }
}

/// 跌倒检测卡片
/// 与 Apple Watch 联动，利用加速度传感器检测跌倒并通知守护人
class FallDetectionCard extends StatelessWidget {
  final List<FallEvent> recentFalls;
  final bool watchPaired;
  final bool watchReachable;
  final Function(String)? onAcknowledge;
  final VoidCallback? onViewHistory;

  const FallDetectionCard({
    super.key,
    required this.recentFalls,
    this.watchPaired = false,
    this.watchReachable = false,
    this.onAcknowledge,
    this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasWatch = watchPaired;
    final bool hasEvents = recentFalls.isNotEmpty;
    final int unackedCount = recentFalls.where((f) => !f.acknowledged).length;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: ZaiNeColors.borderColor()),
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
                    color: hasWatch ? Colors.orange.shade100 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: ZaiNeShadows.card,
                  ),
                  child: Icon(
                    hasWatch ? Icons.watch_outlined : Icons.watch_off_outlined,
                    color: hasWatch ? Colors.orange.shade600 : Colors.grey.shade500,
                    size: 22,
                  ),
                ),
                const SizedBox(width: ZaiNeSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '步行稳定性 & 跌倒检测',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasWatch
                            ? (watchReachable ? 'Apple Watch 已连接' : 'Apple Watch 已配对')
                            : '需要 Apple Watch 支持',
                        style: TextStyle(
                          fontSize: 12,
                          color: hasWatch ? Colors.orange.shade700 : Colors.grey.shade500,
                          fontWeight: hasWatch ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasWatch
                        ? (watchReachable ? Colors.green.shade50 : Colors.grey.shade100)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: ZaiNeShadows.card,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasWatch ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                        size: 14,
                        color: hasWatch ? Colors.green.shade600 : Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hasWatch ? (watchReachable ? '已连接' : '已配对') : '未连接',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: hasWatch ? Colors.green.shade700 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: ZaiNeSpacing.lg),

            // 跌倒事件 / 功能说明
            if (hasEvents) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: ZaiNeShadows.card,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange.shade700),
                        const SizedBox(width: ZaiNeSpacing.sm),
                        Text(
                          unackedCount > 0
                              ? '最近跌倒 ($unackedCount 条待确认)'
                              : '最近跌倒记录',
                          style: TextStyle(
                            fontSize: ZaiNeFontSize.caption,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: ZaiNeSpacing.sm),
                    ...recentFalls.take(3).map((event) => _buildFallItem(event)),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: ZaiNeShadows.card,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildFallInfoItem(
                            icon: Icons.shield_outlined,
                            label: 'Apple Watch 跌倒检测',
                            value: hasWatch ? '已启用' : '未检测到',
                            color: hasWatch ? Colors.green : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: ZaiNeSpacing.lg),
                        Expanded(
                          child: _buildFallInfoItem(
                            icon: Icons.info_outline,
                            label: '参考信息',
                            value: '非医疗诊断',
                            color: Colors.blue.shade300,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: ZaiNeSpacing.md),
                    Row(
                      children: [
                        Icon(Icons.sensors, size: 14, color: Colors.orange.shade300),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '利用 Apple Watch 加速度传感器检测跌倒',
                            style: TextStyle(fontSize: 11, color: ZaiNeColors.textSecondary()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.timer, size: 14, color: Colors.orange.shade300),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '检测后 10 秒内可取消误报',
                            style: TextStyle(fontSize: 11, color: ZaiNeColors.textSecondary()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.notifications_active, size: 14, color: Colors.orange.shade300),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '超时未取消自动通知守护人',
                            style: TextStyle(fontSize: 11, color: ZaiNeColors.textSecondary()),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: ZaiNeSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.privacy_tip_outlined, size: 14, color: ZaiNeColors.textSecondary()),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      !hasWatch
                          ? '在 Apple Watch 上开启"设置 → SOS 紧急联络 → 跌倒检测"'
                          : '跌倒检测数据仅用于安全参考，不作为医疗诊断依据',
                      style: TextStyle(fontSize: 11, color: ZaiNeColors.textSecondary()),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: ZaiNeSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onViewHistory,
                    icon: const Icon(Icons.history, size: 16),
                    label: Text(hasEvents ? '查看历史 (${recentFalls.length})' : '查看历史'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange.shade700,
                      side: BorderSide(color: Colors.orange.shade200),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                if (!hasWatch) ...[
                  const SizedBox(width: ZaiNeSpacing.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showWatchGuide(context),
                      icon: const Icon(Icons.info_outline, size: 16),
                      label: const Text('如何开启'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallItem(FallEvent event) {
    final timeStr = DateFormat('MM/dd HH:mm').format(event.timestamp);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: event.acknowledged ? Colors.green.shade400 : Colors.orange.shade500,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(timeStr, style: TextStyle(fontSize: 11, color: ZaiNeColors.textSecondary())),
          const SizedBox(width: 6),
          Text(
            event.acknowledged ? '已确认' : '待确认',
            style: TextStyle(
              fontSize: 11,
              color: event.acknowledged ? Colors.green.shade600 : Colors.orange.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallInfoItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: ZaiNeColors.textSecondary(), fontSize: 11)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ],
    );
  }

  void _showWatchGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.watch_outlined, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Text('Apple Watch 跌倒检测设置'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('在 Apple Watch 上开启跌倒检测：',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            SizedBox(height: 12),
            _GuideStep(step: '1', text: '打开 Apple Watch 的"设置" App'),
            _GuideStep(step: '2', text: '轻点"SOS 紧急联络"'),
            _GuideStep(step: '3', text: '打开"跌倒检测"开关'),
            _GuideStep(step: '4', text: '建议选择"始终开启"以获得最佳保护'),
            SizedBox(height: 12),
            Text(
              '开启后，Apple Watch 会在检测到严重跌倒时自动拨打紧急电话，并通过本 App 通知你的守护人。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(backgroundColor: Colors.orange.shade50),
            child: Text('知道了', style: TextStyle(color: Colors.orange.shade700)),
          ),
        ],
      ),
    );
  }
}

/// 引导步骤组件
class _GuideStep extends StatelessWidget {
  final String step;
  final String text;

  const _GuideStep({required this.step, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(step,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.orange.shade700)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
