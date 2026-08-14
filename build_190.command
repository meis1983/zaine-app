#!/bin/bash
# 在呢+ 出包脚本（v1.97.3 + build 190）
#
# 190 修复（在 189 基础上，彻底解决「真机诊断看不到日志」的排查死结）：
#
# 核心背景：此前 185~189 在真机诊断「签到入口是否触发」时，依赖 macOS
# Console.app 的进程过滤 / NSPredicate 语法，极易因「进程名不匹配 /
# 未点开始流式传输 / devicectl 版本不支持」等原因看到 0 条日志，反复误导方向。
#
# 190 改用【双通道兜底日志】，彻底不依赖 Console：
#   ① 屏幕 SnackBar：_handleCheckIn 入口 + onTap wrapper 直接弹在 App 屏幕上，
#      用户点签到立刻看到「190 SIGN 入口 / 190 TAP 触发」
#   ② 文件兜底：追加写入 <文档目录>/zaine_debug.log，事后从 Xcode →
#      Devices → Download Container → 解压 → AppData/Documents/zaine_debug.log 取回
#
# 代码改动：
#   · lib/services/debug_log.dart（新）双通道日志工具类
#   · lib/pages/home_page.dart：_handleCheckIn 第一个 await 前插入入口诊断
#     （SnackBar + DebugLog.write + developer.log）；onTap 包 wrapper 打 [190 TAP]
#   · lib/services/api_service.dart：[189 NET] → [190 NET]
#   · lib/pages/onboarding_page.dart：[189 LOGIN] → [190 LOGIN]
#
# 继承：189 的重置补清 Keychain + 188 的登录链路超时兜底 / 毒链免疫。
#
# 双击本文件会用 macOS 系统 Terminal 运行，自动注入版本号并调用 build_ipa.sh。
# 本脚本写死 flutter 绝对路径，不依赖 ~/.zshrc，解决之前出包失败问题。

export PATH="/Users/meixulin/flutter/bin:$PATH"
export PUB_HOSTED_URL="https://pub.flutter-io.cn"
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"

cd /Users/meixulin/Desktop/zaine-app/zaine_app || {
  echo "❌ 项目目录不存在"
  read -p "按回车退出"
  exit 1
}

echo "========================================="
echo "  在呢+ 出包 v1.97.3 (build 190)"
echo "  190 修：①双通道调试日志(屏幕SnackBar+文件) ②诊断标签[189]→[190]"
echo "  PATH 已注入: $(command -v flutter)"
echo "========================================="
echo ""

ZAI_VERSION_NAME=1.97.3 ZAI_BUILD_NUMBER=190 bash build_ipa.sh

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
