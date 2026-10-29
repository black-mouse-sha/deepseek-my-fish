# 小工具

> 全部是纯 Node 脚本，不需要装依赖。用法：`node 脚本名.mjs [参数]`

---

## `verify-manifest.mjs`

校验一份 `manifest.json` 里的文件是否与磁盘一致（sha256）。

```bash
node tools/verify-manifest.mjs ../manifest.json
node tools/verify-manifest.mjs ../manifest.json --quiet   # 只报错
```

输出示例：

```
✅ 3614 个文件全部一致
   总大小 106.27 MB
```

或：

```
❌ 2 个文件不一致
   MISSING  02-插件/xxx/lib/index.js
   CHANGED  01-人格/AGENTS.md
```

**用途**：从别人那里拷来一份包，先校验再安装，防止传输出错。

---

## 另两个脚本没放进仓库

搬家过程中还用到两个脚本，它们**依赖本机绝对路径**（你的 `%USERPROFILE%`、
DSH 安装目录），放进公共仓库没有意义，所以留在本地。思路写在这里，你需要时自己改：

### 1. 从 `app.asar.bak` 抽官方原件

**目的**：把 `@deepseek-ai/*` 里被改动过的文件还原成官方版本。

**做法**：

1. 读 asar 索引（格式见 [docs/03-踩过的坑.md](../docs/03-踩过的坑.md) 第 1 条）
2. 枚举 DSH 关心的文件清单（插件目录下的 `lib/*.js`、`cordis.patch.yml` …）
3. 按 `offset/size` 从数据区读出原始字节
4. 存到 `backups/<时间戳>/original/`，同时把当前版本存到 `patched/`
5. 写 `manifest.json`（每个文件的 sha256 + 状态：`patched` / `identical` / `not-in-asar`）

**回滚**：把 `original/` 里的文件按原路径写回，写之前先把当前文件存成
`<文件名>.pre-restore-<时间戳>`。

### 2. 对比"当前安装"与"官方原版"

**目的**：搞清楚自己到底改了哪些文件、改了多少。

**做法**：

1. 从 `app.asar.bak` 建立"官方文件 → (size, sha256)"表
2. 遍历 `resources\app\` 建立"当前文件 → (size, sha256)"表
3. 分类：`identical` / `modified` / `added` / `removed`
4. **关键**：asar 里 `unpacked: true` 的条目（原生 `.node/.exe/.dll`）内容不在 asar 里，
   要在 `resources\app.asar.unpacked\` 下找基准，否则会被误判成"新增"

**经验数字**（DSH 0.2.1-rc.2，装 27 个插件 + 63 个补丁）：

| 项 | 数量 |
|---|---|
| 官方文件 | 18309 |
| 完全一致 | 18258 |
| 被改写 | 51（合计约 3 MB） |
| 新增 | 2（插件注入的 shim 脚本） |
| 删除 | 0 |

---

## 为什么不把这些脚本直接开源

它们里面写死了：

```js
const HOME = "C:\\Users\\<某个人>\\.dsh";
const RES  = "D:\\<某个安装位置>\\resources";
```

开源出去既是噪音，也泄露路径习惯。上面两段"做法"已经足够你自己实现。
