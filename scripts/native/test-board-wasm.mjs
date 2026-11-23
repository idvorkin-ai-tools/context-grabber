// Story 1503 (spec docs/superpowers/specs/2026-11-22-board-rules-on-the-web-design.md): the board's rules as
// WebAssembly, run under node's WASI as the Cockpit would run them. The Cockpit's recorded board sessions (vendored
// scrubbed by scripts/native/board-sessions.py) replay through the module as BoardSessionReplayTests replays them
// natively; the loaded board answers a cut the same whether it arrived whole or as new ink; failures say why.
//   node scripts/native/test-board-wasm.mjs <BoardWasm.wasm>      (just wasm-test builds it first)
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { WASI } from 'node:wasi';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const fixtures = path.join(root, 'native/ContextCore/Tests/ContextCoreTests/Fixtures/board-sessions');
const wasmPath = process.argv[2] ?? path.join(root, 'native/Build/wasm/BoardWasm.wasm');

// As BoardSessionReplayTests.changedSince: where today's board answers otherwise than the build that was recorded.
const changedSince = { 'ops-move': ['batch 49946d13484f'] };
// The one natural 32-bit midpoint flip the spike found (spec, Precision): on title-build's last board, y = 100 is the
// exact middle of the row from 38.425 to 161.575. In 32 bits the way up is shorter, so the cut lands on the row's top;
// the iPad's 64-bit rules land on its bottom. A change here means the rules or the toolchain changed.
const pinned = { session: 'title-build', y: 100, cut: Math.fround(38.425) };

const wasi = new WASI({ version: 'preview1', args: [], env: {}, returnOnExit: true });
const module = await WebAssembly.compile(fs.readFileSync(wasmPath));
const instance = await WebAssembly.instantiate(module, wasi.getImportObject());
wasi.initialize(instance);
const x = instance.exports;
const encoder = new TextEncoder();
const decoder = new TextDecoder();

/** A reply: four bytes of length, little-endian, then UTF-8. Freed once read. */
function read(pointer) {
  if (!pointer) return null;
  const length = new DataView(x.memory.buffer).getUint32(pointer, true);
  const text = decoder.decode(new Uint8Array(x.memory.buffer, pointer + 4, length));
  x.bw_free(pointer);
  return text;
}
/** Calls an export taking (pointer, length) with the text written into the module's memory, then frees it. */
function call(name, text) {
  const bytes = encoder.encode(typeof text === 'string' ? text : JSON.stringify(text));
  const pointer = x.bw_alloc(bytes.length);
  new Uint8Array(x.memory.buffer, pointer, bytes.length).set(bytes);
  const result = x[name](pointer, bytes.length);
  x.bw_free(pointer);
  return result;
}
const error = () => read(x.bw_error());

let passed = 0;
const failures = [];
function check(ok, what) {
  if (ok) passed++;
  else failures.push(what);
}

// The interface's version and sizes.
const info = JSON.parse(read(x.bw_info()));
check(info.abi === 1, `bw_info abi is 1: ${JSON.stringify(info)}`);
check(info.contract === 1 && info.line === 40 && info.near === 80, `bw_info contract, line, near: ${JSON.stringify(info)}`);
check(info.cgfloat_bits === 32, `bw_info says the rules' arithmetic is 32-bit: ${info.cgfloat_bits}`);

// Nothing loaded: NaN, and why.
check(Number.isNaN(x.bw_cut_y(100)), 'a cut with nothing loaded is NaN');
check(error() === 'no board is loaded', 'and bw_error says no board is loaded');
check(call('bw_add_strokes', { strokes: [] }) === -1 && error() === 'no board is loaded', 'no new ink without a board');

const names = Object.keys(JSON.parse(fs.readFileSync(path.join(fixtures, 'SOURCE.json'), 'utf8')).sessions).sort();
check(names.length === 4, `four recorded sessions: ${names}`);
const lastBoards = {};

for (const name of names) {
  const jsonl = fs.readFileSync(path.join(fixtures, `${name}.jsonl`), 'utf8');
  const golden = JSON.parse(fs.readFileSync(path.join(fixtures, `${name}.golden.json`), 'utf8')).contexts;
  const report = JSON.parse(read(call('bw_replay', jsonl)));
  if (report.error) {
    failures.push(`${name}: ${report.error}`);
    continue;
  }
  // testEverySessionIsContractOneAndReplaysAsRecordedButForWhatChangedSince
  const known = changedSince[name] ?? [];
  check(report.contract === 1 && report.name === name, `${name}: contract 1, named ${report.name}`);
  check(report.turns.length > 0, `${name}: has turns`);
  const unexpected = report.mismatches.filter((m) => !known.some((k) => m.startsWith(k)));
  check(unexpected.length === 0 && report.mismatches.length === known.length, `${name}: mismatches ${JSON.stringify(report.mismatches)}`);
  // testEachTurnCarriesWhatTheCockpitsRecordedHintToldLarry
  const ids = report.turns.map((t) => t.id).sort();
  check(JSON.stringify(ids) === JSON.stringify(Object.keys(golden).sort()), `${name}: the same turns as the golden`);
  for (const turn of report.turns) {
    if (turn.onBoard) check((golden[turn.id] ?? '').endsWith(' ' + turn.hint), `${name} ${turn.id}: hint is the end of the recorded one`);
    else check(!(golden[turn.id] ?? '').includes('· board '), `${name} ${turn.id}: words alone`);
  }
  if (name === 'ops-move') {
    // testABatchAfterIgorDrewOnceMoreNowAppliesWhereTheRecordedBuildRefusedIt
    const [first, last] = [report.batches[0], report.batches.at(-1)];
    check(report.batches.length === 2, 'ops-move: two batches');
    check(first.arrivedAt === 257 && first.recordedOk === false && first.replayedOk === true && !first.matches,
      `ops-move: the stale batch now applies ${JSON.stringify(first)}`);
    check(last.recordedOk === null && last.replayedOk === true, `ops-move: the resend applies ${JSON.stringify(last)}`);
  }
  if (name === 'question-card') {
    // testADeleteWhileIgorKeptWritingAppliesRebasedFromHisLook
    const first = report.batches[0];
    check(first.replayedOk === true && first.matches === true, `question-card: the delete applies as recorded ${JSON.stringify(first)}`);
  }
  for (const line of jsonl.split('\n')) {
    if (!line.trim()) continue;
    const step = JSON.parse(line);
    if (step.step === 'post' && step.route === '/whiteboard/strokes') lastBoards[name] = step.body;
  }
}

// The board stays loaded: whole, or half and then the rest as new ink, it answers every cut the same.
for (const name of names) {
  const board = lastBoards[name];
  if (!board) {
    failures.push(`${name}: no board posted`);
    continue;
  }
  const maxY = Math.max(...board.strokes.flatMap((s) => (s.points ?? [[0, s.y + (s.h ?? 0)]]).map((p) => p[1]))) + 100;
  const ys = [];
  for (let y = -20; y <= maxY; y += 1.5) ys.push(y);
  const whole = call('bw_load', board);
  check(whole > 0, `${name}: loads (${whole} boxes) ${error() ?? ''}`);
  const cuts = ys.map((y) => x.bw_cut_y(y));
  check(cuts.every((c, i) => c === ys[i] || Math.abs(c - ys[i]) <= info.near + 1e3), `${name}: every cut is a number`);
  const half = Math.floor(board.strokes.length / 2);
  const first = call('bw_load', { ...board, strokes: board.strokes.slice(0, half) });
  const added = call('bw_add_strokes', { strokes: board.strokes.slice(half) });
  check(first >= 0 && added === whole, `${name}: in two halves, ${first} then ${added} boxes (whole: ${whole})`);
  const again = ys.map((y) => x.bw_cut_y(y));
  const differ = ys.filter((y, i) => !Object.is(cuts[i], again[i]));
  check(differ.length === 0, `${name}: ${ys.length} cuts the same whole and in halves (differ at ${differ.slice(0, 5)})`);
  // A stroke it can't read leaves the board as it was.
  check(call('bw_add_strokes', { strokes: [{ points: [[0, 0]] }] }) === -1 && /no id/.test(error() ?? ''), `${name}: a stroke with no id is refused, saying why`);
  check(Object.is(x.bw_cut_y(ys[ys.length >> 1]), again[ys.length >> 1]), `${name}: and the board is as it was`);
  if (name === pinned.session) {
    const cut = x.bw_cut_y(pinned.y);
    check(cut === pinned.cut, `${name}: the 32-bit midpoint case, cut at ${pinned.y} lands on ${cut} (pinned ${pinned.cut})`);
  }
}

// A board it can't read: -1, why, and nothing loaded after.
check(call('bw_load', 'not json') === -1 && /could not be read/.test(error() ?? ''), 'an unreadable board is refused, saying why');
check(Number.isNaN(x.bw_cut_y(0)), 'and nothing is loaded after it');

for (const f of failures) console.log(`FAIL ${f}`);
console.log(`${failures.length ? 'FAIL' : 'ok  '} board wasm: ${passed} checks passed, ${failures.length} failed (${names.length} recorded sessions, ${(fs.statSync(wasmPath).size / 1e6).toFixed(1)} MB module)`);
process.exitCode = failures.length ? 1 : 0;
