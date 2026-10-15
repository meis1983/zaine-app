/// 安全围栏管理页面
///
/// 【v1.93.0】设置和管理地理围栏（安全区域）
library;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/theme_helper.dart';
import '../services/safety/safe_zone_service.dart';
import '../l10n/i18n.dart';

class SafeZonePage extends StatefulWidget {
  const SafeZonePage({super.key});

  @override
  State<SafeZonePage> createState() => _SafeZonePageState();
}

class _SafeZonePageState extends State<SafeZonePage> {
  final SafeZoneMonitor? _service = getSafeZoneService();
  List<SafeZone> _fences = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFences();
  }

  Future<void> _loadFences() async {
    await _service?.init();
    await _service?.checkAllFences(); // 更新状态
    final fences = await _service?.getAllFences() ?? [];
    if (mounted) {
      setState(() {
        _fences = fences;
        _isLoading = false;
      });
    }
  }

  Future<void> _addFence() async {
    // 先请求权限
    final status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(tr.s647), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    // 获取当前位置作为默认围栏中心
    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    } catch (_) {}

    if (!mounted) return;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _AddFenceDialog(initialLat: pos?.latitude, initialLng: pos?.longitude),
    );

    if (result == null || !mounted) return;

    final type = switch (result['type']) {
      'home' => SafeZoneType.home,
      'work' => SafeZoneType.work,
      _ => SafeZoneType.custom,
    };

    await _service?.addFence(
      name: result['name']!,
      latitude: double.parse(result['latitude']!),
      longitude: double.parse(result['longitude']!),
      radius: double.parse(result['radius'] ?? '200'),
      type: type,
    );

    await _loadFences();
  }

  Future<void> _toggleFence(String id) async {
    await _service?.toggleFence(id);
    await _loadFences();
  }

  Future<void> _deleteFence(SafeZone fence) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.card)),
        title:  Text(tr.s648),
        content: Text(tr.s649(fence.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child:  Text(tr.s016)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child:  Text(tr.s038),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _service?.removeFence(fence.id);
      await _loadFences();
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.card)),
        title:  Text(tr.s650),
        content:  Text(tr.s651),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child:  Text(tr.s016)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child:  Text(tr.s652),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _service?.clearAll();
      await _loadFences();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZaiNeColors.scaffoldBg(),
      appBar: AppBar(
        title:  Text(tr.s653),
        backgroundColor: ZaiNeColors.cardBg(),
        foregroundColor: ZaiNeColors.textPrimary(),
        elevation: 0,
        actions: [
          if (_fences.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearAll,
              tooltip: tr.s654,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _fences.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(ZaiNeSpacing.lg),
                  itemCount: _fences.length,
                  itemBuilder: (context, index) => _buildFenceCard(_fences[index]),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addFence,
        icon: const Icon(Icons.add),
        label:  Text(tr.s655),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(ZaiNeSpacing.xl),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.fence, size: 64, color: Colors.blue.shade300),
          ),
          const SizedBox(height: ZaiNeSpacing.xl),
           Text(
            tr.s656,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: ZaiNeSpacing.sm),
          Text(
            tr.s657,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: ZaiNeColors.textSecondary()),
          ),
          const SizedBox(height: ZaiNeSpacing.xl),
          ElevatedButton.icon(
            onPressed: _addFence,
            icon: const Icon(Icons.add),
            label:  Text(tr.s658),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.small)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFenceCard(SafeZone fence) {
    final isInside = fence.status == SafeZoneStatus.inside;
    final isOutside = fence.status == SafeZoneStatus.outside;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ZaiNeRadius.card),
        side: BorderSide(
          color: isOutside
              ? Colors.orange.shade300
              : ZaiNeColors.borderColor(),
        ),
      ),
      margin: const EdgeInsets.only(bottom: ZaiNeSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(ZaiNeSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 类型图标
                Container(
                  padding: const EdgeInsets.all(ZaiNeSpacing.sm),
                  decoration: BoxDecoration(
                    color: fence.enabled
                        ? (isInside ? Colors.green.shade50 : Colors.orange.shade50)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(ZaiNeRadius.input),
                  ),
                  child: Icon(
                    _getTypeIcon(fence.type),
                    size: 22,
                    color: fence.enabled
                        ? (isInside ? Colors.green : Colors.orange)
                        : Colors.grey,
                  ),
                ),
                const SizedBox(width: ZaiNeSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fence.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: ZaiNeSpacing.xxs),
                      Text(
                        tr.s659(fence.typeLabel, fence.radius.toStringAsFixed(0)),
                        style: TextStyle(fontSize: 12, color: ZaiNeColors.textSecondary()),
                      ),
                    ],
                  ),
                ),
                // 状态标签
                if (fence.enabled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isInside ? Colors.green.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(ZaiNeRadius.small),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isInside ? Icons.check_circle : Icons.warning_amber,
                          size: 14,
                          color: isInside ? Colors.green.shade600 : Colors.orange.shade600,
                        ),
                        const SizedBox(width: ZaiNeSpacing.xs),
                        Text(
                          fence.statusLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isInside ? Colors.green.shade700 : Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: ZaiNeSpacing.md),
            // 操作按钮行
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 开关
                Text(
                  fence.enabled ? tr.s660 : tr.s661,
                  style: TextStyle(
                    fontSize: 12,
                    color: fence.enabled ? Colors.green : Colors.grey,
                  ),
                ),
                Switch(
                  value: fence.enabled,
                  activeThumbColor: Colors.green,
                  onChanged: (_) => _toggleFence(fence.id),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: ZaiNeSpacing.sm),
                TextButton(
                  onPressed: () => _deleteFence(fence),
                  style: TextButton.styleFrom(foregroundColor: Colors.red.shade400),
                  child:  Text(tr.s038),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTypeIcon(SafeZoneType type) {
    switch (type) {
      case SafeZoneType.home:
        return Icons.home;
      case SafeZoneType.work:
        return Icons.work;
      case SafeZoneType.custom:
        return Icons.location_on;
    }
  }
}

/// 添加围栏对话框
class _AddFenceDialog extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const _AddFenceDialog({this.initialLat, this.initialLng});

  @override
  State<_AddFenceDialog> createState() => _AddFenceDialogState();
}

class _AddFenceDialogState extends State<_AddFenceDialog> {
  final _nameController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _radiusController = TextEditingController(text: '200');
  String _selectedType = 'home';

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null) {
      _latController.text = widget.initialLat!.toStringAsFixed(6);
    }
    if (widget.initialLng != null) {
      _lngController.text = widget.initialLng!.toStringAsFixed(6);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.card)),
      title:  Row(
        children: [
          Icon(Icons.fence, color: Colors.blue, size: 24),
          SizedBox(width: ZaiNeSpacing.sm),
          Text(tr.s662),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 围栏名称
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: tr.s663,
                hintText: tr.s664,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.input)),
                isDense: true,
              ),
            ),
             SizedBox(height: ZaiNeSpacing.md),

            // 围栏类型
             Text(tr.s665, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
             SizedBox(height: ZaiNeSpacing.tight),
            SegmentedButton<String>(
              segments:  [
                ButtonSegment(value: 'home', label: Text(tr.s666)),
                ButtonSegment(value: 'work', label: Text(tr.s667)),
                ButtonSegment(value: 'custom', label: Text(tr.s184)),
              ],
              selected: {_selectedType},
              onSelectionChanged: (v) => setState(() => _selectedType = v.first),
              style: ButtonStyle(visualDensity: VisualDensity.compact),
            ),
            const SizedBox(height: ZaiNeSpacing.md),

            // 半径
            TextField(
              controller: _radiusController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: tr.s668,
                hintText: tr.s669,
                suffix:  Text(tr.s670),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.input)),
                isDense: true,
              ),
            ),
            const SizedBox(height: ZaiNeSpacing.md),

            // 坐标（可选手动输入）
            ExpansionTile(
              title:  Text(tr.s671, style: TextStyle(fontSize: 13)),
              initiallyExpanded: false,
              childrenPadding: const EdgeInsets.only(bottom: ZaiNeSpacing.sm),
              children: [
                TextField(
                  controller: _latController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: tr.s672,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.input)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: ZaiNeSpacing.sm),
                TextField(
                  controller: _lngController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: tr.s673,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(ZaiNeRadius.input)),
                    isDense: true,
                  ),
                ),
              ],
            ),

            if (_latController.text.isEmpty || _lngController.text.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(ZaiNeSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(ZaiNeRadius.button),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue.shade400),
                    const SizedBox(width: ZaiNeSpacing.tight),
                    Expanded(
                      child: Text(
                        tr.s674,
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:  Text(tr.s016),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text(tr.s675), backgroundColor: Colors.orange),
              );
              return;
            }
            Navigator.pop(context, {
              'name': _nameController.text.trim(),
              'type': _selectedType,
              'latitude': _latController.text,
              'longitude': _lngController.text,
              'radius': _radiusController.text,
            });
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
          child:  Text(tr.s676),
        ),
      ],
    );
  }
}
