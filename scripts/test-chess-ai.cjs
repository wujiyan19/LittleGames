const assert = require('node:assert/strict');
const { fixture } = require('./test-performance.cjs');
const tests = [];
const test = (name, run) => tests.push({ name, run });

function create(id = 'chess', level = 1, source = 17) {
  const f = fixture();
  const { ExpansionModel } = f.rules('Expansion');
  const random = typeof source === 'number' ? f.rng(source) : source;
  const model = new ExpansionModel(random); model.start(id, level);
  return model;
}
function position(model, entries) {
  const s = model.state;
  s.board.fill(0);
  for (const [cell, piece] of entries) s.board[cell] = piece;
  s.cursor = 1; s.selected = -1; s.outcome = 0; s.moves = 0;
  return s;
}
function legalResult(model, before, legal) {
  const expected = legal.map(move => {
    const trial = create(before.id, before.level);
    trial.state = JSON.parse(JSON.stringify(before));
    trial.chess.move(trial.state, move.from, move.to);
    return JSON.stringify(trial.state);
  });
  assert(expected.includes(JSON.stringify(model.state)), 'AI committed exactly one legal move without trial-state leakage');
  assert(model.valid(model.state), 'AI result is a valid resumable position');
}

for (const id of ['chess', 'xiangqi']) for (const level of [0, 1, 2]) {
  test(`${id}/${level}: delayed human move leaves a valid pending position; computer commits one legal response`, () => {
    const model = create(id, level);
    const human = model.chess.moves(model.state, 1)[0];
    model.chess.tap(model.state, human.from, false);
    model.chess.tap(model.state, human.to, false);
    assert.equal(model.state.moves, 1); assert.equal(model.state.cursor, 1);
    assert(model.chess.needsComputerTurn(model.state)); assert(model.valid(model.state));
    const pending = JSON.parse(JSON.stringify(model.state));
    const legal = model.chess.moves(model.state, 2);
    // Another human input cannot play the pending computer turn.
    const serialized = JSON.stringify(model.state); model.chess.tap(model.state, 0, false);
    assert.equal(JSON.stringify(model.state), serialized);
    model.chess.computerTurn(model.state);
    assert.equal(model.state.moves, 2); assert.equal(model.state.cursor, 0);
    assert.equal(model.chess.needsComputerTurn(model.state), false);
    legalResult(model, pending, legal);
    const settled = JSON.stringify(model.state); model.chess.computerTurn(model.state);
    assert.equal(JSON.stringify(model.state), settled);
  });
  test(`${id}/${level}: deterministic sources produce reproducible automatic replies`, () => {
    for (const source of [() => 0, () => 0.999999, null]) {
      const a = create(id, level, source ? { next: source } : 49);
      const b = create(id, level, source ? { next: source } : 49);
      const move = a.chess.moves(a.state, 1)[0];
      for (const model of [a, b]) { model.chess.tap(model.state, move.from); model.chess.tap(model.state, move.to); }
      assert.equal(a.state.moves, 2); assert.equal(JSON.stringify(a.state), JSON.stringify(b.state));
      assert(a.valid(a.state));
    }
  });
}

for (const level of [0, 1, 2]) {
  test(`chess/${level}: computer finds the only legal check escape`, () => {
    const model = create('chess', level); const s = position(model, [[0, 11], [8, 3], [17, 1]]);
    assert(model.chess.checked(s, 2)); assert(model.valid(s));
    assert.equal(model.chess.moves(s, 2).length, 1);
    model.chess.computerTurn(s);
    assert.equal(s.board[1], 11); assert.equal(s.cursor, 0); assert.equal(s.moves, 1);
    assert.equal(model.chess.checked(s, 2), false); assert(model.valid(s));
  });
}

test('hard chess chooses immediate checkmate over a quiet move', () => {
  const model = create('chess', 2); const s = position(model, [[63, 1], [45, 11], [53, 12]]);
  assert(model.valid(s)); model.chess.computerTurn(s);
  assert.equal(s.outcome, 2); assert.equal(s.data[8], 0);
  assert(model.chess.checked(s, 1)); assert.equal(model.chess.moves(s, 1).length, 0);
  assert.equal(s.moves, 1); assert(model.valid(s));
});

test('hard chess avoids sacrificing its queen for a defended pawn', () => {
  const model = create('chess', 2); const s = position(model, [[4, 11], [62, 1], [24, 12], [32, 6], [56, 3]]);
  assert(model.valid(s)); assert(model.chess.legal(s, 24, 32));
  model.chess.computerTurn(s);
  assert.equal(s.board[32], 6, 'defended pawn is not taken by the queen');
  assert(s.board.includes(12)); assert(model.valid(s));
});

test('easy chess picks a safe alternative when an exposed queen move is available', () => {
  for (const value of [0, 0.999999]) {
    const model = create('chess', 0, { next: () => value });
    const s = position(model, [[4, 11], [62, 1], [24, 12], [32, 6], [56, 3]]);
    model.chess.computerTurn(s);
    const queen = s.board.indexOf(12);
    assert(queen >= 0); assert.equal(model.chess.attacked(s, queen, 1), false); assert(model.valid(s));
  }
});

test('simulation preserves castling rights, en-passant, promotion choice, counters and history', () => {
  for (const level of [0, 1, 2]) {
    const model = create('chess', level);
    const s = position(model, [[60, 1], [4, 11], [0, 13], [7, 13], [55, 16], [25, 16], [26, 6], [57, 5]]);
    s.data[6] = 35; s.data[7] = 37; s.data[9] = 5; s.moves = 19;
    assert(model.valid(s));
    const legal = model.chess.moves(s, 2);
    assert(legal.some(move => move.from === 4 && move.to === 6), 'castling available');
    assert(legal.some(move => move.from === 25 && move.to === 34), 'en-passant available');
    assert(legal.some(move => move.from === 55 && move.to === 63), 'promotion available');
    const before = JSON.parse(JSON.stringify(s));
    model.chess.computerTurn(s); legalResult(model, before, legal);
    assert.equal(s.data[9], 5); assert.equal(s.moves, 20);
  }
});

test('pending terminal computer positions settle once without trying a move', () => {
  for (const kind of ['mate', 'stalemate']) {
    const model = create('chess', 2);
    const s = position(model, kind === 'mate' ? [[0, 11], [8, 3], [2, 3], [17, 1]] : [[0, 11], [18, 1], [17, 2]]);
    assert(model.valid(s)); assert.equal(model.chess.moves(s, 2).length, 0);
    model.chess.computerTurn(s);
    assert.equal(s.moves, 0); assert.equal(s.outcome, 1); assert.equal(s.data[8], kind === 'stalemate' ? 1 : 0);
    const terminal = JSON.stringify(s); model.chess.computerTurn(s);
    assert.equal(JSON.stringify(s), terminal); assert(model.valid(s));
  }
});

test('hard analysis stays within a fixed legal-generation budget', () => {
  const model = create('chess', 2);
  const move = model.chess.moves(model.state, 1)[0];
  model.chess.tap(model.state, move.from, false); model.chess.tap(model.state, move.to, false);
  let calls = 0; const original = model.chess.moves;
  model.chess.moves = function(state, side) { calls++; return original.call(this, state, side); };
  model.chess.computerTurn(model.state);
  assert(calls <= 62, `bounded generation work: ${calls}`); assert(model.valid(model.state));
});

let failed = 0;
for (const entry of tests) {
  try { entry.run(); }
  catch (error) { failed++; console.error(`FAIL ${entry.name}\n${error.stack}`); }
}
console.log(`${tests.length - failed}/${tests.length} chess AI regressions passed.`);
process.exitCode = failed ? 1 : 0;
