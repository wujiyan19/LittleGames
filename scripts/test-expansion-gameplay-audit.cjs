const assert = require('node:assert/strict');
const { fixture, Frames } = require('./test-performance.cjs');

const cases = [];
const test = (name, run) => cases.push({ name, run });
const actionIds = ['platformer', 'grapple', 'flappy', 'fruitslice', 'rollingball', 'shooter', 'tanks', 'fortress', 'survival', 'backpack'];
const adventureIds = ['runner', 'blackhole', 'fisheat', 'sokoban', 'pipes', 'differences'];
const arcadeIds = ['roomdefense', 'basketball', 'rhythm', 'restaurant'];
const physicsIds = ['bubbleshooter', 'fruitmerge'];
const sportsIds = ['billiards', 'penalty', 'pingpong', 'bowling', 'golf', 'drift', 'hillclimb', 'airhockey', 'tug', 'dots'];
const auditedIds = [...actionIds, ...adventureIds, ...arcadeIds, ...physicsIds, ...sportsIds];

function activate(vm, id) {
  vm.activate();
  if (['blackhole', 'fisheat', 'bubbleshooter', 'fruitmerge', 'basketball', 'billiards', 'golf', 'bowling', 'penalty'].includes(id)) vm.aim(260, 145);
  if (id === 'platformer') { vm.tap(1); vm.tap(2); }
  if (id === 'grapple') vm.tap(0);
  if (id === 'flappy') vm.tap(0);
  if (id === 'hillclimb') vm.tap(0);
  if (['rollingball', 'shooter', 'tanks', 'fortress', 'survival'].includes(id)) vm.aim(220, 330);
  if (id === 'backpack') { vm.choose(0); vm.tap(0); }
  if (id === 'differences') vm.tap(vm.state.target[0]);
  if (['sokoban', 'pipes', 'tug', 'dots'].includes(id)) vm.tap(0);
}

for (const id of auditedIds) for (const level of [0, 1, 2]) test(`${id}/${level}: pause, background, exit and restart keep one coherent session`, () => {
  const f = fixture();
  const frames = new Frames();
  const vm = f.vm('ExpansionViewModel');
  // Lifecycle assertions require a repeatable, non-terminal opening after activate().
  vm.model = new (f.rules('Expansion').ExpansionModel)(f.rng(8));
  const { GameDifficulty } = f.load('entry/src/main/ets/common/GameConstants.ets');
  vm.init(id, frames);
  vm.difficulty = [GameDifficulty.EASY, GameDifficulty.NORMAL, GameDifficulty.HARD][level];
  vm.startGame();
  const initial = vm.exportContinuation();
  assert.equal(vm.state.level, level);
  assert.equal(frames.running, false);
  activate(vm, id);
  frames.tick(96);
  assert.equal(vm.state.outcome, 0);
  assert.equal(frames.running, vm.realtime() && vm.state.phase === 1);
  vm.setDragging(true);
  vm.togglePause();
  assert.equal(vm.dragging, false);
  assert.equal(frames.running, false);
  const paused = vm.exportContinuation();
  frames.tick(96); vm.advance(96); vm.tap(0); vm.aim(180, 230); vm.choose(0); vm.action(); vm.undo();
  assert.equal(vm.exportContinuation(), paused);
  vm.togglePause();
  assert.equal(frames.running, vm.realtime() && vm.state.phase === 1);
  vm.onAppHidden();
  assert.equal(frames.running, false);
  const hidden = vm.exportContinuation();
  vm.advance(96); vm.tap(0); vm.aim(180, 230);
  assert.equal(vm.exportContinuation(), hidden);
  vm.onAppShown();
  assert.equal(frames.running, vm.realtime() && vm.state.phase === 1);
  assert.equal(vm.requestBack(), true);
  assert.equal(frames.running, false);
  const confirming = vm.exportContinuation();
  vm.advance(96); vm.tap(0); vm.aim(180, 230);
  assert.equal(vm.exportContinuation(), confirming);
  vm.dismissExitConfirm();
  assert.equal(frames.running, vm.realtime() && vm.state.phase === 1);
  vm.startGame();
  assert.equal(frames.running, false);
  assert.equal(vm.state.id, id);
  assert.equal(vm.state.level, level);
  assert.equal(vm.state.time, 0);
  assert.equal(vm.state.moves, 0);
  assert.equal(vm.state.outcome, 0);
  assert.equal(vm.confirmExit, false);
  assert.equal(vm.paused, false);
  assert.equal(vm.canUndo, false);
  assert.equal(vm.dragging, false);
  assert.equal(JSON.parse(initial).state.goal, vm.state.goal);
  assert.deepEqual(vm.worldPieces.map(p => p.id), vm.state.pieces.filter(p => p.alive).map(p => p.id));
  vm.dispose();
  assert.equal(frames.disposed, true);
  const disposed = vm.exportContinuation();
  vm.advance(96); vm.tap(0); vm.aim(180, 230);
  assert.equal(vm.exportContinuation(), disposed);
});

const movingKinds = { runner: 7, roomdefense: 15, basketball: 17, rhythm: 18, restaurant: 19 };
for (const id of ['bubbleshooter', 'fruitmerge', 'runner', 'blackhole', 'fisheat', 'roomdefense', 'basketball', 'rhythm', 'restaurant']) test(`${id}: retained render identity follows the next snapshot`, () => {
  const f = fixture();
  const vm = f.vm('ExpansionViewModel');
  vm.init(id); vm.startGame(); activate(vm, id); vm.advance(96);
  const retained = movingKinds[id] ? vm.worldPieces.find(p => p.piece.kind === movingKinds[id]) : vm.worldPieces[0];
  assert(retained);
  const oldPiece = retained.piece;
  const render = () => [retained.piece.x, retained.piece.y, retained.piece.r, retained.piece.age];
  const before = render();
  for (let i = 0; i < (id === 'restaurant' ? 10 : 1); i++) vm.advance(96);
  const current = vm.worldPieces.find(p => p.id === retained.id);
  assert.equal(current, retained);
  assert.notEqual(retained.piece, oldPiece);
  assert.notDeepEqual(render(), before);
  assert.deepEqual(retained.piece, vm.state.pieces.find(p => p.id === retained.id));
  assert.deepEqual([oldPiece.x, oldPiece.y, oldPiece.r, oldPiece.age], before);
  vm.dispose();
});

for (const level of [0, 1, 2]) for (const bombFirst of [true, false]) test(`fruitslice/${level}: a bomb and the winning fruit in one stroke always fail (${bombFirst ? 'bomb first' : 'fruit first'})`, () => {
  const f = fixture();
  const { ExpansionModel } = f.rules('Expansion');
  const { ExpansionPiece } = f.load('entry/src/main/ets/model/game/ExpansionState.ets');
  const m = new ExpansionModel(f.rng(8));
  m.start('fruitslice', level); m.activate();
  m.state.moves = m.state.goal - 1; m.state.target = [100, 200];
  const bomb = new ExpansionPiece(); bomb.id = m.state.serial++; bomb.kind = 31; bomb.x = 150; bomb.y = 200; bomb.r = 20;
  const fruit = new ExpansionPiece(); fruit.id = m.state.serial++; fruit.kind = 30; fruit.x = 250; fruit.y = 200; fruit.r = 20;
  m.state.pieces = bombFirst ? [bomb, fruit] : [fruit, bomb];
  m.aim(300, 200);
  assert.equal(m.state.moves, m.state.goal);
  assert.equal(m.state.score, 50);
  assert.equal(m.state.outcome, 2);
  assert.equal(m.state.pieces.length, 0);
  assert(m.valid(m.state));
  const finished = JSON.stringify(m.state);
  m.aim(150, 200); m.tap(0); m.activate(); m.step(0.008);
  assert.equal(JSON.stringify(m.state), finished);
});

test('fruitslice: the final fruit without a bomb still wins', () => {
  const f = fixture();
  const { ExpansionModel } = f.rules('Expansion');
  const { ExpansionPiece } = f.load('entry/src/main/ets/model/game/ExpansionState.ets');
  const m = new ExpansionModel(f.rng(8));
  m.start('fruitslice', 1); m.activate(); m.state.moves = m.state.goal - 1;
  const fruit = new ExpansionPiece(); fruit.id = m.state.serial++; fruit.kind = 30; fruit.x = 180; fruit.y = 230; fruit.r = 20;
  m.state.pieces = [fruit]; m.aim(180, 230);
  assert.equal(m.state.outcome, 1);
  assert.equal(m.state.pieces.length, 0);
  assert(m.valid(m.state));
});

for (const level of [0, 1, 2]) for (const bigRadius of [16, 18]) for (const bigFirst of [true, false]) test(`fisheat/${level}: growth and a fatal contact in one frame cannot override a loss (radius ${bigRadius}, ${bigFirst ? 'big first' : 'small first'})`, () => {
  const f = fixture();
  const { ExpansionModel } = f.rules('Expansion');
  const { ExpansionPiece } = f.load('entry/src/main/ets/model/game/ExpansionState.ets');
  const m = new ExpansionModel(f.rng(8));
  m.start('fisheat', level); m.aim(180, 230); m.state.moves = m.state.goal - 1;
  const player = m.state.pieces[0];
  const small = new ExpansionPiece(); small.id = m.state.serial++; small.kind = 11; small.r = 8; small.x = player.x; small.y = player.y;
  const big = new ExpansionPiece(); big.id = m.state.serial++; big.kind = 11; big.r = bigRadius; big.x = player.x; big.y = player.y;
  m.state.pieces = [player, ...(bigFirst ? [big, small] : [small, big])];
  assert(m.valid(m.state));
  m.step(0.008);
  assert.equal(m.state.moves, m.state.goal);
  assert.equal(m.state.score, 80);
  assert.equal(player.r, 14.7);
  assert.equal(m.state.outcome, 2);
  assert(m.valid(m.state));
  assert(!m.state.pieces.some(p => p.id === small.id));
  assert(m.state.pieces.some(p => p.id === big.id));
  const finished = JSON.stringify(m.state);
  m.aim(150, 200); m.tap(0); m.activate(); m.step(0.008);
  assert.equal(JSON.stringify(m.state), finished);
});

test('fisheat: growth applies to a later frame and the final safe bite still wins', () => {
  const f = fixture();
  const { ExpansionModel } = f.rules('Expansion');
  const { ExpansionPiece } = f.load('entry/src/main/ets/model/game/ExpansionState.ets');
  const m = new ExpansionModel(f.rng(8)); m.start('fisheat', 1); m.aim(180, 230);
  const player = m.state.pieces[0];
  const small = new ExpansionPiece(); small.id = m.state.serial++; small.kind = 11; small.r = 8; small.x = player.x; small.y = player.y;
  const later = new ExpansionPiece(); later.id = m.state.serial++; later.kind = 11; later.r = 16; later.x = 280; later.y = player.y;
  m.state.pieces = [player, small, later];
  m.step(0.008); assert.equal(m.state.moves, 1); assert.equal(player.r, 14.7); assert.equal(m.state.outcome, 0);
  later.x = player.x; later.y = player.y; m.state.moves = m.state.goal - 1;
  m.step(0.008); assert.equal(m.state.moves, m.state.goal); assert.equal(m.state.outcome, 1); assert(m.valid(m.state));
});

test('fisheat: a terminal 8 ms frame publishes growth and loss before the frame source stops', () => {
  const f = fixture();
  const { ExpansionModel } = f.rules('Expansion');
  const { ExpansionPiece } = f.load('entry/src/main/ets/model/game/ExpansionState.ets');
  const m = new ExpansionModel(f.rng(8)); m.start('fisheat', 1); m.aim(180, 230); m.state.moves = m.state.goal - 1;
  const player = m.state.pieces[0];
  const small = new ExpansionPiece(); small.id = m.state.serial++; small.kind = 11; small.r = 8; small.x = player.x; small.y = player.y;
  const big = new ExpansionPiece(); big.id = m.state.serial++; big.kind = 11; big.r = 16; big.x = player.x; big.y = player.y;
  m.state.pieces = [player, small, big];
  const frames = new Frames(); const vm = f.vm('ExpansionViewModel'); vm.init('fisheat', frames);
  assert(vm.importContinuation(JSON.stringify({ version: 1, state: m.state, recorded: false, paused: false })));
  vm.togglePause(); assert(frames.running);
  const retained = vm.worldPieces[0]; const oldPiece = retained.piece;
  frames.tick(8);
  assert.equal(vm.state.outcome, 2); assert(vm.isFinished); assert.equal(frames.running, false);
  assert.equal(vm.worldPieces[0], retained); assert.notEqual(retained.piece, oldPiece); assert.equal(oldPiece.r, 14); assert.equal(retained.piece.r, 14.7);
  assert.deepEqual(retained.piece, vm.state.pieces[0]); assert(!vm.worldPieces.some(p => p.id === small.id));
  const finished = vm.exportContinuation(); frames.tick(96); vm.advance(96); assert.equal(vm.exportContinuation(), finished); vm.dispose();
});

for (const level of [0, 1, 2]) test(`hillclimb/${level}: crossing the finish during a fatal landing keeps the loss`, () => {
  const f = fixture(); const { ExpansionModel } = f.rules('Expansion');
  const m = new ExpansionModel(f.rng(8)); m.start('hillclimb', level); m.activate(); m.tap(0);
  const car = m.state.pieces[0]; car.x = m.state.goal - 0.1; car.y = m.sports.terrain(car.x) - 18; car.vx = 100; car.vy = 400;
  assert(m.valid(m.state));
  m.step(0.008);
  assert(car.x >= m.state.goal); assert.equal(car.vy, 0); assert.equal(m.state.outcome, 2); assert.equal(m.state.score, Math.floor(car.x)); assert(m.valid(m.state));
  const finished = JSON.stringify(m.state); m.tap(0); m.aim(180, 230); m.activate(); m.step(0.008); assert.equal(JSON.stringify(m.state), finished);
});

test('hillclimb: a safe landing across the finish still receives the victory bonus', () => {
  const f = fixture(); const { ExpansionModel } = f.rules('Expansion');
  const m = new ExpansionModel(f.rng(8)); m.start('hillclimb', 1); m.activate(); m.tap(0);
  const car = m.state.pieces[0]; car.x = m.state.goal - 0.1; car.y = m.sports.terrain(car.x) - 18; car.vx = 100; car.vy = 200;
  assert(m.valid(m.state)); m.step(0.008);
  assert(car.x >= m.state.goal); assert.equal(m.state.outcome, 1); assert.equal(m.state.score, Math.floor(car.x) + 500); assert(m.valid(m.state));
});

test('fisheat: real aim input updates facing and vertical motion preserves the last horizontal direction', () => {
  const f = fixture(); const { ExpansionModel } = f.rules('Expansion');
  const m = new ExpansionModel(f.rng(8)); m.start('fisheat', 1);
  const player = m.state.pieces[0]; m.aim(60, 230); m.step(0.008);
  assert(player.x < 180); assert(player.vx < 0);
  const leftVelocity = player.vx; const beforeY = player.y;
  m.aim(player.x, 60); m.step(0.008); assert(player.y < beforeY); assert.equal(player.vx, leftVelocity);
  const beforeX = player.x; m.aim(300, player.y); m.step(0.008); assert(player.x > beforeX); assert(player.vx > 0); assert(m.valid(m.state));
});

test('fisheat: retained render snapshot exposes left and right facing after real aim input', () => {
  const f = fixture(); const vm = f.vm('ExpansionViewModel'); vm.init('fisheat'); vm.startGame();
  const retained = vm.worldPieces[0]; vm.aim(60, 230); vm.advance(32);
  assert.equal(vm.worldPieces[0], retained); assert(retained.piece.vx < 0);
  vm.aim(300, 230); vm.advance(32);
  assert.equal(vm.worldPieces[0], retained); assert(retained.piece.vx > 0); assert.deepEqual(retained.piece, vm.state.pieces[0]); vm.dispose();
});

for (const id of ['runner', 'blackhole', 'fisheat', 'roomdefense', 'basketball', 'rhythm', 'restaurant', 'bubbleshooter', 'fruitmerge']) for (const level of [0, 1, 2]) test(`${id}/${level}: a generated complete game reaches its goal through actual controls`, () => {
  const f = fixture(); const { ExpansionModel } = f.rules('Expansion');
  // Fixed sources exercise generated goals with repeatable edible fish, bubble colors,
  // and falling fruit tiers. Rules and positions are never modified by the controller.
  const random = ['fisheat', 'bubbleshooter'].includes(id) ? { next: () => 0 } : id === 'fruitmerge' ? { next: () => 0.99999 } : f.rng(8);
  const m = new ExpansionModel(random); m.start(id, level); m.activate();
  for (let frame = 0; frame < 150 / 0.008 && m.state.outcome === 0; frame++) {
    const player = m.state.pieces[0];
    if (id === 'runner') {
      const dangers = m.state.pieces.filter(p => p.kind === 7 && p.color !== 1); let lane = 0; let best = -1;
      for (let candidate = 0; candidate < 3; candidate++) {
        const gap = Math.min(999, ...dangers.filter(p => Math.abs(p.x - (60 + 120 * candidate)) < 30).map(p => Math.abs(p.y - 388)));
        if (gap > best) { best = gap; lane = candidate; }
      }
      while (m.state.cursor < lane) m.tap(1); while (m.state.cursor > lane) m.tap(0);
    }
    if (id === 'blackhole') {
      const candidates = m.state.pieces.filter(p => p.kind === 9 && p.r < player.r * 0.9).sort((a, b) => Math.hypot(a.x - player.x, a.y - player.y) - Math.hypot(b.x - player.x, b.y - player.y));
      if (candidates.length) m.aim(candidates[0].x, candidates[0].y);
    }
    if (id === 'fisheat') m.aim(30, 25);
    if (id === 'roomdefense') { for (let slot = 0; slot < 6; slot++) m.tap(slot); if (m.state.data[1] < 75) m.tap(6); }
    if (id === 'basketball' && m.state.pieces.length === 1) m.aim(260 + Math.sin((m.state.time + 1.6) * 0.9) * level * 24, 145);
    if (id === 'rhythm') for (const note of [...m.state.pieces]) if (note.y >= 390) m.tap(note.owner);
    if (id === 'restaurant') for (const customer of [...m.state.pieces].filter(p => p.kind === 19)) {
      if (m.state.board[customer.color] > 0) m.tap(100 + customer.id); else m.tap(customer.color);
    }
    if (id === 'bubbleshooter' && m.state.pieces.length === 0) m.aim(180, 1);
    if (id === 'fruitmerge' && m.state.cooldown === 0) m.aim(180, 20);
    m.step(0.008); if (frame % 32 === 0) assert(m.valid(m.state), `${id}/${level}, frame ${frame}`);
  }
  assert.equal(m.state.outcome, 1); assert(m.valid(m.state));
  const finished = JSON.stringify(m.state); m.tap(0); m.aim(180, 230); m.activate(); m.step(0.008); assert.equal(JSON.stringify(m.state), finished);
});

let failed = 0;
for (const entry of cases) {
  try { entry.run(); console.log(`PASS ${entry.name}`); }
  catch (error) { failed++; console.error(`FAIL ${entry.name}\n${error.stack}`); }
}
console.log(`${cases.length - failed}/${cases.length} expansion gameplay audit checks passed`);
process.exitCode = failed ? 1 : 0;
