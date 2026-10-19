/* Preferences payloads cross a runtime boundary; verify usable records survive invalid scores. */
const assert = require('node:assert/strict');
const { fixture } = require('./test-performance.cjs');
const tests = [];
const test = (name, run) => tests.push({ name, run });

test('invalid persisted scores cannot poison ranking or block later achievements', () => {
  const f = fixture({ highScores: '{"snake":1e309,"tetris":-20,"2048":64,"sudoku":"999"}' });
  const data = f.data(); data.init({});
  for (const id of ['snake', 'tetris', 'sudoku']) { assert.equal(data.getGameById(id).highScore, 0); }
  assert.equal(data.getGameById('2048').highScore, 64);
  data.updateHighScore('snake', 120); data.flushNow();
  const next = fixture(Object.fromEntries(f.values)); next.data().init({});
  assert.equal(next.data().getGameById('snake').highScore, 120);
  assert.equal(next.data().getTopGames(1)[0].id, 'snake');
  assert.equal(next.data().getGameById('2048').highScore, 64);
});

test('out-of-range runtime scores leave the record and pending writes untouched', () => {
  const f = fixture({ highScores: '{"snake":50}' }); const data = f.data(); data.init({});
  for (const value of [NaN, Infinity, -Infinity, -1, Number.MAX_SAFE_INTEGER + 1]) {
    data.updateHighScore('snake', value);
  }
  assert.equal(data.getGameById('snake').highScore, 50);
  f.clock.advance(1000); data.flushNow(); assert.equal(f.store.writes, 0);
  data.updateHighScore('snake', 60); data.flushNow();
  assert.equal(JSON.parse(f.values.get('highScores')).snake, 60);
});

test('score recovery preserves unrelated settings, time and withdrawn-game history', () => {
  const f = fixture({ highScores: '{"snake":9007199254740992,"tictactoe":5,"2048":32}',
    playTimesMs: '{"snake":1234}', settings: '{"soundEnabled":false,"themeMode":"dark"}',
    playedGames: '["snake"]', lastPlayedAt: '{"snake":123456}' });
  const data = f.data(); data.init({}); data.setSetting('hapticsEnabled', false);
  assert.equal(data.getGameById('snake').highScore, 0);
  assert.equal(data.getGameById('snake').playTimeMs, 1234);
  assert.equal(data.getSetting('soundEnabled', true), false); assert.equal(data.getThemeMode(), 'dark');
  assert.equal(data.getPlayHistory()[0].lastPlayedAt, 123456);
  const scores = JSON.parse(f.values.get('highScores'));
  assert.equal(scores.tictactoe, 5); assert.equal(scores['2048'], 32); assert.equal(scores.snake, 0);
});

let failed = 0;
for (const entry of tests) {
  try { entry.run(); } catch (error) { failed++; console.error('FAIL ' + entry.name + '\n' + error.stack); }
}
console.log(`${tests.length - failed}/${tests.length} data recovery checks passed.`);
process.exitCode = failed ? 1 : 0;
