#!/bin/bash
# 在呢App 一键回滚脚本
# 用法: ./rollback.sh [版本号]
# 示例: ./rollback.sh v1.0.0

set -e

VERSION=${1:-"v1.0.0"}

echo "========================================"
echo "在呢App 一键回滚工具"
echo "========================================"
echo ""

# 检查当前分支
echo "📍 当前分支: $(git branch --show-current)"
echo "📍 当前版本: $(git describe --tags --always 2>/dev/null || echo '无tag')"
echo ""

# 确认版本存在
if ! git tag | grep -q "^${VERSION}$"; then
    echo "❌ 错误: 版本 ${VERSION} 不存在!"
    echo ""
    echo "可用版本:"
    git tag -l | sort -V
    exit 1
fi

echo "⚠️  即将回滚到: ${VERSION}"
echo ""
read -p "确认回滚? (y/N): " confirm

if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
    echo ""
    echo "🔄 正在回滚..."
    
    # 保存当前改动（如果有）
    git stash push -m "rollback-stash-$(date +%Y%m%d_%H%M)" 2>/dev/null || true
    
    # 强制回滚
    git reset --hard ${VERSION}
    
    # 清理未跟踪文件
    git clean -fd
    
    echo ""
    echo "✅ 回滚完成!"
    echo ""
    echo "当前状态:"
    echo "  版本: $(git describe --tags --always)"
    echo "  Commit: $(git rev-parse --short HEAD)"
    echo ""
    echo "📦 如需重新构建，运行:"
    echo "  flutter clean && flutter pub get && flutter build ios --debug"
else
    echo ""
    echo "❎ 已取消"
fi
