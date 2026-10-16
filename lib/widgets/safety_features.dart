import 'package:flutter/material.dart';
import '../services/safety/safety_service.dart';
import '../services/safety/safe_zone_service.dart';
import 'package:intl/intl.dart';
import '../theme/theme_helper.dart';
import '../l10n/i18n.dart';

/// 定时确认设置卡片
class CheckInReminderCard extends StatelessWidget {
  final CheckInReminder config;
  final Function(CheckInReminder) onConfigChanged;
  final VoidCallback onPerformCheckIn;

  CheckInReminderCard({
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
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        side: BorderSide(color: ZaiNeColors.borderColor()),
      ),
      child: Padding(
        padding: EdgeInsets.all(ZaiNeSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(ZaiNeSpacing.cardXs),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                  
                    boxShadow: ZaiNeShadows.card,),
                  child: Icon(
                    Icons.alarm_on,
                    color: Colors.green.shade400,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr.z0525,
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
              SizedBox(height: 16),
              Divider(),
              SizedBox(height: 12),

              // 提醒频率选择
              Text(
                tr.z0526,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              _buildFrequencySelector(context),
              SizedBox(height: 16),

              // 【P3】触发方式选择
              Text(
                tr.z0527,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              _buildTriggerModeSelector(context),
              SizedBox(height: 16),

              // 提醒时间选择（仅「时间定时」模式显示；其他模式展示场景说明）
              if (config.triggerMode == CheckInTriggerMode.time) ...[
                Text(
                  tr.s068,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                _buildTimeChips(context),
              ] else ...[
                Container(
                  padding: EdgeInsets.all(ZaiNeSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                    boxShadow: ZaiNeShadows.card,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.green.shade400, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          config.triggerMode == CheckInTriggerMode.location
                              ? tr.z0528
                              : tr.z0529,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (config.lastCheckIn != null) ...[
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(ZaiNeSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                  
                    boxShadow: ZaiNeShadows.card,),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade400, size: 20),
                      SizedBox(width: 8),
                      Text(
                        tr.z0530(_formatLastCheckIn(config.lastCheckIn!)),
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
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(ZaiNeSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                  
                    boxShadow: ZaiNeShadows.card,),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange.shade400, size: 20),
                      SizedBox(width: 8),
                      Text(
                        tr.z0531(config.missedCount),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onPerformCheckIn,
                  icon: Icon(Icons.check_circle_outline),
                  label: Text(tr.z0532),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ZaiNeRadius.small),
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
    if (!config.enabled) return tr.z0023;
    final modeText = switch (config.triggerMode) {
      CheckInTriggerMode.time => tr.z0024,
      CheckInTriggerMode.location => tr.z0533,
      CheckInTriggerMode.heartbeat => tr.z0534,
    };
    switch (config.status) {
      case CheckInReminderStatus.daily:
        return tr.z0535(modeText);
      case CheckInReminderStatus.weekly:
        return tr.z0536(modeText);
      case CheckInReminderStatus.custom:
        return tr.z0537(modeText);
      default:
        return modeText;
    }
  }

  Widget _buildFrequencySelector(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        _buildFrequencyChip(
          context,
          tr.z0538,
          CheckInReminderStatus.daily,
        ),
        _buildFrequencyChip(
          context,
          tr.z0539,
          CheckInReminderStatus.weekly,
        ),
        _buildFrequencyChip(
          context,
          tr.z0015,
          CheckInReminderStatus.custom,
        ),
      ],
    );
  }

  /// 【P3】触发方式选择（时间定时 / 离开安全区 / 手表心跳）
  Widget _buildTriggerModeSelector(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildTriggerModeChip(context, tr.z0024, CheckInTriggerMode.time, Icons.schedule),
        _buildTriggerModeChip(context, tr.z0540, CheckInTriggerMode.location, Icons.location_off),
        _buildTriggerModeChip(context, tr.z0541, CheckInTriggerMode.heartbeat, Icons.favorite),
      ],
    );
  }

  Widget _buildTriggerModeChip(
    BuildContext context,
    String label,
    CheckInTriggerMode mode,
    IconData icon,
  ) {
    final isSelected = config.triggerMode == mode;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.green.shade700 : Colors.grey.shade600),
          SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          onConfigChanged(config.copyWith(triggerMode: mode));
        }
      },
      selectedColor: Colors.green.shade100,
      labelStyle: TextStyle(
        color: isSelected ? Colors.green.shade700 : Colors.grey.shade600,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
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
      7: tr.z0542,
      9: tr.z0543,
      12: tr.z0025,
      18: tr.z0544,
      21: tr.z0545,
      22: tr.z0546,
    };

    // 用户自定义的时间（不在预设 6 个时段中的小时）
    final customHours = config.reminderHours
        .where((h) => !defaultHours.containsKey(h))
        .toList()
      ..sort();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...defaultHours.entries.map((entry) {
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
        }),
        // 【v1.95.0+115 新功能】自定义时间 Chip：点 × 删除
        ...customHours.map((hour) {
          return FilterChip(
            label: Text(_formatHourLabel(hour)),
            selected: true,
            onSelected: (_) {}, // 选中态不切换，用删除图标移除
            onDeleted: () {
              final hours = List<int>.from(config.reminderHours)..remove(hour);
              onConfigChanged(config.copyWith(reminderHours: hours));
            },
            selectedColor: Colors.green.shade100,
            checkmarkColor: Colors.green.shade700,
            deleteIconColor: Colors.green.shade700,
            labelStyle: TextStyle(color: Colors.green.shade700),
          );
        }),
        // 【v1.95.0+115 新功能】添加自定义时间：原生时间选择器
        ActionChip(
          avatar: Icon(Icons.add, size: 16, color: Colors.green.shade700),
          label: Text(tr.z0547,
              style: TextStyle(color: Colors.green.shade700, fontSize: 13)),
          backgroundColor: Colors.green.shade50,
          onPressed: () => _pickCustomTime(context),
        ),
      ],
    );
  }

  /// 【v1.95.0+115】打开系统时间选择器，允许用户设定任意整点提醒时间
  Future<void> _pickCustomTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: tr.z0548,
    );
    if (picked == null) return;
    final hours = List<int>.from(config.reminderHours);
    if (!hours.contains(picked.hour)) {
      hours.add(picked.hour);
      hours.sort();
      onConfigChanged(config.copyWith(reminderHours: hours));
    }
  }

  /// 将整点小时格式化为中文标签（自定义时间专用）
  String _formatHourLabel(int hour) {
    if (hour == 0) return tr.z0549;
    if (hour < 6) return tr.z0550(hour);
    if (hour < 12) return tr.z0551(hour);
    if (hour == 12) return tr.z0025;
    if (hour < 18) return tr.z0552(hour);
    return tr.z0553(hour);
  }

  String _formatLastCheckIn(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 60) return tr.z0001(diff.inMinutes);
    if (diff.inHours < 24) return tr.z0002(diff.inHours);
    if (diff.inDays < 7) return tr.z0003(diff.inDays);
    return DateFormat('MM/dd HH:mm').format(time);
  }
}

/// 位置轨迹卡片
/// 【v1.93.0】重构：添加追踪模式选择、UI说明文字、地图预览
class LocationTrackCard extends StatefulWidget {
  final List<LocationRecord> todayTrack;
  final VoidCallback? onViewFullMap;
  final VoidCallback? onStartTracking;
  final VoidCallback? onStopTracking;
  final ValueChanged<LocationTrackingMode>? onModeChanged;
  final bool isTracking;
  final LocationTrackingMode currentMode;
  final DateTime? lastRecordTime;

  LocationTrackCard({
    super.key,
    required this.todayTrack,
    this.onViewFullMap,
    this.onStartTracking,
    this.onStopTracking,
    this.onModeChanged,
    this.isTracking = false,
    this.currentMode = LocationTrackingMode.normal,
    this.lastRecordTime,
  });

  @override
  State<LocationTrackCard> createState() => _LocationTrackCardState();
}

class _LocationTrackCardState extends State<LocationTrackCard> {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        side: BorderSide(color: ZaiNeColors.borderColor()),
      ),
      child: Padding(
        padding: EdgeInsets.all(ZaiNeSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(ZaiNeSpacing.cardXs),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                    boxShadow: ZaiNeShadows.card,
                  ),
                  child: Icon(
                    Icons.location_on,
                    color: Colors.blue.shade400,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr.z0554,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.isTracking ? _getModeDescription() : tr.z0555,
                        style: TextStyle(
                          fontSize: 12,
                          color: ZaiNeColors.textSecondary(),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.isTracking ? Colors.green.shade100 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                    boxShadow: ZaiNeShadows.card,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.isTracking ? Colors.green : Colors.grey,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        widget.isTracking ? tr.z0556 : tr.s048,
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.isTracking ? Colors.green.shade700 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 12),

            // 【v1.93.0】说明文字：守护者可见提示
            if (widget.isTracking)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(ZaiNeRadius.button),
                ),
                child: Row(
                  children: [
                    Icon(Icons.visibility, size: 14, color: Colors.blue.shade500),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        tr.z0557(_getIntervalText()),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (widget.isTracking) SizedBox(height: 12),

            // 【v1.93.0】地图预览缩略图
            if (widget.todayTrack.length >= 2 && widget.isTracking)
              _buildMiniMapPreview()
            else if (widget.isTracking && widget.todayTrack.length < 2)
              Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map_outlined, size: 28, color: Colors.grey.shade400),
                      SizedBox(height: 4),
                      Text(
                        tr.z0558,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ),

            if (widget.isTracking && widget.todayTrack.length >= 2) SizedBox(height: 12),

            // 【v1.93.0】追踪模式选择（v1.94.0 修复：未追踪时也可选择）
            Row(
              children: [
                Text(
                  tr.z0559,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                SizedBox(width: ZaiNeSpacing.sm),
                Text(
                  widget.isTracking ? tr.z0560 : tr.z0561,
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.isTracking ? Colors.green.shade600 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            _buildModeSelector(),
            SizedBox(height: 12),

            // 今日轨迹摘要
            if (widget.todayTrack.isNotEmpty) ...[
              Container(
                padding: EdgeInsets.all(ZaiNeSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                  boxShadow: ZaiNeShadows.card,
                ),
                child: Row(
                  children: [
                    Icon(Icons.timeline, color: Colors.blue.shade400, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr.s907,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          Text(
                            tr.z0562(widget.todayTrack.length),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onViewFullMap,
                      child: Text(tr.z0022),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: EdgeInsets.all(ZaiNeSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                  boxShadow: ZaiNeShadows.card,
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: ZaiNeColors.textSecondary(), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tr.z0563,
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

            if (widget.lastRecordTime != null && widget.isTracking) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(ZaiNeSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                  boxShadow: ZaiNeShadows.card,
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: Colors.green.shade400, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr.z0564,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.green.shade700,
                            ),
                          ),
                          Text(
                            _formatLastRecordTime(widget.lastRecordTime!),
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
            ],

            SizedBox(height: 12),

            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.isTracking ? widget.onStopTracking : widget.onStartTracking,
                    icon: Icon(widget.isTracking ? Icons.stop : Icons.play_arrow),
                    label: Text(widget.isTracking ? tr.z0565 : tr.z0566),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: widget.isTracking ? Colors.red : Colors.blue,
                      side: BorderSide(
                        color: widget.isTracking ? Colors.red : Colors.blue,
                      ),
                      padding: EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ZaiNeRadius.input),
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

  String _getModeDescription() {
    switch (widget.currentMode) {
      case LocationTrackingMode.realtime:
        return tr.z0567;
      case LocationTrackingMode.normal:
        return tr.z0568;
      case LocationTrackingMode.powersave:
        return tr.z0569;
    }
  }

  String _getIntervalText() {
    switch (widget.currentMode) {
      case LocationTrackingMode.realtime:
        return tr.z0570;
      case LocationTrackingMode.normal:
        return tr.z0571;
      case LocationTrackingMode.powersave:
        return tr.z0572;
    }
  }

  Widget _buildModeSelector() {
    final modes = [
      (LocationTrackingMode.realtime, tr.z0573, tr.z0574),
      (LocationTrackingMode.normal, tr.z0575, tr.z0576),
      (LocationTrackingMode.powersave, tr.z0577, tr.z0578),
    ];

    return SegmentedButton<LocationTrackingMode>(
      segments: modes.map((m) {
        return ButtonSegment<LocationTrackingMode>(
          value: m.$1,
          label: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                m.$2,
                style: TextStyle(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                m.$3,
                style: TextStyle(fontSize: 9),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      }).toList(),
      selected: {widget.currentMode},
      onSelectionChanged: (selected) {
        widget.onModeChanged?.call(selected.first);
      },
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.blue.shade100;
          }
          return Colors.grey.shade100;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.blue.shade700;
          }
          return Colors.grey.shade600;
        }),
      ),
    );
  }

  /// 【v1.93.0】轨迹缩略图（CustomPainter）
  Widget _buildMiniMapPreview() {
    final points = widget.todayTrack.reversed.toList();

    // 计算边界
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    // 防止单点情况下无边界
    if ((maxLat - minLat) < 0.0001) { maxLat += 0.0005; minLat -= 0.0005; }
    if ((maxLng - minLng) < 0.0001) { maxLng += 0.0005; minLng -= 0.0005; }

    return GestureDetector(
      onTap: widget.onViewFullMap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: Color(0xFFE8F0FE),
          borderRadius: BorderRadius.circular(ZaiNeRadius.small),
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ZaiNeRadius.small),
          child: Stack(
            children: [
              // 地图网格背景
              CustomPaint(
                size: Size.infinite,
                painter: _MiniMapPainter(
                  points: points,
                  minLat: minLat,
                  maxLat: maxLat,
                  minLng: minLng,
                  maxLng: maxLng,
                ),
              ),
              // 叠加信息
              Positioned(
                bottom: 6,
                left: 8,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(ZaiNeRadius.tag),
                  ),
                  child: Text(
                    tr.z0579(widget.todayTrack.length),
                    style: TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatLastRecordTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return tr.s430;
    if (diff.inMinutes < 60) return tr.z0001(diff.inMinutes);
    if (diff.inHours < 24) return tr.z0002(diff.inHours);
    if (diff.inDays < 7) return tr.z0003(diff.inDays);
    return DateFormat('MM/dd HH:mm').format(time);
  }
}

/// 【v1.93.0】迷你地图绘制器
class _MiniMapPainter extends CustomPainter {
  final List<LocationRecord> points;
  final double minLat, maxLat, minLng, maxLng;

  _MiniMapPainter({
    required this.points,
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.6)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final startDotPaint = Paint()
      ..color = Colors.green.shade600
      ..strokeWidth = 0
      ..style = PaintingStyle.fill;

    final endDotPaint = Paint()
      ..color = Colors.red.shade600
      ..strokeWidth = 0
      ..style = PaintingStyle.fill;

    // 添加内边距
    const padding = 12.0;
    final w = size.width - padding * 2;
    final h = size.height - padding * 2;

    // 转换函数：经纬度 → 画布坐标
    Offset toCanvas(LocationRecord p) {
      final x = padding + ((p.longitude - minLng) / (maxLng - minLng)) * w;
      final y = padding + ((maxLat - p.latitude) / (maxLat - minLat)) * h;
      return Offset(x, y);
    }

    // 画路径线
    if (points.length >= 2) {
      final path = Path();
      path.moveTo(toCanvas(points.first).dx, toCanvas(points.first).dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(toCanvas(points[i]).dx, toCanvas(points[i]).dy);
      }
      canvas.drawPath(path, paint);
    }

    // 画起始点（绿点）
    if (points.isNotEmpty) {
      final start = toCanvas(points.last); // 最早的点
      canvas.drawCircle(start, 5, startDotPaint);
    }

    // 画终点（红点）
    if (points.isNotEmpty) {
      final end = toCanvas(points.first); // 最新的点
      canvas.drawCircle(end, 5, endDotPaint..color = Colors.red.shade600);
      // 红色脉冲圈
      canvas.drawCircle(end, 9, Paint()
        ..color = Colors.red.withValues(alpha: 0.2)
        ..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

/// 跌倒检测卡片
/// 整合 Apple Watch 跌倒检测 + 手机端加速度传感器检测
class MotionMonitorCard extends StatelessWidget {
  final List<MotionEvent> recentFalls;
  final bool watchPaired;
  final bool watchReachable;
  final bool phoneDetectionEnabled;
  final Function(String)? onAcknowledge;
  final VoidCallback? onViewHistory;
  final VoidCallback? onTogglePhoneDetection;

  MotionMonitorCard({
    super.key,
    required this.recentFalls,
    this.watchPaired = false,
    this.watchReachable = false,
    this.phoneDetectionEnabled = false,
    this.onAcknowledge,
    this.onViewHistory,
    this.onTogglePhoneDetection,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasWatch = watchPaired;
    final bool hasEvents = recentFalls.isNotEmpty;
    final int unackedCount = recentFalls.where((f) => !f.acknowledged).length;
    final bool anyDetectionActive = hasWatch || phoneDetectionEnabled;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        side: BorderSide(color: ZaiNeColors.borderColor()),
      ),
      child: Padding(
        padding: EdgeInsets.all(ZaiNeSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(ZaiNeSpacing.cardXs),
                  decoration: BoxDecoration(
                    color: anyDetectionActive ? Colors.orange.shade100 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                    boxShadow: ZaiNeShadows.card,
                  ),
                  child: Icon(
                    anyDetectionActive ? Icons.health_and_safety : Icons.health_and_safety_outlined,
                    color: anyDetectionActive ? Colors.orange.shade600 : Colors.grey.shade500,
                    size: 22,
                  ),
                ),
                SizedBox(width: ZaiNeSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr.z0580,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 2),
                      Text(
                        _getStatusText(hasWatch, phoneDetectionEnabled),
                        style: TextStyle(
                          fontSize: 12,
                          color: anyDetectionActive ? Colors.orange.shade700 : Colors.grey.shade500,
                          fontWeight: anyDetectionActive ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                // 功能说明按钮
                GestureDetector(
                  onTap: () => _showFeatureExplanation(context),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(Icons.help_outline, size: 16, color: Colors.grey.shade600),
                    ),
                  ),
                ),
                SizedBox(width: 6),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: anyDetectionActive
                        ? Colors.green.shade50
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                    boxShadow: ZaiNeShadows.card,
                  ),
                  child: Text(
                    anyDetectionActive ? tr.s660 : tr.z0581,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: anyDetectionActive ? Colors.green.shade700 : Colors.grey.shade500,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: ZaiNeSpacing.lg),

            // 检测状态说明
            Container(
              padding: EdgeInsets.all(ZaiNeSpacing.md),
              decoration: BoxDecoration(
                color: anyDetectionActive ? Colors.green.shade50 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(ZaiNeRadius.small),
              ),
              child: Column(
                children: [
                  // Apple Watch 状态
                  // 【v1.94.0】修复：配对即视为可用（WCSession 后台也能接收跌倒数据），
                  // isReachable 仅表示 Watch App 是否在前台，不作为检测能力判定
                  _buildDetectionStatusRow(
                    icon: Icons.watch,
                    label: tr.z0582,
                    status: hasWatch
                        ? (watchReachable ? tr.z0583 : tr.s625)
                        : tr.z0584,
                    active: hasWatch,
                  ),
                  SizedBox(height: 8),
                  Divider(height: 1),
                  SizedBox(height: 8),
                  // 手机端检测状态
                  _buildDetectionStatusRow(
                    icon: Icons.phone_android,
                    label: tr.z0026,
                    status: phoneDetectionEnabled ? tr.z0585 : tr.z0023,
                    active: phoneDetectionEnabled,
                  ),
                ],
              ),
            ),

            SizedBox(height: ZaiNeSpacing.lg),

            // 跌倒事件 / 功能说明
            if (hasEvents) ...[
              Container(
                padding: EdgeInsets.all(ZaiNeSpacing.cardSm),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                  boxShadow: ZaiNeShadows.card,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange.shade700),
                        SizedBox(width: ZaiNeSpacing.sm),
                        Text(
                          unackedCount > 0
                              ? tr.z0586(unackedCount)
                              : tr.z0587,
                          style: TextStyle(
                            fontSize: ZaiNeFontSize.caption,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ZaiNeSpacing.sm),
                    ...recentFalls.take(3).map((event) => _buildFallItem(event)),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: EdgeInsets.all(ZaiNeSpacing.cardSm),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                  boxShadow: ZaiNeShadows.card,
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 20, color: Colors.green),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tr.z0588,
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(height: ZaiNeSpacing.md),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(ZaiNeRadius.button),
              ),
              child: Row(
                children: [
                  Icon(Icons.privacy_tip_outlined, size: 14, color: ZaiNeColors.textSecondary()),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tr.z0589,
                      style: TextStyle(fontSize: 11, color: ZaiNeColors.textSecondary()),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: ZaiNeSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onViewHistory,
                    icon: Icon(Icons.history, size: 16),
                    label: Text(hasEvents ? tr.z0590(recentFalls.length) : tr.z0591),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange.shade700,
                      side: BorderSide(color: Colors.orange.shade200),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ZaiNeRadius.input),
                      ),
                    ),
                  ),
                ),
                // 手机端检测开关
                SizedBox(width: ZaiNeSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onTogglePhoneDetection,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: phoneDetectionEnabled
                          ? Colors.red.shade600
                          : Colors.blue.shade600,
                      side: BorderSide(
                        color: phoneDetectionEnabled
                            ? Colors.red.shade200
                            : Colors.blue.shade200,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ZaiNeRadius.input),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Text(
                      phoneDetectionEnabled ? tr.z0592 : tr.z0593,
                      style: const TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  String _getStatusText(bool hasWatch, bool phoneEnabled) {
    if (hasWatch && watchReachable) return tr.z0594;
    if (hasWatch) return tr.z0595;
    if (phoneEnabled) return tr.z0596;
    return tr.z0597;
  }

  Widget _buildDetectionStatusRow({
    required IconData icon,
    required String label,
    required String status,
    required bool active,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: active ? Colors.green : Colors.grey,
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: active ? Colors.green.shade700 : Colors.grey.shade600,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        SizedBox(width: 8),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? Colors.green : Colors.grey.shade400,
          ),
        ),
        SizedBox(width: 4),
        Text(
          status,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: active ? Colors.green.shade700 : Colors.grey.shade500,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }

  Widget _buildFallItem(MotionEvent event) {
    final timeStr = DateFormat('MM/dd HH:mm').format(event.timestamp);
    final isPhoneEvent = event.id.startsWith('phone_');
    return Padding(
      padding: EdgeInsets.only(top: 8),
      child: Container(
        padding: EdgeInsets.all(ZaiNeSpacing.cardXs),
        decoration: BoxDecoration(
          color: event.acknowledged ? Colors.green.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(ZaiNeRadius.button),
          border: Border.all(
            color: event.acknowledged ? Colors.green.shade100 : Colors.orange.shade100,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: event.acknowledged ? Colors.green.shade400 : Colors.orange.shade500,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 6),
                Text(timeStr, style: TextStyle(fontSize: 11, color: ZaiNeColors.textSecondary())),
                SizedBox(width: 6),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isPhoneEvent ? Colors.blue.shade50 : Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(ZaiNeRadius.tag),
                  ),
                  child: Text(
                    isPhoneEvent ? tr.s627 : 'Watch',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isPhoneEvent ? Colors.blue.shade700 : Colors.purple.shade700,
                    ),
                  ),
                ),
                Spacer(),
                Text(
                  event.acknowledged ? tr.z0598 : tr.z0599,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: event.acknowledged ? Colors.green.shade600 : Colors.orange.shade600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on, size: 12, color: Colors.grey.shade500),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '(${event.latitude.toStringAsFixed(4)}, ${event.longitude.toStringAsFixed(4)})',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                      fontFamily: 'monospace',
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

  void _showFeatureExplanation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.card)),
        title: Row(
          children: [
            Icon(Icons.health_and_safety, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Text(tr.s638),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr.z0600,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            SizedBox(height: 12),
            // Apple Watch 检测
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.watch, size: 18, color: Colors.purple),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr.z0601,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text(
                        tr.z0602,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            // 手机端检测
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.phone_android, size: 18, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr.z0026,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text(
                        tr.z0603,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.warning_amber, size: 14, color: Colors.orange),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tr.z0604,
                    style: TextStyle(fontSize: 11, color: Colors.orange),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(backgroundColor: Colors.orange.shade50),
            child: Text(tr.s087, style: TextStyle(color: Colors.orange.shade700)),
          ),
        ],
      ),
    );
  }
}

/// 安全围栏卡片
/// 【v1.93.0】在安全设置页面展示地理围栏状态
class SafeZoneCard extends StatefulWidget {
  final VoidCallback? onManageFences;

  SafeZoneCard({super.key, this.onManageFences});

  @override
  State<SafeZoneCard> createState() => _SafeZoneCardState();
}

class _SafeZoneCardState extends State<SafeZoneCard> {
  final SafeZoneMonitor? _service = getSafeZoneService();
  List<SafeZone> _fences = [];

  @override
  void initState() {
    super.initState();
    _loadFences();
  }

  Future<void> _loadFences() async {
    await _service?.init();
    final fences = await _service?.getAllFences() ?? [];
    if (mounted) {
      setState(() {
        _fences = fences;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabledFences = _fences.where((f) => f.enabled).toList();
    final outsideCount = enabledFences.where((f) => f.status == SafeZoneStatus.outside).length;
    final insideCount = enabledFences.where((f) => f.status == SafeZoneStatus.inside).length;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        side: BorderSide(color: ZaiNeColors.borderColor()),
      ),
      child: Padding(
        padding: EdgeInsets.all(ZaiNeSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(ZaiNeSpacing.cardXs),
                  decoration: BoxDecoration(
                    color: _fences.isEmpty ? Colors.grey.shade100 : Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                    boxShadow: ZaiNeShadows.card,
                  ),
                  child: Icon(
                    Icons.fence,
                    color: _fences.isEmpty ? Colors.grey.shade400 : Colors.purple.shade400,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr.s653,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _fences.isEmpty ? tr.z0605 : tr.z0606(enabledFences.length, insideCount),
                        style: TextStyle(fontSize: 12, color: ZaiNeColors.textSecondary()),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (outsideCount > 0)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(ZaiNeRadius.input),
                    ),
                    child: Text(
                      tr.z0607(outsideCount),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
              ],
            ),

            if (_fences.isNotEmpty) ...[
              SizedBox(height: 12),

              // 说明文字
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(ZaiNeRadius.button),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.purple.shade400),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        tr.z0608,
                        style: TextStyle(fontSize: 11, color: Colors.purple.shade600),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 8),

              // 围栏列表
              ...enabledFences.map((fence) => _buildFenceRow(fence)),
            ],

            SizedBox(height: 12),

            // 管理按钮
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  widget.onManageFences?.call();
                  // 返回后刷新
                  Future.delayed(Duration(milliseconds: 500), _loadFences);
                },
                icon: Icon(
                  _fences.isEmpty ? Icons.add : Icons.settings,
                  size: 18,
                ),
                label: Text(_fences.isEmpty ? tr.z0609 : tr.z0610),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _fences.isEmpty ? Colors.blue : Colors.purple.shade600,
                  side: BorderSide(
                    color: _fences.isEmpty ? Colors.blue.shade300 : Colors.purple.shade200,
                  ),
                  padding: EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.input)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFenceRow(SafeZone fence) {
    final isInside = fence.status == SafeZoneStatus.inside;
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isInside ? Colors.green.shade50 : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(ZaiNeRadius.input),
        ),
        child: Row(
          children: [
            Icon(
              fence.type == SafeZoneType.home
                  ? Icons.home
                  : fence.type == SafeZoneType.work
                      ? Icons.work
                      : Icons.location_on,
              size: 16,
              color: isInside ? Colors.green.shade600 : Colors.orange.shade600,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                tr.z0611(fence.name, fence.radius.toStringAsFixed(0)),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isInside ? Colors.green.shade800 : Colors.orange.shade800,
                ),
              ),
            ),
            Icon(
              isInside ? Icons.check_circle : Icons.warning_amber,
              size: 18,
              color: isInside ? Colors.green : Colors.orange,
            ),
          ],
        ),
      ),
    );
  }
}