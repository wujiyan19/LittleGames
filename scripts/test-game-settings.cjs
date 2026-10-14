const assert = require('node:assert/strict');
const { fixture, Frames } = require('./test-performance.cjs');
const base = 'entry/src/main/ets/';
const tests = [];
const test = (name, run) => tests.push({ name, run });

test('fresh puzzle sessions have no progress; active timed games are protected', () => {
  const f = fixture();
  for (const name of ['Game2048', 'SlidePuzzle', 'Klotski', 'GuessNumber', 'MemoryCard', 'Minesweeper', 'Match3', 'JumpJump', 'BrickBreaker']) {
    const vm = f.vm(name + 'ViewModel', f.rng()); vm.startGame();
    assert.equal(vm.hasProgress(), false, name); vm.dispose();
  }
  const sudoku = f.vm('SudokuViewModel', f.rng()); sudoku.newGame(); assert.equal(sudoku.hasProgress(), false);
  for (const name of ['Tetris', 'WhackMole']) {
    const vm = f.vm(name + 'ViewModel', f.rng()); vm.startGame();
    assert.equal(vm.hasProgress(), true, name); vm.onAppHidden(); assert.equal(vm.hasProgress(), true); vm.dispose();
  }
});

test('2048 protects a successful move even when no points were earned', () => {
  let checked = false;
  for (let seed = 1; seed <= 100 && !checked; seed++) {
    const f = fixture(), vm = f.vm('Game2048ViewModel', f.rng(seed)); vm.newGame();
    if (!vm.swipeLeft() || vm.score !== 0) continue;
    assert.equal(vm.hasProgress(), true); vm.onAppHidden(); assert.equal(vm.hasProgress(), true);
    const payload = vm.exportContinuation(); vm.startGame(); assert.equal(vm.hasProgress(), false);
    assert.equal(vm.importContinuation(payload), true); assert.equal(vm.hasProgress(), true); checked = true;
  }
  assert(checked);
});

test('Sudoku protects filled cells and clears protection when all edits are erased', () => {
  const f = fixture(), vm = f.vm('SudokuViewModel', f.rng()); vm.newGame();
  const index = vm.board.indexOf(0); assert(index >= 0);
  vm.selectCell(Math.floor(index / 9), index % 9); vm.setNumber(1);
  assert.equal(vm.hasProgress(), true); vm.onAppHidden(); assert.equal(vm.hasProgress(), true);
  vm.erase(); assert.equal(vm.hasProgress(), false);
  vm.setNumber(2); vm.restartGame(); assert.equal(vm.hasProgress(), false);
});

test('one flipped card and an unsubmitted guess are protected', () => {
  const f = fixture(), memory = f.vm('MemoryCardViewModel', f.rng()); memory.startGame(); memory.flipCard(0);
  assert.equal(memory.attempts, 0); assert.equal(memory.hasProgress(), true);
  memory.onAppHidden(); assert.equal(memory.hasProgress(), true); memory.startGame(); assert.equal(memory.hasProgress(), false);
  const guess = f.vm('GuessNumberViewModel', f.rng()); guess.startGame(); guess.pushDigit('1');
  assert.equal(guess.tries, 0); assert.equal(guess.hasProgress(), true); guess.deleteDigit(); assert.equal(guess.hasProgress(), false);
});

test('all collection and expansion games start without edited progress', () => {
  const f = fixture(), data = f.data(); data.init({});
  for (const game of data.getAllGames().slice(13)) {
    const collection = f.load(base + 'model/game/CollectionModel.ets').COLLECTION_IDS.includes(game.id);
    const vm = f.vm(collection ? 'CollectionViewModel' : 'ExpansionViewModel'); vm.init(game.id); vm.startGame();
    assert.equal(vm.hasProgress(), false, game.id); vm.dispose();
  }
  const collection = f.vm('CollectionViewModel'); collection.init('tictactoe'); collection.startGame(); collection.tap(0);
  assert.equal(collection.hasProgress(), true); collection.onAppHidden(); assert.equal(collection.hasProgress(), true);
  collection.startGame(); assert.equal(collection.hasProgress(), false);
  const expansion = f.vm('ExpansionViewModel'); expansion.init('melody', new Frames()); expansion.startGame(); expansion.tap(900);
  assert.equal(expansion.hasProgress(), true); expansion.onAppHidden(); assert.equal(expansion.hasProgress(), true);
  expansion.startGame(); assert.equal(expansion.hasProgress(), false);
});

test('sound preference persists, supports older settings, and resets without losing scores', () => {
  const f = fixture({ settings: JSON.stringify({ hapticsEnabled: false }) }), data = f.data(); data.init({});
  const sound = f.load(base + 'common/GameSound.ets').gameSound;
  assert.equal(sound.enabled, true); data.setSetting('soundEnabled', false); assert.equal(sound.enabled, false);
  const restarted = fixture(Object.fromEntries(f.values)); restarted.data().init({});
  assert.equal(restarted.load(base + 'common/GameSound.ets').gameSound.enabled, false);
  data.updateHighScore('snake', 42); data.resetSettings(); assert.equal(sound.enabled, true);
  assert.equal(data.getGameById('snake').highScore, 42);
});

async function audioFixture() {
  const f = fixture(), stopped = [], played = [], volumes = []; let loaded = () => {}, id = 0;
  const pool = {
    on(event, callback) { assert.equal(event, 'loadComplete'); loaded = callback; },
    async load() { loaded(++id); return id; },
    play(sound, parameters) { played.push({ sound, parameters }); return new Promise(resolve => { pool.finish = resolve; }); },
    async setVolume(stream, left, right) { volumes.push({ stream, left, right }); },
    async stop(stream) { stopped.push(stream); }, async release() {}
  };
  f.native['@kit.MediaKit'] = { media: { async createSoundPool() { return pool; } } };
  f.native['@kit.AudioKit'] = { audio: { StreamUsage: { STREAM_USAGE_GAME: 1 } } };
  f.native['@kit.LocalizationKit'] = {};
  const player = new (f.load(base + 'common/ExpansionTonePlayer.ets').ExpansionTonePlayer)();
  let ready = false; player.onReady = value => { ready = value; };
  await player.init({ async getRawFd() { return { fd: 1, offset: 0, length: 1 }; }, async closeRawFd() {} });
  assert(ready); return { f, player, pool, stopped, played, volumes };
}

test('volume is live, debounced during dragging, committed on release and restored after restart', () => {
  const f = fixture(), data = f.data(); data.init({});
  const sound = f.load(base + 'common/GameSound.ets').gameSound;
  assert.equal(data.getSoundVolume(), 100); assert.equal(sound.volume, 100);
  for (let volume = 80; volume >= 20; volume--) { data.setSoundVolume(volume); }
  assert.equal(sound.volume, 20); assert.equal(f.store.writes, 0); assert.equal(f.clock.count(), 1);
  f.clock.advance(199); assert.equal(f.store.writes, 0);
  data.setSoundVolume(20, true); assert.equal(f.store.writes, 6); assert.equal(f.clock.count(), 0);
  assert.equal(f.store.synchronousFlushes, 1);
  const restarted = fixture(Object.fromEntries(f.values)); restarted.data().init({});
  assert.equal(restarted.data().getSoundVolume(), 20);
  assert.equal(restarted.load(base + 'common/GameSound.ets').gameSound.volume, 20);
});

test('volume validates old/corrupt settings, clamps live input and resets independently of scores', () => {
  for (const value of [undefined, null, true, '20', {}, -1, 101, 1e300]) {
    const f = fixture({ settings: JSON.stringify({ soundVolume: value }) }); f.data().init({});
    assert.equal(f.data().getSoundVolume(), 100);
  }
  const f = fixture({ settings: JSON.stringify({ soundVolume: 42.7, soundEnabled: false }) });
  const data = f.data(); data.init({}); const sound = f.load(base + 'common/GameSound.ets').gameSound;
  assert.equal(sound.volume, 43); assert.equal(sound.enabled, false);
  data.setSoundVolume(25, true); assert.equal(sound.volume, 25); assert.equal(sound.enabled, false);
  data.setSoundVolume(NaN); data.setSoundVolume(Infinity); assert.equal(sound.volume, 25);
  data.setSoundVolume(-10); assert.equal(sound.volume, 0);
  data.setSoundVolume(120); assert.equal(sound.volume, 100);
  data.updateHighScore('snake', 42); data.setSoundVolume(35, true); data.resetSettings();
  assert.equal(sound.volume, 100); assert.equal(sound.enabled, true); assert.equal(data.getGameById('snake').highScore, 42);
  data.setSoundVolume(65, true); data.clearPlayData(); assert.equal(sound.volume, 65);
  assert.equal(data.getSoundVolume(), 65);
});

test('melody volume affects new, active and late-returning streams while zero stays silent', async () => {
  const a = await audioFixture(), data = a.f.data();
  data.setSoundVolume(60); const first = a.player.play(0);
  assert.equal(a.played[0].parameters.leftVolume, 0.6);
  data.setSoundVolume(30); a.pool.finish(31); await first;
  assert.deepEqual(a.volumes.at(-1), { stream: 31, left: 0.3, right: 0.3 });
  data.setSoundVolume(20); await a.player.setVolume();
  assert.deepEqual(a.volumes.at(-1), { stream: 31, left: 0.2, right: 0.2 });
  const pending = a.player.play(1); data.setSoundVolume(0); a.pool.finish(32); await pending;
  assert(a.stopped.includes(32)); await a.player.play(2); assert.equal(a.played.length, 2);
  await a.player.dispose();
});

test('muting blocks playback and stops a stream returned after mute', async () => {
  const a = await audioFixture(), data = a.f.data();
  data.setSetting('soundEnabled', false); await a.player.play(0); assert.equal(a.played.length, 0);
  data.setSetting('soundEnabled', true); const pending = a.player.play(1);
  data.setSetting('soundEnabled', false); a.pool.finish(11); await pending; assert.deepEqual(a.stopped, [11]);
  data.setSetting('soundEnabled', true); const resumed = a.player.play(2); a.pool.finish(12); await resumed;
  await a.player.stop(); assert.deepEqual(a.stopped, [11, 12]); await a.player.dispose();
});

test('stopping playback also cancels an in-flight stream', async () => {
  const a = await audioFixture(); const pending = a.player.play(0);
  await a.player.stop(); a.pool.finish(21); await pending; assert.deepEqual(a.stopped, [21]);
  await a.player.dispose();
});

test('muted melody keeps its visual sequence running', () => {
  const f = fixture(); f.data().setSetting('soundEnabled', false);
  const vm = f.vm('ExpansionViewModel'); vm.init('melody', new Frames()); vm.startGame(); vm.tap(900); vm.advance(100);
  assert.equal(vm.state.phase, 1); assert(vm.state.selected >= 0 && vm.state.selected < 4); vm.dispose();
});

(async () => {
  let failed = 0;
  for (const entry of tests) {
    try { await entry.run(); }
    catch (error) { failed++; console.error('FAIL ' + entry.name + '\n' + error.stack); }
  }
  console.log(`${tests.length - failed}/${tests.length} game settings regressions passed.`);
  process.exitCode = failed ? 1 : 0;
})();
