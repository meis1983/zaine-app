// lib/pages/diagnostic_page.dart
// 【v1.98.2 诊断页】地理围栏 / 到家提醒状态直读（调试用，免 Mac 控制台）。
// 仅展示原生侧 getDiagnostics 返回的状态，不触发任何行为。

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/home_arrival_service.dart';

class DiagnosticPage extends StatefulWidget {
  const DiagnosticPage({super.key});

  @override
  State<DiagnosticPage> createState() => _DiagnosticPageState();
}

class _DiagnosticPageState extends State<DiagnosticPage> {
  Map<String, dynamic>? _diag;
  Map<String, dynamic>? _lastResult;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    Map<String, dynamic>? d;
    Map<String, dynamic>? last;
    try {
      d = await HomeArrivalService.getDiagnostics();
      last = await HomeArrivalService.getLastArrivalResult();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '刷新失败：$e';
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _diag = d;
      _lastResult = last;
      _loading = false;
      _error = d == null ? '未获取到数据（仅 iOS 支持）' : (d['error'] as String?);
    });
  }

  String _fmtTs(dynamic v) {
    if (v == null) return '—';
    if (v is num) {
      final dt = DateTime.fromMillisecondsSinceEpoch((v * 1000).round());
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt.toLocal());
    }
    return v.toString();
  }

  String _fmtCoord(dynamic v) {
    if (v == null) return '—';
    return v.toString();
  }

  String _fmtCount(dynamic v) {
    if (v == null) return '—（旧数据，重触发后显示）';
    if (v is int && v < 0) return '查询失败';
    return v.toString();
  }

  String _fmtGuardians(dynamic v) {
    if (v == null) return '—（旧数据，重触发后显示）';
    if (v is List && v.isEmpty) {
      return '0 个 ❌（Phone B 不在守护列表或未注册）';
    }
    if (v is List) return '${v.length} 个: $v';
    return v.toString();
  }

  Widget _row(String label, String value, {bool warn = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: warn ? Colors.red : Colors.black87,
                fontWeight: warn ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _diag;
    final auth = d?['authStatus']?.toString() ?? '—';
    final registered = d?['homeRegionRegistered'] == true;
    final enabled = d?['enabled'] == true;
    final savedLat = d?['savedLat'];
    final savedLng = d?['savedLng'];
    final savedRadius = d?['savedRadius'];
    final center = d?['homeRegionCenter'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('地理围栏诊断（调试）'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _refresh,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Text(_error!, style: const TextStyle(color: Colors.orange)),
                  ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.only(left: 16, top: 8),
                  child: Text('定位与围栏', style: TextStyle(color: Colors.grey)),
                ),
                _row('定位授权', auth, warn: auth != 'always'),
                _row('围栏已注册(系统级)',
                    registered ? '是 ✅' : '否 ❌（系统未监控家围栏）',
                    warn: !registered),
                _row('系统监控区域数', _fmtCoord(d?['monitoredRegionCount'])),
                if (center is Map)
                  _row('系统围栏中心',
                      'lat=${(center['lat'] as num).toStringAsFixed(5)}, '
                      'lng=${(center['lng'] as num).toStringAsFixed(5)}, '
                      'r=${(center['radius'] as num).toStringAsFixed(0)}m'),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.only(left: 16, top: 8),
                  child: Text('功能开关与家坐标', style: TextStyle(color: Colors.grey)),
                ),
                _row('功能总开关', enabled ? '开 ✅' : '关 ❌', warn: !enabled),
                _row('模式B(通知守护人)', d?['modeB'] == true ? '开' : '关'),
                _row('保存家纬度', _fmtCoord(savedLat)),
                _row('保存家经度', _fmtCoord(savedLng)),
                _row('保存半径(m)', _fmtCoord(savedRadius)),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.only(left: 16, top: 8),
                  child: Text('最近触发记录', style: TextStyle(color: Colors.grey)),
                ),
                _row('最近进入家围栏', _fmtTs(d?['lastEnterTs']),
                    warn: d?['lastEnterTs'] == null),
                _row('最近离开家围栏', _fmtTs(d?['lastExitTs']),
                    warn: d?['lastExitTs'] == null),
                _row('最近本地通知投递', _fmtTs(d?['lastNotifTs']),
                    warn: d?['lastNotifTs'] == null),
                _row('待上报守护人事件', _fmtTs(d?['pendingArrivalTs'])),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.only(left: 16, top: 8),
                  child: Text('后端推送链路（最近一次到家上报）',
                      style: TextStyle(color: Colors.grey)),
                ),
                if (_lastResult == null)
                  _row('上次上报结果', '—（尚未触发过模式B上报）')
                else ...[
                  if (_lastResult!['apns_enabled'] == null)
                    // 旧版后端响应（升级前）不含诊断字段，null 不等于"未启用"，需重新触发一次
                    _row('后端上报数据',
                        '旧版响应（缺诊断字段）\n请重新触发一次模式B以刷新真实状态',
                        warn: true)
                  else
                    _row('APNs 线上启用',
                        _lastResult!['apns_enabled'] == true
                            ? '是 ✅'
                            : '否 ❌（线上未部署 APNS 配置，推送不会发）',
                        warn: _lastResult!['apns_enabled'] != true),
                  _row('解析到的守护人',
                      _fmtGuardians(_lastResult!['guardian_ids'])),
                  _row('守护人有 device_token',
                      _fmtCount(_lastResult!['device_tokens']),
                      warn: (_lastResult!['device_tokens'] is int) &&
                            (_lastResult!['device_tokens'] as int) <= 0),
                  _row('实际推送送达数',
                      _fmtCount(_lastResult!['push_delivered'])),
                  if (_lastResult!['skipped'] != null)
                    _row('状态', '今日已去重(skipped): ${_lastResult!['skipped']}'),
                ],
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '判读：若「围栏已注册=否」→ 到家功能未真正启用或家坐标未保存；'
                    '若「定位授权≠always」→ 后台/被杀时不触发；'
                    '若「最近进入家围栏=—」→ 系统从未回调 didEnterRegion（围栏或授权问题）；'
                    '对比「最近离开家围栏」可判断是漏触发"离开"还是漏触发"进入"。',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              ],
            ),
    );
  }
}
