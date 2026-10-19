// Real phone acceptance: only rendered UI, screenshots and normal HDC input.
// Historical 89-game harness: requires its matching catalog and HAP; see the dated evidence README.
// Resume: node scripts/device-three-settlements.cjs run [game-id ...]
const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '..');
const output = path.resolve(root, process.env.LITTLEGAMES_THREE_OUTPUT || 'docs/device-acceptance/three-settlements-2026-10-14');
fs.mkdirSync(output, { recursive: true });
const hdc = 'C:/Program Files/Huawei/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe';
const target = process.env.LITTLEGAMES_ART_TARGET || 'FMR0224521016052';
const bundle = 'com.littlegames.collection';
const packageFile = path.join(root, 'entry/build/default/outputs/default/entry-default-signed.hap');
const hash = () => crypto.createHash('sha256').update(fs.readFileSync(packageFile)).digest('hex');
const packageSha256 = hash();
const source = name => fs.readFileSync(path.join(root, 'entry/src/main/ets', name), 'utf8');
const retired = [...source('common/GameAvailability.ets').match(/RETIRED_GAME_IDS[^=]+=\s*\[([^\]]+)/)[1].matchAll(/'([a-z0-9]+)'/g)].map(m => m[1]);
const strings = new Map(JSON.parse(fs.readFileSync(path.join(root, 'entry/src/main/resources/zh_CN/element/string.json'))).string.map(s => [s.name, s.value]));
const ids = ['GameData', 'CollectionCatalog', 'ExpansionCatalog'].flatMap(name => [...source('model/' + name + '.ets').matchAll(/\bid:\s*'([a-z0-9]+)'\s*,\s*name:/g)].map(m => m[1])).filter(id => !retired.includes(id));
assert.equal(ids.length, 89);
const reportFile = path.join(output, 'progress.json');
const report = fs.existsSync(reportFile) ? JSON.parse(fs.readFileSync(reportFile)) : {
  schemaVersion: 1, target, bundle, packageSha256, startedAt: new Date().toISOString(),
  scope: 'Actual phone UI play and three natural result dialogs per available game; wins and losses recorded separately. No model execution or injected state.',
  games: ids.map(id => ({ id, name: strings.get('game_' + id + '_name'), rounds: [], attempts: [], visualReview: 'pending' }))
};
assert.equal(report.packageSha256, packageSha256, 'HAP changed: use a new evidence directory');
assert.equal(report.target, target);
const save = () => {
  const reviewFile = path.join(output, 'visual-reviews.json');
  if (fs.existsSync(reviewFile)) {
    const reviews = JSON.parse(fs.readFileSync(reviewFile));
    for (const game of report.games) game.visualReview = reviews.passed.includes(game.id) ? 'passed' : 'pending';
  }
  report.updatedAt = new Date().toISOString();
  report.completedGames = report.games.filter(g => g.rounds.length >= 3).length;
  report.settlements = report.games.reduce((sum, g) => sum + g.rounds.length, 0);
  report.visualReviewedGames = report.games.filter(g => g.visualReview === 'passed').length;
  report.complete = report.completedGames === ids.length && report.games.every(g => g.visualReview === 'passed');
  fs.writeFileSync(reportFile, JSON.stringify(report, null, 2) + '\n');
};
const log = (action, detail = {}) => fs.appendFileSync(path.join(output, 'actions.jsonl'), JSON.stringify({ at: new Date().toISOString(), action, ...detail }) + '\n');
const run = (...args) => {
  if (args[0] === 'shell' && args.slice(1).join(' ').includes('uiInput')) log('input', { command: args.slice(1).join(' ') });
  const result = cp.execFileSync(hdc, ['-t', target, ...args], { encoding: 'utf8', timeout: 45000, maxBuffer: 4 * 1024 * 1024 });
  assert(!/^\s*\[Fail\]/m.test(result), result);
  return result;
};
const shell = (...args) => run('shell', ...args);
const sleep = ms => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
const bounds = n => n.bounds.match(/-?\d+/g).map(Number);
const center = n => { const b = bounds(n); return [Math.round((b[0] + b[2]) / 2), Math.round((b[1] + b[3]) / 2)]; };
let tree, lastNodes;
function layout() {
  const response = shell('uitest', 'dumpLayout', '-b', bundle, '-p', '/data/local/tmp/lg-three.json');
  assert(response.includes('DumpLayout saved to:'), response.trim());
  run('file', 'recv', '/data/local/tmp/lg-three.json', path.join(output, 'current.json'));
  tree = JSON.parse(fs.readFileSync(path.join(output, 'current.json')));
  const ns = [];
  const visit = (raw, parent) => {
    if (raw.attributes?.bounds && raw.attributes.visible !== 'false') ns.push({ ...raw.attributes, raw, parent });
    (raw.children || []).forEach(child => visit(child, raw));
  };
  visit(tree, null); lastNodes = ns; return ns;
}
const texts = ns => ns.filter(n => n.type === 'Text' && n.text).map(n => n.text);
const descendants = n => {
  const ns = []; const visit = raw => { ns.push(raw.attributes); (raw.children || []).forEach(visit); };
  (n.raw.children || []).forEach(visit); return ns;
};
const byId = (ns, id) => ns.find(n => n.id === id);
const find = (ns, label) => ns.find(n => n.type === 'Button' && n.enabled !== 'false' &&
  (n.text === label || n.description === label || descendants(n).some(d => d.type === 'Text' && d.text === label))) || ns.find(n => n.text === label || n.description === label);
const click = n => { assert(n, 'UI target absent'); const xy = center(n); shell('uitest', 'uiInput', 'click', ...xy.map(String)); };
const tap = (label, ns = layout()) => click(find(ns, label));
const batch = nodes => { assert(nodes.length); shell(nodes.map(n => 'uitest uiInput click ' + center(n).join(' ')).join('; ')); };
const swipe = (x1, y1, x2, y2, velocity = 1600) => shell('uitest', 'uiInput', 'swipe', ...[x1, y1, x2, y2, velocity].map(v => String(Math.round(v))));
function wait(predicate, timeout = 12000) {
  const end = Date.now() + timeout;
  do { const ns = layout(); if (predicate(ns)) return ns; sleep(150); } while (Date.now() < end);
  throw Error('Expected UI absent: ' + texts(lastNodes).join(' | '));
}
function shot(tag) {
  const ns = layout();
  shell('snapshot_display', '-f', '/data/local/tmp/lg-three.jpeg');
  run('file', 'recv', '/data/local/tmp/lg-three.jpeg', path.join(output, tag + '.jpeg'));
  fs.writeFileSync(path.join(output, tag + '.json'), JSON.stringify(tree));
  log('capture', { tag, text: texts(ns), images: ns.filter(n => n.type === 'Image').length });
  return ns;
}
const resultButton = ns => find(ns, strings.get('result_play_again')) || find(ns, '新游戏');
const outcome = ns => !!resultButton(ns) && !byId(ns, 'game-settings-panel');
function category() {
  let ns = layout();
  if (byId(ns, 'home_category_search')) return ns;
  if (byId(ns, 'game-settings-panel')) { click(byId(ns, 'game-settings-return')); ns = layout(); }
  if (outcome(ns) && find(ns, '退出')) tap('退出', ns);
  else if (byId(ns, 'game-settings-button')) {
    shell('uitest', 'uiInput', 'keyEvent', 'Back'); ns = layout();
    if (find(ns, strings.get('exit_confirm_title'))) tap(strings.get('exit_confirm_leave'), ns);
  }
  ns = layout();
  if (!byId(ns, 'home_category_search')) tap('分类', ns);
  return wait(a => byId(a, 'home_category_search'));
}
function open(id) {
  const game = report.games.find(g => g.id === id);
  let ns = category();
  const all = byId(ns, 'category_filter_all'); if (all.description !== '已选择') { click(all); ns = layout(); }
  const clear = byId(ns, 'home_search_clear'); if (clear) { click(clear); ns = layout(); }
  const xy = center(byId(ns, 'home_category_search'));
  shell('uitest', 'uiInput', 'inputText', ...xy.map(String), game.name);
  const card = n => n.type === 'Column' && n.clickable === 'true' && (n.text || n.description || '').startsWith(game.name + ',');
  ns = wait(a => byId(a, 'home_category_search')?.text === game.name && a.some(card));
  shell('uitest', 'uiInput', 'keyEvent', 'Back');
  ns = shot(id + '-icon');
  const visibleCard = ns.find(card); assert(visibleCard && descendants(visibleCard).some(n => n.type === 'Image'), 'Game icon Image absent');
  click(visibleCard);
  ns = wait(a => byId(a, 'game-settings-button'));
  if (byId(ns, id + '-save-prompt')) { tap(strings.get('save_continue'), ns); ns = wait(a => !byId(a, id + '-save-prompt')); }
  assert(texts(ns).includes(game.name), 'Wrong game page');
  game.openedAt = new Date().toISOString(); save(); return shot(id + '-opened');
}
function settings() {
  click(byId(layout(), 'game-settings-button'));
  return wait(ns => byId(ns, 'game-settings-panel'));
}
function confirm(label, ns) {
  const choices = ns.filter(n => n.type === 'Button' && descendants(n).some(d => d.text === label));
  click(choices.at(-1) || find(ns, label)); return layout();
}
function restart() {
  let ns = layout();
  if (outcome(ns)) click(resultButton(ns));
  else {
    ns = settings(); tap('重新开始', ns); ns = wait(a => !byId(a, 'game-settings-panel') || texts(a).includes(strings.get('game_settings_restart_confirm')));
    if (texts(ns).includes(strings.get('game_settings_restart_confirm'))) confirm('重新开始', ns);
  }
  return wait(a => byId(a, 'game-settings-button') && !outcome(a) && !byId(a, 'game-settings-panel'));
}
function difficulty(label) {
  let ns = settings();
  const selected = ns.filter(n => n.type === 'Button' && n.description === '已选择').flatMap(n => descendants(n).map(d => d.text));
  const original = selected.find(s => ['简单', '普通', '困难'].includes(s));
  if (original && original !== label) {
    tap(label, ns); ns = wait(a => !byId(a, 'game-settings-panel') || texts(a).includes(strings.get('game_settings_difficulty_confirm')));
    if (texts(ns).includes(strings.get('game_settings_difficulty_confirm'))) confirm('切换并重开', ns);
  } else click(byId(ns, 'game-settings-return'));
  wait(a => !byId(a, 'game-settings-panel')); return original;
}
function scroll(up = true) {
  const ns = layout(), scroller = ns.find(n => n.type === 'Scroll' && n.scrollable === 'true'); assert(scroller);
  const b = bounds(scroller), x = (b[0] + b[2]) / 2;
  swipe(x, b[1] + (b[3] - b[1]) * (up ? .8 : .2), x, b[1] + (b[3] - b[1]) * (up ? .2 : .8));
  return layout();
}
const board = (ns = layout()) => ns.filter(n => n.type === 'Button' && bounds(n)[1] > 360 && bounds(n)[2] - bounds(n)[0] > 30 && Math.abs(bounds(n)[2] - bounds(n)[0] - bounds(n)[3] + bounds(n)[1]) < 12).sort((a, b) => Math.abs(bounds(a)[1] - bounds(b)[1]) < 18 ? bounds(a)[0] - bounds(b)[0] : bounds(a)[1] - bounds(b)[1]);
const grid = (ns = layout(), type = 'Stack') => ns.filter(n => n.type === type && n.clickable === 'true' && bounds(n)[1] > 480 && bounds(n)[3] < 2450).sort((a, b) => Math.abs(bounds(a)[1] - bounds(b)[1]) < 18 ? bounds(a)[0] - bounds(b)[0] : bounds(a)[1] - bounds(b)[1]);
const nums = n => descendants(n).filter(d => d.type === 'Text' && /^\d+$/.test(d.text)).map(d => Number(d.text));
const api = { fs, path, cp, assert, root, output, target, report, save, strings, run, shell, sleep, bounds, center, layout, texts, descendants, byId, find, click, tap, batch, swipe, wait, shot, outcome, category, open, settings, restart, difficulty, scroll, board, grid, nums, log };
module.exports = api;
if (require.main === module) {
  const action = process.argv[2] || 'status', requested = process.argv.slice(3);
  if (action === 'status' || action === 'list') {
    save(); console.log(JSON.stringify({ completedGames: report.completedGames, settlements: report.settlements, total: ids.length,
      games: report.games.map(g => ({ id: g.id, name: g.name, settlements: g.rounds.length, visualReview: g.visualReview, error: g.attempts.at(-1)?.error })) }, null, 2));
  } else if (action === 'observe') console.log(JSON.stringify(layout().filter(n => n.text || n.id || n.clickable === 'true').map(n => ({ type: n.type, id: n.id, text: n.text, description: n.description, bounds: n.bounds, enabled: n.enabled }))));
  else if (action === 'capture') shot(requested[0]);
  else if (action === 'run') {
    shell('aa', 'start', '-b', bundle, '-a', 'EntryAbility'); sleep(600);
    let solvers = require('./device-three-solvers.cjs')(api);
    const selected = requested.length ? requested : ids;
    for (const id of selected) {
      const game = report.games.find(g => g.id === id); assert(game, id);
      if (game.rounds.length >= 3) continue;
      assert.equal(hash(), packageSha256);
      const attempt = { startedAt: new Date().toISOString(), status: 'running' }; game.attempts.push(attempt); save();
      try {
        assert(solvers[id], 'No complete-game UI solver yet: ' + id);
        const testDifficulty = ['xiangqi', 'chess'].includes(id) ? '普通' : '简单';
        open(id); const currentDifficulty = difficulty(testDifficulty);
        if (!game.originalDifficulty) game.originalDifficulty = currentDifficulty;
        restart();
        while (game.rounds.length < 3) {
          const round = game.rounds.length + 1, startedAt = new Date().toISOString();
          api.activeId = id; api.activeRound = round;
          shot(id + '-r' + round + '-start');
          // Reload calibrated input strategies between rounds without another UI controller.
          for (const name of ['solvers', 'puzzles', 'expansion', 'classic', 'extra', 'cards', 'board-games']) {
            delete require.cache[require.resolve('./device-three-' + name + '.cjs')];
          }
          solvers = require('./device-three-solvers.cjs')(api);
          const detail = solvers[id](round);
          let ns = wait(outcome, 12000);
          const resultTag = id + '-r' + round + '-result'; ns = shot(resultTag);
          assert(outcome(ns), 'Result disappeared before evidence');
          const resultText = texts(ns);
          restart(); ns = shot(id + '-r' + round + '-restarted');
          assert(!outcome(ns) && byId(ns, 'game-settings-button'), 'Restart failed');
          game.rounds.push({ round, startedAt, finishedAt: new Date().toISOString(), packageSha256, difficulty: testDifficulty, detail, resultText,
            result: resultText.some(t => /挑战完成|恭喜|获胜|成功|完成[！!]|全部找到|猜中了|达成.*2048/.test(t)) ? 'win' : 'loss-or-score',
            evidence: [id + '-r' + round + '-start.jpeg', resultTag + '.jpeg', id + '-r' + round + '-restarted.jpeg'], restartVerified: true });
          save(); console.log('SETTLED ' + id + ' ' + round + '/3 TOTAL ' + report.settlements + '/267');
        }
        if (game.originalDifficulty) difficulty(game.originalDifficulty);
        category(); attempt.status = 'completed';
      } catch (error) {
        attempt.status = 'incomplete'; attempt.error = error.stack; console.error('INCOMPLETE ' + id + ': ' + error.message);
        try { shot(id + '-incomplete-' + Date.now()); category(); } catch (cleanup) { attempt.cleanupError = cleanup.message; save(); throw error; }
      }
      attempt.finishedAt = new Date().toISOString(); save();
    }
  } else throw Error('Use status, list, observe, capture or run');
}
