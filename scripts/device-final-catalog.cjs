// Real-device entrance/return coverage only. No model imports or state injection.
// Run from the repository root. Start on the Categories tab with the phone unlocked.
process.env.LITTLEGAMES_ART_OUTPUT ||= 'docs/device-acceptance/single-player-iteration-2026-10-12';
const c = require('./device-art-review.cjs');
const crypto = require('node:crypto');

const strings = new Map(JSON.parse(c.fs.readFileSync('entry/src/main/resources/zh_CN/element/string.json', 'utf8')).string
  .map(s => [s.name, s.value]));
for (const [key, value] of strings) {
  if (/^game_.+_name$/.test(key)) c.names[key.slice(5, -5)] = value;
}
const availability = c.fs.readFileSync('entry/src/main/ets/common/GameAvailability.ets', 'utf8');
const retiredSource = availability.match(/const RETIRED_GAME_IDS:\s*string\[\]\s*=\s*\[([^\]]+)\]/);
c.assert(retiredSource, 'Publication policy not found');
const retiredIds = [...retiredSource[1].matchAll(/'([a-z0-9]+)'/g)].map(match => match[1]);
const gameIds = ['GameData', 'CollectionCatalog', 'ExpansionCatalog'].flatMap(file => {
  const source = c.fs.readFileSync('entry/src/main/ets/model/' + file + '.ets', 'utf8');
  return [...source.matchAll(/\bid:\s*'([a-z0-9]+)'\s*,\s*name:\s*\$r\('app\.string\.game_[a-z0-9]+_name'\)/g)]
    .map(match => match[1]);
}).filter(id => !retiredIds.includes(id));
c.assert.equal(gameIds.length, 79, 'Expected the current 79-game catalog');
c.assert.equal(new Set(gameIds).size, 79, 'Duplicate catalog ID');
for (const id of gameIds) c.assert(c.names[id], 'Chinese name missing for ' + id);

const argv = process.argv.slice(2);
if (argv.includes('--help')) {
  console.log('node scripts/device-final-catalog.cjs [--limit 10] [--list]\n' +
    'LITTLEGAMES_ART_TARGET selects the device; LITTLEGAMES_ART_OUTPUT selects the evidence directory.\n' +
    'Each run checks the next unpassed games and checkpoints catalog.json. Start on 分类 / 全部.\n' +
    '--list prints the 79 catalog IDs without operating the device. Unknown dialogs stop the run.');
  process.exit(0);
}
if (argv.includes('--list')) {
  c.assert.equal(argv.length, 1, 'Use --list alone');
  console.log(JSON.stringify(gameIds.map(id => ({ id, name: c.names[id] })), null, 2));
  process.exit(0);
}
c.assert(argv.length === 0 || (argv.length === 2 && argv[0] === '--limit'), 'Expected --limit <count>');
const limit = argv.length === 0 ? 10 : Number(argv[1]);
c.assert(Number.isInteger(limit) && limit >= 1 && limit <= 100, 'Limit must be an integer from 1 to 100');
const reportFile = c.path.join(c.dir, 'catalog.json');
const report = c.fs.existsSync(reportFile) ? JSON.parse(c.fs.readFileSync(reportFile, 'utf8')) : {
  schemaVersion: 1,
  packageSha256: c.packageHash,
  target: c.target,
  scope: 'Real UI search, matching game title/header, screenshot, and return; not complete gameplay acceptance.',
  gameIds,
  total: gameIds.length,
  passed: [],
  failures: []
};
c.assert.equal(report.packageSha256, c.packageHash, 'Evidence directory belongs to a different HAP; choose a new directory');
c.assert.equal(report.target, c.target, 'Evidence directory belongs to another device');
c.assert.deepEqual(report.gameIds, gameIds, 'Evidence catalog differs from the current source catalog');
const byId = (ns, id) => ns.find(n => n.id === id);
const catalogVisible = ns => !!byId(ns, 'home_category_search');
const save = () => {
  report.passedCount = report.passed.length;
  report.complete = report.passedCount === report.total;
  report.updatedAt = new Date().toISOString();
  c.fs.writeFileSync(reportFile, JSON.stringify(report, null, 2) + '\n');
};
const verifyPackage = () => c.assert.equal(crypto.createHash('sha256')
  .update(c.fs.readFileSync('entry/build/default/outputs/default/entry-default-signed.hap')).digest('hex'),
  c.packageHash, 'HAP changed during device acceptance');
const unexpectedModal = ns => ns.some(n => /^(AlertDialog|Dialog|ModalDialog)$/.test(n.type)) ||
  !!c.find(ns, '确认退出？') || c.text(ns).some(t => /待续|待恢复|是否.*(继续|恢复)|继续上次|恢复上次/.test(t));

function requireCatalog() {
  const ns = c.layout();
  c.assert(catalogVisible(ns), 'Start or resume this batch on the 分类 tab; observed: ' + c.text(ns).join(' | '));
  const all = byId(ns, 'category_filter_all');
  c.assert(all && c.bounds(all)[2] > c.bounds(all)[0], '全部 filter is not visible; select 全部 before running');
  if (all.description !== '已选择') {
    c.click(all);
    c.wait(a => byId(a, 'category_filter_all')?.description === '已选择');
  }
  return c.layout();
}

function searchAndOpen(id) {
  const name = c.names[id];
  let ns = requireCatalog();
  const clear = byId(ns, 'home_search_clear');
  if (clear) {
    c.click(clear);
    ns = c.wait(a => !byId(a, 'home_search_clear') && byId(a, 'home_category_search') && !byId(a, 'home_category_search').text);
  }
  const input = byId(ns, 'home_category_search');
  const b = c.bounds(input);
  c.shell('uitest', 'uiInput', 'inputText', '' + Math.round((b[0] + b[2]) / 2),
    '' + Math.round((b[1] + b[3]) / 2), name);
  const card = n => n.type === 'Column' && n.clickable === 'true' &&
    [n.text, n.description].some(t => t?.startsWith(name + ',') || t?.startsWith(name + '，'));
  ns = c.wait(a => byId(a, 'home_category_search')?.text === name && a.some(card));
  // The search keyboard is visible after inputText; dismiss it before capturing the icon or opening.
  c.shell('uitest', 'uiInput', 'keyEvent', 'Back');
  ns = c.wait(a => catalogVisible(a) && a.some(card));
  c.capture('catalog-' + id + '-icon');
  c.click(ns.find(card));
  ns = c.wait(a => byId(a, 'game-settings-button') || unexpectedModal(a), 15000);
  if (ns.some(n => n.id === id + '-save-prompt')) {
    c.capture('catalog-' + id + '-resume-prompt');
    c.tap(strings.get('save_continue'), ns);
    ns = c.wait(a => !a.some(n => n.id === id + '-save-prompt') && byId(a, 'game-settings-button'));
  }
  c.assert(!unexpectedModal(ns), 'Unexpected or pending/resume dialog: ' + c.text(ns).join(' | '));
  c.assert(!catalogVisible(ns) && ns.some(n => n.type === 'Text' && n.text === name),
    'Search opened the wrong game: ' + c.text(ns).join(' | '));
  c.assert(byId(ns, 'game-settings-button'), 'Expected native game header missing');
  c.sleep(250);
  return c.capture('catalog-' + id + '-page');
}

function run() {
  const remaining = gameIds.filter(id => !report.passed.some(item => item.id === id));
  let activeId = null;
  try {
    requireCatalog();
    for (const id of remaining.slice(0, limit)) {
      activeId = id;
      verifyPackage();
      const startedAt = new Date().toISOString();
      const ns = searchAndOpen(id);
      c.back();
      c.assert(catalogVisible(c.layout()), 'Back did not return to the real category search UI');
      report.passed.push({
        id, name: c.names[id], startedAt, finishedAt: new Date().toISOString(),
        observedTitle: c.names[id], headerId: 'game-settings-button',
        pageText: c.text(ns), screenshots: ['catalog-' + id + '-icon.jpeg', 'catalog-' + id + '-page.jpeg'],
        returnedTo: 'home_category_search'
      });
      save();
      c.log('catalog-entrance-return-passed', { id, name: c.names[id] });
      console.log('CATALOG ' + report.passed.length + '/' + gameIds.length + ' ' + id + ' / ' + c.names[id]);
    }
    verifyPackage();
    save();
    console.log(JSON.stringify({ passed: report.passedCount, total: gameIds.length, complete: report.complete,
      next: gameIds.find(id => !report.passed.some(item => item.id === id)) || null }));
  } catch (error) {
    const failure = { id: activeId, at: new Date().toISOString(), error: error.message };
    try {
      const tag = 'catalog-' + (activeId || 'setup') + '-incomplete';
      const ns = c.capture(tag);
      failure.observedText = c.text(ns);
      failure.screenshot = tag + '.jpeg';
    } catch (captureError) {
      failure.captureError = captureError.message;
    }
    report.failures.push(failure);
    save();
    c.log('catalog-check-incomplete', failure);
    throw error;
  }
}

if (require.main === module) {
  try { run(); }
  catch (error) { console.error(error.stack); process.exitCode = 1; }
}
