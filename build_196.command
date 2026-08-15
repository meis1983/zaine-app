#!/bin/bash
# v1.97.3 build 196 — 多账号串号根因修复（登录/登出清除残留静默登录凭证）
# 根因：download 链接的静默登录凭证 pending_token 在 quickLogin/verifyAndDownload/
#       logout/Apple登录 时均未清除 → 残留后下次启动静默登录用陈旧 token 覆盖
#       本次刚登录的正确 token → 切账号后成员签到/头像全写错账号。
# 改动（auth_service.dart 5 处）：
#   1) quickLogin 成功后 clearPendingLogin()
#   2) verifyAndDownload 成功后 clearPendingLogin()
#   3) logout 时 clearPendingLogin()
#   4) Apple 登录成功后 clearPendingLogin()
#   5) 新增 import silent_login_service
# 验证：装 196 → 登出 → 重新登录主账号 → 切成员账号签到/传头像 → 回主账号看是否同步
export ZAI_VERSION_NAME=1.97.3
export ZAI_BUILD_NUMBER=196
cd "$(dirname "$0")"
bash build_ipa.sh
