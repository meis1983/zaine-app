/// 【P1 v1.94.0】位置轨迹地图可视化页面
///
/// 用 Canvas 绘制"地图风格"轨迹可视化：
/// - 网格底图（模拟街道感）
/// - 今日移动轨迹线（渐变色 + 发光）
/// - 定位记录点（大小随时间递增）
/// - 当前位置红色脉冲
/// - 安全围栏虚线圈叠加
/// - 底部统计（移动距离 / 活动范围 / 围栏内停留）
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../services/safety/safety_service.dart';
import '../services/safety/geofence_service.dart';
import 'location_history_page.dart';
import '../theme/theme_helper.dart';

class LocationMapPage extends StatefulWidget {
  final DateTime? day;
  const LocationMapPage({super.key, this.day});

  @override
  State<LocationMapPage> createState() => _LocationMapPageState();
}

class _LocationMapPageState extends State<LocationMapPage>
    with SingleTickerProviderStateMixin {
  final SafetyService _safety = SafetyService();
  final GeoFenceService _geo = GeoFenceService();
  List<LocationRecord> _records = [];
  List<GeoFence> _fences = [];
  bool _loading = true;
  late DateTime _selectedDay;
  late AnimationController _pulseController;

  // 统计
  double _totalDistance = 0;
  double _activityDiameter = 0;
  final Map<String, double> _fenceDurations = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.day ?? DateTime.now();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await _safety.initialize();
    await _geo.init();
    final records = await _safety.getLocationTrackForDay(_selectedDay);
    final fences = await _geo.getAllFences();
    _computeStats(records, fences);
    if (mounted) {
      setState(() {
        _records = records;
        _fences = fences;
        _loading = false;
      });
    }
  }

  void _computeStats(List<LocationRecord> records, List<GeoFence> fences) {
    _totalDistance = 0;
    _activityDiameter = 0;
    _fenceDurations.clear();

    if (records.length >= 2) {
      double minLat = records.first.latitude;
      double maxLat = records.first.latitude;
      double minLng = records.first.longitude;
      double maxLng = records.first.longitude;

      for (int i = 0; i < records.length; i++) {
        final r = records[i];
        if (i > 0) {
          _totalDistance += Geolocator.distanceBetween(
            records[i - 1].latitude,
            records[i - 1].longitude,
            r.latitude,
            r.longitude,
          );
        }
        minLat = math.min(minLat, r.latitude);
        maxLat = math.max(maxLat, r.latitude);
        minLng = math.min(minLng, r.longitude);
        maxLng = math.max(maxLng, r.longitude);

        // 围栏内停留时长（用相邻记录时间差累加）
        if (i > 0) {
          final dt = records[i].timestamp
              .difference(records[i - 1].timestamp)
              .inSeconds
              .toDouble();
          for (final f in fences) {
            if (f.enabled && f.containsCoord(r.latitude, r.longitude)) {
              _fenceDurations[f.name] = (_fenceDurations[f.name] ?? 0) + dt;
            }
          }
        }
      }
      // 活动范围 = bounding box 对角线
      _activityDiameter = Geolocator.distanceBetween(
        minLat,
        minLng,
        maxLat,
        maxLng,
      );
    }
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDay = picked);
      await _load();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: ZaiNeColors.scaffoldBg(),
      appBar: AppBar(
        title: const Text('今日轨迹'),
        backgroundColor: ZaiNeColors.cardBg(),
        foregroundColor: ZaiNeColors.textPrimary(),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _pickDay,
            tooltip: '选择日期',
          ),
          IconButton(
            icon: const Icon(Icons.list_alt),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LocationHistoryPage(day: _selectedDay),
              ),
            ),
            tooltip: '轨迹列表',
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          // 日期条
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            color: isDark ? Colors.indigo.shade900 : Colors.blue.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today,
                    size: 15, color: isDark ? Colors.indigo.shade200 : Colors.blue.shade400),
                const SizedBox(width: 8),
                Text(
                  DateFormat('yyyy年MM月dd日').format(_selectedDay),
                  style: TextStyle(
                    fontSize: ZaiNeFontSize.body,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.indigo.shade100 : Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _pickDay,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('切换', style: TextStyle(fontSize: ZaiNeFontSize.caption)),
                ),
              ],
            ),
          ),

          // 地图可视化
          Expanded(
            flex: 3,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                    ? _buildEmptyMap()
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          return CustomPaint(
                            size: Size(constraints.maxWidth, constraints.maxHeight),
                            painter: TrackMapPainter(
                              records: _records,
                              fences: _fences,
                              isDark: isDark,
                              pulse: _pulseController,
                            ),
                          );
                        },
                      ),
          ),

          // 统计卡片
          if (!_loading && _records.isNotEmpty)
            _buildStatsCard()
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildEmptyMap() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, size: 64, color: ZaiNeColors.textHint()),
          const SizedBox(height: 12),
          Text('今日暂无轨迹记录',
              style: TextStyle(fontSize: ZaiNeFontSize.body, color: ZaiNeColors.textSecondary())),
          const SizedBox(height: 6),
          Text('开启位置共享后，这里会显示你的活动地图',
              style: TextStyle(fontSize: ZaiNeFontSize.caption, color: ZaiNeColors.textHint())),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _StatItem(
            icon: Icons.route,
            color: Colors.blue,
            value: _formatDistance(_totalDistance),
            label: '今日移动',
          ),
          const SizedBox(width: 12),
          _StatItem(
            icon: Icons.open_with,
            color: Colors.purple,
            value: _formatDistance(_activityDiameter),
            label: '活动范围',
          ),
          const SizedBox(width: 12),
          _StatItem(
            icon: Icons.timer_outlined,
            color: Colors.green,
            value: _fenceDurations.isNotEmpty
                ? _formatDuration(_fenceDurations.values.reduce((a, b) => a + b))
                : '0分',
            label: '围栏内停留',
          ),
        ],
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)}km';
    return '${meters.toInt()}m';
  }

  String _formatDuration(double seconds) {
    final min = (seconds / 60).floor();
    if (min >= 60) {
      final h = (min / 60).floor();
      return '${h}时${min % 60}分';
    }
    return '${min}分';
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  const _StatItem({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 11, color: ZaiNeColors.textSecondary())),
          ],
        ),
      ),
    );
  }
}

/// 地图风格轨迹绘制
class TrackMapPainter extends CustomPainter {
  final List<LocationRecord> records;
  final List<GeoFence> fences;
  final bool isDark;
  final Animation<double> pulse;

  TrackMapPainter({
    required this.records,
    required this.fences,
    required this.isDark,
    required this.pulse,
  }) : super(repaint: pulse);

  // 视图范围
  late final _ViewBox _box = _computeViewBox();

  _ViewBox _computeViewBox() {
    if (records.isEmpty) {
      return _ViewBox(0, 0, 0, 0, 1, 1, 0, 0);
    }
    double minLat = records.first.latitude;
    double maxLat = records.first.latitude;
    double minLng = records.first.longitude;
    double maxLng = records.first.longitude;

    for (final r in records) {
      minLat = math.min(minLat, r.latitude);
      maxLat = math.max(maxLat, r.latitude);
      minLng = math.min(minLng, r.longitude);
      maxLng = math.max(maxLng, r.longitude);
    }

    // 扩展围栏半径
    for (final f in fences) {
      if (!f.enabled) continue;
      final latDelta = f.radius / 111320;
      final lngDelta = f.radius / (111320 * math.cos(f.latitude * math.pi / 180));
      minLat = math.min(minLat, f.latitude - latDelta);
      maxLat = math.max(maxLat, f.latitude + latDelta);
      minLng = math.min(minLng, f.longitude - lngDelta);
      maxLng = math.max(maxLng, f.longitude + lngDelta);
    }

    // 加 8% padding
    final latPad = (maxLat - minLat) * 0.08;
    final lngPad = (maxLng - minLng) * 0.08;
    minLat -= latPad;
    maxLat += latPad;
    minLng -= lngPad;
    maxLng += lngPad;

    return _ViewBox(minLat, maxLat, minLng, maxLng,
        111320, 111320 * math.cos(((minLat + maxLat) / 2) * math.pi / 180), 0, 0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 背景
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFEEF2F7);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = bg);

    // 网格（模拟地图街道）
    final gridColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.04);
    const gridStep = 36.0;
    final gridPaint = Paint()..color = gridColor..strokeWidth = 1;
    for (double x = 0; x <= w; x += gridStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }
    for (double y = 0; y <= h; y += gridStep) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    if (records.isEmpty) return;

    // 计算缩放：保持纵横比，居中
    final spanLat = _box.maxLat - _box.minLat;
    final spanLng = _box.maxLng - _box.minLng;
    final metersH = spanLat * _box.mPerLat;
    final metersW = spanLng * _box.mPerLng;
    final scale = math.min(w / metersW, h / metersH) * 0.92;
    final drawW = metersW * scale;
    final drawH = metersH * scale;
    final offsetX = (w - drawW) / 2;
    final offsetY = (h - drawH) / 2;

    Offset toXY(double lat, double lng) {
      final x = offsetX + (lng - _box.minLng) * _box.mPerLng * scale;
      final y = offsetY + (_box.maxLat - lat) * _box.mPerLat * scale;
      return Offset(x, y);
    }

    // 围栏圈
    for (final f in fences) {
      if (!f.enabled) continue;
      final center = toXY(f.latitude, f.longitude);
      final rPx = f.radius * scale;
      final color = _fenceColor(f.type);
      // 半透明填充
      canvas.drawCircle(center, rPx, Paint()..color = color.withValues(alpha: 0.08));
      // 虚线边框
      _drawDashedCircle(canvas, center, rPx, color.withValues(alpha: 0.7));
      // 标签
      final label = f.name;
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - rPx - 16));
    }

    // 轨迹线（渐变发光）
    if (records.length >= 2) {
      final path = Path();
      for (int i = 0; i < records.length; i++) {
        final p = toXY(records[i].latitude, records[i].longitude);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      // 发光底层
      canvas.drawPath(
        path,
        Paint()
          ..color = (isDark ? Colors.cyan : Colors.blue).withValues(alpha: 0.25)
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
      // 主线
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            colors: isDark
                ? [Colors.cyan.shade300, Colors.orange.shade300]
                : [Colors.blue.shade400, Colors.orange.shade400],
          ).createShader(Rect.fromLTWH(0, 0, w, h))
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    }

    // 定位点（大小随时间递增）
    for (int i = 0; i < records.length; i++) {
      final p = toXY(records[i].latitude, records[i].longitude);
      final t = records.length > 1 ? i / (records.length - 1) : 0.0;
      final r = 3 + t * 3;
      final isLast = i == records.length - 1;
      if (isLast) {
        // 当前位置：红色脉冲
        final pulseR = 8 + pulse.value * 6;
        canvas.drawCircle(
          p,
          pulseR,
          Paint()..color = Colors.red.withValues(alpha: 0.25 * (1 - pulse.value)),
        );
        canvas.drawCircle(
          p,
          r + 2,
          Paint()..color = Colors.red.withValues(alpha: 0.9),
        );
      } else {
        final dotColor = Color.lerp(Colors.blue, Colors.orange, t)!;
        canvas.drawCircle(p, r, Paint()..color = dotColor);
      }
    }

    // 起点标记
    final start = toXY(records.first.latitude, records.first.longitude);
    canvas.drawCircle(start, 4.5, Paint()..color = Colors.green);
  }

  Color _fenceColor(GeoFenceType type) {
    switch (type) {
      case GeoFenceType.home:
        return Colors.purple;
      case GeoFenceType.work:
        return Colors.blue;
      case GeoFenceType.custom:
        return Colors.teal;
    }
  }

  void _drawDashedCircle(Canvas canvas, Offset c, double r, Color color) {
    const dash = 6.0;
    const gap = 4.0;
    const step = dash + gap;
    final count = (2 * math.pi * r / step).floor();
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < count; i++) {
      final a1 = i * step / r;
      final a2 = (i * step + dash) / r;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        a1,
        a2 - a1,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant TrackMapPainter old) =>
      old.records != records || old.fences != fences || old.isDark != isDark;
}

class _ViewBox {
  final double minLat, maxLat, minLng, maxLng;
  final double mPerLat, mPerLng;
  final double pad1, pad2;
  _ViewBox(this.minLat, this.maxLat, this.minLng, this.maxLng, this.mPerLat,
      this.mPerLng, this.pad1, this.pad2);
}
