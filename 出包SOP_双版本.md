# 在呢+ 双版本出包 SOP（global 海外 / cn 中国合规）

> 最后更新：2026-08-06
> 适用范围：单代码库 Flutter + 原生 Watch（Swift），通过 `ZAI_REGION` 闸门切换两版。

---

## 0. 一句话约定

- 单代码库，`ZAI_REGION` 闸门切换 global / cn，**同一份 Dart + Watch 代码**两版共用。
- **global（海外全功能版）** `com.zaine.app`：保留自动通知守护人 / 安全中心 / Watch 自动打卡。
- **cn（中国合规版）** `com.zaine.app.cn`：关闭自动外发、安全中心入口用 `isChinaRegion` 闸门屏蔽（非物理删文件）。
- 主屏显示名代码已是 `在呢+`（`ios/Runner/Info.plist` 的 `CFBundleDisplayName` / `CFBundleName`），改名只动 ASC 元数据，无需改代码。

---

## 1. 构建矩阵

| 项目 | 海外 global | 中国合规 cn |
|---|---|---|
| 命令 | `ZAI_BUILD_NUMBER=<n> bash build_ipa.sh` | `ZAI_REGION=cn ZAI_BUILD_NUMBER=<n> bash build_ipa.sh` |
| Bundle ID | `com.zaine.app` | `com.zaine.app.cn`（脚本 sed 改写 pbxproj，trap 自动还原）|
| Dart 区域开关 | 默认 global | `--dart-define=ZAI_REGION=cn` → `AppConfig.isChinaRegion=true` |
| Info.plist 文案 | 原文 | 位置/健康权限描述去除"守护/报平安/始终"等监控暗示（脚本 sed）|
| 自动通知第三方 | 保留 | 关闭（手动确认才外发）|
| 安全中心入口 | 保留 | `isChinaRegion` 闸门屏蔽 |
| 构建号规则 | 不与 cn 复用同一号（见 §4）| 不与 global 复用同一号 |

> 注意：Watch 原生代码在 cn 构建时**不**改写逻辑（只改 bundle id 前缀），所以 cn 包同样包含最新 Watch 修复——前提是出包时仓库代码已合入。

---

## 2. ⚠️ 关键补丁依赖（最重要）

- **#326 Watch「第二天卡死」修复**（2026-08-06，build 152 阶段）：修复 Watch `hasCheckedInToday` 跨天不复位、无回前台/跨午夜监听导致"第二天卡住无法再签到"。
  - 改动文件：`ios/ZaineWatch Watch App/WatchConnectivityManager.swift`、`lib/services/platform/health_service.dart`、`ios/Runner/AppDelegate.swift`。
- **🔴 CN 版下次出包必须用 build ≥ 152**，否则 cn 包不含 #326，CN 上架后手表会重演"第二天卡住无法再签到"。
  - 说明：CN 版 Watch 自动打卡虽被 `isChinaRegion` 闸口禁用，但"手动签到后第二天卡住"的 UI bug 与闸口无关，照样存在。
- global 版 152 已含此补丁，线上以 152 为准。

---

## 3. 上传流程

- `build_ipa.sh` **本身不上传**（Step 5 仅打印提示文字）。真正的上传由用户在 Mac 用 **Transporter** 或 **Xcode Organizer** 手动完成。
- 上传归宿由**包内 bundle id** 决定：
  - global 包（com.zaine.app）→ 海外版 App 记录
  - cn 包（com.zaine.app.cn）→ 合规版 App 记录
- 两者不会串台；但 build number 建议两版各自独立递增，避免同一号码在两边各占一次造成混淆（见 §4）。

---

## 4. 历史教训（151 误传事件）

- 曾误把**不带 cn** 的 151 传到海外账号（成了 `com.zaine.app` 下的 global 151），后又用 `ZAI_REGION=cn` 重打 151 传到合规版。两个 151 bundle id 不同、内容各自正确，**未混乱**，但同一 build number 151 在两边各占一次，易混淆。
- **建议**：global 与 cn 的 build number 各自独立递增，避免复用同一号码跨版本。

---

## 5. 海外版 152 提交正式审核 · 元数据核对清单

> 海外版 = global，保留全部功能（自动通知、位置共享、报平安等），这些在海外是合法核心卖点。**不要把 CN 版"去敏感词"的清理逻辑套到海外版**，否则会削弱卖点。

### 📛 海外版改名实际只改一处
- 代码侧（设备主屏图标名）：`Info.plist` 的 `CFBundleDisplayName`/`CFBundleName` **本就是 `在呢+`**，全项目 Grep"打卡日记" 0 命中——无需改代码、无需重新出包。
- App Store 商店展示名：在 ASC 元数据里改即可。
- **现成文案全套见 `docs/海外版AppStore文案_v1.97.1.md`**（推广文本 / 描述 / 新增内容 / 审核备注 / 关键词 直接复制粘贴）。

### 🆕 改名必须建新版本（ASC 硬规则）
- ASC 不允许复用已分发的版本号（`CFBundleShortVersionString`），已分发的 `1.97.0` 不论 build 怎么换都不能再建同名版本。
- **正确做法**：用下一个版本号挂本轮 build。152 build 的 `CFBundleShortVersionString=1.97.0`，新建 **`1.97.1`** 把它选入；不用重新出包。
- 操作顺序：取消旧弹窗 → `+ 版本` → 输入 `1.97.1` → 在"可本地化的信息"里把名称改成 `在呢+` → "构建版本"区选入 `152 (1.97.0)` → 按文案文档填其余元数据 → 提交。

### 🔴 必须改
1. **App 名称（Name）**：当前若是 `打卡日记·在呢` / `打卡日记在呢` → 改为 `在呢+`（去掉"打卡日记"）。仅改商店展示名；主屏图标名代码已是 `在呢+`，无需重新出包。

### 🟡 建议核对（按现状决定是否改）
2. **副标题(Subtitle)**：检查是否含"打卡日记"，有则去掉；通常"独居安全守护"之类不含。
3. **推广文本(Promotional Text)**：海外版有真实位置共享/自动守护，可保留"位置共享"表述（不同于 CN 要避讳）。若当前写的是"打卡日记"相关则改。建议突出"自动向守护人报平安 · 手表/手机同步签到"。
4. **关键词(Keywords)**：**建议保留"打卡日记"作为搜索词**以继承历史搜索权重（只改名称，不动关键词）——需与用户确认是否接受。
5. **描述(Description)**：保留自动通知守护人、位置共享、报平安、Watch 同步等完整功能描述（核心卖点）。核对与 152 实际功能一致（含 Watch 同步修复）。
6. **审核备注(Notes)**：可写明"自动向守护人发送安全通知 / 跌倒求助"等，帮助审核理解；可附 152 修复点。无需像 CN 那样避讳自动外发。
7. **截图/预览**：确认截图内 App 名为 `在呢+`，无"打卡日记"字样；UI 已显示 `在呢+`，一般无需改。
8. **隐私政策 URL / 联系邮箱**：`zaine.love/privacy.html` + `meis1983@163.com`（已统一，核对无误即可）。

### 🟢 不用动 / 与 CN 版相反
- 勿套用 CN 版"守护/报平安/位置共享/自动通知"去敏感词清理——海外版这些是合法卖点。
- 152 是 global 包，安装后功能完整（安全中心、自动通知、Watch 自动打卡均在），符合海外版定位。

### 📋 提交动作
- ASC 选 152 build 入版本 → 填好上述元数据 → 提交审核。
- 先在 TestFlight 做完真机验证（重点：连续多天手表自动同步手机天数、不再卡旧数据、能再次签到；心率感应自动签到仍触发）再提交。

### 📋 改名 / 改类别 / 改隐私政策实操（已发布版本锁定）
- 这些字段在 ASC 中**已发布版本锁定**，改任意一项必须**建新版本**。
- 新版本号规则：必须 **> 当前已分发的版本号**（已用过的不能复用，哪怕 build 不同——版本号是 `CFBundleShortVersionString`，与 build number 是两个维度）。
- 推荐选 **1.97.1** 挂 152 build：152 build 的 CFBundleShortVersionString=1.97.0，可挂到 1.97.1（bug fix 级，命名自然）。如要发更大改动再升 1.98.0（需 `ZAI_VERSION_NAME=1.98.0` 重新出包）。
- 步骤：ASC → 你的 App → 点 `+ 版本`（或新建版本）→ 输入新版本号 → 在新版本页改名称为 `在呢+` → 把 152 build 选入 → 填好其余元数据 → 提交审核。

---

## 6. 出包命令速查

```bash
# 海外全功能版（不带 cn）
ZAI_BUILD_NUMBER=152 bash /Users/meixulin/Desktop/zaine-app/zaine_app/build_ipa.sh

# 中国合规版（带 cn，构建号须 ≥152 才能带上 #326 补丁）
ZAI_REGION=cn ZAI_BUILD_NUMBER=153 bash /Users/meixulin/Desktop/zaine-app/zaine_app/build_ipa.sh
```
