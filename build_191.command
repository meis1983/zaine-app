#!/bin/bash
# 在呢+ 出包脚本（v1.97.3 + build 191）
#
# 191 修复（在 190 基础上，收口诊断 + 修复守护圈同步/头像/心跳克制）：
#
# 核心结论（前几轮已用 FC 后台铁证定位）：
#   · 服务端写库正常（uid=5 的 batch_lookup 两次返 checked_in_today=True）；
#   · 传输层没问题，客户端显示层 + 同步时机是根因。
#
# 191 改动：
#   ① 头像不同步（Bug3）：profile_page 头像上传失败不再静默吞掉 → 失败弹提示 + 重试一次
#      + 成功后强制 SyncService.pullFromServer()；guardian_page 进页面无条件以 batchLookup
#      返回值为准覆盖本地头像缓存（空值回退默认首字母，不再显示几个月前的旧头像）。
#   ② 签到同步时效（Bug2，用户重点要求）：守护圈已有「进页面即拉 + 30s 轮询 + App 回到前台刷新
#      + 下拉手动刷新」四重机制；成员签到后守护者打开守护圈即时看到，停留时 ≤30s 自动跟上
#      （远低于用户可接受的 2~3 分钟上限）。
#   ③ Watch 心跳克制 + 透明化（Bug5，保留心跳签到=产品灵魂）：当天已通过任意方式签到 →
#      自动心跳/信号签到静默跳过，不再重复 do_checkin、不再重复弹💓横幅，根除「无缘无故滴一下
#      滴一下」；仅用户在 Watch 上明确手动点击仍放行。所有心跳路径加 [191 WB] 双通道日志
#      （成功/跳过/超时/异常），明天早上可在 zaine_debug.log 验证。
#   ④ 平安确认不丢失（Bug4）：App 回到前台即重载平安确认请求，避免切后台后横幅丢失。
#   ⑤ 收口 190 临时诊断：删除 _handleCheckIn 入口 / onTap 的侵入式 SnackBar，保留文件+控制台日志通道。
#
# 继承：190 双通道日志 + 189 重置补清 Keychain + 188 登录链路超时兜底。
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
echo "  在呢+ 出包 v1.97.3 (build 191)"
echo "  191 修：①头像同步如实反馈 ②守护圈时效四重机制 ③心跳克制+透明化 ④平安确认防丢失 ⑤收口诊断"
echo "  PATH 已注入: $(command -v flutter)"
echo "========================================="
echo ""

ZAI_VERSION_NAME=1.97.3 ZAI_BUILD_NUMBER=191 bash build_ipa.sh

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
