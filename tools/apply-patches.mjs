#!/usr/bin/env node
/**
 * apply-patches.mjs —— 精确地对「你真正在用的那份 @deepseek-ai」打补丁。
 *
 * 为什么不用 `dsh-purge --apply`：
 *   那个命令会枚举所有能找到的宿主（包括备份目录里的副本），
 *   在 node 子进程里可能挑错对象。这里只认一个明确路径。
 *
 * 用法：
 *   node apply-patches.mjs                 # 自动探测安装目录并在干跑后应用
 *   node apply-patches.mjs --dry           # 只检测，不改文件
 *   node apply-patches.mjs --ai-base "X:\...\resources\app\dsh\node_modules\@deepseek-ai"
 *   node apply-patches.mjs --dsh-home "C:\Users\你\.dsh"
 *
 * 退出码：0 成功 / 2 找不到安装目录 / 3 找不到 dsh-purge 插件 / 4 补丁失败
 */
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { pathToFileURL } from "node:url";

const argv = process.argv.slice(2);
const has = (f) => argv.includes(f);
const opt = (f) => {
  const i = argv.indexOf(f);
  return i >= 0 ? argv[i + 1] : undefined;
};
const DRY = has("--dry");

const DSH_HOME = opt("--dsh-home") || process.env.DSH_HOME || path.join(os.homedir(), ".dsh");
const say = (s) => console.log(s);

function log(level, msg) {
  const mark = level === "ok" ? "  ✓" : level === "warn" ? "  ⚠" : level === "skip" ? "  -" : "  ✗";
  say(`${mark} ${msg}`);
}

function isAiBase(p) {
  try {
    return !!p && fs.statSync(path.join(p, "dsh-agent-instructions", "lib", "index.js")).isFile();
  } catch {
    return false;
  }
}

/** 找出真正在用的 @deepseek-ai 目录 */
function detectAiBase() {
  const given = opt("--ai-base") || process.env.DSH_PURGE_AI_BASE;
  if (given) return { dir: path.normalize(given), from: "参数/环境变量" };

  const envBase = process.env.DSH_BASE;
  if (envBase) return { dir: path.normalize(envBase), from: "DSH_BASE" };

  // 1) 桌面安装记录
  const installFile = path.join(DSH_HOME, "dsh-purge", "desktop-install.txt");
  const roots = [];
  if (fs.existsSync(installFile)) {
    const root = fs.readFileSync(installFile, "utf8").trim().replace(/[\\/]+$/, "");
    if (root) roots.push({ root, from: "desktop-install.txt" });
  }

  // 2) 常见安装位置
  for (const p of [
    process.env.LOCALAPPDATA && path.join(process.env.LOCALAPPDATA, "Programs", "DeepSeek Harness"),
    process.env.PROGRAMFILES && path.join(process.env.PROGRAMFILES, "DeepSeek Harness"),
    process.env["PROGRAMFILES(X86)"] && path.join(process.env["PROGRAMFILES(X86)"], "DeepSeek Harness"),
    "D:\\Downloads\\dsh",
  ]) {
    if (p && fs.existsSync(p)) roots.push({ root: p, from: "常见路径" });
  }

  for (const { root, from } of roots) {
    for (const rel of [
      ["resources", "app", "dsh", "node_modules", "@deepseek-ai"],
      ["resources", "app.asar", "dsh", "node_modules", "@deepseek-ai"],
      ["resources", "app", "node_modules", "@deepseek-ai"],
    ]) {
      const dir = path.join(root, ...rel);
      if (isAiBase(dir)) return { dir, from };
    }
  }

  // 3) profiles 下的 npm 安装
  const profiles = path.join(DSH_HOME, "profiles");
  if (fs.existsSync(profiles)) {
    for (const name of fs.readdirSync(profiles)) {
      const dir = path.join(profiles, name, "node_modules", "@deepseek-ai");
      if (isAiBase(dir)) return { dir, from: `profiles/${name}` };
    }
  }
  return null;
}

/** 找已安装的 dsh-purge 插件（提供补丁定义） */
function detectPurgeLib() {
  const cands = [
    path.join(DSH_HOME, "plugins", "dsh-purge", "lib", "core.js"),
    path.join(DSH_HOME, "profiles", "desktop", "node_modules", "dsh-purge", "lib", "core.js"),
  ];
  for (const p of cands) if (fs.existsSync(p)) return p;
  if (fs.existsSync(profiles_scan())) return profiles_scan();
  return null;
}
function profiles_scan() {
  const profiles = path.join(DSH_HOME, "profiles");
  if (!fs.existsSync(profiles)) return "";
  for (const name of fs.readdirSync(profiles)) {
    const p = path.join(profiles, name, "node_modules", "dsh-purge", "lib", "core.js");
    if (fs.existsSync(p)) return p;
  }
  return "";
}

async function main() {
  say("");
  say("==============================================");
  say("  打补丁（精确指向你要用的那份安装）");
  say("  DSH_HOME: " + DSH_HOME);
  say("==============================================");

  const host = detectAiBase();
  if (!host) {
    log("fail", "没找到 @deepseek-ai 目录");
    say("       桌面安装的话，先启动一次 DSH；或用 --ai-base 手动指定：");
    say('       --ai-base "X:\\你的安装目录\\resources\\app\\dsh\\node_modules\\@deepseek-ai"');
    process.exit(2);
  }
  log("ok", `宿主: ${host.dir}  (来源: ${host.from})`);

  const corePath = detectPurgeLib();
  if (!corePath) {
    log("fail", "没找到 dsh-purge 插件（补丁定义在它里面）");
    say("       请先安装插件 dsh-purge，或者在应用里的 dsh-purge 面板点「应用」。");
    process.exit(3);
  }
  log("ok", `补丁定义: ${path.dirname(path.dirname(corePath))}`);

  const core = await import(pathToFileURL(corePath).href);
  const aiBase = host.dir;

  if (DRY) {
    const state = await core.patchStatus(aiBase);
    let applied = 0, pending = 0;
    for (const p of core.ALL_PATCHES) {
      const s = state[p.id];
      if (s === "applied") applied += 1;
      else if (s === "pending") pending += 1;
    }
    log("ok", `干跑：已应用 ${applied} / 待应用 ${pending} / 总计 ${core.ALL_PATCHES.length}`);
    return;
  }

  say("");
  say("  备份原件…");
  await core.backupAll(aiBase);

  say("  应用补丁…");
  const report = await core.applyPatches(aiBase, core.ALL_PATCHES, {
    preserveClientBundles: false,
    forApply: true,
  });

  const tally = {};
  for (const r of report) tally[r.status] = (tally[r.status] || 0) + 1;
  for (const [k, v] of Object.entries(tally)) say(`    ${k.padEnd(16)} ${v}`);

  const failed = report.filter((r) => r.status === "failed" || r.status === "read_error");
  const applied = report.filter((r) => r.status === "applied" || r.status === "already");
  say("");
  log(failed.length ? "fail" : "ok", `成功 ${applied.length} 项${failed.length ? `，失败 ${failed.length} 项` : "，没有失败"}`);
  if (failed.length) {
    for (const f of failed.slice(0, 5)) log("fail", `#${f.patch_id} ${f.name}: ${f.status}`);
    process.exit(4);
  }
  say("");
  say("  完成。完全退出 DSH 再打开，补丁才生效。");
}

main().catch((e) => {
  console.error("[apply-patches] 出错:", e && e.message ? e.message : e);
  process.exit(1);
});
