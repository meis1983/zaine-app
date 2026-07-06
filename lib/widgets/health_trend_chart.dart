import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/theme_helper.dart';

/// 健康数据趋势图表组件
/// 
/// 支持多种健康指标的趋势展示：
/// - 心率趋势
/// - 血氧趋势
/// - 睡眠时长趋势
/// - 体温趋势
/// - HRV 趋势
class HealthTrendChart extends StatelessWidget {
  final List<HealthDataPoint> data;
  final String title;
  final String unit;
  final Color lineColor;
  final Color fillColor;
  final double minY;
  final double maxY;
  final bool showGrid;
  final bool showDots;
  final Duration timeRange;

  const HealthTrendChart({
    super.key,
    required this.data,
    required this.title,
    required this.unit,
    this.lineColor = Colors.blue,
    this.fillColor = Colors.blue,
    this.minY = 0,
    this.maxY = 100,
    this.showGrid = true,
    this.showDots = true,
    this.timeRange = const Duration(days: 7),
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return _buildEmptyState();
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题和统计
            _buildHeader(),
            const SizedBox(height: 16),
            // 图表
            SizedBox(
              height: 180,
              child: CustomPaint(
                size: Size.infinite,
                painter: _TrendChartPainter(
                  data: data,
                  lineColor: lineColor,
                  fillColor: fillColor,
                  minY: minY,
                  maxY: maxY,
                  showGrid: showGrid,
                  showDots: showDots,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // X轴标签
            _buildXAxisLabels(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart,
              size: 48,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              '暂无$title数据',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '佩戴 Apple Watch 并开启健康权限后可查看',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final avg = data.isEmpty ? 0 : data.map((e) => e.value).reduce((a, b) => a + b) / data.length;
    final max = data.isEmpty ? 0 : data.map((e) => e.value).reduce(math.max);
    final latest = data.isEmpty ? 0 : data.last.value;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '最近${timeRange.inDays}天趋势',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
        // 统计数据
        _buildStatItem('当前', latest.toStringAsFixed(0), unit),
        const SizedBox(width: 16),
        _buildStatItem('平均', avg.toStringAsFixed(0), unit),
        const SizedBox(width: 16),
        _buildStatItem('最高', max.toStringAsFixed(0), unit),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade400,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: lineColor,
              ),
            ),
            const SizedBox(width: 2),
            Text(
                unit,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildXAxisLabels() {
    if (data.length < 2) return const SizedBox.shrink();

    final firstDate = data.first.date;
    final lastDate = data.last.date;
    final middleDate = firstDate.add(
      Duration(milliseconds: (lastDate.difference(firstDate).inMilliseconds / 2).round()),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${firstDate.month}/${firstDate.day}',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade400,
          ),
        ),
        Text(
          '${middleDate.month}/${middleDate.day}',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade400,
          ),
        ),
        Text(
          '${lastDate.month}/${lastDate.day}',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade400,
          ),
        ),
      ],
    );
  }
}

/// 健康数据点
class HealthDataPoint {
  final DateTime date;
  final double value;
  final String? note;

  const HealthDataPoint({
    required this.date,
    required this.value,
    this.note,
  });
}

/// 趋势图表绘制器
class _TrendChartPainter extends CustomPainter {
  final List<HealthDataPoint> data;
  final Color lineColor;
  final Color fillColor;
  final double minY;
  final double maxY;
  final bool showGrid;
  final bool showDots;

  _TrendChartPainter({
    required this.data,
    required this.lineColor,
    required this.fillColor,
    required this.minY,
    required this.maxY,
    required this.showGrid,
    required this.showDots,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    const padding = EdgeInsets.only(left: 0, right: 0, top: 10, bottom: 20);
    final chartWidth = size.width - padding.horizontal;
    final chartHeight = size.height - padding.vertical;

    // 绘制网格
    if (showGrid) {
      _drawGrid(canvas, size, padding, chartWidth, chartHeight);
    }

    // 计算数据范围
    final firstDate = data.first.date;
    final lastDate = data.last.date;
    final timeRange = lastDate.difference(firstDate).inMilliseconds.toDouble();

    // 创建路径
    final path = Path();
    final fillPath = Path();

    // 起始点
    final startX = padding.left;
    final startY = padding.top + chartHeight - _normalize(data.first.value, chartHeight);
    path.moveTo(startX, startY);
    fillPath.moveTo(startX, size.height - padding.bottom);
    fillPath.lineTo(startX, startY);

    // 绘制曲线
    for (int i = 1; i < data.length; i++) {
      final point = data[i];
      final prevPoint = data[i - 1];

      final x = padding.left + (point.date.difference(firstDate).inMilliseconds / timeRange) * chartWidth;
      final y = padding.top + chartHeight - _normalize(point.value, chartHeight);

      final prevX = padding.left + (prevPoint.date.difference(firstDate).inMilliseconds / timeRange) * chartWidth;
      final prevY = padding.top + chartHeight - _normalize(prevPoint.value, chartHeight);

      // 使用贝塞尔曲线使线条更平滑
      final cp1x = prevX + (x - prevX) * 0.5;
      final cp1y = prevY;
      final cp2x = prevX + (x - prevX) * 0.5;
      final cp2y = y;

      path.cubicTo(cp1x, cp1y, cp2x, cp2y, x, y);
      fillPath.cubicTo(cp1x, cp1y, cp2x, cp2y, x, y);
    }

    // 完成填充路径
    final lastX = padding.left + chartWidth;
    final lastY = padding.top + chartHeight - _normalize(data.last.value, chartHeight);
    fillPath.lineTo(lastX, size.height - padding.bottom);
    fillPath.close();

    // 绘制填充区域
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          fillColor.withValues(alpha: 0.3),
          fillColor.withValues(alpha: 0.05),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // 绘制线条
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    // 绘制数据点
    if (showDots) {
      _drawDots(canvas, padding, chartWidth, chartHeight, firstDate, timeRange);
    }

    // 绘制最新值的标签
    _drawLatestValueLabel(canvas, size, padding, chartHeight, lastX, lastY);
  }

  void _drawGrid(Canvas canvas, Size size, EdgeInsets padding, double chartWidth, double chartHeight) {
    final gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1;

    // 水平网格线
    for (int i = 0; i <= 4; i++) {
      final y = padding.top + (chartHeight / 4) * i;
      canvas.drawLine(
        Offset(padding.left, y),
        Offset(size.width - padding.right, y),
        gridPaint,
      );
    }
  }

  void _drawDots(
    Canvas canvas,
    EdgeInsets padding,
    double chartWidth,
    double chartHeight,
    DateTime firstDate,
    double timeRange,
  ) {
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final dotBorderPaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < data.length; i++) {
      // 只显示部分点，避免过于密集
      if (data.length > 20 && i % (data.length ~/ 10) != 0 && i != data.length - 1) {
        continue;
      }

      final point = data[i];
      final x = padding.left + (point.date.difference(firstDate).inMilliseconds / timeRange) * chartWidth;
      final y = padding.top + chartHeight - _normalize(point.value, chartHeight);

      canvas.drawCircle(Offset(x, y), 4, dotPaint);
      canvas.drawCircle(Offset(x, y), 4, dotBorderPaint);
    }
  }

  void _drawLatestValueLabel(
    Canvas canvas,
    Size size,
    EdgeInsets padding,
    double chartHeight,
    double lastX,
    double lastY,
  ) {
    final latestValue = data.last.value.toStringAsFixed(0);
    
    // 绘制背景
    final bgPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 11,
      fontWeight: FontWeight.bold,
    );

    final textSpan = TextSpan(text: latestValue, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(lastX - textPainter.width / 2 - 8, lastY - 15),
        width: textPainter.width + 12,
        height: textPainter.height + 6,
      ),
      const Radius.circular(4),
    );

    canvas.drawRRect(bgRect, bgPaint);
    textPainter.paint(
      canvas,
      Offset(lastX - textPainter.width / 2 - 8 - textPainter.width / 2, lastY - 15 - textPainter.height / 2),
    );
  }

  double _normalize(double value, double chartHeight) {
    final range = maxY - minY;
    if (range == 0) return chartHeight / 2;
    return ((value - minY) / range) * chartHeight;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
