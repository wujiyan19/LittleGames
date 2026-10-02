const assert = require('node:assert/strict');
const { fixture, Frames } = require('./test-performance.cjs');
const tests = [];
const test = (name, run) => tests.push({ name, run });
const base = 'entry/src/main/ets/';
const equalData = (left, right) => assert.deepEqual(JSON.parse(JSON.stringify(left)), JSON.parse(JSON.stringify(right)));
const games = ['Snake', 'Tetris', 'Game2048', 'WhackMole', 'Minesweeper', 'Sudoku',
  'SlidePuzzle', 'Klotski', 'GuessNumber', 'MemoryCard', 'JumpJump', 'BrickBreaker', 'Match3'];

function game(name, difficulty = 'normal') {
  const f = fixture();
  const vm = name === 'JumpJump' ? f.vm(name + 'ViewModel') : f.vm(name + 'ViewModel', f.rng(7));
  if ('difficulty' in vm) { vm.difficulty = difficulty; }
  const frames = new Frames();
  if (vm.setFrameLoop) { vm.setFrameLoop(frames); }
  if (name === 'Sudoku') { vm.newGame(); } else { vm.startGame(); }
  return { f, vm, frames };
}

for (const name of games) {
  for (const difficulty of ['easy', 'normal', 'hard']) {
    test(`${name}/${difficulty}: restores complete state without starting another round`, () => {
      const source = game(name, difficulty);
      const target = game(name, 'normal');
      const id = source.vm.continuationGameId();
      const count = target.f.data().getGameById(id).playCount;
      const payload = source.vm.exportContinuation();
      assert.equal(target.vm.importContinuation(payload), true);
      const expected = JSON.parse(payload);
      const actual = JSON.parse(target.vm.exportContinuation());
      if (['WhackMole', 'Tetris'].includes(name)) { expected.status = 'paused'; }
      assert.deepEqual(actual, expected);
      assert.equal(target.f.data().getGameById(id).playCount, count);
      assert.equal(Buffer.byteLength(payload), Buffer.byteLength(source.vm.exportContinuation()));
      source.vm.dispose(); target.vm.dispose();
    });
  }
  test(`${name}: rejects malformed data before changing the target`, () => {
    const target = game(name);
    const before = target.vm.exportContinuation();
    for (const invalid of ['null', '{}', '{bad', JSON.stringify({ version: 2 }), 'x'.repeat(65537)]) {
      assert.equal(target.vm.importContinuation(invalid), false);
      assert.equal(target.vm.exportContinuation(), before);
    }
    const malformed = JSON.parse(before);
    if ('board' in malformed) { malformed.board = []; }
    else if ('snake' in malformed) { malformed.snake[0].x = 99; }
    else if ('holes' in malformed) { malformed.holes = []; }
    else if ('secret' in malformed) { malformed.secret = 'xyz'; }
    else if ('cards' in malformed) { malformed.cards = []; }
    else if ('blocks' in malformed) { malformed.blocks[1].x = malformed.blocks[0].x; }
    else if ('ball' in malformed) { malformed.ball.vx = 'bad'; }
    else if ('platforms' in malformed) { malformed.currentIndex = 99; }
    assert.equal(target.vm.importContinuation(JSON.stringify(malformed)), false);
    assert.equal(target.vm.exportContinuation(), before);
    target.vm.dispose();
  });
}

test('Snake: keeps direction, pending turn and occupancy; resumes only on player action', () => {
  const source = game('Snake'); source.vm.turnDown(); source.vm.stepOnce(); source.vm.turnLeft();
  const target = game('Snake'); const payload = JSON.parse(source.vm.exportContinuation());
  assert.equal(target.vm.importContinuation(JSON.stringify(payload)), true);
  assert.equal(target.vm.status, 'paused');
  target.vm.onAppShown(); assert.equal(target.vm.status, 'paused');
  target.f.clock.advance(5000); equalData(target.vm.snake, source.vm.snake);
  target.vm.togglePause(); target.vm.stepOnce();
  source.vm.stepOnce(); equalData(target.vm.snake, source.vm.snake);
});

test('Tetris: preserves the falling piece and frozen board across the pause', () => {
  const source = game('Tetris'); source.vm.drop(); source.vm.moveLeft();
  const target = game('Tetris'); assert.equal(target.vm.importContinuation(source.vm.exportContinuation()), true);
  equalData(target.vm.piece, source.vm.piece);
  target.vm.togglePause(); target.vm.drop(); source.vm.drop();
  equalData(target.vm.piece, source.vm.piece); assert.deepEqual(target.vm.board, source.vm.board);
});

test('WhackMole: preserves the partial second and excludes transfer time', () => {
  const source = game('WhackMole'); source.f.clock.advance(650);
  const target = game('WhackMole'); assert.equal(target.vm.importContinuation(source.vm.exportContinuation()), true);
  const remaining = target.vm.timeLeft; target.f.clock.advance(5000); assert.equal(target.vm.timeLeft, remaining);
  target.vm.togglePause(); target.f.clock.advance(349); assert.equal(target.vm.timeLeft, remaining);
  target.f.clock.advance(1); assert.equal(target.vm.timeLeft, remaining - 1);
  assert.equal(source.vm.status, 'playing');
});

test('Minesweeper: keeps first-click safety, flags, mines and elapsed seconds', () => {
  const source = game('Minesweeper'); source.vm.reveal(4, 4); source.vm.toggleFlag(0, 0); source.f.clock.advance(2400);
  const target = game('Minesweeper'); assert.equal(target.vm.importContinuation(source.vm.exportContinuation()), true);
  assert.deepEqual(target.vm.board, source.vm.board); assert.deepEqual(target.vm.flagged, source.vm.flagged);
  assert.equal(target.vm.elapsed, 2); target.f.clock.advance(1000); assert.equal(target.vm.elapsed, 3);
  assert.equal(target.vm.minesPlaced, true);
});

test('Sudoku: preserves fixed cells, edited board and restart puzzle; refuses generation in flight', () => {
  const source = game('Sudoku'); const index = source.vm.board.findIndex(value => value === 0);
  source.vm.selectCell(Math.floor(index / 9), index % 9); source.vm.setNumber(2);
  const target = game('Sudoku'); assert.equal(target.vm.importContinuation(source.vm.exportContinuation()), true);
  assert.deepEqual(target.vm.board, source.vm.board); assert.equal(target.vm.isFixed(0, 0), source.vm.isFixed(0, 0));
  target.vm.restartGame(); assert.deepEqual(target.vm.board, source.vm.puzzle);
  source.vm.newGameAsync(); assert.throws(() => source.vm.exportContinuation()); source.vm.dispose();
});

test('MemoryCard: recreates observed cards and finishes a pending pair without locking forever', () => {
  const source = game('MemoryCard'); source.vm.flipCard(0); source.vm.flipCard(1);
  const target = game('MemoryCard'); assert.equal(target.vm.importContinuation(source.vm.exportContinuation()), true);
  assert.equal(target.vm.locked, true); target.f.clock.advance(800);
  assert.equal(target.vm.locked, false); assert.equal(target.vm.flippedIdxs.length, 0);
  source.f.clock.advance(800); equalData(target.vm.cards, source.vm.cards);
});

test('GuessNumber: keeps input, secret and ordered history for the next guess', () => {
  const source = game('GuessNumber'); for (const digit of '0123') { source.vm.pushDigit(digit); }
  source.vm.submit(); source.vm.pushDigit('5');
  const target = game('GuessNumber'); assert.equal(target.vm.importContinuation(source.vm.exportContinuation()), true);
  assert.equal(target.vm.input, '5'); assert.equal(target.vm.secret, source.vm.secret);
  equalData(target.vm.records, source.vm.records);
});

test('BrickBreaker: keeps ball velocity, destroyed bricks and paddle; resumes physics on demand', () => {
  const source = game('BrickBreaker'); source.vm.launchBall(); source.frames.tick(90);
  const target = game('BrickBreaker'); assert.equal(target.vm.importContinuation(source.vm.exportContinuation()), true);
  assert.equal(target.frames.running, false); assert.equal(target.vm.status, 'paused');
  target.vm.togglePause(); target.vm.stepOnce(); source.vm.stepOnce();
  equalData(target.vm.ball, source.vm.ball); assert.deepEqual(target.vm.bricksAlive, source.vm.bricksAlive);
});

test('BrickBreaker: carries level-transition state to the next layout', () => {
  const source = game('BrickBreaker'); source.vm.level = 2; source.vm.levelClearMsg = true; source.vm.status = 'paused';
  const target = game('BrickBreaker'); assert.equal(target.vm.importContinuation(source.vm.exportContinuation()), true);
  target.f.clock.advance(2000); assert.equal(target.vm.levelClearMsg, false);
  assert.equal(target.vm.status, 'playing'); assert.equal(target.vm.level, 2);
});

test('JumpJump: resumes a mid-air trajectory and settles the same landing result', () => {
  const source = game('JumpJump'); source.vm.beginCharge(); source.frames.tick(600); source.vm.endCharge(); source.frames.tick(60);
  const target = game('JumpJump'); assert.equal(target.vm.importContinuation(source.vm.exportContinuation()), true);
  assert.equal(target.vm.isJumping, true); assert.equal(target.vm.playerJumpX, source.vm.playerJumpX);
  source.frames.tick(1000); target.frames.tick(1000);
  assert.equal(target.vm.score, source.vm.score); assert.equal(target.vm.currentIndex, source.vm.currentIndex);
});

test('Continuation: validates routes, versions, limits and game/route pairing', () => {
  const f = fixture(); const app = f.load(base + 'common/AppContinuation.ets').AppContinuation;
  const state = { version: 1, tab: 1, paths: [], gameId: '', gamePayload: '' };
  for (const delta of [{ version: 2 }, { tab: 3 }, { paths: ['MissingPage'] }, { paths: ['SettingsPage', 'SnakeGamePage'] },
    { paths: ['SnakeGamePage'], gameId: '2048', gamePayload: '{}' }, { gameId: 'snake' }]) {
    assert.equal(app.receive(JSON.stringify({ ...state, ...delta })), false);
  }
  assert.equal(app.receive('x'.repeat(20001)), false); assert.equal(app.receive('null'), false);
  assert.equal(app.receive(JSON.stringify(state)), true); assert.equal(app.hasPending(), true);
});

test('Continuation: cold start queues once; warm start invokes navigation restoration directly', () => {
  const f = fixture(); const app = f.load(base + 'common/AppContinuation.ets').AppContinuation;
  const source = game('SlidePuzzle', 'hard');
  const state = { version: 1, tab: 2, paths: ['SlidePuzzlePage'], gameId: 'slidepuzzle', gamePayload: source.vm.exportContinuation() };
  assert.equal(app.receive(JSON.stringify(state)), true);
  const restored = []; const active = [];
  app.setStateHandler(value => active.push(value));
  app.connect(() => ({ tab: 2, paths: [] }), incoming => restored.push(incoming));
  assert.deepEqual(restored, [state]); assert.equal(app.hasPending(), false);
  assert.equal(app.receive(JSON.stringify({ ...state, tab: 1 })), true);
  assert.equal(restored.length, 2); assert.equal(restored[1].tab, 1);
  app.disconnect(); assert.deepEqual(active, [false, true, false]);
});

test('Continuation: game snapshots fit Want and exporting keeps the source alive', () => {
  for (const name of games) {
    const source = game(name, 'hard'); const f = source.f;
    const app = f.load(base + 'common/AppContinuation.ets').AppContinuation;
    const bus = f.load(base + 'common/GameLifecycleBus.ets').GameLifecycleBus;
    const routes = f.load(base + 'router/GameRouteRegistry.ets').GameRoutes;
    bus.attach(source.vm);
    const id = source.vm.continuationGameId();
    app.connect(() => ({ tab: 1, paths: [routes.routeName(id)] }), () => {});
    const count = f.clock.count(); const before = source.vm.exportContinuation(); const payload = app.capture();
    assert.ok(Buffer.byteLength(payload) < 100000); assert.equal(f.clock.count(), count);
    assert.equal(source.vm.exportContinuation(), before); assert.equal(JSON.parse(payload).gameId, id);
    app.disconnect(); source.vm.dispose();
  }
});

test('Continuation: pending state is consumed once and never restored into a different game', () => {
  const f = fixture(); const transfer = f.load(base + 'common/GameSessionTransfer.ets').GameSessionTransfer;
  const target = game('SlidePuzzle', 'hard'); const payload = target.vm.exportContinuation();
  transfer.prepare('slidepuzzle', payload); assert.equal(transfer.restore(game('Snake').vm), false);
  assert.equal(transfer.restore(target.vm), true); assert.equal(transfer.restore(target.vm), false);
  let failures = 0; transfer.setFailureHandler(() => failures++); transfer.prepare('slidepuzzle', '{}');
  assert.equal(transfer.restore(target.vm), false); assert.equal(failures, 1);
});

test('Continuation: preserves a higher record already saved on the target', () => {
  for (const name of ['Snake', 'Tetris', 'Game2048', 'WhackMole', 'BrickBreaker', 'JumpJump', 'Match3']) {
    const source = game(name); const target = game(name);
    const id = target.vm.continuationGameId(); target.f.data().updateHighScore(id, 9999);
    assert.equal(target.vm.importContinuation(source.vm.exportContinuation()), true);
    assert.equal(target.vm.highScore, 9999); assert.equal(target.f.data().getGameById(id).highScore, 9999);
  }
});

test('2048, slide puzzle and Match3 retain an edited board, moves and selection', () => {
  const a = game('Game2048'); a.vm.board = [[2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]];
  a.vm.swipeLeft(); a.vm.swipeDown(); a.vm.swipeRight();
  const b = game('Game2048'); assert.equal(b.vm.importContinuation(a.vm.exportContinuation()), true);
  assert.deepEqual(b.vm.board, a.vm.board); assert.equal(b.vm.score, a.vm.score); assert.ok(a.vm.score > 0);
  const slide = game('SlidePuzzle', 'hard'); const blank = slide.vm.board.indexOf(0);
  const row = Math.floor(blank / 5); const col = blank % 5;
  slide.vm.tapCell(row, col > 0 ? col - 1 : col + 1);
  const slideTarget = game('SlidePuzzle'); assert.equal(slideTarget.vm.importContinuation(slide.vm.exportContinuation()), true);
  assert.equal(slideTarget.vm.steps, 1); assert.deepEqual(slideTarget.vm.board, slide.vm.board);
  const match = game('Match3'); match.vm.onGemClick(3, 4);
  const matchTarget = game('Match3'); assert.equal(matchTarget.vm.importContinuation(match.vm.exportContinuation()), true);
  assert.equal(matchTarget.vm.isSelected(3, 4), true); assert.equal(matchTarget.vm.movesLeft, match.vm.movesLeft);
});

test('Continuation: rejects another transfer while restoration is in progress', () => {
  const f = fixture(); const app = f.load(base + 'common/AppContinuation.ets').AppContinuation;
  const states = []; app.setStateHandler(active => states.push(active));
  app.connect(() => ({ tab: 0, paths: [] }), () => {});
  app.setRestoring(true); assert.throws(() => app.capture());
  app.setRestoring(false); assert.equal(JSON.parse(app.capture()).tab, 0);
  assert.deepEqual(states, [false, true, false, true]);
});

test('HDS immersive material follows device support and enables native thermal control', () => {
  for (const supported of [true, false, 'error']) {
    const f = fixture();
    f.native['@kit.UIDesignKit'] = { hdsMaterial: {
      MaterialType: { ADAPTIVE: 100, IMMERSIVE: 101 }, MaterialLevel: { ADAPTIVE: 10 },
      getSystemMaterialTypes() { if (supported === 'error') { throw new Error('Unavailable'); } return supported ? [101] : [0, 100]; }
    } };
    const style = f.load(base + 'common/ImmersiveLight.ets').ImmersiveLight.floatingTabs();
    assert.equal(style.systemMaterialEffect.materialType, supported === true ? 101 : 100);
    assert.equal(style.systemMaterialEffect.materialLevel, 10); assert.equal(style.thermoCtrl, true);
    assert.equal(style.barBottomMargin, 'app.float.home_tab_bottom_margin');
  }
});

test('JumpJump: rebases a mid-air jump to a different target window without changing the landing', () => {
  const source = game('JumpJump'); source.vm.beginCharge(); source.frames.tick(600); source.vm.endCharge(); source.frames.tick(60);
  const target = game('JumpJump');
  target.f.load(base + 'common/ScreenUtils.ets').ScreenUtils.updateFromWindow({
    getWindowProperties() { return { windowRect: { width: 800, height: 1000 } }; }
  });
  assert.equal(target.vm.importContinuation(source.vm.exportContinuation()), true);
  assert.equal(target.vm.platforms[target.vm.currentIndex].centerX, 144);
  assert.equal(target.vm.playerX - target.vm.platforms[target.vm.currentIndex].centerX,
    source.vm.playerX - source.vm.platforms[source.vm.currentIndex].centerX);
  source.frames.tick(1000); target.frames.tick(1000);
  assert.equal(target.vm.score, source.vm.score); assert.equal(target.vm.currentIndex, source.vm.currentIndex);
});

test('UIAbility: native handoff captures data and handles both cold and warm continuation launches', () => {
  const source = game('Game2048'); const f = source.f;
  const ability = f.native['@kit.AbilityKit'];
  ability.UIAbility = class { constructor() { this.context = { setMissionContinueState() { return Promise.resolve(); } }; } };
  ability.AbilityConstant = { LaunchReason: { CONTINUATION: 1 }, ContinueState: { ACTIVE: 1, INACTIVE: 0 },
    OnContinueResult: { AGREE: 0, REJECT: 1 } };
  ability.wantConstant = { Params: { SUPPORT_CONTINUE_PAGE_STACK_KEY: 'ohos.extra.param.key.supportContinuePageStack' } };
  const app = f.load(base + 'common/AppContinuation.ets').AppContinuation;
  f.load(base + 'common/GameLifecycleBus.ets').GameLifecycleBus.attach(source.vm);
  const restored = []; app.connect(() => ({ tab: 1, paths: ['Game2048Page'] }), state => restored.push(state));
  const EntryAbility = f.load(base + 'entryability/EntryAbility.ets').default;
  const entry = new EntryAbility(); const parameters = {};
  assert.equal(entry.onContinue(parameters), ability.AbilityConstant.OnContinueResult.AGREE);
  assert.equal(parameters[ability.wantConstant.Params.SUPPORT_CONTINUE_PAGE_STACK_KEY], false);
  const want = { parameters };
  entry.onNewWant(want, { launchReason: 0 }); assert.equal(restored.length, 0);
  entry.onNewWant(want, { launchReason: 1 }); assert.equal(restored.length, 1);
  app.disconnect(); entry.onCreate(want, { launchReason: 1 }); assert.equal(app.hasPending(), true);
  app.connect(() => ({ tab: 1, paths: ['Game2048Page'] }), state => restored.push(state));
  assert.equal(restored.length, 2); assert.equal(restored[1].gamePayload, source.vm.exportContinuation());
  app.setRestoring(true); assert.equal(entry.onContinue({}), ability.AbilityConstant.OnContinueResult.REJECT);
  entry.onDestroy(); assert.equal(app.hasPending(), false);
});

let failed = 0;
for (const entry of tests) {
  try { entry.run(); }
  catch (error) { failed++; console.error(`FAIL ${entry.name}\n${error.stack}`); }
}
console.log(`${tests.length - failed}/${tests.length} continuation regressions passed.`);
process.exitCode = failed ? 1 : 0;
