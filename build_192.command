#!/bin/bash
# 在呢+ 出包脚本（v1.97.3 + build 192）
#
# 192 修复（基于 191，第一性原理定位真实根因）：
#
# 用户 191 实测反馈四现象，逐一定位：
#   ① 生命体征守护「未监测」，必须手动点刷新才显示「守护中」
#      → 根因：initState 未调用 _loadSafetyStatus，且 batchLookup 成功路径提前 return
#        跳过了它；只有 batchLookup 失败兜底分支 / 手动刷新才加载。192 在 initState 即加载。
#   ② 手表健康速览（Apple Watch）空白（191 之前是好的）
#      → 根因：191 的「今天已签到→直接 return」克制规则，跳过了 performSilentHeartbeatCheckin
#        内部的 syncHealthData()(负责 pushHealthSummary 到手表)。192 改为：跳过重复签到，
#        但仍同步健康数据到手表。
#   ③ 守护圈成员签到状态 / 头像不同步
#      → 客户端逻辑本身正确（batchLookup→_guardians→卡片 全链路校验无误）。
#        加 [192 G] 双通道诊断日志，确认是 batchLookup 未成功还是后端时区，需用户跑一次取日志。
#   ④ 收口：保留 191 头像无条件覆盖 + 心跳克制 + 双通道日志。
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
echo "  在呢+ 出包 v1.97.3 (build 192)"
echo "  192 修：①进页面即加载生命体征(修未监测) ②修191回归-手表健康速览空白 ③守护圈同步诊断"
echo "  PATH 已注入: $(command -v flutter)"
echo "========================================="
echo ""

ZAI_VERSION_NAME=1.97.3 ZAI_BUILD_NUMBER=192 bash build_ipa.sh

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
