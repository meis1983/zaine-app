#!/bin/bash
# CN 中国合规版 1.97.1 build 158 —— 在 CN 157 之上的增量修复包
# 本包构建自当前 HEAD (bf02f99 = tag v1.97.5+199)，同时包含两处修复：
#   ① CN 157 的「已签到仍收到定时签到提醒」修复（CheckInReminderService 单一真相源）：
#      - 排程前读 last_check_in_date，今日已签到则跳过闸门
#      - 去每日重复改单次排程，App 启动/前台按签到态重排
#      - 签到成功/服务端确认已签到/服务端对账已签到 → 即时 cancel(id=0/id=3)
#   ② 连续签到天数显示不一致修复（来自海外版 199 的同一 commit）：
#      弹窗前用本地真相源兜底刷新 _continuousDays，并把 today 幂等并入 checkin_history，
#      解决 already_checked_in 分支漏写 today 导致的「连点第一次 0 天、第二次 2 天」窗口期不一致
#      （此 bug 在 CN 157 上被测出，故 CN 需升 158 才能带上该修复）
# 与海外版共用同一套代码，ZAI_REGION=cn 自动：
#   1) 切换 Bundle ID com.zaine.app → com.zaine.app.cn（sed + trap 还原）
#   2) 关闭自动通知第三方亲友（dead-man switch 合规整改）
# 版本号规则：CN 版走 1.97.1 train（独立于海外 1.97.5），build 从 155 递增到 158
# 注意：.command 双击会丢 export，务必在终端手动 export 后 bash build_ipa.sh（见下方命令）
export ZAI_VERSION_NAME=1.97.1
export ZAI_BUILD_NUMBER=158
export ZAI_REGION=cn
cd "$(dirname "$0")"
bash build_ipa.sh
