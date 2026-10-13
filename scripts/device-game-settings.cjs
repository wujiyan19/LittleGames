// Rendered-UI checks only: game settings, pause, rules and return from app settings.
process.env.LITTLEGAMES_ART_OUTPUT = process.env.LITTLEGAMES_ART_OUTPUT || 'docs/device-acceptance/game-settings-2026-10-03';
const c = require('./device-art-review.cjs');
const strings = new Map(JSON.parse(c.fs.readFileSync('entry/src/main/resources/zh_CN/element/string.json')).string.map(s => [s.name, s.value]));
for (const [name, value] of strings) {
  if (/^game_.+_name$/.test(name)) c.names[name.slice(5, -5)] = value;
}
const summaryFile = c.path.join(c.dir, 'summary.json');
const summary = c.fs.existsSync(summaryFile) ? JSON.parse(c.fs.readFileSync(summaryFile)) :
  { target: c.target, packageSha256: c.packageHash, checks: [] };
c.assert.equal(summary.packageSha256, c.packageHash);
function passed(id, evidence, detail) {
  summary.checks = summary.checks.filter(check => check.id !== id);
  summary.checks.push({ id, evidence, detail, at: new Date().toISOString() });
  c.fs.writeFileSync(summaryFile, JSON.stringify(summary, null, 2) + '\n');
  console.log('PASS ' + id);
}
function sheet(ns = c.layout()) { return ns.some(n => n.id === 'game-settings-panel'); }
function settings() {
  let ns = c.layout();
  if (!sheet(ns)) {
    const gear = ns.find(n => n.id === 'game-settings-button'); c.assert(gear); c.click(gear);
  }
  return c.wait(ns => sheet(ns) && ns.some(n => n.id === 'game-settings-return'));
}
function close() {
  c.shell('uitest', 'uiInput', 'keyEvent', 'Back');
  return c.wait(ns => !sheet(ns));
}
function confirmPending(label) {
  const ns = c.wait(a => !sheet(a) || c.find(a, strings.get('game_settings_restart_confirm')) || c.find(a, strings.get('game_settings_difficulty_confirm')));
  if (!sheet(ns)) { return; }
  const button = ns.filter(n => n.type === 'Button' && c.descendants(n).some(d => d.text === label)).pop();
  c.assert(button); c.click(button);
}
function open(id) {
  if (sheet()) close();
  let ns = c.layout();
  if (!ns.some(n => n.type === 'TextInput')) {
    if (ns.some(n => n.id === 'game-settings-button')) c.back();
    c.tap('分类', c.tabs());
  }
  // The art helper's names list covers classic and collection games; expansion uses its catalog resource.
  c.names[id] = strings.get('game_' + id + '_name');
  c.assert(c.names[id]); return c.open(id);
}
function panels(ids) {
  for (const id of ids) {
    const ns = open(id);
    c.assert.equal(ns.filter(n => n.type === 'Button' && c.bounds(n)[1] < 200).length, 2);
    let panel = settings();
    const pause = ['snake', 'tetris', 'whackmole', 'brickbreaker', 'fruitslice'].includes(id);
    c.assert.equal(!!c.find(panel, '暂停'), pause, id + ' pause capability');
    c.tap('游戏玩法说明', panel);
    panel = c.wait(a => c.find(a, strings.get('game_' + id + '_rules')));
    c.capture('tablet-' + id + '-rules');
    if (id === 'sudoku') c.assert(c.find(panel, '新游戏'));
    close(); settings(); c.tap('重新开始');
    confirmPending(strings.get('header_restart'));
    c.wait(a => !sheet(a) && a.some(n => n.id === 'game-settings-button'));
    passed('panel-' + id, ['tablet-' + id + '-rules.jpeg'], 'Unified settings, complete rules, supported pause and restart');
    c.back();
  }
}
function appSettings() {
  open('2048'); const before = c.text(c.layout()); settings(); c.tap(strings.get('game_settings_page'));
  let app = c.wait(a => c.find(a, '主题模式')); c.capture('tablet-app-settings');
  for (let i = 0; i < 3 && !c.find(app, '关于软件'); i++) {
    const scroll = app.find(n => n.type === 'Scroll'); c.assert(scroll);
    const b = c.bounds(scroll), x = Math.round((b[0] + b[2]) / 2);
    c.shell('uitest', 'uiInput', 'swipe', '' + x, '' + (b[3] - 70), '' + x, '' + (b[1] + 70), '600');
    c.sleep(250); app = c.layout();
  }
  c.tap('关于软件', app); c.wait(a => c.find(a, strings.get('settings_statement_title')));
  c.capture('tablet-game-app-about');
  c.shell('uitest', 'uiInput', 'keyEvent', 'Back'); c.wait(a => c.find(a, '设置') && !c.find(a, strings.get('settings_statement_title')));
  c.shell('uitest', 'uiInput', 'keyEvent', 'Back');
  const returned = c.wait(a => a.some(n => n.id === 'game-settings-button') && !sheet(a));
  c.assert(!c.find(returned, '确认退出？'));
  c.assert.deepEqual(c.text(returned), before);
  c.capture('tablet-app-settings-return');
  settings(); c.tap('困难'); confirmPending(strings.get('game_settings_change_action')); c.wait(a => !sheet(a));
  let ns = settings(); const selected = ns.filter(n => n.type === 'Button' && n.description === '已选择');
  c.assert(selected.some(n => c.descendants(n).some(d => d.text === '困难')));
  c.capture('tablet-difficulty-hard'); c.tap('普通'); confirmPending(strings.get('game_settings_change_action')); c.wait(a => !sheet(a));
  passed('app-settings-and-difficulty', ['tablet-app-settings.jpeg', 'tablet-game-app-about.jpeg', 'tablet-app-settings-return.jpeg', 'tablet-difficulty-hard.jpeg'],
    'Game to app settings to About and back preserves board; difficulty changes and selection updates');
  c.back();
}
function themes() {
  c.theme('dark'); open('2048'); let ns = settings(); c.tap('游戏玩法说明', ns);
  c.wait(a => c.find(a, strings.get('game_2048_rules'))); c.capture('tablet-dark-2048-rules');
  close(); c.back();
  open('fruitslice'); settings(); c.capture('tablet-dark-fruitslice-settings'); close(); c.back();
  c.theme('restore'); c.tap('精选', c.tabs()); c.capture('tablet-final-featured');
  passed('dark-theme-and-restore', ['tablet-dark-2048-rules.jpeg', 'tablet-dark-fruitslice-settings.jpeg', 'tablet-final-featured.jpeg'],
    'Dark settings are readable; original theme restored and left on Featured');
}
function pause() {
  open('whackmole'); let ns = settings();
  const frozen = c.text(ns); c.sleep(1800); c.assert.deepEqual(c.text(c.layout()), frozen);
  c.tap('暂停', ns); c.wait(a => !sheet(a)); c.sleep(1400);
  ns = settings(); c.assert(c.find(ns, '继续')); c.capture('tablet-manual-pause');
  close(); c.sleep(1600); ns = settings(); c.assert(c.find(ns, '继续'));
  c.tap('继续', ns); c.wait(a => !sheet(a));
  ns = settings(); c.assert(c.find(ns, '暂停')); c.capture('tablet-resumed-settings');
  close();
  passed('pause-and-resume', ['tablet-manual-pause.jpeg', 'tablet-resumed-settings.jpeg'],
    'Sheet freezes countdown, deliberate pause survives dismissal and Resume restores play');
  c.back();
}
const action = process.argv[2];
if (action === 'panels') panels(process.argv.slice(3));
else if (action === 'app') appSettings();
else if (action === 'pause') pause();
else if (action === 'themes') themes();
else throw new Error('Use panels <ids>, app, pause or themes');
