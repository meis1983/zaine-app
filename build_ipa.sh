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
# 安全中心导航 active 文件（方案 A 文件 swap）：CN 构建前整体替换为 stub，构建后 trap 还原
NAV_ACTIVE="$PROJECT_DIR/lib/pages/safety_settings_navigator.dart"
NAV_CN="$PROJECT_DIR/lib/pages/safety_settings_navigator_stub.dart"
if [ "$ZAI_REGION" = "cn" ]; then
  echo "ℹ️  cn 区域：将工程 Bundle ID 切换为 com.zaine.app.cn，并改写位置/健康权限文案（去除守护/报平安等监控暗示）"
  cp "$PBXPROJ" "$PBXPROJ.bak"
  sed -i '' 's/com\.zaine\.app/com.zaine.app.cn/g' "$PBXPROJ"
  # 中国合规版：Watch App 健康权限文案 CN 化（去掉"感应签到"等自动行为暗示）
  #   背景：Watch target 用 GENERATE_INFOPLIST_FILE=YES，其 Info.plist 由 build settings 生成，
  #         文案存在 project.pbxproj 的 503/553/599 三处（Debug/Release/Profile），
  #         不走 ios/Runner/Info.plist 文件 → 下方 INFOPLIST 的 sed 完全够不到，必须单独处理。
  #   风险：原文案"需要读取您的心率数据以实现感应签到功能"= dead-man switch 的书面自认
  #         （与 164 驳回判语同源），审核员读 plist 直接可见，比扫二进制更致命。
  sed -i '' 's|需要读取您的心率数据以实现感应签到功能|用于在手表上查看您的心率等健康数据|g' "$PBXPROJ"
  sed -i '' 's|暂不使用写入功能，保留权限以便未来扩展|暂不使用健康数据写入功能|g' "$PBXPROJ"
  echo "[i] 已将 Watch 健康权限文案 CN 化（感应签到 -> 查看心率）"
  # 中国合规版：位置 / 健康权限描述去掉“始终 / 守护人 / 守护 / 报平安”等监控暗示，避免触发死开关判定
  cp "$INFOPLIST" "$INFOPLIST.zai_bak"
  sed -i '' 's|在呢需要始终获取您的位置，以便在您发起求助时向您的守护人发送位置信息。|在呢会在您主动使用位置相关功能时获取您的位置信息。|g' "$INFOPLIST"
  sed -i '' 's|在呢需要读取您的健康记录（步数、心率、血氧、睡眠），以便在紧急情况下向守护人展示您的健康状况。|在呢需要读取您的健康记录（步数、心率、血氧、睡眠），用于为您生成本人的健康日记。|g' "$INFOPLIST"
  sed -i '' 's|在呢需要同步您的健康数据（心率、血氧、睡眠、经期等），以实现生命体征守护功能。|在呢需要同步您的健康数据（心率、血氧、睡眠、经期等），用于为您生成本人的健康日记与趋势记录。|g' "$INFOPLIST"
  sed -i '' 's|在呢需要读取您的健康数据，以实现每日签到报平安和经期跟踪功能。|在呢需要读取您的健康数据，用于记录您的每日签到与经期跟踪。|g' "$INFOPLIST"
  sed -i '' 's|在呢需要发送通知提醒您定时报平安。|在呢需要发送通知提醒您每日签到。|g' "$INFOPLIST"
  # 中国合规版：保留 NSLocationAlwaysAndWhenInUseUsageDescription key
  #   原因：iOS 静态校验 / ITMS-90683 要求 binary 链接 CLLocationManager 时 Info.plist 必须有此 key；删了 Transporter 拒传（163 翻车已回滚）。
  #   性质：key 是"声明文本"（Apple 要求印在盒子上的标签），不是触发器。
  #         真正弹"始终允许"对话框的触发条件是代码调用 requestAlwaysAuthorization——
  #         本项目从未调过该方法（location_service.dart:137 仅 Geolocator.requestPermission → CLLocationManager.requestWhenInUseAuthorization），
  #         所以保留 key ≠ 用户会看到"始终允许"选项。
  # 实际打包文案：当前 Info.plist:58 = "在呢需要在您发起紧急求助时获取您的位置，用于向紧急联系人提供您的位置信息。"
  #   - 已无"始终/守护人/报平安"等监控暗示，描述与代码行为一致（仅在用户主动点 SOS/求助按钮时获取一次位置）。
  #   - 注：上方 sed 第 1 行的 old-string 是上一版文案（"在呢需要始终获取..."），与当前 Info.plist 不匹配，sed 为空操作；
  #         安全无害，留作回滚锚点；如要重写文案，直接改 Info.plist:58 即可（无需动 sed）。
  # CN 合规（方案 A 文件 swap）：编译前把"安全中心"导航 active 文件整体替换为 stub，
  #   使 CN 编译单元根本不 import SafetySettingsPage → 100% 物理剥离（苹果类级判定扫不到）。
  if [ -f "$NAV_ACTIVE" ] && [ -f "$NAV_CN" ]; then
    cp "$NAV_ACTIVE" "$NAV_ACTIVE.zai_bak"
    cp "$NAV_CN" "$NAV_ACTIVE"
    echo "[i] 已用 CN stub 替换安全中心导航文件（物理剥离 SafetySettingsPage）"
  fi
  cleanup_cn() {
    if [ -f "$PBXPROJ.bak" ]; then
      mv "$PBXPROJ.bak" "$PBXPROJ"
      echo "ℹ️  已还原工程 Bundle ID 为 com.zaine.app"
    fi
    if [ -f "$INFOPLIST.zai_bak" ]; then
      mv "$INFOPLIST.zai_bak" "$INFOPLIST"
      echo "ℹ️  已还原 Info.plist 位置权限文案"
    fi
    if [ -f "$NAV_ACTIVE.zai_bak" ]; then
      mv "$NAV_ACTIVE.zai_bak" "$NAV_ACTIVE"
      echo "[i] 已还原安全中心导航文件"
    fi
  }
  trap cleanup_cn EXIT
fi

echo "===== Step 1: 清理并获取依赖 ====="
cd "$PROJECT_DIR"

# ----------------------------------------------------------
# 自动定位 Flutter SDK
# 说明：本脚本若由 .command 文件 / 非交互 shell 调用，不会加载
#       ~/.zshrc，PATH 中可能没有 flutter，导致 "command not found"。
#       此处显式把已知 Flutter 安装路径注入 PATH（写死绝对路径，
#       不依赖用户 shell 配置），找不到再用 which 兜底。
# ----------------------------------------------------------
if ! command -v flutter >/dev/null 2>&1; then
  for p in "/Users/meixulin/flutter/bin" "/opt/homebrew/bin" "/usr/local/bin" "/usr/bin"; do
    if [ -x "$p/flutter" ]; then
      export PATH="$p:$PATH"
      echo "ℹ️  已将 Flutter 加入 PATH: $p"
      break
    fi
  done
fi
# 国内镜像，避免 pub get 超时（用户 ~/.zshrc 中配置，此处兜底）
export PUB_HOSTED_URL="${PUB_HOSTED_URL:-https://pub.flutter-io.cn}"
export FLUTTER_STORAGE_BASE_URL="${FLUTTER_STORAGE_BASE_URL:-https://storage.flutter-io.cn}"

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

# 原生编译宏（仅 cn）：向 Xcode 注入 ZAI_REGION_CN，使 Watch 心跳自动签到
# （dead-man switch 核心之一）在 CN 构建被编译期物理剔除（表里如一）。
# 用 \$(inherited) 追加，避免覆盖工程既有 preprocessor 定义（如 COCOAPODS=1）。
NATIVE_REGION_ARGS=()
if [ "$ZAI_REGION" = "cn" ]; then
  NATIVE_REGION_ARGS+=(SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) ZAI_REGION_CN')
  NATIVE_REGION_ARGS+=(GCC_PREPROCESSOR_DEFINITIONS='$(inherited) ZAI_REGION_CN=1')
  echo "ℹ️  原生编译宏: ZAI_REGION_CN 已注入（Watch 心跳自动签到将被编译期剔除）"
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
  -allowProvisioningUpdates \
  "${NATIVE_REGION_ARGS[@]}"

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
