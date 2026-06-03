# 在呢+ Watch 复杂表盘 (Widget Complications)

## 功能概述

为 Apple Watch 提供多种复杂表盘样式，显示：
- 健康数据（心率、血氧、睡眠）
- 守护圈状态
- 经期追踪
- 紧急告警

## 支持的表盘样式

### 1. 圆形表盘 (Circular)
- 显示健康进度圆环
- 中心显示心率/经期天数/告警图标
- 适合 Modular Compact 等表盘

### 2. 矩形表盘 (Rectangular)
- 左侧：心率 + 血氧
- 右侧：睡眠/经期状态 + 守护圈人数
- 适合 Modular 表盘

### 3. 行内表盘 (Inline)
- 简洁单行显示
- 告警/经期/心率轮换显示
- 适合 Utility 等表盘

### 4. 角落表盘 (Corner)
- 渐变背景设计
- 显示心率和守护圈人数
- 适合 Infograph 等表盘

## 数据同步

### iPhone → Watch Widget

1. **健康数据**: 通过 `WatchDataService.syncWidgetFromHealthSummary()` 同步
2. **守护圈**: 通过 `WatchDataService.updateWidgetData(guardianCount:)` 更新
3. **告警**: 通过 `WatchDataService.updateWidgetData(hasAlert: true, alertType:)` 触发

### 数据存储

- 使用 `SharedPreferences` 存储 Widget 数据
- Key: `widget_data`
- 格式: JSON

## Xcode 配置步骤

### 1. 创建 Widget Extension Target

1. 在 Xcode 中打开项目
2. File → New → Target
3. 选择 "Widget Extension"
4. 命名: `ZaineWatchWidget`
5. 勾选 "Include Configuration Intent"

### 2. 配置 App Group

1. 选中主 Target (Runner)
2. Signing & Capabilities → + Capability
3. 添加 "App Groups"
4. 创建/选择 Group: `group.com.zaine.app`

5. 对 Watch App Target 重复上述步骤
6. 对 Widget Extension Target 重复上述步骤

### 3. 更新 Info.plist

确保所有 Target 的 Bundle Identifier 正确：
- 主 App: `com.zaine.app`
- Watch App: `com.zaine.app.watch`
- Watch Widget: `com.zaine.app.watch.widget`

### 4. 添加文件到 Target

将 `ZaineWatchWidget.swift` 添加到 Widget Extension Target

## 使用示例

### Flutter 端调用

```dart
import 'services/platform/watch_data_service.dart';

// 同步健康数据
final summary = await HealthService().getHealthSummary();
await WatchDataService().syncWidgetFromHealthSummary(
  summary,
  guardianCount: 5,
);

// 触发告警显示
await WatchDataService().updateWidgetData(
  hasAlert: true,
  alertType: 'checkin_missed', // 'sos', 'period', 'checkin_missed'
);

// 清除告警
await WatchDataService().updateWidgetData(
  hasAlert: false,
);
```

## 刷新策略

- 正常状态: 每 5 分钟刷新一次
- 告警状态: 每 1 分钟刷新一次
- 数据更新时: 立即通过 `updateWidgetData` 写入

## 注意事项

1. Widget 数据存储在 iPhone 端，通过 WatchConnectivity 同步到 Watch
2. 确保所有 Target 使用相同的 App Group
3. 首次使用需要在 Watch 表盘设置中添加复杂功能
