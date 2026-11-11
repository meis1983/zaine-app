#!/bin/bash
# screenshot_run.sh —— 一遍跑完三语截图，按语言归类到 screenshots/<语言>/
# 用法：bash screenshot_run.sh
# 前置：模拟器已 boot；演示账号需在模拟器里先 quickLogin 建号并手动加好假守护人
#
# ⚠️ 切勿用真实手机号！改用演示号（默认 13800001234，可覆盖）：
#   SHOT_PHONE=13800001234 bash screenshot_run.sh
set -e

# 确保 flutter 在 PATH（后台纯 bash 不加载 ~/.zshrc，需显式补）
export PATH="$HOME/flutter/bin:$PATH"

cd /Users/meixulin/Desktop/zaine-app/zaine_app

# 截图演示账号（默认虚构号；用环境变量覆盖，严禁填真实号）
SHOT_PHONE="${SHOT_PHONE:-13800001234}"

# 设备预检：必须有一个在线的 iOS 模拟器，否则 flutter test 会卡在设备检测阶段
echo "🔍 检查 iOS 模拟器是否在线..."
if ! flutter devices 2>/dev/null | grep -qiE 'ios|simulator'; then
  echo "❌ 未检测到已启动的 iOS 模拟器。请先启动（二选一）："
  echo "     终端: xcrun simctl boot \"iPhone 16 Pro\""
  echo "     或打开 Simulator.app 手动启动一台 iPhone，启动后再重跑本脚本。"
  exit 1
fi

# 本项目含 watchOS companion app，flutter 必须指定具体设备 ID 才能构建模拟器版本
# 用正则精确提取 UUID（awk 取末词会误取行尾的 "(simulator)"）
DEVICE_ID=$(flutter devices 2>/dev/null | grep -iE 'simulator' | grep -oE '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}' | head -1)
if [ -z "$DEVICE_ID" ]; then
  echo "❌ 取到空 device id，请确认模拟器已完全启动（flutter devices 能看到 simulator 一行）。"
  exit 1
fi
echo "✅ 模拟器 device id: $DEVICE_ID"

LOCALES=("en" "zh-CN" "zh-TW")

# 确保依赖已装（沙箱外首次需跑）
flutter pub get

# ── 激活模拟器移动位置源（必须在宿主机执行，不能在 App 内 Process.run）──
# iOS 模拟器无真实 GPS，geolocator.getCurrentPosition 的静态点(含 GUI Custom Location)
# 在 iOS 26 模拟器上常不回调而超时。改用「移动路线(gpx)」让 CLLocationManager 持续
# 产生位置更新，geolocator 才能稳定拿到坐标。此命令运行在 Mac 终端，绕开 iOS 限制。
GPX="$PWD/integration_test/sim_location.gpx"
echo "📍 激活模拟器移动位置源（解决 geolocator 模拟器超时）..."
xcrun simctl location "$DEVICE_ID" stop 2>/dev/null || true
if xcrun simctl location "$DEVICE_ID" start "$GPX"; then
  echo "✅ 位置源已设为上海移动路线（3 个途经点），geolocator 应能拿到坐标"
else
  echo "⚠️ simctl 启动路线失败（上面可能有 stderr）。将回退依赖 GUI Custom Location。"
  echo "   若仍失败，SOS 页 03_sos 会是空态，建议用真机补截这一张。"
fi

for loc in "${LOCALES[@]}"; do
  echo "▶️  截图语言: $loc"
  flutter test integration_test/screenshot_test.dart -d "$DEVICE_ID" --dart-define=SHOT_LOCALE=$loc --dart-define=SHOT_PHONE=$SHOT_PHONE

  mkdir -p "screenshots/$loc"
  # 截图默认输出位置不固定，两处都找后归到语言目录
  find . -path ./screenshots -prune -o \( -name '0*.png' -o -name '*.png' \) -print 2>/dev/null \
    | grep -E '0[0-9]_' \
    | while read -r f; do mv "$f" "screenshots/$loc/" 2>/dev/null || true; done

  echo "✅ $loc 截图已存 screenshots/$loc/"
done

# 停止模拟器位置模拟（恢复默认，避免影响后续真机/其他用途）
xcrun simctl location "$DEVICE_ID" stop 2>/dev/null || true

# ── 汇总到桌面最终文件夹 ──
# 每台语言文件夹里：脚本产出的 4 张（01_home/02_guardian/04_health/05_profile）
# + 已预先放好的手机 SOS 图（03_sos.png）＝ 共 5 张，可直接上传 ASC。
DESK_FINAL="$HOME/Desktop/zaine_screenshots"
for loc in "${LOCALES[@]}"; do
  mkdir -p "$DESK_FINAL/$loc"
  cp -n "screenshots/$loc/"*.png "$DESK_FINAL/$loc/" 2>/dev/null || true
done

echo ""
echo "✅ 全部完成。最终截图在：~/Desktop/zaine_screenshots/<语言>/ （每语言 5 张）"
echo "   01_home / 02_guardian / 03_sos(手机) / 04_health / 05_profile"
echo "下一步：用设计工具给每张加 headline 横幅（见 SCREENSHOT_GUIDE.md），再上传 ASC 1.98.3。"
