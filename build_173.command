#!/bin/bash
# ============================================================
#  在呢+ 一键打包 · v1.97.3 (build 173)
#  用法：
#    A. Finder 中双击本文件（系统 Terminal 打开执行）
#    B. 在你自己的终端里运行：
#       bash /Users/meixulin/Desktop/zaine-app/zaine_app/build_173.command
#  注意：不要直接在 WorkBuddy 沙箱终端跑，flutter build 会被拦截。
# ============================================================
# —— 关键修复：.command / 非交互 shell 不会加载 ~/.zshrc，PATH 里没有 flutter ——
# 写死绝对路径，确保 flutter 命令可被找到（不依赖用户 shell 配置）
export PATH="/Users/meixulin/flutter/bin:$PATH"
# 国内镜像，避免 pub get 超时
export PUB_HOSTED_URL="https://pub.flutter-io.cn"
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"

PROJECT_DIR="/Users/meixulin/Desktop/zaine-app/zaine_app"
cd "$PROJECT_DIR" || {
  echo "❌ 无法进入目录: $PROJECT_DIR"
  exit 1
}

# 注入版本号（与 App Store Connect 显示版本 / build 对应）
export ZAI_VERSION_NAME=1.97.3
export ZAI_BUILD_NUMBER=173
# 如需打中国合规版，取消下面注释（build_ipa.sh 会自动切 Bundle ID + 合规文案）：
# export ZAI_REGION=cn

echo "===================================================="
echo "   在呢+ 打包 · v1.97.3 (build 173)"
echo "   项目目录 : $(pwd)"
echo "   flutter  : $(command -v flutter)"
echo "===================================================="
echo ""

bash build_ipa.sh

echo ""
echo "===== 打包流程结束（若上面无报错，IPA 已生成在 build/ios/ipa/）====="
# 双击运行时 stdout 是终端，则暂停以便看结果；若重定向到文件则跳过
if [ -t 1 ]; then
  read -p "按回车关闭终端窗口..."
fi
