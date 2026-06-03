#!/bin/bash

# =============================================================================
# 在呢+ iOS IPA 自动化构建脚本 - 优化版
# 使用方法：bash build_ipa.sh [fast|clean]
#   - 无参数: 完整构建（推荐首次使用）
#   - fast: 快速构建（跳过清理，适合小修改后）
#   - clean: 仅清理项目
# =============================================================================

# 设置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 打印带颜色的信息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_step() {
    echo -e "${CYAN}[STEP $1/7]${NC} $2"
}

# 检查是否在正确的目录
check_directory() {
    if [ ! -f "pubspec.yaml" ]; then
        print_error "请在项目根目录运行此脚本"
        print_info "正确路径: ~/Desktop/zaine-app/zaine_app"
        print_info "请执行: cd ~/Desktop/zaine-app/zaine_app"
        exit 1
    fi
    
    # 显示项目信息
    APP_NAME=$(grep "^name:" pubspec.yaml | head -1 | cut -d' ' -f2)
    APP_VERSION=$(grep "^version:" pubspec.yaml | head -1 | cut -d' ' -f2)
    print_success "项目: $APP_NAME v$APP_VERSION"
}

# 检查 Flutter 环境
check_flutter() {
    print_step "1" "检查 Flutter 环境"
    if ! command -v flutter &> /dev/null; then
        print_error "未找到 Flutter"
        print_info "请访问 https://flutter.dev/docs/get-started/install 安装"
        exit 1
    fi
    
    FLUTTER_VERSION=$(flutter --version | head -1)
    print_success "$FLUTTER_VERSION"
}

# 检查 Xcode
check_xcode() {
    print_step "2" "检查 Xcode"
    if ! command -v xcodebuild &> /dev/null; then
        print_error "未找到 Xcode"
        print_info "请从 App Store 安装 Xcode"
        exit 1
    fi
    
    XCODE_VERSION=$(xcodebuild -version | head -1)
    print_success "$XCODE_VERSION"
}

# 清理项目
clean_project() {
    print_step "3" "清理项目"
    flutter clean > /dev/null 2>&1
    print_success "清理完成"
}

# 获取依赖
get_dependencies() {
    print_step "4" "获取 Flutter 依赖"
    flutter pub get > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        print_error "获取依赖失败"
        exit 1
    fi
    print_success "依赖获取完成"
}

# 安装 iOS 依赖
install_ios_deps() {
    print_step "5" "安装 iOS 依赖 (CocoaPods)"
    cd ios
    
    # 检查 Podfile 是否存在
    if [ ! -f "Podfile" ]; then
        print_warning "未找到 Podfile，生成中..."
        flutter pub get > /dev/null 2>&1
    fi
    
    # 安装 pods
    pod install --repo-update > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        print_warning "Pod install 失败，尝试清理后重新安装..."
        rm -rf Pods Podfile.lock
        pod install --repo-update > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            print_error "CocoaPods 安装失败"
            cd ..
            exit 1
        fi
    fi
    
    cd ..
    print_success "iOS 依赖安装完成"
}

# 构建 iOS Release
build_ios() {
    print_step "6" "构建 iOS Release"
    print_info "这可能需要 3-10 分钟，请耐心等待..."
    
    flutter build ios --release > /tmp/flutter_build.log 2>&1
    if [ $? -ne 0 ]; then
        print_error "iOS 构建失败"
        print_info "错误日志:"
        tail -20 /tmp/flutter_build.log
        print_info ""
        print_info "常见原因："
        print_info "1. 签名配置问题 - 请在 Xcode 中检查 Signing"
        print_info "2. 依赖问题 - 尝试: cd ios && pod update"
        exit 1
    fi
    print_success "iOS 构建完成"
}

# 归档（Archive）
archive_project() {
    print_step "7" "归档项目"
    
    cd ios
    
    # 使用 xcodebuild 归档
    xcodebuild archive \
        -workspace Runner.xcworkspace \
        -scheme Runner \
        -configuration Release \
        -archivePath build/Runner.xcarchive \
        -destination 'generic/platform=iOS' > /tmp/xcode_archive.log 2>&1
    
    if [ $? -ne 0 ]; then
        print_error "归档失败"
        print_info "错误日志:"
        tail -20 /tmp/xcode_archive.log
        cd ..
        exit 1
    fi
    
    cd ..
    print_success "归档完成"
}

# 导出 IPA
export_ipa() {
    print_info "导出 IPA..."
    
    cd ios
    
    # 检查 ExportOptions.plist 是否存在
    if [ ! -f "ExportOptions.plist" ]; then
        print_error "未找到 ExportOptions.plist"
        cd ..
        exit 1
    fi
    
    # 创建输出目录
    mkdir -p ../build/ios/ipa
    
    # 导出 IPA
    xcodebuild -exportArchive \
        -archivePath build/Runner.xcarchive \
        -exportOptionsPlist ExportOptions.plist \
        -exportPath ../build/ios/ipa > /tmp/xcode_export.log 2>&1
    
    if [ $? -ne 0 ]; then
        print_error "导出 IPA 失败"
        print_info "错误日志:"
        tail -20 /tmp/xcode_export.log
        cd ..
        exit 1
    fi
    
    cd ..
    print_success "IPA 导出完成"
}

# 显示结果
show_result() {
    echo ""
    echo "========================================"
    print_success "🎉 IPA 构建成功！"
    echo "========================================"
    
    # 查找生成的 IPA 文件
    IPA_PATH=$(find build/ios/ipa -name "*.ipa" 2>/dev/null | head -1)
    
    if [ -f "$IPA_PATH" ]; then
        IPA_FULL_PATH="$PWD/$IPA_PATH"
        IPA_SIZE=$(ls -lh "$IPA_PATH" | awk '{print $5}')
        
        print_info "📁 IPA 文件路径:"
        echo "   $IPA_FULL_PATH"
        print_info "📦 文件大小: $IPA_SIZE"
        echo ""
        print_success "下一步操作（选择一种）："
        echo ""
        echo -e "${CYAN}方法1 - Xcode Organizer（推荐）:${NC}"
        echo "   1. 打开 Xcode"
        echo "   2. 菜单栏: Window → Organizer"
        echo "   3. 找到最新的 Archive，点击 Distribute App"
        echo "   4. 选择 App Store Connect → Upload"
        echo ""
        echo -e "${CYAN}方法2 - Transporter App:${NC}"
        echo "   1. 从 App Store 安装 Transporter"
        echo "   2. 拖拽 IPA 文件到 Transporter"
        echo "   3. 点击交付"
        echo ""
    else
        print_warning "未找到 IPA 文件，请检查 build/ios/ipa 目录"
    fi
}

# 快速构建模式（跳过清理）
fast_build() {
    echo ""
    echo "========================================"
    echo "  在呢+ iOS IPA 快速构建模式"
    echo "========================================"
    echo ""
    
    START_TIME=$(date +%s)
    
    check_directory
    check_flutter
    check_xcode
    # 跳过 clean_project
    get_dependencies
    install_ios_deps
    build_ios
    archive_project
    export_ipa
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    MINUTES=$((DURATION / 60))
    SECONDS=$((DURATION % 60))
    
    show_result
    
    echo ""
    print_success "⏱️  总耗时: ${MINUTES}分${SECONDS}秒"
    echo ""
}

# 完整构建模式
full_build() {
    echo ""
    echo "========================================"
    echo "  在呢+ iOS IPA 完整构建"
    echo "========================================"
    echo ""
    
    START_TIME=$(date +%s)
    
    check_directory
    check_flutter
    check_xcode
    clean_project
    get_dependencies
    install_ios_deps
    build_ios
    archive_project
    export_ipa
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    MINUTES=$((DURATION / 60))
    SECONDS=$((DURATION % 60))
    
    show_result
    
    echo ""
    print_success "⏱️  总耗时: ${MINUTES}分${SECONDS}秒"
    echo ""
}

# 显示帮助
show_help() {
    echo ""
    echo "在呢+ iOS IPA 构建脚本"
    echo ""
    echo "用法: bash build_ipa.sh [选项]"
    echo ""
    echo "选项:"
    echo "   (无参数)  完整构建（清理+构建，推荐首次使用）"
    echo "   fast      快速构建（跳过清理，适合小修改后）"
    echo "   clean     仅清理项目"
    echo "   help      显示帮助"
    echo ""
    echo "示例:"
    echo "   bash build_ipa.sh           # 完整构建"
    echo "   bash build_ipa.sh fast      # 快速构建"
    echo ""
}

# 主流程
main() {
    case "${1:-}" in
        fast)
            fast_build
            ;;
        clean)
            check_directory
            clean_project
            ;;
        help|--help|-h)
            show_help
            ;;
        "")
            full_build
            ;;
        *)
            print_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
}

# 运行主流程
main "$@"
