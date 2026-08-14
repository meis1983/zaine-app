#!/bin/bash
# v1.97.3 build 194 — 签到写库决定性诊断包
# 改动（仅 home_page.dart 签到路径，加文件级日志）：
#   1) 签到前：同时记录「本地 uid」与「JWT token 解码出的后端 uid」
#      —— 两者不一致 = 多账号切换时 token 没换，签到写到了错误的 uid
#   2) 签到时：完整记录 do_checkin 的响应（success / already_checked_in / 错误码）
# 用途：装 194 → 登录某成员账号 → 点一次签到 → 取 zaine_debug.log 搜 [194 S]
#       → 一眼看出「写到了哪个 uid / 后端返回了什么」，彻底定位同步不更新真凶
export ZAI_VERSION_NAME=1.97.3
export ZAI_BUILD_NUMBER=194
cd "$(dirname "$0")"
bash build_ipa.sh
