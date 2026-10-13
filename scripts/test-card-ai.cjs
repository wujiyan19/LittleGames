const assert = require('node:assert/strict');
const { fixture } = require('./test-performance.cjs');
const f = fixture();
const { ExpansionCards } = f.load('entry/src/main/ets/model/game/ExpansionCards.ets');
const { ExpansionState } = f.load('entry/src/main/ets/model/game/ExpansionState.ets');
const tests = [];
const test = (name, run) => tests.push({ name, run });
const snapshot = s => JSON.stringify(s);
const create = (id, level = 1, seed = 8, random = f.rng(seed)) => {
  const cards = new ExpansionCards(random);
  const state = new ExpansionState(); state.id = id; state.level = level; cards.start(state);
  return { cards, state };
};
const check = ({ cards, state }) => assert(cards.valid(state), `${state.id} conserved and valid`);
const destination = (token, die) => {
  let at = token.x < 0 ? 0 : token.x + die;
  if (at > 57) at = 114 - at;
  if (at < 50 && at > 0 && at % 4 === 0) at = Math.min(51, at + 4);
  return at;
};
function mahjongPosition(level, specified = {}, discards = []) {
  const game = create('mahjong', level);
  const s = game.state, remaining = Array.from({ length: 136 }, (_, i) => i);
  for (const pile of s.piles) pile.cards = [];
  const take = type => {
    const at = remaining.findIndex(card => Math.floor(card / 4) === type);
    assert(at >= 0, `fixture has too many copies of tile ${type}`);
    return remaining.splice(at, 1)[0];
  };
  for (const [seat, types] of Object.entries(specified)) s.piles[Number(seat)].cards = types.map(take);
  s.piles[8].cards = discards.map(take);
  for (let seat = 0; seat < 4; seat++) if (!Object.hasOwn(specified, seat)) {
    for (let i = 0; i < 13; i++) s.piles[seat].cards.push(remaining.splice((i * 7) % remaining.length, 1)[0]);
  }
  const used = s.piles.flatMap(pile => pile.cards);
  s.board = [...used, ...remaining]; s.cursor = used.length; s.next = 0; s.data.fill(0); s.selected = -1;
  check(game); return game;
}

for (const level of [0, 1, 2]) {
  test(`mahjong/${level}: deferred input waits for one visible computer action`, () => {
    const game = create('mahjong', level, 19), { cards, state: s } = game;
    assert.equal(s.next, 0); assert.equal(cards.needsComputerTurn(s), false);
    const tile = s.piles[0].cards.at(-1), beforeCursor = s.cursor;
    cards.tap(s, tile, false); cards.tap(s, tile, false);
    assert.equal(s.next, 1); assert.equal(s.cursor, beforeCursor); assert(cards.needsComputerTurn(s));
    const waiting = snapshot(s);
    for (const action of [...s.piles[0].cards, 900, 901, 906, 907]) cards.tap(s, action, false);
    assert.equal(snapshot(s), waiting); assert.equal(cards.mahjongCan(s, 900), false);
    const beforeMoves = s.moves;
    cards.computerTurn(s); assert(s.cursor - beforeCursor <= 2); assert(s.moves - beforeMoves <= 1); check(game);
  });
  test(`mahjong/${level}: complete deferred games conserve all tiles`, () => {
    for (let seed = 1; seed <= 30; seed++) {
      const game = create('mahjong', level, seed), { cards, state: s } = game;
      let steps = 0;
      while (!s.outcome && steps++ < 400) {
        if (cards.needsComputerTurn(s)) cards.computerTurn(s);
        else if (s.data[0] === 1) cards.tap(s, cards.mahjongCan(s, 900) ? 900 : 907, false);
        else if (cards.mahjongCan(s, 900)) cards.tap(s, 900, false);
        else { const tile = s.piles[0].cards.at(-1); cards.tap(s, tile, false); cards.tap(s, tile, false); }
        check(game);
      }
      assert(s.outcome !== 0, `mahjong level ${level} seed ${seed} reached a win or wall exhaustion`);
      const ended = snapshot(s); cards.computerTurn(s); cards.tap(s, 907, false); assert.equal(snapshot(s), ended);
    }
  });
  test(`mahjong/${level}: wall exhaustion is a terminal draw`, () => {
    const game = create('mahjong', level), { cards, state: s } = game;
    s.piles[8].cards.push(...s.board.slice(s.cursor)); s.cursor = 136; s.next = 1; s.data[1] = 3;
    cards.computerTurn(s); assert.equal(s.outcome, 1); assert.equal(s.data[3], 1); assert.equal(s.score, 0);
    assert.equal(cards.needsComputerTurn(s), false); check(game);
  });
  test(`ludo/${level}: a computer step makes one move or one legal pass`, () => {
    const game = create('ludo', level, 8, { next: () => 0 }), { cards, state: s } = game;
    s.next = 2; cards.computerTurn(s); assert.equal(s.next, 3); assert.equal(s.moves, 0);
    s.next = 2; s.pieces[4].x = 0; const waiting = snapshot(s);
    cards.tap(s, 900, false); cards.tap(s, 0, false); assert.equal(snapshot(s), waiting);
    cards.computerTurn(s); assert.equal(s.next, 3); assert.equal(s.moves, 1); assert.equal(s.pieces[4].x, 1); check(game);
  });
  test(`ludo/${level}: deferred races reach a winner`, () => {
    for (let seed = 1; seed <= 30; seed++) {
      const game = create('ludo', level, seed), { cards, state: s } = game;
      let steps = 0;
      while (!s.outcome && steps++ < 10000) {
        if (cards.needsComputerTurn(s)) { const moves = s.moves; cards.computerTurn(s); assert(s.moves - moves <= 1); }
        else if (!s.data[0]) cards.tap(s, 900, false);
        else {
          const legal = s.pieces.filter(p => p.owner === 0 && p.x < 57 && (p.x >= 0 || s.data[0] === 6));
          legal.sort((a, b) => destination(b, s.data[0]) - destination(a, s.data[0]));
          assert(legal.length); cards.tap(s, legal[0].id, false);
        }
        check(game);
      }
      assert(s.outcome !== 0, `ludo level ${level} seed ${seed} completed a race`);
      const ended = snapshot(s); cards.computerTurn(s); cards.tap(s, 900, false); assert.equal(snapshot(s), ended);
    }
  });
  test(`ludo/${level}: the last computer token finishes the race`, () => {
    const game = create('ludo', level, 8, { next: () => 0 }), { cards, state: s } = game;
    for (let id = 4; id < 8; id++) s.pieces[id].x = 57;
    s.pieces[4].x = 56; s.next = 2; cards.computerTurn(s);
    assert.equal(s.outcome, 2); assert.equal(s.pieces[4].x, 57); assert.equal(cards.needsComputerTurn(s), false); check(game);
  });
}

test('mahjong: claim windows suspend computers and pong preserves ownership', () => {
  const game = mahjongPosition(2, { 0: [0, 0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 27, 29] }, [0]);
  const { cards, state: s } = game;
  s.data[0] = 1; s.data[1] = 1; s.data[2] = s.piles[8].cards[0] + 1; s.next = 2;
  assert.equal(cards.needsComputerTurn(s), false); assert(cards.mahjongCan(s, 901));
  const waiting = snapshot(s); cards.computerTurn(s); cards.tap(s, s.piles[0].cards[0], false); assert.equal(snapshot(s), waiting);
  cards.tap(s, 901, false); assert.equal(s.next, 0); assert.equal(s.data[4], 1); assert.equal(s.piles[4].cards.length, 3);
  assert.equal(s.piles[0].cards.length, 11); assert.equal(s.piles[8].cards.length, 0); check(game);
});
test('mahjong: passing the preceding computer discard draws the human tile immediately', () => {
  const game = mahjongPosition(1, { 0: [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 27, 29] }, [3]);
  const { cards, state: s } = game;
  s.data[0] = 1; s.data[1] = 3; s.data[2] = s.piles[8].cards[0] + 1; s.next = 0;
  assert(cards.mahjongCan(s, 903)); const cursor = s.cursor;
  cards.tap(s, 907, false); assert.equal(s.cursor, cursor + 1); assert.equal(s.piles[0].cards.length, 14);
  assert.equal(s.next, 0); assert.equal(s.data[0], 0); assert.equal(cards.needsComputerTurn(s), false); check(game);
});
test('mahjong: a claimed kong replaces its tile without starting a computer turn', () => {
  const game = mahjongPosition(1, { 0: [0, 0, 0, 2, 4, 6, 8, 10, 12, 14, 16, 27, 29] }, [0]);
  const { cards, state: s } = game;
  s.data[0] = 1; s.data[1] = 2; s.data[2] = s.piles[8].cards[0] + 1; s.next = 3;
  const cursor = s.cursor; assert(cards.mahjongCan(s, 905)); cards.tap(s, 905, false);
  assert.equal(s.cursor, cursor + 1); assert.equal(s.piles[4].cards.length, 4); assert.equal(s.piles[0].cards.length, 11);
  assert.equal(s.next, 0); assert.equal(cards.needsComputerTurn(s), false); check(game);
});
test('mahjong: a computer wins on a human discard before drawing', () => {
  const game = mahjongPosition(2, { 1: [0, 0, 0, 1, 2, 3, 9, 10, 11, 18, 19, 20, 27] }, [27]);
  const { cards, state: s } = game;
  s.data[1] = 0; s.data[2] = s.piles[8].cards[0] + 1; s.next = 1;
  const cursor = s.cursor; cards.computerTurn(s); assert.equal(s.outcome, 2); assert.equal(s.cursor, cursor); check(game);
});
test('mahjong: stronger levels retain complete groups instead of a random discard', () => {
  for (const level of [0, 1, 2]) {
    const game = mahjongPosition(level, { 1: [0, 0, 0, 1, 2, 3, 9, 10, 11, 18, 19, 20, 27] });
    const { state: s } = game;
    const wall = s.board.findIndex((card, i) => i >= s.cursor && Math.floor(card / 4) === 33);
    assert(wall >= s.cursor); [s.board[s.cursor], s.board[wall]] = [s.board[wall], s.board[s.cursor]];
    s.next = 1; s.data[1] = 3;
    const cards = new ExpansionCards({ next: () => 0 }); cards.computerTurn(s);
    assert.equal(Math.floor((s.data[2] - 1) / 4), level === 0 ? 0 : 33); check(game);
  }
});
test('mahjong: changing hidden opponent hands cannot change a hard discard choice', () => {
  const first = mahjongPosition(2, { 1: [0, 0, 0, 1, 2, 3, 9, 10, 11, 18, 19, 20, 27] });
  first.state.next = 1; first.state.data[1] = 3;
  const second = create('mahjong', 2); second.state = JSON.parse(snapshot(first.state));
  [second.state.piles[2].cards, second.state.piles[3].cards] = [second.state.piles[3].cards, second.state.piles[2].cards];
  first.cards.computerTurn(first.state); second.cards.computerTurn(second.state);
  assert.equal(first.state.data[2], second.state.data[2]); check(first); check(second);
});
test('ludo: normal advances while hard takes a visible capture', () => {
  for (const level of [1, 2]) {
    const game = create('ludo', level, 8, { next: () => 0 }), { cards, state: s } = game;
    s.next = 2; s.pieces[4].x = 0; s.pieces[5].x = 25; s.pieces[0].x = 14;
    cards.computerTurn(s);
    if (level === 1) { assert.equal(s.pieces[5].x, 26); assert.equal(s.pieces[0].x, 14); }
    else { assert.equal(s.pieces[4].x, 1); assert.equal(s.pieces[0].x, -1); }
    check(game);
  }
});
test('ludo: hard avoids a visible capture threat', () => {
  const game = create('ludo', 2, 8, { next: () => 0 }), { cards, state: s } = game;
  s.next = 2; s.pieces[4].x = 25; s.pieces[5].x = 20; s.pieces[0].x = 38;
  cards.computerTurn(s); assert.equal(s.pieces[5].x, 21); assert.equal(s.pieces[4].x, 25); check(game);
});
test('ludo: constant sixes perform one deferred action and bounded automatic work', () => {
  let calls = 0;
  const game = create('ludo', 2, 8, { next: () => { calls++; return 0.999999; } }), { cards, state: s } = game;
  s.next = 2; cards.computerTurn(s); assert.equal(s.moves, 1); assert.equal(s.next, 2); assert.equal(calls, 1); check(game);
  s.next = 1; s.data[0] = 1; s.pieces[0].x = 0; const before = calls;
  cards.tap(s, 0); assert(calls - before <= 100); check(game);
});
test('card computers: invalid input and unsupported or terminal games do nothing', () => {
  for (const id of ['mahjong', 'ludo', 'spider', 'freecell']) {
    const game = create(id), { cards, state: s } = game, before = snapshot(s);
    for (const invalid of [-1, NaN, Infinity, 0.5, 1001]) cards.tap(s, invalid, false);
    cards.computerTurn(s); assert.equal(snapshot(s), before);
    s.outcome = 2; const terminal = snapshot(s); cards.computerTurn(s); cards.tap(s, 900); assert.equal(snapshot(s), terminal); check(game);
  }
});
test('card computers: default automatic turns preserve immediate model callers', () => {
  const game = create('mahjong', 1, 19), { cards, state: s } = game;
  const tile = s.piles[0].cards.at(-1); cards.tap(s, tile); cards.tap(s, tile);
  assert.equal(cards.needsComputerTurn(s), false); assert(s.outcome || s.next === 0 || s.data[0] === 1); check(game);
});

let failures = 0;
for (const { name, run } of tests) {
  try { run(); console.log(`PASS ${name}`); }
  catch (error) { failures++; console.error(`FAIL ${name}\n${error.stack}`); }
}
assert.equal(failures, 0, `${failures} card AI regression failures`);
console.log(`Passed ${tests.length} card AI regression checks.`);
