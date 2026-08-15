#!/bin/bash
# v1.97.4 build 198 — 海外版收口（多账号串号 + 手机号归一化 根因彻底修复）
# 本版本包含 191~197 全部修复：
#   191 头像如实反馈 / 签到时效四重机制 / Watch 心跳克制
#   192 生命体征守护 initState 即加载 + 修 191 回归(手表健康速览空白)
#   193-194 守护圈同步诊断日志
#   195 静默登录补写 user_id + 启动按 token 自修复
#   196 登录/登出清除残留静默登录凭证 pending_token（防陈旧 token 覆盖）
#   197 客户端登录归一化手机号（配合后端 normalize_phone）
# 根因：quick_login 不归一化手机号 + 查不到就建新账号 → 切账号产生带空格的幽灵账号
export ZAI_VERSION_NAME=1.97.4
export ZAI_BUILD_NUMBER=198
cd "$(dirname "$0")"
bash build_ipa.sh
