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
check(info.abi === 4, `bw_info abi is 4: ${JSON.stringify(info)}`);
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
  check(cuts.every((c, i) => Number.isFinite(c) && c >= ys[i] - info.near), `${name}: every cut is the height, below it, or at most near above it`);
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
  check(call('bw_add_strokes', { strokes: {} }) === -1 && /no strokes list/.test(error() ?? ''), `${name}: strokes that are not a list are refused, saying why`);
  check(Object.is(x.bw_cut_y(ys[ys.length >> 1]), again[ys.length >> 1]), `${name}: and the board is still as it was`);
  if (name === pinned.session) {
    const cut = x.bw_cut_y(pinned.y);
    check(cut === pinned.cut, `${name}: the 32-bit midpoint case, cut at ${pinned.y} lands on ${cut} (pinned ${pinned.cut})`);
  }
}

// A board built by hand, so each kind of box is there: a line of ink, a hidden stroke (left out), a kept text, and two
// strokes Larry grouped (one box across the gap between them).
const line = (id, y, extra = {}) => ({ id, points: [[0, y], [200, y]], width: 4, ...extra });
const hand = {
  board: 'hand',
  strokes: [
    line('ink', 100),
    line('hidden', 300, { hidden: true }),
    { id: 'text', kind: 'text', x: 0, y: 200, w: 100, h: 40, t: 1000 },
    line('g1', 400, { width: 2, meta: { group: 'g' } }),
    line('g2', 480, { width: 2, meta: { group: 'g' } }),
  ],
};
check(call('bw_load', hand) === 3, `by hand: three boxes (ink, text, the group) ${error() ?? ''}`);
const handCuts = { 99: 98, 210: 200, 230: 240, 300: 300, 350: 350, 430: 399, 470: 481 };
for (const [y, cut] of Object.entries(handCuts)) {
  check(x.bw_cut_y(Number(y)) === cut, `by hand: a cut at ${y} lands on ${cut}, not ${x.bw_cut_y(Number(y))}`);
}
// A kept text is told from another by its time, as on the iPad: two with their own t are two boxes; two without are
// taken for one text's glyphs (spec, a kept text carries its t).
const text = (id, y, t) => ({ id, kind: 'text', x: 0, y, w: 100, h: 40, ...(t ? { t } : {}) });
check(call('bw_load', { board: 'texts', strokes: [text('a', 0, 1000), text('b', 100, 2000)] }) === 2, 'two kept texts with their own t: two boxes');
check(call('bw_load', { board: 'texts', strokes: [text('a', 0), text('b', 100)] }) === 1, 'two kept texts with no t: one box');

// A board it can't read: -1, why, and nothing loaded after.
check(call('bw_load', 'not json') === -1 && /could not be read/.test(error() ?? ''), 'an unreadable board is refused, saying why');
check(Number.isNaN(x.bw_cut_y(0)), 'and nothing is loaded after it');

// Interface 2, story 1508 (spec, rows and folds): the outline, held apart from the board, answers the row a tap is on and what a
// header folds. Built by hand so every number is worked out: a header at 100, two indented lines under it, a line back
// at the header's indent at 300 (which ends its section) and a kept text at 400.
const reply = (pointer) => JSON.parse(read(pointer));
const ask = (name, body) => reply(call(name, body));
check(reply(x.bw_row_at(100)).error === 'no outline is loaded', 'a row with no outline says none is loaded');
check(ask('bw_fold', { id: 'H' }).error === 'no outline is loaded', 'a fold with no outline says none is loaded');
check(call('bw_outline_add', { strokes: [] }) === -1 && error() === 'no outline is loaded', 'no new outline ink without an outline');
const outline = {
  strokes: [line('h1', 100), { ...line('b1', 140), points: [[60, 140], [200, 140]] },
    { ...line('b2', 180), points: [[60, 180], [200, 180]] }, line('n', 300)],
  boxes: [{ id: 't', box: [0, 400, 100, 440] }],
  groups: { t: 't' },
  headers: [{ id: 'H', ids: ['h1'] }],
};
check(call('bw_outline_load', outline) === 5, `the outline: four strokes and a box ${error() ?? ''}`);
const rowAt = (y) => reply(x.bw_row_at(y)).row;
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
check(same(rowAt(100), { bottom: 102, header: 'H', top: 98 }), `the header's row at 100: ${JSON.stringify(rowAt(100))}`);
check(same(rowAt(119), { bottom: 102, header: 'H', top: 98 }), 'within half a line below it, still the header');
check(same(rowAt(140), { bottom: 142, names: ['b1'], top: 138 }), `a line of ink at 140: ${JSON.stringify(rowAt(140))}`);
check(rowAt(250) === null, `blank paper at 250: ${JSON.stringify(rowAt(250))}`);
check(same(rowAt(420), { bottom: 440, names: [], top: 400 }), `a kept text is no one's ink: ${JSON.stringify(rowAt(420))}`);
// The fold: b1 and b2 tuck under H; the rest slides up to a line under the header in whole lines (300 - 102 = 198, four
// lines down less one = 120); two lines hidden; the section ended 80 under the header row.
const folded = { fold: { bottom: 80, ids: ['b1', 'b2'], lines: 2, own: ['b1', 'b2'], shift: 120 } };
check(same(ask('bw_fold', { id: 'H' }), folded), `folding H: ${JSON.stringify(ask('bw_fold', { id: 'H' }))}`);
check(same(ask('bw_fold', { id: 'H' }), folded) && same(rowAt(140), { bottom: 142, names: ['b1'], top: 138 }), 'asking leaves the outline as it was');
check(same(ask('bw_fold', { id: 'nobody' }), { fold: null }), 'no such header: nothing to fold');
check(ask('bw_fold', {}).error === 'no header id', 'a fold with no id says so');
// New ink at the end, and ink it can't read.
check(call('bw_outline_add', { strokes: [line('n2', 340)] }) === 6, `new ink at 340 ${error() ?? ''}`);
check(same(rowAt(340), { bottom: 342, names: ['n2'], top: 338 }), `and its row: ${JSON.stringify(rowAt(340))}`);
check(call('bw_outline_add', { strokes: [{ points: [[0, 0]] }] }) === -1 && /no id/.test(error() ?? ''), 'outline ink with no id is refused, saying why');
check(call('bw_outline_add', { strokes: [{ id: 'z', points: [] }] }) === -1 && /no points/.test(error() ?? ''), 'outline ink with no points is refused, saying why');
check(same(rowAt(340), { bottom: 342, names: ['n2'], top: 338 }) && call('bw_outline_add', { strokes: [] }) === 6, 'and the outline is as it was');
check(call('bw_outline_load', { boxes: [{ id: 't', box: [0, 400, 100, 440] }] }) === 1 && same(rowAt(420), { bottom: 440, names: [], top: 400 }), `a box with no group is still no one's ink: ${JSON.stringify(rowAt(420))}`);
check(call('bw_outline_load', { boxes: [{ id: 'b', box: [0, 0] }] }) === -1 && /\[left, top, right, bottom\]/.test(error() ?? ''), 'a box with no four sides is refused, saying why');
check(call('bw_outline_load', { headers: 'nope' }) === -1 && /headers could not be read/.test(error() ?? ''), 'headers that are not a list are refused, saying why');
check(reply(x.bw_row_at(100)).error === 'no outline is loaded', 'and nothing is loaded after it');
// The outline is apart from the board: bw_load's board still answers cuts.
check(call('bw_load', hand) === 3 && x.bw_cut_y(99) === 98, 'the board and the outline are held apart');

// Interface 3, story 1513 (spec, paste and drop): where a paste lands and the room a drop opens, over the hand board
// above (its boxes: the line at 98..102 across -2..202, the text at 200..240 across 0..100, the group at 399..481).
// Worked by hand from the spec's rules: a clear patch with half a line of air round it nearest the view's middle, on a
// 20-point grid from the margin's air (84); else room at the clear line nearest the view's middle.
check(same(reply(x.bw_place(100, 40, 0, 0, 820, 1000)), { push: null, x: 364, y: 480 }),
  `a paste in a clear view lands nearest its middle: ${read(x.bw_place(100, 40, 0, 0, 820, 1000))}`);
// A view with no room for it, 90..130: the middle (110) is clear, the blank band runs from the line (102) to the text
// (200), 98 points, and it lands a half line under the line, at the margin's air.
check(same(reply(x.bw_place(100, 40, 0, 90, 820, 130)), { push: null, x: 84, y: 122 }),
  `no clear patch, but blank paper enough: ${read(x.bw_place(100, 40, 0, 90, 820, 130))}`);
// 100 tall needs 140 with its air, 42 more than the band holds: room opens in whole lines, ceil(42 / 40) = 2, 80 points.
check(same(reply(x.bw_place(100, 100, 0, 90, 820, 130)), { push: { cut: 110, dy: 80 }, x: 84, y: 122 }),
  `no blank paper enough: room opens at the view's middle: ${read(x.bw_place(100, 100, 0, 90, 820, 130))}`);
// A drop on the line from far below: room from the clear line at its top (90) down until the line is a half line under
// it (110 + 20 - 98 = 32, one whole line).
check(same(reply(x.bw_drop(50, 90, 150, 110, 50, 600, 150, 620)), { push: { cut: 90, dy: 40 } }),
  `a drop on the line pushes it down a line: ${read(x.bw_drop(50, 90, 150, 110, 50, 600, 150, 620))}`);
check(same(reply(x.bw_drop(300, 300, 400, 320, 300, 600, 400, 620)), { push: null }), 'a drop on clear paper opens nothing');
check(same(reply(x.bw_drop(50, 95, 150, 105, 50, 95, 150, 105)), { push: null }), 'a drop back on the line it was lifted from opens nothing');
check(call('bw_load', 'not json') === -1 && reply(x.bw_place(10, 10, 0, 0, 820, 1000)).error === 'no board is loaded' &&
  reply(x.bw_drop(0, 0, 1, 1, 0, 0, 1, 1)).error === 'no board is loaded', 'with nothing loaded, a paste and a drop say so');

// Interface 4 (spec, headers in ink, Fold all and Collapse): over the outline, each on a copy.
// A line of two zigzag words (98..202 across, 88..112 down, its middle at 100) and a flat stroke under it (95..205,
// 119..121): an underline under most of the line and not far past it, so the line becomes header H, the underline its
// mark and one of its strokes.
const zig = (id, x0) => ({ id, width: 4, points: [0, 1, 2, 3, 4].map((i) => [x0 + 10 * i, i % 2 ? 110 : 90]) });
const inked = { strokes: [zig('a', 100), zig('b', 160), { id: 'u', width: 2, points: [[96, 120], [204, 120]] }], boxes: [], groups: {}, headers: [] };
check(call('bw_outline_load', inked) === 3, `the inked outline ${error() ?? ''}`);
check(same(ask('bw_ink_header', { name: 'u', id: 'H' }),
  { after: { id: 'H', ids: ['a', 'b', 'u'], mark: ['u'] }, ink: { header: 'H', kind: 'underline', mark: ['u'], y: 100 } }),
  `an underline makes its line a header: ${JSON.stringify(ask('bw_ink_header', { name: 'u', id: 'H' }))}`);
check(same(ask('bw_ink_header', { name: 'a', id: 'H' }), { ink: null }), 'a word of writing makes no header');
check(same(ask('bw_ink_header', { name: 'nobody', id: 'H' }), { ink: null }), 'no such stroke: nothing');
check(ask('bw_ink_header', { name: 'u' }).error === 'no stroke name and header id', 'no header id says so');
check(rowAt(100).header === undefined && same(rowAt(100).names, ['a', 'b']), `asking leaves the outline as it was (the line is no header yet): ${JSON.stringify(rowAt(100))}`);
// Fold all: the rows-and-folds outline above with the line at 300 made header N over an indented line at 340. From
// the lowest up: N tucks the line at 340 (338..342, 40 under its row's 302; nothing below, so nothing slides), then H
// tucks its two lines and the rest slides up 120 as before (N's row, its fold under it, still starts at 298).
const two = { ...outline, strokes: [...outline.strokes, { ...line('n2', 340), points: [[60, 340], [200, 340]] }], boxes: [],
  groups: {}, headers: [{ id: 'H', ids: ['h1'] }, { id: 'N', ids: ['n'] }] };
check(call('bw_outline_load', two) === 5, `two headers ${error() ?? ''}`);
const allFolds = [
  { bottom: 40, id: 'N', ids: ['n2'], lines: 1, own: ['n2'], shift: 0 },
  { bottom: 80, id: 'H', ids: ['b1', 'b2'], lines: 2, own: ['b1', 'b2'], shift: 120 },
];
check(same(ask('bw_fold_plan', {}), { folds: allFolds, levels: { H: 1, N: 1 }, open: false }), `Fold all: ${JSON.stringify(ask('bw_fold_plan', {}))}`);
check(same(ask('bw_fold_plan', { to: 1 }), { folds: allFolds, levels: { H: 1, N: 1 }, open: true }), `Collapse to 1, both at level 1: ${JSON.stringify(ask('bw_fold_plan', { to: 1 }))}`);
check(same(ask('bw_fold_plan', { to: 2 }), { folds: allFolds, levels: { H: 1, N: 1 }, open: true }), 'Collapse to 2: shallower headers with nothing under them fold too');
check(same(ask('bw_fold', { id: 'H' }).fold.shift, 120), 'and the outline is as it was: H still folds on its own');
// A header inside another's section: H at 100, N indented to 60 at 140 (in H's section, so level 2), a line indented
// further to 120 at 180 (N's), and a line back at the margin at 300 that ends both. Collapse to 1 folds only H (its
// section the two lines under it, the rest sliding up 120 as before); Collapse to 2 folds only N and leaves H open, a
// header with a header under it (N tucks the line at 180, 40 under its row's 142; 300 - 142 = 158, three whole lines
// less one = 80). Fold all folds N as Collapse to 2 does, then H: its section is N's row alone now (the margin line
// slid to 218), one line, 40 under its row, the rest sliding up 218 - 102 = 116, two lines less one = 40.
const nested = { strokes: [line('h1', 100), { ...line('n', 140), points: [[60, 140], [200, 140]] },
  { ...line('c', 180), points: [[120, 180], [200, 180]] }, line('e', 300)], boxes: [], groups: {},
  headers: [{ id: 'H', ids: ['h1'] }, { id: 'N', ids: ['n'] }] };
check(call('bw_outline_load', nested) === 4, `nested headers ${error() ?? ''}`);
const foldN = { bottom: 40, id: 'N', ids: ['c'], lines: 1, own: ['c'], shift: 80 };
check(same(ask('bw_fold_plan', { to: 1 }), { folds: [{ bottom: 80, id: 'H', ids: ['n', 'c'], lines: 2, own: ['n', 'c'], shift: 120 }],
  levels: { H: 1, N: 2 }, open: true }), `Collapse to 1 folds the outer header only: ${JSON.stringify(ask('bw_fold_plan', { to: 1 }))}`);
check(same(ask('bw_fold_plan', { to: 2 }), { folds: [foldN], levels: { H: 1, N: 2 }, open: true }),
  `Collapse to 2 folds the inner header and leaves its parent open: ${JSON.stringify(ask('bw_fold_plan', { to: 2 }))}`);
check(same(ask('bw_fold_plan', {}), { folds: [foldN, { bottom: 40, id: 'H', ids: ['n', 'c'], lines: 1, own: ['n'], shift: 40 }],
  levels: { H: 1, N: 2 }, open: false }), `Fold all folds the inner header, then the outer: ${JSON.stringify(ask('bw_fold_plan', {}))}`);
check(ask('bw_fold_plan', { to: '2' }).error && ask('bw_fold_plan', { to: 1.5 }).error && ask('bw_fold_plan', 'not json').error,
  'a level that is no whole number, or no request, says so rather than folding all');
// A fold left on a header whose lines show again (an Undo opened it) is no fold made: a header with nothing under it
// does not fold, so Fold all lists nothing.
check(call('bw_outline_load', { strokes: [line('x', 100)], boxes: [], groups: {},
  headers: [{ id: 'X', ids: ['x'], fold: { ids: ['x'], own: ['x'], shift: 0, lines: 1, bottom: 40 } }] }) === 1, `an undone fold ${error() ?? ''}`);
check(same(ask('bw_fold_plan', {}).folds, []), `an undone fold that does not fold again is not listed: ${JSON.stringify(ask('bw_fold_plan', {}))}`);
check(call('bw_load', 'not json') === -1 && call('bw_outline_load', 'not json') === -1 && ask('bw_fold_plan', {}).error === 'no outline is loaded' &&
  ask('bw_ink_header', { name: 'u', id: 'H' }).error === 'no outline is loaded', 'with no outline, both say so');

for (const f of failures) console.log(`FAIL ${f}`);
console.log(`${failures.length ? 'FAIL' : 'ok  '} board wasm: ${passed} checks passed, ${failures.length} failed (${names.length} recorded sessions, ${(fs.statSync(wasmPath).size / 1e6).toFixed(1)} MB module)`);
process.exitCode = failures.length ? 1 : 0;
