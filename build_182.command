#!/bin/bash
# 在呢+ 出包脚本（v1.97.3 + build 182）
# 182 守护态跳动根本性收口（第一性原理，不再盲改）：
#   健康卡守护态跳动(Bug1) 复发真因：181 仅「用户点开启弹窗」时写标记，若从未触发则标记恒
#   false → 每次进页走实时探测 → iOS HealthKit 隐私模型下探测偶发成功 → 跳动。
#   修复：markAuthorized() 同时写 health_authorized_at 时间戳；_loadSafetyStatus 引入
#   hasEverAuthorized() 破冰兜底——标记 true 或「历史上曾授权」即恒定「守护中」，
#   实时探测失败不再回落「尚未检测」。用户在 182 上点一次「开启生命体征守护」破冰后即恒定。
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
echo "  在呢+ 出包 v1.97.3 (build 182)"
echo "  182 修：守护态破冰兜底(根除守护中↔尚未检测跳动)"
echo "  PATH 已注入: $(command -v flutter)"
echo "========================================="
echo ""

ZAI_VERSION_NAME=1.97.3 ZAI_BUILD_NUMBER=182 bash build_ipa.sh

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
