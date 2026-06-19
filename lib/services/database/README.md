# 在呢+ 本地数据库（SQLite）迁移指南

> v1.17.4 新增，用于替代部分 SharedPreferences 场景，支持复杂查询和事务。

---

## 目录结构

```
lib/services/database/
├── database_service.dart      # 数据库初始化、表创建
├── checkin_dao.dart           # 签到记录 DAO
├── contact_dao.dart           # 联系人缓存 DAO
├── health_dao.dart            # 健康数据缓存 DAO
├── notification_dao.dart      # 通知历史 DAO
├── location_dao.dart          # 位置历史 DAO
└── README.md                  # 本文档
```

---

## 已创建的表

| 表名 | 用途 | 替代 SharedPreferences 场景 |
|---|---|---|
| `checkin_records` | 签到记录 | `checkin_history`（JSON 字符串） |
| `contacts` | 联系人本地缓存 | 联系人列表离线查看 |
| `health_cache` | 健康数据缓存 | 每日步数/心率缓存 |
| `notification_history` | 通知发送记录 | 通知去重、审计 |
| `location_history` | 位置追踪记录 | SOS 位置事后查看 |

---

## 快速使用示例

### 1. 签到记录（CheckinDao）

```dart
import 'services/database/checkin_dao.dart';

// 签到时保存记录
await CheckinDao.insert(CheckinRecord(
  date: '2026-06-10',
  time: '08:30:00',
  timestamp: DateTime.now().millisecondsSinceEpoch,
));

// 查询今日是否已签到
final hasCheckin = await CheckinDao.hasCheckinOn('2026-06-10');

// 获取连续签到天数
final streak = await CheckinDao.getConsecutiveDays();

// 获取本月签到次数
final monthCount = await CheckinDao.getMonthCount(2026, 6);
```

### 2. 联系人缓存（ContactDao）

```dart
import 'services/database/contact_dao.dart';

// 同步服务器联系人时批量插入
await ContactDao.insertBatch([
  ContactRecord(name: '张三', phone: '13800138000', relation: '家人'),
  ContactRecord(name: '李四', phone: '13900139000', relation: '朋友'),
]);

// 获取所有联系人（离线可用）
final contacts = await ContactDao.getAll();

// 获取紧急联系人
final emergency = await ContactDao.getEmergencyContacts();
```

### 3. 健康数据缓存（HealthDao）

```dart
import 'services/database/health_dao.dart';

// 缓存今日步数
await HealthDao.upsert(HealthRecord(
  dataType: 'steps',
  value: 8523,
  unit: 'count',
  date: '2026-06-10',
  timestamp: DateTime.now().millisecondsSinceEpoch,
  source: 'HealthKit',
));

// 获取今日步数
final steps = await HealthDao.getTodaySteps();

// 获取最近 7 天步数趋势（用于图表）
final weekData = await HealthDao.getRecent('steps', 7);
```

### 4. 通知历史（NotificationDao）

```dart
import 'services/database/notification_dao.dart';

// 发送 SOS 后记录
await NotificationDao.insert(NotificationRecord(
  type: 'sos',
  recipient: '13800138000',
  content: '紧急求助 - 位置已发送',
  status: 'sent',
));

// 检查今日是否已发送某类通知（去重）
final hasSent = await NotificationDao.hasSentToday('checkin_reminder');
```

### 5. 位置历史（LocationDao）

```dart
import 'services/database/location_dao.dart';

// SOS 触发时记录位置
await LocationDao.insert(LocationRecord(
  latitude: 31.2304,
  longitude: 121.4737,
  address: '上海市黄浦区人民广场',
  accuracy: 10.5,
  triggerReason: 'sos',
));

// 查看最近 SOS 位置
final sosLocations = await LocationDao.getByReason('sos');
```

---

## 数据库初始化

数据库在**首次调用任意 DAO 方法时自动初始化**，无需手动调用。

如需手动初始化（例如在 `main.dart` 中预加载）：

```dart
import 'services/database/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 可选：预初始化数据库
  await DatabaseService.database;
  
  runApp(const MyApp());
}
```

---

## 迁移策略（从 SharedPreferences 迁移）

### 阶段 1：双写（v1.17.4 - v1.18）

新数据同时写入 SQLite 和 SharedPreferences，保持兼容：

```dart
// 新逻辑：双写
await CheckinDao.insert(record);        // 写入 SQLite
await prefs.setString('checkin_history', json);  // 保留旧逻辑
```

### 阶段 2：单写（v1.19）

确认 SQLite 稳定后，移除 SharedPreferences 写入：

```dart
// 仅写入 SQLite
await CheckinDao.insert(record);
```

### 阶段 3：清理（v1.20）

清理旧版 SharedPreferences 数据：

```dart
await prefs.remove('checkin_history');
```

---

## 调试命令

```dart
// 删除数据库（调试用）
await DatabaseService.deleteDatabase();

// 关闭数据库
await DatabaseService.close();
```

---

## 注意事项

1. **不要存储敏感数据** — Token 等敏感信息继续使用 `flutter_secure_storage`
2. **数据库路径** — iOS: `Documents/zaine_app.db`，Android: `databases/zaine_app.db`
3. **版本升级** — 修改 `_dbVersion` 并更新 `_onUpgrade` 方法
4. **性能** — 单表数据量建议不超过 10,000 条，超出请清理旧数据
