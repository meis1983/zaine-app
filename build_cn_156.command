#!/bin/bash
# CN 中国合规版 1.97.1 build 156 — ①定时确认「已签到仍提醒」根因修复(重装SP清空+already_checked_in不写key→补写双key+服务端checked_in_today兜底) ②手机端连点统计跳动(防重锁+历史条数真相源)
# 与海外版共用同一套代码，ZAI_REGION=cn 自动：
#   1) 切换 Bundle ID com.zaine.app → com.zaine.app.cn（sed + trap 还原）
#   2) 关闭自动通知第三方亲友（dead-man switch 合规整改）
# 版本号规则：CN 版走 1.97.1 train（独立于海外 1.97.4），build 从 155 递增到 156
# 注意：.command 双击会丢 export，务必在终端手动 export 后 bash build_ipa.sh（见下方命令）
export ZAI_VERSION_NAME=1.97.1
export ZAI_BUILD_NUMBER=156
export ZAI_REGION=cn
cd "$(dirname "$0")"
bash build_ipa.sh
