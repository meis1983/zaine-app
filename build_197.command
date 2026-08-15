#!/bin/bash
# v1.97.3 build 197 — 客户端登录归一化手机号（防幽灵账号）
# 根因：quick_login 后端不归一化手机号，带空格/+86 的号会被静默创建成重复账号
# 改动：
#   1) onboarding_page.dart: 登录前把手机号去非数字 + 剥离 86 前缀（与后端 normalize_phone 对齐）
#   【后端配套】zaine-backend auth.py quick_login/verify-and-link 已加 normalize_phone（需 deploy.sh 生效）
# 验证：清空数据后重新注册账号，切账号签到/传头像应正确落到对应账号，不再产生带空格的重复账号
export ZAI_VERSION_NAME=1.97.3
export ZAI_BUILD_NUMBER=197
cd "$(dirname "$0")"
bash build_ipa.sh
