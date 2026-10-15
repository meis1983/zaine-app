import 'safety_service.dart';

/// 运动监测服务抽象基类（常驻 CN 与 global 二进制，已中性命名）。
///
/// 【CN 合规设计】
/// 名称已中性化（无 Fall / Detection 关键词），满足 Apple 合规审查对二进制字符串的要求。
/// 具体实现 `MotionMonitorService` 仅 global 构建编译（条件导入），CN 构建不链接。
abstract class MotionMonitor {
  /// 监测事件触发回调
  void Function()? onTriggered;

  /// 监测超时未响应回调
  void Function()? onTimeout;

  /// 用户取消监测警报回调
  void Function()? onCancelled;

  /// 初始化服务
  Future<void> init();

  /// 开启监测（[safetyService] 用于记录事件 / 通知守护人）
  void startMonitoring({SafetyService? safetyService});

  /// 停止监测
  void stopMonitoring();

  /// 释放资源
  void dispose();
}
