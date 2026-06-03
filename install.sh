#!/bin/bash
# 在呢App - 一键安装脚本（Mac专用）
# 运行方式：
#   chmod +x install.sh
#   ./install.sh

set -e

echo "🚀 在呢 App 安装向导"
echo "======================================="

# 1. 检查Flutter是否安装
if command -v flutter &> /dev/null; then
    echo "✅ Flutter 已安装: $(flutter --version)"
else
    echo "📦 Flutter 未安装，正在下载..."
    cd ~
    
    # 如果没有下载过，从头下载
    if [ ! -d "flutter" ]; then
        echo "正在从官方下载 Flutter SDK（约1GB）..."
        curl -LO https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_3.24.0-stable.zip
        unzip -q flutter_macos_3.24.0-stable.zip
        rm flutter_macos_3.24.0-stable.zip
    fi
    
    # 添加到PATH
    export PATH="$HOME/flutter/bin:$PATH"
    echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.zshrc
    echo "✅ Flutter 安装完成"
fi

# 2. 进入项目目录
cd /Users/meixulin/WorkBuddy/20260407202444/zaine_app

# 3. 获取依赖
echo "📦 安装项目依赖..."
flutter pub get

# 4. 检查iOS模拟器
echo "📱 检查可用模拟器..."
xcrun simctl list devices available | head -20

echo ""
echo "✅ 安装完成！运行方式："
echo "   cd /Users/meixulin/WorkBuddy/20260407202444/zaine_app"
echo "   flutter run"
echo ""
echo "📌 或者用Xcode打开："
echo "   open ios/Runner.xcworkspace"
