import 'package:flutter/material.dart';
import '../services/ai/ai_health_analyzer.dart';
import '../services/platform/health_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// AI 健康分析页面
///
/// 展示 AI 分析的健康评分、洞察、异常和建议
class AIHealthAnalysisPage extends StatefulWidget {
  const AIHealthAnalysisPage({super.key});

  @override
  State<AIHealthAnalysisPage> createState() => _AIHealthAnalysisPageState();
}

class _AIHealthAnalysisPageState extends State<AIHealthAnalysisPage> {
  HealthAnalysisResult? _analysisResult;
  bool _isLoading = true;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _loadLastAnalysis();
  }

  Future<void> _loadLastAnalysis() async {
    final lastAnalysis = await AIHealthAnalyzer.getLastAnalysis();
    if (lastAnalysis != null && mounted) {
      setState(() {
        _analysisResult = lastAnalysis;
        _isLoading = false;
      });
    } else {
      // 如果没有历史分析，执行新的分析
      await _performAnalysis();
    }
  }

  Future<void> _performAnalysis() async {
    setState(() => _isAnalyzing = true);

    try {
      // 获取健康数据
      final healthData = await HealthService.getHealthSummary();

      // 获取用户资料
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString('user_profile');
      final userProfile = profileJson != null
          ? jsonDecode(profileJson) as Map<String, dynamic>
          : <String, dynamic>{};

      // 执行 AI 分析
      final result = await AIHealthAnalyzer.analyzeHealthData(
        healthData: healthData,
        userProfile: userProfile,
      );

      if (mounted) {
        setState(() {
          _analysisResult = result;
          _isLoading = false;
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      debugPrint('[AIHealthPage] 分析失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isAnalyzing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('分析失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('AI 健康分析'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          if (_isAnalyzing)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _performAnalysis,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _analysisResult == null
              ? _buildEmptyState()
              : _buildAnalysisResult(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.psychology_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 20),
          Text(
            '暂无分析数据',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _performAnalysis,
            icon: const Icon(Icons.analytics),
            label: const Text('开始分析'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisResult() {
    final result = _analysisResult!;

    return RefreshIndicator(
      onRefresh: _performAnalysis,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 健康评分卡片
            _buildScoreCard(result.overallScore),
            const SizedBox(height: 20),

            // 异常提醒
            if (result.anomalies.isNotEmpty) ...[
              _buildSectionTitle('⚠️ 需要关注', Colors.orange),
              const SizedBox(height: 12),
              ...result.anomalies.map((a) => _buildAnomalyCard(a)),
              const SizedBox(height: 20),
            ],

            // 健康洞察
            if (result.insights.isNotEmpty) ...[
              _buildSectionTitle('💡 健康洞察', Colors.blue),
              const SizedBox(height: 12),
              ...result.insights.map((i) => _buildInsightCard(i)),
              const SizedBox(height: 20),
            ],

            // 个性化建议
            if (result.recommendations.isNotEmpty) ...[
              _buildSectionTitle('🎯 个性化建议', Colors.green),
              const SizedBox(height: 12),
              ...result.recommendations.map((r) => _buildRecommendationCard(r)),
              const SizedBox(height: 20),
            ],

            // 分析时间
            Center(
              child: Text(
                '分析时间: ${_formatTime(result.analysisTime)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard(double score) {
    Color scoreColor;
    String scoreLabel;
    String scoreEmoji;

    if (score >= 80) {
      scoreColor = Colors.green;
      scoreLabel = '优秀';
      scoreEmoji = '🌟';
    } else if (score >= 60) {
      scoreColor = Colors.orange;
      scoreLabel = '良好';
      scoreEmoji = '👍';
    } else {
      scoreColor = Colors.red;
      scoreLabel = '需改善';
      scoreEmoji = '⚠️';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scoreColor.withOpacity(0.15),
            scoreColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scoreColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '健康评分',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '基于您的健康数据分析',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: scoreColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(scoreEmoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 4),
                    Text(
                      scoreLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: scoreColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // 大分数显示
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 12,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                ),
              ),
              Column(
                children: [
                  Text(
                    score.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                    ),
                  ),
                  Text(
                    '/ 100',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: color,
      ),
    );
  }

  Widget _buildAnomalyCard(HealthAnomaly anomaly) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange.shade400, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    anomaly.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getSeverityColor(anomaly.severity).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getSeverityLabel(anomaly.severity),
                    style: TextStyle(
                      fontSize: 11,
                      color: _getSeverityColor(anomaly.severity),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              anomaly.description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            if (anomaly.relatedValue != null && anomaly.threshold != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(
                      '当前: ${anomaly.relatedValue}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '建议: ${anomaly.threshold}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard(HealthInsight insight) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.blue.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.lightbulb, color: Colors.blue.shade400, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    insight.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    insight.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(HealthRecommendation recommendation) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.green.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.check_circle, color: Colors.green.shade400, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    recommendation.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _buildPriorityBadge(recommendation.priority),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              recommendation.description,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            if (recommendation.actionText != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    // 执行建议动作
                  },
                  child: Text(recommendation.actionText!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(int priority) {
    Color color;
    String label;

    switch (priority) {
      case 5:
        color = Colors.red;
        label = '紧急';
        break;
      case 4:
        color = Colors.orange;
        label = '重要';
        break;
      case 3:
        color = Colors.blue;
        label = '建议';
        break;
      default:
        color = Colors.grey;
        label = '提示';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getSeverityColor(double severity) {
    if (severity >= 0.7) return Colors.red;
    if (severity >= 0.4) return Colors.orange;
    return Colors.yellow.shade700;
  }

  String _getSeverityLabel(double severity) {
    if (severity >= 0.7) return '严重';
    if (severity >= 0.4) return '中等';
    return '轻微';
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    return '${time.month}/${time.day} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}
