// Accept the new history flow using only rendered UI and official HDC input.
process.env.LITTLEGAMES_ART_TARGET ||= '49X0224C24001554';
process.env.LITTLEGAMES_ART_OUTPUT ||= 'docs/device-acceptance/play-history-2026-10-04/final';
const c = require('./device-art-review.cjs');
const strings = new Map(JSON.parse(c.fs.readFileSync('entry/src/main/resources/zh_CN/element/string.json')).string.map(s => [s.name, s.value]));
for (const [name, value] of strings) if (/^game_.+_name$/.test(name)) c.names[name.slice(5, -5)] = value;
c.names.history = strings.get('play_history_title');
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
const history = ns => ns.some(n => n.id === 'play_history_list');
const rows = ns => ns.filter(n => n.id?.startsWith('history_game_')).sort((a, b) => c.bounds(a)[1] - c.bounds(b)[1]);
const rowText = row => c.descendants(row).filter(n => n.type === 'Text').map(n => n.text).join(' | ');
function enter() {
  let ns = c.layout();
  if (!history(ns)) {
    c.tap('精选', c.tabs()); ns = c.wait(a => a.some(n => n.id === 'featured_history_button'));
    c.capture('tablet-featured-entry'); c.click(ns.find(n => n.id === 'featured_history_button'));
  }
  return c.wait(history);
}
function swipe(up) {
  const ns = c.layout(), b = c.bounds(ns.find(n => n.id === 'play_history_list'));
  const x = Math.round((b[0] + b[2]) / 2), top = b[1] + 60, bottom = b[3] - 60;
  c.shell('uitest', 'uiInput', 'swipe', '' + x, '' + (up ? bottom : top), '' + x, '' + (up ? top : bottom), '600');
  return c.layout();
}
function top() {
  let ns = c.layout();
  for (let i = 0; i < 10; i++) {
    const before = rows(ns).map(n => n.id + n.bounds).join('|'); ns = swipe(false);
    if (rows(ns).map(n => n.id + n.bounds).join('|') === before) return ns;
  }
  return ns;
}
function featured() {
  c.shell('uitest', 'uiInput', 'keyEvent', 'Back');
  return c.wait(a => a.some(n => n.id === 'featured_history_button'));
}
function entry() {
  c.shell('aa', 'start', '-a', 'EntryAbility', '-b', 'com.littlegames.collection');
  c.sleep(1200);
  let ns = enter(); c.capture('tablet-history-initial');
  const countText = c.text(ns).find(t => /^共 \d+ 款/.test(t)); c.assert(countText);
  const count = Number(countText.match(/\d+/)[0]); c.assert(count > 5, 'Need more than five existing played games');
  const seen = new Set(rows(ns).map(n => n.id));
  for (let i = 0; i < 30 && seen.size < count; i++) {
    ns = swipe(true); for (const row of rows(ns)) seen.add(row.id);
  }
  c.assert.equal(seen.size, count, 'Every played game should be reachable in the full list');
  c.capture('tablet-history-bottom'); top();
  passed('complete-history', ['tablet-featured-entry.jpeg', 'tablet-history-initial.jpeg', 'tablet-history-bottom.jpeg'],
    `${count} distinct played games are reachable; history includes all records beyond the five home shortcuts.`);
  console.log(JSON.stringify({ count, rows: rows(c.layout()).slice(0, 5).map(n => ({ id: n.id, description: n.description, bounds: n.bounds })) }));
}
function replay() {
  let ns = top(); const before = rows(ns); c.assert(before.length >= 3);
  const selected = before[2], id = selected.id.slice('history_game_'.length);
  const countText = c.text(ns).find(t => /^共 \d+ 款/.test(t)); c.sleep(1100); c.click(selected);
  c.wait(a => a.some(n => n.id === 'game-settings-button')); c.capture('tablet-game-from-history');
  c.shell('uitest', 'uiInput', 'keyEvent', 'Back');
  ns = c.wait(a => history(a) || c.find(a, '确认退出？'));
  if (!history(ns)) { c.tap('退出', ns); ns = c.wait(history); }
  ns = top(); c.assert.equal(rows(ns)[0].id, 'history_game_' + id);
  c.assert.equal(c.text(ns).find(t => /^共 \d+ 款/.test(t)), countText);
  c.assert(rowText(rows(ns)[0]).includes('最近游玩：'));
  c.assert(!rowText(rows(ns)[0]).includes(strings.get('play_history_time_unknown')));
  c.capture('tablet-history-replayed-first');
  ns = featured(); c.assert.equal(ns.filter(n => n.id?.startsWith('recent_game_'))[0].id, 'recent_game_' + id);
  c.capture('tablet-featured-replayed-first');
  passed('replay-refresh', ['tablet-game-from-history.jpeg', 'tablet-history-replayed-first.jpeg', 'tablet-featured-replayed-first.jpeg'],
    `${c.names[id]} opened from an older history row; return refreshes its timestamp and puts it first without duplicating it; home preview agrees.`);
}
function dark() {
  if (history(c.layout())) featured();
  c.theme('dark'); c.tap('精选', c.tabs()); enter(); top(); c.capture('tablet-history-dark');
  featured(); c.theme('restore'); c.tap('精选', c.tabs());
  enter(); c.capture('tablet-history-restored');
  passed('dark-theme', ['tablet-history-dark.jpeg', 'tablet-history-restored.jpeg'],
    'History renders in dark mode; original theme is restored and the final history page remains open.');
}
function restart() {
  let ns = enter(); ns = top(); const first = rowText(rows(ns)[0]);
  const countText = c.text(ns).find(t => /^共 \d+ 款/.test(t)); featured();
  c.shell('aa', 'force-stop', 'com.littlegames.collection');
  c.shell('aa', 'start', '-a', 'EntryAbility', '-b', 'com.littlegames.collection');
  c.sleep(1200);
  c.wait(a => a.some(n => n.id === 'featured_history_button')); ns = enter();
  c.assert.equal(rowText(rows(ns)[0]), first);
  c.assert.equal(c.text(ns).find(t => /^共 \d+ 款/.test(t)), countText);
  c.capture('tablet-history-relaunched');
  passed('persisted-history', ['tablet-history-relaunched.jpeg'], 'Full history count, newest game and its exact timestamp survive an application restart.');
}
const actions = { entry, replay, dark, restart };
c.assert(actions[process.argv[2]], 'Choose entry, replay, dark or restart'); actions[process.argv[2]]();
