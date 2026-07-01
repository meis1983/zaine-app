import 'package:flutter/material.dart';
import '../theme/theme_helper.dart';
import 'package:intl/intl.dart';
import '../services/safety/safety_service.dart';

/// 位置历史记录页面
///
/// 展示某天的位置轨迹记录（时间轴形式）
class LocationHistoryPage extends StatefulWidget {
  final DateTime? day;

  const LocationHistoryPage({super.key, this.day});

  @override
  State<LocationHistoryPage> createState() => _LocationHistoryPageState();
}

class _LocationHistoryPageState extends State<LocationHistoryPage> {
  final SafetyService _safetyService = SafetyService();
  List<LocationRecord> _records = [];
  bool _isLoading = true;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.day ?? DateTime.now();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    await _safetyService.initialize();
    final records = await _safetyService.getLocationTrackForDay(_selectedDay);
    setState(() {
      _records = records;
      _isLoading = false;
    });
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDay = picked);
      await _loadRecords();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZaiNeColors.scaffoldBg(),
      appBar: AppBar(
        title: const Text('位置记录'),
        backgroundColor: ZaiNeColors.cardBg(),
        foregroundColor: ZaiNeColors.textPrimary(),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _pickDay,
            tooltip: '选择日期',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecords,
          ),
        ],
      ),
      body: Column(
        children: [
          // 日期显示
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: Colors.blue.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.blue.shade400),
                const SizedBox(width: ZaiNeSpacing.sm),
                Text(
                  DateFormat('yyyy年MM月dd日').format(_selectedDay),
                  style: TextStyle(
                    fontSize: ZaiNeFontSize.body,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: ZaiNeSpacing.sm),
                TextButton(
                  onPressed: _pickDay,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.sm, vertical: ZaiNeSpacing.xs),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('切换', style: TextStyle(fontSize: ZaiNeFontSize.caption)),
                ),
              ],
            ),
          ),

          // 记录列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _records.length,
                        itemBuilder: (context, index) {
                          final record = _records[index];
                          final isFirst = index == 0;
                          final isLast = index == _records.length - 1;
                          return _buildTimelineItem(record, isFirst, isLast, index);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off, size: 64, color: ZaiNeColors.textHint()),
          const SizedBox(height: ZaiNeSpacing.lg),
          Text(
            '暂无位置记录',
            style: TextStyle(fontSize: ZaiNeFontSize.body, color: ZaiNeColors.textSecondary()),
          ),
          const SizedBox(height: ZaiNeSpacing.sm),
          Text(
            '开启位置追踪后，每5分钟记录一次位置',
            style: TextStyle(fontSize: ZaiNeFontSize.caption, color: ZaiNeColors.textHint()),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(LocationRecord record, bool isFirst, bool isLast, int index) {
    final timeStr = DateFormat('HH:mm:ss').format(record.timestamp);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 时间轴
          SizedBox(
            width: 60,
            child: Column(
              children: [
                Text(
                  timeStr,
                  style: TextStyle(fontSize: ZaiNeFontSize.caption, color: Colors.grey.shade600),
                ),
                if (!isLast) ...[
                  const SizedBox(height: ZaiNeSpacing.xs),
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.blue.shade200,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: ZaiNeSpacing.md),

          // 记录卡片
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                border: Border.all(color: ZaiNeColors.borderColor()),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.blue.shade400),
                      const SizedBox(width: ZaiNeSpacing.sm),
                      Text(
                        '位置记录 ${_records.length - index}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: ZaiNeFontSize.caption),
                      ),
                      const Spacer(),
                      if (record.accuracy != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.sm, vertical: ZaiNeSpacing.xs),
                          decoration: BoxDecoration(
                            color: _getAccuracyColor(record.accuracy!).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                          ),
                          child: Text(
                            '精度±${record.accuracy!.toStringAsFixed(0)}m',
                            style: TextStyle(
                              fontSize: ZaiNeFontSize.micro,
                              color: _getAccuracyColor(record.accuracy!),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: ZaiNeSpacing.sm),
                  Text(
                    '纬度: ${record.latitude.toStringAsFixed(6)}',
                    style: TextStyle(fontSize: ZaiNeFontSize.caption, color: Colors.grey.shade700, fontFamily: 'monospace'),
                  ),
                  Text(
                    '经度: ${record.longitude.toStringAsFixed(6)}',
                    style: TextStyle(fontSize: ZaiNeFontSize.caption, color: Colors.grey.shade700, fontFamily: 'monospace'),
                  ),
                  if (record.accuracy != null) ...[
                    const SizedBox(height: ZaiNeSpacing.xs),
                    Text(
                      '定位精度约 ${record.accuracy!.toStringAsFixed(0)} 米（数值越小越精确）',
                      style: TextStyle(fontSize: ZaiNeFontSize.micro, color: Colors.grey.shade500),
                    ),
                  ],
                  if (record.address != null && record.address!.isNotEmpty) ...[
                    const SizedBox(height: ZaiNeSpacing.sm),
                    Row(
                      children: [
                        Icon(Icons.place, size: 14, color: ZaiNeColors.textSecondary()),
                        const SizedBox(width: ZaiNeSpacing.xs),
                        Expanded(
                          child: Text(
                            record.address!,
                            style: TextStyle(fontSize: ZaiNeFontSize.caption, color: Colors.grey.shade600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (record.activityType != null) ...[
                    const SizedBox(height: ZaiNeSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.sm, vertical: ZaiNeSpacing.xs),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                      ),
                      child: Text(
                        _getActivityText(record.activityType!),
                        style: TextStyle(fontSize: ZaiNeFontSize.micro, color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy <= 10) return Colors.green;
    if (accuracy <= 50) return Colors.orange;
    return Colors.red;
  }

  String _getActivityText(LocationActivityType type) {
    switch (type) {
      case LocationActivityType.stationary:
        return '静止';
      case LocationActivityType.walking:
        return '行走';
      case LocationActivityType.running:
        return '跑步';
      case LocationActivityType.cycling:
        return '骑行';
      case LocationActivityType.driving:
        return '驾驶';
      default:
        return '未知';
    }
  }
}
