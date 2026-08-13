#!/bin/bash
# 在呢+ 出包脚本（v1.97.3 + build 180）
# 180 第一性原理根因修复（179 实测仍顽固，本次从根因层彻底解决）：
#   ① 健康卡授权态：登出改为「只清健康数据镜像、保留设备级授权粘性标记」，
#      根除「切账号→守护卡先闪未检测→再回守护中」的跳动（HealthKit 授权是设备级，与账号无关）
#   ② 签到不同步（根因在后端）：last_signin_at 由 aware(+8) 改为 UTC naive 写入，
#      MySQL DATETIME 字面量存储 + get_china_date(naive→UTC→+8) 读取一致，
#      修正下午/晚上签到 checked_in_today 恒 false → 守护圈「未签到」/「待激活」
#   ③ 切换账号串号：logout / quickLogin / silentLogin 三处统一清 contact_* 联系人缓存，
#      杜绝旧账号的签到/激活/头像态串到新账号
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
echo "  在呢+ 出包 v1.97.3 (build 180)"
echo "  180 修：健康卡登出保留标记 + 后端签到时区 + 切换账号清联系人缓存"
echo "  PATH 已注入: $(command -v flutter)"
echo "========================================="
echo ""

ZAI_VERSION_NAME=1.97.3 ZAI_BUILD_NUMBER=180 bash build_ipa.sh

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
