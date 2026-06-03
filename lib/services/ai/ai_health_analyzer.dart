/// AI 健康分析服务
///
/// 基于端侧规则引擎和统计分析的 AI 功能
/// 无需调用外部 API，保护用户隐私
library;

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// 健康异常类型
enum HealthAnomalyType {
  heartRateHigh,      // 心率过高
  heartRateLow,       // 心率过低
  heartRateIrregular, // 心率不齐
  sleepInsufficient,  // 睡眠不足
  sleepQualityPoor,   // 睡眠质量差
  bloodOxygenLow,     // 血氧偏低
  hrvLow,             // 心率变异性低（压力大）
  temperatureAbnormal,// 体温异常
  bloodPressureHigh,  // 血压偏高
  bloodPressureLow,   // 血压偏低
  periodIrregular,    // 经期不规律
  checkinMissed,      // 未签到
}

/// 健康分析结果
class HealthAnalysisResult {
  final double overallScore;      // 综合健康评分 0-100
  final List<HealthInsight> insights;  // 健康洞察
  final List<HealthAnomaly> anomalies; // 检测到的异常
  final List<HealthRecommendation> recommendations; // 建议
  final DateTime analysisTime;

  const HealthAnalysisResult({
    required this.overallScore,
    required this.insights,
    required this.anomalies,
    required this.recommendations,
    required this.analysisTime,
  });

  Map<String, dynamic> toJson() => {
        'overall_score': overallScore,
        'insights': insights.map((i) => i.toJson()).toList(),
        'anomalies': anomalies.map((a) => a.toJson()).toList(),
        'recommendations': recommendations.map((r) => r.toJson()).toList(),
        'analysis_time': analysisTime.toIso8601String(),
      };

  factory HealthAnalysisResult.fromJson(Map<String, dynamic> json) {
    return HealthAnalysisResult(
      overallScore: (json['overall_score'] as num).toDouble(),
      insights: (json['insights'] as List<dynamic>)
          .map((i) => HealthInsight.fromJson(i as Map<String, dynamic>))
          .toList(),
      anomalies: (json['anomalies'] as List<dynamic>)
          .map((a) => HealthAnomaly.fromJson(a as Map<String, dynamic>))
          .toList(),
      recommendations: (json['recommendations'] as List<dynamic>)
          .map((r) => HealthRecommendation.fromJson(r as Map<String, dynamic>))
          .toList(),
      analysisTime: DateTime.parse(json['analysis_time'] as String),
    );
  }
}

/// 健康洞察
class HealthInsight {
  final String title;
  final String description;
  final String category; // 'sleep', 'heart', 'activity', 'period', 'general'
  final double confidence; // 置信度 0-1
  final String? relatedMetric;

  const HealthInsight({
    required this.title,
    required this.description,
    required this.category,
    this.confidence = 0.8,
    this.relatedMetric,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'category': category,
        'confidence': confidence,
        'related_metric': relatedMetric,
      };

  factory HealthInsight.fromJson(Map<String, dynamic> json) {
    return HealthInsight(
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      relatedMetric: json['related_metric'] as String?,
    );
  }
}

/// 健康异常
class HealthAnomaly {
  final HealthAnomalyType type;
  final String title;
  final String description;
  final DateTime detectedAt;
  final double severity; // 严重程度 0-1
  final String? relatedValue;
  final String? threshold;

  const HealthAnomaly({
    required this.type,
    required this.title,
    required this.description,
    required this.detectedAt,
    this.severity = 0.5,
    this.relatedValue,
    this.threshold,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'title': title,
        'description': description,
        'detected_at': detectedAt.toIso8601String(),
        'severity': severity,
        'related_value': relatedValue,
        'threshold': threshold,
      };

  factory HealthAnomaly.fromJson(Map<String, dynamic> json) {
    return HealthAnomaly(
      type: HealthAnomalyType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => HealthAnomalyType.checkinMissed,
      ),
      title: json['title'] as String,
      description: json['description'] as String,
      detectedAt: DateTime.parse(json['detected_at'] as String),
      severity: (json['severity'] as num).toDouble(),
      relatedValue: json['related_value'] as String?,
      threshold: json['threshold'] as String?,
    );
  }
}

/// 健康建议
class HealthRecommendation {
  final String title;
  final String description;
  final String category;
  final int priority; // 1-5, 5最高
  final String? actionText;
  final String? actionRoute;

  const HealthRecommendation({
    required this.title,
    required this.description,
    required this.category,
    this.priority = 3,
    this.actionText,
    this.actionRoute,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'category': category,
        'priority': priority,
        'action_text': actionText,
        'action_route': actionRoute,
      };

  factory HealthRecommendation.fromJson(Map<String, dynamic> json) {
    return HealthRecommendation(
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      priority: json['priority'] as int,
      actionText: json['action_text'] as String?,
      actionRoute: json['action_route'] as String?,
    );
  }
}

/// AI 健康分析器
class AIHealthAnalyzer {
  static const String _lastAnalysisKey = 'ai_last_health_analysis';
  static const String _analysisHistoryKey = 'ai_health_analysis_history';

  /// 执行健康数据分析
  static Future<HealthAnalysisResult> analyzeHealthData({
    required Map<String, dynamic> healthData,
    required Map<String, dynamic> userProfile,
    List<Map<String, dynamic>>? historicalData,
  }) async {
    debugPrint('[AI] 开始健康数据分析...');

    final insights = <HealthInsight>[];
    final anomalies = <HealthAnomaly>[];
    final recommendations = <HealthRecommendation>[];

    // 1. 分析心率
    _analyzeHeartRate(healthData, userProfile, insights, anomalies, recommendations);

    // 2. 分析睡眠
    _analyzeSleep(healthData, userProfile, insights, anomalies, recommendations);

    // 3. 分析血氧
    _analyzeBloodOxygen(healthData, insights, anomalies, recommendations);

    // 4. 分析 HRV（压力）
    _analyzeHRV(healthData, insights, anomalies, recommendations);

    // 5. 分析经期（如果有）
    if (userProfile['gender'] == 'female') {
      _analyzeMenstruation(healthData, userProfile, insights, anomalies, recommendations);
    }

    // 6. 分析签到习惯
    _analyzeCheckinPattern(userProfile, insights, anomalies, recommendations);

    // 7. 计算综合评分
    final score = _calculateOverallScore(insights, anomalies);

    final result = HealthAnalysisResult(
      overallScore: score,
      insights: insights,
      anomalies: anomalies,
      recommendations: recommendations..sort((a, b) => b.priority.compareTo(a.priority)),
      analysisTime: DateTime.now(),
    );

    // 保存分析结果
    await _saveAnalysisResult(result);

    debugPrint('[AI] 健康分析完成，评分: $score');
    return result;
  }

  /// 分析心率
  static void _analyzeHeartRate(
    Map<String, dynamic> data,
    Map<String, dynamic> profile,
    List<HealthInsight> insights,
    List<HealthAnomaly> anomalies,
    List<HealthRecommendation> recommendations,
  ) {
    final heartRate = data['heart_rate'];
    final restingHR = data['resting_heart_rate'];

    if (heartRate == null) return;

    final hr = (heartRate is num) ? heartRate.toDouble() : double.tryParse(heartRate.toString()) ?? 0;

    if (hr > 100) {
      anomalies.add(HealthAnomaly(
        type: HealthAnomalyType.heartRateHigh,
        title: '心率偏高',
        description: '当前心率 $hr bpm，高于正常静息心率范围',
        detectedAt: DateTime.now(),
        severity: hr > 120 ? 0.7 : 0.4,
        relatedValue: '$hr bpm',
        threshold: '< 100 bpm',
      ));
      recommendations.add(const HealthRecommendation(
        title: '放松身心',
        description: '尝试深呼吸或冥想，帮助降低心率',
        category: 'heart',
        priority: 4,
        actionText: '开始冥想',
      ));
    } else if (hr < 50) {
      anomalies.add(HealthAnomaly(
        type: HealthAnomalyType.heartRateLow,
        title: '心率偏低',
        description: '当前心率 $hr bpm，低于正常范围',
        detectedAt: DateTime.now(),
        severity: hr < 45 ? 0.6 : 0.3,
        relatedValue: '$hr bpm',
        threshold: '> 50 bpm',
      ));
    } else {
      insights.add(HealthInsight(
        title: '心率正常',
        description: '您的心率 $hr bpm 处于健康范围内',
        category: 'heart',
        confidence: 0.9,
        relatedMetric: 'heart_rate',
      ));
    }

    // 静息心率分析
    if (restingHR != null) {
      final rhr = (restingHR is num) ? restingHR.toDouble() : double.tryParse(restingHR.toString()) ?? 0;
      if (rhr < 60) {
        insights.add(const HealthInsight(
          title: '心肺功能优秀',
          description: '您的静息心率较低，说明心肺功能良好',
          category: 'heart',
          confidence: 0.85,
          relatedMetric: 'resting_heart_rate',
        ));
      }
    }
  }

  /// 分析睡眠
  static void _analyzeSleep(
    Map<String, dynamic> data,
    Map<String, dynamic> profile,
    List<HealthInsight> insights,
    List<HealthAnomaly> anomalies,
    List<HealthRecommendation> recommendations,
  ) {
    final sleepTotal = data['sleep_total'];
    final deepSleep = data['sleep_deep'];

    if (sleepTotal == null) return;

    final totalMinutes = (sleepTotal is num) ? sleepTotal.toInt() : int.tryParse(sleepTotal.toString()) ?? 0;
    final hours = totalMinutes / 60;

    if (hours < 6) {
      anomalies.add(HealthAnomaly(
        type: HealthAnomalyType.sleepInsufficient,
        title: '睡眠不足',
        description: '昨晚睡眠仅 ${hours.toStringAsFixed(1)} 小时，建议保证7-9小时睡眠',
        detectedAt: DateTime.now(),
        severity: hours < 5 ? 0.8 : 0.5,
        relatedValue: '${hours.toStringAsFixed(1)} 小时',
        threshold: '7-9 小时',
      ));
      recommendations.add(const HealthRecommendation(
        title: '改善睡眠',
        description: '尝试提前30分钟上床，建立规律作息',
        category: 'sleep',
        priority: 5,
        actionText: '设置睡眠提醒',
      ));
    } else if (hours > 9) {
      insights.add(const HealthInsight(
        title: '睡眠充足',
        description: '昨晚睡眠充足，有助于身体恢复',
        category: 'sleep',
        confidence: 0.9,
        relatedMetric: 'sleep_total',
      ));
    }

    // 深度睡眠分析
    if (deepSleep != null) {
      final deepMinutes = (deepSleep is num) ? deepSleep.toInt() : int.tryParse(deepSleep.toString()) ?? 0;
      final deepPercentage = (deepMinutes / totalMinutes) * 100;
      
      if (deepPercentage < 15) {
        anomalies.add(HealthAnomaly(
          type: HealthAnomalyType.sleepQualityPoor,
          title: '深度睡眠不足',
          description: '深度睡眠仅占 ${deepPercentage.toStringAsFixed(1)}%，影响恢复质量',
          detectedAt: DateTime.now(),
          severity: 0.5,
          relatedValue: '${deepPercentage.toStringAsFixed(1)}%',
          threshold: '> 15%',
        ));
      }
    }
  }

  /// 分析血氧
  static void _analyzeBloodOxygen(
    Map<String, dynamic> data,
    List<HealthInsight> insights,
    List<HealthAnomaly> anomalies,
    List<HealthRecommendation> recommendations,
  ) {
    final bloodOxygen = data['blood_oxygen'];
    if (bloodOxygen == null) return;

    final bo = (bloodOxygen is num) ? bloodOxygen.toDouble() : double.tryParse(bloodOxygen.toString()) ?? 0;

    if (bo < 95) {
      anomalies.add(HealthAnomaly(
        type: HealthAnomalyType.bloodOxygenLow,
        title: '血氧偏低',
        description: '当前血氧 $bo%，建议关注呼吸健康',
        detectedAt: DateTime.now(),
        severity: bo < 90 ? 0.9 : 0.5,
        relatedValue: '$bo%',
        threshold: '> 95%',
      ));
      if (bo < 90) {
        recommendations.add(const HealthRecommendation(
          title: '关注呼吸健康',
          description: '血氧过低，建议就医检查',
          category: 'general',
          priority: 5,
        ));
      }
    } else {
      insights.add(const HealthInsight(
        title: '血氧正常',
        description: '血氧水平良好，呼吸系统健康',
        category: 'general',
        confidence: 0.9,
        relatedMetric: 'blood_oxygen',
      ));
    }
  }

  /// 分析 HRV（心率变异性 - 压力指标）
  static void _analyzeHRV(
    Map<String, dynamic> data,
    List<HealthInsight> insights,
    List<HealthAnomaly> anomalies,
    List<HealthRecommendation> recommendations,
  ) {
    final hrv = data['hrv_sdnn'];
    if (hrv == null) return;

    final hrvValue = (hrv is num) ? hrv.toDouble() : double.tryParse(hrv.toString()) ?? 0;

    if (hrvValue < 20) {
      anomalies.add(HealthAnomaly(
        type: HealthAnomalyType.hrvLow,
        title: '压力较大',
        description: '心率变异性较低，提示身体处于高压状态',
        detectedAt: DateTime.now(),
        severity: hrvValue < 15 ? 0.7 : 0.5,
        relatedValue: '${hrvValue.toStringAsFixed(1)} ms',
        threshold: '> 20 ms',
      ));
      recommendations.add(const HealthRecommendation(
        title: '减压放松',
        description: '尝试深呼吸、瑜伽或冥想，帮助缓解压力',
        category: 'general',
        priority: 4,
        actionText: '开始冥想',
      ));
    } else if (hrvValue > 50) {
      insights.add(const HealthInsight(
        title: '压力管理良好',
        description: '心率变异性良好，说明压力管理得当',
        category: 'general',
        confidence: 0.85,
        relatedMetric: 'hrv_sdnn',
      ));
    }
  }

  /// 分析经期
  static void _analyzeMenstruation(
    Map<String, dynamic> data,
    Map<String, dynamic> profile,
    List<HealthInsight> insights,
    List<HealthAnomaly> anomalies,
    List<HealthRecommendation> recommendations,
  ) {
    final isInPeriod = data['has_menstruation'] == true;
    final cycleDay = data['cycle_day'] as int?;
    final cycleLength = data['cycle_length'] as int? ?? 28;

    if (isInPeriod && cycleDay != null) {
      if (cycleDay > 7) {
        insights.add(HealthInsight(
          title: '经期较长',
          description: '当前经期第 $cycleDay 天，如持续过长建议咨询医生',
          category: 'period',
          confidence: 0.7,
          relatedMetric: 'cycle_day',
        ));
      }

      // 经期建议
      if (cycleDay <= 3) {
        recommendations.add(const HealthRecommendation(
          title: '经期护理',
          description: '注意保暖，避免剧烈运动，多喝温水',
          category: 'period',
          priority: 3,
        ));
      }
    }

    // 周期规律性分析
    if (cycleLength < 21 || cycleLength > 35) {
      anomalies.add(HealthAnomaly(
        type: HealthAnomalyType.periodIrregular,
        title: '周期不规律',
        description: '当前周期 $cycleLength 天，不在正常范围（21-35天）',
        detectedAt: DateTime.now(),
        severity: 0.4,
        relatedValue: '$cycleLength 天',
        threshold: '21-35 天',
      ));
    }
  }

  /// 分析签到习惯
  static void _analyzeCheckinPattern(
    Map<String, dynamic> profile,
    List<HealthInsight> insights,
    List<HealthAnomaly> anomalies,
    List<HealthRecommendation> recommendations,
  ) {
    final lastCheckin = profile['last_checkin_at'];
    if (lastCheckin == null) {
      anomalies.add(HealthAnomaly(
        type: HealthAnomalyType.checkinMissed,
        title: '未签到',
        description: '今天还没有确认平安，记得签到哦',
        detectedAt: DateTime.now(),
        severity: 0.3,
      ));
      recommendations.add(const HealthRecommendation(
        title: '每日签到',
        description: '养成每日签到习惯，让守护你的人放心',
        category: 'general',
        priority: 3,
        actionText: '立即签到',
        actionRoute: '/home',
      ));
    }
  }

  /// 计算综合健康评分
  static double _calculateOverallScore(
    List<HealthInsight> insights,
    List<HealthAnomaly> anomalies,
  ) {
    double baseScore = 80;

    // 每个异常扣分
    for (final anomaly in anomalies) {
      baseScore -= anomaly.severity * 15;
    }

    // 每个洞察加分（上限20分）
    final insightBonus = math.min(insights.length * 5, 20);
    baseScore += insightBonus;

    return baseScore.clamp(0, 100);
  }

  /// 获取经期预测（基于历史数据）
  static Map<String, dynamic> predictNextPeriod({
    required List<DateTime> periodHistory,
    required int averageCycleLength,
  }) {
    if (periodHistory.length < 2) {
      return {
        'predicted_date': null,
        'confidence': 0.0,
        'fertile_window': null,
        'message': '数据不足，需要至少2个周期记录',
      };
    }

    // 计算平均周期
    final cycles = <int>[];
    for (int i = 1; i < periodHistory.length; i++) {
      final diff = periodHistory[i].difference(periodHistory[i - 1]).inDays;
      if (diff > 20 && diff < 40) {
        cycles.add(diff);
      }
    }

    if (cycles.isEmpty) {
      return {
        'predicted_date': null,
        'confidence': 0.0,
        'message': '周期数据异常',
      };
    }

    final avgCycle = cycles.reduce((a, b) => a + b) / cycles.length;
    final lastPeriod = periodHistory.last;
    final predictedDate = lastPeriod.add(Duration(days: avgCycle.round()));
    
    // 计算易孕窗口（排卵日前5天到后1天）
    final ovulationDay = predictedDate.subtract(const Duration(days: 14));
    final fertileStart = ovulationDay.subtract(const Duration(days: 5));
    final fertileEnd = ovulationDay.add(const Duration(days: 1));

    // 计算置信度（基于数据稳定性）
    final variance = _calculateVariance(cycles);
    final confidence = math.max(0, 1 - (variance / 100));

    return {
      'predicted_date': predictedDate.toIso8601String(),
      'confidence': confidence,
      'average_cycle': avgCycle.round(),
      'fertile_window': {
        'start': fertileStart.toIso8601String(),
        'end': fertileEnd.toIso8601String(),
      },
      'ovulation_day': ovulationDay.toIso8601String(),
      'message': '基于 ${cycles.length} 个周期预测',
    };
  }

  /// 计算方差
  static double _calculateVariance(List<int> values) {
    if (values.length < 2) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((v) => math.pow(v - mean, 2));
    return squaredDiffs.reduce((a, b) => a + b) / values.length;
  }

  /// 保存分析结果
  static Future<void> _saveAnalysisResult(HealthAnalysisResult result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastAnalysisKey, jsonEncode(result.toJson()));

    // 保存到历史
    final historyJson = prefs.getString(_analysisHistoryKey);
    final history = historyJson != null
        ? (jsonDecode(historyJson) as List<dynamic>).cast<Map<String, dynamic>>()
        : <Map<String, dynamic>>[];
    
    history.insert(0, result.toJson());
    // 只保留最近30天的记录
    if (history.length > 30) {
      history.removeRange(30, history.length);
    }
    await prefs.setString(_analysisHistoryKey, jsonEncode(history));
  }

  /// 获取上次分析结果
  static Future<HealthAnalysisResult?> getLastAnalysis() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_lastAnalysisKey);
    if (jsonStr == null) return null;

    try {
      return HealthAnalysisResult.fromJson(jsonDecode(jsonStr));
    } catch (e) {
      debugPrint('[AI] 解析分析结果失败: $e');
      return null;
    }
  }

  /// 获取分析历史
  static Future<List<HealthAnalysisResult>> getAnalysisHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_analysisHistoryKey);
    if (jsonStr == null) return [];

    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((json) => HealthAnalysisResult.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[AI] 解析分析历史失败: $e');
      return [];
    }
  }
}
