import 'package:flutter/material.dart';
import '../theme/theme_helper.dart';
import 'package:intl/intl.dart';
import '../services/safety/safety_service.dart';
import '../services/platform/watch_data_service.dart';

/// 跌倒事件历史页面
///
/// 展示 Apple Watch 检测到的跌倒事件记录
class FallEventHistoryPage extends StatefulWidget {
  const FallEventHistoryPage({super.key});

  @override
  State<FallEventHistoryPage> createState() => _FallEventHistoryPageState();
}

class _FallEventHistoryPageState extends State<FallEventHistoryPage> {
  final SafetyService _safetyService = SafetyService();
  final WatchDataService _watchService = WatchDataService();
  List<FallEvent> _events = [];
  bool _isLoading = true;
  bool _watchPaired = false;
  bool _watchReachable = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _safetyService.initialize();
    final events = await _safetyService.getFallEvents();
    await _watchService.refreshWatchState();
    setState(() {
      _events = events;
      _watchPaired = _watchService.isPaired;
      _watchReachable = _watchService.isReachable;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZaiNeColors.scaffoldBg(),
      appBar: AppBar(
        title: const Text('跌倒事件记录'),
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
      body: Column(
        children: [
          // 功能状态提示（根据 Apple Watch 配对状态显示）
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _watchPaired ? Colors.green.shade50 : Colors.orange.shade50,
            child: Row(
              children: [
                Icon(
                  _watchPaired ? Icons.check_circle_outline : Icons.info_outline,
                  color: _watchPaired ? Colors.green.shade600 : Colors.orange.shade400,
                  size: 20,
                ),
                const SizedBox(width: ZaiNeSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _watchPaired
                            ? (_watchReachable ? '跌倒检测已启用，Apple Watch 正在监测' : '跌倒检测已启用，Apple Watch 已配对')
                            : '跌倒检测需要 Apple Watch 支持',
                        style: TextStyle(
                          fontSize: ZaiNeFontSize.bodySm,
                          fontWeight: FontWeight.w600,
                          color: _watchPaired ? Colors.green.shade700 : Colors.orange.shade700,
                        ),
                      ),
                      const SizedBox(height: ZaiNeSpacing.xs),
                      Text(
                        _watchPaired
                            ? '检测到跌倒后会自动记录在这里，并在 10 秒内允许您取消误报'
                            : '请确保 iPhone 已与 Apple Watch 配对，并在 Watch 上启用跌倒检测',
                        style: TextStyle(
                          fontSize: ZaiNeFontSize.caption,
                          color: _watchPaired ? Colors.green.shade600 : Colors.orange.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 事件列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _events.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _events.length,
                        itemBuilder: (context, index) {
                          final event = _events[index];
                          return _buildEventCard(event, index);
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
          Icon(Icons.sensors, size: 64, color: ZaiNeColors.textHint()),
          const SizedBox(height: ZaiNeSpacing.lg),
          Text(
            '暂无跌倒事件',
            style: TextStyle(fontSize: ZaiNeFontSize.body, color: ZaiNeColors.textSecondary()),
          ),
          const SizedBox(height: ZaiNeSpacing.sm),
          Text(
            'Apple Watch 会持续监测，检测到跌倒后会自动记录在这里',
            style: TextStyle(fontSize: ZaiNeFontSize.caption, color: ZaiNeColors.textHint()),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(FallEvent event, int index) {
    final timeStr = DateFormat('MM/dd HH:mm').format(event.timestamp);
    final confidencePercent = event.confidence != null
        ? '${(event.confidence! * 100).toStringAsFixed(0)}%'
        : '未知';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        border: Border.all(
          color: event.acknowledged ? Colors.grey.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部：状态 + 时间
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.sm, vertical: ZaiNeSpacing.xs),
                decoration: BoxDecoration(
                  color: event.acknowledged
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      event.acknowledged ? Icons.check_circle : Icons.warning_amber,
                      size: 14,
                      color: event.acknowledged ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: ZaiNeSpacing.xs),
                    Text(
                      event.acknowledged ? '已确认' : '待确认',
                      style: TextStyle(
                        fontSize: ZaiNeFontSize.caption,
                        fontWeight: FontWeight.w600,
                        color: event.acknowledged ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                timeStr,
                style: TextStyle(fontSize: ZaiNeFontSize.caption, color: ZaiNeColors.textSecondary()),
              ),
            ],
          ),

          const SizedBox(height: ZaiNeSpacing.md),

          // 位置信息
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: ZaiNeColors.textSecondary()),
              const SizedBox(width: ZaiNeSpacing.sm),
              Expanded(
                child: Text(
                  '纬度: ${event.latitude.toStringAsFixed(6)}, 经度: ${event.longitude.toStringAsFixed(6)}',
                  style: TextStyle(
                    fontSize: ZaiNeFontSize.caption,
                    color: Colors.grey.shade700,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: ZaiNeSpacing.sm),

          // 置信度 + 确认时间
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.sm, vertical: ZaiNeSpacing.xs),
                decoration: BoxDecoration(
                  color: _getConfidenceColor(event.confidence).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                ),
                child: Text(
                  '置信度: $confidencePercent',
                  style: TextStyle(
                    fontSize: ZaiNeFontSize.micro,
                    color: _getConfidenceColor(event.confidence),
                  ),
                ),
              ),
              const SizedBox(width: ZaiNeSpacing.sm),
              if (event.acknowledgedAt != null)
                Expanded(
                  child: Text(
                    '确认于 ${DateFormat('HH:mm').format(event.acknowledgedAt!)}',
                    style: TextStyle(fontSize: ZaiNeFontSize.micro, color: ZaiNeColors.textSecondary()),
                  ),
                ),
            ],
          ),

          if (event.notes != null && event.notes!.isNotEmpty) ...[
            const SizedBox(height: ZaiNeSpacing.sm),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(ZaiNeRadius.small),
              ),
              child: Row(
                children: [
                  Icon(Icons.note, size: 14, color: ZaiNeColors.textSecondary()),
                  const SizedBox(width: ZaiNeSpacing.sm),
                  Expanded(
                    child: Text(
                      event.notes!,
                      style: TextStyle(fontSize: ZaiNeFontSize.caption, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 操作按钮（未确认时显示）
          if (!event.acknowledged) ...[
            const SizedBox(height: ZaiNeSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await _safetyService.acknowledgeFallEvent(event.id);
                  await _loadData();
                },
                icon: const Icon(Icons.check, size: 16),
                label: const Text('确认为误报'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange.shade700,
                  side: BorderSide(color: Colors.orange.shade300),
                  padding: const EdgeInsets.symmetric(vertical: ZaiNeSpacing.sm),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getConfidenceColor(double? confidence) {
    if (confidence == null) return Colors.grey;
    if (confidence >= 0.8) return Colors.red;
    if (confidence >= 0.5) return Colors.orange;
    return Colors.green;
  }
}
