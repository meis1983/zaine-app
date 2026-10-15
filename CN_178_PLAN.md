# CN 178 改前方案（国内版「登录 + 绑定守护码」体验优化）

> 状态：**方案文档，未改任何代码**。用户已就 4 项逐条拍板（见各节结论）。
> 基线：177 包（1.97.7 / build 177 / com.zaine.app.cn）已出，本轮在其上叠加。
> 术语对齐：用户说的"安全码" = 国内版「守护码」（绑定朋友关系用）。

## 〇、范围与已拍板结论

| # | 议题 | 结论 |
|---|---|---|
| ① | 国内版国家代码 | ✅ 只留 +86，隐藏国家选择下拉 |
| ② | 微信登录 | ❌ 本轮不加（避免微信开放平台配置 + 强制 Sign in with Apple + 隐私/条款大改） |
| ③ | 登录页绑定守护码入口 | ✅ 在登录/onboarding 露出「朋友发你守护码？点此绑定」 |
| ④ | 绑定输入方式 | ✅ 输 / 相机扫 / 相册选取 三选一；隐私政策补权限披露 |

---

## 一、改动文件清单

### 1. Point ① 国家代码锁 +86
- **文件**：`lib/pages/onboarding_page.dart`
- **现状**：用 `intl_phone_number_input`，默认 `PhoneNumber(isoCode:'CN', dialCode:'+86')`（73 行）；国家列表硬编码 `countries:`（259–264 行，含 CN/US/JP…）；下拉箭头 ▼ 叠加在区号右侧（229–280 行）。
- **改动（用 `kIsChinaBuild` 门禁，海外版不变）**：
  - CN 时 `countries` 改为 `const ['CN']`；
  - 隐藏 229–280 的下拉箭头 ▼（`if (!kIsChinaBuild) ...` 包裹或 `Opacity`/`IgnorePointer` 控制）；
  - 让 selector 不可展开为对话框（实现时选最干净的一种：CN 下改用不可交互的「+86 国旗」展示，或保留 widget 但禁用 tap）；
  - 保留登录时剥离 `+86` 前缀逻辑（1207–1209 行，与后端 `normalize_phone` 对齐）。

### 2. Point ③ 登录页绑定守护码入口
- **文件**：`lib/pages/onboarding_page.dart`（登录/引导页；即用户说的"登录的页"）
- **现状**：绑定入口现仅在「我的」（`profile_page.dart` 730、1824 跳 `RedeemCardPage`）；CN 在 onboarding 被故意隐藏（331 行注释），但底层 `pending_card_code` 预存 + 自动绑定机制仍在（519–548、1233–1349）。
- **改动（CN 仅显）**：
  - 在手机号输入区下方、登录按钮上方加一行可点文案「朋友发你守护码了？点此绑定 →」，`Navigator.push(const RedeemCardPage())`；
  - **必须走 `RedeemCardPage`**（自带 PIPL 单独同意弹窗 `_showConsentDialog`），不可裸输入框直接提交绑定；
  - 不触发 177 修的全局欢迎仪式（CN 已被 `kIsChinaBuild return` 挡掉），不会卡死。
- **假设**：你指的"登录页"= onboarding 引导+登录页。若另有独立登录页，请指给我，我补到那里。

### 3. Point ④ 相册选取
- **文件 A**：`lib/pages/scan_guardian_code_page.dart`
  - 加「从相册选取」按钮 → `ImagePicker().pickImage(source: ImageSource.gallery)` → `controller.analyzeImage(picked.path)` 解析二维码；
  - 解析到则回填（同相机扫码成功逻辑）；解析不到则 toast「未能识别守护码，请手动输入或重新选择」；
  - `image_picker` **已是依赖**（pubspec.yaml:38），无需加包；`mobile_scanner` 7.x `analyzeImage` 支持本地图。
- **文件 B**：`ios/Runner/Info.plist`（63–64 行）
  - 扩写 `NSPhotoLibraryUsageDescription`：从「在呢需要访问相册以选择联系人头像。」→「在呢需要访问相册以选择联系人头像，或识别好友发来的守护码二维码。」（用途声明须准确覆盖两种调用）。
- **文件 C**：`lib/l10n/app_zh_CN.arb` + 其余 3 个 arb（海外可复用同 key）
  - 新增 key：相册选取按钮文案、未能识别提示。

### 4. 隐私政策（Point ④ 触发，兼补 177 相机权限缺口）
- **文件**：`zaine-backend/static/privacy.html`（真身；前端 `landing-page/` 此 checkout 无副本，以后端为准）
- **现状**：`Info.plist` 已声明 `NSPhotoLibraryUsageDescription`（63–64 行），177 又加了相机权限，但隐私政策「二、信息收集」**无任何相机/相册权限披露**（仅 36 行提"头像"作为收集资料）。属既有合规缺口。
- **改动**：在「二、信息收集」`<ol>` 之后新增「设备权限调用说明」小节（diff 见第二节）。
- **上线**：改完 `zaine.love` 实际服务版须 `cp` 进后端 `static/` 并重跑 `deploy.sh`（隐私页走后端 static，非前端）。

---

## 二、隐私政策 diff（草案）

在 `privacy.html` 第 41 行（`</ol>` 之后、`<h2>三、信息使用</h2>` 之前）插入：

```html
<h3>2.1 设备权限调用说明</h3>
<p>为实现上述功能，App 会在您<strong>主动操作</strong>时申请并使用以下设备权限，均不会在后台静默调用：</p>
<ul>
  <li>📷 <strong>相机：</strong>仅在您主动扫描好友发来的守护码二维码以建立守护关系时调用，用于识别二维码中的守护码。</li>
  <li>🖼️ <strong>相册（照片）：</strong>仅在您主动从相册中选择截图以识别其中的守护码二维码，或选择联系人头像时调用。App 仅读取您选定的图片以提取守护码编号 / 二维码，<strong>不会将整张照片上传至服务器</strong>。</li>
</ul>
```

> 说明：相机权限文案（`NSCameraUsageDescription`，177 新增，用于扫描守护码）与相册权限一并在此披露，覆盖两种用户场景（面对面扫码 / 非面对面截图选图）。

---

## 三、不在本次范围

- ② 微信登录：不做。
- 后端：无需改动（oneway / 新端点已上线，见 177 交接单）。
- 海外版：① 国家选择、③ 绑定入口均 `kIsChinaBuild` 门禁，海外不变。

---

## 四、执行时再给完整命令（待确认后）

- 出 178 包：`ZAI_VERSION_NAME=1.97.7 ZAI_BUILD_NUMBER=178 ZAI_REGION=cn bash build_ipa.sh`（⚠️ 必带 VERSION_NAME）
- 自检：版本 1.97.7 / `CFBundleIdentifier`=com.zaine.app.cn / `NSCameraUsageDescription` + 扩写后 `NSPhotoLibraryUsageDescription` 均存在
- 真机验收：+86 锁定不可改 / 登录页有绑定入口且跳转带同意弹窗 / 相册选截图能识别二维码并绑定 / 隐私政策页含权限披露段

---

## 五、下一步

本文件为方案，**未改动任何代码**。你确认后我落地：
1. `onboarding_page.dart`（①③）
2. `scan_guardian_code_page.dart`（④ 相册）
3. `Info.plist`（④ 扩写相册用途）
4. 4 个 arb 加 key → `flutter gen-l10n`
5. `privacy.html` 加权限段 → cp 后端 static → `deploy.sh`
6. 出 178 包 + 自检 + 验收清单
