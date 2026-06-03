# 在呢 - 独居守护 App v1.0

> 一个简单温暖的独居守护应用，让关心你的人安心。

**口号**：在呢，安心。

---

## 功能特性

### 🟢 第一版MVP核心功能

- ✅ **健康档案** — 姓名/年龄/血型/过敏史/病史/常用药
- ✅ **紧急联系人** — 添加2-3位联系人，SOS优先拨打第一位
- ✅ **每日签到** — 一键确认"我还好"，记录连续签到天数
- 🔥 **连续签到统计** — 养成好习惯
- 🆘 **SOS紧急呼救** — 3秒倒计时触发
  - 自动获取GPS位置
  - 生成完整求救信息（位置+年龄+血型+病史）
  - 自动拨打紧急联系人
  - 发送求救短信给所有联系人
- 📞 **一键拨打120** — SOS后可直接拨打急救电话
- 🔔 **签到提醒** — 设置每日提醒时间
- 🛡️ **隐私中心** — 隐私政策、数据安全保障

---

## 快速开始

### 方式一：一键安装（推荐）

```bash
cd /Users/meixulin/WorkBuddy/20260407202444/zaine_app
chmod +x install.sh
./install.sh
```

安装完成后运行：
```bash
flutter run
```

### 方式二：手动安装 Flutter

1. **下载 Flutter SDK**
   ```bash
   cd ~
   curl -LO https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_3.24.0-stable.zip
   unzip flutter_macos_3.24.0-stable.zip
   rm flutter_macos_3.24.0-stable.zip
   ```

2. **添加到 PATH**
   ```bash
   echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.zshrc
   source ~/.zshrc
   ```

3. **进入项目并运行**
   ```bash
   cd /Users/meixulin/WorkBuddy/20260407202444/zaine_app
   flutter pub get
   flutter run
   ```

---

## iOS 模拟器运行

```bash
# 查看可用模拟器
xcrun simctl list devices available

# 选择一个模拟器运行
flutter run -d "iPhone 15 Pro"
```

---

## 技术栈

- **Flutter** - 跨平台 UI 框架
- **Dart** - 编程语言
- **shared_preferences** - 本地数据存储
- **geolocator** - GPS 定位
- **permission_handler** - 权限管理
- **url_launcher** - 打电话、发短信

---

## 项目结构

```
zaine_app/
├── lib/
│   ├── main.dart              # 主入口 + 底部导航
│   └── pages/
│       ├── home_page.dart     # 主页（签到按钮）
│       ├── profile_page.dart  # 健康档案（新增）
│       ├── sos_page.dart      # SOS紧急呼救（增强）
│       ├── contacts_page.dart # 紧急联系人管理
│       └── settings_page.dart # 设置页 + 隐私中心（增强）
├── ios/
│   └── Runner/Info.plist     # iOS权限配置
├── pubspec.yaml              # 项目依赖
└── README.md                 # 使用说明
```

---

## SOS求救信息格式

触发SOS后，系统会自动生成如下求救信息发送给紧急联系人：

```
【在呢 · SOS紧急求救】

姓名：张三
年龄：28 岁
血型：A型
过敏史：无
既往病史：无
常用药物：无

当前位置：https://maps.apple.com/?ll=39.9042,116.4074

请收到此信息后立即联系我或拨打120！
```

---

## 注意事项

1. **iOS 真机调试** 需要：
   - 苹果开发者账号 ($99/年)
   - 在 Xcode 中配置签名

2. **SOS功能** 需要：
   - 完善健康档案
   - 添加至少一位紧急联系人
   - 开启位置权限（建议"始终允许"）

3. **短信功能**：
   - 当前版本短信发送为模拟状态
   - 正式版需要集成短信API（如阿里云短信）

---

## 版本记录

### v1.0.0 (2026-04-07)
- 初始版本
- 健康档案功能
- SOS紧急呼救
- 每日签到
- 紧急联系人管理
- 隐私政策

---

## 下一步计划

- [ ] 集成真实短信API
- [ ] 添加签到提醒推送通知
- [ ] 设计App Store图标
- [ ] 申请苹果开发者账号
- [ ] 申请应用宝软著
- [ ] 提交审核上架

---

## 商业模式

- **基础版**：免费（签到提醒）
- **高级订阅**：3元/月 或 18元/年（未来版本）
- **永久买断**：48元（未来版本）

---

**让每一次签到，都是对在乎你的人最好的回应。**
