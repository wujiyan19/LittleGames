/* Gameplay snapshot regressions for the 2026-10-08 puzzle/render audit.
 * The fixture runs actual ArkTS models and view models; native ArkUI rendering
 * remains a separate device check. */
const assert = require('node:assert/strict');
const { fixture } = require('./test-performance.cjs');
const f = fixture();
const { ExpansionModel } = f.rules('Expansion');
const checks = [];
const test = (name, run) => checks.push({ name, run });
const model = (id, level = 1, seed = 8) => {
  const game = new ExpansionModel(f.rng(seed)); game.start(id, level); return game;
};
const restore = game => {
  const vm = f.vm('ExpansionViewModel'); vm.init(game.state.id);
  assert(vm.importContinuation(JSON.stringify({ version: 1, state: game.state, recorded: false, paused: false })));
  return vm;
};
const rendered = (vm, id) => {
  const child = vm.worldPieces.find(piece => piece.id === id);
  assert(child, `missing live render child ${vm.state.id}/${id}`); return child;
};
const liveChildren = vm => assert.deepEqual(vm.worldPieces.map(piece => piece.piece), vm.state.pieces.filter(piece => piece.alive));

test('parking removes the driven car while retaining the other children; undo restores it', () => {
  const game = model('parkingjam'), vm = restore(game), id = game.state.target[0];
  const previous = rendered(vm, id).piece;
  const retained = vm.worldPieces.find(piece => piece.id !== id);
  vm.tap(id);
  assert.equal(previous.alive, true, 'ordinary old snapshots remain alive');
  assert.equal(vm.state.pieces[id].alive, false);
  assert(!vm.worldPieces.some(piece => piece.id === id));
  assert.strictEqual(rendered(vm, retained.id), retained);
  liveChildren(vm);
  vm.undo(); assert.equal(rendered(vm, id).piece.alive, true); liveChildren(vm);
});

test('three removed screws drop their plate and undo restores its last screw', () => {
  const game = model('screwout'), vm = restore(game), screws = game.state.target.slice(0, 3);
  const owner = game.state.pieces.find(piece => piece.id === screws[0]).owner;
  const oldPlate = rendered(vm, owner).piece;
  for (const id of screws) { vm.tap(id); assert(!vm.worldPieces.some(piece => piece.id === id)); }
  assert.equal(oldPlate.alive, true);
  assert.equal(vm.state.pieces.find(piece => piece.id === owner).alive, false);
  assert(!vm.worldPieces.some(piece => piece.id === owner)); liveChildren(vm);
  vm.undo(); assert.equal(rendered(vm, owner).piece.alive, true);
  assert.equal(rendered(vm, screws[2]).piece.alive, true); liveChildren(vm);
});

test('mahjong matching removes both tiles and undo restores the pair', () => {
  const game = model('mahjongsolitaire'), vm = restore(game), pair = game.state.target.slice(0, 2);
  const old = pair.map(id => rendered(vm, id).piece);
  vm.tap(pair[0]); vm.tap(pair[1]);
  for (const id of pair) assert(!vm.worldPieces.some(piece => piece.id === id));
  assert(old.every(piece => piece.alive)); liveChildren(vm);
  vm.undo(); for (const id of pair) assert.equal(rendered(vm, id).piece.alive, true); liveChildren(vm);
});

test('mahjong rearrange updates every retained tile snapshot; restart also refreshes them', () => {
  const vm = restore(model('mahjongsolitaire')), children = [...vm.worldPieces];
  const oldPieces = children.map(child => child.piece);
  vm.action(); liveChildren(vm);
  children.forEach((child, index) => {
    assert.strictEqual(rendered(vm, child.id), child);
    assert.notStrictEqual(child.piece, oldPieces[index]);
  });
  const afterShuffle = children.map(child => child.piece);
  vm.startGame(); liveChildren(vm);
  children.forEach((child, index) => {
    assert.strictEqual(rendered(vm, child.id), child);
    assert.notStrictEqual(child.piece, afterShuffle[index]);
  });
});

test('untangle drag updates the retained node, matches the edges and supports undo', () => {
  const vm = restore(model('untangle')), child = rendered(vm, 0), old = child.piece;
  let destination;
  for (let y = 30; y <= 430 && !destination; y += 40) for (let x = 30; x <= 330 && !destination; x += 40) {
    if (Math.hypot(x - old.x, y - old.y) > 10 && !vm.state.pieces.some(piece => piece.id !== 0 && Math.hypot(piece.x - x, piece.y - y) < 36)) destination = [x, y];
  }
  assert(destination); vm.tap(0); vm.setDragging(true); vm.aim(...destination); vm.setDragging(false);
  assert.strictEqual(rendered(vm, 0), child); assert.notStrictEqual(child.piece, old);
  assert.equal(child.piece.x, destination[0]); assert.equal(child.piece.y, destination[1]); liveChildren(vm);
  vm.undo(); assert.equal(rendered(vm, 0).piece.x, old.x); assert.equal(rendered(vm, 0).piece.y, old.y); liveChildren(vm);
});

test('rescue bees move in their existing children; pause freezes and resume updates them', () => {
  const vm = restore(model('linerescue'));
  vm.aim(0, 0); vm.aim(50, 0); vm.activate();
  const child = rendered(vm, 2), old = child.piece;
  vm.advance(96); assert.strictEqual(rendered(vm, 2), child);
  assert.notStrictEqual(child.piece, old); assert.notEqual(child.piece.y, old.y); liveChildren(vm);
  vm.togglePause(); const paused = child.piece; vm.advance(96); assert.strictEqual(child.piece, paused);
  vm.togglePause(); vm.advance(96); assert.notStrictEqual(child.piece, paused); liveChildren(vm);
});

test('word tower enemies move without replacing their render identity', () => {
  const vm = restore(model('wordtower')); vm.activate(); vm.advance(96);
  const child = vm.worldPieces.find(piece => piece.piece.kind === 56); assert(child);
  const old = child.piece; vm.advance(96);
  assert.strictEqual(rendered(vm, child.id), child); assert(child.piece.y > old.y); liveChildren(vm);
});

test('beat jump moves the retained player after a correctly timed beat', () => {
  const vm = restore(model('beatjump')); vm.activate();
  for (let frame = 0; frame < 20 && vm.state.cooldown > 0.08; frame++) vm.advance(96);
  assert(Math.abs(vm.state.cooldown) <= 0.18);
  const child = vm.worldPieces[0], old = child.piece;
  vm.tap(vm.state.target[vm.state.cursor]); vm.advance(96);
  assert.strictEqual(vm.worldPieces[0], child); assert(child.piece.y < old.y); liveChildren(vm);
});

test('block tray snapshots record consumed slots and refill after three placements', () => {
  const game = model('blockfit', 0), initial = [...game.state.tray];
  const vm = restore(game), before = vm.state;
  for (let slot = 0; slot < 3; slot++) {
    game.choose(slot);
    const at = game.state.board.findIndex((_, index) => game.puzzle.fits(game.state, game.state.tray[slot], index));
    assert(at >= 0); game.tap(at);
    assert(vm.importContinuation(JSON.stringify({ version: 1, state: game.state, recorded: false, paused: false })));
    if (slot < 2) {
      assert.equal(vm.state.tray[slot], -1);
      assert.equal(before.tray[slot], initial[slot], 'a captured old shape never marks the consumed slot empty');
    }
  }
  assert(vm.state.tray.every(shape => shape >= 0)); assert.notStrictEqual(vm.state, before);
});

test('link tiles clear their actual board cells; undo restores them', () => {
  const game = model('linktiles'), pair = game.matching.linkPair(game.state), vm = restore(game), old = vm.state;
  assert.equal(pair.length, 2); vm.tap(pair[0]); vm.tap(pair[1]);
  for (const index of pair) { assert.equal(vm.state.board[index], 0); assert(old.board[index] > 0); }
  vm.undo(); for (const index of pair) assert.equal(vm.state.board[index], old.board[index]);
});

test('slot pair drops into an initially empty child and the next drop clears it', () => {
  const vm = restore(model('slotpair')), old = vm.state;
  vm.tap(0); assert(vm.state.board[30] > 0); assert.equal(old.board[30], 0);
  vm.tap(0); assert.equal(vm.state.board[30], 0); assert.equal(vm.state.cursor, 2);
});

test('group clear changes surviving cell colors as they settle, without changing cell identity', () => {
  const game = model('groupclear'); game.state.board.fill(0);
  game.state.board[42] = game.state.board[36] = 1; game.state.board[45] = 2; game.state.board[46] = 3;
  const vm = restore(game), old = vm.state; vm.tap(42);
  assert.equal(old.board[42], 1); assert.equal(vm.state.board[42], 2); assert.equal(vm.state.board[43], 3);
});

test('bus FIFO and filled seats change after legal launches', () => {
  const game = model('buscolor'), vm = restore(game), previous = vm.state;
  for (const lane of game.state.data.slice(3, 6)) vm.tap(lane);
  assert(vm.state.cursor > 0);
  assert.deepEqual(vm.state.board.slice(vm.state.cursor, vm.state.cursor + 9), game.state.board.slice(vm.state.cursor, vm.state.cursor + 9));
  assert(vm.state.pieces.some((piece, index) => piece.w > previous.pieces[index].w));
});

test('sand collection changes the selected can counter while preserving the other counts', () => {
  const vm = restore(model('sand')), previous = vm.state, color = vm.state.board[0];
  vm.choose(color - 1); vm.tap(0);
  assert(vm.state.data[color - 1] > 0); assert.equal(previous.data[color - 1], 0);
  assert.equal(vm.state.data.reduce((sum, count) => sum + count, 0), vm.state.cursor);
});

let passed = 0;
for (const check of checks) {
  check.run(); passed++; console.log('PASS ' + check.name);
}
console.log(`${passed}/${checks.length} expansion render audit checks passed`);
