#!/usr/bin/env node
// The web board's screens for the whiteboard walk: the Cockpit's /ink on the app's own rules (BoardWasm), staged on
// a Cockpit scratch stage (fixture data only, never :8778/:8780), shot at 390 and 1200 wide in ONE browser session.
// Run from a dir with node_modules/playwright (~/gits/idvorkin.github.io):
//   node web_shots.cjs <cockpit tree> <out dir>
// Writes <out>/shots/<state>-<width>.png and <out>/shots.json (state, width, file, facts read off the page).
"use strict";
const fs = require("fs");
const path = require("path");
const [cockpit, outDir] = process.argv.slice(2).map((p) => path.resolve(p));
const stage = require(path.join(cockpit, "scratch_stage.cjs"));
const { chromium } = require(path.join(process.cwd(), "node_modules/playwright"));

const writing = (id, y, x0 = 100, n = 17) => ({ id, w: 3, pts: Array.from({ length: n }, (_, i) => [x0 + 25 * i, y + (i % 2 ? 22 : 0), 0.5]) });
const BOARD = { v: 1, strokes: [writing("l1", 100), writing("l2", 150), writing("l3", 300), writing("l4", 350), writing("l5", 400, 140, 11)],
  objects: [], headers: [], connectors: [] };

async function settle(page) { await page.waitForTimeout(400); }

(async () => {
  fs.mkdirSync(path.join(outDir, "shots"), { recursive: true });
  const s = stage.build({ appTree: cockpit, prefix: "walk-shots-" });
  const port = await stage.freePort();
  await stage.startServer(s, port);
  const base = "http://127.0.0.1:" + port;
  for (let i = 0; i < 60; i++) { try { await stage.get(base + "/ink"); break; } catch { await stage.sleep(500); } }
  const browser = await chromium.launch();
  const rows = [];
  try {
    for (const width of [390, 1200]) {
      const ctx = await browser.newContext({ viewport: { width, height: width === 390 ? 844 : 900 }, hasTouch: true, deviceScaleFactor: 1 });
      const shoot = async (page, state, facts = {}) => {
        const file = path.join(outDir, "shots", `${state}-${width}.png`);
        await page.screenshot({ path: file });
        const errs = facts.errors || [];
        const box = await page.evaluate(() => {
          const sw = document.documentElement.scrollWidth, cw = document.documentElement.clientWidth;
          const bar = document.getElementById("bar");
          return { hscroll: sw > cw, scrollWidth: sw, clientWidth: cw, bar: bar ? bar.innerText.replace(/\s+/g, " ").slice(0, 160) : null,
            rules: window.__ink && window.__ink.rules ? { state: window.__ink.rules.state, mode: window.__ink.rules.mode } : null };
        });
        rows.push({ state, width, file, ...box, ...facts, errors: errs });
      };
      const open = async (query) => {
        const page = await ctx.newPage();
        const errors = [];
        page.on("pageerror", (e) => errors.push(String(e)));
        await page.goto(base + "/ink?b=walk-" + width + "-" + Date.now().toString(36) + query);
        await page.waitForFunction(() => window.__ink && window.__ink.loaded, null, { timeout: 60000 });
        await page.waitForFunction(() => ["wasm", "failed"].includes(window.__ink.rules.state), null, { timeout: 180000 });
        return { page, errors };
      };
      const at = (page, x, y) => page.evaluate(([x, y]) => {
        const p = document.getElementById("paper"), r = p.getBoundingClientRect(), k = p.clientWidth / window.__ink.M.PAGE_W;
        return [r.left + x * k, r.top + y * k];
      }, [x, y]);
      const synth = (page, type, c, buttons) => page.evaluate(([type, c, buttons]) => {
        const t = document.elementFromPoint(c[0], c[1]) || document.getElementById("paper");
        t.dispatchEvent(new PointerEvent(type, { bubbles: true, cancelable: true, composed: true, pointerId: 5,
          pointerType: "touch", isPrimary: true, pressure: buttons ? 0.5 : 0, buttons, clientX: c[0], clientY: c[1] }));
      }, [type, c, buttons]);

      // 1. an empty board on the wasm rules
      {
        const { page, errors } = await open("");
        await settle(page);
        await shoot(page, "empty", { errors });
        // 2. the same board with writing on it
        await page.evaluate((b) => window.__ink.setBoard(b), BOARD);
        await settle(page);
        await shoot(page, "writing", { errors });
        // 3. a press and hold on l2: the hold menu
        const c = await at(page, 300, 160);
        await synth(page, "pointerdown", c, 1);
        await page.waitForTimeout(700);
        await synth(page, "pointerup", c, 0);
        let menu = null;
        try {
          await page.waitForSelector("#menu:not([hidden])", { timeout: 3000 });
          menu = await page.$$eval("#menu button", (bs) => bs.map((b) => b.textContent.trim()));
        } catch { menu = null; }
        await settle(page);
        await shoot(page, "hold-menu", { errors, menu });
        // 4. Insert space from that menu: the room the wasm chose
        let push = null;
        if (menu && menu.some((m) => /Insert space/.test(m))) {
          await page.locator("#menu button", { hasText: "Insert space" }).click();
          await page.waitForTimeout(300);
          push = await page.evaluate(() => window.__ink.log.at(-1));
        }
        await settle(page);
        await shoot(page, "insert-space", { errors, push, stats: await page.evaluate(() => window.__ink.rules.stats) });
        await page.close();
      }
      // 5. ?debug=board: which rules answer, rows and units drawn
      {
        const { page, errors } = await open("&debug=board");
        await page.evaluate((b) => window.__ink.setBoard(b), BOARD);
        await page.waitForFunction(() => ["wasm", "failed"].includes(window.__ink.debugBoard.swift), null, { timeout: 180000 }).catch(() => {});
        await page.evaluate((b) => window.__ink.setBoard({ ...b }), BOARD);
        await settle(page);
        const panel = await page.textContent("#dbgboard").catch(() => null);
        await shoot(page, "debug-board", { errors, panel: panel && panel.split("\n").slice(0, 3).join(" | ") });
        await page.close();
      }
      await ctx.close();
    }
  } finally {
    await browser.close();
    fs.writeFileSync(path.join(outDir, "shots.json"), JSON.stringify(rows, null, 1));
    stage.teardown();
  }
  console.log(rows.map((r) => `${r.state}@${r.width} rules=${r.rules && r.rules.state} hscroll=${r.hscroll} errors=${r.errors.length}`).join("\n"));
  process.exit(0);
})().catch((e) => { console.error("shots failed: " + (e.stack || e)); try { stage.teardown(); } catch {} process.exit(2); });
