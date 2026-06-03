#!/bin/bash

# iOS 开发环境自动配置脚本

echo "🚀 开始配置 iOS 开发环境..."

# 1. 检查 Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ 错误：未找到 Xcode，请先安装 Xcode"
    exit 1
fi

echo "✅ Xcode 已安装"

# 2. 检查 Apple ID 登录
echo ""
echo "📱 检查 Apple ID 登录状态..."
ACCOUNTS=$(xcrun altool --list-providers 2>&1)
if [ $? -ne 0 ]; then
    echo "⚠️  未检测到 Apple ID 登录"
    echo ""
    echo "请手动完成以下步骤："
    echo "1. 打开 Xcode"
    echo "2. 点击菜单：Xcode → Settings（或按 Cmd + ,）"
    echo "3. 点击 Accounts 标签"
    echo "4. 点击 + 号，选择 Apple ID"
    echo "5. 输入你的 Apple ID 和密码"
    echo ""
    echo "完成后按回车继续..."
    read
fi

# 3. 打开项目
echo ""
echo "🔨 打开 Xcode 项目..."
open ios/Runner.xcworkspace

echo ""
echo "📋 请在 Xcode 中完成以下步骤："
echo ""
echo "1. 在左侧点击 'Runner'（蓝色图标）"
echo "2. 点击中间的 'Signing & Capabilities'"
echo "3. 在 'Team' 下拉框选择你的 Apple ID"
echo "4. 如果看到警告，点击 'Fix Issue'"
echo "5. 用数据线连接 iPhone"
echo "6. 在顶部选择你的 iPhone 设备"
echo "7. 点击运行按钮（▶️）"
echo ""
echo "首次运行时，iPhone 会提示'不信任的开发者'"
echo "请去 iPhone 设置 → 通用 → VPN与设备管理 → 信任你的 Apple ID"
echo ""
