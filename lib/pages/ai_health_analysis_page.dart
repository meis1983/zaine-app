import 'package:flutter/material.dart';
import '../theme/theme_helper.dart';
import 'package:flutter/foundation.dart';
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
      if (kDebugMode) debugPrint('[AIHealthPage] 分析失败: $e');
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
      backgroundColor: ZaiNeColors.scaffoldBg(),
      appBar: AppBar(
        title: const Text('AI 健康分析'),
        backgroundColor: ZaiNeColors.cardBg(),
        foregroundColor: ZaiNeColors.textPrimary(),
        elevation: 0,
        actions: [
          if (_isAnalyzing)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: ZaiNeSpacing.lg),
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
            color: ZaiNeColors.textHint(),
          ),
          const SizedBox(height: ZaiNeSpacing.xl),
          Text(
            '暂无分析数据',
            style: TextStyle(
              fontSize: ZaiNeFontSize.subtitle,
              color: ZaiNeColors.textSecondary(),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: ZaiNeSpacing.md),
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
        padding: const EdgeInsets.all(ZaiNeSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 健康评分卡片
            _buildScoreCard(result.overallScore),
            const SizedBox(height: ZaiNeSpacing.xl),

            // 异常提醒
            if (result.anomalies.isNotEmpty) ...[
              _buildSectionTitle('⚠️ 需要关注', Colors.orange),
              const SizedBox(height: ZaiNeSpacing.md),
              ...result.anomalies.map((a) => _buildAnomalyCard(a)),
              const SizedBox(height: ZaiNeSpacing.xl),
            ],

            // 健康洞察
            if (result.insights.isNotEmpty) ...[
              _buildSectionTitle('💡 健康洞察', Colors.blue),
              const SizedBox(height: ZaiNeSpacing.md),
              ...result.insights.map((i) => _buildInsightCard(i)),
              const SizedBox(height: ZaiNeSpacing.xl),
            ],

            // 个性化建议
            if (result.recommendations.isNotEmpty) ...[
              _buildSectionTitle('🎯 个性化建议', Colors.green),
              const SizedBox(height: ZaiNeSpacing.md),
              ...result.recommendations.map((r) => _buildRecommendationCard(r)),
              const SizedBox(height: ZaiNeSpacing.xl),
            ],

            // 分析时间
            Center(
              child: Text(
                '分析时间: ${_formatTime(result.analysisTime)}',
                style: TextStyle(
                  fontSize: ZaiNeFontSize.caption,
                  color: ZaiNeColors.textHint(),
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
      padding: const EdgeInsets.all(ZaiNeSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scoreColor.withValues(alpha: 0.15),
            scoreColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
      
        boxShadow: ZaiNeShadows.card,),
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
                        fontSize: ZaiNeFontSize.body,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: ZaiNeSpacing.xs),
                    Text(
                      '基于您的健康数据分析',
                      style: TextStyle(
                        fontSize: ZaiNeFontSize.caption,
                        color: ZaiNeColors.textSecondary(),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.md, vertical: ZaiNeSpacing.sm),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(ZaiNeRadius.card),
                
                  boxShadow: ZaiNeShadows.card,),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(scoreEmoji, style: const TextStyle(fontSize: ZaiNeFontSize.body)),
                    const SizedBox(width: ZaiNeSpacing.xs),
                    Text(
                      scoreLabel,
                      style: TextStyle(
                        fontSize: ZaiNeFontSize.bodySm,
                        fontWeight: FontWeight.w600,
                        color: scoreColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ZaiNeSpacing.xl),
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
                      fontSize: ZaiNeFontSize.title,
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                    ),
                  ),
                  Text(
                    '/ 100',
                    style: TextStyle(
                      fontSize: ZaiNeFontSize.body,
                      color: ZaiNeColors.textHint(),
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
        fontSize: ZaiNeFontSize.subtitle,
        fontWeight: FontWeight.bold,
        color: color,
      ),
    );
  }

  Widget _buildAnomalyCard(HealthAnomaly anomaly) {
    return Card(
      margin: const EdgeInsets.only(bottom: ZaiNeSpacing.md),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ZaiNeSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange.shade400, size: 24),
                const SizedBox(width: ZaiNeSpacing.md),
                Expanded(
                  child: Text(
                    anomaly.title,
                    style: const TextStyle(
                      fontSize: ZaiNeFontSize.body,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.sm, vertical: ZaiNeSpacing.xs),
                  decoration: BoxDecoration(
                    color: _getSeverityColor(anomaly.severity).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                  
                    boxShadow: ZaiNeShadows.card,),
                  child: Text(
                    _getSeverityLabel(anomaly.severity),
                    style: TextStyle(
                      fontSize: ZaiNeFontSize.micro,
                      color: _getSeverityColor(anomaly.severity),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZaiNeSpacing.sm),
            Text(
              anomaly.description,
              style: TextStyle(
                fontSize: ZaiNeFontSize.bodySm,
                color: ZaiNeColors.textSecondary(),
              ),
            ),
            if (anomaly.relatedValue != null && anomaly.threshold != null) ...[
              const SizedBox(height: ZaiNeSpacing.sm),
              Container(
                padding: const EdgeInsets.all(ZaiNeSpacing.cardXs),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                
                  boxShadow: ZaiNeShadows.card,),
                child: Row(
                  children: [
                    Text(
                      '当前: ${anomaly.relatedValue}',
                      style: TextStyle(
                        fontSize: ZaiNeFontSize.caption,
                        color: ZaiNeColors.textSecondary(),
                      ),
                    ),
                    const SizedBox(width: ZaiNeSpacing.lg),
                    Text(
                      '建议: ${anomaly.threshold}',
                      style: TextStyle(
                        fontSize: ZaiNeFontSize.caption,
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
      margin: const EdgeInsets.only(bottom: ZaiNeSpacing.md),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        side: BorderSide(color: Colors.blue.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ZaiNeSpacing.lg),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(ZaiNeSpacing.cardXs),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(ZaiNeRadius.small),
              
                boxShadow: ZaiNeShadows.card,),
              child: Icon(Icons.lightbulb, color: Colors.blue.shade400, size: 20),
            ),
            const SizedBox(width: ZaiNeSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    insight.title,
                    style: const TextStyle(
                      fontSize: ZaiNeFontSize.body,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: ZaiNeSpacing.xs),
                  Text(
                    insight.description,
                    style: TextStyle(
                      fontSize: ZaiNeFontSize.caption,
                      color: ZaiNeColors.textSecondary(),
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
      margin: const EdgeInsets.only(bottom: ZaiNeSpacing.md),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        side: BorderSide(color: Colors.green.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ZaiNeSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(ZaiNeSpacing.sm),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                  
                    boxShadow: ZaiNeShadows.card,),
                  child: Icon(Icons.check_circle, color: Colors.green.shade400, size: 18),
                ),
                const SizedBox(width: ZaiNeSpacing.md),
                Expanded(
                  child: Text(
                    recommendation.title,
                    style: const TextStyle(
                      fontSize: ZaiNeFontSize.body,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _buildPriorityBadge(recommendation.priority),
              ],
            ),
            const SizedBox(height: ZaiNeSpacing.sm),
            Text(
              recommendation.description,
              style: TextStyle(
                fontSize: ZaiNeFontSize.caption,
                color: ZaiNeColors.textSecondary(),
              ),
            ),
            if (recommendation.actionText != null) ...[
              const SizedBox(height: ZaiNeSpacing.md),
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
      padding: const EdgeInsets.symmetric(horizontal: ZaiNeSpacing.sm, vertical: ZaiNeSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ZaiNeRadius.small),
      
        boxShadow: ZaiNeShadows.card,),
      child: Text(
        label,
        style: TextStyle(
          fontSize: ZaiNeFontSize.micro,
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
