#!/bin/bash
# CN 中国合规版 1.97.1 build 157 — 彻底修复「已签到仍收到定时签到提醒」：
#   settings_page 原 zonedSchedule + matchDateTimeComponents(time) 每日重复排程 id=0(主提醒)/id=3(系统提醒)，
#   由系统准时触发无法判断「今日是否已签到」→ 即使用户早已签到(如早 8-9 点)仍会在设定时间(如 11:42 / 13:42)重复提醒；
#   重设提醒时间会再次排程 → 又收到一次。
#   修复(CheckInReminderService 单一真相源)：
#     ① 排程前读 last_check_in_date，今日已签到则跳过(闸门)；
#     ② 去每日重复改为单次排程，App 启动/前台(home_page)按签到态重排(保证次日继续提醒)；
#     ③ 签到成功/服务端确认已签到/服务端对账已签到 → 即时 cancel(id=0/id=3)。
# 与海外版共用同一套代码，ZAI_REGION=cn 自动：
#   1) 切换 Bundle ID com.zaine.app → com.zaine.app.cn（sed + trap 还原）
#   2) 关闭自动通知第三方亲友（dead-man switch 合规整改）
# 版本号规则：CN 版走 1.97.1 train（独立于海外 1.97.4），build 从 155 递增到 157
# 注意：.command 双击会丢 export，务必在终端手动 export 后 bash build_ipa.sh（见下方命令）
export ZAI_VERSION_NAME=1.97.1
export ZAI_BUILD_NUMBER=157
export ZAI_REGION=cn
cd "$(dirname "$0")"
bash build_ipa.sh
