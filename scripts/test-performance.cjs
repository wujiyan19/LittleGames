/* Desktop logic regression runner. ArkTS/UI compilation and real device profiling
 * remain separate checks; native services and time are controlled here. */
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const ts = require(process.env.ARKTS_TYPESCRIPT_PATH ||
  'C:/Program Files/Huawei/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const root = path.resolve(__dirname, '..');
const compiled = new Map();
const tests = [];
let group = '';
const hypium = {
  describe(name, callback) { const previous = group; group = name; callback(); group = previous; },
  it(name, flags, callback) { tests.push({ name: `${group}: ${name}`, callback }); },
  expect(value) { return {
    assertEqual(expected) { assert.equal(value, expected); },
    assertTrue() { assert.equal(value, true); },
    assertFalse() { assert.equal(value, false); }
  }; }
};

function fixture(initialValues = {}) {
  let now = 100000;
  let nextTimer = 1;
  const timers = new Map();
  const cache = new Map();
  const tasks = [];
  const displays = [];
  const flushes = [];
  const values = new Map(Object.entries(initialValues));
  const vibrations = [];
  const store = {
    writes: 0, synchronousFlushes: 0,
    getSync(key, fallback) { return values.has(key) ? values.get(key) : fallback; },
    putSync(key, value) { this.writes++; values.set(key, value); },
    flushSync() { this.synchronousFlushes++; },
    flush() { return new Promise((resolve, reject) => flushes.push({ resolve, reject })); }
  };
  function schedule(callback, ms, interval) {
    const id = nextTimer++;
    timers.set(id, { callback, at: now + ms, interval: interval ? ms : 0 });
    return id;
  }
  const clock = {
    count() { return timers.size; },
    advance(ms) {
      const end = now + ms;
      let guard = 0;
      while (true) {
        let selected = null;
        for (const entry of timers.entries()) {
          if (entry[1].at <= end && (!selected || entry[1].at < selected[1].at)) { selected = entry; }
        }
        if (!selected) { break; }
        assert.ok(++guard < 100000, 'unbounded timer work');
        now = selected[1].at;
        if (selected[1].interval) { selected[1].at += selected[1].interval; }
        else { timers.delete(selected[0]); }
        selected[1].callback();
      }
      now = end;
    }
  };
  class ClockDate extends Date { static now() { return now; } }
  class Task {
    constructor(callback, ...args) { this.callback = callback; this.args = args; this.cancelled = false; }
  }
  const native = {
    '@ohos/hypium': hypium,
    '@kit.ArkData': { preferences: { getPreferencesSync() { return store; } } },
    '@kit.AbilityKit': { ConfigurationConstant: { ColorMode: {
      COLOR_MODE_NOT_SET: -1, COLOR_MODE_DARK: 0, COLOR_MODE_LIGHT: 1
    } } }, '@kit.BasicServicesKit': {},
    '@kit.PerformanceAnalysisKit': { hilog: { error() {}, debug() {}, info() {}, warn() {} } },
    '@kit.SensorServiceKit': { vibrator: { startVibration(effect, usage) { vibrations.push({ effect, usage }); } } },
    '@kit.ArkUI': { display: { getDefaultDisplaySync() { return { width: 400, height: 800, densityPixels: 1 }; } } },
    '@kit.ArkTS': { taskpool: {
      Task,
      execute(task) { return new Promise((resolve, reject) => tasks.push({ task, resolve, reject })); },
      cancel(task) { task.cancelled = true; }
    } },
    '@kit.ArkGraphics2D': { displaySync: { create() {
      const display = {
        running: false, starts: 0, listener: null, range: null,
        setExpectedFrameRateRange(range) { this.range = range; },
        on(event, callback) { assert.equal(event, 'frame'); this.listener = callback; },
        off(event, callback) { assert.equal(this.listener, callback); this.listener = null; },
        start() { this.running = true; this.starts++; },
        stop() { this.running = false; },
        emit(ms) { if (this.listener) { this.listener({ timestamp: ms * 1e6 }); } }
      };
      displays.push(display);
      return display;
    } } }
  };
  function load(relative) {
    const file = path.resolve(root, relative);
    if (cache.has(file)) { return cache.get(file).exports; }
    if (!compiled.has(file)) {
      const source = fs.readFileSync(file, 'utf8').replace(/@(ObservedV2|Trace|Concurrent)\b/g, '');
      const result = ts.transpileModule(source, { fileName: file, compilerOptions: {
        target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
      }, reportDiagnostics: true });
      const errors = (result.diagnostics || []).filter(d => d.category === ts.DiagnosticCategory.Error);
      assert.equal(errors.length, 0, `${file}: ${errors.map(e => e.messageText).join(', ')}`);
      compiled.set(file, result.outputText);
    }
    const module = { exports: {} };
    cache.set(file, module);
    const localRequire = name => {
      if (Object.hasOwn(native, name)) { return native[name]; }
      assert.ok(name.startsWith('.'), `unmocked native import ${name}`);
      return load(path.relative(root, path.resolve(path.dirname(file), name + '.ets')));
    };
    new Function('require', 'module', 'exports', 'setInterval', 'clearInterval',
      'setTimeout', 'clearTimeout', 'Date', '$r', compiled.get(file))(
      localRequire, module, module.exports,
      (fn, ms) => schedule(fn, ms, true), id => timers.delete(id),
      (fn, ms) => schedule(fn, ms, false), id => timers.delete(id), ClockDate, name => name);
    return module.exports;
  }
  return { load, clock, tasks, displays, store, flushes, values, vibrations, native,
    vm(name, ...args) { return new (load(`entry/src/main/ets/viewmodel/${name}.ets`)[name])(...args); },
    rules(name) { return load(`entry/src/main/ets/model/game/${name}Model.ets`); },
    rng(seed = 1) { return new (load('entry/src/main/ets/model/game/RandomSource.ets').SeededRandom)(seed); },
    data() { return load('entry/src/main/ets/model/GameData.ets').GameDataManager; }
  };
}

class Frames {
  constructor() { this.running = false; this.disposed = false; this.callback = () => {}; }
  start(callback) { this.callback = callback; this.running = true; }
  stop() { this.running = false; }
  dispose() { this.stop(); this.disposed = true; }
  tick(ms) { if (this.running) { this.callback(ms); } }
}
function test(name, callback) { tests.push({ name: `Performance: ${name}`, callback }); }
function live(name, start) {
  const f = fixture();
  const vm = f.vm(name, f.rng());
  vm[start]();
  return { f, vm };
}
function jumpFixture() {
  const f = fixture(); const vm = f.vm('JumpJumpViewModel'); const frames = new Frames();
  vm.setFrameLoop(frames); vm.newGame();
  return { f, vm, frames };
}
function brickFixture(seed = 8) {
  const f = fixture(); const vm = f.vm('BrickBreakerViewModel', f.rng(seed)); const frames = new Frames();
  vm.setFrameLoop(frames); vm.startGame();
  return { f, vm, frames };
}

fixture().load('entry/src/test/List.test.ets').default();

test('snake restart removes the previous timer until the first direction input', () => {
  const { f, vm } = live('SnakeViewModel', 'newGame');
  assert.equal(f.clock.count(), 0);
  vm.turnRight(); assert.equal(f.clock.count(), 1);
  vm.newGame(); assert.equal(f.clock.count(), 0);
  const x = vm.snake[0].x; f.clock.advance(2000); assert.equal(vm.snake[0].x, x);
  vm.turnRight(); assert.equal(f.clock.count(), 1); vm.dispose(); assert.equal(f.clock.count(), 0);
});

for (const [name, start, count] of [['SnakeViewModel', 'newGame', 1],
  ['TetrisViewModel', 'startGame', 1], ['WhackMoleViewModel', 'startGame', 2]]) {
  test(`${name} releases timers on pause, modal, background and disposal`, () => {
    const { f, vm } = live(name, start);
    if (name === 'SnakeViewModel') { vm.turnRight(); }
    assert.equal(f.clock.count(), count);
    vm.togglePause(); assert.equal(f.clock.count(), 0);
    vm.onAppHidden(); vm.onAppShown(); assert.equal(vm.status, 'paused'); assert.equal(f.clock.count(), 0);
    vm.togglePause(); assert.equal(f.clock.count(), count);
    assert.equal(vm.requestBack(), true); assert.equal(f.clock.count(), 0);
    vm.onAppHidden(); vm.onAppShown(); assert.equal(f.clock.count(), 0);
    vm.dismissExitConfirm(); assert.equal(f.clock.count(), count);
    vm.onAppHidden(); assert.equal(f.clock.count(), 0);
    f.clock.advance(10000); vm.onAppShown(); assert.equal(f.clock.count(), count);
    vm.dispose(); assert.equal(f.clock.count(), 0);
  });
}

test('mole countdown preserves the remaining fraction of a second across pauses', () => {
  const { f, vm } = live('WhackMoleViewModel', 'startGame'); const time = vm.timeLeft;
  f.clock.advance(400); vm.togglePause(); f.clock.advance(4000);
  assert.equal(vm.timeLeft, time); vm.togglePause(); f.clock.advance(599);
  assert.equal(vm.timeLeft, time); f.clock.advance(1); assert.equal(vm.timeLeft, time - 1);
  vm.onAppHidden(); f.clock.advance(9000); vm.onAppShown(); f.clock.advance(1000);
  assert.equal(vm.timeLeft, time - 2); vm.dispose();
});

test('snake retained cell identities update only changed appearances', () => {
  const { vm } = live('SnakeViewModel', 'newGame'); const cells = vm.cells.slice();
  const before = cells.map(c => `${c.kind}/${c.rotation}`); vm.stepOnce();
  assert.ok(cells.filter((c, i) => `${c.kind}/${c.rotation}` !== before[i]).length <= 4);
  assert.ok(cells.every((c, i) => vm.cells[i] === c));
  for (let y = 0; y < 20; y++) { for (let x = 0; x < 20; x++) {
    assert.equal(vm.isSnakeCell(x, y), vm.snake.some(p => p.x === x && p.y === y));
    assert.equal(vm.isFood(x, y), vm.food.x === x && vm.food.y === y);
  } }
  vm.dispose();
});

test('tetris cell cache agrees with the rules after movement, rotation, falling and locking', () => {
  const { vm } = live('TetrisViewModel', 'newGame'); const cells = vm.cells.slice();
  const before = cells.map(c => c.mark); vm.moveLeft();
  assert.ok(cells.filter((c, i) => c.mark !== before[i]).length <= 8);
  for (const op of ['moveRight', 'rotateBlock', 'drop', 'hardDrop']) {
    vm[op]();
    for (let r = 0; r < 20; r++) { for (let c = 0; c < 10; c++) {
      assert.equal(vm.cells[r * 10 + c].mark, vm.cellMark(r, c));
    } }
  }
  assert.ok(cells.every((c, i) => vm.cells[i] === c)); vm.dispose();
});

test('food spawning excludes all occupied cells and handles a full board', () => {
  const f = fixture(); const { SnakeRules } = f.rules('Snake'); const rules = new SnakeRules(20, 20);
  const occupied = new Set();
  for (let x = 0; x < 20; x++) { for (let y = 0; y < 20; y++) {
    if (x !== 19 || y !== 19) { occupied.add(y * 20 + x); }
  } }
  const food = rules.spawnFoodFromOccupancy(occupied, f.rng());
  assert.deepEqual([food.x, food.y], [19, 19]); occupied.add(399);
  assert.equal(rules.spawnFoodFromOccupancy(occupied, f.rng()).x, -1);
});

test('display frame source converts nanoseconds, resets resume time and unregisters on disposal', () => {
  const f = fixture(); const { DisplayFrameLoop } = f.load('entry/src/main/ets/common/DisplayFrameLoop.ets');
  let scopes = 0; const values = [];
  const loop = new DisplayFrameLoop({ runScopedTask(fn) { scopes++; fn(); } });
  loop.start(delta => values.push(delta)); loop.start(delta => values.push(delta));
  const display = f.displays[0]; assert.deepEqual(display.range, { min: 30, max: 60, expected: 60 });
  assert.equal(display.starts, 1); display.emit(1000); display.emit(1016);
  loop.stop(); display.emit(9000); loop.start(delta => values.push(delta)); display.emit(9016); display.emit(9033);
  assert.deepEqual(values, [0, 16, 0, 17]); assert.equal(scopes, 2);
  loop.dispose(); assert.equal(display.listener, null); assert.equal(display.running, false);
});

test('brick simulation keeps its original 30ms speed while display positions interpolate', () => {
  const a = brickFixture(); const b = brickFixture(); a.vm.launchBall(); b.vm.launchBall();
  for (let i = 0; i < 10; i++) { a.frames.tick(30); b.vm.stepOnce(); }
  assert.deepEqual({ ...a.vm.ball }, { ...b.vm.ball });
  const previousX = a.vm.ballX; const nextX = a.vm.ball.x; a.frames.tick(15);
  assert.ok(Math.abs(a.vm.ballX - (previousX + nextX) / 2) < 1e-8);
  assert.deepEqual({ ...a.vm.ball }, { ...b.vm.ball });
  a.vm.dispose(); b.vm.dispose();
});

test('brick long frame catches up at most three physics steps', () => {
  const a = brickFixture(); const b = brickFixture(); a.vm.launchBall(); b.vm.launchBall();
  a.frames.tick(5000); for (let i = 0; i < 3; i++) { b.vm.stepOnce(); }
  assert.deepEqual({ ...a.vm.ball }, { ...b.vm.ball }); a.vm.dispose(); b.vm.dispose();
});

test('brick first interpolated frame starts at the dragged paddle and launch is blocked behind confirmation', () => {
  const { vm, frames } = brickFixture(); vm.dragPaddle(230); vm.requestBack(); vm.launchBall();
  assert.equal(vm.started, false); assert.equal(frames.running, false);
  vm.dismissExitConfirm(); vm.launchBall(); frames.tick(0); assert.equal(vm.ballX, 230);
  vm.dispose();
});

test('brick missed ball stops frames while waiting for another launch', () => {
  const { f, vm, frames } = brickFixture(); const { BallState } = f.rules('BrickBreaker');
  vm.launchBall(); vm.ball = new BallState(10, vm.gameHeight() + 20, 0, 4, 6); frames.tick(30);
  assert.equal(vm.lives, 2); assert.equal(vm.started, false); assert.equal(frames.running, false);
  vm.launchBall(); assert.equal(frames.running, true); vm.dispose();
});

test('brick level transitions suspend in background and old transitions cannot overwrite a new game', () => {
  const { f, vm, frames } = brickFixture(); vm.nextLevel();
  assert.equal(frames.running, false); vm.onAppHidden(); assert.equal(f.clock.count(), 0);
  f.clock.advance(5000); assert.equal(vm.levelClearMsg, true); vm.onAppShown();
  assert.equal(f.clock.count(), 1); vm.newGame(); f.clock.advance(5000);
  assert.equal(vm.level, 1); assert.equal(vm.started, false); assert.equal(vm.levelClearMsg, false);
  vm.nextLevel(); f.clock.advance(2000); assert.equal(vm.level, 2); assert.equal(vm.started, false);
  assert.equal(frames.running, false); vm.dispose();
});

test('brick idle, pause, modal and background never run frames', () => {
  const { vm, frames } = brickFixture(); assert.equal(frames.running, false);
  vm.launchBall(); assert.equal(frames.running, true); vm.togglePause(); assert.equal(frames.running, false);
  vm.onAppHidden(); vm.onAppShown(); assert.equal(frames.running, false); vm.togglePause();
  assert.equal(frames.running, true); vm.requestBack(); assert.equal(frames.running, false);
  const ball = { ...vm.ball }; vm.advanceFrame(300); assert.deepEqual({ ...vm.ball }, ball);
  vm.onAppHidden(); vm.onAppShown(); assert.equal(frames.running, false);
  vm.dismissExitConfirm(); assert.equal(frames.running, true); vm.dispose(); assert.equal(frames.disposed, true);
});

test('brick collision geometry is reused and the input ball remains unchanged', () => {
  const f = fixture(); const { BrickBreakerRules, BallState } = f.rules('BrickBreaker');
  const rules = new BrickBreakerRules(); const layout = rules.generateLayout(1);
  const rect = rules.brickRect(0, 0); rules.generateLayout(5); assert.equal(rules.brickRect(0, 0), rect);
  const ball = new BallState(200, 300, 3, -4, 6); const before = { ...ball };
  rules.step(ball, layout, layout.map(() => true), 200); assert.deepEqual({ ...ball }, before);
});

test('1000 successful jumps keep platform count bounded and current platform identity stable', () => {
  const { vm, frames } = jumpFixture(); let max = 0; let previousId = 0;
  for (let i = 0; i < 1000; i++) {
    vm.beginCharge(); frames.tick(1200); assert.equal(frames.running, false);
    vm.endCharge(); frames.tick(1000); assert.equal(vm.status, 'playing'); assert.equal(vm.isJumping, false);
    assert.equal(frames.running, false); assert.equal(vm.playerX, vm.baseScreenX());
    assert.ok(vm.currentPlatform().id > previousId); previousId = vm.currentPlatform().id;
    assert.equal(vm.platforms.filter(p => vm.isCurrentPlatform(p.id)).length, 1);
    assert.equal(vm.platforms.filter(p => vm.isNextPlatform(p.id)).length, 1);
    max = Math.max(max, vm.platforms.length);
  }
  assert.equal(vm.score, 1000); assert.ok(max <= 15, `retained ${max} platforms`); vm.dispose();
});

test('jump freezes mid-flight during background and confirmation then resumes without elapsed idle time', () => {
  const { f, vm, frames } = jumpFixture(); vm.beginCharge(); frames.tick(1200); vm.endCharge(); frames.tick(100);
  const x = vm.playerJumpX; vm.onAppHidden(); assert.equal(frames.running, false);
  f.clock.advance(10000); vm.advanceFrame(10000); assert.equal(vm.playerJumpX, x);
  vm.onAppShown(); assert.equal(frames.running, true); vm.requestBack(); assert.equal(frames.running, false);
  vm.advanceFrame(10000); assert.equal(vm.playerJumpX, x); vm.dismissExitConfirm(); frames.tick(1000);
  assert.equal(vm.score, 1); assert.equal(frames.running, false); vm.dispose();
});

test('jump aborts charging on background and stops completely after a miss', () => {
  const { vm, frames } = jumpFixture(); vm.beginCharge(); frames.tick(400); vm.onAppHidden();
  assert.equal(vm.isCharging, false); assert.equal(vm.chargeRatio, 0); vm.onAppShown();
  assert.equal(frames.running, false); vm.beginCharge(); vm.endCharge(); frames.tick(1000); frames.tick(520);
  assert.equal(vm.status, 'over'); assert.equal(frames.running, false); vm.dispose();
});

test('match3 generated boards stay playable for 500 seeds and optimized legal-swap search matches brute force', () => {
  const f = fixture(); const { Match3Rules } = f.rules('Match3'); const rules = new Match3Rules();
  for (let seed = 1; seed <= 500; seed++) {
    const board = rules.generateBoard(f.rng(seed)); assert.equal(rules.hasMatches(board), false);
    let brute = false;
    for (let r = 0; r < 8; r++) { for (let c = 0; c < 8; c++) {
      for (const [dr, dc] of [[1, 0], [0, 1]]) {
        if (r + dr < 8 && c + dc < 8) { brute ||= rules.hasMatches(rules.swap(board, r, c, r + dr, c + dc)); }
      }
    } }
    assert.equal(rules.hasLegalSwap(board), brute); assert.equal(brute, true);
  }
});

test('match3 degenerate random source cannot run an unbounded chain', () => {
  const f = fixture(); const { Match3Rules } = f.rules('Match3'); const rules = new Match3Rules();
  const rng = { next() { return 0; } }; const board = Array.from({ length: 8 }, () => Array(8).fill(0));
  const result = rules.resolveChain(board, rng);
  assert.ok(result.chainRounds <= 32); assert.equal(rules.hasMatches(result.board), false);
  assert.equal(rules.hasLegalSwap(result.board), true);
});

test('sudoku runs puzzle generation asynchronously and a newer request wins out-of-order completion', async () => {
  const f = fixture(); const vm = f.vm('SudokuViewModel', f.rng());
  const first = vm.newGameAsync(); assert.equal(vm.isGenerating, true); assert.equal(vm.board.length, 0);
  const second = vm.newGameAsync(); assert.equal(f.tasks[0].task.cancelled, true);
  const latest = f.tasks[1].task.callback(...f.tasks[1].task.args); f.tasks[1].resolve(latest); await second;
  assert.deepEqual(vm.board, latest); assert.equal(vm.isGenerating, false);
  f.tasks[0].resolve(Array(81).fill(9)); await first; assert.deepEqual(vm.board, latest); vm.dispose();
});

test('sudoku disposal and restart invalidate pending generation; failure permits retry', async () => {
  const f = fixture(); const vm = f.vm('SudokuViewModel', f.rng()); vm.newGame(); const board = vm.board.slice();
  const first = vm.newGameAsync(); vm.restartGame(); f.tasks[0].resolve(Array(81).fill(9)); await first;
  assert.deepEqual(vm.board, board); const second = vm.newGameAsync();
  f.tasks[1].reject(new Error('mock worker failed')); await second;
  assert.equal(vm.generationFailed, true); assert.equal(vm.isGenerating, false);
  const third = vm.newGameAsync(); assert.equal(vm.generationFailed, false); vm.dispose();
  f.tasks[2].resolve(Array(81).fill(9)); await third;
  assert.deepEqual(vm.board, board); assert.equal(vm.isGenerating, false);
});

test('clean persistence writes nothing, dirty updates debounce, pending flush is completed synchronously', async () => {
  const f = fixture(); const data = f.data(); data.init({}); data.flushNow(); assert.equal(f.store.writes, 0);
  data.incrementPlayCount('snake'); data.incrementPlayCount('snake'); data.updateHighScore('snake', 99);
  f.clock.advance(199); assert.equal(f.store.writes, 0); f.clock.advance(1);
  assert.equal(f.store.writes, 4); assert.equal(f.flushes.length, 1);
  data.flushNow(); assert.equal(f.store.writes, 4); assert.equal(f.store.synchronousFlushes, 1);
  f.flushes[0].resolve(); await Promise.resolve(); await Promise.resolve();
  data.flushNow(); assert.equal(f.store.synchronousFlushes, 1);
  data.setSetting('hapticsEnabled', true); assert.equal(f.store.synchronousFlushes, 1);
  data.setSetting('hapticsEnabled', false); assert.equal(f.store.writes, 8); assert.equal(f.store.synchronousFlushes, 2);
});

test('failed asynchronous persistence retries the dirty data', async () => {
  const f = fixture(); const data = f.data(); data.init({}); data.incrementPlayCount('snake'); f.clock.advance(200);
  f.flushes[0].reject(new Error('mock disk failure')); await Promise.resolve(); await Promise.resolve();
  data.flushNow(); assert.equal(f.store.writes, 8); assert.equal(f.store.synchronousFlushes, 1);
});

test('vector icons and the remaining bitmap retain small decoding dimensions; loading strings exist in all locales', () => {
  const media = path.join(root, 'entry/src/main/resources/base/media'); let total = 0; let count = 0;
  for (const name of fs.readdirSync(media)) {
    if (name !== 'play_mole.png') { continue; }
    const data = fs.readFileSync(path.join(media, name)); total += data.length; count++;
    const maximum = 512;
    assert.ok(data.readUInt32BE(16) <= maximum && data.readUInt32BE(20) <= maximum);
    assert.equal(data[25], 6, 'RGBA transparency must be retained');
  }
  assert.equal(count, 1); assert.ok(total < 512 * 1024);
  const games=fixture().data().getAllGames(); assert.equal(games.length,100);
  for (const theme of ['base','dark']) {
    let vectorBytes=0;
    for (const game of games) {
      const name=game.icon.replace('app.media.','');
      assert(!fs.existsSync(path.join(root,`entry/src/main/resources/${theme}/media/${name}.png`)));
      const svg=fs.readFileSync(path.join(root,`entry/src/main/resources/${theme}/media/${name}.svg`),'utf8');
      assert(svg.includes('viewBox="0 0 120 120"')); vectorBytes+=Buffer.byteLength(svg);
    }
    assert.ok(vectorBytes<1024*1024,'catalog icon resource budget');
  }
  for (const locale of ['base', 'zh_CN', 'en_US']) {
    const resources = JSON.parse(fs.readFileSync(path.join(root, `entry/src/main/resources/${locale}/element/string.json`)));
    for (const name of ['sudoku_generating', 'sudoku_generation_failed']) {
      assert.ok(resources.string.some(entry => entry.name === name && entry.value.length > 0));
    }
  }
});

function settingsTest(name, callback) { tests.push({ name: `Settings: ${name}`, callback }); }

settingsTest('old haptics-only preferences migrate without losing scores or history', () => {
  const f = fixture({ settings: '{"hapticsEnabled":false}', highScores: '{"snake":99}',
    playCounts: '{"snake":3}', recentGames: '["snake"]' });
  const data = f.data(); data.init({});
  assert.equal(data.getSetting('hapticsEnabled', true), false);
  assert.equal(data.getThemeMode(), 'system'); assert.equal(data.getDefaultDifficulty(), 'normal');
  assert.equal(data.getSetting('rememberDifficulty', false), false);
  assert.equal(data.getSetting('confirmExitEnabled', true), true);
  assert.equal(data.getGameById('snake').highScore, 99);
  assert.equal(data.getRecentlyPlayed()[0].id, 'snake');
});

settingsTest('settings and remembered difficulty survive a cold start', () => {
  const f = fixture(); const data = f.data(); data.init({});
  data.setTextSetting('themeMode', 'dark'); data.setTextSetting('defaultDifficulty', 'hard');
  data.setSetting('hapticsEnabled', false); data.setSetting('confirmExitEnabled', false);
  data.setSetting('rememberDifficulty', true); data.rememberGameDifficulty('snake', 'easy');
  const restarted = fixture(Object.fromEntries(f.values)).data(); restarted.init({});
  assert.equal(restarted.getThemeMode(), 'dark'); assert.equal(restarted.getDefaultDifficulty(), 'hard');
  assert.equal(restarted.getInitialDifficulty('snake'), 'easy');
  assert.equal(restarted.getInitialDifficulty('sudoku'), 'hard');
  assert.equal(restarted.getSetting('hapticsEnabled', true), false);
  assert.equal(restarted.getSetting('confirmExitEnabled', true), false);
});

settingsTest('malformed settings fall back to validated defaults', () => {
  const f = fixture({ settings: JSON.stringify({ hapticsEnabled: 'false', themeMode: 'invalid',
    defaultDifficulty: 'easy', rememberDifficulty: true, difficulty_snake: 'invalid' }) });
  const data = f.data(); data.init({});
  assert.equal(data.getSetting('hapticsEnabled', true), true);
  assert.equal(data.getThemeMode(), 'system'); assert.equal(data.getInitialDifficulty('snake'), 'easy');
  for (const settings of ['{broken', 'null']) {
    const broken = fixture({ settings }).data(); broken.init({});
    assert.equal(broken.getThemeMode(), 'system'); assert.equal(broken.getDefaultDifficulty(), 'normal');
  }
});

const difficultyGames = [['SnakeViewModel', 'snake'], ['TetrisViewModel', 'tetris'],
  ['Game2048ViewModel', '2048'], ['WhackMoleViewModel', 'whackmole'], ['MinesweeperViewModel', 'minesweeper'],
  ['SudokuViewModel', 'sudoku'], ['SlidePuzzleViewModel', 'slidepuzzle'], ['KlotskiViewModel', 'klotski'],
  ['GuessNumberViewModel', 'guessnumber'], ['MemoryCardViewModel', 'memorycard'], ['JumpJumpViewModel', 'jumpjump']];

settingsTest('all 11 supported games honor defaults, isolated memory and same-difficulty selections', () => {
  for (const [name, id] of difficultyGames) {
    const f = fixture(); const data = f.data(); data.init({});
    data.setTextSetting('defaultDifficulty', 'hard');
    const vm = f.vm(name, f.rng()); assert.equal(vm.difficulty, 'hard', name);
    data.setTextSetting('defaultDifficulty', 'easy'); assert.equal(vm.difficulty, 'hard', 'active game stays unchanged');
    data.setSetting('rememberDifficulty', true);
    vm.changeDifficulty('hard'); // Selecting the existing difficulty must still be remembered.
    assert.equal(f.vm(name, f.rng()).difficulty, 'hard', name);
    const otherId = id === 'snake' ? 'sudoku' : 'snake';
    assert.equal(data.getInitialDifficulty(otherId), 'easy');
    data.setSetting('rememberDifficulty', false); vm.changeDifficulty('normal');
    assert.equal(f.vm(name, f.rng()).difficulty, 'easy', name);
    data.setSetting('rememberDifficulty', true);
    assert.equal(data.getInitialDifficulty(id), 'hard', 'disabled memory does not overwrite saved selection');
    vm.dispose();
  }
});

settingsTest('all 13 games honor exit confirmation for toolbar and system back', () => {
  for (const name of difficultyGames.map(entry => entry[0]).concat(['BrickBreakerViewModel', 'Match3ViewModel'])) {
    const f = fixture(); const data = f.data(); data.init({}); const vm = f.vm(name, f.rng());
    vm.status = 'playing'; data.setSetting('confirmExitEnabled', false);
    assert.equal(vm.requestBack(), false, name); assert.equal(vm.onBackRequested(), false, name);
    assert.equal(vm.confirmExit, false);
    data.setSetting('confirmExitEnabled', true);
    assert.equal(vm.onBackRequested(), true, name); assert.equal(vm.confirmExit, true); vm.dispose();
  }
});

settingsTest('clearing play data keeps preferences and remains cleared after restart and debounce', () => {
  const f = fixture(); const data = f.data(); data.init({});
  data.setTextSetting('themeMode', 'dark'); data.setSetting('hapticsEnabled', false);
  data.incrementPlayCount('snake'); data.incrementPlayCount('sudoku'); data.updateHighScore('snake', 99);
  data.clearPlayData(); f.clock.advance(1000);
  assert.equal(data.getPlayedGameCount(), 0); assert.deepEqual(data.getRecentlyPlayed(), []);
  const restarted = fixture(Object.fromEntries(f.values)).data(); restarted.init({});
  assert.equal(restarted.getPlayedGameCount(), 0); assert.deepEqual(restarted.getRecentlyPlayed(), []);
  assert.ok(restarted.getAllGames().every(game => game.highScore === 0 && game.playCount === 0));
  assert.equal(restarted.getThemeMode(), 'dark'); assert.equal(restarted.getSetting('hapticsEnabled', true), false);
});

settingsTest('restoring preferences keeps scores and removes remembered difficulty after restart', () => {
  const f = fixture(); const data = f.data(); data.init({});
  data.incrementPlayCount('snake'); data.updateHighScore('snake', 99);
  data.setTextSetting('themeMode', 'dark'); data.setSetting('rememberDifficulty', true);
  data.rememberGameDifficulty('snake', 'hard'); data.setSetting('hapticsEnabled', false);
  data.resetSettings();
  const restarted = fixture(Object.fromEntries(f.values)).data(); restarted.init({});
  assert.equal(restarted.getThemeMode(), 'system'); assert.equal(restarted.getDefaultDifficulty(), 'normal');
  assert.equal(restarted.getSetting('hapticsEnabled', false), true);
  assert.equal(restarted.getSetting('confirmExitEnabled', false), true);
  assert.equal(restarted.getSetting('rememberDifficulty', true), false);
  assert.equal(restarted.getTextSetting('difficulty_snake', ''), '');
  assert.equal(restarted.getGameById('snake').highScore, 99);
  assert.equal(restarted.getRecentlyPlayed()[0].id, 'snake');
});

settingsTest('vibration switches off all feedback and works again after enabling', () => {
  const f = fixture(); const data = f.data(); const haptics = f.load('entry/src/main/ets/common/Haptics.ets').Haptics;
  data.setSetting('hapticsEnabled', false); haptics.tap(); haptics.success(); assert.equal(f.vibrations.length, 0);
  data.setSetting('hapticsEnabled', true); haptics.tap(); haptics.success(); assert.equal(f.vibrations.length, 2);
});

settingsTest('theme modes use native configuration and report application failure', () => {
  const theme = fixture().load('entry/src/main/ets/common/AppTheme.ets').AppTheme; const modes = [];
  const context = { setColorMode(mode) { modes.push(mode); } };
  assert.equal(theme.apply(context, 'system'), true);
  assert.equal(theme.apply(context, 'light'), true); assert.equal(theme.apply(context, 'dark'), true);
  assert.deepEqual(modes, [-1, 1, 0]);
  assert.equal(theme.apply({ setColorMode() { throw new Error('unavailable'); } }, 'dark'), false);
});

settingsTest('every settings string exists in all locales without duplicate resource names', () => {
  const source = ['pages/settings/SettingsPage', 'pages/settings/AboutPage', 'components/SettingsHeader',
    'components/SettingsChoice', 'components/SettingsSwitchRow', 'components/ProfileStatsCard', 'pages/home/ProfileTab']
    .map(file => fs.readFileSync(path.join(root, `entry/src/main/ets/${file}.ets`), 'utf8')).join('\n');
  const names = [...source.matchAll(/\$r\('app\.string\.([^']+)'\)/g)].map(match => match[1]);
  for (const locale of ['base', 'zh_CN', 'en_US']) {
    const entries = JSON.parse(fs.readFileSync(path.join(root, `entry/src/main/resources/${locale}/element/string.json`))).string;
    assert.equal(new Set(entries.map(entry => entry.name)).size, entries.length, locale);
    for (const name of names) { assert.ok(entries.some(entry => entry.name === name && entry.value.length > 0), `${locale}:${name}`); }
  }
});

module.exports = { fixture, Frames };

if (require.main === module) { (async () => {
  let failed = 0;
  for (const entry of tests) {
    try { await entry.callback(); }
    catch (error) { failed++; console.error(`FAIL ${entry.name}\n${error.stack}`); }
  }
  console.log(`${tests.length - failed}/${tests.length} passed (${tests.filter(t => t.name.startsWith('Performance:')).length} performance regressions, ${tests.filter(t => t.name.startsWith('Settings:')).length} settings regressions).`);
  process.exitCode = failed ? 1 : 0;
})(); }
