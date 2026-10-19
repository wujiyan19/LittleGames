const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { fixture } = require('./test-performance.cjs');
const { pruneSvgDefs } = require('./svg-resource-utils.cjs');
const root = path.resolve(__dirname, '..');
const tests = [];
const test = (name, run) => tests.push({ name, run });
const base = 'entry/src/main/ets/';

test('duration displays zero, sub-minute, minute and hour boundaries in both languages', () => {
  for (const [lang, expected] of [
    ['base', ['0分钟','不足1分钟','不足1分钟','1分钟','59分钟','1.0 小时','1.2 小时']],
    ['en_US', ['0 min','Under 1 min','Under 1 min','1 min','59 min','1.0 h','1.2 h']]
  ]) {
    const values = JSON.parse(fs.readFileSync(path.join(root, 'entry/src/main/resources', lang, 'element/string.json'))).string;
    const context = { resourceManager: { getStringSync(id) { return values.find(value => 'app.string.' + value.name === id).value; } } };
    const f = fixture({}, name => ({ id: name, params: [] }));
    const { formatPlayTime } = f.load(base + 'common/PlayTime.ets');
    [0,1,59999,60000,3599999,3600000,4320000].forEach((ms, index) => assert.equal(formatPlayTime(ms, context), expected[index]));
    assert.equal(formatPlayTime(-1, context), expected[0]);
    assert.equal(formatPlayTime(NaN, context), expected[0]);
  }
});

test('actual starts rank by count, never by score or page attachment', () => {
  const f = fixture(), data = f.data(); data.init({});
  data.updateHighScore('2048', 99999);
  data.recordGameStarted('snake'); data.recordGameStarted('snake'); data.recordGameStarted('2048');
  for (let i = 0; i < 4; i++) data.recordGamePlayed('2048');
  assert.equal(data.getPlayCount('2048'), 1); assert.equal(data.getPlayCount('snake'), 2);
  assert.equal(data.getTotalStarts(), 3);
  assert.deepEqual(data.getFrequentlyPlayed().map(game => game.id), ['snake', '2048']);
  data.recordGameStarted('not-a-game'); data.recordGameStarted('tictactoe'); assert.equal(data.getTotalStarts(), 3);
  data.flushNow();
  const restoredFixture = fixture(Object.fromEntries(f.values));
  const restored = restoredFixture.data(); restored.init({});
  assert.equal(restored.getTotalStarts(), 3); assert.equal(restored.getPlayCount('snake'), 2);
  restored.clearPlayData(); restored.flushNow();
  const cleared = fixture(Object.fromEntries(restoredFixture.values)).data(); cleared.init({});
  assert.equal(cleared.getTotalStarts(), 0); assert.equal(cleared.getFrequentlyPlayed().length, 0);
});

test('old play-time records never fabricate starts, retired records remain persisted', () => {
  const f = fixture({ playedGames: '["snake"]', playTimesMs: '{"snake":99999}', playCounts: '{"snake":50}',
    gameStartCounts: '{"tictactoe":9,"2048":2,"snake":-1,"sudoku":1e309}' });
  const data = f.data(); data.init({});
  assert.equal(data.getPlayCount('snake'), 0); assert.equal(data.getPlayCount('sudoku'), 0);
  assert.equal(data.getTotalStarts(), 2); assert.equal(data.getPlayedGameCount(), 1);
  data.recordGameStarted('snake'); data.flushNow();
  assert.equal(JSON.parse(f.values.get('gameStartCounts')).tictactoe, 9);
});

test('view-model start plus page attachment counts once, save restoration adds no start', () => {
  const f = fixture(), data = f.data(); data.init({});
  const vm = f.vm('Game2048ViewModel'); vm.newGame();
  const bus = f.load(base + 'common/GameLifecycleBus.ets').GameLifecycleBus;
  bus.attach(vm); assert.equal(data.getPlayCount('2048'), 1);
  vm.saveCurrentGame(); const next = f.vm('Game2048ViewModel'); assert(next.offerSavedGame()); next.continueSavedGame();
  bus.detach(vm); bus.attach(next); assert.equal(data.getPlayCount('2048'), 1); bus.detach(next);
});

test('all available games have localized brief copy and the same color identities', () => {
  const f = fixture(), data = f.data(); data.init({});
  const { gameBrief } = f.load(base + 'common/GameCardCopy.ets');
  const { GameColorCue } = f.load(base + 'common/GameColorCue.ets');
  for (const lang of ['base','zh_CN','en_US']) {
    const values = JSON.parse(fs.readFileSync(path.join(root,'entry/src/main/resources',lang,'element/string.json'))).string;
    assert.equal(new Set(values.map(value => value.name)).size, values.length);
    for (const game of data.getAllGames()) {
      assert.equal(gameBrief(game), 'app.string.game_' + game.id + '_brief');
      const brief = values.find(value => value.name === 'game_' + game.id + '_brief');
      assert(brief && brief.value.length > 0); assert(brief.value.length <= (lang === 'en_US' ? 28 : 8));
    }
  }
  assert.equal(new Set([1,2,3,4,5,6].map(value => GameColorCue.symbol(value))).size, 6);
  assert.equal(GameColorCue.symbol(0), '');
});

test('status text colors meet 4.5 against their light and dark surfaces', () => {
  const luminance = hex => hex.slice(1).match(/../g).map(v => parseInt(v,16)/255)
    .map(v => v <= .04045 ? v / 12.92 : ((v + .055) / 1.055) ** 2.4)
    .reduce((sum,v,i) => sum + v * [.2126,.7152,.0722][i], 0);
  for (const theme of ['base','dark']) {
    const colors = JSON.parse(fs.readFileSync(path.join(root,'entry/src/main/resources',theme,'element/color.json'))).color;
    for (const name of ['success_text','warning_text','error_text']) for (const surface of ['surface','surface_hover','bg']) {
      const a = luminance(colors.find(c => c.name === name).value), b = luminance(colors.find(c => c.name === surface).value);
      assert((Math.max(a,b)+.05)/(Math.min(a,b)+.05) >= 4.5, theme + ':' + name + '/' + surface);
    }
  }
});

test('SVG pruning retains transitive references and leaves all visible geometry unchanged', () => {
  const source = '<svg><defs><linearGradient id="unused"><stop/></linearGradient><linearGradient id="parent"><stop/></linearGradient><linearGradient id="used" href="#parent"><stop/></linearGradient></defs><path fill="url(#used)" d="M1 2L3 4"/></svg>';
  const next = pruneSvgDefs(source); assert(!next.includes('id="unused"')); assert(next.includes('id="parent"'));
  assert.equal(pruneSvgDefs(next), next);
  assert.equal(source.replace(/<defs>[\s\S]*?<\/defs>/g,''), next.replace(/<defs>[\s\S]*?<\/defs>/g,''));
  for (const theme of ['base','dark']) {
    const dir = path.join(root,'entry/src/main/resources',theme,'media');
    for (const file of fs.readdirSync(dir).filter(file => file.endsWith('.svg'))) {
      const svg = fs.readFileSync(path.join(dir,file),'utf8'); const ids = new Set([...svg.matchAll(/\bid="([^"]+)"/g)].map(m => m[1]));
      for (const match of svg.matchAll(/url\(#([^)]*)\)/g)) assert(ids.has(match[1]), file + ':' + match[1]);
      assert.equal(pruneSvgDefs(svg), svg, file + ' still contains unused gradients');
    }
  }
});
let failed = 0;
for (const entry of tests) {
  try { entry.run(); } catch (error) { failed++; console.error('FAIL ' + entry.name + '\n' + error.stack); }
}
console.log((tests.length - failed) + '/' + tests.length + ' UI iteration checks passed.');
process.exitCode = failed ? 1 : 0;
