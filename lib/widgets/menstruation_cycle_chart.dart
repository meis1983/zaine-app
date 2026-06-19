import 'package:flutter/material.dart';

/// 经期周期可视化图表
///
/// 展示用户的经期周期历史、预测下次经期、 fertile window 等信息
class MenstruationCycleChart extends StatelessWidget {
  /// 经期记录列表，每个记录包含开始日期和持续天数
  final List<PeriodRecord> periodRecords;
  
  /// 平均周期长度（天）
  final int averageCycleLength;
  
  /// 当前周期天数（如果正在经期）
  final int? currentCycleDay;
  
  /// 预测下次经期开始日期
  final DateTime? predictedNextDate;
  
  /// 是否正在经期
  final bool isInPeriod;

  const MenstruationCycleChart({
    super.key,
    required this.periodRecords,
    this.averageCycleLength = 28,
    this.currentCycleDay,
    this.predictedNextDate,
    this.isInPeriod = false,
  });

  @override
  Widget build(BuildContext context) {
    if (periodRecords.isEmpty) {
      return _buildEmptyState();
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题和当前状态
            _buildHeader(),
            const SizedBox(height: 20),
            // 周期可视化
            _buildCycleVisualization(),
            const SizedBox(height: 20),
            // 周期历史
            _buildPeriodHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today,
              size: 48,
              color: Colors.pink.shade200,
            ),
            const SizedBox(height: 12),
            Text(
              '暂无经期记录',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '在健康概览页记录经期数据后可查看周期分析',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '经期周期',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '平均周期 $averageCycleLength 天',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
        // 当前状态
        if (isInPeriod && currentCycleDay != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.pink.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.pink.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.water_drop,
                  size: 16,
                  color: Colors.pink.shade400,
                ),
                const SizedBox(width: 4),
                Text(
                  '经期第 $currentCycleDay 天',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.pink.shade600,
                  ),
                ),
              ],
            ),
          )
        else if (predictedNextDate != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.event,
                  size: 16,
                  color: Colors.blue.shade400,
                ),
                const SizedBox(width: 4),
                Text(
                  '预计 ${_daysUntil(predictedNextDate!)} 天后',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _daysUntil(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final days = target.difference(today).inDays;
    return days.toString();
  }

  Widget _buildCycleVisualization() {
    // 显示最近3个周期
    final recentRecords = periodRecords.take(3).toList();
    
    return Column(
      children: [
        // 周期示意图
        SizedBox(
          height: 120,
          child: CustomPaint(
            size: Size.infinite,
            painter: _CyclePainter(
              records: recentRecords,
              averageCycleLength: averageCycleLength,
              isInPeriod: isInPeriod,
              currentCycleDay: currentCycleDay,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 图例
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem('经期', Colors.pink.shade300),
            const SizedBox(width: 20),
            _buildLegendItem('安全期', Colors.green.shade300),
            const SizedBox(width: 20),
            _buildLegendItem('易孕期', Colors.orange.shade300),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '近期记录',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...periodRecords.take(5).map((record) {
          return _buildPeriodHistoryItem(record);
        }),
      ],
    );
  }

  Widget _buildPeriodHistoryItem(PeriodRecord record) {
    final endDate = record.startDate.add(Duration(days: record.duration - 1));
    final dateFormat = '${record.startDate.month}/${record.startDate.day}';
    final endDateFormat = '${endDate.month}/${endDate.day}';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.pink.shade300,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$dateFormat - $endDateFormat',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Text(
            '${record.duration} 天',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.pink.shade400,
            ),
          ),
        ],
      ),
    );
  }
}

/// 经期记录数据类
class PeriodRecord {
  final DateTime startDate;
  final int duration;
  final String? notes;

  const PeriodRecord({
    required this.startDate,
    required this.duration,
    this.notes,
  });
}

/// 周期可视化绘制器
class _CyclePainter extends CustomPainter {
  final List<PeriodRecord> records;
  final int averageCycleLength;
  final bool isInPeriod;
  final int? currentCycleDay;

  _CyclePainter({
    required this.records,
    required this.averageCycleLength,
    required this.isInPeriod,
    this.currentCycleDay,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cycleWidth = size.width / 3;
    final cycleHeight = size.height - 30;
    const topPadding = 15.0;

    for (int i = 0; i < 3; i++) {
      final left = i * cycleWidth + 10;
      final right = (i + 1) * cycleWidth - 10;
      
      if (i < records.length) {
        // 绘制历史周期
        _drawHistoricalCycle(
          canvas,
          left,
          topPadding,
          right - left,
          cycleHeight,
          records[i],
        );
      } else if (i == records.length && isInPeriod) {
        // 绘制当前周期
        _drawCurrentCycle(
          canvas,
          left,
          topPadding,
          right - left,
          cycleHeight,
        );
      } else {
        // 绘制预测周期
        _drawPredictedCycle(
          canvas,
          left,
          topPadding,
          right - left,
          cycleHeight,
        );
      }
    }
  }

  void _drawHistoricalCycle(
    Canvas canvas,
    double left,
    double top,
    double width,
    double height,
    PeriodRecord record,
  ) {
    // 背景条
    final bgPaint = Paint()
      ..color = Colors.grey.shade100
      ..style = PaintingStyle.fill;
    
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, width, height),
      const Radius.circular(8),
    );
    canvas.drawRRect(rect, bgPaint);

    // 经期部分
    final periodRatio = record.duration / averageCycleLength;
    final periodHeight = height * periodRatio;
    
    final periodPaint = Paint()
      ..color = Colors.pink.shade300
      ..style = PaintingStyle.fill;
    
    final periodRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top + height - periodHeight, width, periodHeight),
      const Radius.circular(8),
    );
    canvas.drawRRect(periodRect, periodPaint);

    // 标签
    _drawLabel(canvas, left + width / 2, top - 5, '${record.duration}天');
  }

  void _drawCurrentCycle(
    Canvas canvas,
    double left,
    double top,
    double width,
    double height,
  ) {
    // 背景条
    final bgPaint = Paint()
      ..color = Colors.grey.shade100
      ..style = PaintingStyle.fill;
    
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, width, height),
      const Radius.circular(8),
    );
    canvas.drawRRect(rect, bgPaint);

    // 当前经期进度
    final progressRatio = (currentCycleDay ?? 1) / averageCycleLength;
    final progressHeight = height * progressRatio.clamp(0.0, 1.0);
    
    final periodPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Colors.pink.shade400,
          Colors.pink.shade200,
        ],
      ).createShader(Rect.fromLTWH(left, top + height - progressHeight, width, progressHeight))
      ..style = PaintingStyle.fill;
    
    final periodRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top + height - progressHeight, width, progressHeight),
      const Radius.circular(8),
    );
    canvas.drawRRect(periodRect, periodPaint);

    // 当前标记
    final indicatorPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(left + width / 2, top + height - progressHeight),
      6,
      indicatorPaint,
    );
    
    final borderPaint = Paint()
      ..color = Colors.pink.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(
      Offset(left + width / 2, top + height - progressHeight),
      6,
      borderPaint,
    );

    // 标签
    _drawLabel(canvas, left + width / 2, top - 5, '第$currentCycleDay天');
  }

  void _drawPredictedCycle(
    Canvas canvas,
    double left,
    double top,
    double width,
    double height,
  ) {
    // 虚线边框表示预测
    final borderPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, width, height),
      const Radius.circular(8),
    );
    canvas.drawRRect(rect, borderPaint);

    // 预测的经期（半透明）
    const typicalPeriodDays = 5;
    final periodRatio = typicalPeriodDays / averageCycleLength;
    final periodHeight = height * periodRatio;
    
    final periodPaint = Paint()
      ..color = Colors.pink.shade100
      ..style = PaintingStyle.fill;
    
    final periodRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top + height - periodHeight, width, periodHeight),
      const Radius.circular(8),
    );
    canvas.drawRRect(periodRect, periodPaint);

    // 标签
    _drawLabel(canvas, left + width / 2, top - 5, '预测', isPredicted: true);
  }

  void _drawLabel(Canvas canvas, double x, double y, String text, {bool isPredicted = false}) {
    final textStyle = TextStyle(
      color: isPredicted ? Colors.grey.shade500 : Colors.pink.shade600,
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );
    
    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();
    
    textPainter.paint(
      canvas,
      Offset(x - textPainter.width / 2, y),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// 经期预测卡片
class MenstruationPredictionCard extends StatelessWidget {
  final DateTime? predictedNextDate;
  final int? fertileWindowStart;
  final int? fertileWindowEnd;
  final int averageCycleLength;

  const MenstruationPredictionCard({
    super.key,
    this.predictedNextDate,
    this.fertileWindowStart,
    this.fertileWindowEnd,
    this.averageCycleLength = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '经期预测',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildPredictionItem(
                    '下次经期',
                    predictedNextDate != null
                        ? '${predictedNextDate!.month}/${predictedNextDate!.day}'
                        : '--',
                    Icons.calendar_today,
                    Colors.pink.shade400,
                  ),
                ),
                Expanded(
                  child: _buildPredictionItem(
                    '易孕窗口',
                    fertileWindowStart != null && fertileWindowEnd != null
                        ? '第$fertileWindowStart-$fertileWindowEnd天'
                        : '--',
                    Icons.favorite,
                    Colors.orange.shade400,
                  ),
                ),
                Expanded(
                  child: _buildPredictionItem(
                    '周期长度',
                    '$averageCycleLength天',
                    Icons.timelapse,
                    Colors.blue.shade400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }
}
