#!/bin/bash
# 在呢+ 出包脚本（v1.97.3 + build 179）
# 179 关键修复：① 健康卡授权态粘性化（根除「守护中↔尚未检测」跳动）
#             ② 签到状态覆盖 bug 修复（双向守护者不再被恒 false 覆盖为「未签到」）
#             ③ 头像/档案/HealthKit 缓存彻底隔离（根治多账号切换串号）
# 双击本文件会用 macOS 系统 Terminal 运行，自动注入版本号并调用 build_ipa.sh
# 注意：本脚本写死 flutter 绝对路径，不依赖 ~/.zshrc，解决之前出包失败问题

export PATH="/Users/meixulin/flutter/bin:$PATH"
export PUB_HOSTED_URL="https://pub.flutter-io.cn"
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"

cd /Users/meixulin/Desktop/zaine-app/zaine_app || {
  echo "❌ 项目目录不存在"
  read -p "按回车退出"
  exit 1
}

echo "========================================="
echo "  在呢+ 出包 v1.97.3 (build 179)"
echo "  179 修：健康卡粘性 + 签到覆盖 + 头像隔离"
echo "  PATH 已注入: $(command -v flutter)"
echo "========================================="
echo ""

ZAI_VERSION_NAME=1.97.3 ZAI_BUILD_NUMBER=179 bash build_ipa.sh

echo ""
echo "========================================="
if [ -d "build/ios/ipa" ] && ls build/ios/ipa/*.ipa >/dev/null 2>&1; then
  echo "✅ 出包完成，IPA 位于 build/ios/ipa/"
  ls -lh build/ios/ipa/*.ipa
else
  echo "⚠️  未找到 IPA，请检查上方构建日志"
fi
echo "========================================="

# 双击运行时暂停，便于查看结果；重定向运行时（如后台）不卡住
if [ -t 1 ]; then
  read -p "按回车关闭窗口"
fi
