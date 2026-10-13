const assert = require('node:assert/strict');
const { fixture } = require('./test-performance.cjs');
const tests = [];
const test = (name, run) => tests.push({ name, run });
const historyIds = data => data.getPlayHistory().map(record => record.game.id);
const restart = f => {
  const next = fixture(Object.fromEntries(f.values));
  const data = next.data();
  data.init({});
  return { f: next, data };
};

test('all distinct games remain in history beyond the five-game preview', () => {
  const f = fixture(), data = f.data(); data.init({});
  const ids = ['snake', 'tetris', '2048', 'whackmole', 'minesweeper', 'sudoku', 'slidepuzzle', 'klotski'];
  for (const id of ids) { data.recordGamePlayed(id); f.clock.advance(100); }
  assert.deepEqual(historyIds(data), ids.slice().reverse());
  assert.equal(data.getPlayedGameCount(), 8);
  assert.deepEqual(data.getRecentlyPlayed().map(game => game.id), ids.slice().reverse().slice(0, 5));
  assert.equal(data.getPlayHistory()[0].lastPlayedAt, 100700);
  data.flushNow();
  const restored = restart(f).data;
  assert.deepEqual(historyIds(restored), ids.slice().reverse());
  assert.equal(restored.getPlayHistory()[0].lastPlayedAt, 100700);
});

test('replay updates the same record and same-millisecond entries follow recent order', () => {
  const f = fixture(), data = f.data(); data.init({});
  data.recordGamePlayed('snake'); data.recordGamePlayed('2048'); data.recordGamePlayed('tetris');
  assert.deepEqual(historyIds(data), ['tetris', '2048', 'snake']);
  data.recordGamePlayed('snake');
  assert.deepEqual(historyIds(data), ['snake', 'tetris', '2048']);
  assert.equal(data.getPlayedGameCount(), 3);
  f.clock.advance(1000); data.recordGamePlayed('2048');
  assert.deepEqual(historyIds(data), ['2048', 'snake', 'tetris']);
  assert.equal(data.getPlayHistory()[0].lastPlayedAt, 101000);
  f.clock.advance(1000); data.addPlayTime('snake', 900);
  assert.equal(data.getPlayHistory().find(record => record.game.id === 'snake').lastPlayedAt, 100000);
  assert.deepEqual(historyIds(data), ['2048', 'snake', 'tetris']);
});

test('restored history sorts actual timestamps first and uses recent order for ties', () => {
  const f = fixture({ playedGames: '["snake","2048","tetris","sudoku"]',
    recentGames: '["snake","tetris","2048","sudoku"]',
    lastPlayedAt: '{"snake":1000,"2048":3000,"tetris":3000,"minesweeper":2000}' });
  const data = f.data(); data.init({});
  assert.deepEqual(historyIds(data), ['tetris', '2048', 'minesweeper', 'snake', 'sudoku']);
  assert.deepEqual(data.getPlayHistory().map(record => record.lastPlayedAt), [3000, 3000, 2000, 1000, 0]);
  assert.equal(data.getPlayedGameCount(), 5);
});

test('legacy played IDs, recent order and durations merge without invented timestamps', () => {
  const f = fixture({ playedGames: '["snake","tetris","2048","whackmole","minesweeper","sudoku"]',
    recentGames: '["2048","snake","2048","tetris"]', playTimesMs: '{"slidepuzzle":5000}' });
  const data = f.data(); data.init({});
  const expected = ['2048', 'snake', 'tetris', 'whackmole', 'minesweeper', 'sudoku', 'slidepuzzle'];
  assert.deepEqual(historyIds(data), expected);
  assert.ok(data.getPlayHistory().every(record => record.lastPlayedAt === 0));
  data.setTextSetting('themeMode', 'dark');
  const restored = restart(f).data;
  assert.deepEqual(historyIds(restored), expected);
  assert.ok(restored.getPlayHistory().every(record => record.lastPlayedAt === 0));
  restored.recordGamePlayed('whackmole');
  assert.deepEqual(historyIds(restored), ['whackmole', ...expected.filter(id => id !== 'whackmole')]);
  assert.equal(restored.getPlayHistory()[0].lastPlayedAt, 100000);
  assert.ok(restored.getPlayHistory().slice(1).every(record => record.lastPlayedAt === 0));
});

test('legacy count migration includes played games beyond the old recent list', () => {
  const f = fixture({ playCounts: '{"snake":2,"tetris":7,"2048":1,"whackmole":3,"minesweeper":4,"sudoku":5}',
    recentGames: '["2048","snake"]', playTimesMs: '{"slidepuzzle":5000}' });
  const data = f.data(); data.init({});
  assert.deepEqual(historyIds(data), ['2048', 'snake', 'tetris', 'whackmole', 'minesweeper', 'sudoku', 'slidepuzzle']);
  assert.equal(data.getPlayHistory().length, 7);
  assert.ok(data.getPlayHistory().every(record => record.lastPlayedAt === 0));
});

test('timestamps persist through debounced writes and replay after restart', () => {
  const f = fixture(), data = f.data(); data.init({});
  data.recordGamePlayed('snake'); f.clock.advance(500); data.recordGamePlayed('2048');
  f.clock.advance(200);
  assert.deepEqual(JSON.parse(f.values.get('lastPlayedAt')), { snake: 100000, 2048: 100500 });
  const restored = restart(f); restored.f.clock.advance(2000); restored.data.recordGamePlayed('snake');
  restored.data.flushNow();
  const finalData = restart(restored.f).data;
  assert.deepEqual(historyIds(finalData), ['snake', '2048']);
  assert.deepEqual(finalData.getPlayHistory().map(record => record.lastPlayedAt), [102000, 100500]);
});

test('malformed or invalid timestamps do not fabricate history or dates', () => {
  const f = fixture({ playedGames: '["snake","2048","tetris","sudoku"]',
    recentGames: '["snake","2048"]',
    lastPlayedAt: '{"snake":-1,"2048":"1000","tetris":1e300,"sudoku":0,"minesweeper":4000.9,"invalid":9000}' });
  const data = f.data(); data.init({});
  assert.deepEqual(historyIds(data), ['minesweeper', 'snake', '2048', 'tetris', 'sudoku']);
  assert.deepEqual(data.getPlayHistory().map(record => record.lastPlayedAt), [4000, 0, 0, 0, 0]);
  for (const json of ['{bad', 'null', '[]']) {
    const broken = fixture({ playedGames: '["snake"]', lastPlayedAt: json }).data(); broken.init({});
    assert.deepEqual(historyIds(broken), ['snake']);
    assert.equal(broken.getPlayHistory()[0].lastPlayedAt, 0);
  }
});

test('timestamp restoration respects the maximum date supported by Date', () => {
  const f = fixture({ playedGames: '["snake","tetris","sudoku"]', recentGames: '["tetris","sudoku"]',
    lastPlayedAt: '{"snake":8640000000000000,"tetris":8640000000000001,"sudoku":9007199254740991}' });
  const data = f.data(); data.init({});
  assert.deepEqual(historyIds(data), ['snake', 'tetris', 'sudoku']);
  assert.deepEqual(data.getPlayHistory().map(record => record.lastPlayedAt), [8640000000000000, 0, 0]);
  assert.equal(new Date(data.getPlayHistory()[0].lastPlayedAt).getTime(), 8640000000000000);
});

test('clearPlayData removes timestamps and migrated records persistently while retaining settings', () => {
  const f = fixture({ playCounts: '{"snake":5,"tetris":3}', recentGames: '["snake"]',
    lastPlayedAt: '{"snake":90000}', settings: '{"themeMode":"dark","soundEnabled":false}' });
  const data = f.data(); data.init({});
  data.recordGamePlayed('2048'); data.addPlayTime('snake', 999); data.updateHighScore('snake', 123);
  data.clearPlayData();
  assert.deepEqual(historyIds(data), []);
  assert.deepEqual(JSON.parse(f.values.get('lastPlayedAt')), {});
  const restored = restart(f).data;
  assert.deepEqual(historyIds(restored), []); assert.equal(restored.getPlayedGameCount(), 0);
  assert.equal(restored.getRecentlyPlayed().length, 0); assert.equal(restored.getTotalPlayTimeMs(), 0);
  assert.equal(restored.getGameById('snake').highScore, 0); assert.equal(restored.getThemeMode(), 'dark');
  assert.equal(restored.getSetting('soundEnabled', true), false);
});

test('invalid game IDs are ignored and timestamp sorting remains strict after a clock change', () => {
  const f = fixture(), data = f.data(); data.init({});
  data.recordGamePlayed('invalid'); assert.deepEqual(historyIds(data), []);
  data.recordGamePlayed('snake'); f.clock.advance(1000); data.recordGamePlayed('2048');
  f.clock.shiftWallTime(-5000); data.recordGamePlayed('tetris');
  assert.deepEqual(historyIds(data), ['2048', 'snake', 'tetris']);
  assert.deepEqual(data.getPlayHistory().map(record => record.lastPlayedAt), [101000, 100000, 96000]);
});

(async () => {
  let failed = 0;
  for (const entry of tests) {
    try { await entry.run(); } catch (error) { failed++; console.error(`FAIL ${entry.name}\n${error.stack}`); }
  }
  console.log(`${tests.length - failed}/${tests.length} play-history regressions passed.`);
  process.exitCode = failed ? 1 : 0;
})();
