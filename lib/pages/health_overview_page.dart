import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/theme_helper.dart';
import '../services/platform/health_service.dart';
import '../services/api/user_service.dart';
import '../services/safety/safety_signal_engine.dart';
import '../config/app_config.dart';
import 'menstrual_page.dart';
import 'menstrual_settings_page.dart';

/// 生命体征守护页
///
/// 【信息架构 · 三层克制原则 · 勿改】
/// 本页**不是** Apple 健康 App 的镜像。原生桥虽已读取全部 ~70 项 HealthKit 指标，
/// 但 UI 只展示与「安全」相关的部分，理由见 SafetySignalEngine 顶部注释。
///
///   ┌ 今日状态卡  一句人话结论 + 报平安动作（差异化核心）
///   ├ L1 守护级   5 项常驻：异常时守护圈需要被惊动的指标
///   ├ 睡眠卡      Apple Watch 原生睡眠分期
///   ├ L2 参考级   6 项折叠：辅助判断，不触发守护，默认收起
///   ├ 经期卡      女性健康（独立模块）
///   └ L3 深链     心电图/房颤/听力/体能 → 一行入口跳系统健康 App，不做卡片
///
/// 其中心电图、房颤、不规则心律 Apple **禁止**任何第三方读取，
/// 硬做只能是假数据，因此只提供深链跳转。

class HealthOverviewPage extends StatefulWidget {
  const HealthOverviewPage({super.key});

  @override
  State<HealthOverviewPage> createState() => _HealthOverviewPageState();
}

class _HealthOverviewPageState extends State<HealthOverviewPage> {
  bool _isLoading = true;
  Map<String, dynamic> _metrics = {};
  String _lastUpdated = '';
  List<String> _alerts = [];

  /// 安全信号引擎输出：把原始指标翻译成一句人话结论
  SafetySignal? _signal;

  /// L2 参考级指标是否展开（默认收起，不占首屏心智）
  bool _showMore = false;

  /// 报平安按钮 loading
  bool _reporting = false;

  /// 异常时是否自动通知守护圈（CN 版恒 false，且整个开关不显示）
  bool _autoAlert = false;

  @override
  void initState() {
    super.initState();
    _loadAutoAlertPref();
    _loadHealthData();
  }

  Future<void> _loadAutoAlertPref() async {
    final v = await HealthService.isSafetyAutoAlertEnabled();
    if (mounted) setState(() => _autoAlert = v);
  }

  Future<void> _loadHealthData() async {
    setState(() => _isLoading = true);
    try {
      // 1. 尝试从后端获取最新同步的数据
      final res = await UserService.getProfile();
      if (res['success'] == true && res['health_metrics'] != null) {
        _metrics = res['health_metrics'];
        _lastUpdated = _metrics['updated_at'] ?? '';
      }
      
      // 2. 同时尝试从本地 HealthKit 获取最新数据并同步一次
      final summary = await HealthService.getHealthSummary();
      if (summary.isNotEmpty) {
        await HealthService.syncHealthData();
        setState(() {
          _metrics.addAll(summary);
          _lastUpdated = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
        });
      }

      // 3. 检查异常
      final anomalies = HealthService.checkAnomalies(_metrics);
      // 4. 安全信号引擎：把 ~70 项原始指标翻译成一句结论
      final signal = SafetySignalEngine.evaluate(_metrics);
      setState(() {
        _alerts = anomalies != null ? List<String>.from(anomalies['alerts']) : [];
        _signal = signal;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[HealthOverview] 加载失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZaiNeColors.scaffoldBg(),
      appBar: AppBar(
        title: const Text('生命体征守护', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: ZaiNeColors.cardBg(),
        foregroundColor: ZaiNeColors.textPrimary(),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHealthData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHealthData,
              child: ListView(
                padding: const EdgeInsets.all(ZaiNeSpacing.section),
                children: [
                  // ① 今日状态卡：一句结论 + 一个动作（本页差异化核心）
                  _buildTodayStatusCard(),
                  if (_alerts.isNotEmpty) ...[
                    const SizedBox(height: ZaiNeSpacing.xl),
                    _buildAlertBanner(),
                  ],
                  // ①-b 自动守护开关（海外版专属；CN 版合规屏蔽）
                  if (!AppConfig.isChinaRegion) ...[
                    const SizedBox(height: ZaiNeSpacing.lg),
                    _buildAutoAlertSwitch(),
                  ],
                  // ② L1 守护级：异常时守护圈需要被惊动的 5 项
                  const SizedBox(height: ZaiNeSpacing.xl),
                  _buildSectionTitle(
                    '守护指标',
                    AppConfig.isChinaRegion
                        ? '记录今日体征，随时可主动分享'
                        : '异常时会提醒你向守护圈报平安',
                  ),
                  const SizedBox(height: ZaiNeSpacing.lg),
                  _buildL1Grid(),
                  // ③ 睡眠（Apple Watch 原生分期）
                  const SizedBox(height: ZaiNeSpacing.xl),
                  _buildSleepCard(),
                  // ④ L2 参考级：折叠
                  const SizedBox(height: ZaiNeSpacing.xl),
                  _buildMoreMetricsSection(),
                  // ⑤ 经期（独立模块，保持原样）
                  const SizedBox(height: ZaiNeSpacing.xl),
                  _buildMenstruationCard(),
                  // ⑥ L3 深链：Apple 封闭数据不做假卡片
                  const SizedBox(height: ZaiNeSpacing.xl),
                  _buildAppleHealthLink(),
                  const SizedBox(height: ZaiNeSpacing.xxl),
                  _buildDisclaimer(),
                ],
              ),
            ),
    );
  }

  // ==================== ① 今日状态卡（差异化核心） ====================

  /// Apple 健康说「静息心率 62 bpm」，我们说「今天状态平稳，可以报平安了」。
  /// 指标是原料，**结论 + 动作**才是产品。
  Widget _buildTodayStatusCard() {
    final s = _signal;
    final color = s?.color ?? const Color(0xFF8E8E93);
    final headline = s?.headline ?? '正在读取…';
    final detail = s?.detail ?? '';

    return Container(
      padding: const EdgeInsets.all(ZaiNeSpacing.section),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.14), color.withValues(alpha: 0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
        boxShadow: ZaiNeShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(s?.icon ?? Icons.watch_off_rounded, color: color, size: 24),
              ),
              const SizedBox(width: ZaiNeSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: TextStyle(
                        fontSize: ZaiNeFontSize.title,
                        fontWeight: FontWeight.w800,
                        color: ZaiNeColors.textPrimary(),
                      ),
                    ),
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: TextStyle(
                          fontSize: ZaiNeFontSize.caption,
                          color: ZaiNeColors.textSecondary(),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // 判定依据明细（仅在有异常时展开，正常时不打扰）
          if (s != null && s.reasons.isNotEmpty) ...[
            const SizedBox(height: ZaiNeSpacing.lg),
            ...s.reasons.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: ZaiNeSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(r.icon,
                          size: 16,
                          color: r.level == SafetyLevel.alert
                              ? const Color(0xFFFF3B30)
                              : const Color(0xFFFF9500)),
                      const SizedBox(width: ZaiNeSpacing.sm),
                      Expanded(
                        child: Text(
                          r.text,
                          style: TextStyle(
                            fontSize: ZaiNeFontSize.caption,
                            color: ZaiNeColors.textPrimary().withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],

          const SizedBox(height: ZaiNeSpacing.lg),
          // 一个动作：把结论同步给在乎你的人。这是 Apple 健康 App 永远不会做的事。
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _reporting ? null : _reportSafe,
              icon: _reporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.favorite, size: 18),
              label: Text(_reporting ? '同步中…' : '同步并向守护圈报平安'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ZaiNeColors.brandOrange,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: ZaiNeSpacing.lg),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                ),
              ),
            ),
          ),
          const SizedBox(height: ZaiNeSpacing.sm),
          Text(
            _lastUpdated.isNotEmpty ? '数据同步于 $_lastUpdated' : '尚未同步健康数据',
            style: TextStyle(
              color: ZaiNeColors.textSecondary(),
              fontSize: ZaiNeFontSize.micro,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reportSafe() async {
    setState(() => _reporting = true);
    try {
      await HealthService.performSilentHeartbeatCheckin();
      await _loadHealthData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('同步成功，已向守护圈报平安 ❤️')),
        );
      }
    } finally {
      if (mounted) setState(() => _reporting = false);
    }
  }

  // ==================== ①-b 自动守护开关（海外版专属） ====================

  /// 「检测到异常时自动通知守护圈」—— 本 App 相对 Apple 健康 App 的核心差异：
  /// 它顶多推个通知给你自己，我们**替你通知家人**。
  ///
  /// 🔴 CN 合规版整个开关不渲染（外层 `!AppConfig.isChinaRegion` 判断），
  /// 且 `HealthService.isSafetyAutoAlertEnabled()` 在 CN 恒返回 false，
  /// 双保险确保 CN 版无任何自动外发路径。
  Widget _buildAutoAlertSwitch() {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: ZaiNeSpacing.section, vertical: ZaiNeSpacing.md),
      decoration: BoxDecoration(
        color: ZaiNeColors.cardBg(),
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        boxShadow: ZaiNeShadows.card,
      ),
      child: Row(
        children: [
          Icon(Icons.shield_moon_rounded,
              size: 20,
              color: _autoAlert
                  ? ZaiNeColors.brandOrange
                  : ZaiNeColors.textSecondary()),
          const SizedBox(width: ZaiNeSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('异常时自动通知守护圈',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: ZaiNeFontSize.bodySm)),
                const SizedBox(height: 2),
                Text(
                  _autoAlert
                      ? '检测到长时间无活动等异常，会自动替你报信'
                      : '已关闭，异常只在 App 内提醒你本人',
                  style: TextStyle(
                      color: ZaiNeColors.textSecondary(),
                      fontSize: ZaiNeFontSize.micro),
                ),
              ],
            ),
          ),
          Switch(
            value: _autoAlert,
            activeThumbColor: ZaiNeColors.brandOrange,
            onChanged: (v) async {
              await HealthService.setSafetyAutoAlertEnabled(v);
              if (!mounted) return;
              setState(() => _autoAlert = v);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(v ? '已开启：异常时会自动通知守护圈' : '已关闭：异常仅在 App 内提醒你'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
              fontSize: ZaiNeFontSize.subtitle, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
              color: ZaiNeColors.textSecondary(), fontSize: ZaiNeFontSize.micro),
        ),
      ],
    );
  }

  Widget _buildAlertBanner() {
    return Container(
      padding: const EdgeInsets.all(ZaiNeSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F0),
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        border: Border.all(color: Colors.red.shade200),
      
        boxShadow: ZaiNeShadows.card,),
      child: Column(
        children: _alerts.map((alert) => Padding(
          padding: const EdgeInsets.symmetric(vertical: ZaiNeSpacing.xs),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
              const SizedBox(width: ZaiNeSpacing.md),
              Expanded(
                child: Text(
                  alert,
                  style: const TextStyle(color: Color(0xFFCF1322), fontWeight: FontWeight.w600, fontSize: ZaiNeFontSize.bodySm),
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }

  // ==================== ② L1 守护级（5 项常驻） ====================

  /// 入选标准只有一条：**这项异常时，守护圈需不需要被惊动？**
  /// 不看指标多高级 —— VO2Max 掉 3 个点家人不需要知道，
  /// 但「今天一动没动」家人必须知道。
  Widget _buildL1Grid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        // ★ 头牌：独居风险最强的信号不是任何生理指标，而是「一动没动」。
        //   Apple 健康 App 永远不会做这个判定，因为它不是安全产品。
        _buildActivityCard(),
        _buildMetricCard(
          title: '心率',
          value: _metrics['heart_rate'] != null ? '${_metrics['heart_rate']} bpm' : '--',
          icon: Icons.favorite,
          color: Colors.red,
          subtitle: _hrRangeText(),
          isAlert: _alerts.any((a) => a.contains('心率')),
        ),
        _buildMetricCard(
          title: '血氧',
          value: _metrics['blood_oxygen'] != null
              ? _formatSpo2(_parseValue(_metrics['blood_oxygen']))
              : '--',
          icon: Icons.bloodtype,
          color: Colors.blue,
          subtitle: '血液含氧量',
          isAlert: _alerts.any((a) => a.contains('血氧')),
        ),
        // Apple 官方的 Walking Steadiness 本就是为跌倒风险设计，
        // 对独居长者场景高度对口，是我们最该抓住的一项。
        _buildMetricCard(
          title: '步行稳定性',
          value: _metrics['walking_steadiness_pct'] != null
              ? '${_parseValue(_metrics['walking_steadiness_pct']).toStringAsFixed(0)}%'
              : '--',
          icon: Icons.accessibility_new,
          color: Colors.indigo,
          subtitle: _steadinessText(),
          isAlert: _parseValue(_metrics['walking_steadiness_pct']) > 0 &&
              _parseValue(_metrics['walking_steadiness_pct']) < 50,
        ),
        // 血压：Apple Watch S9 本身支持，但需 iOS 26。
        // 未开通时保持展示、不置灰 —— 用户明确要求保留入口。
        _buildMetricCard(
          title: '血压',
          value: (_metrics['bp_systolic'] != null && _metrics['bp_diastolic'] != null)
              ? '${_parseValue(_metrics['bp_systolic']).toInt()}/${_parseValue(_metrics['bp_diastolic']).toInt()}'
              : '--',
          icon: Icons.speed,
          color: Colors.deepPurple,
          subtitle: '单位: mmHg',
          isAlert: _alerts.any((a) => a.contains('血压')),
        ),
      ],
    );
  }

  /// 今日活动卡：步数 / 运动 / 站立 三合一，是「无活动」判定的可视化载体
  Widget _buildActivityCard() {
    final steps = _parseValue(_metrics['steps']).toInt();
    final exercise = _parseValue(
            _metrics['exercise_minutes'] ?? _metrics['ring_exercise_min'])
        .toInt();
    final stand = _parseValue(_metrics['ring_stand_hours']).toInt();
    final hasData = _metrics['steps'] != null || _metrics['ring_stand_hours'] != null;

    final isQuiet = _signal?.inactiveHours != null && _signal!.inactiveHours > 0;

    return _buildMetricCard(
      title: '今日活动',
      value: hasData ? '$steps 步' : '--',
      icon: Icons.directions_walk,
      color: Colors.green,
      subtitle: hasData ? '运动 $exercise 分钟 · 站立 $stand 小时' : '需佩戴 Apple Watch',
      isAlert: isQuiet,
    );
  }

  String _hrRangeText() {
    final min = _parseValue(_metrics['heart_rate_min']).toInt();
    final max = _parseValue(_metrics['heart_rate_max']).toInt();
    if (min > 0 && max > 0) return '今日 $min–$max bpm';
    return '过去24小时';
  }

  String _steadinessText() {
    final v = _parseValue(_metrics['walking_steadiness_pct']);
    if (v <= 0) return '跌倒风险评估';
    if (v >= 70) return '稳定 · 跌倒风险低';
    if (v >= 50) return '尚可 · 建议留意';
    return '偏低 · 跌倒风险高';
  }

  double _parseValue(dynamic val) {
    if (val == null) return 0;
    return double.tryParse(val.toString()) ?? 0;
  }

  /// 【2026-07-15 修复】血氧(SpO2)显示：HealthKit 可能返回 0.0–1.0 分数或 0–100 百分比，
  /// 统一归一化为百分比；超出合理区间(70%–100%)视为脏数据，显示「数据异常」，避免误导。
  String _formatSpo2(double raw) {
    if (raw <= 0) return '数据异常';
    final pct = raw <= 1.0 ? raw * 100 : raw; // 分数→百分比，或已为百分比
    if (pct >= 70 && pct <= 100) return '${pct.toStringAsFixed(0)}%';
    return '数据异常';
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
    bool isAlert = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(ZaiNeSpacing.lg),
      decoration: BoxDecoration(
        color: isAlert ? const Color(0xFFFFF1F0) : Colors.white,
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        border: isAlert ? Border.all(color: Colors.red.shade200, width: 1.5) : null,
        boxShadow: [
          BoxShadow(
            color: isAlert ? Colors.red.withValues(alpha: 0.1) : color.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: isAlert ? Colors.red : color, size: 20),
              const SizedBox(width: ZaiNeSpacing.sm),
              Text(title, style: TextStyle(color: isAlert ? Colors.red.shade700 : Colors.grey.shade700, fontSize: ZaiNeFontSize.bodySm, fontWeight: FontWeight.w600)),
              if (isAlert) ...[
                const Spacer(),
                const Icon(Icons.error_outline, color: Colors.red, size: 16),
              ],
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(fontSize: ZaiNeFontSize.title, fontWeight: FontWeight.bold, color: isAlert ? Colors.red.shade900 : Colors.black),
          ),
          const SizedBox(height: ZaiNeSpacing.xs),
          Text(
            subtitle,
            style: TextStyle(color: isAlert ? Colors.red.withValues(alpha: 0.6) : Colors.grey.shade500, fontSize: ZaiNeFontSize.micro),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepCard() {
    final int totalMinutes = _metrics['sleep_total'] ?? 0;
    final String hours = (totalMinutes / 60).floor().toString();
    final String minutes = (totalMinutes % 60).toString();

    return Container(
      padding: const EdgeInsets.all(ZaiNeSpacing.section),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade400, Colors.indigo.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.nights_stay, color: Colors.white, size: 24),
                  SizedBox(width: ZaiNeSpacing.md),
                  Text(
                    '昨晚睡眠',
                    style: TextStyle(color: Colors.white, fontSize: ZaiNeFontSize.subtitle, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Text(
                totalMinutes > 0 ? '$hours小时$minutes分' : '暂无数据',
                style: const TextStyle(color: Colors.white, fontSize: ZaiNeFontSize.title, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: ZaiNeSpacing.xl),
          Row(
            children: [
              _buildSleepBit('深度睡眠', _metrics['sleep_deep'] ?? 0, Colors.blue.shade200),
              _buildSleepBit('REM', _metrics['sleep_rem'] ?? 0, Colors.purple.shade200),
              _buildSleepBit('核心睡眠', _metrics['sleep_core'] ?? _metrics['sleep_asleep'] ?? 0, Colors.indigo.shade200),
            ],
          ),
          const SizedBox(height: ZaiNeSpacing.sm),
          Text(
            '数据来源：HealthKit（可能包含 iPhone 和 Apple Watch）',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: ZaiNeFontSize.micro),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepBit(String label, int mins, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '${(mins / 60).floor()}h${mins % 60}m',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: ZaiNeFontSize.bodySm),
          ),
          const SizedBox(height: ZaiNeSpacing.xs),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: ZaiNeFontSize.micro)),
        ],
      ),
    );
  }

  Widget _buildMenstruationCard() {
    final bool hasData = _metrics['has_menstruation'] == true;
    final bool isInPeriod = _metrics['is_in_period'] == true;
    final int cycleDay = _parseValue(_metrics['cycle_day']).toInt();
    final int avgCycle = _parseValue(_metrics['average_cycle_length']).toInt();
    final String predictedNext = _metrics['predicted_next_date']?.toString() ?? '';

    // 经期状态颜色
    final Color statusColor = isInPeriod ? Colors.pink : Colors.grey.shade400;
    final String statusText = isInPeriod ? '经期中' : (hasData ? '非经期' : '未开启跟踪');

    return Container(
      padding: const EdgeInsets.all(ZaiNeSpacing.section),
      decoration: BoxDecoration(
        gradient: isInPeriod
            ? LinearGradient(
                colors: [Colors.pink.shade50, Colors.pink.shade100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isInPeriod ? null : Colors.white,
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        border: Border.all(
          color: isInPeriod ? Colors.pink.shade200 : Colors.grey.shade200,
          width: 1.5,
        ),
      
        boxShadow: ZaiNeShadows.card,),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(ZaiNeSpacing.cardXs),
                decoration: BoxDecoration(
                  color: isInPeriod ? Colors.pink.shade100 : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.water_drop,
                  color: statusColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: ZaiNeSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('女性经期跟踪',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: ZaiNeFontSize.body)),
                    const SizedBox(height: ZaiNeSpacing.xs),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: ZaiNeFontSize.caption,
                        fontWeight: isInPeriod ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasData)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.md, vertical: ZaiNeSpacing.xs),
                  decoration: BoxDecoration(
                    color: isInPeriod
                        ? Colors.pink.shade100
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                
                    boxShadow: ZaiNeShadows.card,),
                  child: Text(
                    '第$cycleDay天',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: ZaiNeFontSize.caption,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          // 详情行（有数据时显示）
          if (hasData) ...[
            const SizedBox(height: ZaiNeSpacing.lg),
            Container(
              padding: const EdgeInsets.all(ZaiNeSpacing.cardSm),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(ZaiNeRadius.small),
              
                boxShadow: ZaiNeShadows.card,),
              child: Row(
                children: [
                  _buildMenstruationInfoItem(
                    label: '平均周期',
                    value: '$avgCycle天',
                    icon: Icons.calendar_today,
                    color: Colors.pink.shade300,
                  ),
                  const SizedBox(width: ZaiNeSpacing.lg),
                  _buildMenstruationInfoItem(
                    label: '预测下次',
                    value: predictedNext.isNotEmpty
                        ? _formatPredictedDate(predictedNext)
                        : '数据不足',
                    icon: Icons.event,
                    color: Colors.purple.shade300,
                  ),
                ],
              ),
            ),
          ],
          // 【v1.93.9 优化】无数据时显示引导提示
          if (!hasData) ...[
            const SizedBox(height: ZaiNeSpacing.lg),
            Container(
              padding: const EdgeInsets.all(ZaiNeSpacing.cardSm),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(ZaiNeRadius.small),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey.shade500, size: 18),
                  const SizedBox(width: ZaiNeSpacing.sm),
                  Expanded(
                    child: Text(
                      '可手动记录经期日期，系统将自动计算周期并预测下次经期时间',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: ZaiNeFontSize.micro),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // ✅ 按钮（记录经期 + 设置）
          const SizedBox(height: ZaiNeSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MenstrualPage()),
                    ).then((_) => _loadHealthData());
                  },
                  icon: const Icon(Icons.edit_calendar, size: 16),
                  label: Text(hasData ? '记录经期' : '开始记录'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: hasData ? Colors.pink : ZaiNeColors.brandOrange,
                    side: BorderSide(color: hasData ? Colors.pink.shade200 : ZaiNeColors.brandOrange.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: ZaiNeSpacing.md),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MenstrualSettingsPage()),
                    );
                  },
                  icon: const Icon(Icons.settings, size: 16),
                  label: const Text('设置'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenstruationInfoItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: ZaiNeSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(color: ZaiNeColors.textSecondary(), fontSize: ZaiNeFontSize.micro)),
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: ZaiNeFontSize.bodySm)),
            ],
          ),
        ],
      ),
    );
  }

  String _formatPredictedDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = date.difference(DateTime(now.year, now.month, now.day)).inDays;
      if (diff <= 0) return '今天';
      if (diff == 1) return '明天';
      if (diff <= 7) return '$diff天后';
      return '${date.month}/${date.day}';
    } catch (_) {
      return dateStr;
    }
  }

  // ==================== ④ L2 参考级（折叠，默认收起） ====================

  /// 这些指标不触发守护判定，但能为「今日状态」提供依据。
  /// 默认收起 —— 不占首屏心智，需要时点开即可。
  Widget _buildMoreMetricsSection() {
    return Container(
      decoration: BoxDecoration(
        color: ZaiNeColors.cardBg(),
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        boxShadow: ZaiNeShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _showMore = !_showMore),
            child: Padding(
              padding: const EdgeInsets.all(ZaiNeSpacing.section),
              child: Row(
                children: [
                  Icon(Icons.tune_rounded,
                      size: 20, color: ZaiNeColors.textSecondary()),
                  const SizedBox(width: ZaiNeSpacing.md),
                  const Expanded(
                    child: Text(
                      '更多身体数据',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: ZaiNeFontSize.body),
                    ),
                  ),
                  Text(
                    _showMore ? '收起' : '展开',
                    style: TextStyle(
                        color: ZaiNeColors.textSecondary(),
                        fontSize: ZaiNeFontSize.caption),
                  ),
                  AnimatedRotation(
                    turns: _showMore ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: ZaiNeColors.textSecondary()),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(ZaiNeSpacing.section, 0,
                  ZaiNeSpacing.section, ZaiNeSpacing.section),
              child: Column(
                children: [
                  _buildMiniRow('静息心率', _fmt(_metrics['resting_heart_rate'], 'bpm'),
                      Icons.monitor_heart_outlined, Colors.orange),
                  _buildMiniRow('心率变异性 HRV', _fmt(_metrics['hrv'], 'ms', decimals: 0),
                      Icons.bolt_outlined, Colors.amber),
                  _buildMiniRow('呼吸频率', _fmt(_metrics['respiratory_rate'], '次/分'),
                      Icons.air_rounded, Colors.teal),
                  _buildMiniRow(
                      '手腕温度',
                      _metrics['wrist_temperature'] != null
                          ? '${_parseValue(_metrics['wrist_temperature']).toStringAsFixed(1)}°C'
                          : '需佩戴过夜',
                      Icons.thermostat_rounded,
                      Colors.cyan),
                  _buildMiniRow(
                      '行走距离',
                      _metrics['distance_m'] != null
                          ? '${(_parseValue(_metrics['distance_m']) / 1000).toStringAsFixed(1)} km'
                          : '--',
                      Icons.straighten_rounded,
                      Colors.blue),
                  _buildMiniRow('活跃能量', _fmt(_metrics['active_energy'], '千卡'),
                      Icons.local_fire_department_outlined, Colors.deepOrange,
                      isLast: true),
                ],
              ),
            ),
            crossFadeState:
                _showMore ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }

  Widget _buildMiniRow(String label, String value, IconData icon, Color color,
      {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: ZaiNeSpacing.md),
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(
                    color: ZaiNeColors.textSecondary().withValues(alpha: 0.12)),
              ),
            ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: ZaiNeSpacing.md),
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: ZaiNeFontSize.bodySm)),
          ),
          Text(
            value,
            style: const TextStyle(
                fontSize: ZaiNeFontSize.bodySm, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _fmt(dynamic v, String unit, {int decimals = 0}) {
    if (v == null) return '--';
    final d = _parseValue(v);
    if (d <= 0) return '--';
    return '${d.toStringAsFixed(decimals)} $unit';
  }

  // ==================== ⑥ L3 深链（不做假卡片） ====================

  /// 心电图、房颤病史、不规则心律通知 —— Apple **禁止**任何第三方 App 读取，
  /// 硬做卡片只能显示假数据或永远的 '--'，那是欺骗用户。
  /// 听力暴露、体能 VO2Max 对「安全」判定零贡献，同样不占首屏。
  /// 这一层只做一行入口，一行，不是十张卡。
  Widget _buildAppleHealthLink() {
    return InkWell(
      borderRadius: BorderRadius.circular(ZaiNeRadius.card),
      onTap: _openAppleHealth,
      child: Container(
        padding: const EdgeInsets.all(ZaiNeSpacing.section),
        decoration: BoxDecoration(
          color: ZaiNeColors.cardBg(),
          borderRadius: BorderRadius.circular(ZaiNeRadius.card),
          border: Border.all(
              color: ZaiNeColors.textSecondary().withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            const Icon(Icons.favorite_border_rounded,
                color: Color(0xFFFF2D55), size: 22),
            const SizedBox(width: ZaiNeSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('心电图 · 听力 · 体能等完整数据',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: ZaiNeFontSize.bodySm)),
                  const SizedBox(height: 2),
                  Text(
                    '这些数据 Apple 仅在系统「健康」App 中开放',
                    style: TextStyle(
                        color: ZaiNeColors.textSecondary(),
                        fontSize: ZaiNeFontSize.micro),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: ZaiNeColors.textSecondary()),
          ],
        ),
      ),
    );
  }

  Future<void> _openAppleHealth() async {
    try {
      final ok = await launchUrl(
        Uri.parse('x-apple-health://'),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请在 iPhone 上打开系统「健康」App 查看')),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[HealthOverview] 打开健康 App 失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请在 iPhone 上打开系统「健康」App 查看')),
        );
      }
    }
  }

  Widget _buildDisclaimer() {
    return Column(
      children: [
        Icon(Icons.shield_outlined, color: ZaiNeColors.textSecondary(), size: 32),
        const SizedBox(height: ZaiNeSpacing.md),
        Text(
          '健康数据由 Apple HealthKit 提供\n仅供参考，不作为医疗诊断依据',
          textAlign: TextAlign.center,
          style: TextStyle(color: ZaiNeColors.textSecondary(), fontSize: ZaiNeFontSize.caption, height: 1.5),
        ),
      ],
    );
  }
}
