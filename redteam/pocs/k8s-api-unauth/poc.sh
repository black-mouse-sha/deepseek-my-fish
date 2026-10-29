#!/usr/bin/env bash
API="${1:?usage: bash k8s.sh https://HOST:6443}"
echo '--- API 匿名访问'
curl -sk -m 8 "${API%/}/api" | head -c 200; echo
curl -sk -m 8 "${API%/}/version" | head -c 200; echo
echo '--- 容器内 SA token（在目标 shell 里执行才有意义）'
# TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
# curl -sk -H "Authorization: Bearer $TOKEN" https://kubernetes.default.svc/api/v1/namespaces/default/pods
echo '--- kubelet 10250'
K="${API%%:*}://${API#*//}"
curl -sk -m 8 "${K%%/}/pods" 2>/dev/null | head -c 200; echo
# 权限：kubectl --server="$API" --insecure-skip-tls-verify auth can-i --list
# 逃逸：create pods + hostPath / → 见技能 cloud-container
