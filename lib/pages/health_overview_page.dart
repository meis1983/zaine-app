import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../theme/theme_helper.dart';
import '../services/platform/health_service.dart';
import '../services/api/user_service.dart';
import 'menstrual_page.dart';
import 'menstrual_settings_page.dart';

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

  @override
  void initState() {
    super.initState();
    _loadHealthData();
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
      setState(() {
        _alerts = anomalies != null ? List<String>.from(anomalies['alerts']) : [];
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
                  _buildHeader(),
                  if (_alerts.isNotEmpty) ...[
                    const SizedBox(height: ZaiNeSpacing.xl),
                    _buildAlertBanner(),
                  ],
                  const SizedBox(height: ZaiNeSpacing.xl),
                  _buildGrid(),
                  const SizedBox(height: ZaiNeSpacing.xl),
                  _buildSleepCard(),
                  const SizedBox(height: ZaiNeSpacing.xl),
                  _buildMenstruationCard(),
                  const SizedBox(height: ZaiNeSpacing.xl),
                  _buildQuickActionCard(),
                  const SizedBox(height: ZaiNeSpacing.xxl),
                  _buildDisclaimer(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '实时健康摘要',
          style: TextStyle(fontSize: ZaiNeFontSize.title, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: ZaiNeSpacing.xs),
        Text(
          _lastUpdated.isNotEmpty ? '上次同步: $_lastUpdated' : '尚未同步健康数据',
          style: TextStyle(color: ZaiNeColors.textSecondary(), fontSize: ZaiNeFontSize.caption),
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

  Widget _buildGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        _buildMetricCard(
          title: '心率',
          value: _metrics['heart_rate'] != null ? '${_metrics['heart_rate']} bpm' : '--',
          icon: Icons.favorite,
          color: Colors.red,
          subtitle: '过去24小时',
          isAlert: _alerts.any((a) => a.contains('心率')),
        ),
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
        _buildMetricCard(
          title: '呼吸频率',
          value: _metrics['respiratory_rate'] != null ? '${_metrics['respiratory_rate']} 次/分' : '--',
          icon: Icons.air,
          color: Colors.teal,
          subtitle: '静息状态参考值',
        ),
        _buildMetricCard(
          title: '静息心率',
          value: _metrics['resting_heart_rate'] != null ? '${_metrics['resting_heart_rate']} bpm' : '--',
          icon: Icons.monitor_heart,
          color: Colors.orange,
          subtitle: '心血管健康参考',
        ),
        _buildMetricCard(
          title: 'HRV',
          value: _metrics['hrv'] != null ? '${_parseValue(_metrics['hrv']).toStringAsFixed(0)} ms' : '--',
          icon: Icons.bolt,
          color: Colors.amber,
          subtitle: '心率变异性',
        ),
        _buildMetricCard(
          title: '手腕温度',
          value: _metrics['body_temperature'] != null ? '${_parseValue(_metrics['body_temperature']).toStringAsFixed(1)}°C' : '--',
          icon: Icons.thermostat,
          color: Colors.cyan,
          subtitle: _metrics['body_temperature'] != null ? '夜间基础体温' : '需佩戴手表过夜',
        ),
        _buildMetricCard(
          title: '步数',
          value: _metrics['steps'] != null ? '${_parseValue(_metrics['steps']).toInt()} 步' : '--',
          icon: Icons.directions_walk,
          color: Colors.green,
          subtitle: '今日累计',
        ),
        _buildMetricCard(
          title: '行走距离',
          value: _metrics['distance_m'] != null
              ? '${(_parseValue(_metrics['distance_m']) / 1000).toStringAsFixed(1)} km'
              : '--',
          icon: Icons.straight,
          color: Colors.blue,
          subtitle: '今日累计',
        ),
        _buildMetricCard(
          title: '活跃能量',
          value: _metrics['active_energy'] != null
              ? '${_parseValue(_metrics['active_energy']).toInt()} 千卡'
              : '--',
          icon: Icons.local_fire_department,
          color: Colors.deepOrange,
          subtitle: '今日消耗',
        ),
      ],
    );
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

  Widget _buildQuickActionCard() {
    return Container(
      padding: const EdgeInsets.all(ZaiNeSpacing.section),
      decoration: BoxDecoration(
        color: ZaiNeColors.cardBg(),
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
      
        boxShadow: ZaiNeShadows.card,),
      child: Column(
        children: [
          const Text(
            '让守护者更放心',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: ZaiNeFontSize.body),
          ),
          const SizedBox(height: ZaiNeSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                setState(() => _isLoading = true);
                await HealthService.performSilentHeartbeatCheckin();
                await _loadHealthData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('同步成功，已向守护圈报平安 ❤️')),
                  );
                }
              },
              icon: const Icon(Icons.favorite),
              label: const Text('立即同步并报平安'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ZaiNeColors.brandOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: ZaiNeSpacing.lg),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.small)),
              ),
            ),
          ),
        ],
      ),
    );
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
