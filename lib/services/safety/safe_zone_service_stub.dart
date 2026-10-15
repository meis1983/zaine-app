/// 安全区域（原地理围栏）服务 CN 桩
///
/// 【CN 合规设计】CN 构建经条件导入链接本桩，**不定义任何实现类**，
/// 故 `SafeZoneService` 类在 CN 二进制中不存在（类名彻底消失，表里如一）。
library;

import 'safe_zone_service_base.dart';

/// 工厂函数：CN 构建返回 null（不提供安全区域能力）
SafeZoneMonitor? createSafeZoneService() => null;
