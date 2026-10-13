// Checks use only rendered UI, native input, and screenshots from the connected tablet.
process.env.LITTLEGAMES_ART_OUTPUT ||= 'docs/device-acceptance/settings-polish-2026-10-04';
const c = require('./device-art-review.cjs');
const strings = new Map(JSON.parse(c.fs.readFileSync('entry/src/main/resources/zh_CN/element/string.json')).string.map(s => [s.name, s.value]));
for (const [name, value] of strings) if (/^game_.+_name$/.test(name)) c.names[name.slice(5, -5)] = value;
const summaryFile = c.path.join(c.dir, 'summary.json');
const summary = c.fs.existsSync(summaryFile) ? JSON.parse(c.fs.readFileSync(summaryFile)) :
  { target: c.target, packageSha256: c.packageHash, checks: [] };
c.assert.equal(summary.packageSha256, c.packageHash);
function passed(id, evidence, detail) {
  summary.checks = summary.checks.filter(check => check.id !== id);
  summary.checks.push({ id, evidence, detail, at: new Date().toISOString() });
  c.fs.writeFileSync(summaryFile, JSON.stringify(summary, null, 2) + '\n'); console.log('PASS ' + id);
}
const sheet = ns => ns.some(n => n.id === 'game-settings-panel');
function settings() {
  const ns = c.layout(); if (!sheet(ns)) c.click(ns.find(n => n.id === 'game-settings-button'));
  return c.wait(ns => sheet(ns) && ns.some(n => n.id === 'game-settings-return'));
}
function returned() { return c.wait(ns => !sheet(ns) && ns.some(n => n.id === 'game-settings-button')); }
function close() { c.click(c.layout().find(n => n.id === 'game-settings-return')); return returned(); }
function open(id) {
  let ns = c.layout(); if (sheet(ns)) ns = close();
  if (ns.some(n => n.id === 'game-settings-button')) c.back();
  c.tap('分类', c.tabs()); return c.open(id);
}
function footer(ns) {
  const button = ns.find(n => n.id === 'game-settings-return'), panel = ns.find(n => n.id === 'game-settings-panel');
  c.assert(button && panel); const b = c.bounds(button), p = c.bounds(panel);
  c.assert(b[0] >= p[0] && b[2] <= p[2] && b[1] >= p[1] && b[3] <= p[3], 'Return button must fit in panel'); return b;
}
function panels() {
  for (const id of ['2048', 'sudoku', 'fruitslice']) {
    open(id); let ns = settings(); const fixed = footer(ns); c.capture('tablet-' + id + '-settings');
    c.tap(strings.get('game_settings_rules'), ns);
    ns = c.wait(a => c.find(a, strings.get('game_' + id + '_rules')));
    c.assert.deepEqual(footer(ns), fixed); c.capture('tablet-' + id + '-rules-fixed-footer'); close(); c.back();
  }
  passed('fixed-footer', ['tablet-2048-settings.jpeg', 'tablet-sudoku-rules-fixed-footer.jpeg', 'tablet-fruitslice-rules-fixed-footer.jpeg'],
    'Return stays fully visible and in the same position with rules expanded in three representative games.');
}
function protection() {
  open('guessnumber'); c.tap('1'); const before = c.text(c.layout());
  settings(); c.tap(strings.get('header_restart'));
  let ns = c.wait(a => c.find(a, strings.get('game_settings_restart_confirm'))); c.capture('tablet-restart-confirm');
  c.tap(strings.get('settings_cancel'), ns); c.wait(a => sheet(a) && !c.find(a, strings.get('game_settings_restart_confirm')));
  c.assert.deepEqual(c.text(close()), before);
  ns = settings(); const selected = ns.filter(n => n.type === 'Button' && n.description === '已选择');
  const selectedText = selected.flatMap(n => c.descendants(n).filter(d => d.type === 'Text').map(d => d.text));
  const next = selectedText.includes('困难') ? '简单' : '困难'; c.tap(next, ns);
  c.wait(a => c.find(a, strings.get('game_settings_difficulty_confirm'))); c.capture('tablet-difficulty-confirm');
  c.shell('uitest', 'uiInput', 'keyEvent', 'Back');
  c.wait(a => sheet(a) && !c.find(a, strings.get('game_settings_difficulty_confirm')));
  c.assert.deepEqual(c.text(close()), before);
  settings(); c.tap(strings.get('header_restart')); ns = c.wait(a => c.find(a, strings.get('game_settings_restart_confirm')));
  const confirm = ns.filter(n => n.type === 'Button' && c.descendants(n).some(d => d.text === strings.get('header_restart'))).pop();
  c.assert(confirm); c.click(confirm); ns = returned(); c.assert.notDeepEqual(c.text(ns), before);
  settings(); c.tap(strings.get('header_restart')); returned(); c.back();
  passed('progress-protection', ['tablet-restart-confirm.jpeg', 'tablet-difficulty-confirm.jpeg'],
    'An unsubmitted guess is protected; cancel and system Back preserve it; confirmed restart clears it; untouched game restarts directly.');
}
function audio() {
  open('melody'); let ns = settings(); const toggle = ns.find(n => n.type === 'Toggle'); c.assert(toggle);
  const original = toggle.checked; c.fs.writeFileSync(c.path.join(c.dir, 'original-sound.json'), JSON.stringify({ checked: original }));
  if (original === 'true') { c.click(toggle); c.wait(a => a.some(n => n.type === 'Toggle' && n.checked === 'false')); }
  c.capture('tablet-melody-sound-off'); ns = close(); c.assert(c.find(ns, strings.get('settings_sound_muted')));
  c.tap(strings.get('expansion_play_melody'), ns); c.wait(a => c.find(a, strings.get('expansion_listen')));
  c.capture('tablet-muted-melody-visual-cues');
  ns = settings();
  for (let i = 0; i < 3 && !c.find(ns, strings.get('game_settings_page')); i++) {
    const b = c.bounds(ns.find(n => n.id === 'game-settings-content')), x = Math.round((b[0] + b[2]) / 2);
    c.shell('uitest', 'uiInput', 'swipe', '' + x, '' + (b[3] - 40), '' + x, '' + (b[1] + 40), '600'); ns = c.layout();
  }
  c.tap(strings.get('game_settings_page'), ns); ns = c.wait(a => c.find(a, strings.get('settings_sound')));
  const soundText = c.find(ns, strings.get('settings_sound'));
  const row = ns.find(n => n.type === 'Row' && c.descendants(n).some(d => d.text === soundText.text) && c.descendants(n).some(d => d.type === 'Toggle'));
  c.assert(row); const soundToggle = c.descendants(row).find(d => d.type === 'Toggle'); c.assert.equal(soundToggle.checked, 'false');
  c.capture('tablet-app-settings-sound-off');
  c.shell('uitest', 'uiInput', 'keyEvent', 'Back'); returned();
  // Restart the application through its normal ability entry to check persisted preference.
  c.shell('aa', 'force-stop', 'com.littlegames.collection'); c.shell('aa', 'start', '-a', 'EntryAbility', '-b', 'com.littlegames.collection');
  c.wait(a => c.find(a, '精选')); open('melody'); ns = c.layout(); c.assert(c.find(ns, strings.get('settings_sound_muted')));
  ns = settings(); const persisted = ns.find(n => n.type === 'Toggle'); c.assert.equal(persisted.checked, 'false');
  if (original === 'true') { c.click(persisted); c.wait(a => a.some(n => n.type === 'Toggle' && n.checked === 'true')); }
  close(); c.back();
  passed('sound-preference', ['tablet-melody-sound-off.jpeg', 'tablet-muted-melody-visual-cues.jpeg', 'tablet-app-settings-sound-off.jpeg'],
    'Game and app settings share sound preference; mute retains visual playback, survives app restart, and original preference is restored.');
}
function dark() {
  c.theme('dark'); open('sudoku'); settings(); c.tap(strings.get('game_settings_rules')); footer(c.layout()); c.capture('tablet-dark-fixed-footer');
  close(); c.back(); c.theme('restore'); c.tap('精选', c.tabs());
  passed('dark-theme', ['tablet-dark-fixed-footer.jpeg'], 'Dark-mode rules and footer checked; original theme restored.');
}
function newPuzzle() {
  const blankCell = n => n.type === 'Stack' && n.clickable === 'true' &&
    c.bounds(n)[2] - c.bounds(n)[0] === c.bounds(n)[3] - c.bounds(n)[1] &&
    c.descendants(n).every(d => d.type !== 'Text' || d.text.length === 0);
  let ns = open('sudoku'); ns = c.wait(a => a.some(blankCell));
  c.click(ns.find(blankCell));
  const keys = c.layout().filter(n => n.type === 'Button' && c.descendants(n).some(d => d.text === '1'));
  c.assert(keys.length); c.click(keys.sort((a, b) => c.bounds(b)[1] - c.bounds(a)[1])[0]);
  const before = c.text(c.layout()); settings(); c.tap(strings.get('header_new_game'));
  ns = c.wait(a => c.find(a, strings.get('game_settings_new_game_confirm'))); c.capture('tablet-new-game-confirm');
  c.tap(strings.get('settings_cancel'), ns); c.wait(a => sheet(a) && !c.find(a, strings.get('game_settings_new_game_confirm')));
  c.assert.deepEqual(c.text(close()), before); c.back();
  passed('new-puzzle-protection', ['tablet-new-game-confirm.jpeg'], 'A filled Sudoku cell triggers new-game confirmation; cancel retains the puzzle and entry.');
}
const actions = { panels, protection, audio, dark, newPuzzle };
c.assert(actions[process.argv[2]], 'Choose panels, protection, audio, dark, or newPuzzle'); actions[process.argv[2]]();
