#!/bin/bash
# 在呢+ 出包脚本（v1.97.3 + build 181）
# 181 两处状态跳动根因修复（第一性原理，不再盲改）：
#   ① 健康卡同账号跳动(Bug1)：health_service.requestPermissions 在 HealthKit
#      授权弹窗成功拉起(未抛异常)即写粘性标记 health_authorized，不再依赖 iOS
#      隐私模型下不可靠的 requestAuthorization 返回值。使「守护中」状态恒定，
#      告别「尚未检测↔守护中」来回跳动（即使实时探测偶发失败）。
#   ② 守护圈头部数字级联跳动(Bug4)：移除 _loadGuardians 中提前的
#      setState(_guardedByMe)，三源(守护我的人/我守护的人/互为守护)全部
#      填充后统一刷新；引入 _headerReady 标志，未就绪时显示「正在同步守护圈
#      状态…」占位，根除进入页面时计数逐步跳变。
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
echo "  在呢+ 出包 v1.97.3 (build 181)"
echo "  181 修：健康卡授权弹窗即粘性标记(根除跳动) + 守护圈头部级联修复"
echo "  PATH 已注入: $(command -v flutter)"
echo "========================================="
echo ""

ZAI_VERSION_NAME=1.97.3 ZAI_BUILD_NUMBER=181 bash build_ipa.sh

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
