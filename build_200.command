#!/bin/bash
# v1.97.5 build 200 — 多语言全量补全出海包（新 train）
# 改动：
#   1) Stage 0-5 多语言基建 + 语言切换 UI/持久化（LocaleNotifier + 设置页语言项）
#   2) Stage 6 翻译补全：en 全翻 1093 键 + zh_TW(地道台湾体 s2twp) / zh_HK(香港体 s2hk) 精翻
#   3) flutter analyze 0 error；gen-l10n 全量通过；CN 锁 zh-CN 零回归
# 区域：global（海外全功能版，不传 ZAI_REGION → 跟随系统语言 + 语言切换可用）
# ⚠️ 版本号/train 须与最终决定一致（防 ASC 409 train 关闭）；build 200 须 > 已上传号(198)
# 运行：在本机 Terminal 执行 `bash build_200.command`（勿在 WorkBuddy 终端跑）
export ZAI_VERSION_NAME=1.97.5
export ZAI_BUILD_NUMBER=200
cd "$(dirname "$0")"
bash build_ipa.sh
