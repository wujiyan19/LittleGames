const assert = require('node:assert/strict');
const { fixture } = require('./test-performance.cjs');
const f = fixture();
const { ExpansionPoker, PokerPattern } = f.load('entry/src/main/ets/model/game/ExpansionPoker.ets');
const { ExpansionState } = f.load('entry/src/main/ets/model/game/ExpansionState.ets');
const tests = [];
const test = (name, run) => tests.push({ name, run });
const card = (rank, suit = 0, deck = 0) => rank >= 16 ? 52 + rank - 16 + deck * 54 :
  (rank === 14 ? 0 : rank - 1) + suit * 13 + deck * 54;
const cards = ranks => {
  const counts = new Map();
  return ranks.map(rank => {
    const count = counts.get(rank) || 0; counts.set(rank, count + 1);
    return card(rank, [0, 2, 3, 1][count % 4], Math.floor(count / 4));
  });
};
function start(id, level = 1, seed = 1) {
  const poker = new ExpansionPoker(f.rng(seed)); const state = new ExpansionState();
  state.id = id; state.level = level; poker.start(state); return { poker, state };
}
function position(id, hand, last = new PokerPattern(), level = 1, player = 1, leader = 0) {
  const game = start(id, level); const s = game.state;
  for (const pile of s.piles) { pile.cards = []; }
  s.piles[player].cards = hand.slice(); const used = new Set(hand);
  for (let seat = 0; seat < (id === 'guandan' ? 4 : 3); seat++) {
    if (seat === player) { continue; }
    const filler = s.board.find(value => !used.has(value)); used.add(filler); s.piles[seat].cards = [filler];
  }
  s.piles[5].cards = s.board.filter(value => !used.has(value));
  s.cursor = player; s.data = [leader, 0, last.kind, last.strength, last.size, last.bomb];
  assert(game.poker.valid(s)); return game;
}
const played = game => game.poker.pattern(game.state.piles[4].cards, game.state.id === 'guandan');

test('deferred human play stops at the first computer seat and each computer call performs one action', () => {
  for (const id of ['doudizhu', 'guandan']) {
    const game = start(id); const p = game.poker; const s = game.state;
    p.tap(s, 902, false); assert(s.tray.length > 0); p.tap(s, 900, false);
    assert.equal(s.cursor, 1); assert.equal(s.moves, 1); assert(p.needsComputerTurn(s));
    const before = JSON.stringify(s); p.tap(s, 902, false); p.tap(s, 900, false);
    assert.equal(JSON.stringify(s), before, 'human cannot act during an AI turn');
    const moves = s.moves; p.computerTurn(s); assert(s.moves - moves <= 1);
    assert.notEqual(JSON.stringify(s), before); assert(p.valid(s));
    assert.equal(s.cursor, 2, 'one action must not run the next bot inline');
    assert(p.valid(JSON.parse(JSON.stringify(s))), 'pending AI snapshots remain valid');
  }
});

for (const id of ['doudizhu', 'guandan']) {
  for (const automatic of [true, false]) {
    test(`${id}: ${automatic ? 'automatic' : 'deferred'} seeded rounds finish at every difficulty with legal moves and a conserved deck`, () => {
      for (const level of [0, 1, 2]) {
        for (const seed of [1, 2, 3, 4, 7, 12, 19, 30, 41, 57, 83, 101]) {
          const game = start(id, level, seed); const p = game.poker; const s = game.state;
          let actions = 0;
          while (!s.outcome && actions++ < 1200) {
            const before = JSON.stringify(s); const moves = s.moves;
            if (p.needsComputerTurn(s)) { p.computerTurn(s); assert(s.moves - moves <= 1); }
            else { p.tap(s, 902, automatic); p.tap(s, s.tray.length ? 900 : 901, automatic); }
            assert.notEqual(JSON.stringify(s), before, `${id}/${level}/${seed} stalled at ${actions}`);
            assert(p.valid(s), `${id}/${level}/${seed} invalid after ${actions}`);
            if (!s.outcome) { assert(s.piles[s.cursor].cards.length > 0, 'skip seats that already finished'); }
          }
          assert(s.outcome !== 0, `${id}/${level}/${seed} did not finish`);
          assert.equal(p.needsComputerTurn(s), false);
          if (id === 'guandan') { assert.equal(s.target.length, 4); }
        }
      }
    });
  }
}

test('normal and hard bots leave a partner lead intact, while a finishing hand can still play', () => {
  for (const id of ['doudizhu', 'guandan']) {
    for (const level of [1, 2]) {
      const partner = id === 'guandan' ? 3 : 2;
      const game = position(id, cards([7, 9]), new PokerPattern(1, 6, 1), level, 1, partner);
      const hand = game.state.piles[1].cards.slice(); game.poker.computerTurn(game.state);
      assert.deepEqual(game.state.piles[1].cards, hand); assert.equal(game.state.moves, 0);
      assert.equal(game.state.cursor, 2);
      const finish = position(id, cards([7]), new PokerPattern(1, 6, 1), level, 1, partner);
      finish.poker.computerTurn(finish.state); assert.equal(finish.state.piles[1].cards.length, 0);
      assert(finish.poker.valid(finish.state));
    }
    const easy = position(id, cards([7, 9]), new PokerPattern(1, 6, 1), 0, 1, id === 'guandan' ? 3 : 2);
    easy.poker.computerTurn(easy.state); assert.equal(easy.state.piles[1].cards.length, 1);
  }
});

test('difficulty changes decisions: combinations, group preservation, and public short-hand blocking', () => {
  const hand = cards([3, 4, 5, 6, 7, 12]);
  const easy = position('doudizhu', hand, new PokerPattern(), 0);
  const normal = position('doudizhu', hand, new PokerPattern(), 1);
  assert.equal(easy.poker.candidate(easy.state, 1).length, 1);
  assert.equal(normal.poker.candidate(normal.state, 1).length, 5);
  const groups = cards([8, 8, 8, 8, 9, 9, 10, 12]);
  const ordinary = position('doudizhu', groups, new PokerPattern(1, 3, 1), 1);
  const hard = position('doudizhu', groups, new PokerPattern(1, 3, 1), 2);
  // Give the visible opponent more cards, so this tests conservation rather than emergency blocking.
  for (const game of [ordinary, hard]) { game.state.piles[0].cards.push(game.state.piles[5].cards.pop(), game.state.piles[5].cards.pop()); }
  assert.equal(ordinary.poker.rank(ordinary.poker.candidate(ordinary.state, 1)[0]), 8);
  assert.equal(hard.poker.rank(hard.poker.candidate(hard.state, 1)[0]), 10);
  const low = position('doudizhu', cards([5, 9, 14]), new PokerPattern(1, 4, 1), 1);
  const block = position('doudizhu', cards([5, 9, 14]), new PokerPattern(1, 4, 1), 2);
  assert.equal(low.poker.rank(low.poker.candidate(low.state, 1)[0]), 5);
  assert.equal(block.poker.rank(block.poker.candidate(block.state, 1)[0]), 14);
});

test('candidate responses cover airplane wings, four-with-two, and rocket without rejecting a legal bomb', () => {
  const cases = [
    { hand: [5,5,5,6,6,6,8,9,12], last: new PokerPattern(9, 4, 8), kind: 9 },
    { hand: [5,5,5,6,6,6,8,8,9,9,12], last: new PokerPattern(10, 4, 10), kind: 10 },
    { hand: [6,6,6,6,8,9,12], last: new PokerPattern(11, 3, 6), kind: 11 },
    { hand: [6,6,6,6,8,8,9,9,12], last: new PokerPattern(12, 3, 8), kind: 12 }
  ];
  for (const entry of cases) {
    const game = position('doudizhu', cards(entry.hand), entry.last);
    const candidate = game.poker.candidate(game.state, 1);
    const pattern = game.poker.pattern(candidate, false, entry.last);
    assert.equal(pattern.kind, entry.kind); assert(game.poker.beats(pattern, entry.last));
  }
  const rocket = position('doudizhu', [52, 53, card(3)], new PokerPattern(13, 15, 4, 40));
  const candidate = rocket.poker.candidate(rocket.state, 1);
  assert.deepEqual(candidate, [52, 53]); rocket.poker.computerTurn(rocket.state);
  assert.equal(played(rocket).kind, 14); assert(rocket.poker.valid(rocket.state));
});

test('guandan finds low-A runs, suited flushes, missing ranks with either wildcard count, and wild full houses', () => {
  const ace = position('guandan', [card(14,0),card(2,0),card(3,2),card(4,3),card(5,0),card(9,1)]);
  assert.equal(ace.poker.pattern(ace.poker.candidate(ace.state, 1), true).kind, 6);
  const flush = position('guandan', [5,6,7,8,9].map(rank => card(rank, 2)).concat(card(12)), new PokerPattern(13, 4, 5, 50));
  assert.equal(flush.poker.pattern(flush.poker.candidate(flush.state, 1), true).kind, 15);
  for (const hand of [
    [card(3,0),card(4,2),card(6,3),card(7,0),14,card(12,1)],
    [card(3,0),card(4,2),card(7,3),14,68,card(12,0)]
  ]) {
    const game = position('guandan', hand, new PokerPattern(6, 6, 5));
    const candidate = game.poker.candidate(game.state, 1);
    assert.equal(candidate.length, 5); assert.equal(game.poker.pattern(candidate, true, game.poker.last(game.state)).kind, 6);
    assert.equal(new Set(candidate).size, candidate.length);
  }
  const house = position('guandan', cards([7,7,9,9,12]).concat(14), new PokerPattern(5, 5, 5));
  const candidate = house.poker.candidate(house.state, 1);
  assert.equal(house.poker.pattern(candidate, true, house.poker.last(house.state)).kind, 5);
});

test('hard choice uses only its own cards, played pattern and public counts', () => {
  for (const id of ['doudizhu', 'guandan']) {
    const game = position(id, cards([5, 9, 14]), new PokerPattern(1, 4, 1), 2);
    const choice = game.poker.candidate(game.state, 1);
    // Change hidden ranks while keeping every publicly visible hand count and the full deck intact.
    const hand = game.state.piles[0].cards; const discard = game.state.piles[5].cards;
    const previous = hand[0]; hand[0] = discard[0]; discard[0] = previous;
    assert.deepEqual(game.poker.candidate(game.state, 1), choice);
    assert(game.poker.valid(game.state));
  }
});

test('invalid actions, finished games, human-turn computer calls and illegal selected hands make no changes', () => {
  const game = start('doudizhu'); const p = game.poker; const s = game.state;
  for (const at of [-1, NaN, Infinity, 1.5, 1001, 899]) {
    const before = JSON.stringify(s); p.tap(s, at, false); assert.equal(JSON.stringify(s), before);
  }
  const before = JSON.stringify(s); p.computerTurn(s); assert.equal(JSON.stringify(s), before);
  assert.deepEqual(p.candidate(s, -1), []); assert.deepEqual(p.candidate(s, 3), []);
  s.tray = [s.piles[1].cards[0]]; const illegal = JSON.stringify(s); p.tap(s, 900, false);
  assert.equal(JSON.stringify(s), illegal);
  s.tray = []; s.outcome = 2; const finished = JSON.stringify(s); p.tap(s, 902); p.computerTurn(s);
  assert.equal(JSON.stringify(s), finished); assert.equal(p.needsComputerTurn(s), false);
});

let failures = 0;
for (const entry of tests) {
  try { entry.run(); console.log('PASS ' + entry.name); }
  catch (error) { failures++; console.error('FAIL ' + entry.name, error); }
}
console.log(`${tests.length - failures}/${tests.length} poker AI checks passed`);
process.exitCode = failures ? 1 : 0;
