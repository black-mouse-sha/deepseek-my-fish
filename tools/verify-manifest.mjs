#!/usr/bin/env node
/**
 * 校验 manifest.json：逐文件比对 size + sha256。
 *
 *   node verify-manifest.mjs <manifest.json> [--quiet]
 *
 * manifest 格式（本仓库约定）:
 *   { "files": [ { "path": "相对路径", "size": 123, "sha256": "..." } ] }
 * 也兼容 { "fileCount": n, "totalBytes": n } 这类汇总字段（有就用，没有就现算）。
 */
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";

const args = process.argv.slice(2);
const quiet = args.includes("--quiet");
const manifestPath = args.find((a) => !a.startsWith("--"));

if (!manifestPath) {
  console.error("用法: node verify-manifest.mjs <manifest.json> [--quiet]");
  process.exit(1);
}

const abs = path.resolve(manifestPath);
const root = path.dirname(abs);
const manifest = JSON.parse(fs.readFileSync(abs, "utf8"));
const files = Array.isArray(manifest.files) ? manifest.files : [];

if (!files.length) {
  console.error("manifest 里没有 files 数组");
  process.exit(1);
}

function sha256(p) {
  const h = crypto.createHash("sha256");
  const fd = fs.openSync(p, "r");
  try {
    const buf = Buffer.allocUnsafe(1 << 20);
    for (;;) {
      const n = fs.readSync(fd, buf, 0, buf.length, null);
      if (!n) break;
      h.update(buf.subarray(0, n));
    }
  } finally {
    fs.closeSync(fd);
  }
  return h.digest("hex");
}

const bad = [];
let total = 0;

for (const rec of files) {
  const p = path.join(root, rec.path);
  if (!fs.existsSync(p)) {
    bad.push({ kind: "MISSING", path: rec.path });
    continue;
  }
  const st = fs.statSync(p);
  total += st.size;
  if (typeof rec.size === "number" && st.size !== rec.size) {
    bad.push({ kind: "SIZE", path: rec.path, expect: rec.size, got: st.size });
    continue;
  }
  if (rec.sha256) {
    const got = sha256(p);
    if (got !== rec.sha256) bad.push({ kind: "CHANGED", path: rec.path });
  }
}

if (!bad.length) {
  if (!quiet) {
    console.log(`✅ ${files.length} 个文件全部一致`);
    console.log(`   总大小 ${(total / 1048576).toFixed(2)} MB`);
  }
  process.exit(0);
}

console.error(`❌ ${bad.length} 个文件有问题（共校验 ${files.length} 个）`);
for (const b of bad.slice(0, 50)) {
  console.error(`   ${b.kind.padEnd(8)} ${b.path}${b.expect != null ? ` (期望 ${b.expect}, 实际 ${b.got})` : ""}`);
}
if (bad.length > 50) console.error(`   …还有 ${bad.length - 50} 个`);
process.exit(2);
