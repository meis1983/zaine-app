import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import '../theme/theme_helper.dart';

/// 跌倒确认对话框
/// 
/// 当系统检测到可能的跌倒时，显示全屏确认对话框
/// 用户可以选择"我没事"或"需要帮助"
class FallConfirmationDialog extends StatefulWidget {
  final int countdownSeconds;
  final Function()? onCancel;
  final Function()? onConfirm;

  const FallConfirmationDialog({
    Key? key,
    this.countdownSeconds = 30,
    this.onCancel,
    this.onConfirm,
  }) : super(key: key);

  @override
  State<FallConfirmationDialog> createState() => _FallConfirmationDialogState();
}

class _FallConfirmationDialogState extends State<FallConfirmationDialog>
    with SingleTickerProviderStateMixin {
  late int _remainingSeconds;
  Timer? _countdownTimer;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.countdownSeconds;
    
    // 动画控制器
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );
    
    _animationController.forward();
    
    // 启动倒计时
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _remainingSeconds--;
      });
      
      if (_remainingSeconds <= 0) {
        timer.cancel();
        // 倒计时结束，自动触发紧急求助
        _triggerEmergency();
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    if (widget.onCancel != null) {
      widget.onCancel!();
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _triggerEmergency() {
    _countdownTimer?.cancel();
    if (widget.onConfirm != null) {
      widget.onConfirm!();
    }
    
    // 触发紧急求助（这里需要调用实际的紧急求助逻辑）
    // TODO: 实现紧急求助逻辑
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // 禁止返回键关闭
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.85),
        body: SafeArea(
          child: Center(
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 警告图标
                    _buildWarningIcon(),
                    const SizedBox(height: 20),
                    
                    // 标题
                    const Text(
                      '检测到可能的跌倒',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    
                    // 描述
                    const Text(
                      '系统检测到您可能发生了跌倒。\n如果您没事，请点击"我没事"。\n如果需要帮助，请点击"需要帮助"。',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    
                    // 倒计时指示器
                    _buildCountdownIndicator(),
                    const SizedBox(height: 24),
                    
                    // 操作按钮
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWarningIcon() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.warning_amber_rounded,
        size: 48,
        color: Colors.orange,
      ),
    );
  }

  Widget _buildCountdownIndicator() {
    final progress = _remainingSeconds / widget.countdownSeconds;
    final color = _remainingSeconds <= 10
        ? Colors.red
        : _remainingSeconds <= 20
            ? Colors.orange
            : ZaiNeColors.brandOrange;

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 4,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Text(
              '$_remainingSeconds',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '$_remainingSeconds 秒后自动触发紧急求助',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        // 我没事按钮
        Expanded(
          child: ElevatedButton(
            onPressed: _cancelCountdown,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 28),
                SizedBox(height: 4),
                Text(
                  '我没事',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        
        // 需要帮助按钮
        Expanded(
          child: ElevatedButton(
            onPressed: _triggerEmergency,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emergency, size: 28),
                SizedBox(height: 4),
                Text(
                  '需要帮助',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 显示跌倒确认对话框
void showFallConfirmationDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const FallConfirmationDialog(),
  );
}

/// 跌倒检测通知服务
/// 
/// 负责显示跌倒确认通知
class FallNotificationService {
  static final FallNotificationService _instance = FallNotificationService._internal();
  factory FallNotificationService() => _instance;
  FallNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    // 处理通知点击事件
    if (response.payload == 'fall_detection') {
      // 打开跌倒确认页面
      // TODO: 导航到确认页面
    }
  }

  Future<void> showFallDetectionNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'fall_detection',
      '跌倒检测',
      channelDescription: '跌倒检测提醒通知',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
      enableVibration: true,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notifications.show(
      0,
      '跌倒检测提醒',
      '系统检测到您可能发生了跌倒，请确认您的安全状态',
      details,
      payload: 'fall_detection',
    );
  }

  Future<void> cancelNotification() async {
    await _notifications.cancel(0);
  }
}
