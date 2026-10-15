import 'motion_monitor_service_base.dart';
import 'motion_monitor_service_impl.dart';

// 下游（UI 等）通过本 provider 单点引入，故 re-export 基类类型，
// 使 MotionMonitor 对调用方可见。
// CN 构建仍保留该抽象类型（仅实现类 MotionMonitorService 被 stub 物理剥离）。
export 'motion_monitor_service_base.dart';

/// 获取运动监测服务实例。
///
/// - global 构建：返回完整实现 `MotionMonitorService`。
/// - CN 构建：由 `build_ipa.sh` 经方案 A 文件 swap 把 impl 替换为 stub，
///   返回 null，具体实现不参与编译，
///   故 `MotionMonitorService` 类在 CN 二进制中物理不存在。
MotionMonitor? getMotionMonitor() => createMotionMonitor();
