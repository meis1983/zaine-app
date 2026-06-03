#!/bin/bash

# =============================================================================
# 在呢+ 项目环境检查脚本
# 使用方法：bash check_project.sh
# 功能：检查所有依赖和环境是否就绪
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

check_mark="✅"
error_mark="❌"
warning_mark="⚠️"

print_header() {
    echo ""
    echo "========================================"
    echo "  在呢+ 项目环境检查"
    echo "========================================"
    echo ""
}

print_check() {
    echo -e "${BLUE}检查: $1${NC}"
}

print_ok() {
    echo -e "  ${check_mark} $1"
}

print_fail() {
    echo -e "  ${error_mark} ${RED}$1${NC}"
}

print_warn() {
    echo -e "  ${warning_mark} ${YELLOW}$1${NC}"
}

# 检查目录
check_directory() {
    print_check "项目目录"
    if [ -f "pubspec.yaml" ]; then
        print_ok "项目目录正确"
        APP_NAME=$(grep "^name:" pubspec.yaml | head -1 | cut -d' ' -f2)
        APP_VERSION=$(grep "^version:" pubspec.yaml | head -1 | cut -d' ' -f2)
        echo "    应用名称: $APP_NAME"
        echo "    版本号: $APP_VERSION"
        return 0
    else
        print_fail "请在项目根目录运行此脚本"
        return 1
    fi
}

# 检查 Flutter
check_flutter() {
    print_check "Flutter 环境"
    if command -v flutter &> /dev/null; then
        VERSION=$(flutter --version | head -1)
        print_ok "Flutter 已安装"
        echo "    $VERSION"
        
        # 检查 Flutter doctor
        DOCTOR_ISSUES=$(flutter doctor --machine 2>/dev/null | grep -c '"type":"error"' || echo "0")
        if [ "$DOCTOR_ISSUES" -eq "0" ]; then
            print_ok "Flutter doctor 无错误"
        else
            print_warn "Flutter doctor 发现 $DOCTOR_ISSUES 个问题"
            echo "    建议运行: flutter doctor"
        fi
        return 0
    else
        print_fail "Flutter 未安装"
        echo "    请访问 https://flutter.dev/docs/get-started/install"
        return 1
    fi
}

# 检查 Xcode
check_xcode() {
    print_check "Xcode 环境"
    if command -v xcodebuild &> /dev/null; then
        VERSION=$(xcodebuild -version | head -1)
        print_ok "Xcode 已安装"
        echo "    $VERSION"
        
        # 检查 Xcode 命令行工具
        if xcode-select -p &> /dev/null; then
            print_ok "Xcode 命令行工具已配置"
        else
            print_warn "Xcode 命令行工具未配置"
            echo "    请运行: sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
        fi
        return 0
    else
        print_fail "Xcode 未安装"
        echo "    请从 App Store 安装 Xcode"
        return 1
    fi
}

# 检查 CocoaPods
check_cocoapods() {
    print_check "CocoaPods"
    if command -v pod &> /dev/null; then
        VERSION=$(pod --version)
        print_ok "CocoaPods 已安装"
        echo "    版本: $VERSION"
        return 0
    else
        print_fail "CocoaPods 未安装"
        echo "    请运行: sudo gem install cocoapods"
        return 1
    fi
}

# 检查 iOS 项目配置
check_ios_config() {
    print_check "iOS 项目配置"
    
    if [ ! -d "ios" ]; then
        print_fail "iOS 目录不存在"
        return 1
    fi
    
    cd ios
    
    # 检查必要文件
    if [ -f "Podfile" ]; then
        print_ok "Podfile 存在"
    else
        print_warn "Podfile 不存在，需要生成"
    fi
    
    if [ -f "ExportOptions.plist" ]; then
        print_ok "ExportOptions.plist 存在"
    else
        print_warn "ExportOptions.plist 不存在"
    fi
    
    if [ -f "Runner.xcworkspace" ]; then
        print_ok "Xcode Workspace 已创建"
    else
        print_warn "Xcode Workspace 不存在，需要运行 pod install"
    fi
    
    # 检查 Signing 配置
    if grep -q "DEVELOPMENT_TEAM" "Runner.xcodeproj/project.pbxproj" 2>/dev/null; then
        TEAM_ID=$(grep "DEVELOPMENT_TEAM" "Runner.xcodeproj/project.pbxproj" | head -1 | sed 's/.*= \(.*\);/\1/' | tr -d ' ')
        print_ok "Development Team 已配置"
        echo "    Team ID: $TEAM_ID"
    else
        print_warn "Development Team 未配置"
        echo "    请在 Xcode 中配置 Signing"
    fi
    
    cd ..
    return 0
}

# 检查依赖
check_dependencies() {
    print_check "项目依赖"
    
    if [ -d ".dart_tool" ]; then
        print_ok "Flutter 依赖已获取"
    else
        print_warn "Flutter 依赖未获取"
        echo "    请运行: flutter pub get"
    fi
    
    if [ -d "ios/Pods" ]; then
        print_ok "iOS Pods 已安装"
    else
        print_warn "iOS Pods 未安装"
        echo "    请运行: cd ios && pod install"
    fi
}

# 检查关键文件
check_key_files() {
    print_check "关键文件"
    
    # 检查图标
    if [ -f "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png" ]; then
        print_ok "App 图标已配置"
    else
        print_warn "App 图标未配置"
    fi
    
    # 检查启动图
    if [ -f "ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md" ]; then
        print_ok "启动图已配置"
    else
        print_warn "启动图未配置"
    fi
    
    # 检查 Info.plist
    if [ -f "ios/Runner/Info.plist" ]; then
        print_ok "Info.plist 存在"
    else
        print_fail "Info.plist 不存在"
    fi
}

# 显示总结
show_summary() {
    echo ""
    echo "========================================"
    echo "  检查完成"
    echo "========================================"
    echo ""
    
    if [ $ERRORS -eq 0 ]; then
        echo -e "${GREEN}✅ 所有检查通过！可以开始构建 IPA${NC}"
        echo ""
        echo "下一步："
        echo "  运行: bash build_ipa.sh"
    else
        echo -e "${RED}❌ 发现 $ERRORS 个错误，请修复后再试${NC}"
        echo ""
        echo "常见问题解决："
        echo "  1. Flutter 未安装: https://flutter.dev/docs/get-started/install"
        echo "  2. Xcode 未安装: 从 App Store 安装"
        echo "  3. CocoaPods: sudo gem install cocoapods"
        echo "  4. 依赖问题: flutter pub get && cd ios && pod install"
    fi
    
    if [ $WARNS -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}⚠️ 有 $WARNS 个警告，建议查看但不影响构建${NC}"
    fi
    
    echo ""
}

# 主流程
main() {
    print_header
    
    ERRORS=0
    WARNS=0
    
    check_directory || ((ERRORS++))
    check_flutter || ((ERRORS++))
    check_xcode || ((ERRORS++))
    check_cocoapods || ((ERRORS++))
    check_ios_config || ((ERRORS++))
    check_dependencies || ((WARNS++))
    check_key_files || ((WARNS++))
    
    show_summary
}

main
