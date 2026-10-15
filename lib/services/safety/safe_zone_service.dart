/// 安全区域（原地理围栏）服务——provider 入口
///
/// 【CN 合规设计 / 方案 A 文件 swap】
/// - global 构建：直接链接 `safe_zone_service_impl.dart`（`SafeZoneService` 实现类）
/// - CN 构建：由 `build_ipa.sh` 在编译前把 impl 文件整体替换为
///   `safe_zone_service_stub.dart`（仅返回 null，实现类不编译），编译后 trap 还原。
///
/// 因此 `SafeZoneService` 类在 CN 二进制中物理不存在（类名彻底消失，表里如一）。
/// 注：此处不再用 `if (kIsChinaBuild) stub` 条件导入——Dart stable 条件导入
/// 不支持自定义 const bool，AOT 永远选第一个 URI，stub 永不生效（8/28 已验证）。
library;

import 'safe_zone_service_base.dart';
import 'safe_zone_service_impl.dart';

// 下游（UI 等）通过本 provider 单点引入，故 re-export 基类类型，
// 使 SafeZoneMonitor / SafeZone / SafeZoneStatus / SafeZoneType 对调用方可见。
// CN 构建仍保留这些类型（仅实现类 SafeZoneService 被 stub 物理剥离）。
export 'safe_zone_service_base.dart';

/// 获取安全区域服务（CN 构建返回 null）
SafeZoneMonitor? getSafeZoneService() => createSafeZoneService();
