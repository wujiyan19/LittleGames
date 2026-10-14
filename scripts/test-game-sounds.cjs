const assert = require('node:assert/strict');
const fs = require('node:fs');
const crypto = require('node:crypto');
const { fixture } = require('./test-performance.cjs');
const manifest = JSON.parse(fs.readFileSync('docs/audio/manifest.json', 'utf8'));
const base = 'entry/src/main/ets/';
const tests = [];
const test = (name, run) => tests.push({ name, run });
const settle = async () => { for (let i = 0; i < 100; i++) { await Promise.resolve(); } };
function capture(f, id) {
  const { gameSound, GameSoundEvent } = f.load(base + 'common/GameSound.ets');
  const events = [];
  gameSound.connect((game, event) => events.push({ game, event }), () => {}, () => {});
  gameSound.selectGame(id); gameSound.setVisible(true);
  return { sound: gameSound, E: GameSoundEvent, events };
}
function audioFixture(options = {}) {
  const f = fixture(), pools = [], opened = new Set(), closed = [], requested = [];
  let fd = 1;
  f.native['@kit.MediaKit'] = { media: { async createSoundPool(maxStreams, info) {
    assert.equal(maxStreams, 4); assert.equal(info.usage, 11);
    const callbacks = {}, pool = { loaded: [], played: [], stopped: [], volumes: [], released: false,
      on(event, callback) { callbacks[event] = callback; },
      async load() {
        if (options.failLoad) { throw new Error('load failure'); }
        const sound = pool.loaded.length + 1; pool.loaded.push(sound);
        if (options.deferLoad) { await new Promise(resolve => { pool.finishLoad = resolve; }); }
        if (!options.manualComplete) { callbacks.loadComplete(sound); }
        return sound;
      },
      async play(sound, parameters) {
        pool.played.push({ sound, parameters });
        if (options.deferPlay) { return new Promise(resolve => { pool.finishPlay = resolve; }); }
        return pool.played.length + 100;
      },
      async stop(stream) { pool.stopped.push(stream); },
      async setVolume(stream, left, right) { pool.volumes.push({ stream, left, right }); },
      async release() { pool.released = true; },
      complete(sound) { callbacks.loadComplete(sound); },
      finish(stream) { callbacks.playFinishedWithStreamId(stream); }
    };
    pools.push(pool); return pool;
  } } };
  f.native['@kit.AudioKit'] = { audio: { StreamUsage: { STREAM_USAGE_GAME: 11 } } };
  f.native['@kit.LocalizationKit'] = {};
  const sound = f.load(base + 'common/GameSound.ets').gameSound;
  const E = f.load(base + 'common/GameSound.ets').GameSoundEvent;
  const player = new (f.load(base + 'common/GameSoundPlayer.ets').GameSoundPlayer)();
  player.init({ async getRawFd(path) {
    assert(!opened.has(path), 'raw descriptor opened twice: ' + path);
    assert(fs.existsSync('entry/src/main/resources/rawfile/' + path));
    opened.add(path); requested.push(path); return { fd: fd++, offset: 0, length: 100 };
  }, async closeRawFd(path) { assert(opened.delete(path)); closed.push(path); } });
  sound.selectGame('snake');
  return { f, sound, E, player, pools, opened, closed, requested };
}

test('only the 89 available games have sound resources; retired games are absent', () => {
  const f = fixture();
  assert.equal(manifest.games.length, 89);
  const ids = new Set(manifest.games.map(game => game.id));
  assert.equal(ids.size, 89);
  for (const game of f.data().getAllGames()) { assert(ids.has(game.id), game.id); }
  const availableIds = f.data().getAllGames().map(game => game.id);
  assert.deepEqual([...ids].sort(), [...availableIds].sort());
  assert.equal(fs.readdirSync('entry/src/main/resources/rawfile/sounds').length, 182);
  const available = f.load(base + 'common/GameAvailability.ets').isGameAvailable;
  for (const id of ['tictactoe', 'gomoku', 'reversi', 'fourline', 'nim', 'dots', 'tug', 'doudizhu', 'guandan', 'mahjong', 'ludo']) {
    assert.equal(available(id), false); assert(!ids.has(id));
    for (const event of ['action', 'reward']) { assert(!fs.existsSync('entry/src/main/resources/rawfile/sounds/' + id + '_' + event + '.wav')); }
  }
});

test('every WAV is mono 44.1 kHz PCM with nonzero audio, fade edges, no clipping and matching hash', () => {
  const files = manifest.games.flatMap(game => [game.action, game.reward]).concat(manifest.shared);
  const hashes = new Set();
  for (const item of files) {
    const bytes = fs.readFileSync('entry/src/main/resources/rawfile/' + item.path);
    assert.equal(bytes.toString('ascii', 0, 4), 'RIFF'); assert.equal(bytes.toString('ascii', 8, 16), 'WAVEfmt ');
    assert.equal(bytes.readUInt16LE(20), 1); assert.equal(bytes.readUInt16LE(22), 1);
    assert.equal(bytes.readUInt32LE(24), 44100); assert.equal(bytes.readUInt16LE(34), 16);
    assert.equal(bytes.readUInt32LE(40), bytes.length - 44); assert.equal(bytes.length, item.bytes);
    let peak = 0, power = 0;
    for (let i = 44; i < bytes.length; i += 2) { const value = bytes.readInt16LE(i); peak = Math.max(peak, Math.abs(value)); power += value * value; }
    assert(peak > 1000 && peak <= 21300, item.path + ': peak');
    assert(Math.sqrt(power / ((bytes.length - 44) / 2)) > 100, item.path + ': silent');
    assert.equal(bytes.readInt16LE(44), 0); assert(Math.abs(bytes.readInt16LE(bytes.length - 2)) < 100);
    assert.equal(crypto.createHash('sha256').update(bytes).digest('hex'), item.sha256);
    assert(!hashes.has(item.sha256), item.path + ': duplicate'); hashes.add(item.sha256);
  }
});

test('playback waits for loadComplete, loads only six resources, throttles hits and prioritizes results', async () => {
  const a = audioFixture({ manualComplete: true }); await settle(); const pool = a.pools[0];
  assert.equal(a.requested.length, 6); assert.equal(a.opened.size, 0);
  a.sound.play('snake'); await settle(); assert.equal(pool.played.length, 0);
  pool.loaded.forEach(sound => pool.complete(sound));
  a.sound.play('snake'); a.sound.play('snake', a.E.REWARD); await settle();
  assert.equal(pool.played.length, 1); assert.equal(pool.played[0].parameters.loop, 0);
  a.f.clock.advance(60); a.sound.play('snake', a.E.REWARD); await settle();
  assert.equal(pool.played[1].sound, 2);
  a.sound.play('snake', a.E.WIN); await settle();
  assert.equal(pool.played[2].sound, 4); assert.equal(pool.played[2].parameters.priority, 2);
  assert.deepEqual(pool.stopped, [101, 102]); await a.player.dispose(); assert(pool.released);
});

test('mute stops current and in-flight streams, and unmute permits the next action', async () => {
  const a = audioFixture({ deferPlay: true }); await settle(); const pool = a.pools[0];
  a.sound.play('snake'); a.sound.setEnabled(false); pool.finishPlay(501); await settle();
  assert.deepEqual(pool.stopped, [501]);
  a.sound.play('snake'); assert.equal(pool.played.length, 1);
  a.sound.setEnabled(true); a.sound.play('snake'); pool.finishPlay(502); await settle();
  a.sound.setEnabled(false); await settle(); assert.deepEqual(pool.stopped, [501, 502]);
  await a.player.dispose();
});

test('volume scales new and active effects, and zero stops streams without changing the sound switch', async () => {
  const a = audioFixture(); await settle(); const pool = a.pools[0];
  a.f.data().setSoundVolume(80); a.sound.play('snake'); await settle();
  assert.equal(pool.played[0].parameters.leftVolume, 0.52);
  a.f.data().setSoundVolume(40); await settle();
  assert.deepEqual(pool.volumes.at(-1), { stream: 101, left: 0.26, right: 0.26 });
  a.f.data().setSoundVolume(0); await settle(); assert.deepEqual(pool.stopped, [101]);
  assert.equal(a.sound.enabled, true); a.sound.play('snake'); assert.equal(pool.played.length, 1);
  a.f.data().setSoundVolume(50); a.sound.play('snake'); await settle();
  assert.equal(pool.played[1].parameters.leftVolume, 0.325);
  await a.player.dispose();
});

test('an in-flight effect picks up the latest volume when its stream arrives', async () => {
  const a = audioFixture({ deferPlay: true }); await settle(); const pool = a.pools[0];
  a.f.data().setSoundVolume(80); a.sound.play('snake');
  a.f.data().setSoundVolume(20); pool.finishPlay(801); await settle();
  assert.deepEqual(pool.volumes.at(-1), { stream: 801, left: 0.13, right: 0.13 });
  await a.player.dispose();
});

test('rapid volume updates are serialized and coalesce to the newest level', async () => {
  const a = audioFixture(); await settle(); const pool = a.pools[0];
  a.sound.play('snake'); await settle(); let release;
  pool.setVolume = async (stream, left, right) => {
    pool.volumes.push({ stream, left, right });
    if (pool.volumes.length === 1) { await new Promise(resolve => { release = resolve; }); }
  };
  a.f.data().setSoundVolume(70); a.f.data().setSoundVolume(40); a.f.data().setSoundVolume(20);
  assert.equal(pool.volumes.length, 1); release(); await settle();
  assert.deepEqual(pool.volumes.at(-1), { stream: 101, left: 0.13, right: 0.13 });
  assert.equal(pool.volumes.length, 2);
  pool.setVolume = async () => { throw new Error('Stream already ended'); };
  a.f.data().setSoundVolume(30); await settle();
  await a.player.dispose();
});

test('background visibility and old-game callbacks cannot play after navigation', async () => {
  const a = audioFixture({ deferPlay: true }); await settle(); const old = a.pools[0];
  a.sound.play('snake'); a.sound.setVisible(false); old.finishPlay(601); await settle();
  assert.deepEqual(old.stopped, [601]);
  a.sound.play('snake'); assert.equal(old.played.length, 1);
  a.sound.setVisible(true); a.sound.play('snake'); a.sound.selectGame('tetris'); old.finishPlay(602); await settle();
  assert(old.released); assert.deepEqual(old.stopped, [601, 602]);
  const current = a.pools[1]; a.sound.play('snake'); assert.equal(current.played.length, 0);
  a.sound.stop('snake'); a.sound.play('tetris'); current.finishPlay(603); await settle();
  assert.equal(current.played.length, 1); await a.player.dispose();
});

test('rapid switches serialize FD loading and cancel obsolete preparation', async () => {
  const a = audioFixture({ deferLoad: true }); await settle();
  assert.equal(a.opened.size, 1); a.sound.selectGame('tetris'); a.sound.selectGame('2048');
  a.pools[0].finishLoad(); await settle(); assert(a.pools[0].released);
  assert.equal(a.pools.length, 2); assert.equal(a.requested[1], 'sounds/2048_action.wav');
  // Cancel the active load and verify its descriptor is closed when it returns.
  await a.player.dispose(); a.pools[1].finishLoad(); await settle(); assert.equal(a.opened.size, 0);
});

test('failed loading closes the descriptor and releases the pool without rejecting callers', async () => {
  const a = audioFixture({ failLoad: true }); await settle();
  assert.equal(a.opened.size, 0); assert.equal(a.closed.length, 1); assert(a.pools[0].released);
  a.sound.play('snake'); assert.equal(a.pools[0].played.length, 0); await a.player.dispose();
});

test('completed streams are removed and stopping invalidates an unresolved play request', async () => {
  const a = audioFixture(); await settle(); const pool = a.pools[0];
  a.sound.play('snake'); await settle(); pool.finish(101); await a.player.stop(); assert.equal(pool.stopped.length, 0);
  await a.player.dispose();
  const b = audioFixture({ deferPlay: true }); await settle(); b.sound.play('snake');
  await b.player.stop(); b.pools[0].finishPlay(701); await settle(); assert.deepEqual(b.pools[0].stopped, [701]); await b.player.dispose();
});

test('all 13 classic/puzzle ViewModels emit feedback for a legal player action', () => {
  const cases = [
    ['Snake', 'snake', vm => { vm.newGame(); vm.turnRight(); }],
    ['Tetris', 'tetris', vm => { vm.startGame(); vm.moveLeft(); }],
    ['Game2048', '2048', vm => { vm.startGame(); vm.swipeLeft(); vm.swipeRight(); }],
    ['WhackMole', 'whackmole', vm => { vm.startGame(); vm.holes[0] = true; vm.whack(0); }],
    ['BrickBreaker', 'brickbreaker', vm => { vm.startGame(); vm.launchBall(); }],
    ['JumpJump', 'jumpjump', vm => { vm.newGame(); vm.beginCharge(); vm.endCharge(); }],
    ['MemoryCard', 'memorycard', vm => { vm.startGame(); vm.flipCard(0); }],
    ['Minesweeper', 'minesweeper', vm => { vm.startGame(); vm.toggleFlag(0, 0); }],
    ['Match3', 'match3', vm => { vm.startGame(); vm.onGemClick(0, 0); vm.onGemClick(0, 1); }],
    ['SlidePuzzle', 'slidepuzzle', vm => { vm.startGame(); const index = vm.board.indexOf(0); const next = index % vm.getSize() > 0 ? index - 1 : index + 1; vm.tapCell(Math.floor(next / vm.getSize()), next % vm.getSize()); }],
    ['Klotski', 'klotski', vm => { vm.startGame(); for (const block of vm.blocks) { for (const delta of [[1,0],[-1,0],[0,1],[0,-1]]) { if (vm.rules.canMove(vm.blocks, vm.grid, block.id, ...delta)) { vm.selectBlockAt(block.y, block.x); vm.moveBlock(...delta); return; } } } }],
    ['Sudoku', 'sudoku', vm => { vm.newGame(); const index = vm.board.indexOf(0); vm.selectCell(Math.floor(index / 9), index % 9); vm.setNumber(1); }],
    ['GuessNumber', 'guessnumber', vm => { vm.startGame(); vm.pushDigit('1'); }]
  ];
  for (const [name, id, action] of cases) {
    const f = fixture(), vm = f.vm(name + 'ViewModel', f.rng()), a = capture(f, id);
    action(vm); assert(a.events.length > 0, name + ': missing feedback');
    assert(a.events.every(event => event.game === id)); vm.dispose();
  }
});

test('collection illegal taps are silent, results play once, and restored games do not replay results', () => {
  const f = fixture(), vm = f.vm('CollectionViewModel'), a = capture(f, 'tictactoe');
  vm.init('tictactoe'); vm.startGame(); assert.equal(a.events.length, 0);
  vm.tap(-1); assert.equal(a.events.length, 0); vm.tap(0); assert.equal(a.events[0].event, a.E.ACTION);
  vm.tap(0); assert.equal(a.events.length, 1);
  for (const index of [3,1,4,2]) { vm.tap(index); }
  assert.equal(a.events.at(-1).event, a.E.WIN); const count = a.events.length;
  vm.tap(8); assert.equal(a.events.length, count);
  assert(vm.importContinuation(vm.exportContinuation())); assert.equal(a.events.length, count); vm.dispose();
});

test('expansion successful moves/rewards play, undo/restore stay quiet, and melody keeps its original notes', () => {
  const f = fixture(), vm = f.vm('ExpansionViewModel'), a = capture(f, 'pipes');
  vm.init('pipes'); vm.startGame(); assert.equal(a.events.length, 0);
  vm.tap(0); assert(a.events.length > 0); const count = a.events.length;
  vm.undo(); assert.equal(a.events.length, count); assert(vm.importContinuation(vm.exportContinuation())); assert.equal(a.events.length, count);
  vm.dispose();
  const melody = f.vm('ExpansionViewModel'); a.sound.selectGame('melody'); melody.init('melody'); melody.startGame();
  const notes = []; melody.setToneCallbacks(note => notes.push(note), () => {});
  melody.tap(900); melody.advance(100); assert(notes.length > 0);
  assert.equal(a.events.length, count); melody.dispose();
});

test('all sound preferences and lifecycle gating operate through the existing bus', () => {
  const f = fixture(), vm = f.vm('SnakeViewModel', f.rng()), a = capture(f, 'snake');
  const bus = f.load(base + 'common/GameLifecycleBus.ets').GameLifecycleBus;
  bus.attach(vm); vm.newGame(); a.sound.play('snake'); assert.equal(a.events.length, 1);
  bus.setSettingsVisible('snake', true); a.sound.play('snake'); assert.equal(a.events.length, 1);
  bus.setSettingsVisible('snake', false); a.sound.play('snake'); assert.equal(a.events.length, 2);
  bus.notifyHidden(); a.sound.play('snake'); assert.equal(a.events.length, 2);
  bus.notifyShown(); a.sound.play('snake'); assert.equal(a.events.length, 3);
  f.data().setSetting('soundEnabled', false); a.sound.play('snake'); assert.equal(a.events.length, 3);
  f.data().resetSettings(); a.sound.play('snake'); assert.equal(a.events.length, 4);
  bus.detach(vm); a.sound.play('snake'); assert.equal(a.events.length, 4); vm.dispose();
});

(async () => {
  let failed = 0;
  for (const entry of tests) {
    try { await entry.run(); }
    catch (error) { failed++; console.error('FAIL ' + entry.name + '\n' + error.stack); }
  }
  console.log(`${tests.length - failed}/${tests.length} game sound regressions passed.`);
  process.exitCode = failed ? 1 : 0;
})();
