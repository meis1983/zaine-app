#!/bin/bash
# v1.97.3 build 193 — 守护圈同步彻底诊断包
# 改动：
#   1) batchLookup 发出的 phones 全量 dump（定位「手机号格式」是否被静默归一化）
#   2) batchLookup 原始 response 全 dump（看后端是否对人返回 found=false）
#   3) 每个成员的 lastSigninAt / isActive 也 dump（用于「梅长苏-待激活」一类）
#   4) 兜底路径 lookupByPhone / queryCheckinStatus 的 raw 也 dump
# 用途：装 193 → 进一次守护圈 → 在 zaine_debug.log 搜 [193 G] → 一次性定位"同步为何不更新"真凶
export ZAI_VERSION_NAME=1.97.3
export ZAI_BUILD_NUMBER=193
cd "$(dirname "$0")"
bash build_ipa.sh
