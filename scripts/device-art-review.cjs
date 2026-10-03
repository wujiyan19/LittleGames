// Real-device art review through HDC's official rendered UI and screenshots.
// No game-model imports, application files, or injected game state.
const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const target = process.env.LITTLEGAMES_ART_TARGET || 'FMR0224521016052';
const hdc = 'C:/Program Files/Huawei/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe';
const dir = path.resolve(process.env.LITTLEGAMES_ART_OUTPUT || 'docs/device-acceptance/art-review-2026-10-03');
fs.mkdirSync(dir, { recursive: true });
const strings = JSON.parse(fs.readFileSync('entry/src/main/resources/zh_CN/element/string.json')).string;
const ids = ['snake', 'tetris', '2048', 'whackmole', 'minesweeper', 'jumpjump', 'brickbreaker',
  'sudoku', 'slidepuzzle', 'klotski', 'guessnumber', 'memorycard', 'match3',
  'tictactoe', 'gomoku', 'reversi', 'fourline', 'nim', 'lights', 'flood', 'maze', 'hanoi', 'peg',
  'nonogram', 'arithmetic', 'compare', 'sequence', 'binary', 'targetsum', 'schulte',
  'memorysequence', 'missing', 'reaction'];
const names = Object.fromEntries(ids.map(id => [id, strings.find(s => s.name === 'game_' + id + '_name').value]));
const packageHash = crypto.createHash('sha256').update(fs.readFileSync('entry/build/default/outputs/default/entry-default-signed.hap')).digest('hex');
let root;
let lastNodes = [];
const sleep = ms => { assert(ms <= 2000); Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms); };
const run = (...args) => {
  const output = cp.execFileSync(hdc, ['-t', target, ...args], { encoding: 'utf8', timeout: 20000 });
  assert(!/^\s*\[Fail\]/m.test(output), output.trim());
  return output;
};
const shell = (...args) => run('shell', ...args);
const bounds = n => n.bounds.match(/-?\d+/g).map(Number);
const text = ns => ns.filter(n => n.type === 'Text' && n.text).map(n => n.text);
const descendants = n => {
  const out = [];
  const visit = raw => { out.push(raw.attributes); (raw.children || []).forEach(visit); };
  (n.raw.children || []).forEach(visit);
  return out;
};
function layout() {
  shell('uitest', 'dumpLayout', '-b', 'com.littlegames.collection', '-p', '/data/local/tmp/lg-art-review.json');
  run('file', 'recv', '/data/local/tmp/lg-art-review.json', path.join(dir, 'current.json'));
  root = JSON.parse(fs.readFileSync(path.join(dir, 'current.json'), 'utf8'));
  const ns = [];
  const visit = (raw, parent) => {
    if (raw.attributes?.bounds && raw.attributes.visible !== 'false') ns.push({ ...raw.attributes, raw, parent });
    (raw.children || []).forEach(child => visit(child, raw));
  };
  visit(root, null);
  assert(ns.some(n => n.type === 'Text' && [...Object.values(names), '精选', '分类', '我的', '设置', '玩趣盒'].includes(n.text)),
    'Application UI is not foreground');
  lastNodes = ns;
  return ns;
}
const find = (ns, label) => ns.find(n => n.clickable === 'true' && (n.text === label || n.description === label)) ||
  ns.find(n => n.text === label || n.description === label);
function click(n) {
  assert(n, 'Observed UI target absent');
  const b = bounds(n);
  assert(b[2] > b[0] && b[3] > b[1]);
  shell('uitest', 'uiInput', 'click', '' + Math.round((b[0] + b[2]) / 2), '' + Math.round((b[1] + b[3]) / 2));
}
function tap(label, ns = layout()) { click(find(ns, label)); sleep(100); }
function wait(pred, timeout = 10000) {
  const end = Date.now() + timeout;
  do { const ns = layout(); if (pred(ns)) return ns; sleep(100); } while (Date.now() < end);
  throw Error('Expected UI not observed: ' + text(lastNodes).join(' | '));
}
function log(action, details) {
  fs.appendFileSync(path.join(dir, 'actions.jsonl'), JSON.stringify({ at: new Date().toISOString(), target, packageHash, action, ...details }) + '\n');
}
function capture(tag) {
  assert.match(tag, /^[a-z0-9-]+$/);
  shell('snapshot_display', '-f', '/data/local/tmp/lg-art-review.jpeg');
  run('file', 'recv', '/data/local/tmp/lg-art-review.jpeg', path.join(dir, tag + '.jpeg'));
  const ns = layout();
  fs.writeFileSync(path.join(dir, tag + '.json'), JSON.stringify(root));
  log('capture', { tag, text: text(ns), images: ns.filter(n => n.type === 'Image').length });
  return ns;
}
function open(id) {
  const name = names[id]; assert(name);
  let ns = wait(a => a.some(n => n.type === 'TextInput'));
  let input = ns.find(n => n.type === 'TextInput');
  if (input.text) {
    const clear = input.parent.children.find(n => n.attributes.type === 'Button'); assert(clear);
    click(clear.attributes); ns = wait(a => a.some(n => n.type === 'TextInput' && !n.text));
    input = ns.find(n => n.type === 'TextInput');
  }
  const b = bounds(input);
  shell('uitest', 'uiInput', 'inputText', '' + Math.round((b[0] + b[2]) / 2), '' + Math.round((b[1] + b[3]) / 2), name);
  const card = n => n.type === 'Column' && n.clickable === 'true' &&
    [n.text, n.description].some(t => t?.startsWith(name + ',') || t?.startsWith(name + '，'));
  ns = wait(a => a.some(card)); click(ns.find(card));
  return wait(a => a.some(n => n.type === 'Text' && n.text === name) && !a.some(n => n.type === 'TextInput'));
}
function back() {
  let ns = layout();
  if (ns.some(n => n.type === 'TextInput')) return ns;
  if (find(ns, '再来一局') && find(ns, '退出')) tap('退出', ns);
  else {
    shell('uitest', 'uiInput', 'keyEvent', 'Back');
    ns = wait(a => find(a, '确认退出？') || a.some(n => n.type === 'TextInput'));
    if (find(ns, '确认退出？')) tap('退出', ns);
  }
  return wait(a => a.some(n => n.type === 'TextInput'));
}
function tabs() {
  let ns = layout();
  if (!find(ns, '我的') && ns.some(n => n.type === 'TextInput')) shell('uitest', 'uiInput', 'keyEvent', 'Back');
  return wait(a => find(a, '我的'));
}
function settings() { const ns = tabs(); tap('我的', ns); tap('设置', wait(a => find(a, '设置'))); return wait(a => find(a, '主题模式')); }
function leaveSettings() {
  shell('uitest', 'uiInput', 'keyEvent', 'Back'); tap('分类', wait(a => find(a, '分类')));
  return wait(a => a.some(n => n.type === 'TextInput'));
}
function theme(mode) {
  const ns = settings();
  const selected = ns.filter(n => n.type === 'Button' && n.description === '已选择')
    .flatMap(n => descendants(n).filter(d => d.type === 'Text').map(d => d.text));
  const originalFile = path.join(dir, 'original-settings.json');
  if (!fs.existsSync(originalFile)) {
    const original = selected.find(label => ['浅色', '深色', '跟随系统'].includes(label)); assert(original);
    fs.writeFileSync(originalFile, JSON.stringify({ at: new Date().toISOString(), theme: original,
      toggles: ns.filter(n => n.type === 'Toggle').map(n => ({ checked: n.checked, bounds: n.bounds })) }, null, 2));
    capture('settings-before');
  }
  const label = mode === 'restore' ? JSON.parse(fs.readFileSync(originalFile)).theme : mode === 'dark' ? '深色' : '浅色';
  tap(label, ns); sleep(350); capture('settings-' + mode); leaveSettings();
}
const grid = (ns = layout(), type = 'Stack') => ns.filter(n => n.type === type && n.clickable === 'true' && bounds(n)[1] > 550 && bounds(n)[3] < 2380)
  .sort((a, b) => Math.abs(bounds(a)[1] - bounds(b)[1]) < 20 ? bounds(a)[0] - bounds(b)[0] : bounds(a)[1] - bounds(b)[1]);
const board = (ns = layout()) => ns.filter(n => n.type === 'Button' && bounds(n)[1] > 380 && bounds(n)[3] < 2380 &&
  bounds(n)[2] - bounds(n)[0] > 30 && Math.abs(bounds(n)[2] - bounds(n)[0] - bounds(n)[3] + bounds(n)[1]) < 8)
  .sort((a, b) => Math.abs(bounds(a)[1] - bounds(b)[1]) < 15 ? bounds(a)[0] - bounds(b)[0] : bounds(a)[1] - bounds(b)[1]);
const nums = n => descendants(n).filter(d => d.type === 'Text' && /^\d+$/.test(d.text)).map(d => Number(d.text));
function headerRestart(ns = layout()) { click(ns.find(n => n.type === 'Button' && bounds(n)[0] > 1000 && bounds(n)[1] < 300)); sleep(200); }
async function main() {
  const action = process.argv[2] || 'observe';
  const args = process.argv.slice(3);
  if (action === 'observe') console.log(JSON.stringify(layout().filter(n => n.text || n.description || n.clickable === 'true')
    .map(n => ({ type: n.type, text: n.text, description: n.description, bounds: n.bounds, id: n.id, checked: n.checked }))));
  else if (action === 'theme') theme(args[0]);
  else if (action === 'open') open(args[0]);
  else if (action === 'back') back();
  else if (action === 'tap') tap(args[0]);
  else if (action === 'capture') console.log(JSON.stringify({ tag: args[0], text: text(capture(args[0])) }));
  else if (action === 'fronts') {
    const mode = args[0]; theme(mode);
    for (const id of args.slice(1).length ? args.slice(1) : ids) {
      open(id); sleep(250); const ns = capture(mode + '-' + id + '-ready');
      assert(ns.some(n => n.type === 'Text' && n.text === names[id]));
      back(); log('front-passed', { mode, id, name: names[id] });
      console.log('FRONT ' + mode + ' ' + id + ' / ' + names[id]);
    }
  } else throw Error('Unknown action');
}
if (require.main === module) main().catch(e => { log('check-incomplete', { message: e.stack }); console.error(e.stack); process.exitCode = 1; });
module.exports = { fs, path, cp, assert, dir, ids, names, target, packageHash, run, shell, sleep, bounds, text, descendants,
  layout, find, click, tap, wait, log, capture, open, back, tabs, theme, grid, board, nums, headerRestart };
