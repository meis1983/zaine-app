#!/bin/bash
# 海外版 1.97.5 build 199 —— 多语言开发基线 + 综合修复出包
# 包含：
#   ① CN 157 的「已签到仍收到定时签到提醒」修复（CheckInReminderService 单一真相源）：
#      - 排程前读 last_check_in_date，今日已签到则跳过闸门
#      - 去每日重复改单次排程，App 启动/前台按签到态重排
#      - 签到成功/服务端确认已签到/服务端对账已签到 → 即时 cancel(id=0/id=3)
#   ② 连续签到天数显示不一致修复（v1.97.5+199）：
#      弹窗前用本地真相源兜底刷新 _continuousDays，并把 today 幂等并入 checkin_history，
#      解决 already_checked_in 分支漏写 today 导致的「连点第一次 0 天、第二次 2 天」窗口期不一致
#   ③ 本包作为后续多语言开发原始基线（第一阶段优先：中文繁体 zh-TW/zh-HK + 英文 en）
# 海外版 = 全功能版：保持 Bundle ID com.zaine.app（**不**设置 ZAI_REGION=cn，不切包、不关自动通知）
# 版本号策略：1.97.5 开新 train（i18n 架构准备 = 重大升级，按版本铁律开新 train），build 199
# 注意：.command 双击会丢 export，务必在终端手动 export 后 bash build_ipa.sh（见下方命令）
export ZAI_VERSION_NAME=1.97.5
export ZAI_BUILD_NUMBER=199
# 海外版不 export ZAI_REGION → 默认 global（全功能版，不切 Bundle ID、不关自动通知）
cd "$(dirname "$0")"
bash build_ipa.sh
