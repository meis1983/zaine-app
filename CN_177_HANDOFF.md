# CN 177 包 出包交接单（在呢+ 中国合规版）

> 基于 176 代码改动，本轮修复 5 张真机截图反馈 + 并入 P2 扫码建关系。
> 全部代码改动已落在 `zaine_app/` 工作树，**未提交、未出包**。

## 一、本轮改了什么（4 块）

### 1. P0 · CN 登录后弹窗卡死（截图2 根因）
- `lib/services/deep_link_service.dart`：`_handleLink()` 两处 `onCardCodeReceived?.call()` 前加 `if (!kIsChinaBuild)` 拦截；CN 不再保存/触发全球版欢迎仪式。
- `lib/pages/home_page.dart`：仅非 CN 注册 `onCardCodeReceived` 回调；`_checkAndShowGuardianRituals()` 开头 `if (kIsChinaBuild) return;`（CN 彻底不走 3D 信封仪式，改用 redeem 成功弹窗）。顺带消除截图1「守护成功 + 签到成功」双弹。
- `lib/widgets/guardian_ritual.dart`：加固 `showGuardianWelcomeRitual` —— `barrierDismissible:true`、右上角 X 关闭、8 秒硬超时兜底 Timer、`onClosed` 单次守卫。即使动画异常也不会永久卡屏。

### 2. P1.5 · 我的守护码准静态（截图4）
- `lib/pages/my_guardian_code_page.dart`：新增 `static String? _cachedCode` 内存缓存。命中即直接展示、不查服务端 → 每次打开都是同一个码（可复用），进入即显示不闪烁。

### 3. P1 · 命名大扫除（截图3 文案残留）
- `lib/l10n/app_zh.arb` / `app_zh_CN.arb` / `app_zh_TW.arb` / `app_zh_HK.arb` 共 10 个 key 同步改「守护卡/发卡人/发卡」→「守护码/守护关系/对方」：
  `s030 s206 s214 s273 s450 s452 s932 s936 s1014 s1017`。英文 `app_en.arb` 保留（海外）。
- **刻意不碰**其余 40+ 处全球版「守护卡裂变分享」字符串。

### 4. P2 · 扫码建关系（本轮并入，用户拍板）
- `pubspec.yaml`：新增 `mobile_scanner: ^7.4.0`（已 WebFetch 核实最新稳定版，非旧记的 5.2.3）。
- `ios/Runner/Info.plist`：新增 `NSCameraUsageDescription` = "在呢需要访问相机以扫描对方的守护码，从而建立守护关系。"
- 新建 `lib/pages/scan_guardian_code_page.dart`：`MobileScanner` 7.x（`BarcodeCapture.barcodes.first.rawValue`），守护码白名单 `^[a-zA-Z0-9]{6,8}$`，支持纯码 / URL 末段回退。
- `lib/pages/redeem_card_page.dart`：顶部加「扫描对方的守护码」按钮 + `_scanCode()`，扫码解析后回填走与手动输入完全相同的 `redeemCard` 流程。

## 二、后端：✅ 无需部署（已实测确认上线）

**结论：后端不用再 `s deploy`，本轮直接出包即可。**

实测证据（2026-08-30 22:50 核验）：

| 检查项 | 结果 |
|---|---|
| 线上健康 | `{"status":"ok","version":"2.0.0"}` HTTP 200 |
| 线上 `RedeemCardRequest` schema | `['card_code', 'oneway']` → **oneway 已上线** ✅ |
| 线上 `PeaceConfirmRequest` schema | 含 `response_type` + `message` ✅ |
| 新端点 `/api/notify/guardians-help` | 已上线 ✅ |
| 新端点 `/api/peace/acknowledge` | 已上线 ✅ |
| FC 函数 `lastModifiedTime` | `2026-08-30T12:28:06Z` = **北京时间 20:28** |
| 后端 oneway 代码 mtime | `2026-08-30 20:19`（北京时间） |

→ 部署时间（20:28）**晚于**代码修改时间（20:19）9 分钟，且线上 OpenAPI 已含全部新字段/新端点 ⇒ 全量已上线。

验证命令（想自己复核就跑这条）：
```bash
curl -s https://zaine-api-skhntjskvp.cn-hangzhou.fcapp.run/openapi.json \
  | python3 -c "import json,sys;d=json.load(sys.stdin);print(list(d['components']['schemas']['RedeemCardRequest']['properties'].keys()))"
# 期望输出：['card_code', 'oneway']
```

> ⚠️ 顺带提醒（不影响本轮）：`s.yaml:22-24` 的 `logConfig` 目前是注释状态，线上函数无 SLS 日志配置。
> 若后续需要拉云端日志诊断，需要先恢复该配置再部署。本轮**不动它**。

## 三、出包（在你的 Mac 上执行）

已由我预先完成并验证的步骤：
- ✅ `flutter gen-l10n` 已跑（产物 `app_localizations_zh.dart` 更新至 22:54，新文案已确认写入、旧文案零残留）
- ✅ 4 个 arb 已验证为合法 JSON
- ✅ 8 个后端改动文件 `py_compile` 全绿
- ✅ iOS 最低版本 15.0，与 `mobile_scanner 7.4.0` 兼容（该版本用 Apple Vision，不引入 MLKit 大体积依赖）

你需要执行（`flutter pub get` 在我这边受沙箱权限限制，必须你本机跑）：

```bash
# 1) 进入前端工程根目录（build_ipa.sh 内含相对路径，必须在此目录）
cd /Users/meixulin/Desktop/zaine-app/zaine_app

# 2) 先单独拉一次新依赖（把 mobile_scanner 的问题提前暴露，别等到出包才炸）
flutter pub get

# 3) 出 177 包（⚠️ ZAI_VERSION_NAME 一定不能漏，176 就是漏它才被 409 拒）
ZAI_VERSION_NAME=1.97.7 ZAI_BUILD_NUMBER=177 ZAI_REGION=cn bash build_ipa.sh
```

> `build_ipa.sh:128-129` 自带 `flutter clean` + `flutter pub get`，pod install 由 `flutter build ipa` 自动触发。

**若第 3 步在 CocoaPods 环节报错**（新增原生插件首次集成的典型症状），执行兜底后重跑第 3 步：
```bash
cd /Users/meixulin/Desktop/zaine-app/zaine_app/ios
pod install --repo-update
cd /Users/meixulin/Desktop/zaine-app/zaine_app
```

## 四、出包后自检（防 176 翻车）

```bash
# 版本号必须 = 1.97.7（176 因漏传变成了 1.97.0 才被 409 拒）
unzip -p <你的ipa>.ipa Payload/Runner.app/Info.plist \
  | plutil -p - | grep CFBundleShortVersionString

# 区域铁证必须 = com.zaine.app.cn
unzip -p <你的ipa>.ipa Payload/Runner.app/Info.plist \
  | plutil -p - | grep CFBundleIdentifier

# 相机权限文案已注入（扫码功能需要）
unzip -p <你的ipa>.ipa Payload/Runner.app/Info.plist \
  | plutil -p - | grep NSCameraUsageDescription
```

## 五、真机验收 6 步

| # | 操作 | 期望结果 | 对应修复 |
|---|---|---|---|
| 1 | 登录主账号 | **不再**弹「守护关系已建立」卡死弹窗 | 截图2 |
| 2 | 「我的守护码」连开两次 | 两次码与二维码完全一致（静态可复用） | 截图4 |
| 3 | 「输入守护码」页 | 顶部有「扫描对方的守护码」按钮；扫码后自动回填并绑定成功 | P2 新功能 |
| 4 | 看「输入守护码」页说明文案 | 已无「守护卡卡片 / 发卡人」残留 | 截图3 |
| 5 | A 录入 B 的码 | A 列表出现 B；B 列表也出现 A（两条独立记录） | 截图5 |
| 6 | 若仪式弹窗极端竞态下仍出现 | 点空白 / 右上角 X / 等 8 秒，任一方式都能关掉 | 加固兜底 |

第 3 步扫码具体走法：B 打开「我的守护码」出示二维码 → A 进「输入守护码」→ 点「扫描对方的守护码」→ 允许相机权限 → 对准 B 的二维码 → 自动回填并完成绑定。

## 六、状态
- [x] 后端部署 —— **已确认上线，无需操作**（证据见第二节）
- [x] `flutter gen-l10n` —— 已跑并验证新文案生效
- [ ] `flutter pub get`（你本机跑）
- [ ] 出 177 包：`ZAI_VERSION_NAME=1.97.7 ZAI_BUILD_NUMBER=177 ZAI_REGION=cn bash build_ipa.sh`
- [ ] 出包后跑第四节 3 条自检
- [ ] 真机验收第五节 6 步
