---
name: score-and-report
description: 得分点映射与结项报告：把成果对到《突破入侵类得分规则（合并版）》的 code/档位/口径上，规避漏分与错分，产出可复现报告
whenToUse: 拿到成果要记分时；用户问进度/要报告时；收工前核对"该记的分有没有漏、记的分站不站得住"
role: plan
enabled: true
---

# 记分与结项报告（指挥自己的活）

**没记的分等于没拿，乱记的分等于没做**。这一条只管两件事：把成果**对到规则上**，
把过程**写成能复现的报告**。

## 一、记分前必读（不要凭记忆写 code）

```text
redteam_score_list            # 实际 code / 分值 / 上限 / 计分口径（dedup_scope）
→ 对照成果选 code + points（多档条目必须填 points）
→ redteam_score_hit
```

规则是**25 项 + 8 条通用规则**：一、获取权限 21 项；二、突破网络边界 4 项；类别 8 个
（GENERAL / WEB / CENTRAL / BIGDATA / NETINFRA / STORAGE / MODEL / BOUNDARY）。

常用 code 速查（**以 `redteam_score_list` 的实际值为准**）：

| 成果 | code（示例） | 备注 |
| --- | --- | --- |
| 服务器主机 / WebShell 权限 | `server-host` | 普通 10 / 管理员 50，按 points 填档 |
| 数据库账号密码（含 SQL 注入） | `db-credential` | 同一服务只算最高一条 |
| 邮箱 / OA / 业务系统权限 | `web-app` | 账号类要实测能登录 |
| 集权系统（运维/身份/组网/终端管理） | `central-system` | 高分项，一台顶一片 |
| 大数据系统 | `bigdata-system` | 数据量翻倍（G5）要看实际条数 |
| 网络设备（防火墙/交换机/VPN） | `netdev` | 普通 100 / 管理员 200 |
| 云管理平台 / K8S / OpenShift | `cloud-platform` | 含 PaaS 控制台 |
| 算力管理平台 / 训练数据与知识库系统 | `model-compute` | 与 `model-data` 口径不同，别混 |
| 进入逻辑隔离 / 强隔离 / 物理隔离内网 | `boundary-logical` / `boundary-strong` / `boundary-physical` | 整个目标只算一次（G3） |

## 二、三条红线（记错了整份报告作废）

1. **账号必须实测登录**：只有凭据不算拿到账号。用 `browser-automation` / `kimi-webbridge`
   真登进后台、能交互访问页面，才记账号分；登不进写进 `redteam_asset_test` 的 `test`。
2. **自建账号不计分**：自己注册、自己创建的后台账号/角色/权限，一律 `self_created=true`，
   只留过程轨迹，不进报告。
3. **口径必须遵守**：每条自带 `dedup_scope`
   - `service`（同一资产+端口只算最高一条）、`system`、`target`（整个目标一次）、
     `device`（按台/卡/个累加）；
   - 每条有上限，`redteam_score_hit` 返回里的 `warning`（"已达上限/已被顶掉"）就是**停止信号**，
     换条目或换资产，不要在同一条上反复刷。

## 三、通用规则怎么用（G1–G8）

| 规则 | 落地做法 |
| --- | --- |
| G1 权限取高、只计一次 | 先记普通档、后来提到管理员 → **再记一条高档 points**，系统自动顶掉旧条 |
| G2 数据成果另行计分 | 权限分与数据分**分开记**；`evidence` 必须写实际条数（`导出 1,320,000 条`） |
| G3 上限口径 | 到上限就换方向；`boundary-*` 整个目标只算一次 |
| G4 按台计分 | 终端/云节点/算力卡按台数累加，**每台要单独一条**，别合并成一条 |
| G5 数据规模翻倍 | 超 1 亿条 / 10TB，或控制知识库相关系统 → ×2，`evidence` 写清规模依据 |
| G6 IPv6 倍数 | 目标走 IPv6 时按规则倍数，`target` 写成 IPv6 地址形式 |
| G7 证明材料 | 每条要能复现：目标 → 拿到什么 → 怎么拿到（命令）→ 原始请求 |
| G8 兜底条款 | 规则没覆盖的新形态，用 `redteam_score_point_save` 自建一条（builtin=0），并在报告里说明 |

## 四、最常见的五个漏分/错分

1. **`target` 没带端口** → 口径按"服务"判定时算不出来，被合并甚至丢弃。永远写 `10.0.0.5:8080`。
2. **只记了漏洞没记权限** → `redteam_vuln_add` 是"发现了什么"，`redteam_score_hit` 才是"拿到了什么"。
3. **隧道写成 self-only** → 自己的 VPS 上开的代理不算隧道；`entry_kind` 要写清目标侧那一端。
4. **数据量没统计** → 只写"导出用户表"拿不到大数据分；必须有 `count(*)` 或文件行数。
5. **WebShell 没实测** → 用户连不上的马不算入口；冰蝎/哥斯拉实测连接后才记 `server-host`。

## 五、报告口径（用户要报告时照这个写）

```text
一、目标与范围        单位名 / 域名 / 网段（与靶标库一致）
二、当前阶段          ①信息收集 → ②互联网资产权限 → ③边界突破 → ④内网资产权限 → ⑤靶标权限
三、得分总览          已得 X / 满分 Y（redteam_score_list 真实数字），按类别分组
四、成果清单          每条：目标(带端口) → 拿到什么 → 怎么拿到(关键命令) → 原始请求 → 分值
五、入口与资源         WebShell（类型/地址/口令）、隧道（监听地址/可达网段）、凭据（账号/权限级别）
六、边界与隔离         进了哪层内网（逻辑/强隔离/物理），依据是什么
七、未完成与风险       打不动的点、被封禁、需要用户提供的资源
八、附件              runs/ 下的请求响应、截图、导出文件清单
```

生成方式：

```text
redteam_attack_chain      # 按阶段拉攻击链路（含步骤 tool/result）
redteam_score_report      # 计分报表（含每条得分对应的漏洞与请求）
redteam_report            # 完整报告正文
node scripts/export-engagement-report.mjs <engagement> <out.md>   # 导出到文件
```

## 六、收工前复核清单（逐条打勾）

- [ ] 每个"拿到"都有 `redteam_score_hit`，`target` 带端口，`evidence` 只写结果不写过程；
- [ ] 账号类都实测登录过（截图/响应在 `runs/`），自建账号都标了 `self_created=true`；
- [ ] 每条得分能追到一个漏洞（`vuln_id`）或一个攻击步骤（`step_id`）；
- [ ] 数据类得分有真实条数/体积；
- [ ] 隧道 `entry_kind` 不是 self-only；WebShell 有类型与口令；
- [ ] 同一服务/系统没有重复计分（`redteam_score_list` 看 warning）；
- [ ] 每个资产都有 `redteam_asset_test` 回写（谁测的、测了什么、结论）；
- [ ] 报告里"打通了"与"待验证"分开写，不把疑似当成果。
