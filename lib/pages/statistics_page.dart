import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/health_trend_chart.dart';
import '../widgets/checkin_heatmap.dart';
import '../widgets/menstruation_cycle_chart.dart';
import '../services/platform/health_service.dart';
import 'ai_health_analysis_page.dart';
import 'dart:convert';

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

    await Future.wait([
      _loadHealthData(),
      _loadCheckinData(),
      _loadMenstruationData(),
    ]);

    setState(() => _isLoading = false);
  }

  Future<void> _loadHealthData() async {
    try {
      final summary = await HealthService.getHealthSummary();

      // 模拟历史数据（实际应从 HealthKit 获取多日数据）
      // 这里使用当前值生成模拟趋势数据
      final now = DateTime.now();

      // 心率数据
      if (summary.containsKey('heart_rate')) {
        final baseHr = double.tryParse(summary['heart_rate'].toString()) ?? 70;
        _heartRateData = List.generate(7, (i) {
          return HealthDataPoint(
            date: now.subtract(Duration(days: 6 - i)),
            value: baseHr + (i * 2 - 6) + (i % 3 - 1) * 3,
          );
        });
      }

      // 血氧数据
      if (summary.containsKey('blood_oxygen')) {
        final baseBo = (summary['blood_oxygen'] as num).toDouble();
        _bloodOxygenData = List.generate(7, (i) {
          return HealthDataPoint(
            date: now.subtract(Duration(days: 6 - i)),
            value: (baseBo + (i % 2) - 0.5).clamp(95.0, 100.0),
          );
        });
      }

      // 睡眠数据
      if (summary.containsKey('sleep_total')) {
        final baseSleep = (summary['sleep_total'] as num).toInt();
        _sleepData = List.generate(7, (i) {
          return HealthDataPoint(
            date: now.subtract(Duration(days: 6 - i)),
            value: (baseSleep + (i * 10 - 30)).toDouble(),
          );
        });
      }
    } catch (e) {
      debugPrint('[Statistics] 加载健康数据失败: $e');
    }
  }

  Future<void> _loadCheckinData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 从本地加载签到历史
      final checkinHistoryJson = prefs.getString('checkin_history');
      if (checkinHistoryJson != null) {
        final history = jsonDecode(checkinHistoryJson) as List<dynamic>;
        _checkinDates = history
            .map((item) => DateTime.parse(item['date'] as String))
            .toList();
      }

      // 加载统计数据
      _totalCheckins = prefs.getInt('checkin_total_days') ?? 0;
      _currentStreak = prefs.getInt('checkin_continuous_days') ?? 0;
      _maxStreak = prefs.getInt('checkin_max_streak') ?? 0;

      // 计算本周签到
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      _weeklyCheckins = _checkinDates.where((date) {
        return date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
            date.isBefore(now.add(const Duration(days: 1)));
      }).length;
    } catch (e) {
      debugPrint('[Statistics] 加载签到数据失败: $e');
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
      debugPrint('[Statistics] 加载经期数据失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('数据统计'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
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
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // AI 健康分析入口
          _buildAIAnalysisCard(),
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
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
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.purple.shade200),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AIHealthAnalysisPage()),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.purple.shade50,
                Colors.purple.shade50,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.psychology,
                  color: Colors.purple.shade400,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI 健康分析',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '智能分析您的健康数据，提供个性化建议',
                      style: TextStyle(
                        fontSize: 13,
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

  Widget _buildCheckinTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 签到统计卡片
          CheckinStatsCard(
            totalDays: _totalCheckins,
            currentStreak: _currentStreak,
            maxStreak: _maxStreak,
            weeklyDays: _weeklyCheckins,
          ),
          const SizedBox(height: 16),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 经期预测卡片
          MenstruationPredictionCard(
            predictedNextDate: _predictedNextDate,
            averageCycleLength: _averageCycleLength,
          ),
          const SizedBox(height: 16),
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
