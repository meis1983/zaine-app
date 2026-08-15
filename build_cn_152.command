#!/bin/bash
# CN 中国合规版 V1.1 build 152 — 多账号串号 + 手机号归一化 根因修复（与海外 1.97.4 同源码）
# 与海外版共用同一套代码，ZAI_REGION=cn 自动：
#   1) 切换 Bundle ID com.zaine.app → com.zaine.app.cn（sed + trap 还原）
#   2) 关闭自动通知第三方亲友（dead-man switch 合规整改）
# 版本号规则：CN 版走 V1.x 线（独立于海外 1.97.x），build 从 151 递增到 152
export ZAI_VERSION_NAME=V1.1
export ZAI_BUILD_NUMBER=152
export ZAI_REGION=cn
cd "$(dirname "$0")"
bash build_ipa.sh
