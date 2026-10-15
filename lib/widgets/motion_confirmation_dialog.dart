import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import '../theme/theme_helper.dart';
import '../l10n/i18n.dart';

/// 跌倒确认对话框
/// 
/// 当系统检测到可能的跌倒时，显示全屏确认对话框
/// 用户可以选择"我没事"或"需要帮助"
class MotionConfirmationDialog extends StatefulWidget {
  final int countdownSeconds;
  final Function()? onCancel;
  final Function()? onConfirm;

  MotionConfirmationDialog({
    Key? key,
    this.countdownSeconds = 30,
    this.onCancel,
    this.onConfirm,
  }) : super(key: key);

  @override
  State<MotionConfirmationDialog> createState() => _MotionConfirmationDialogState();
}

class _MotionConfirmationDialogState extends State<MotionConfirmationDialog>
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
      duration: Duration(milliseconds: 300),
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
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
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
                margin: EdgeInsets.all(24),
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 警告图标
                    _buildWarningIcon(),
                    SizedBox(height: 20),
                    
                    // 标题
                    Text(
                      tr.z0503,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12),
                    
                    // 描述
                    Text(
                      tr.z0504,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24),
                    
                    // 倒计时指示器
                    _buildCountdownIndicator(),
                    SizedBox(height: 24),
                    
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
      child: Icon(
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
        SizedBox(height: 8),
        Text(
          tr.z0505(_remainingSeconds),
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
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 28),
                SizedBox(height: 4),
                Text(
                  tr.z0506,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 16),
        
        // 需要帮助按钮
        Expanded(
          child: ElevatedButton(
            onPressed: _triggerEmergency,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emergency, size: 28),
                SizedBox(height: 4),
                Text(
                  tr.z0507,
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
void showMotionConfirmationDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => MotionConfirmationDialog(),
  );
}

/// 跌倒检测通知服务
/// 
/// 负责显示跌倒确认通知
class MotionNotificationService {
  static final MotionNotificationService _instance = MotionNotificationService._internal();
  factory MotionNotificationService() => _instance;
  MotionNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    final androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    final initSettings = InitializationSettings(
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
    if (response.payload == 'motion_detection') {
      // 打开跌倒确认页面
      // TODO: 导航到确认页面
    }
  }

  Future<void> showMotionMonitorNotification() async {
    final androidDetails = AndroidNotificationDetails(
      'motion_detection',
      tr.z0508,
      channelDescription: tr.z0509,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
      enableVibration: true,
    );
    
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notifications.show(
      0,
      tr.z0510,
      tr.z0511,
      details,
      payload: 'motion_detection',
    );
  }

  Future<void> cancelNotification() async {
    await _notifications.cancel(0);
  }
}
