// Device UI acceptance for the HarmonyOS motion changes. No injected app state.
process.env.LITTLEGAMES_ART_OUTPUT = process.env.LITTLEGAMES_ART_OUTPUT || 'docs/device-acceptance/harmony-motion-2026-10-03';
const c = require('./device-art-review.cjs');
const hdc = 'C:/Program Files/Huawei/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe';
const summaryFile = c.path.join(c.dir, 'summary.json');
const state = c.fs.existsSync(summaryFile) ? JSON.parse(c.fs.readFileSync(summaryFile)) :
  { date: '2026-10-03', target: c.target, packageSha256: c.packageHash, checks: [], motionSamples: [] };
c.assert.equal(state.packageSha256, c.packageHash, 'Do not mix acceptance for different packages');
const save = () => c.fs.writeFileSync(summaryFile, JSON.stringify(state, null, 2) + '\n');
const passed = (id, behavior, evidence = [], detail = {}) => {
  state.checks = state.checks.filter(a => a.id !== id);
  state.checks.push({ id, behavior, evidence, ...detail, at: new Date().toISOString() });
  save(); c.log('motion-check-passed', { id, behavior, detail }); console.log('PASS ' + id);
};
const center = n => { const b = c.bounds(n); return [Math.round((b[0] + b[2]) / 2), Math.round((b[1] + b[3]) / 2)]; };
const card = n => n.type === 'Column' && n.clickable === 'true' && [n.text, n.description].some(s => /[,，]/.test(s || ''));
const tapStream = (nodes, interval = 70) => {
  // The device CLI accepts one -c per invocation, even though down/up may be combined.
  for (const n of nodes) {
    const output = c.shell('uinput', '-T', '-c', ...center(n).map(String), '25');
    c.assert(!/parameter error|unable to run/i.test(output), output);
    c.sleep(interval);
  }
};
function beginTouch(args) {
  const child = c.cp.spawn(hdc, ['-t', c.target, 'shell', 'uinput', '-T', ...args], { windowsHide: true });
  let output = ''; child.stdout.on('data', data => { output += data; }); child.stderr.on('data', data => { output += data; });
  const done = new Promise((resolve, reject) => {
    child.on('error', reject);
    child.on('close', code => code === 0 && !/\[Fail\]|parameter error|unable to run/i.test(output) ? resolve() : reject(new Error(output || 'Touch input failed')));
  });
  return done;
}
async function sampleMotion(n, tag) {
  const coords = center(n).map(String), started = Date.now();
  const done = beginTouch(['-c', ...coords, '25']);
  const samples = [];
  for (let i = 0; i < 7; i++) {
    const remote = '/data/local/tmp/lg-motion-' + i + '.jpeg';
    const file = tag + '-' + i + '.jpeg';
    const requested = Date.now() - started;
    c.shell('snapshot_display', '-f', remote);
    const completed = Date.now() - started;
    c.run('file', 'recv', remote, c.path.join(c.dir, file));
    samples.push({ file, requestMs: requested, completionMs: completed });
  }
  await done;
  state.motionSamples.push({ tag, source: 'real device snapshots during UI input; timestamps include capture overhead', samples });
  save(); return samples.map(s => s.file);
}
async function pressCancel(n, tag) {
  const before = c.bounds(n), xy = center(n).map(String);
  const observedTarget = nodes => nodes.filter(a => a.type === n.type && a.text === n.text && a.description === n.description)
    .sort((a, b) => {
      const ca = center(a), cb = center(b), original = center(n);
      return Math.hypot(ca[0] - original[0], ca[1] - original[1]) - Math.hypot(cb[0] - original[0], cb[1] - original[1]);
    })[0];
  const done = beginTouch(['-d', ...xy, '-i', '3500', '-u', '1250', '960']);
  await new Promise(resolve => setTimeout(resolve, 400));
  const held = c.capture(tag + '-held');
  const match = observedTarget(held);
  c.assert(match, 'Pressed element remains visible');
  const during = c.bounds(match);
  await done;
  c.sleep(350);
  const after = c.capture(tag + '-released');
  const released = observedTarget(after);
  c.assert(released, 'Canceled press keeps the same page');
  c.assert.deepEqual(c.bounds(released), before, 'Canceled press restores the original bounds');
  return { before, during, after: c.bounds(released), widthRatio: (during[2] - during[0]) / (before[2] - before[0]),
    evidence: [tag + '-held.jpeg', tag + '-released.jpeg'] };
}
function header(ns, label) {
  let node = c.find(ns, label);
  // This device's dumpLayout omits accessibilityText on Symbol-only buttons.
  const top = ns.filter(n => n.type === 'Button' && c.bounds(n)[1] < 330).sort((a, b) => c.bounds(a)[0] - c.bounds(b)[0]);
  if (!node && label === '重新开始') node = top.at(-1);
  if (!node && (label === '暂停' || label === '继续')) node = top.at(-2);
  if (!node && (label === '向左' || label === '向右')) {
    const pad = ns.filter(n => n.type === 'Button' && c.bounds(n)[1] > 1500 && c.bounds(n)[2] - c.bounds(n)[0] < 250)
      .sort((a, b) => Math.abs(c.bounds(a)[1] - c.bounds(b)[1]) < 20 ? c.bounds(a)[0] - c.bounds(b)[0] : c.bounds(a)[1] - c.bounds(b)[1]);
    node = pad[label === '向左' ? 1 : 3];
  }
  c.assert(node, 'Missing header/control ' + label); return node;
}
function result(label) {
  return c.wait(ns => c.find(ns, '再来一局') && (!label || c.text(ns).includes(label)));
}
function emptyDuel(ns) {
  c.assert(c.text(ns).some(t => t.includes('玩家 1 回合')));
  c.assert.equal(c.board(ns).length, 9);
  c.assert(c.board(ns).every(n => c.descendants(n).filter(d => d.type === 'Image').length === 1),
    'Restart stays empty after double tap');
}
async function catalog(mode) {
  c.theme(mode);
  c.tap('精选', c.tabs()); c.sleep(350); c.capture(mode + '-featured');
  const tabs = ['精选', '分类', '我的'].map(label => header(c.layout(), label));
  const order = [1, 2, 0, 2, 1, 0, 1, 2, 0, 2, 0, 1];
  tapStream(order.map(i => tabs[i]), 80);
  let ns = c.wait(a => a.some(n => n.type === 'TextInput'));
  const search = ns.find(n => n.type === 'TextInput');
  if (search.text) {
    const clear = search.parent.children.find(n => n.attributes.type === 'Button');
    c.assert(clear, 'Observed search clear button'); c.click(clear.attributes);
    ns = c.wait(a => a.some(n => n.type === 'TextInput' && !n.text));
  }
  c.capture(mode + '-tabs-fast');
  passed(mode + '-rapid-tabs', '12 consecutive native tab taps end on Category with live content', [mode + '-tabs-fast.jpeg']);
  const labels = ['全部', '街机休闲', '逻辑解谜', '棋盘对弈', '数字训练', '记忆专注', '反应节奏'];
  const chips = labels.map(label => {
    const n = ns.find(a => a.type === 'Row' && a.clickable === 'true' && c.descendants(a).some(d => d.text === label));
    c.assert(n, label); const count = Number(c.descendants(n).find(d => d.type === 'Text' && /^\d+$/.test(d.text)).text);
    return { n, label, count };
  });
  const widths = [];
  for (const chip of chips) {
    c.click(chip.n);
    ns = c.wait(a => c.text(a).includes(chip.count + ' 款游戏'));
    const selected = ns.find(a => a.type === 'Row' && a.description === '已选择' && c.descendants(a).some(d => d.text === chip.label));
    c.assert(selected, chip.label + ' selected feedback');
    const games = ns.filter(card); c.assert(games.length > 0);
    widths.push({ label: chip.label, width: c.bounds(games[0])[2] - c.bounds(games[0])[0] });
  }
  c.assert(widths.every(w => w.width === widths[0].width), 'Filtering preserves grid card widths');
  tapStream([3, 1, 5, 2, 6, 4, 1, 3, 0].map(i => chips[i].n), 65);
  ns = c.wait(a => c.text(a).includes('100 款游戏')); c.sleep(350); c.capture(mode + '-categories');
  passed(mode + '-categories', 'All 7 categories select correctly; rapid switching returns all 100 games with stable card widths',
    [mode + '-categories.jpeg'], { widths });
  ns = c.layout();
  const first = ns.find(card); c.assert(first);
  c.capture(mode + '-card-before');
  const press = await pressCancel(first, mode + '-card');
  c.assert(press.widthRatio > 0.965 && press.widthRatio < 0.995, 'Native card press visibly compresses');
  passed(mode + '-card-press-cancel', 'Held card gently compresses; release outside cancels navigation and restores size',
    [mode + '-card-before.jpeg', ...press.evidence], press);
  const xy = center(first);
  c.shell('uitest', 'uiInput', 'swipe', ...xy.map(String), String(xy[0]), String(xy[1] - 480), '1200');
  ns = c.wait(a => a.some(n => n.type === 'TextInput')); c.capture(mode + '-card-scroll-cancel');
  passed(mode + '-card-scroll', 'Dragging from a card scrolls the catalog without opening a game', [mode + '-card-scroll-cancel.jpeg']);
  c.tap('我的', c.tabs()); c.sleep(300); c.capture(mode + '-profile');
  c.assert(c.find(c.layout(), '最高分排行'));
  passed(mode + '-profile', 'Profile and ranking remain readable after rapid navigation', [mode + '-profile.jpeg']);
  c.tap('分类', c.tabs());
}
async function dialogs(mode) {
  c.theme(mode); c.open('tictactoe');
  let ns = c.layout(), cells = c.board(ns); c.assert.equal(cells.length, 9);
  const reset = header(ns, '重新开始');
  for (const i of [0, 3, 1, 4]) c.click(cells[i]);
  const frames = await sampleMotion(cells[2], mode + '-win-entry');
  ns = result('玩家 1 获胜'); c.capture(mode + '-win');
  c.click(reset); c.assert(c.find(c.layout(), '再来一局'));
  c.capture(mode + '-win-blocked');
  passed(mode + '-win-modal', 'Winning result appears; scrim prevents covered restart controls receiving taps',
    [mode + '-win.jpeg', mode + '-win-blocked.jpeg', ...frames]);
  const restart = header(ns, '再来一局');
  c.shell('uitest', 'uiInput', 'doubleClick', ...center(restart).map(String));
  ns = c.wait(a => !c.find(a, '再来一局')); emptyDuel(ns); c.capture(mode + '-double-restart');
  passed(mode + '-double-restart', 'Double tapping result restart closes once and leaves an empty zero-move board', [mode + '-double-restart.jpeg']);
  cells = c.board(ns); for (const i of [0, 3, 1, 4, 8, 5]) c.click(cells[i]);
  result('玩家 2 获胜'); c.capture(mode + '-player2-win');
  c.tap('再来一局'); ns = c.wait(a => !c.find(a, '再来一局')); cells = c.board(ns);
  for (const i of [0, 1, 2, 4, 3, 5, 7, 6, 8]) c.click(cells[i]);
  ns = result('平局'); c.capture(mode + '-draw'); c.tap('再来一局', ns);
  ns = c.wait(a => !c.find(a, '再来一局')); emptyDuel(ns);
  passed(mode + '-result-variants', 'Player 2 win and draw both settle, close and restart correctly', [mode + '-player2-win.jpeg', mode + '-draw.jpeg']);
  c.click(c.board(ns)[0]);
  for (let i = 0; i < 3; i++) {
    c.shell('uitest', 'uiInput', 'keyEvent', 'Back'); ns = c.wait(a => c.find(a, '确认退出？'));
    c.capture(mode + '-exit-' + i);
    const cancel = header(ns, '继续对局');
    if (i === 2) c.shell('uitest', 'uiInput', 'doubleClick', ...center(cancel).map(String)); else c.click(cancel);
    ns = c.wait(a => !c.find(a, '确认退出？'));
    c.assert(c.text(ns).some(t => t.includes('玩家 2 回合')));
    c.assert.equal(c.board(ns).filter(n => c.descendants(n).filter(d => d.type === 'Image').length === 2).length, 1,
      'Canceled exit preserves the single played piece');
  }
  c.shell('uitest', 'uiInput', 'keyEvent', 'Back'); ns = c.wait(a => c.find(a, '确认退出？'));
  const framesOut = await sampleMotion(header(ns, '退出'), mode + '-exit-out');
  c.wait(a => a.some(n => n.type === 'TextInput')); c.capture(mode + '-exit-return');
  passed(mode + '-exit-modal', 'Exit opens/cancels 3 times, double cancel preserves progress, confirm returns to catalog',
    [mode + '-exit-2.jpeg', mode + '-exit-return.jpeg', ...framesOut]);
}
async function controls(mode) {
  c.theme(mode); let ns = c.open('snake'); c.click(header(ns, '向右')); c.click(header(ns, '暂停'));
  ns = c.layout();
  c.assert(!c.find(ns, '再来一局'), 'Pausing keeps the live board out of result state');
  c.assert(!c.find(ns, '按方向键开始'), 'The snake has actually started');
  const imagePositions = a => a.filter(n => n.type === 'Image').map(n => n.bounds).sort();
  const pausedPositions = imagePositions(ns); c.sleep(1000);
  c.assert.deepEqual(imagePositions(c.layout()), pausedPositions, 'Pause stops live snake movement');
  c.capture(mode + '-snake-paused');
  const control = header(ns, '向左');
  const press = await pressCancel(control, mode + '-direction');
  c.assert(press.widthRatio > 0.93 && press.widthRatio < 0.995, 'Held direction button visibly compresses');
  passed(mode + '-direction-press', 'Native direction button press and cancellation restore bounds while paused', press.evidence, press);
  ns = c.layout(); c.click(header(ns, '继续'));
  ns = c.wait(a => c.find(a, '再来一局'), 15000); c.capture(mode + '-loss');
  c.tap('再来一局', ns); ns = c.wait(a => !c.find(a, '再来一局'));
  c.assert(c.find(ns, '按方向键开始')); c.click(header(ns, '向右')); c.click(header(ns, '暂停'));
  ns = c.capture(mode + '-loss-restart');
  c.assert(!c.find(ns, '再来一局') && !c.find(ns, '按方向键开始'), 'Restart recovers a started, paused live board');
  passed(mode + '-pause-loss-restart', 'Pause/resume works; natural wall collision settles and restart recovers a live board',
    [mode + '-snake-paused.jpeg', mode + '-loss.jpeg', mode + '-loss-restart.jpeg']);
  c.back();
}
function restore() {
  c.theme('restore');
  const original = JSON.parse(c.fs.readFileSync(c.path.join(c.dir, 'original-settings.json')));
  const raw = JSON.parse(c.fs.readFileSync(c.path.join(c.dir, 'settings-restore.json')));
  const nodes = []; const visit = n => { nodes.push(n); (n.children || []).forEach(visit); }; visit(raw);
  const selected = nodes.filter(n => n.attributes.type === 'Button' && n.attributes.description === '已选择');
  c.assert(selected.some(n => JSON.stringify(n).includes(original.theme)));
  c.assert.deepEqual(nodes.filter(n => n.attributes.type === 'Toggle').map(n => n.attributes.checked), original.toggles.map(n => n.checked));
  c.tap('精选', c.tabs()); c.sleep(600); c.capture('finished-home');
  state.settingsRestored = { theme: original.theme, toggles: original.toggles.map(n => n.checked), verified: true };
  state.finishedAt = new Date().toISOString(); save();
  console.log('Original settings restored; phone at Featured.');
}
async function main() {
  const stage = process.argv[2], mode = process.argv[3];
  if (stage === 'catalog') await catalog(mode);
  else if (stage === 'dialogs') await dialogs(mode);
  else if (stage === 'controls') await controls(mode);
  else if (stage === 'restore') restore();
  else throw Error('Use catalog/dialogs/controls light|dark, or restore');
  state.completedStages = (state.completedStages || []).filter(s => s !== process.argv.slice(2).join(' '));
  state.completedStages.push(process.argv.slice(2).join(' '));
  if (state.incomplete && state.incomplete.stage.join(' ') === process.argv.slice(2).join(' ')) delete state.incomplete;
  save();
}
main().catch(e => { state.incomplete = { stage: process.argv.slice(2), error: e.stack, at: new Date().toISOString() }; save(); c.log('motion-check-incomplete', state.incomplete); console.error(e.stack); process.exitCode = 1; });
