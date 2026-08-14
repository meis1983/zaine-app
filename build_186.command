#!/bin/bash
# 在呢+ 出包脚本（v1.97.3 + build 186）
# 186 修复诊断日志不可见问题：
#   185 用 print() 在 iOS release 包里被系统完全吞掉——
#   Xcode Console / macOS 控制台 App 都搜不到 [185 _handleCheckIn]，
#   实测 185 包装上后手机操作无任何 [185 日志输出。
#   根因：Dart print() 在 release 包经 stdout 桥接未稳定进 OSLog（或被标 <private>）。
#   186 改为 dart:developer 的 developer.log()，直接走 os_log API，
#   保证 release 包日志必进 OSLog，Console 一定能搜到。
#   所有 [185 _handleCheckIn] 诊断前缀同步改为 [186。
#   —— do_checkin 永远调用（185 业务逻辑不变），仅日志机制升级。
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
echo "  在呢+ 出包 v1.97.3 (build 186)"
echo "  186 修：诊断日志改用 developer.log(release 包必进 OSLog)"
echo "  PATH 已注入: $(command -v flutter)"
echo "========================================="
echo ""

ZAI_VERSION_NAME=1.97.3 ZAI_BUILD_NUMBER=186 bash build_ipa.sh

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
