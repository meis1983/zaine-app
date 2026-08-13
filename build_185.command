#!/bin/bash
# 在呢+ 出包脚本（v1.97.3 + build 185）
# 185 根治 Bug2（do_checkin 不发）：FC 日志铁证——用户装 184 后仍 0 条 do_checkin，
# 说明仅靠 184 的 _checkedInToday && historySaysChecked 还没覆盖全部场景。
# 本次彻底移除所有本地状态守卫：
#   - 移除 _checkedInToday && historySaysChecked 早退分支
#   - 移除 do_checkin 之前的 if (_isLoggedIn) 包裹（改为：若 false 先紧急读 prefs 再判定）
#   - 永远调用 do_checkin，让服务端做唯一真相源
#   - 用 print() 而非 debugPrint()，release 包也能在 Xcode 控制台看到诊断
# 配合 183（守护态根除跳动）— 通过即收口。
# 双击本文件会用 macOS 系统 Terminal 运行，自动注入版本号并调用 build_ipa.sh
# 注意：本脚本写死 flutter 绝对路径，不依赖 ~/.zshrc，解决之前出包失败问题
#
# 185b 修补（2026-08-13）：原 185 内写了不存在的 _loadUserInfo()，编译报错
#   '_HomePageState' has no method named '_loadUserInfo'。改为直接
#   SharedPreferences.getInstance().getBool('is_logged_in') 同步状态。
#   本意不变，仅去除编译错误。

export PATH="/Users/meixulin/flutter/bin:$PATH"
export PUB_HOSTED_URL="https://pub.flutter-io.cn"
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"

cd /Users/meixulin/Desktop/zaine-app/zaine_app || {
  echo "❌ 项目目录不存在"
  read -p "按回车退出"
  exit 1
}

echo "========================================="
echo "  在呢+ 出包 v1.97.3 (build 185)"
echo "  185 修：do_checkin 永远调用(移除所有本地状态守卫)"
echo "  PATH 已注入: $(command -v flutter)"
echo "========================================="
echo ""

ZAI_VERSION_NAME=1.97.3 ZAI_BUILD_NUMBER=185 bash build_ipa.sh

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