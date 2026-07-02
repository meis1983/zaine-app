#!/bin/bash
# 在呢+ v1.93.0 Git 提交脚本
# 请在 Terminal.app 中运行此脚本（不在 WorkBuddy 内运行）
cd /Users/meixulin/Desktop/zaine-app/zaine_app

# 清除可能的 lock 文件
rm -f .git/index.lock

# 提交所有改动
git add -A
git commit -m "v1.93.0+93: 跌倒检测方案B+C-2 + 位置共享方案A+B + Watch SOS修复

- 跌倒确认对话框（60秒倒计时+自动通知守护者）
- 医疗数据集成（通知携带心率/血氧/体温/血压）
- 位置追踪三档模式（实时/普通/省电）+ 轨迹缩略图
- 安全围栏（家/公司/自定义 + 离开通知守护者）
- Watch SOS修复（MethodChannel即时通知Flutter端）"

# 打标签
git tag v1.93.0

# 推送到远程
git push origin feature/v1.0-flag
git push origin v1.93.0

echo "✅ 完成！现在可以在 Xcode 中 Archive 并上传 TestFlight"
echo "   或直接运行: xcodebuild -archive ..."
