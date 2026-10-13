const assert = require('node:assert/strict');
const { fixture, Frames } = require('./test-performance.cjs');
const tests = [];
const test = (name, run) => tests.push({ name, run });
const base = 'entry/src/main/ets/';

class Session {
  constructor(id) { this.id = id; this.active = true; this.hidden = 0; this.shown = 0; }
  continuationGameId() { return this.id; }
  isPlayTimeActive() { return this.active; }
  onAppHidden() { this.hidden++; }
  onAppShown() { this.shown++; }
  onBackRequested() { this.active = false; return true; }
  exportContinuation() { return '{}'; }
  importContinuation() { return true; }
}
function tracking(initialValues = {}) {
  const f = fixture(initialValues), data = f.data(); data.init({});
  const bus = f.load(base + 'common/GameLifecycleBus.ets').GameLifecycleBus;
  const session = new Session('2048'); bus.attach(session); bus.updatePlayTime(session);
  return { f, data, bus, session, time: () => data.getGameById('2048').playTimeMs };
}

test('hours always have one decimal, including zero and rounding boundaries', () => {
  const { playTimeHours, formatPlayTime } = fixture().load(base + 'common/PlayTime.ets');
  for (const [ms, expected] of [[0, '0.0'], [60000, '0.0'], [179999, '0.0'], [180000, '0.1'],
    [3600000, '1.0'], [4320000, '1.2'], [35999999, '10.0'], [-1, '0.0'], [NaN, '0.0'], [Infinity, '0.0']]) {
    assert.equal(playTimeHours(ms), expected);
  }
  assert.equal(formatPlayTime(4320000, { resourceManager: { getStringSync() { return '%1$s 小时'; } } }), '1.2 小时');
});

test('legacy counts preserve played games, scores and recent order without invented time', () => {
  const f = fixture({ playCounts: '{"snake":8,"2048":2,"not-a-game":99}',
    recentGames: '["2048","snake","2048","invalid"]', highScores: '{"snake":128}', settings: '{"themeMode":"dark"}' });
  const data = f.data(); data.init({});
  assert.equal(data.getTotalPlayTimeMs(), 0); assert.equal(data.getPlayedGameCount(), 2);
  assert.deepEqual(data.getRecentlyPlayed().map(g => g.id), ['2048', 'snake']);
  assert.equal(data.getGameById('snake').highScore, 128); assert.equal(data.getThemeMode(), 'dark');
  data.addPlayTime('snake', 4320000); data.flushNow();
  const restored = fixture(Object.fromEntries(f.values)).data(); restored.init({});
  assert.equal(restored.getGameById('snake').playTimeMs, 4320000);
  assert.equal(restored.getPlayedGameCount(), 2);
});

test('clearing records persists empty played IDs and never restores legacy counts on restart', () => {
  const f = fixture({ playCounts: '{"snake":8}', recentGames: '["snake"]' }), data = f.data(); data.init({});
  data.addPlayTime('snake', 4320000); data.updateHighScore('snake', 128); data.setTextSetting('themeMode', 'dark');
  data.clearPlayData();
  const restored = fixture(Object.fromEntries(f.values)).data(); restored.init({});
  assert.equal(restored.getTotalPlayTimeMs(), 0); assert.equal(restored.getPlayedGameCount(), 0);
  assert.equal(restored.getRecentlyPlayed().length, 0); assert.equal(restored.getGameById('snake').highScore, 0);
  assert.equal(restored.getThemeMode(), 'dark');
});

test('restoration ignores malformed durations and game IDs', () => {
  const f = fixture({ playTimesMs: '{"snake":3600000.9,"2048":-1,"tetris":"999","sudoku":1e300,"invalid":200}',
    playedGames: '["snake","snake",null,99,"invalid"]', recentGames: '{}' }), data = f.data(); data.init({});
  assert.equal(data.getTotalPlayTimeMs(), 3600000); assert.equal(data.getPlayedGameCount(), 1);
  assert.equal(data.getRecentlyPlayed().length, 0);
  const malformed = fixture({ playTimesMs: '{bad', playedGames: 'null', recentGames: 'null' }).data(); malformed.init({});
  assert.equal(malformed.getTotalPlayTimeMs(), 0); assert.equal(malformed.getPlayedGameCount(), 0);
});

test('entry and replay only reorder recents; durations rank games independently of entry counts', () => {
  const f = fixture(), data = f.data(); data.init({});
  for (let i = 0; i < 10; i++) data.recordGamePlayed('snake');
  data.recordGamePlayed('2048'); assert.equal(data.getTotalPlayTimeMs(), 0);
  data.addPlayTime('snake', 1000); data.addPlayTime('2048', 2500.9);
  assert.equal(data.getTotalPlayTimeMs(), 3500); assert.equal(data.getPlayedGameCount(), 2);
  assert.deepEqual(data.getMostPlayed(2).map(g => g.id), ['2048', 'snake']);
  data.recordGamePlayed('snake'); assert.deepEqual(data.getRecentlyPlayed(2).map(g => g.id), ['snake', '2048']);
  for (const invalid of [-1, 0, 0.9, NaN, Infinity, Number.MAX_SAFE_INTEGER]) data.addPlayTime('snake', invalid);
  data.addPlayTime('invalid', 99999); assert.equal(data.getTotalPlayTimeMs(), 3500);
});

test('checkpoint plus final milliseconds accumulates exactly, persists and never double-counts', () => {
  const { f, data, bus, session, time } = tracking();
  f.clock.advance(12345); assert.equal(time(), 10000);
  bus.flushPlayTime(); assert.equal(time(), 12345); bus.flushPlayTime(); assert.equal(time(), 12345);
  f.clock.advance(3456); bus.detach(session); assert.equal(time(), 15801); assert.equal(f.clock.count(), 0);
  f.clock.advance(100000); bus.flushPlayTime(); assert.equal(time(), 15801);
  const restored = fixture(Object.fromEntries(f.values)).data(); restored.init({});
  assert.equal(restored.getGameById('2048').playTimeMs, 15801);
});

test('pause, confirmation and finished result stop counting; replay resumes the same total', () => {
  const { f, bus, session, time } = tracking();
  f.clock.advance(1234); session.active = false; bus.updatePlayTime(session); assert.equal(time(), 1234);
  f.clock.advance(10000); assert.equal(time(), 1234); assert.equal(f.clock.count(), 0);
  session.active = true; bus.updatePlayTime(session); f.clock.advance(2345);
  assert.equal(bus.notifyBackRequested(), true); assert.equal(time(), 3579);
  f.clock.advance(10000); session.active = true; bus.updatePlayTime(session); f.clock.advance(333);
  session.active = false; bus.updatePlayTime(session); f.clock.advance(10000); assert.equal(time(), 3912);
  session.active = true; bus.updatePlayTime(session); f.clock.advance(111); bus.detach(session); assert.equal(time(), 4023);
});

test('background and foreground preserve active/manual-pause state and exclude time asleep', () => {
  const { f, bus, session, time } = tracking();
  f.clock.advance(1111); bus.notifyHidden(); assert.equal(time(), 1111); assert.equal(session.hidden, 1);
  f.clock.advance(3600000); bus.updatePlayTime(session); assert.equal(f.clock.count(), 0); assert.equal(time(), 1111);
  bus.notifyShown(); f.clock.advance(2222); bus.flushPlayTime(); assert.equal(time(), 3333);
  session.active = false; bus.updatePlayTime(session); bus.notifyHidden(); f.clock.advance(10000); bus.notifyShown();
  f.clock.advance(10000); bus.detach(session); assert.equal(time(), 3333);
});

test('switching games and stale detach/monitor callbacks cannot leak duration between games', () => {
  const { f, data, bus, session, time } = tracking();
  f.clock.advance(4567); const next = new Session('snake'); bus.attach(next); bus.updatePlayTime(next);
  assert.equal(time(), 4567); bus.detach(session); bus.updatePlayTime(session);
  f.clock.advance(2345); bus.detach(next); assert.equal(data.getGameById('snake').playTimeMs, 2345);
  assert.equal(time(), 4567); assert.equal(f.clock.count(), 0);
});

test('wall-clock changes do not alter duration, and export flushes the active interval', () => {
  const { f, bus, session, time } = tracking();
  f.clock.advance(999); f.clock.shiftWallTime(-86400000); f.clock.advance(888); bus.flushPlayTime(); assert.equal(time(), 1887);
  f.clock.shiftWallTime(864000000); f.clock.advance(777);
  assert.equal(bus.exportSession('2048'), '{}'); assert.equal(time(), 2664); bus.detach(session);
});

test('a warm continuation replaces the session while preserving foreground accounting', () => {
  const { f, data, bus, session, time } = tracking();
  f.clock.advance(1234); bus.suspendSession(); assert.equal(time(), 1234);
  f.clock.advance(4567); const next = new Session('snake'); bus.attach(next); bus.updatePlayTime(next);
  bus.detach(session); f.clock.advance(2345); bus.detach(next);
  assert.equal(data.getGameById('snake').playTimeMs, 2345); assert.equal(time(), 1234);
});

test('a transient uptime failure never produces negative duration and recovers on the next checkpoint', () => {
  const { f, bus, session, time } = tracking();
  const clock = f.native['@kit.BasicServicesKit'].systemDateTime, original = clock.getUptime;
  f.clock.advance(1000); clock.getUptime = () => { throw new Error('clock unavailable'); }; bus.flushPlayTime();
  assert.equal(time(), 0); clock.getUptime = original; f.clock.advance(5000);
  bus.flushPlayTime(); assert.equal(time(), 1000); bus.detach(session);
});

for (const name of ['Snake', 'Tetris', 'Game2048', 'WhackMole', 'Minesweeper', 'Sudoku',
  'SlidePuzzle', 'Klotski', 'GuessNumber', 'MemoryCard', 'JumpJump', 'BrickBreaker', 'Match3']) {
  test(`${name}: active predicate excludes modal, pause, result and first-action/generation waits`, () => {
    const f = fixture(), vm = name === 'JumpJump' ? f.vm(name + 'ViewModel') : f.vm(name + 'ViewModel', f.rng(7));
    if (vm.setFrameLoop) vm.setFrameLoop(new Frames());
    if (name === 'Sudoku') vm.newGame(); else vm.startGame();
    if (name === 'Snake' || name === 'BrickBreaker') { assert.equal(vm.isPlayTimeActive(), false); vm.started = true; }
    assert.equal(vm.isPlayTimeActive(), true);
    vm.confirmExit = true; assert.equal(vm.isPlayTimeActive(), false); vm.confirmExit = false;
    vm.status = 'paused'; assert.equal(vm.isPlayTimeActive(), false);
    vm.status = 'gameover'; assert.equal(vm.isPlayTimeActive(), false); vm.status = 'playing';
    if (name === 'Sudoku') {
      vm.isGenerating = true; assert.equal(vm.isPlayTimeActive(), false); vm.isGenerating = false;
      vm.generationFailed = true; assert.equal(vm.isPlayTimeActive(), false);
    }
    vm.dispose();
  });
}

test('collection terminal result stops time; replay resets terminal state', () => {
  const f = fixture(), vm = f.vm('CollectionViewModel'); vm.init('tictactoe'); vm.startGame();
  assert.equal(vm.isPlayTimeActive(), true); vm.requestBack(); assert.equal(vm.isPlayTimeActive(), false);
  vm.dismissExitConfirm(); for (const i of [0, 3, 1, 4, 2]) vm.tap(i);
  assert.equal(vm.isFinished, true); assert.equal(vm.isPlayTimeActive(), false);
  vm.startGame(); assert.equal(vm.isFinished, false); assert.equal(vm.isPlayTimeActive(), true); vm.dispose();
});

test('expansion pause, modal and terminal state control time across replay', () => {
  const f = fixture(), vm = f.vm('ExpansionViewModel'); vm.init('xiangqi', new Frames()); vm.startGame();
  assert.equal(vm.isPlayTimeActive(), true); vm.togglePause(); assert.equal(vm.isPlayTimeActive(), false);
  vm.togglePause(); vm.requestBack(); assert.equal(vm.isPlayTimeActive(), false); vm.dismissExitConfirm();
  vm.model.state.outcome = 1; vm.sync(false); assert.equal(vm.isFinished, true); assert.equal(vm.isPlayTimeActive(), false);
  vm.startGame(); assert.equal(vm.isFinished, false); assert.equal(vm.isPlayTimeActive(), true); vm.dispose();
});

test('settings pause time and app foreground cannot resume a covered game', () => {
  const { f, bus, session, time } = tracking();
  f.clock.advance(1234); bus.setSettingsVisible('2048', true);
  assert.equal(time(), 1234); assert.equal(session.hidden, 1);
  f.clock.advance(20000); bus.updatePlayTime(session); assert.equal(f.clock.count(), 0);
  bus.notifyHidden(); bus.notifyShown(); assert.equal(session.shown, 0);
  f.clock.advance(20000); assert.equal(time(), 1234);
  bus.setSettingsVisible('2048', false); assert.equal(session.shown, 1);
  f.clock.advance(345); bus.detach(session); assert.equal(time(), 1579);
});

test('app settings keeps the game suspended until its destination is shown again', () => {
  const { f, bus, session, time } = tracking();
  f.clock.advance(1000); bus.setSettingsVisible('2048', true);
  bus.setPageVisible('2048', false); bus.setSettingsVisible('2048', false);
  assert.equal(session.shown, 0); f.clock.advance(20000);
  bus.notifyHidden(); bus.notifyShown(); assert.equal(session.shown, 0);
  bus.setPageVisible('2048', true); assert.equal(session.shown, 1);
  f.clock.advance(500); bus.detach(session); assert.equal(time(), 1500);
});

test('stale settings callbacks do not suspend a new game and repeated close is idempotent', () => {
  const { f, data, bus, session } = tracking();
  const next = new Session('snake'); bus.attach(next); bus.updatePlayTime(next);
  bus.setSettingsVisible('2048', true); bus.setPageVisible('2048', false);
  f.clock.advance(1000); bus.setSettingsVisible('snake', true);
  bus.setSettingsVisible('snake', false); bus.setSettingsVisible('snake', false);
  assert.equal(next.hidden, 1); assert.equal(next.shown, 1);
  bus.detach(session); f.clock.advance(500); bus.detach(next);
  assert.equal(data.getGameById('snake').playTimeMs, 1500);
});

for (const name of ['Snake', 'Tetris', 'WhackMole', 'BrickBreaker']) {
  test(`${name}: settings restores automatic pause and preserves deliberate pause`, () => {
    const f = fixture(), data = f.data(); data.init({});
    const bus = f.load(base + 'common/GameLifecycleBus.ets').GameLifecycleBus;
    const vm = f.vm(name + 'ViewModel', f.rng(7));
    if (vm.setFrameLoop) vm.setFrameLoop(new Frames());
    vm.startGame(); const id = vm.continuationGameId(); bus.attach(vm); bus.updatePlayTime(vm);
    bus.setSettingsVisible(id, true); assert.equal(vm.status, 'paused');
    bus.setSettingsVisible(id, false); assert.equal(vm.status, 'playing');
    vm.togglePause(); assert.equal(vm.status, 'paused');
    bus.setSettingsVisible(id, true); bus.setSettingsVisible(id, false);
    assert.equal(vm.status, 'paused');
    vm.togglePause(); assert.equal(vm.status, 'playing');
    bus.detach(vm); vm.dispose();
  });
}

(async () => {
  let failed = 0;
  for (const entry of tests) {
    try { await entry.run(); } catch (error) { failed++; console.error(`FAIL ${entry.name}\n${error.stack}`); }
  }
  console.log(`${tests.length - failed}/${tests.length} play-time regressions passed.`);
  process.exitCode = failed ? 1 : 0;
})();
