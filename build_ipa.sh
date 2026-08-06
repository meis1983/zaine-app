#!/bin/bash
# ============================================================
# 在呢+ IPA 构建脚本
# 请在本机 Terminal（非 WorkBuddy 终端）中运行
#
# 可选环境变量（用于同一功能版重传 TestFlight / 重提审核）：
#   ZAI_VERSION_NAME  覆写 CFBundleShortVersionString（如 1.94.0）
#   ZAI_BUILD_NUMBER  覆写 CFBundleVersion（如 111，须大于已上传的号）
#   ZAI_REGION        区域开关：global(默认, 海外全功能版) / cn(中国合规版, 关闭自动通知)
#   例:
#     海外全功能版 : bash build_ipa.sh
#     中国合规版   : ZAI_REGION=cn ZAI_BUILD_NUMBER=135 bash build_ipa.sh
# ============================================================
set -e

PROJECT_DIR="/Users/meixulin/Desktop/zaine-app/zaine_app"
ARCHIVE_PATH="$PROJECT_DIR/build/ios/archive/Runner.xcarchive"
EXPORT_PATH="$PROJECT_DIR/build/ios/ipa"

# ----------------------------------------------------------
# cn 区域：将工程内所有 Bundle ID 由 com.zaine.app 切换为
#          com.zaine.app.cn（含主 App / Watch / Tests 派生后缀）。
#          导出完成后由 trap 自动还原，海外构建不受影响。
# ----------------------------------------------------------
PBXPROJ="$PROJECT_DIR/ios/Runner.xcodeproj/project.pbxproj"
INFOPLIST="$PROJECT_DIR/ios/Runner/Info.plist"
if [ "$ZAI_REGION" = "cn" ]; then
  echo "ℹ️  cn 区域：将工程 Bundle ID 切换为 com.zaine.app.cn，并改写位置/健康权限文案（去除守护/报平安等监控暗示）"
  cp "$PBXPROJ" "$PBXPROJ.bak"
  sed -i '' 's/com\.zaine\.app/com.zaine.app.cn/g' "$PBXPROJ"
  # 中国合规版：位置 / 健康权限描述去掉“始终 / 守护人 / 守护 / 报平安”等监控暗示，避免触发死开关判定
  cp "$INFOPLIST" "$INFOPLIST.zai_bak"
  sed -i '' 's|在呢需要始终获取您的位置，以便在您发起求助时向您的守护人发送位置信息。|在呢会在您主动使用位置相关功能时获取您的位置信息。|g' "$INFOPLIST"
  sed -i '' 's|在呢需要读取您的健康记录（步数、心率、血氧、睡眠），以便在紧急情况下向守护人展示您的健康状况。|在呢需要读取您的健康记录（步数、心率、血氧、睡眠），用于为您生成本人的健康日记。|g' "$INFOPLIST"
  sed -i '' 's|在呢需要同步您的健康数据（心率、血氧、睡眠、经期等），以实现生命体征守护功能。|在呢需要同步您的健康数据（心率、血氧、睡眠、经期等），用于为您生成本人的健康日记与趋势记录。|g' "$INFOPLIST"
  sed -i '' 's|在呢需要读取您的健康数据，以实现每日签到报平安和经期跟踪功能。|在呢需要读取您的健康数据，用于记录您的每日签到与经期跟踪。|g' "$INFOPLIST"
  sed -i '' 's|在呢需要发送通知提醒您定时报平安。|在呢需要发送通知提醒您每日签到。|g' "$INFOPLIST"
  cleanup_cn() {
    if [ -f "$PBXPROJ.bak" ]; then
      mv "$PBXPROJ.bak" "$PBXPROJ"
      echo "ℹ️  已还原工程 Bundle ID 为 com.zaine.app"
    fi
    if [ -f "$INFOPLIST.zai_bak" ]; then
      mv "$INFOPLIST.zai_bak" "$INFOPLIST"
      echo "ℹ️  已还原 Info.plist 位置权限文案"
    fi
  }
  trap cleanup_cn EXIT
fi

echo "===== Step 1: 清理并获取依赖 ====="
cd "$PROJECT_DIR"
flutter clean
flutter pub get

echo ""
echo "===== Step 2: Flutter Release 构建（无签名） ====="
# 支持版本覆写（用于同一功能版重新上传 TestFlight / 重提审核）
VERSION_ARGS=""
if [ -n "$ZAI_VERSION_NAME" ]; then
    VERSION_ARGS="$VERSION_ARGS --build-name=$ZAI_VERSION_NAME"
fi
if [ -n "$ZAI_BUILD_NUMBER" ]; then
    VERSION_ARGS="$VERSION_ARGS --build-number=$ZAI_BUILD_NUMBER"
fi
if [ -n "$VERSION_ARGS" ]; then
    echo "ℹ️  覆写版本: name=${ZAI_VERSION_NAME:-未指定} build=${ZAI_BUILD_NUMBER:-未指定}"
fi

# 区域开关：global(默认, 海外全功能版) / cn(中国合规版, 关闭自动通知第三方亲友)
REGION_ARGS=""
if [ -n "$ZAI_REGION" ]; then
    REGION_ARGS="--dart-define=ZAI_REGION=$ZAI_REGION"
    echo "ℹ️  区域开关: ZAI_REGION=$ZAI_REGION"
fi

# IAP 签名密钥：与后端 _MVP_SIGN_SECRET 保持一致，可通过环境变量覆盖
SIGN_ARGS="--dart-define=ZAINE_SIGN_SECRET=${ZAINE_SIGN_SECRET:-zaine-storekit-mvp-v1}"
echo "ℹ️  IAP 签名密钥已注入"

# 用 eval 让 $VERSION_ARGS / $REGION_ARGS / $SIGN_ARGS 正确展开为多个参数
eval "flutter build ios --release --no-codesign $VERSION_ARGS $REGION_ARGS $SIGN_ARGS"

echo ""
echo "===== Step 3: Xcode Archive ====="
cd "$PROJECT_DIR/ios"
xcodebuild -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -sdk iphoneos \
  -archivePath "$ARCHIVE_PATH" \
  archive \
  ONLY_ACTIVE_ARCH=NO \
  -allowProvisioningUpdates

echo ""
echo "===== Step 4: 导出 IPA ====="
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$PROJECT_DIR/ios/ExportOptions.plist" \
  -allowProvisioningUpdates

echo ""
echo "===== 完成! ====="
echo "IPA 路径: $EXPORT_PATH"
ls -la "$EXPORT_PATH"

echo ""
echo "===== Step 5: 上传到 TestFlight（可选） ====="
echo "方式一：使用 Transporter App 上传 $EXPORT_PATH/*.ipa"
echo "方式二：命令行上传："
echo "  xcrun altool --upload-app -f $EXPORT_PATH/*.ipa -t ios -u <AppleID> -p <app-specific-password>"
echo ""
echo "方式三：使用 Xcode Organizer 的 Archive 直接上传"
