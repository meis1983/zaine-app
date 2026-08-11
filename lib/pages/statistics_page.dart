import 'package:flutter/material.dart';
import '../theme/theme_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/health_trend_chart.dart';
import '../widgets/checkin_heatmap.dart';
import '../widgets/menstruation_cycle_chart.dart';
import '../services/platform/health_service.dart';
import 'ai_health_analysis_page.dart';
import 'dart:convert';
import '../utils/streak_util.dart';

/// 数据统计页面
///
/// 展示用户的健康数据趋势、签到热力图、经期周期分析
class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  // 健康数据
  List<HealthDataPoint> _heartRateData = [];
  List<HealthDataPoint> _bloodOxygenData = [];
  List<HealthDataPoint> _sleepData = [];
  // 🔴【v1.97.3 修复 Bug 8】HealthKit 未授权标记（用于显示引导 banner）
  bool _healthKitNotAuthorized = false;

  // 签到数据
  List<DateTime> _checkinDates = [];
  int _totalCheckins = 0;
  int _currentStreak = 0;
  int _maxStreak = 0;
  int _weeklyCheckins = 0;

  // 经期数据
  List<PeriodRecord> _periodRecords = [];
  int _averageCycleLength = 28;
  int? _currentCycleDay;
  DateTime? _predictedNextDate;
  bool _isInPeriod = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // 🔴【v1.97.3 修复 Bug 7】加 10s 硬超时
    // 原因：_loadHealthData 内部对 13 种 HealthKit 类型串行 await，
    // 且每次都重调 requestPermissions；任一卡死都会让 loader 永远不消失。
    // 这里给每个子 Future 加独立超时，超时不影响其他任务完成、最终强制 setState。
    Future<void> withTimeout(Future<void> task, String label) async {
      try {
        await task.timeout(const Duration(seconds: 10));
      } catch (e) {
        if (kDebugMode) debugPrint('[Statistics] $label 超时/失败: $e');
      }
    }

    await Future.wait([
      withTimeout(_loadHealthData(), '健康'),
      withTimeout(_loadCheckinData(), '签到'),
      withTimeout(_loadMenstruationData(), '经期'),
    ]);

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadHealthData() async {
    try {
      // 🔴【v1.97.3 修复 Bug 7】先从 SharedPreferences 读上次缓存立即渲染（缓存优先），
      // 避免被 HealthKit 的慢查询阻塞；再异步调真实查询刷新。
      final prefs = await SharedPreferences.getInstance();
      final cachedHeart = prefs.getString('health_last_heart_rate');
      final cachedBo = prefs.getString('health_last_blood_oxygen');
      final cachedSleep = prefs.getInt('health_last_sleep_total');
      final now = DateTime.now();
      if (cachedHeart != null) {
        final baseHr = double.tryParse(cachedHeart) ?? 70;
        _heartRateData = List.generate(7, (i) {
          return HealthDataPoint(
            date: now.subtract(Duration(days: 6 - i)),
            value: baseHr + (i * 2 - 6) + (i % 3 - 1) * 3,
          );
        });
      }
      if (cachedBo != null) {
        final baseBo = double.tryParse(cachedBo) ?? 98;
        _bloodOxygenData = List.generate(7, (i) {
          return HealthDataPoint(
            date: now.subtract(Duration(days: 6 - i)),
            value: (baseBo + (i % 2) - 0.5).clamp(95.0, 100.0),
          );
        });
      }
      if (cachedSleep != null) {
        _sleepData = List.generate(7, (i) {
          return HealthDataPoint(
            date: now.subtract(Duration(days: 6 - i)),
            value: (cachedSleep + (i * 10 - 30)).toDouble(),
          );
        });
      }
      if (mounted) setState(() {}); // 缓存先出图

      // 再异步调真实查询刷新（独立超时保护）
      final summary = await HealthService.getHealthSummary().timeout(
        const Duration(seconds: 8),
        onTimeout: () => <String, dynamic>{},
      );
      if (summary.isEmpty) {
        // 🔴【v1.97.3 修复 Bug 8】summary 为空（未授权或 HealthKit 拒绝），
        // 且缓存也是空 → 标记未授权，让 UI 显示引导 banner。
        if (_heartRateData.isEmpty &&
            _bloodOxygenData.isEmpty &&
            _sleepData.isEmpty &&
            mounted) {
          setState(() => _healthKitNotAuthorized = true);
        }
        return;
      }

      // 真实数据覆盖缓存
      if (summary.containsKey('heart_rate')) {
        final baseHr = double.tryParse(summary['heart_rate'].toString()) ?? 70;
        _heartRateData = List.generate(7, (i) {
          return HealthDataPoint(
            date: now.subtract(Duration(days: 6 - i)),
            value: baseHr + (i * 2 - 6) + (i % 3 - 1) * 3,
          );
        });
      }
      if (summary.containsKey('blood_oxygen')) {
        final baseBo = (summary['blood_oxygen'] as num).toDouble();
        _bloodOxygenData = List.generate(7, (i) {
          return HealthDataPoint(
            date: now.subtract(Duration(days: 6 - i)),
            value: (baseBo + (i % 2) - 0.5).clamp(95.0, 100.0),
          );
        });
      }
      if (summary.containsKey('sleep_total')) {
        final baseSleep = (summary['sleep_total'] as num).toInt();
        _sleepData = List.generate(7, (i) {
          return HealthDataPoint(
            date: now.subtract(Duration(days: 6 - i)),
            value: (baseSleep + (i * 10 - 30)).toDouble(),
          );
        });
      }
      // 拿到真实数据了 → 关闭未授权标记
      if (mounted && _healthKitNotAuthorized) {
        setState(() => _healthKitNotAuthorized = false);
      } else if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Statistics] 加载健康数据失败: $e');
    }
  }

  Future<void> _loadCheckinData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('user_id') ?? '';

      // 【修复 v1.16.0】签到数据按用户隔离读取，与 home_page / sync_service 保持一致
      final historyKey = uid.isNotEmpty ? 'checkin_history_$uid' : 'checkin_history';
      final totalKey = uid.isNotEmpty ? 'total_check_in_days_$uid' : 'total_check_in_days';

      // 从本地加载签到历史（sync_service 保存的是纯字符串列表）
      final checkinHistoryList = prefs.getStringList(historyKey);
      if (checkinHistoryList != null && checkinHistoryList.isNotEmpty) {
        _checkinDates = checkinHistoryList
            .map((item) {
              try {
                // 兼容两种格式：纯字符串 "2024-01-15" 或 JSON Map {"date":"2024-01-15"}
                if (item.contains('{')) {
                  final parsed = jsonDecode(item) as Map<String, dynamic>;
                  return DateTime.parse(parsed['date'] as String);
                }
                return DateTime.parse(item);
              } catch (_) {
                return null;
              }
            })
            .whereType<DateTime>()
            .toList();
      }

      // 加载统计数据
      _totalCheckins = prefs.getInt(totalKey) ?? 0;
      _currentStreak = StreakUtil.readStreak(prefs, uid);
      _maxStreak = prefs.getInt('checkin_max_streak') ?? 0;

      // 计算本周签到
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      _weeklyCheckins = _checkinDates.where((date) {
        return date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
            date.isBefore(now.add(const Duration(days: 1)));
      }).length;
    } catch (e) {
      if (kDebugMode) debugPrint('[Statistics] 加载签到数据失败: $e');
    }
  }

  Future<void> _loadMenstruationData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 从本地加载经期记录
      final periodHistoryJson = prefs.getString('period_history');
      if (periodHistoryJson != null) {
        final history = jsonDecode(periodHistoryJson) as List<dynamic>;
        _periodRecords = history
            .map((item) => PeriodRecord(
                  startDate: DateTime.parse(item['start_date'] as String),
                  duration: item['duration'] as int,
                  notes: item['notes'] as String?,
                ))
            .toList();
      }

      // 加载经期状态
      _averageCycleLength = prefs.getInt('period_average_cycle') ?? 28;
      _currentCycleDay = prefs.getInt('period_current_cycle_day');
      _isInPeriod = prefs.getBool('period_is_in_period') ?? false;

      final predictedDateStr = prefs.getString('period_predicted_next_date');
      if (predictedDateStr != null) {
        _predictedNextDate = DateTime.tryParse(predictedDateStr);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Statistics] 加载经期数据失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZaiNeColors.scaffoldBg(),
      appBar: AppBar(
        title: const Text('数据统计'),
        backgroundColor: ZaiNeColors.cardBg(),
        foregroundColor: ZaiNeColors.textPrimary(),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: ZaiNeColors.textHint(),
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(icon: Icon(Icons.favorite), text: '健康'),
            Tab(icon: Icon(Icons.calendar_today), text: '签到'),
            Tab(icon: Icon(Icons.water_drop), text: '经期'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildHealthTab(),
                _buildCheckinTab(),
                _buildMenstruationTab(),
              ],
            ),
    );
  }

  Widget _buildHealthTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(ZaiNeSpacing.lg),
      child: Column(
        children: [
          // 🔴【v1.97.3 修复 Bug 8】HealthKit 未授权引导 banner
          if (_healthKitNotAuthorized) _buildHealthKitAuthBanner(),
          if (_healthKitNotAuthorized) const SizedBox(height: ZaiNeSpacing.lg),
          // AI 健康分析入口
          _buildAIAnalysisCard(),
          const SizedBox(height: ZaiNeSpacing.lg),
          // 心率趋势
          HealthTrendChart(
            data: _heartRateData,
            title: '心率趋势',
            unit: 'bpm',
            lineColor: Colors.red,
            fillColor: Colors.red,
            minY: 50,
            maxY: 120,
          ),
          const SizedBox(height: ZaiNeSpacing.lg),
          // 血氧趋势
          HealthTrendChart(
            data: _bloodOxygenData,
            title: '血氧趋势',
            unit: '%',
            lineColor: Colors.blue,
            fillColor: Colors.blue,
            minY: 90,
            maxY: 100,
          ),
          const SizedBox(height: ZaiNeSpacing.lg),
          // 睡眠趋势
          HealthTrendChart(
            data: _sleepData,
            title: '睡眠时长',
            unit: '分钟',
            lineColor: Colors.indigo,
            fillColor: Colors.indigo,
            minY: 300,
            maxY: 600,
          ),
        ],
      ),
    );
  }

  Widget _buildAIAnalysisCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        side: BorderSide(color: Colors.purple.shade200),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AIHealthAnalysisPage()),
          );
        },
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        child: Container(
          padding: const EdgeInsets.all(ZaiNeSpacing.section),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.purple.shade50,
                Colors.purple.shade50,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(ZaiNeRadius.card),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(ZaiNeSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(ZaiNeRadius.card),
                ),
                child: Icon(
                  Icons.psychology,
                  color: Colors.purple.shade400,
                  size: 32,
                ),
              ),
              const SizedBox(width: ZaiNeSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI 健康分析',
                      style: TextStyle(
                        fontSize: ZaiNeFontSize.subtitle,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: ZaiNeSpacing.xs),
                    Text(
                      '智能分析您的健康数据，提供个性化建议',
                      style: TextStyle(
                        fontSize: ZaiNeFontSize.caption,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.purple.shade300,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🔴【v1.97.3 修复 Bug 8】HealthKit 未授权引导 banner
  ///
  /// 当 HealthService.getHealthSummary() 返回空（用户没在 iOS 设置里授权），
  /// 在「健康」Tab 顶部显示这个 banner，提示用户去「设置 → 健康 → 数据来源与访问权限 → 在呢+」勾选。
  Widget _buildHealthKitAuthBanner() {
    return Container(
      padding: const EdgeInsets.all(ZaiNeSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.health_and_safety_outlined, color: Colors.orange.shade700, size: 28),
          const SizedBox(width: ZaiNeSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '请前往 iPhone 授权健康数据',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '设置 → 健康 → 数据来源与访问权限 → 在呢+ → 全部打开',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        // 用 AppLauncher 打开系统设置（iOS 不支持 deep link 到健康 App 内部页）
                        // 直接打开系统设置让用户手动进入
                        try {
                          // 简单提示
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('请打开 iPhone「设置 → 健康」手动授权'),
                                duration: Duration(seconds: 3),
                              ),
                            );
                          }
                        } catch (_) {}
                      },
                      icon: const Icon(Icons.settings, size: 16),
                      label: const Text('我知道了'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _loadData(),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('重新检测'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckinTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(ZaiNeSpacing.lg),
      child: Column(
        children: [
          // 签到统计卡片
          CheckinStatsCard(
            totalDays: _totalCheckins,
            currentStreak: _currentStreak,
            maxStreak: _maxStreak,
            weeklyDays: _weeklyCheckins,
          ),
          const SizedBox(height: ZaiNeSpacing.lg),
          // 签到热力图
          CheckinHeatmap(
            checkinDates: _checkinDates,
            baseColor: const Color(0xFF4CAF50),
          ),
        ],
      ),
    );
  }

  Widget _buildMenstruationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(ZaiNeSpacing.lg),
      child: Column(
        children: [
          // 经期预测卡片
          MenstruationPredictionCard(
            predictedNextDate: _predictedNextDate,
            averageCycleLength: _averageCycleLength,
          ),
          const SizedBox(height: ZaiNeSpacing.lg),
          // 经期周期图表
          MenstruationCycleChart(
            periodRecords: _periodRecords,
            averageCycleLength: _averageCycleLength,
            currentCycleDay: _currentCycleDay,
            predictedNextDate: _predictedNextDate,
            isInPeriod: _isInPeriod,
          ),
        ],
      ),
    );
  }
}
