// Acceptance uses rendered device UI, official HDC input and screenshots only.
// No model imports, private application data or injected game state.
process.env.LITTLEGAMES_ART_OUTPUT ||= 'docs/device-acceptance/computer-opponents-2026-10-04';
const c = require('./device-art-review.cjs');
const strings = new Map(JSON.parse(c.fs.readFileSync('entry/src/main/resources/zh_CN/element/string.json')).string.map(s => [s.name, s.value]));
for (const [key, value] of strings) if (/^game_.+_name$/.test(key)) c.names[key.slice(5, -5)] = value;
const ids = ['doudizhu', 'guandan', 'mahjong', 'xiangqi', 'chess', 'ludo'];
const labels = { easy: '简单', normal: '普通', hard: '困难' };
const summaryFile = c.path.join(c.dir, 'summary.json');
const summary = c.fs.existsSync(summaryFile) ? JSON.parse(c.fs.readFileSync(summaryFile)) : {
  date: '2026-10-04', target: c.target, packageSha256: c.packageHash,
  originalDifficulty: {}, checks: [], samples: []
};
c.assert.equal(summary.packageSha256, c.packageHash, 'Keep evidence for different packages separate');
const save = () => c.fs.writeFileSync(summaryFile, JSON.stringify(summary, null, 2) + '\n');
function passed(id, detail, evidence) {
  summary.checks = summary.checks.filter(entry => entry.id !== id);
  summary.checks.push({ id, detail, evidence, at: new Date().toISOString() }); save();
  console.log('PASS ' + id);
}
const sheet = ns => ns.some(n => n.id === 'game-settings-panel');
const status = ns => ns.find(n => n.id === 'computer-turn-status')?.text || '';
const thinking = ns => /^电脑\s*\d+\s*正在思考/.test(status(ns));
const human = ns => status(ns) === strings.get('computer_your_turn') || status(ns) === strings.get('computer_mahjong_reaction');
const moves = ns => Number(c.text(ns).find(t => /^步数 \d+$/.test(t))?.split(' ').at(-1));
const selected = ns => ns.filter(n => n.type === 'Button' && n.description === '已选择')
  .flatMap(n => c.descendants(n).filter(d => d.type === 'Text').map(d => d.text)).find(t => Object.values(labels).includes(t));
function fast(n, interrupt = null) {
  c.assert(n); const b = c.bounds(n);
  const x = Math.round((b[0] + b[2]) / 2), y = Math.round((b[1] + b[3]) / 2);
  c.assert(x >= 0 && x < 1260 && y >= 0 && y < 2630 && b[2] > b[0], 'Observed input target center fits the phone viewport');
  let out = '';
  if (interrupt) {
    const next = c.bounds(interrupt), nextX = Math.round((next[0] + next[2]) / 2), nextY = Math.round((next[1] + next[3]) / 2);
    // One device-shell sequence avoids two host round trips between input and
    // the settings action that must interrupt the 500 ms pending computer turn.
    out = c.shell(`uinput -T -c ${x} ${y} 25; uinput -T -c ${nextX} ${nextY} 25`);
  } else out = c.shell('uinput', '-T', '-c', '' + x, '' + y, '25');
  c.assert(!/parameter error|unable to run/i.test(out), out);
}
function settings(ns = c.layout()) {
  if (!sheet(ns)) fast(ns.find(n => n.id === 'game-settings-button'));
  return c.wait(a => sheet(a) && a.some(n => n.id === 'game-settings-return'));
}
function close() {
  fast(c.layout().find(n => n.id === 'game-settings-return'));
  return c.wait(a => !sheet(a) && a.some(n => n.id === 'computer-turn-status'));
}
function open(id) {
  let ns = c.layout(); if (sheet(ns)) ns = close();
  if (ns.some(n => n.id === 'game-settings-button') && c.text(ns).includes(c.names[id])) return scrollTop();
  if (ns.some(n => n.id === 'game-settings-button')) c.back();
  c.tap('分类', c.tabs());
  return c.open(id);
}
function confirm(action) {
  const ns = c.wait(a => !sheet(a) || c.find(a, strings.get('game_settings_restart_confirm')) ||
    c.find(a, strings.get('game_settings_difficulty_confirm')));
  if (sheet(ns)) {
    const button = ns.filter(n => n.type === 'Button' && c.descendants(n).some(d => d.text === action)).pop();
    c.assert(button, 'Observed confirmation button'); fast(button);
  }
  return c.wait(a => !sheet(a) && a.some(n => n.id === 'computer-turn-status'));
}
function difficulty(id, label) {
  let ns = settings(); const previous = selected(ns); c.assert(previous);
  if (!summary.originalDifficulty[id]) { summary.originalDifficulty[id] = previous; save(); }
  if (previous === label) return close();
  fast(c.find(ns, label)); ns = confirm(strings.get('game_settings_change_action'));
  c.assert.equal(moves(ns), 0); c.assert.equal(status(ns), strings.get('computer_your_turn'));
  c.assert(c.text(ns).includes(label));
  ns = settings(); c.assert.equal(selected(ns), label); return close();
}
function restart() {
  const ns = settings(); fast(c.find(ns, strings.get('header_restart')));
  const ready = confirm(strings.get('header_restart'));
  c.assert.equal(moves(ready), 0); c.assert.equal(status(ready), strings.get('computer_your_turn'));
  return ready;
}
function scrollFind(label) {
  let ns = c.layout();
  for (let i = 0; i < 5 && (!c.find(ns, label) || c.bounds(c.find(ns, label))[3] > 2590); i++) {
    const scroll = ns.find(n => n.type === 'Scroll' && c.bounds(n)[3] > 1800); c.assert(scroll);
    const b = c.bounds(scroll), x = Math.round((b[0] + b[2]) / 2);
    c.shell('uitest', 'uiInput', 'swipe', '' + x, '' + (b[3] - 100), '' + x, '' + (b[1] + 160), '300');
    ns = c.layout();
  }
  const node = c.find(ns, label); c.assert(node, 'Missing control ' + label); return node;
}
function scrollTop() {
  let ns = c.layout();
  for (let i = 0; i < 6 && !ns.some(n => n.id === 'computer-turn-status'); i++) {
    const scroll = ns.find(n => n.type === 'Scroll' && c.bounds(n)[3] > 1800); c.assert(scroll);
    const b = c.bounds(scroll), x = Math.round((b[0] + b[2]) / 2);
    c.shell('uitest', 'uiInput', 'swipe', '' + x, '' + (b[1] + 160), '' + x, '' + (b[3] - 100), '300');
    ns = c.layout();
  }
  return ns;
}
function cells(ns, expected) {
  const result = ns.filter(n => n.type === 'Button' && c.bounds(n)[1] > 700 &&
    c.bounds(n)[2] - c.bounds(n)[0] > 70 &&
    Math.abs(c.bounds(n)[2] - c.bounds(n)[0] - c.bounds(n)[3] + c.bounds(n)[1]) < 7)
    .sort((a, b) => Math.abs(c.bounds(a)[1] - c.bounds(b)[1]) < 10 ? c.bounds(a)[0] - c.bounds(b)[0] : c.bounds(a)[1] - c.bounds(b)[1]);
  c.assert.equal(result.length, expected); return result;
}
function submit(id, ns = c.layout(), interrupt = false) {
  c.assert(human(ns)); const gear = ns.find(n => n.id === 'game-settings-button'); c.assert(gear);
  if (id === 'chess' || id === 'xiangqi') {
    const board = cells(ns, id === 'chess' ? 64 : 90);
    fast(board[id === 'chess' ? 52 : 54]); c.sleep(100);
    fast(board[id === 'chess' ? 36 : 45], interrupt ? gear : null);
  } else if (id === 'doudizhu' || id === 'guandan') {
    const card = ns.find(n => n.type === 'Button' && /^(?:[♠♥♦♣](?:A|[2-9]|10|J|Q|K)|[☆★])$/.test(n.text));
    c.assert(card); fast(card);
    const selectedHand = c.capture('manual-' + id + '-selected');
    const selectedCard = selectedHand.find(n => n.accessibilityId === card.accessibilityId);
    c.assert(selectedCard && c.bounds(selectedCard)[2] - c.bounds(selectedCard)[0] > c.bounds(card)[2] - c.bounds(card)[0], 'Manual hand selection renders its selected scale after restart');
    fast(scrollFind(strings.get('expansion_hint'))); c.sleep(150);
    fast(scrollFind(strings.get('expansion_play_cards')), interrupt ? gear : null);
  } else if (id === 'mahjong') {
    const tile = ns.find(n => n.type === 'Button' && /^(?:[1-9][萬筒索]|[東南西北中發白])$/.test(n.text));
    c.assert(tile); fast(tile); c.sleep(150);
    const selectedHand = c.capture('manual-mahjong-selected');
    const selectedTile = selectedHand.find(n => n.accessibilityId === tile.accessibilityId);
    c.assert(selectedTile && c.bounds(selectedTile)[2] - c.bounds(selectedTile)[0] > c.bounds(tile)[2] - c.bounds(tile)[0], 'Mahjong selection renders its selected scale after restart');
    fast(tile, interrupt ? gear : null);
  } else {
    let guard = 0;
    while (guard++ < 20) {
      fast(scrollFind(strings.get('expansion_roll')), interrupt ? gear : null);
      ns = c.layout(); if (interrupt) break;
      const die = c.text(ns).find(t => /^骰子点数 /.test(t));
      if (!die?.endsWith('6') || !human(ns)) break;
      const own = ns.filter(n => n.type === 'Button' && n.text === '1' && n.parent?.attributes.enabled === 'true' && c.bounds(n)[1] > 700)
        .sort((a, b) => Math.abs(c.bounds(a)[1] - c.bounds(b)[1]) < 10 ? c.bounds(a)[0] - c.bounds(b)[0] : c.bounds(a)[1] - c.bounds(b)[1]);
      c.assert(own.length); fast(own[0]);
    }
    c.assert(guard < 20, 'Bounded human bonus rolls');
  }
  return gear;
}
function returned() { return c.wait(a => human(a) || c.find(a, '再来一局'), 12000); }
function round(id, level) {
  open(id); let ns = difficulty(id, labels[level]); ns = restart();
  const tag = 'light-' + id + '-' + level;
  ns = c.capture(tag + '-ready'); const beforeMoves = moves(ns);
  const started = Date.now(); submit(id, ns);
  const afterTouch = Date.now() - started;
  ns = c.capture(tag + '-thinking');
  const observed = { tag, afterTouchMs: afterTouch, sampleMs: Date.now() - started,
    status: status(ns), moves: moves(ns), thinkingObserved: thinking(ns),
    disabledBoardButtons: ns.filter(n => n.type === 'Button' && n.enabled === 'false' && c.bounds(n)[1] > 700).length };
  summary.samples.push(observed); save();
  ns = returned(); c.assert(!c.find(ns, '再来一局'), 'First interaction returns to the human');
  if (id === 'chess' || id === 'xiangqi') c.assert.equal(moves(ns), beforeMoves + 2);
  else if (id !== 'ludo') c.assert(moves(ns) > beforeMoves);
  c.assert(human(ns)); c.capture(tag + '-replied');
  passed(id + '-' + level, 'Observed real human input and automatic computer response, difficulty label and selected setting verified',
    [tag + '-ready.jpeg', tag + '-thinking.jpeg', tag + '-replied.jpeg']);
}
function signature(ns) {
  return c.text(ns).filter(t => !/^得分 /.test(t));
}
function lifecycle(id) {
  open(id); difficulty(id, '普通'); restart(); c.sleep(400); let ns = c.layout(); submit(id, ns, true);
  ns = c.wait(a => sheet(a));
  for (let retry = 0; id === 'ludo' && !thinking(ns) && retry < 8; retry++) {
    close(); restart(); ns = c.layout(); submit(id, ns, true); ns = c.wait(a => sheet(a));
  }
  c.assert(thinking(ns), 'Interrupt a pending real computer turn before pausing');
  c.assert(c.find(ns, '暂停')); fast(c.find(ns, '暂停'));
  ns = c.wait(a => !sheet(a) && c.find(a, strings.get('expansion_paused')));
  const tag = 'lifecycle-' + id, pending = thinking(ns), frozen = signature(ns);
  c.capture(tag + '-paused'); c.sleep(1500); c.sleep(1500);
  c.assert.deepEqual(signature(c.layout()), frozen);
  c.shell('uitest', 'uiInput', 'keyEvent', 'Home'); c.sleep(1500); c.sleep(1500);
  c.shell('aa', 'start', '-a', 'EntryAbility', '-b', 'com.littlegames.collection');
  ns = c.wait(a => c.find(a, strings.get('expansion_paused'))); c.assert.deepEqual(signature(ns), frozen);
  c.capture(tag + '-background-return');
  ns = settings(); c.assert(c.find(ns, '继续')); fast(c.find(ns, '继续'));
  c.wait(a => !sheet(a)); returned(); c.capture(tag + '-resumed');
  const undo = scrollFind(strings.get('expansion_undo')); c.assert.equal(undo.enabled, 'true'); fast(undo);
  scrollTop(); ns = c.wait(a => moves(a) === 0 && human(a)); c.capture(tag + '-undo');
  ns = restart(); c.capture(tag + '-restart');
  passed(id + '-lifecycle', 'Pause and Home/foreground preserve the UI; Resume returns control; Undo and confirmed Restart restore a human initial turn',
    [tag + '-paused.jpeg', tag + '-background-return.jpeg', tag + '-resumed.jpeg', tag + '-undo.jpeg', tag + '-restart.jpeg']);
  summary.samples.push({ tag, pendingComputerAtPause: pending }); save(); c.back();
}
function prepare() {
  if (c.layout().some(n => n.id === 'game-settings-button')) c.back();
  c.theme('light');
  summary.model = c.shell('param', 'get', 'const.product.model').trim();
  summary.api = c.shell('param', 'get', 'const.ohos.apiversion').trim();
  summary.os = c.shell('param', 'get', 'const.ohos.fullname').trim();
  c.fs.writeFileSync(c.path.join(c.dir, 'installed-bundle.txt'), c.shell('bm', 'dump', '-n', 'com.littlegames.collection'));
  save(); console.log('PREPARED ' + summary.model + ' API ' + summary.api);
}
function appearance(id, mode) {
  if (c.layout().some(n => n.id === 'game-settings-button')) c.back();
  open(id); let ns = c.capture(mode + '-' + id + '-ready');
  c.assert.equal(moves(ns), 0); c.assert(human(ns));
  submit(id, ns); returned(); c.capture(mode + '-' + id + '-replied');
  passed(id + '-' + mode, 'Identity, status, board and controls rendered after real computer reply in ' + mode + ' theme',
    [mode + '-' + id + '-ready.jpeg', mode + '-' + id + '-replied.jpeg']); c.back();
}
function movement(mode) {
  if (c.layout().some(n => n.id === 'game-settings-button')) c.back();
  c.theme(mode); open('ludo'); difficulty('ludo', '普通'); restart();
  const tag = mode + '-ludo-movement'; let ns = c.capture(tag + '-before');
  const plane = ns.filter(n => n.type === 'Button' && n.text === '1' && n.parent?.attributes.enabled === 'true').sort((a, b) =>
    Math.abs(c.bounds(a)[1] - c.bounds(b)[1]) < 10 ? c.bounds(a)[0] - c.bounds(b)[0] : c.bounds(a)[1] - c.bounds(b)[1])[0];
  c.assert(plane);
  for (let roll = 0; roll < 30; roll++) {
    fast(scrollFind(strings.get('expansion_roll'))); ns = returned();
    if (c.text(ns).includes('骰子点数 6')) {
      c.capture(tag + '-six'); const before = moves(ns);
      fast(ns.find(n => n.accessibilityId === plane.accessibilityId));
      ns = c.wait(a => moves(a) > before); ns = c.capture(tag + '-takeoff');
      const moved = ns.find(n => n.accessibilityId === plane.accessibilityId); c.assert(moved);
      c.assert.notEqual(moved.bounds, plane.bounds, 'The human plane visibly leaves its hangar after a real six');
      summary.samples.push({ tag, rolls: roll + 1, before: plane.bounds, after: moved.bounds }); save();
      passed('ludo-movement-' + mode, 'Natural dice six and human plane takeoff update the rendered coordinates',
        [tag + '-before.jpeg', tag + '-six.jpeg', tag + '-takeoff.jpeg']); c.back(); return;
    }
  }
  throw Error('No natural six observed in 30 rolls');
}
function restore(visualOnly = false) {
  if (visualOnly) {
    for (const id of ids) for (const mode of ['light', 'dark']) c.assert(summary.checks.some(check => check.id === id + '-' + mode));
    const flowFile = c.path.resolve(c.dir, '../logic-and-flow/summary.json');
    const flow = JSON.parse(c.fs.readFileSync(flowFile));
    c.assert.equal(flow.checks.length, 32); c.assert(flow.finishedAt);
    summary.relatedFlow = { packageSha256: flow.packageSha256, evidence: '../logic-and-flow/summary.json' };
  } else {
    for (const id of ids) {
      for (const level of Object.keys(labels)) c.assert(summary.checks.some(check => check.id === id + '-' + level));
      c.assert(summary.checks.some(check => check.id === id + '-lifecycle'));
      c.assert(summary.checks.some(check => check.id === id + '-dark'));
    }
    for (const mode of ['light', 'dark']) c.assert(summary.checks.some(check => check.id === 'ludo-movement-' + mode));
  }
  for (const id of Object.keys(summary.originalDifficulty)) {
    open(id); difficulty(id, summary.originalDifficulty[id]); c.back();
  }
  c.theme('restore');
  const original = JSON.parse(c.fs.readFileSync(c.path.join(c.dir, 'original-settings.json')));
  const settingsRoot = JSON.parse(c.fs.readFileSync(c.path.join(c.dir, 'settings-restore.json')));
  const settingsNodes = [];
  const collect = node => { settingsNodes.push({ ...node.attributes, raw: node }); for (const child of node.children || []) collect(child); };
  collect(settingsRoot);
  c.assert.deepEqual(settingsNodes.filter(n => n.type === 'Toggle').map(n => n.checked), original.toggles.map(n => n.checked));
  c.assert(settingsNodes.some(n => n.type === 'Button' && n.description === '已选择' && c.descendants(n).some(d => d.text === original.theme)));
  summary.restoredSettings = { theme: original.theme, toggles: original.toggles.map(n => n.checked) };
  c.tap('精选', c.tabs()); c.capture('finished-home');
  summary.finishedAt = new Date().toISOString(); save(); console.log('RESTORED');
}
const action = process.argv[2];
try {
  if (action === 'prepare') prepare();
  else if (action === 'front') { open(process.argv[3]); c.capture('light-' + process.argv[3] + '-outline-check'); }
  else if (action === 'rounds') { for (const id of process.argv.slice(3)) { for (const level of Object.keys(labels)) round(id, level); c.back(); } }
  else if (action === 'lifecycle') { for (const id of process.argv.slice(3)) lifecycle(id); }
  else if (action === 'dark') {
    if (c.layout().some(n => n.id === 'game-settings-button')) c.back();
    c.theme('dark'); for (const id of process.argv.slice(3)) appearance(id, 'dark');
  }
  else if (action === 'visual') {
    if (c.layout().some(n => n.id === 'game-settings-button')) c.back();
    for (const mode of ['light', 'dark']) { c.theme(mode); for (const id of ids) appearance(id, mode); }
  }
  else if (action === 'movement') movement(process.argv[3] || 'light');
  else if (action === 'restore') restore();
  else if (action === 'finish-visual') restore(true);
  else if (action === 'observe') console.log(JSON.stringify(c.layout().filter(n => n.text || n.description || n.clickable === 'true').map(n =>
    ({ type: n.type, id: n.id, text: n.text, description: n.description, bounds: n.bounds, enabled: n.enabled })), null, 2));
  else if (action === 'capture') c.capture(process.argv[3]);
  else throw Error('Use prepare, front <id>, rounds <ids>, lifecycle <ids>, dark <ids>, visual, movement <light|dark>, restore, finish-visual, observe or capture <tag>');
} catch (error) { c.log('check-incomplete', { action, message: error.stack }); console.error(error.stack); process.exitCode = 1; }
