# 在呢+ / Zaine 截图重做指南（ASC 1.98.3）

自动化脚本 + 合成规范。目标：6.7″（1290×2796）截图，前 3 张决定转化，全按「秀收益不秀功能」。

---

## 一、前置条件（必做）

1. **模拟器已 boot**：`open -a Simulator`，并在 Xcode 里选 **iPhone 15 Pro Max（6.7″）** 作为运行设备。
2. **手动登录测试号并造数据**：在模拟器里打开 App，登录一个测试号，确保：
   - 守护圈里**已有守护人**（否则守护圈页空）
   - **已授权 HealthKit 体征**（否则体征页是「未授权」状态）
   - **有联系人**（否则联系人页空）
   脚本不会造数据，只负责导航 + 截图。
3. `flutter pub get`（已加 `integration_test` 依赖）。

> 若未登录，脚本会截一张 `00_need_login.png` 并退出，提示你先登录。

---

## 二、跑脚本（三语一遍出）

```bash
cd /Users/meixulin/Desktop/zaine-app/zaine_app
bash screenshot_run.sh
```

或单跑某一语言：

```bash
flutter test integration_test/screenshot_test.dart --dart-define=SHOT_LOCALE=en
flutter test integration_test/screenshot_test.dart --dart-define=SHOT_LOCALE=zh-CN
flutter test integration_test/screenshot_test.dart --dart-define=SHOT_LOCALE=zh-TW
```

- 截图默认输出 `build/integration_test/screenshots/`（个别 Flutter 版本在项目根目录）。跑完用
  `find . -name '0*.png'` 定位，`screenshot_run.sh` 已自动归到 `screenshots/en|zh-CN|zh-TW/`。
- 第 6 张（联系人）若脚本没找到入口图标，会跳过 —— 此时在模拟器手动进入联系人页按 `⌘+S` 补一张即可。

---

## 三、截图顺序与对应页面

| 文件名 | 页面 | 主题 |
|---|---|---|
| `01_home.png` | 首页·报平安 | 主动报平安 |
| `02_guardian.png` | 守护圈 | 双向守护 |
| `03_sos.png` | SOS / 求助 | 一键求助 + 手动电话短信 |
| `04_health.png` | 体征概览 | 体征守护 |
| `05_profile.png` | 我的 | 场景收尾 |
| `06_contacts.png` | 联系人 | 手动联系 |

---

## 四、合成规范（headline 横幅）

文章 5 条：前 3 张最关键；信息清晰；字要大（≥ 等效 48pt 粗体）；高对比（白字 + 品牌深底或底部深色蒙层）；秀收益不秀功能。

- 横幅放**顶部或底部**，不挡核心按钮。
- 字号手机上能看清，别浅灰字配白底。
- 简中 / 繁中可**同图换 headline**，省一套拍摄。

---

## 五、六张 headline 文案（直接复制进横幅）

### 🇺🇸 English
| 截图 | Headline |
|---|---|
| 01 首页 | One tap, they know you're okay |
| 02 守护圈 | Your guardian circle, always there |
| 03 SOS | SOS with live location, in 1 tap |
| 04 体征 | Know they're truly okay |
| 05 我的 | For families across any distance |
| 06 联系人 | Call or text, your way |

### 🇨🇳 简体中文
| 截图 | Headline |
|---|---|
| 01 首页 | 一键报平安，在乎的人安心 |
| 02 守护圈 | 守护圈，让牵挂有回音 |
| 03 SOS | 一键 SOS，实时位置直达守护人 |
| 04 体征 | 读懂 TA 是否真的安好 |
| 05 我的 | 为远方的家，多一份安心 |
| 06 联系人 | 手动打电话发短信，按你的方式 |

### 🇹🇼 繁體中文
| 截图 | Headline |
|---|---|
| 01 首页 | 一鍵報平安，在乎的人安心 |
| 02 守护圈 | 守護圈，讓牽掛有回音 |
| 03 SOS | 一鍵 SOS，即時位置直達守護人 |
| 04 体征 | 讀懂 TA 是否真的安好 |
| 05 我的 | 為遠方的家，多一份安心 |
| 06 联系人 | 手動打電話發簡訊，按你的方式 |

---

## 六、上传

ASC → 在呢+ → App Store → **1.98.3** → 截图区 → 6.7″ → 按上表顺序传 6 张。
简中 / 繁中本地化截图：可上传对应语言 headline 版本（或用同一张 + 不同语言副标题说明）。
