# 在呢+ iOS IPA 构建指南

## 🚀 超简单三步生成 IPA

### 第一步：打开终端，进入项目目录

```bash
cd ~/Desktop/zaine_project/zaine-app/zaine_app
```

> 💡 **提示**：根据您实际存放项目的位置调整路径

---

### 第二步：运行环境检查（可选但推荐）

```bash
bash check_project.sh
```

这个脚本会检查：
- ✅ Flutter 环境
- ✅ Xcode 安装
- ✅ CocoaPods 安装
- ✅ 项目配置
- ✅ 依赖状态

如果显示 **"✅ 所有检查通过！"**，就可以继续下一步。

---

### 第三步：一键构建 IPA

```bash
bash build_ipa.sh
```

然后**坐等 5-15 分钟**，脚本会自动完成：

1. 清理项目
2. 获取依赖
3. 安装 iOS Pods
4. 构建 iOS Release
5. 归档项目
6. 导出 IPA

---

## 📤 上传到 TestFlight

构建完成后，您会看到这样的输出：

```
========================================
  IPA 构建成功！
========================================
IPA 文件路径:
  /Users/xxx/Desktop/zaine_project/.../build/ios/ipa/在呢+.ipa

下一步操作：
1. 打开 Xcode
2. 菜单栏选择: Window → Organizer
3. 找到最新的 Archive，点击 Distribute App
4. 选择 App Store Connect → Upload
```

### 方法 A：使用 Xcode（推荐）

1. 打开 **Xcode**
2. 菜单栏：`Window` → `Organizer`
3. 找到最新的 Archive（应该是最上面的）
4. 点击 `Distribute App`
5. 选择 `App Store Connect` → `Upload`
6. 等待上传完成

### 方法 B：使用 Transporter（更简单）

1. 在 Mac App Store 下载 **Transporter**
2. 打开 Transporter，登录您的 Apple ID
3. 把生成的 IPA 文件拖到 Transporter
4. 点击 **交付**

---

## ⚠️ 常见问题

### 问题 1："未找到 Flutter"

**解决**：
```bash
# 安装 Flutter（如果还没安装）
brew install flutter

# 或者从官网下载：https://flutter.dev/docs/get-started/install
```

### 问题 2："CocoaPods 未安装"

**解决**：
```bash
sudo gem install cocoapods
```

### 问题 3："签名配置问题"

**解决**：
1. 打开 Xcode
2. 打开项目：`ios/Runner.xcworkspace`
3. 点击左侧 `Runner`
4. 选择 `Signing & Capabilities`
5. 勾选 `Automatically manage signing`
6. 选择您的 Team

### 问题 4：构建失败，提示依赖问题

**解决**：
```bash
cd ios
rm -rf Pods Podfile.lock
pod install --repo-update
cd ..
bash build_ipa.sh
```

### 问题 5："ExportOptions.plist 不存在"

**解决**：
这个文件我已经帮您配置好了，如果丢失可以重新创建：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string>KK27TYK93U</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>stripSwiftSymbols</key>
    <true/>
</dict>
</plist>
```

---

## 📋 完整命令流程

```bash
# 1. 进入项目目录
cd ~/Desktop/zaine_project/zaine-app/zaine_app

# 2. 检查环境（可选）
bash check_project.sh

# 3. 构建 IPA
bash build_ipa.sh

# 4. 等待完成，根据提示上传到 TestFlight
```

---

## 🎯 成功标志

构建成功后会显示：

```
========================================
  IPA 构建成功！
========================================
IPA 文件路径:
  .../build/ios/ipa/在呢+.ipa
文件大小:
  45M

总耗时: 8分32秒
```

---

## 📱 TestFlight 测试

上传成功后：

1. 登录 [App Store Connect](https://appstoreconnect.apple.com)
2. 进入 **我的 App** → **在呢+** → **TestFlight**
3. 等待处理（通常 10-30 分钟）
4. 添加测试人员或创建公开测试链接

---

## 🆘 需要帮助？

如果遇到问题：

1. 先运行 `bash check_project.sh` 查看具体问题
2. 根据错误提示修复
3. 重新运行 `bash build_ipa.sh`

或者把终端输出的错误信息发给我，我帮您分析！

---

**祝您构建顺利！🎉**
