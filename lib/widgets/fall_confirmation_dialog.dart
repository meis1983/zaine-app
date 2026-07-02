import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/safety/safety_service.dart';
import '../services/safety/fall_detection_service.dart';
import '../services/api/notify_service.dart';
import '../services/platform/health_service.dart';

/// 跌倒确认对话框 — 全屏覆盖
///
/// 【v1.93.0 方案B-1】当检测到跌倒时弹出：
/// - ⚠️ 检测到跌倒！警告
/// - 60秒倒计时，超时自动通知守护者
/// - [ 我没事，误报 ] — 取消警报
/// - [ 需要帮助！] — 立即通知守护者 + 显示紧急呼叫入口
class FallConfirmationDialog extends StatefulWidget {
  final FallDetectionService detectionService;
  final SafetyService safetyService;
  final VoidCallback? onDismissed;

  const FallConfirmationDialog({
    super.key,
    required this.detectionService,
    required this.safetyService,
    this.onDismissed,
  });

  @override
  State<FallConfirmationDialog> createState() => _FallConfirmationDialogState();
}

class _FallConfirmationDialogState extends State<FallConfirmationDialog>
    with TickerProviderStateMixin {
  // 倒计时
  static const int _totalSeconds = 60;
  int _countdown = 60;
  Timer? _timer;

  // 状态
  bool _isConfirmed = false; // 用户已确认
  bool _isNotifying = false; // 正在通知守护者
  String? _locationAddress; // 位置地址
  List<Map<String, dynamic>> _guardians = []; // 紧急联系人列表
  String _userName = '';
  Map<String, dynamic>? _healthSummary; // 【C-2】生命体征数据

  // 动画
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _startCountdown();
    _loadContext();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ==================== 数据加载 ====================

  Future<void> _loadContext() async {
    // 加载用户信息
    final prefs = await SharedPreferences.getInstance();
    final profileJson = prefs.getString('user_profile');
    if (profileJson != null) {
      try {
        final profile = jsonDecode(profileJson);
        _userName = (profile['name'] as String?) ?? '';
      } catch (_) {}
    }

    // 加载紧急联系人
    final userId = prefs.getString('user_id');
    final contactsKey = (userId != null && userId.isNotEmpty)
        ? 'emergency_contacts_$userId'
        : 'emergency_contacts';
    final contactsJson = prefs.getString(contactsKey);
    if (contactsJson != null && contactsJson.isNotEmpty) {
      try {
        final contacts = List<Map<String, dynamic>>.from(
          jsonDecode(contactsJson),
        );
        if (mounted) setState(() => _guardians = contacts);
      } catch (_) {}
    }

    // 获取位置
    try {
      final location = await widget.safetyService.getCurrentLocation();
      if (mounted && location != null) {
        setState(() => _locationAddress = location.address ?? 
            '(${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)})');
      }
    } catch (_) {}

    // 【C-2】获取生命体征数据
    try {
      final summary = await HealthService.getHealthSummary();
      if (mounted) setState(() => _healthSummary = summary);
    } catch (_) {}
  }

  // ==================== 倒计时 ====================

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_countdown > 0) {
          _countdown--;
          // 最后10秒加触觉反馈
          if (_countdown <= 10 && _countdown > 0) {
            HapticFeedback.lightImpact();
          }
        } else {
          _timer?.cancel();
          _onTimeout();
        }
      });
    });
  }

  /// 倒计时结束，自动通知守护者
  Future<void> _onTimeout() async {
    if (_isConfirmed || _isNotifying) return;
    setState(() => _isNotifying = true);
    HapticFeedback.heavyImpact();
    await _notifyGuardians(reason: 'user_no_response');
    if (mounted) {
      setState(() => _isConfirmed = true);
    }
  }

  // ==================== 用户操作 ====================

  /// 用户确认误报
  void _onCancelTap() {
    _timer?.cancel();
    HapticFeedback.mediumImpact();
    widget.detectionService.cancelFallAlert();
    _dismiss();
  }

  /// 用户确认需要帮助
  Future<void> _onNeedHelpTap() async {
    _timer?.cancel();
    if (_isConfirmed || _isNotifying) return;
    setState(() => _isNotifying = true);
    HapticFeedback.heavyImpact();
    await _notifyGuardians(reason: 'user_confirmed');
    if (mounted) {
      setState(() => _isConfirmed = true);
    }
  }

  // ==================== 通知守护者 ====================

  /// 通知守护者（后端推送 + 系统短信）
  Future<void> _notifyGuardians({required String reason}) async {
    if (kDebugMode) debugPrint('[FallDialog] 通知守护者，原因: $reason');

    // 1. 后端推送通知（附带生命体征数据）
    try {
      await NotifyService.notifyGuardiansAboutFall(
        timestamp: DateTime.now(),
        latitude: _locationAddress?.split(',')[0].replaceAll('(', '').trim(),
        longitude: _locationAddress?.split(',')[1].replaceAll(')', '').trim(),
        healthSummary: _healthSummary, // 【C-2】
      );
      if (kDebugMode) debugPrint('[FallDialog] 后端推送已发送（含生命体征）');
    } catch (e) {
      if (kDebugMode) debugPrint('[FallDialog] 后端推送失败: $e');
    }

    // 2. 生成地图短链并发送短信给所有守护者
    if (_guardians.isNotEmpty) {
      await _sendSMSToAllGuardians();
    }
  }

  /// 发送短信给所有守护者
  Future<void> _sendSMSToAllGuardians() async {
    // 构建通知内容（含生命体征）
    final displayName = _userName.isNotEmpty ? _userName : '用户';
    final locationStr = _locationAddress ?? '位置获取中...';
    final vitalsLine = _buildVitalsSMSLine(); // 【C-2】生命体征摘要

    var smsBody = '【在呢 紧急！】\n'
        '$displayName 疑似跌倒！\n'
        '位置：$locationStr\n';

    if (vitalsLine != null) {
      smsBody += '$vitalsLine\n';
    }

    smsBody += '请尽快联系确认安全！\n'
        '点击拨打电话或打开App查看详情';

    // 逐个发送短信（系统限制一次只能发给一个人）
    for (final guardian in _guardians) {
      final phone = (guardian['phone'] ?? '').toString();
      if (phone.isEmpty) continue;

      try {
        final uri = Uri(
          scheme: 'sms',
          path: phone,
          queryParameters: {'body': smsBody},
        );
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          // 短暂延迟，避免短信界面冲突
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[FallDialog] 发送短信到 $phone 失败: $e');
      }
    }
  }

  // ==================== 紧急呼叫 ====================

  /// 拨打紧急联系人
  Future<void> _callGuardian(Map<String, dynamic> guardian) async {
    final phone = (guardian['phone'] ?? '').toString();
    final name = (guardian['name'] ?? '守护者').toString();
    if (phone.isEmpty) return;

    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法拨打 $name 的电话，请手动拨打 $phone')),
        );
      }
    }
  }

  /// 拨打120
  Future<void> _call120() async {
    final uri = Uri(scheme: 'tel', path: '120');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  // ==================== 退出 ====================

  void _dismiss() {
    widget.onDismissed?.call();
    Navigator.of(context).pop();
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Material(
        color: Colors.transparent,
        child: Container(
          color: Colors.black.withValues(alpha: 0.85),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _isConfirmed ? _buildConfirmedView() : _buildAlertView(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 跌倒警告视图（倒计时中）
  Widget _buildAlertView() {
    final isUrgent = _countdown <= 15;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // ⚠️ 警告图标（脉冲动画）
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final scale = _pulseController.value;
            return Transform.scale(
              scale: 1.0 + scale * 0.1,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isUrgent
                      ? Colors.red.withValues(alpha: 0.2)
                      : Colors.orange.withValues(alpha: 0.15),
                  border: Border.all(
                    color: isUrgent ? Colors.red : Colors.orange,
                    width: 3,
                  ),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 64,
                  color: isUrgent ? Colors.red : Colors.orange,
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 32),

        // 标题
        Text(
          '检测到跌倒！',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: isUrgent ? Colors.red.shade300 : Colors.orange.shade300,
          ),
        ),
        const SizedBox(height: 16),

        // 询问文案
        Text(
          '你是否受伤需要帮助？',
          style: const TextStyle(
            fontSize: 18,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 24),

        // 倒计时环
        _buildCountdownRing(isUrgent),
        const SizedBox(height: 12),

        // 倒计时文案
        Text(
          '${_countdown}秒无响应将自动通知守护者',
          style: TextStyle(
            fontSize: 13,
            color: isUrgent ? Colors.red.shade300 : Colors.white38,
            fontWeight: isUrgent ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 32),

        // 位置信息
        if (_locationAddress != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, color: Colors.white60, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _locationAddress!,
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],

        // 【C-2】生命体征数据
        _buildVitalsPanel(),

        const SizedBox(height: 32),

        // 操作按钮
        _isNotifying
            ? _buildNotifyingIndicator()
            : Row(
                children: [
                  // "我没事" 按钮
                  Expanded(
                    child: _buildActionButton(
                      label: '我没事，误报',
                      icon: Icons.thumb_up_alt,
                      color: Colors.green,
                      onTap: _onCancelTap,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // "需要帮助" 按钮
                  Expanded(
                    child: _buildActionButton(
                      label: '需要帮助！',
                      icon: Icons.sos,
                      color: Colors.red,
                      onTap: _onNeedHelpTap,
                      isPrimary: true,
                    ),
                  ),
                ],
              ),
      ],
    );
  }

  /// 倒计时环
  Widget _buildCountdownRing(bool isUrgent) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: _countdown / _totalSeconds,
            strokeWidth: 4,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
              isUrgent ? Colors.red : Colors.orange,
            ),
          ),
          Text(
            '$_countdown',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isUrgent ? Colors.red : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// 操作按钮
  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? color : Colors.transparent,
          foregroundColor: isPrimary ? Colors.white : color,
          side: isPrimary ? null : BorderSide(color: color.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: isPrimary ? 4 : 0,
        ),
      ),
    );
  }

  /// 通知中指示器
  Widget _buildNotifyingIndicator() {
    return Column(
      children: [
        const SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '正在通知守护者...',
          style: TextStyle(color: Colors.orange, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // ==================== 确认后视图 ====================

  /// 已确认/超时后显示：紧急呼叫入口
  Widget _buildConfirmedView() {
    // 分类联系人：父母排前面
    final sortedGuardians = List<Map<String, dynamic>>.from(_guardians)
      ..sort((a, b) {
        final relA = (a['relation'] ?? '').toString();
        final relB = (b['relation'] ?? '').toString();
        // 父母优先
        if ((relA.contains('爸') || relA.contains('妈')) &&
            !(relB.contains('爸') || relB.contains('妈'))) return -1;
        if (!(relA.contains('爸') || relA.contains('妈')) &&
            (relB.contains('爸') || relB.contains('妈'))) return 1;
        return 0;
      });

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // ✅ 已通知图标
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.orange.withValues(alpha: 0.2),
          ),
          child: const Icon(Icons.check_circle, size: 48, color: Colors.orange),
        ),
        const SizedBox(height: 24),

        Text(
          '已通知守护者',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.orange.shade300,
          ),
        ),
        const SizedBox(height: 12),

        if (_locationAddress != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, color: Colors.white60, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _locationAddress!,
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],

        // 【C-2】生命体征数据（确认后视图中展示给用户，方便口述给急救人员）
        _buildVitalsPanel(),

        const SizedBox(height: 32),
        const Text(
          '立即拨打紧急联系人',
          style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),

        // 守护者列表（快速拨打）
        if (_guardians.isNotEmpty) ...[
          ...sortedGuardians.take(3).map((g) => _buildGuardianCallButton(g)),
          const SizedBox(height: 12),
        ],

        // 拨打120
        _build120CallButton(),

        const SizedBox(height: 32),

        // 关闭按钮
        TextButton.icon(
          onPressed: _dismiss,
          icon: const Icon(Icons.close, color: Colors.white54),
          label: const Text('关闭', style: TextStyle(color: Colors.white54)),
        ),
      ],
    );
  }

  /// 守护者呼叫按钮
  Widget _buildGuardianCallButton(Map<String, dynamic> guardian) {
    final name = (guardian['name'] ?? '守护者').toString();
    final relation = (guardian['relation'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: () => _callGuardian(guardian),
          icon: const Icon(Icons.phone, size: 20),
          label: Text(
            relation.isNotEmpty ? '$name（$relation）' : name,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.15),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== 生命体征展示 【C-2】 ====================

  /// 构建生命体征展示组件
  Widget _buildVitalsPanel() {
    if (_healthSummary == null || _healthSummary!.isEmpty) return const SizedBox.shrink();

    final vitals = _extractVitalsForDisplay();
    if (vitals.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '生命体征',
            style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: vitals.entries.map((e) => _buildVitalChip(e.key, e.value)).toList(),
          ),
        ],
      ),
    );
  }

  /// 提取用于UI展示的生命体征（只取关键指标）
  Map<String, String> _extractVitalsForDisplay() {
    final result = <String, String>{};
    final s = _healthSummary!;

    if (s.containsKey('heart_rate')) {
      result['心率'] = '${s['heart_rate']} bpm';
    }
    if (s.containsKey('blood_oxygen')) {
      final bo = double.tryParse(s['blood_oxygen'].toString()) ?? 0;
      final disp = bo > 1.0 ? '${bo.toStringAsFixed(0)}%' : '${(bo * 100).toStringAsFixed(0)}%';
      result['血氧'] = disp;
    }
    if (s.containsKey('body_temperature')) {
      final temp = double.tryParse(s['body_temperature'].toString()) ?? 0;
      result['体温'] = '${temp.toStringAsFixed(1)}°C';
    }
    if (s.containsKey('bp_systolic') && s.containsKey('bp_diastolic')) {
      final sys = (double.tryParse(s['bp_systolic'].toString()) ?? 0).toStringAsFixed(0);
      final dia = (double.tryParse(s['bp_diastolic'].toString()) ?? 0).toStringAsFixed(0);
      result['血压'] = '$sys/$dia';
    }
    if (s.containsKey('resting_heart_rate')) {
      result['静息心率'] = '${s['resting_heart_rate']} bpm';
    }

    return result;
  }

  /// 生命体征芯片
  Widget _buildVitalChip(String label, String value) {
    // 根据指标类型着色
    Color chipColor = Colors.white.withValues(alpha: 0.12);
    final labelLower = label;

    if (labelLower == '血氧') {
      final numVal = double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
      if (numVal < 92) chipColor = Colors.red.withValues(alpha: 0.25);
    } else if (labelLower == '心率') {
      final numVal = double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
      if (numVal > 100 || (numVal > 0 && numVal < 50)) {
        chipColor = Colors.orange.withValues(alpha: 0.25);
      }
    } else if (labelLower == '体温') {
      final numVal = double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
      if (numVal > 37.5) chipColor = Colors.orange.withValues(alpha: 0.25);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          Text(
            value,
            style: TextStyle(
              color: chipColor == Colors.white.withValues(alpha: 0.12)
                  ? Colors.white70
                  : (chipColor == Colors.red.withValues(alpha: 0.25)
                      ? Colors.red.shade300
                      : Colors.orange.shade300),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建短信中的生命体征行
  String? _buildVitalsSMSLine() {
    if (_healthSummary == null || _healthSummary!.isEmpty) return null;

    final parts = <String>[];
    final s = _healthSummary!;

    if (s.containsKey('heart_rate')) {
      parts.add('心率${s['heart_rate']}bpm');
    }
    if (s.containsKey('blood_oxygen')) {
      final bo = double.tryParse(s['blood_oxygen'].toString()) ?? 0;
      parts.add('血氧${bo > 1.0 ? bo.toStringAsFixed(0) : (bo * 100).toStringAsFixed(0)}%');
    }
    if (s.containsKey('body_temperature')) {
      final temp = double.tryParse(s['body_temperature'].toString()) ?? 0;
      parts.add('体温${temp.toStringAsFixed(1)}°C');
    }
    if (parts.isEmpty) return null;

    return '体征：${parts.join('，')}';
  }

  /// 120呼叫按钮
  Widget _build120CallButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: _call120,
        icon: const Icon(Icons.local_hospital, size: 24),
        label: const Text(
          '拨打 120 急救',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade600,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
        ),
      ),
    );
  }
}
