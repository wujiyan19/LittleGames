/* Publication boundaries for the 79-game single-player collection.
 * Uses real data, route and continuation modules with controlled native services. */
const assert = require('node:assert/strict');
const { fixture, Frames } = require('./test-performance.cjs');
const base = 'entry/src/main/ets/';
const retired = ['tictactoe', 'gomoku', 'reversi', 'fourline', 'nim', 'dots', 'tug',
  'doudizhu', 'guandan', 'mahjong', 'ludo',
  'hiddenobjects', 'farm', 'decorate', 'characters', 'idiom',
  'wordtower', 'backpack', 'differences', 'onestroke', 'golf'];
const collectionRetired = retired.slice(0, 5);
const oldRoute = id => (collectionRetired.includes(id) ? 'Collection_' : 'Expansion_') + id;
const tests = [];
const test = (name, run) => tests.push({ name, run });
const historyIds = data => data.getPlayHistory().map(record => record.game.id);
const restoredFixture = f => {
  const next = fixture(Object.fromEntries(f.values));
  next.data().init({});
  return next;
};

test('published catalog contains 79 unique games and the approved six-category counts', () => {
  const f = fixture(), data = f.data();
  const categories = f.load(base + 'common/GameConstants.ets').GameCategory;
  const games = data.getAllGames();
  assert.equal(games.length, 79);
  assert.equal(new Set(games.map(game => game.id)).size, 79);
  for (const [category, count] of [['CLASSIC', 18], ['PUZZLE', 28], ['BOARD', 5],
    ['NUMBER', 8], ['MEMORY', 5], ['REACTION', 15]]) {
    assert.equal(data.getGamesByCategory(categories[category]).length, count, category);
  }
  for (const id of retired) { assert.equal(data.getGameById(id), undefined, id); }
  for (const id of ['xiangqi', 'chess', 'solitaire', 'spider', 'freecell']) {
    assert.equal(data.getGameById(id).id, id);
  }
});

test('withdrawal does not remove archived catalogs or playable model implementations', () => {
  const f = fixture();
  const collections = f.load(base + 'model/CollectionCatalog.ets').collectionGames();
  const expansions = f.load(base + 'model/ExpansionCatalog.ets').expansionGames();
  const collectionIds = f.rules('Collection').COLLECTION_IDS;
  const expansionIds = f.rules('Expansion').PLAYABLE_EXPANSION_IDS;
  assert.equal(collections.length, 20);
  assert.equal(expansions.length, 67);
  for (const id of retired) {
    assert.ok(collectionIds.includes(id) || expansionIds.includes(id), id);
    assert.ok(collections.concat(expansions).some(game => game.id === id), id);
  }
});

test('direct and reverse routes reject all 21 withdrawn games and invalid identifiers', () => {
  const f = fixture(), routes = f.load(base + 'router/GameRouteRegistry.ets').GameRoutes;
  for (const id of retired) {
    assert.equal(routes.routeName(id), '', id);
    for (const route of [oldRoute(id), 'Collection_' + id, 'Expansion_' + id]) {
      assert.equal(routes.gameIdForRoute(route), '', route);
      assert.equal(routes.isKnownRoute(route), false, route);
      assert.equal(routes.isExpansionRoute(route), false, route);
      assert.equal(routes.isCollectionRoute(route), false, route);
    }
  }
  for (const id of ['', 'invalid', 'Xiangqi', 'xiangqi ']) { assert.equal(routes.routeName(id), ''); }
  for (const route of ['', 'MissingPage', 'Expansion_invalid']) {
    assert.equal(routes.gameIdForRoute(route), '');
    assert.equal(routes.isKnownRoute(route), false);
  }
});

test('generated routes contain exactly the 79 published games with reversible navigation', () => {
  const f = fixture(), routes = f.load(base + 'router/GameRouteRegistry.ets').GameRoutes;
  const generated = routes.getAllGameRoutes();
  assert.equal(generated.length, 79);
  assert.equal(new Set(generated).size, 79);
  assert.deepEqual(generated.map(route => routes.gameIdForRoute(route)).sort(),
    f.data().getAllGames().map(game => game.id).sort());
  for (const game of f.data().getAllGames()) {
    const route = routes.routeName(game.id);
    assert.ok(generated.includes(route), game.id);
    assert.equal(routes.gameIdForRoute(route), game.id);
    assert.equal(routes.isKnownRoute(route), true);
  }
  for (const route of ['SettingsPage', 'AboutPage', 'PlayHistoryPage']) {
    assert.equal(routes.isKnownRoute(route), true);
    assert.equal(generated.includes(route), false);
  }
});

function historicalValues() {
  const scores = {}, times = {}, dates = {};
  for (let index = 0; index < retired.length; index++) {
    scores[retired[index]] = 10000 + index;
    times[retired[index]] = 100000 + index;
    dates[retired[index]] = 200000 + index;
  }
  Object.assign(scores, { snake: 12, xiangqi: 20, chess: 25 });
  Object.assign(times, { snake: 1500, xiangqi: 2000, chess: 3000 });
  Object.assign(dates, { snake: 1000, xiangqi: 2000, chess: 3000 });
  return { highScores: JSON.stringify(scores), playTimesMs: JSON.stringify(times),
    lastPlayedAt: JSON.stringify(dates),
    playedGames: JSON.stringify(retired.concat(['snake', 'xiangqi', 'chess', 'invalid'])),
    recentGames: JSON.stringify(retired.concat(['snake', 'xiangqi', 'chess'])) };
}

test('old persisted games are absent from history, statistics, recent previews and recommendations', () => {
  const f = fixture(historicalValues()), data = f.data(); data.init({});
  assert.equal(data.getPlayedGameCount(), 3);
  assert.equal(data.getTotalPlayTimeMs(), 6500);
  assert.deepEqual(historyIds(data), ['chess', 'xiangqi', 'snake']);
  assert.deepEqual(data.getRecentlyPlayed(3).map(game => game.id), ['snake', 'xiangqi', 'chess']);
  assert.deepEqual(data.getMostPlayed(3).map(game => game.id), ['chess', 'xiangqi', 'snake']);
  assert.deepEqual(data.getTopGames(3).map(game => game.id), ['chess', 'xiangqi', 'snake']);
  assert.equal(data.getGameById('chess').highScore, 25);
  assert.equal(data.getGameById('xiangqi').playTimeMs, 2000);
});

test('ordinary writes and restart preserve hidden scores, time, dates and original historical IDs', () => {
  const initial = historicalValues(), f = fixture(initial), data = f.data(); data.init({});
  data.updateHighScore('snake', 99); data.addPlayTime('snake', 500); data.recordGamePlayed('snake');
  data.setTextSetting('themeMode', 'dark');
  for (const key of ['highScores', 'playTimesMs', 'lastPlayedAt']) {
    const before = JSON.parse(initial[key]), after = JSON.parse(f.values.get(key));
    for (const id of retired) { assert.equal(after[id], before[id], key + '/' + id); }
  }
  for (const key of ['playedGames', 'recentGames']) {
    const ids = JSON.parse(f.values.get(key));
    for (const id of retired) { assert.ok(ids.includes(id), key + '/' + id); }
    assert.equal(ids.includes('invalid'), false);
  }
  const next = restoredFixture(f), restored = next.data();
  assert.deepEqual(historyIds(restored), ['snake', 'chess', 'xiangqi']);
  assert.equal(restored.getPlayedGameCount(), 3);
  assert.equal(restored.getTotalPlayTimeMs(), 7000);
  assert.equal(restored.getGameById('snake').highScore, 99);
  assert.equal(restored.getThemeMode(), 'dark');
  restored.setSetting('soundEnabled', false);
  for (const id of retired) {
    assert.equal(JSON.parse(next.values.get('highScores'))[id], JSON.parse(initial.highScores)[id]);
  }
});

test('legacy play-count migration hides withdrawn games while retaining their saved history', () => {
  const f = fixture({ playCounts: '{"tictactoe":5,"mahjong":8,"chess":3,"snake":2}',
    recentGames: '["tictactoe","snake"]' }), data = f.data(); data.init({});
  assert.equal(data.getPlayedGameCount(), 2);
  assert.deepEqual(historyIds(data), ['snake', 'chess']);
  assert.equal(data.getTotalPlayTimeMs(), 0);
  data.resetSettings();
  assert.ok(JSON.parse(f.values.get('playedGames')).includes('tictactoe'));
  assert.ok(JSON.parse(f.values.get('playedGames')).includes('mahjong'));
  const restored = restoredFixture(f).data();
  assert.equal(restored.getPlayedGameCount(), 2);
  assert.deepEqual(historyIds(restored), ['snake', 'chess']);
});

test('direct statistic updates for withdrawn games do not create records or overwrite archived data', () => {
  const initial = historicalValues(), f = fixture(initial), data = f.data(); data.init({});
  for (const id of retired) {
    data.recordGamePlayed(id); data.addPlayTime(id, 1000); data.updateHighScore(id, 999999);
  }
  assert.equal(f.store.writes, 0);
  assert.equal(f.clock.count(), 0);
  assert.equal(data.getPlayedGameCount(), 3);
  data.setSetting('soundEnabled', false);
  for (const key of ['highScores', 'playTimesMs', 'lastPlayedAt']) {
    const before = JSON.parse(initial[key]), after = JSON.parse(f.values.get(key));
    for (const id of retired) { assert.equal(after[id], before[id], key + '/' + id); }
  }
});

test('explicit clear-play-data also clears archived games and keeps preferences after restart', () => {
  const f = fixture(historicalValues()), data = f.data(); data.init({});
  data.setTextSetting('themeMode', 'dark'); data.clearPlayData();
  for (const id of retired) {
    assert.equal(JSON.parse(f.values.get('highScores'))[id], 0);
    assert.equal(JSON.parse(f.values.get('playTimesMs'))[id], 0);
  }
  assert.deepEqual(JSON.parse(f.values.get('lastPlayedAt')), {});
  assert.deepEqual(JSON.parse(f.values.get('playedGames')), []);
  assert.deepEqual(JSON.parse(f.values.get('recentGames')), []);
  const restored = restoredFixture(f).data();
  assert.equal(restored.getPlayedGameCount(), 0);
  assert.equal(restored.getTotalPlayTimeMs(), 0);
  assert.deepEqual(historyIds(restored), []);
  assert.equal(restored.getThemeMode(), 'dark');
});

test('old continuation payloads cannot restore withdrawn games through any navigation nesting', () => {
  const f = fixture(), app = f.load(base + 'common/AppContinuation.ets').AppContinuation;
  const restored = [];
  app.connect(() => ({ tab: 0, paths: [] }), state => restored.push(state));
  for (const id of retired) {
    for (const paths of [[oldRoute(id)], ['PlayHistoryPage', oldRoute(id)],
      [oldRoute(id), 'SettingsPage', 'AboutPage']]) {
      assert.equal(app.receive(JSON.stringify({ version: 1, tab: 0, paths, gameId: id,
        gamePayload: '{"version":1}' })), false, id);
      assert.equal(app.hasPending(), false);
    }
    assert.equal(app.receive(JSON.stringify({ version: 1, tab: 0, paths: [], gameId: id,
      gamePayload: '{"version":1}' })), false);
  }
  assert.deepEqual(restored, []);
  app.disconnect();
});

test('capturing an obsolete route fails without exporting a retired live game session', () => {
  const f = fixture(), app = f.load(base + 'common/AppContinuation.ets').AppContinuation;
  const bus = f.load(base + 'common/GameLifecycleBus.ets').GameLifecycleBus;
  const exported = [];
  bus.exportSession = id => { exported.push(id); return '{"version":1}'; };
  for (const id of retired) {
    app.connect(() => ({ tab: 1, paths: ['PlayHistoryPage', oldRoute(id), 'SettingsPage'] }), () => {});
    assert.throws(() => app.capture(), /Unsupported continuation state/);
    assert.equal(app.hasPending(), false);
  }
  assert.deepEqual(exported, []);
  app.disconnect();
});

for (const id of ['xiangqi', 'chess']) {
  for (const difficulty of ['easy', 'normal', 'hard']) {
    test(`${id}/${difficulty}: retained computer responds and the live game can be continued`, () => {
      const f = fixture(), frames = new Frames(), vm = f.vm('ExpansionViewModel');
      vm.init(id, frames); vm.difficulty = difficulty; vm.startGame();
      assert.equal(vm.hasComputerOpponent(), true);
      if (id === 'chess') { vm.tap(52); vm.tap(36); }
      else { vm.tap(54); vm.tap(45); }
      assert.equal(vm.computerThinking, true);
      const waiting = JSON.stringify(vm.state);
      f.clock.advance(499); assert.equal(JSON.stringify(vm.state), waiting);
      f.clock.advance(1); assert.notEqual(JSON.stringify(vm.state), waiting);
      assert.equal(vm.computerThinking, false);
      assert.equal(vm.model.valid(vm.state), true);
      const routes = f.load(base + 'router/GameRouteRegistry.ets').GameRoutes;
      const app = f.load(base + 'common/AppContinuation.ets').AppContinuation;
      const bus = f.load(base + 'common/GameLifecycleBus.ets').GameLifecycleBus;
      bus.attach(vm);
      const restored = [];
      app.connect(() => ({ tab: 0, paths: [routes.routeName(id), 'SettingsPage'] }), state => restored.push(state));
      const captured = app.capture();
      assert.equal(JSON.parse(captured).gameId, id);
      assert.equal(app.receive(captured), true);
      assert.equal(restored.length, 1);
      assert.equal(restored[0].gameId, id);
      bus.detach(vm); app.disconnect(); vm.dispose();
    });
  }
}

(async () => {
  let failed = 0;
  for (const entry of tests) {
    try { await entry.run(); } catch (error) { failed++; console.error(`FAIL ${entry.name}\n${error.stack}`); }
  }
  console.log(`${tests.length - failed}/${tests.length} single-player catalog regressions passed.`);
  process.exitCode = failed ? 1 : 0;
})();
