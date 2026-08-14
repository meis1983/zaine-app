#!/bin/bash
# 在呢+ 出包脚本（v1.97.3 + build 184）
# 184 根除签到幽灵早退(Bug2 真正根因)：
#   FC 日志铁证：4 个成员点「签到」后端 0 条 do_checkin 记录。
#   根因：home_page._handleCheckIn 入口用本地 prefs 的 last_check_in_date_$uid
#   早退，一旦残留「今天」标记，do_checkin 永远发不出去 → 4 个成员 last_signin_at
#   仍停 5~6 月、守护圈永远显示未签到。后端 d29adcb 的 checkin_history 真相源
#   修不了客户端幽灵。
#   修复：早退条件由「_checkedInToday || alreadyCheckedLocally」改为
#   「_checkedInToday && historySaysChecked」，其他一律放行 do_checkin 让后端做
#   最终判断（后端 already_checked_in 拦截真重复）。
# 配合 183（守护态根除跳动）— 通过即收口。
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
echo "  在呢+ 出包 v1.97.3 (build 184)"
echo "  184 修：根除签到幽灵早退(FC 日志铁证：4 成员点签到 0 条 do_checkin)"
echo "  PATH 已注入: $(command -v flutter)"
echo "========================================="
echo ""

ZAI_VERSION_NAME=1.97.3 ZAI_BUILD_NUMBER=184 bash build_ipa.sh

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
