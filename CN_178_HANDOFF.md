# CN 178 出包交接单（在呢+ 中国合规版 · 登录+绑定守护码优化）

> 基于 177 包。本轮落实 4 项已拍板改动，代码已改完并通过 `flutter analyze`（0 error / 0 warning）。
> 构建需在你 Mac 上跑（沙箱 `flutter pub get` 受限）。

## 一、本轮改了什么（已全部落地）

### ① 国内版仅留 +86（onboarding_page.dart）
- 用 `kIsChinaBuild` 门禁：CN 时 `countries` 锁 `['CN']`，selector 改为 `PHONE_INPUT_WITH_FLAG`（显示 🇨🇳+86、不可展开下拉），并隐藏 ▼ 箭头。海外版完全不变。

### ② 不加微信登录
- 未改动。

### ③ 登录页绑定守护码入口（onboarding_page.dart）
- CN 登录页手机号下方新增「朋友发你守护码了？点此绑定 →」卡片，**跳转 `RedeemCardPage`**（自带 PIPL 单独同意弹窗），不复活旧"静默自动绑定"路径，也不会触发 177 修的欢迎仪式卡死。

### ④ 绑定支持 输 / 相机扫 / 相册选取（scan_guardian_code_page.dart + Info.plist + privacy.html）
- 扫码页新增悬浮按钮「从相册选取」：`ImagePicker` 选图 → `controller.analyzeImage()` 识别二维码；识别不到则 toast 提示。
- `image_picker` 本就是依赖（pubspec:38），无需加包。
- `Info.plist` 扩写 `NSPhotoLibraryUsageDescription`（"选择联系人头像" → "选择联系人头像，或从截图中识别好友发来的守护码二维码"）。
- **隐私政策补权限段**（`zaine-backend/static/privacy.html`「2.1 设备权限调用说明」：相机 + 相册用途披露，含"不上传整张照片"口径）—— 兼补 177 相机权限未披露的合规缺口。

### i18n
- `app_zh_CN.arb` 新增 `s1180`（"朋友发你守护码了？点此绑定"），已 `flutter gen-l10n` 生成；其余语种回退模板值。

---

## 二、后端部署（隐私政策改了，需重新上线）

代码已直接改在后端 `static/privacy.html`（即 zaine.love 实际服务版）。**在你 Mac 上跑：**

```bash
cd /Users/meixulin/WorkBuddy/20260421164027/zaine-backend
bash deploy.sh
```

> 若你另有一份 `landing-page/` 源码副本，请先把它同步到 `static/privacy.html` 再 deploy（本 checkout 无 landing-page 副本，已直接改 static）。
> 部署完验证：`curl -s https://zaine.love/privacy.html | grep -c "设备权限调用说明"` 期望 ≥1。

---

## 三、出 178 包（在你 Mac 上）

```bash
# 1) 进工程目录
cd /Users/meixulin/Desktop/zaine-app/zaine_app

# 2) 拉依赖（image_picker 等已声明，这里确保本地同步）
flutter pub get

# 3) 出 178 包（⚠️ ZAI_VERSION_NAME 必带，否则回退 1.97.0 被 409 拒）
ZAI_VERSION_NAME=1.97.7 ZAI_BUILD_NUMBER=178 ZAI_REGION=cn bash build_ipa.sh
```

CocoaPods 兜底（仅第 3 步报原生插件错时跑）：
```bash
cd /Users/meixulin/Desktop/zaine-app/zaine_app/ios
pod install --repo-update
cd /Users/meixulin/Desktop/zaine-app/zaine_app
```

---

## 四、出包后自检

```bash
unzip -p <你的ipa>.ipa Payload/Runner.app/Info.plist \
  | plutil -p - | grep -E "CFBundleShortVersionString|CFBundleIdentifier|NSPhotoLibraryUsageDescription|NSCameraUsageDescription"
```
期望：
- `CFBundleShortVersionString` = `1.97.7`
- `CFBundleIdentifier` = `com.zaine.app.cn`
- `NSPhotoLibraryUsageDescription` 含「守护码二维码」
- `NSCameraUsageDescription` 含「守护码」

---

## 五、真机验收（你上手机测）

| # | 操作 | 期望 |
|---|---|---|
| 1 | 登录页手机号区 | 仅显示 🇨🇳 +86，无国家下拉（海外版仍有下拉） |
| 2 | 登录页手机号下方 | 出现「朋友发你守护码了？点此绑定 →」卡片 |
| 3 | 点该卡片 | 跳到输入守护码页，走"单独同意"弹窗后绑定成功 |
| 4 | 输入守护码页点「扫描对方的守护码」 | 进扫码页，右下角有「从相册选取」悬浮按钮 |
| 5 | 选一张含守护码二维码的截图 | 自动识别并回填绑定（纯编号无码截图则提示手动输入） |
| 6 | 打开 zaine.love/privacy.html | 含「2.1 设备权限调用说明」相机+相册段 |

---

## 六、状态
- [x] 代码改动（onboarding / scan / Info.plist / arb / privacy.html）
- [x] `flutter gen-l10n` 生成 s1180
- [x] `flutter analyze` 0 error / 0 warning
- [ ] 隐私政策 deploy（你跑第二节命令）
- [ ] `flutter pub get` + 出 178 包（你跑第三节）
- [ ] 出包自检（第四节）
- [ ] 真机验收（第五节）
