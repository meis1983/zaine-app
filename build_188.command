#!/bin/bash
# 在呢+ 出包脚本（v1.97.3 + build 188）
#
# 188 修复（针对「登录中」永久转 + 登录后才能复现的守护圈 Bug2）：
#
# 改动 1 —— 全局串行请求队列毒链免疫（核心，修「登录中」永远转）
#   文件：lib/services/api_service.dart
#   位置：_enqueue() / 新增 resetRequestChain()
#   问题：原 _enqueue 用 `await prev` 串起整条请求链，一旦某前序请求异常
#         落定（非 Exception 的 Error / 未捕获异常），整条链会永远 pending，
#         后续所有请求（含本次登录 quick-login）卡在 `await prev` 上不进网络。
#         且 55s 超时只包住了 AuthService.quickLogin 单点，登录成功后的
#         pullFromServer() / _completeOnboarding() 都在超时之外 → finally 不执行
#         → `_isLoggingIn` 永远 true → 「登录中」永远转、且到不了位置弹窗。
#   新逻辑：
#     · resetRequestChain()：登录/冷启动前强制重置队列，打断残留挂起链。
#     · _enqueue 的 `await prev` 包 try/catch，前序异常被隔离，不毒化新请求。
#
# 改动 2 —— 登录链路全节点超时兜底 + 诊断（彻底杜绝永久转 + 定位证据）
#   文件：lib/pages/onboarding_page.dart 的 _quickLogin
#   位置：入口调用 resetRequestChain()；quickLogin 30s 超时（原 55s）；
#         pullFromServer() 25s 超时降级跳过；_completeOnboarding() 15s 超时降级。
#         并插入 [188 LOGIN] 诊断日志（入口/调前/返回/拉取/完成引导）。
#   作用：最坏 30+25+15 = 70s 内「登录中」必定结束并进入首页；
#         同时若仍卡，可在 Xcode Console 用 [188 LOGIN] 看到卡在哪个节点。
#
# 改动 3 —— 网络出口诊断日志升级 187 → 188（与 build 号对齐）
#   文件：lib/services/api_service.dart 的 _withRetry
#   前缀：[188 NET OUT] / [188 NET IN] / [188 NET ERR]，name='zaine.net'
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
echo "  在呢+ 出包 v1.97.3 (build 188)"
echo "  188 修：①请求队列毒链免疫 ②登录全链路超时兜底 ③[188]诊断"
echo "  PATH 已注入: $(command -v flutter)"
echo "========================================="
echo ""

ZAI_VERSION_NAME=1.97.3 ZAI_BUILD_NUMBER=188 bash build_ipa.sh

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
