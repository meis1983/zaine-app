import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/theme_helper.dart';
import 'package:intl/intl.dart';
import '../services/safety/safety_service.dart';
import '../services/platform/watch_data_service.dart';
import '../l10n/i18n.dart';

/// 跌倒事件历史页面
///
/// 展示 Apple Watch / 手机端 检测到的跌倒事件记录
class MotionEventHistoryPage extends StatefulWidget {
  const MotionEventHistoryPage({super.key});

  @override
  State<MotionEventHistoryPage> createState() => _MotionEventHistoryPageState();
}

class _MotionEventHistoryPageState extends State<MotionEventHistoryPage> {
  final SafetyService _safetyService = SafetyService();
  final WatchDataService _watchService = WatchDataService();
  List<MotionEvent> _events = [];
  bool _isLoading = true;
  bool _watchPaired = false;
  bool _watchReachable = false;
  Timer? _watchTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    // 【v1.94.0】轻量轮询，确保 Watch 连接状态及时刷新（与 safety_settings_page 一致）
    _watchTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final state = await _watchService.refreshWatchState();
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
    setState(() => _isLoading = true);
    await _safetyService.initialize();
    final events = await _safetyService.getMotionEvents();
    await _watchService.refreshWatchState();
    setState(() {
      _events = events;
      _watchPaired = _watchService.isPaired;
      _watchReachable = _watchService.isReachable;
      _isLoading = false;
    });
  }

  /// 获取友好的位置描述
  String _formatLocation(double lat, double lng) {
    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZaiNeColors.scaffoldBg(),
      appBar: AppBar(
        title:  Text(tr.s622),
        backgroundColor: ZaiNeColors.cardBg(),
        foregroundColor: ZaiNeColors.textPrimary(),
        elevation: 0,
        actions: [
          // 【v1.92.0】功能说明按钮
          IconButton(
            icon: const Icon(Icons.help_outline, size: 20),
            tooltip: tr.s623,
            onPressed: () => _showHelpDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // 功能状态提示
          _buildStatusBanner(),
          // 事件列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _events.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(ZaiNeSpacing.lg),
                        itemCount: _events.length,
                        itemBuilder: (context, index) => _buildEventCard(_events[index]),
                      ),
          ),
        ],
      ),
    );
  }

  /// 状态横幅：同时展示 Watch 和手机端检测状态
  ///
  /// 【v1.94.0】修复：iOS 的 `isReachable` 仅在 Watch App 处于前台时为 true，
  /// 但 WCSession 配对后即可在后台接收跌倒数据。故"配对即视为检测可用"，
  /// `isReachable` 仅用于区分"实时推送/后台守护"，避免误判为"未连接"。
  Widget _buildStatusBanner() {
    final bool watchActive = _watchPaired; // 配对成功即启用 Watch 精准检测
    final bool watchLive = _watchPaired && _watchReachable;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZaiNeSpacing.cardSm),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: watchActive
              ? [Colors.green.shade50, Colors.teal.shade50]
              : [Colors.indigo.shade50, Colors.blue.shade50],
        ),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Apple Watch 状态
          _buildStatusIndicator(
            icon: Icons.watch_outlined,
            label: 'Apple Watch',
            active: watchActive,
            activeText: watchLive ? tr.s624 : tr.s625,
            inactiveText: tr.s626,
          ),
          const SizedBox(width: ZaiNeSpacing.sm),
          Container(width: 1, height: 36, color: Colors.grey.shade300),
          const SizedBox(width: ZaiNeSpacing.sm),
          // 手机端状态
          _buildStatusIndicator(
            icon: Icons.phone_android_outlined,
            label: tr.s627,
            active: true,
            activeText: tr.s628,
            inactiveText: '',
          ),
          const Spacer(),
          // 总计事件数
          if (_events.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(ZaiNeRadius.small),
              ),
              child: Text(
                tr.s629(_events.length),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator({
    required IconData icon,
    required String label,
    required bool active,
    required String activeText,
    required String inactiveText,
  }) {
    return Row(
      children: [
        Container(
          width: 10, height: 10,
          margin: const EdgeInsets.only(right: ZaiNeSpacing.tight),
          decoration: BoxDecoration(
            color: active ? Colors.green : Colors.grey.shade400,
            shape: BoxShape.circle,
            boxShadow: active
                ? [BoxShadow(color: Colors.green.withValues(alpha: 0.4), blurRadius: 4)]
                : null,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: active ? Colors.green.shade700 : Colors.grey),
                const SizedBox(width: ZaiNeSpacing.xs),
                Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: active ? Colors.green.shade800 : Colors.grey)),
              ],
            ),
            Text(active ? activeText : inactiveText,
                style: TextStyle(fontSize: 10, color: active ? Colors.green.shade600 : Colors.grey.shade500)),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(ZaiNeSpacing.section),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.sensors_off, size: 48, color: Colors.indigo.shade300),
            ),
            const SizedBox(height: ZaiNeSpacing.xl),
            Text(
              tr.s630,
              style: TextStyle(fontSize: ZaiNeFontSize.body, fontWeight: FontWeight.w600,
                  color: ZaiNeColors.textSecondary()),
            ),
            const SizedBox(height: ZaiNeSpacing.sm),
            Text(
              tr.s631,
              style: TextStyle(fontSize: ZaiNeFontSize.caption,
                  color: ZaiNeColors.textHint(), height: 1.6),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(MotionEvent event) {
    final timeStr = DateFormat('MM/dd HH:mm').format(event.timestamp);
    final confidencePercent = event.confidence != null
        ? '${(event.confidence! * 100).toStringAsFixed(0)}%'
        : '--';

    return Container(
      margin: const EdgeInsets.only(bottom: ZaiNeSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ZaiNeRadius.cardSm),
        border: Border.all(
          color: event.acknowledged ? Colors.grey.shade200 : Colors.orange.shade200,
        ),
        boxShadow: event.acknowledged ? null : [
          BoxShadow(color: Colors.orange.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 顶部状态栏：检测来源 + 状态 + 时间 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                // 检测来源图标
                _buildSourceBadge(event),
                const Spacer(),
                // 时间
                Text(timeStr,
                    style: TextStyle(fontSize: ZaiNeFontSize.micro, color: ZaiNeColors.textHint())),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 位置信息行 ──
                _buildInfoRow(
                  icon: Icons.location_on_outlined,
                  iconColor: Colors.red.shade400,
                  label: tr.s632,
                  value: _formatLocation(event.latitude, event.longitude),
                ),
                const SizedBox(height: ZaiNeSpacing.sm),

                // ── 置信度 + 检测来源 ──
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoRow(
                        icon: Icons.analytics_outlined,
                        iconColor: _getConfidenceColor(event.confidence),
                        label: tr.s633,
                        value: confidencePercent,
                      ),
                    ),
                    const SizedBox(width: ZaiNeSpacing.md),
                    // ── 守护者通知状态 ──
                    _buildGuardianNotifiedBadge(event),
                  ],
                ),
                const SizedBox(height: ZaiNeSpacing.tight),

                // ── 确认时间 ──
                if (event.acknowledgedAt != null)
                  _buildInfoRow(
                    icon: Icons.check_circle_outline,
                    iconColor: Colors.green,
                    label: tr.s634,
                    value: DateFormat('HH:mm').format(event.acknowledgedAt!),
                  ),

                // ── 备注 ──
                if (event.notes != null && event.notes!.isNotEmpty) ...[
                  const SizedBox(height: ZaiNeSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(ZaiNeSpacing.cardXs),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(ZaiNeRadius.button),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.note_alt_outlined, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: ZaiNeSpacing.tight),
                        Expanded(
                          child: Text(event.notes!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── 操作按钮：未确认时显示 ──
          if (!event.acknowledged)
            Container(
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () async {
                    await _safetyService.acknowledgeMotionEvent(event.id);
                    await _loadData();
                  },
                  icon: Icon(Icons.check, size: 16, color: Colors.orange.shade700),
                  label: Text(tr.s635,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.orange.shade700)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(bottomLeft: Radius.circular(14), bottomRight: Radius.circular(14)),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 检测来源徽章
  Widget _buildSourceBadge(MotionEvent event) {
    final bool isWatch = !event.isPhoneSource;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isWatch ? Colors.purple.shade50 : Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(ZaiNeRadius.button),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isWatch ? Icons.watch : Icons.phone_android,
            size: 14,
            color: isWatch ? Colors.purple.shade600 : Colors.indigo.shade600,
          ),
          const SizedBox(width: ZaiNeSpacing.xs),
          Text(
            isWatch ? 'Apple Watch' : tr.s627,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isWatch ? Colors.purple.shade700 : Colors.indigo.shade700,
            ),
          ),
        ],
      ),
    );
  }

  /// 守护者通知状态徽章
  Widget _buildGuardianNotifiedBadge(MotionEvent event) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: event.guardianNotified ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(ZaiNeRadius.button),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            event.guardianNotified ? Icons.people : Icons.people_outline,
            size: 13,
            color: event.guardianNotified ? Colors.green.shade600 : Colors.grey.shade500,
          ),
          const SizedBox(width: ZaiNeSpacing.xs),
          Text(
            event.guardianNotified ? tr.s636 : tr.s637,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: event.guardianNotified ? Colors.green.shade700 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  /// 通用信息行
  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: ZaiNeSpacing.tight),
        Text('$label  ', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        Expanded(
          child: Text(value,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade800),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  /// 【v1.92.0】功能说明弹窗
  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.card)),
        title:  Row(
          children: [
            Icon(Icons.info_outline, color: Colors.indigo, size: 24),
            SizedBox(width: ZaiNeSpacing.sm),
            Text(tr.s638, style: TextStyle(fontSize: 16)),
          ],
        ),
        content:  Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HelpItem(
              icon: Icons.watch,
              title: tr.s639,
              desc: tr.s640,
            ),
            SizedBox(height: ZaiNeSpacing.cardSm),
            _HelpItem(
              icon: Icons.phone_android,
              title: tr.s641,
              desc: tr.s642,
            ),
            SizedBox(height: ZaiNeSpacing.cardSm),
            _HelpItem(
              icon: Icons.people,
              title: tr.s643,
              desc: tr.s644,
            ),
            SizedBox(height: ZaiNeSpacing.cardSm),
            _HelpItem(
              icon: Icons.warning_amber,
              title: tr.s645,
              desc: tr.s646,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(backgroundColor: Colors.indigo.shade50),
            child: Text(tr.s087, style: TextStyle(color: Colors.indigo.shade700)),
          ),
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

/// 帮助弹窗中的说明条目
class _HelpItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _HelpItem({
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(ZaiNeSpacing.sm),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(ZaiNeRadius.button),
          ),
          child: Icon(icon, size: 18, color: Colors.indigo.shade600),
        ),
        const SizedBox(width: ZaiNeSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: ZaiNeSpacing.xxs),
              Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }
}
