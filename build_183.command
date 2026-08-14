#!/bin/bash
# 在呢+ 出包脚本（v1.97.3 + build 183）
# 183 守护态跳动根本性收口（第一性原理 + git 回归考古）：
#   Bug1 经 git 考古确认回归点：v1.97.4 误判 hasPermissions「iOS 永远 false」，
#   催生 179 用 prefs 标记取代 172 稳定版「直接读 HealthKit 真实权限态」方案。
#   182 仅「点上按钮才写标记」仍不够——若 requestAuthorization 在设备上报异常两次则标记永不写。
#   修复：markAuthorized() 置于 requestPermissions 的 finally 中，用户点「开启生命体征守护」
#   即设备级配对意图，无论返回值/异常恒定写标记 → 切界面/切账号回来恒为「守护中」。
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
echo "  在呢+ 出包 v1.97.3 (build 183)"
echo "  183 修：守护态必然写标记(根除守护中↔尚未检测跳动)"
echo "  PATH 已注入: $(command -v flutter)"
echo "========================================="
echo ""

ZAI_VERSION_NAME=1.97.3 ZAI_BUILD_NUMBER=183 bash build_ipa.sh

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
