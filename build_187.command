#!/bin/bash
# 在呢+ 出包脚本（v1.97.3 + build 187）
#
# 187 双线修复（基于 186 实测定案）：
#
# 改动 A —— 客户端请求出口统一加 developer.log（核心诊断）
#   文件：lib/services/api_service.dart
#   位置：统一出口 _withRetry() 的入口/成功返回/三个异常分支/最终离线返回
#   前缀：[187 NET OUT] / [187 NET IN] / [187 NET ERR]，name='zaine.net'
#   作用：release 包也能在 Xcode Console（开发者工具自动解密 <private>）看到
#         "每一个 HTTP 请求是否发出 / 响应状态 / 是否有异常"——彻底解决
#         "FC 控制台看不到 HTTP path"的死路，直接锁定 do_checkin 为何没发出。
#
# 改动 B —— 撤销本地乐观更新（修复 UI 骗人）
#   文件：lib/pages/home_page.dart 的 _handleCheckIn
#   原逻辑：点签到立即 setState(_checkedInToday=true) + 立即持久化 prefs，
#           不等服务端响应 → UI 永远显示"已签到"但云端可能没收到（这就是
#           用户一直被假象骗、以为 bug 在别处的根因）。
#   新逻辑：仅在 do_checkin 返回 success / already_checked_in 时才 setState +
#           持久化。UI 与服务端完全同步。
#
# 说明：186 已把"永远调用 do_checkin"写进代码，但 186 的 developer.log 在
#       _handleCheckIn 内、且用户实测完全不输出（Xcode Console 也搜不到 [186），
#       说明 _handleCheckIn 这条函数本身可能根本没被调用、或在某 await 处被吞。
#       187 把诊断下沉到**所有 HTTP 请求的统一出口**，无论哪条路径调用，
#       必在 OSLog 留下 [187 NET *] 痕迹。
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
echo "  在呢+ 出包 v1.97.3 (build 187)"
echo "  187 修：①请求出口统一 developer.log ②撤销本地乐观更新"
echo "  PATH 已注入: $(command -v flutter)"
echo "========================================="
echo ""

ZAI_VERSION_NAME=1.97.3 ZAI_BUILD_NUMBER=187 bash build_ipa.sh

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
