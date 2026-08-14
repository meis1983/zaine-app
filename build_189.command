#!/bin/bash
# 在呢+ 出包脚本（v1.97.3 + build 189）
#
# 189 修复（在 188 基础上顺带修「重置所有数据」漏清 Keychain 的 bug）：
#
# 改动 1 —— 「重置所有数据」补清 Keychain 登录凭证（核心，修「重置后数据还在」）
#   文件：lib/pages/settings_page.dart 的 _resetAllData
#   问题：原实现只清 SharedPreferences（prefs.getKeys()），但 auth_token /
#         user_id / user_phone 存在 FlutterSecureStorage（Keychain）里，
#         SharedPreferences 不含 Keychain → 重置后凭证仍在 → 冷启动自动恢复
#         登录 → pullFromServer 把服务端数据重新拉回 → 用户感觉"数据还在"。
#   新逻辑：
#     · 清 SharedPreferences 后，显式 secureStorage.delete(auth_token/user_id/
#       user_phone)，打断自动恢复登录。
#     · 弹窗文案补一句：仅清本机数据，云端账号与服务器数据不受影响；
#       如需彻底删除请用「删除账号」。
#
# 改动 2 —— 诊断日志 188 → 189（与 build 号对齐，Console 搜 [189 即可）
#   文件：lib/services/api_service.dart（[189 NET *]）+ lib/pages/onboarding_page.dart（[189 LOGIN]）
#
# 188 已含的修复（本 build 一并继承）：
#   · 全局串行请求队列毒链免疫（resetRequestChain + await prev 隔离）
#   · 登录链路全节点超时兜底（quickLogin 30s / pullFromServer 25s / _completeOnboarding 15s）
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
echo "  在呢+ 出包 v1.97.3 (build 189)"
echo "  189 修：①重置补清 Keychain ②[189]诊断日志对齐"
echo "  PATH 已注入: $(command -v flutter)"
echo "========================================="
echo ""

ZAI_VERSION_NAME=1.97.3 ZAI_BUILD_NUMBER=189 bash build_ipa.sh

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
