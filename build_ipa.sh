#!/bin/bash
# ============================================================
# 在呢+ IPA 构建脚本
# 请在本机 Terminal（非 WorkBuddy 终端）中运行
# ============================================================
set -e

PROJECT_DIR="/Users/meixulin/Desktop/zaine-app/zaine_app"
ARCHIVE_PATH="$PROJECT_DIR/build/ios/archive/Runner.xcarchive"
EXPORT_PATH="$PROJECT_DIR/build/ios/ipa"

echo "===== Step 1: 清理并获取依赖 ====="
cd "$PROJECT_DIR"
flutter clean
flutter pub get

echo ""
echo "===== Step 2: Flutter Release 构建（无签名） ====="
flutter build ios --release --no-codesign

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
