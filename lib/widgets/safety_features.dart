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
  final DateTime? lastRecordTime; // 新增：上次记录时间

  const LocationTrackCard({
    super.key,
    required this.todayTrack,
    this.onViewFullMap,
    this.onStartTracking,
    this.isTracking = false,
    this.lastRecordTime, // 新增参数
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

  /// 格式化上次记录时间
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

/// 跌倒检测卡片（v1.76.0 框架展示，功能即将推出）
class FallDetectionCard extends StatelessWidget {
  final List<FallEvent> recentFalls;
  final bool isEnabled;
  final VoidCallback? onToggle;
  final Function(String)? onAcknowledge;
  final VoidCallback? onViewHistory;

  const FallDetectionCard({
    super.key,
    required this.recentFalls,
    this.isEnabled = false,
    this.onToggle,
    this.onAcknowledge,
    this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: ZaiNeColors.borderColor()),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onViewHistory != null
            ? () => _showComingSoonDialog(context, onViewHistory)
            : () => _showComingSoonDialog(context, null),
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
                    
                      boxShadow: ZaiNeShadows.card,),
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
                        Row(
                          children: [
                            const Text(
                              '跌倒检测',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(10),
                              
                                boxShadow: ZaiNeShadows.card,),
                              child: Text(
                                '即将推出',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '需要 Apple Watch 支持',
                          style: TextStyle(
                            fontSize: 12,
                            color: ZaiNeColors.textSecondary(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: ZaiNeColors.textSecondary(),
                    size: 20,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 功能说明
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                
                  boxShadow: ZaiNeShadows.card,),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.watch, color: ZaiNeColors.textSecondary(), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '佩戴 Apple Watch 可自动检测跌倒',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: ZaiNeColors.textSecondary(),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '检测到跌倒后自动通知守护人，为独居生活增添一份保障',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: ZaiNeColors.textSecondary(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 功能预览列表
                    _buildPreviewItem(Icons.sensors, '高精度传感器检测', '利用 Apple Watch 的加速度传感器'),
                    _buildPreviewItem(Icons.timer, '10秒取消窗口', '误报时可手动取消通知'),
                    _buildPreviewItem(Icons.notifications_active, '自动通知守护人', '超时未取消将自动发送求助信息'),
                    _buildPreviewItem(Icons.history, '跌倒记录回看', '可在安全中心查看历史跌倒事件'),
                  ],
                ),
              ),

              // 查看历史按钮
              if (onViewHistory != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: onViewHistory,
                    icon: Icon(Icons.history, size: 16, color: Colors.orange.shade400),
                    label: Text(
                      '查看历史记录',
                      style: TextStyle(color: Colors.orange.shade400),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.orange.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 功能预览条目
  Widget _buildPreviewItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.orange.shade300),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: ZaiNeColors.textSecondary(),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: ZaiNeColors.textSecondary(),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(4),
            
              boxShadow: ZaiNeShadows.card,),
            child: Text(
              '即将推出',
              style: TextStyle(
                fontSize: 10,
                color: Colors.orange.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 显示"即将推出"弹窗
  void _showComingSoonDialog(BuildContext context, VoidCallback? onViewHistory) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.watch, color: Colors.orange.shade400, size: 24),
            const SizedBox(width: 8),
            const Text('跌倒检测'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '此功能需要连接 Apple Watch 才能使用。',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(
              '功能特点：',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ZaiNeColors.textSecondary(),
              ),
            ),
            const SizedBox(height: 6),
            _buildFeaturePoint('自动检测跌倒事件'),
            _buildFeaturePoint('检测后10秒内可取消'),
            _buildFeaturePoint('超时自动通知守护人'),
            _buildFeaturePoint('跌倒事件记录与回看'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              
                boxShadow: ZaiNeShadows.card,),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade400, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '我们正在努力开发中，敬请期待！',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (onViewHistory != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                onViewHistory();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange.shade700,
              ),
              child: const Text('查看测试记录'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              backgroundColor: Colors.orange.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              '知道了',
              style: TextStyle(color: Colors.orange.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: Colors.orange.shade300),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: ZaiNeColors.textSecondary()),
          ),
        ],
      ),
    );
  }
}
