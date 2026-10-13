const assert = require('node:assert/strict');
const fs = require('node:fs');
const { fixture } = require('./test-performance.cjs');
const f = fixture();
const { ExpansionModel } = f.rules('Expansion');
const Art = f.load('entry/src/main/ets/common/ExpansionArt.ets').ExpansionArt;
let count = 0;
const test = (name, run) => { run(); count++; console.log('PASS ' + name); };
const fruitGame = () => {
  const m = new ExpansionModel(f.rng(100)); m.start('fruitslice', 1); m.activate(); m.step(0.008);
  assert.equal(m.state.pieces[0].kind, 30); m.state.cooldown = 10; return m;
};
const restore = m => {
  const vm = f.vm('ExpansionViewModel'); vm.init(m.state.id);
  assert(vm.importContinuation(JSON.stringify({ version: 1, state: m.state, recorded: false, paused: false })));
  if (vm.paused) vm.togglePause(); return vm;
};

test('a reused fruit child receives new positions without changing its UI identity', () => {
  const vm = restore(fruitGame()), rendered = vm.worldPieces[0], previous = rendered.piece;
  vm.advance(96);
  assert.strictEqual(vm.worldPieces[0], rendered);
  assert.notStrictEqual(rendered.piece, previous);
  assert(rendered.piece.y < previous.y);
  assert.equal(rendered.piece.id, previous.id);
  assert.deepEqual(rendered.piece, vm.state.pieces[0]);
  assert.equal(Art.piece('fruitslice', rendered.piece), Art.piece('fruitslice', previous));
});

test('stable IDs update image resources and size when a new snapshot reuses an ID', () => {
  const m = new ExpansionModel(f.rng(8)); m.start('rollingball', 1);
  const vm = restore(m), rendered = vm.worldPieces[0], oldImage = Art.piece('rollingball', rendered.piece);
  vm.init('shooter'); vm.startGame();
  assert.strictEqual(vm.worldPieces[0], rendered);
  assert.equal(rendered.piece.kind, 24);
  assert.notEqual(Art.piece('shooter', rendered.piece), oldImage);
  const changed = fruitGame();
  const fruit = restore(changed), original = fruit.worldPieces[0], image = Art.piece('fruitslice', original.piece);
  changed.state.pieces[0].color = 6;
  assert(fruit.importContinuation(JSON.stringify({ version: 1, state: changed.state, recorded: false, paused: true })));
  assert.strictEqual(fruit.worldPieces[0], original);
  assert.notEqual(Art.piece('fruitslice', original.piece), image);
});

test('pause and background freeze the displayed fruit; resume updates the same child', () => {
  const vm = restore(fruitGame()), rendered = vm.worldPieces[0];
  vm.togglePause(); const paused = rendered.piece; vm.advance(96); assert.strictEqual(rendered.piece, paused);
  vm.togglePause(); vm.onAppHidden(); vm.advance(96); assert.deepEqual(rendered.piece, paused);
  vm.onAppShown(); vm.advance(96); assert.notStrictEqual(rendered.piece, paused);
  assert.strictEqual(vm.worldPieces[0], rendered);
});

test('cut fruit disappears immediately, scores once, and exports a valid continuation', () => {
  const vm = restore(fruitGame()), piece = vm.worldPieces[0].piece;
  vm.aim(piece.x, piece.y); assert.equal(vm.state.score, 50); assert.equal(vm.state.moves, 1);
  assert.equal(vm.worldPieces.length, 0); assert.equal(vm.state.pieces.length, 0);
  vm.aim(piece.x, piece.y); assert.equal(vm.state.score, 50);
  const resumed = f.vm('ExpansionViewModel'); resumed.init('fruitslice');
  assert(resumed.importContinuation(vm.exportContinuation())); assert.equal(resumed.worldPieces.length, 0);
});

test('winning fruit and hit bomb disappear even though their terminal frame loop stops', () => {
  for (const bomb of [false, true]) {
    const m = fruitGame();
    if (bomb) m.state.pieces[0].kind = 31;
    else { m.state.moves = m.state.goal - 1; m.state.score = m.state.moves * 50; }
    const vm = restore(m), piece = vm.worldPieces[0].piece;
    vm.aim(piece.x, piece.y); assert.equal(vm.state.outcome, bomb ? 2 : 1);
    assert.equal(vm.worldPieces.length, 0); assert.equal(vm.state.pieces.length, 0);
    const resumed = f.vm('ExpansionViewModel'); resumed.init('fruitslice');
    assert(resumed.importContinuation(vm.exportContinuation())); assert.equal(resumed.state.outcome, vm.state.outcome);
  }
});

test('missed fruit removes its child; restarting creates a fresh child for reused IDs', () => {
  const vm = restore(fruitGame()), original = vm.worldPieces[0];
  for (let i = 0; i < 22; i++) vm.advance(96);
  assert.equal(vm.worldPieces.length, 0); assert.equal(vm.state.errors, 1);
  vm.startGame(); assert.equal(vm.worldPieces.length, 0); assert.equal(vm.state.errors, 0);
  vm.activate(); vm.advance(32); assert.equal(vm.worldPieces.length, 1);
  assert.equal(vm.worldPieces[0].id, original.id); assert.notStrictEqual(vm.worldPieces[0], original);
});

test('world rendering observes snapshots while keeping keys independent of frame positions', () => {
  const wrapper = fs.readFileSync('entry/src/main/ets/viewmodel/ExpansionRenderPiece.ets', 'utf8');
  const board = fs.readFileSync('entry/src/main/ets/pages/collection/ExpansionWorldBoard.ets', 'utf8');
  assert(wrapper.includes('@ObservedV2')); assert(wrapper.includes('@Trace piece: ExpansionPiece'));
  assert(board.includes('ForEach(this.vm.worldPieces'));
  assert(board.includes('ExpansionArt.piece(this.gameId, rendered.piece)'));
  assert(board.includes('(rendered: ExpansionRenderPiece) => rendered.id.toString()'));
  assert(!board.includes('ForEach(this.vm.state.pieces'));
});
test('fruit mistake text agrees with the five-miss rule in every locale', () => {
  for (const locale of ['base', 'zh_CN', 'en_US']) {
    const values = JSON.parse(fs.readFileSync(`entry/src/main/resources/${locale}/element/string.json`, 'utf8')).string;
    assert(values.find(s => s.name === 'expansion_fruitslice_errors').value.endsWith('/ 5'));
  }
  const m = fruitGame(); m.state.errors = 4; m.state.pieces[0].y = 489; m.state.pieces[0].vy = 400;
  m.step(0.008); assert.equal(m.state.errors, 5); assert.equal(m.state.outcome, 2);
});
console.log(`${count}/${count} world piece refresh checks passed`);
