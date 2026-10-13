process.env.LITTLEGAMES_ART_OUTPUT ||= 'docs/device-acceptance/ui-polish-2026-10-08';
const c = require('./device-art-review.cjs');
const strings = new Map(JSON.parse(c.fs.readFileSync('entry/src/main/resources/zh_CN/element/string.json')).string.map(s => [s.name, s.value]));
for (const [name, value] of strings) if (/^game_.+_name$/.test(name)) c.names[name.slice(5, -5)] = value;
const reportFile = c.path.join(c.dir, 'summary.json');
const report = c.fs.existsSync(reportFile) ? JSON.parse(c.fs.readFileSync(reportFile)) :
  { packageSha256: c.packageHash, target: c.target, checks: [] };
c.assert.equal(report.packageSha256, c.packageHash);
const byId = (ns, id) => ns.find(n => n.id === id);
const hasCatalog = ns => !!byId(ns, 'home_category_search');
const capture = tag => { c.layout(); c.sleep(500); return c.capture(tag); };
function pass(id, detail, evidence = []) {
  report.checks = report.checks.filter(x => x.id !== id);
  report.checks.push({ id, detail, evidence, at: new Date().toISOString() });
  c.fs.writeFileSync(reportFile, JSON.stringify(report, null, 2) + '\n');
  console.log('PASS ' + id + ': ' + detail);
}
function tab(label) {
  const ns = c.layout();
  const target = ns.filter(n => n.type === 'Text' && n.text === label && c.bounds(n)[1] > 2100).pop();
  c.click(target);
  c.wait(a => a.some(n => n.type === 'Text' && n.text === label && c.bounds(n)[1] < 400));
  c.sleep(400);
}
function appSettings() {
  c.click(byId(c.layout(), 'home_settings_button'));
  return c.wait(a => c.find(a, '主题模式'));
}
function setTheme(mode) {
  let ns = appSettings();
  const originalFile = c.path.join(c.dir, 'original-settings.json');
  if (!c.fs.existsSync(originalFile)) {
    const selected = ns.filter(n => n.type === 'Button' && n.description === '已选择')
      .flatMap(n => c.descendants(n).filter(d => d.type === 'Text').map(d => d.text));
    const theme = selected.find(t => ['浅色', '深色', '跟随系统'].includes(t)); c.assert(theme);
    c.fs.writeFileSync(originalFile, JSON.stringify({ theme,
      toggles: ns.filter(n => n.type === 'Toggle').map(n => ({ checked: n.checked, bounds: n.bounds })) }, null, 2));
  }
  const label = mode === 'restore' ? JSON.parse(c.fs.readFileSync(originalFile)).theme : mode === 'dark' ? '深色' : '浅色';
  c.tap(label, ns); c.sleep(450); capture('settings-' + mode);
  c.shell('uitest', 'uiInput', 'keyEvent', 'Back');
  c.wait(a => byId(a, 'home_settings_button'));
  pass('theme-' + mode, 'Theme selected through UI: ' + label, ['settings-' + mode + '.jpeg']);
}
function fronts(mode) {
  for (const label of ['精选', '分类', '我的']) {
    tab(label); capture(mode + '-' + ({ '精选': 'featured', '分类': 'category', '我的': 'profile' })[label]);
  }
  pass('fronts-' + mode, 'Three native tabs and fixed headers visible; screenshots captured.',
    ['featured', 'category', 'profile'].map(x => mode + '-' + x + '.jpeg'));
}
function swipeList(direction) {
  const ns = c.layout(), b = c.bounds(byId(ns, 'home_category_filters')), y = Math.round((b[1] + b[3]) / 2);
  c.shell('uitest', 'uiInput', 'swipe', direction === 'left' ? '1110' : '160', '' + y,
    direction === 'left' ? '160' : '1110', '' + y, '600');
  c.sleep(450); c.assert(hasCatalog(c.layout()), 'Filter gesture changed main tab');
}
function select(index) {
  const id = index < 0 ? 'category_filter_all' : 'category_filter_' + index;
  let ns = c.layout();
  for (let i = 0; i < 5 && (!byId(ns, id) || c.bounds(byId(ns, id))[2] - c.bounds(byId(ns, id))[0] < 80); i++) {
    swipeList(index < 0 ? 'right' : 'left'); ns = c.layout();
  }
  c.click(byId(ns, id));
  c.wait(a => byId(a, id)?.description === '已选择'); c.sleep(400);
  ns = c.layout();
  c.assert.equal(ns.filter(n => /^category_filter_/.test(n.id) && n.description === '已选择').length, 1);
  c.assert(c.bounds(byId(ns, id))[2] <= 1210, 'Selected filter is clipped at screen edge');
  return ns;
}
function filters() {
  tab('分类'); select(-1);
  const counts = [];
  for (let i = 0; i < 6; i++) {
    const ns = select(i); counts.push(c.text(ns).find(t => /\d+ 款游戏/.test(t)));
    console.log('FILTER ' + i + ': ' + counts[counts.length - 1]);
  }
  capture('category-last-filter'); swipeList('left'); swipeList('left');
  select(-1); c.assert(c.find(c.layout(), '100 款游戏'));
  swipeList('right'); swipeList('right');
  capture('category-all-filters');
  pass('all-filters', 'All seven choices reachable with one selection. Counts: ' + counts.join(', ') +
    '. Gestures at both list ends kept main Categories tab.', ['category-last-filter.jpeg', 'category-all-filters.jpeg']);
}
function typeSearch(text) {
  let ns = c.layout();
  const clear = byId(ns, 'home_search_clear'); if (clear) { c.click(clear); ns = c.wait(a => !byId(a, 'home_search_clear')); }
  const b = c.bounds(byId(ns, 'home_category_search'));
  c.shell('uitest', 'uiInput', 'inputText', '' + Math.round((b[0] + b[2]) / 2), '' + Math.round((b[1] + b[3]) / 2), text);
  c.wait(a => byId(a, 'home_category_search')?.text === text);
  c.shell('uitest', 'uiInput', 'keyEvent', 'Back'); c.sleep(300);
}
function search() {
  tab('分类'); select(-1); typeSearch('2048');
  c.assert(c.find(c.layout(), '1 款游戏')); capture('search-2048');
  select(5); c.assert(c.find(c.layout(), '0 款游戏')); capture('search-category-intersection');
  const categoryCount = c.descendants(byId(c.layout(), 'category_filter_5')).find(n => n.type === 'Text' && /^\d+$/.test(n.text)).text;
  c.click(byId(c.layout(), 'home_search_clear')); c.wait(a => !byId(a, 'home_search_clear'));
  c.assert(c.find(c.layout(), categoryCount + ' 款游戏')); select(-1); typeSearch('zzzzzz');
  c.assert(c.find(c.layout(), '0 款游戏')); capture('search-empty');
  c.click(byId(c.layout(), 'home_search_clear')); c.wait(a => c.find(a, '100 款游戏'));
  pass('search', 'Name search, category intersection, empty state, and clear restoring current category passed.',
    ['search-2048.jpeg', 'search-category-intersection.jpeg', 'search-empty.jpeg']);
}
function scrollState() {
  tab('分类'); select(0);
  const first = () => c.layout().find(n => n.type === 'Column' && n.clickable === 'true' && n.text && c.bounds(n)[1] >= 819)?.text;
  const categoryTop = first(); c.assert(categoryTop);
  select(-1); const allTop = first(); c.assert(allTop);
  const scroll = () => { c.shell('uitest', 'uiInput', 'swipe', '600', '2110', '600', '1070', '550'); c.sleep(400); };
  scroll(); scroll();
  const before = first(); c.assert(before && before !== allTop);
  select(-1); c.assert.equal(first(), before);
  tab('精选'); tab('分类'); c.assert.equal(first(), before);
  select(0); c.assert.equal(first(), categoryTop);
  capture('category-switched-top'); select(-1);
  pass('scroll-state', 'Same filter and main-tab roundtrip retain position; changing filter returns content to top.', ['category-switched-top.jpeg']);
}
function history() {
  tab('精选'); c.click(byId(c.layout(), 'featured_history_button'));
  let ns = c.wait(a => byId(a, 'play_history_list'));
  c.assert(ns.some(n => /^history_game_/.test(n.id))); capture('play-history');
  c.click(ns.find(n => /^history_game_/.test(n.id)));
  c.wait(a => byId(a, 'game-settings-button')); capture('history-game');
  c.shell('uitest', 'uiInput', 'keyEvent', 'Back');
  ns = c.wait(a => byId(a, 'play_history_list') || c.find(a, '确认退出？'));
  if (c.find(ns, '确认退出？')) { c.tap('退出', ns); c.wait(a => byId(a, 'play_history_list')); }
  c.shell('uitest', 'uiInput', 'keyEvent', 'Back'); c.wait(a => byId(a, 'featured_history_button'));
  pass('history', 'History opens, existing record launches game, and navigation returns to Featured.', ['play-history.jpeg', 'history-game.jpeg']);
}
function panel(mode) {
  tab('分类'); select(-1); typeSearch('2048');
  const card = c.layout().find(n => n.type === 'Column' && n.clickable === 'true' && n.text?.startsWith('2048,'));
  c.click(card); c.wait(a => byId(a, 'game-settings-button')); capture(mode + '-2048');
  c.click(byId(c.layout(), 'game-settings-button')); c.wait(a => byId(a, 'game-settings-return'));
  const before = c.bounds(byId(c.layout(), 'game-settings-return'));
  c.tap('游戏玩法说明'); c.wait(a => c.text(a).some(t => t.includes('向上、下、左、右滑动棋盘')));
  const ns = capture(mode + '-game-settings');
  c.assert.deepEqual(c.bounds(byId(ns, 'game-settings-return')), before);
  const p = c.bounds(byId(ns, 'game-settings-panel'));
  c.assert(before[0] >= p[0] && before[2] <= p[2] && before[1] >= p[1] && before[3] <= p[3]);
  c.click(byId(ns, 'game-settings-return')); c.wait(a => !byId(a, 'game-settings-panel'));
  c.shell('uitest', 'uiInput', 'keyEvent', 'Back');
  const back = c.wait(a => hasCatalog(a) || c.find(a, '确认退出？'));
  if (c.find(back, '确认退出？')) {
    capture(mode + '-exit-confirm');
    c.tap('继续对局', back); c.wait(a => byId(a, 'game-settings-button') && !c.find(a, '确认退出？'));
    c.shell('uitest', 'uiInput', 'keyEvent', 'Back'); c.wait(a => c.find(a, '确认退出？'));
    c.tap('退出'); c.wait(hasCatalog);
    pass('exit-dialog-' + mode, 'Exit confirmation shown; cancel returns to game and confirm returns to catalog.', [mode + '-exit-confirm.jpeg']);
  }
  c.click(byId(c.layout(), 'home_search_clear')); c.wait(a => c.find(a, '100 款游戏'));
  pass('game-settings-' + mode, 'Game header, sheet/rules and fixed fully visible return button passed; catalog state restored.',
    [mode + '-2048.jpeg', mode + '-game-settings.jpeg']);
}
function about(mode) {
  appSettings();
  for (let i = 0; i < 3 && !c.find(c.layout(), strings.get('settings_about')); i++) {
    c.shell('uitest', 'uiInput', 'swipe', '600', '2250', '600', '900', '600'); c.sleep(350);
  }
  c.tap(strings.get('settings_about')); c.wait(a => c.find(a, strings.get('settings_statement_title'))); capture(mode + '-about');
  c.shell('uitest', 'uiInput', 'keyEvent', 'Back'); c.wait(a => c.find(a, '设置'));
  c.shell('uitest', 'uiInput', 'keyEvent', 'Back'); c.wait(a => byId(a, 'home_settings_button'));
  pass('about-' + mode, 'Settings to About and two-level return passed.', [mode + '-about.jpeg']);
}
function resultDialog(mode) {
  tab('分类'); select(-1); typeSearch(c.names.reaction);
  const card = c.layout().find(n => n.type === 'Column' && n.clickable === 'true' && n.text?.startsWith(c.names.reaction + ','));
  c.click(card); c.wait(a => c.find(a, '点击开始')); c.tap('点击开始');
  c.wait(a => c.find(a, '现在点击！'), 10000); c.tap('现在点击！');
  c.wait(a => c.find(a, '再来一局')); capture(mode + '-result');
  c.tap('再来一局'); c.wait(a => c.find(a, '点击开始')); c.tap('点击开始');
  c.wait(a => c.find(a, '现在点击！'), 10000); c.tap('现在点击！');
  c.wait(a => c.find(a, '再来一局')); c.tap('退出'); c.wait(hasCatalog);
  c.click(byId(c.layout(), 'home_search_clear')); c.wait(a => c.find(a, '100 款游戏'));
  pass('result-dialog-' + mode, 'Completed a reaction game, replayed through result action and exited a second result.', [mode + '-result.jpeg']);
}
const action = process.argv[2], arg = process.argv[3];
if (action === 'fronts') fronts(arg);
else if (action === 'theme') setTheme(arg);
else if (action === 'filters') filters();
else if (action === 'search') search();
else if (action === 'scroll') scrollState();
else if (action === 'history') history();
else if (action === 'panel') panel(arg);
else if (action === 'about') about(arg);
else if (action === 'result') resultDialog(arg);
else if (action === 'all') {
  setTheme('light'); fronts('light'); filters(); search(); scrollState(); history();
  panel('light'); resultDialog('light'); about('light');
  setTheme('dark'); fronts('dark'); panel('dark'); resultDialog('dark'); about('dark');
  setTheme('restore'); tab('精选'); capture('finished-home');
  report.completedAt = new Date().toISOString(); report.finalState = 'Original theme restored; Featured foreground';
  c.fs.writeFileSync(reportFile, JSON.stringify(report, null, 2) + '\n');
}
else if (action === 'capture') capture(arg);
else throw Error('Unknown action');
