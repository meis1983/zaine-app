#!/bin/bash
# v1.97.3 build 195 — 多账号串号根因修复（静默登录补写 user_id + 启动自修复）
# 根因：silent_login_service.performSilentLogin 只写 auth_token、漏写 user_id，
#       导致 token 身份(A) 与本地 user_id 身份(B) 分叉 → 切账号后签到/头像全写错账号。
# 改动：
#   1) silent_login_service.dart: 静默登录时从 JWT 解析 user_id 并写入 Keychain+SP（与 token 对齐）
#   2) main.dart: 启动迁移阶段按 token 真相源重新对齐 user_id（已装旧版设备无需登出重登即自愈）
#   3) 保留 194 的 [194 S] 签到诊断日志，便于验证修复生效
# 用途：双击出包 → TF 传 195 → 装包后正常切账号签到/传头像应正确落到对应账号
export ZAI_VERSION_NAME=1.97.3
export ZAI_BUILD_NUMBER=195
cd "$(dirname "$0")"
bash build_ipa.sh
