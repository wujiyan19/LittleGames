/* Human/computer integration with the same controlled native services and clock
 * as the existing ViewModel regressions. Native ArkTS compilation is separate. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { fixture, Frames } = require('./test-performance.cjs');
const ids = ['doudizhu', 'guandan', 'mahjong', 'xiangqi', 'chess', 'ludo'];
const difficulties = ['easy', 'normal', 'hard'];
const tests = [];
const test = (name, run) => tests.push({ name, run });
const snapshot = vm => JSON.stringify(vm.state);

function game(id, level = 1, seed = 19) {
  const f = fixture(), frames = new Frames(), vm = f.vm('ExpansionViewModel');
  vm.init(id, frames);
  vm.model = new (f.rules('Expansion').ExpansionModel)(f.rng(seed));
  vm.model.deferComputerTurns = true;
  vm.difficulty = difficulties[level]; vm.startGame();
  assert.equal(vm.hasComputerOpponent(), true);
  assert.equal(vm.computerThinking, false);
  return { f, vm, frames };
}

function humanTurn(vm) {
  if (vm.state.id === 'chess') { vm.tap(52); vm.tap(36); }
  else if (vm.state.id === 'xiangqi') { vm.tap(54); vm.tap(45); }
  else if (['doudizhu', 'guandan'].includes(vm.state.id)) { vm.tap(902); vm.tap(900); }
  else if (vm.state.id === 'mahjong') {
    const tile = vm.state.piles[0].cards.at(-1); vm.tap(tile); vm.tap(tile);
  } else {
    let attempts = 0;
    while (!vm.computerThinking && attempts++ < 100) {
      vm.tap(900);
      if (vm.state.data[0]) {
        const token = vm.state.pieces.find(p => p.owner === 0 && p.x < 57 &&
          (p.x >= 0 || vm.state.data[0] === 6));
        assert(token); vm.tap(token.id);
      }
    }
  }
  assert.equal(vm.computerThinking, true, `${vm.state.id} hands the turn to a computer`);
}

function computerRound(f, vm) {
  let steps = 0;
  while (vm.computerThinking && steps++ < 100) {
    f.clock.advance(500); assert.equal(vm.model.valid(vm.state), true);
  }
  assert(steps < 100, 'computer eventually returns control or finishes');
  assert.equal(f.clock.count(), 0);
}

for (const id of ids) {
  for (let level = 0; level < 3; level++) {
    test(`${id}/${difficulties[level]}: each computer action waits and owns one timer`, () => {
      const { f, vm, frames } = game(id, level);
      humanTurn(vm);
      assert.equal(vm.state.level, level); assert(vm.computerPlayer >= 2);
      assert.equal(f.clock.count(), 1); assert.equal(frames.running, false);
      const waiting = snapshot(vm), moves = vm.state.moves;
      vm.tap(900); vm.tap(0); vm.choose(0); vm.action(); vm.activate();
      assert.equal(snapshot(vm), waiting);
      vm.onAppShown(); vm.onAppShown(); assert.equal(f.clock.count(), 1);
      f.clock.advance(499); assert.equal(snapshot(vm), waiting);
      f.clock.advance(1); assert.notEqual(snapshot(vm), waiting);
      assert(vm.state.moves - moves <= 1, 'one scheduled decision, including a pass');
      assert.equal(vm.model.valid(vm.state), true);
      assert.equal(f.clock.count(), vm.computerThinking ? 1 : 0);
      computerRound(f, vm); vm.dispose();
    });
  }

  test(`${id}: pause, background and exit confirmation suspend and resume once`, () => {
    for (const mode of ['pause', 'background', 'exit']) {
      const { f, vm } = game(id); humanTurn(vm); f.clock.advance(200);
      const waiting = snapshot(vm);
      if (mode === 'pause') vm.togglePause();
      else if (mode === 'background') vm.onAppHidden();
      else assert.equal(vm.requestBack(), true);
      assert.equal(f.clock.count(), 0); f.clock.advance(5000);
      assert.equal(snapshot(vm), waiting);
      vm.onAppShown(); vm.onAppShown();
      assert.equal(f.clock.count(), mode === 'background' ? 1 : 0);
      if (mode === 'pause') vm.togglePause();
      else if (mode === 'exit') vm.dismissExitConfirm();
      assert.equal(f.clock.count(), 1);
      f.clock.advance(499); assert.equal(snapshot(vm), waiting);
      f.clock.advance(1); assert.notEqual(snapshot(vm), waiting);
      vm.dispose(); const disposed = snapshot(vm); assert.equal(f.clock.count(), 0);
      f.clock.advance(5000); assert.equal(snapshot(vm), disposed);
    }
  });

  test(`${id}: undo, restart and difficulty changes cancel stale replies`, () => {
    const { f, vm } = game(id); humanTurn(vm);
    vm.undo(); assert.equal(vm.computerThinking, false); assert.equal(f.clock.count(), 0);
    const undone = snapshot(vm); f.clock.advance(1000); assert.equal(snapshot(vm), undone);
    vm.startGame(); humanTurn(vm); computerRound(f, vm);
    vm.undo(); assert.equal(vm.computerThinking, false); assert.equal(f.clock.count(), 0);
    const undoneRound = snapshot(vm); f.clock.advance(1000); assert.equal(snapshot(vm), undoneRound);
    vm.startGame(); humanTurn(vm); vm.startGame();
    assert.equal(vm.computerThinking, false); assert.equal(f.clock.count(), 0);
    const restarted = snapshot(vm); f.clock.advance(1000); assert.equal(snapshot(vm), restarted);
    humanTurn(vm); vm.changeDifficulty('hard');
    assert.equal(vm.state.level, 2); assert.equal(vm.computerThinking, false);
    const changed = snapshot(vm); f.clock.advance(1000); assert.equal(snapshot(vm), changed);
    vm.dispose();
  });

  test(`${id}: continuation restores pending replies without serializing timers`, () => {
    for (const paused of [false, true]) {
      const source = game(id, 2), target = game(id, 0, 8);
      humanTurn(source.vm); if (paused) source.vm.togglePause();
      const payload = source.vm.exportContinuation(), expected = snapshot(source.vm);
      assert.equal(target.vm.importContinuation(payload), true);
      assert.equal(snapshot(target.vm), expected); assert.equal(target.vm.difficulty, 'hard');
      assert.equal(target.vm.computerThinking, true); assert.equal(target.vm.canUndo, false);
      assert.equal(target.f.clock.count(), paused ? 0 : 1);
      target.vm.onAppShown(); target.vm.onAppShown();
      assert.equal(target.f.clock.count(), paused ? 0 : 1);
      if (paused) {
        target.f.clock.advance(5000); assert.equal(snapshot(target.vm), expected);
        target.vm.togglePause(); assert.equal(target.f.clock.count(), 1);
      }
      target.f.clock.advance(499); assert.equal(snapshot(target.vm), expected);
      target.f.clock.advance(1); assert.notEqual(snapshot(target.vm), expected);
      computerRound(target.f, target.vm); source.vm.dispose(); target.vm.dispose();
    }
  });

  test(`${id}: rejected continuation keeps the current pending reply`, () => {
    const { f, vm } = game(id); humanTurn(vm);
    const waiting = vm.exportContinuation(), malformed = JSON.parse(waiting);
    malformed.state.level = 3;
    for (const payload of ['null', '{}', '{bad', JSON.stringify(malformed)]) {
      assert.equal(vm.importContinuation(payload), false);
      assert.equal(vm.exportContinuation(), waiting); assert.equal(f.clock.count(), 1);
    }
    f.clock.advance(500); assert.notEqual(vm.exportContinuation(), waiting); vm.dispose();
  });

  test(`${id}: a new continuation target created in the background waits for foreground`, () => {
    const source = game(id), target = game(id);
    humanTurn(source.vm);
    const bus = target.f.load('entry/src/main/ets/common/GameLifecycleBus.ets').GameLifecycleBus;
    bus.notifyHidden(); bus.attach(target.vm);
    assert.equal(target.vm.importContinuation(source.vm.exportContinuation()), true);
    const waiting = snapshot(target.vm);
    assert.equal(target.vm.computerThinking, true); assert.equal(target.f.clock.count(), 0);
    target.vm.onAppShown(); target.f.clock.advance(5000);
    assert.equal(snapshot(target.vm), waiting); assert.equal(target.f.clock.count(), 0);
    bus.notifyShown(); bus.notifyShown();
    target.f.clock.advance(499); assert.equal(snapshot(target.vm), waiting);
    target.f.clock.advance(1); assert.notEqual(snapshot(target.vm), waiting);
    bus.detach(target.vm); target.vm.dispose(); source.vm.dispose();
    assert.equal(target.f.clock.count(), 0);
  });
}

function mahjongClaim(vm) {
  const s = vm.model.state, remaining = Array.from({ length: 136 }, (_, i) => i);
  for (const pile of s.piles) pile.cards = [];
  const take = type => {
    const at = remaining.findIndex(card => Math.floor(card / 4) === type);
    assert(at >= 0); return remaining.splice(at, 1)[0];
  };
  s.piles[0].cards = [0, 0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 27, 29].map(take);
  s.piles[8].cards = [take(0)];
  for (let seat = 1; seat < 4; seat++) {
    for (let i = 0; i < 13; i++) s.piles[seat].cards.push(remaining.splice((i * 7) % remaining.length, 1)[0]);
  }
  const used = s.piles.flatMap(pile => pile.cards);
  s.board = [...used, ...remaining]; s.cursor = used.length; s.next = 2;
  s.data = [1, 1, s.piles[8].cards[0] + 1, 0, 0, 0, 0, 0]; s.selected = -1;
  assert.equal(vm.model.valid(s), true); vm.sync(false);
}

test('Mahjong: claim prompts stop the clock until the human passes or claims', () => {
  const { f, vm } = game('mahjong'); mahjongClaim(vm);
  const waiting = snapshot(vm); assert.equal(vm.mahjongCan(901), true);
  assert.equal(vm.computerThinking, false); assert.equal(f.clock.count(), 0);
  f.clock.advance(5000); assert.equal(snapshot(vm), waiting);
  vm.tap(907); assert.equal(vm.computerThinking, true); assert.equal(f.clock.count(), 1);
  computerRound(f, vm); vm.dispose();

  const claimed = game('mahjong'); mahjongClaim(claimed.vm); claimed.vm.tap(901);
  assert.equal(claimed.vm.state.next, 0); assert.equal(claimed.vm.state.data[4], 1);
  assert.equal(claimed.vm.state.piles[0].cards.length, 11);
  assert.equal(claimed.vm.computerThinking, false); assert.equal(claimed.f.clock.count(), 0);
  claimed.vm.dispose();
});

test('Mahjong: old automatic saves keep the drawn human hand and new pending saves stay pending', () => {
  const old = game('mahjong'), target = game('mahjong');
  const payload = JSON.parse(old.vm.exportContinuation()); payload.state.next = 1;
  assert.equal(target.vm.importContinuation(JSON.stringify(payload)), true);
  assert.equal(target.vm.state.next, 0); assert.equal(target.vm.computerThinking, false);
  const hand = snapshot(target.vm); target.f.clock.advance(2000); assert.equal(snapshot(target.vm), hand);
  humanTurn(old.vm); assert.equal(target.vm.importContinuation(old.vm.exportContinuation()), true);
  assert.equal(target.vm.state.next, 1); assert.equal(target.vm.state.piles[0].cards.length, 13);
  assert.equal(target.vm.computerThinking, true); assert.equal(target.f.clock.count(), 1);
  old.vm.dispose(); target.vm.dispose();
});

test('Mahjong: old saves with declared melds and active claim windows are distinguished', () => {
  const source = game('mahjong'), target = game('mahjong'); mahjongClaim(source.vm);
  const claim = source.vm.exportContinuation();
  assert.equal(target.vm.importContinuation(claim), true);
  assert.equal(target.vm.state.next, 2); assert.equal(target.vm.state.data[0], 1);
  assert.equal(target.vm.computerThinking, false);
  source.vm.tap(901);
  const old = JSON.parse(source.vm.exportContinuation()); old.state.next = 1;
  assert.equal(target.vm.importContinuation(JSON.stringify(old)), true);
  assert.equal(target.vm.state.next, 0); assert.equal(target.vm.state.piles[0].cards.length, 11);
  assert.equal(target.vm.computerThinking, false); assert.equal(target.f.clock.count(), 0);
  source.vm.dispose(); target.vm.dispose();
});

test('Ludo: a computer win removes the timer and rejects further input', () => {
  const { f, vm } = game('ludo');
  const { ExpansionCards } = f.load('entry/src/main/ets/model/game/ExpansionCards.ets');
  vm.model.cards = new ExpansionCards({ next: () => 0 });
  const s = vm.model.state; s.next = 2;
  for (let id = 4; id < 8; id++) s.pieces[id].x = 57;
  s.pieces[4].x = 56; vm.sync(false);
  assert.equal(f.clock.count(), 1); f.clock.advance(500);
  assert.equal(vm.state.outcome, 2); assert.equal(vm.isFinished, true);
  assert.equal(vm.computerThinking, false); assert.equal(f.clock.count(), 0);
  const ended = snapshot(vm); f.clock.advance(5000); vm.tap(900); vm.choose(0);
  assert.equal(snapshot(vm), ended); assert.equal(vm.model.valid(vm.state), true); vm.dispose();
});

test('The six identities and turn messages have complete localized resources', () => {
  const root = path.resolve(__dirname, '..');
  const panel = fs.readFileSync(path.join(root, 'entry/src/main/ets/components/ComputerOpponentPanel.ets'), 'utf8');
  const board = fs.readFileSync(path.join(root, 'entry/src/main/ets/pages/collection/ExpansionCardBoard.ets'), 'utf8');
  const page = fs.readFileSync(path.join(root, 'entry/src/main/ets/pages/collection/ExpansionPage.ets'), 'utf8');
  const names = [...panel.matchAll(/app\.string\.(computer_\w+)/g),
    ...board.matchAll(/app\.string\.(computer_\w+)/g)].map(match => match[1]);
  assert(page.includes('ComputerOpponentPanel({')); assert(page.includes('vm.hasComputerOpponent()'));
  assert.equal(panel.includes("id('computer-turn-status')"), true);
  for (const locale of ['base', 'zh_CN', 'en_US']) {
    const entries = JSON.parse(fs.readFileSync(path.join(root, `entry/src/main/resources/${locale}/element/string.json`))).string;
    const strings = new Map(entries.map(entry => [entry.name, entry.value]));
    assert.equal(strings.size, entries.length, `${locale} has unique string names`);
    for (const name of names) assert(strings.get(name)?.length, `${locale}:${name}`);
    for (const id of ids) assert(strings.get(`computer_${id}`)?.length, `${locale}:${id}`);
    for (const name of ['computer_thinking', 'computer_hand_count', 'computer_last_play']) {
      assert(strings.get(name).includes('%d'), `${locale}:${name} retains seat placeholders`);
    }
  }
});

test('Same-screen LAN games and solitaire do not schedule computer opponents', () => {
  for (const id of ['dots', 'tug', 'spider', 'freecell', 'solitaire']) {
    const f = fixture(), vm = f.vm('ExpansionViewModel'); vm.init(id); vm.startGame();
    assert.equal(vm.hasComputerOpponent(), false); assert.equal(vm.computerThinking, false);
    assert.equal(f.clock.count(), 0); vm.dispose();
  }
});

let failed = 0;
for (const entry of tests) {
  try { entry.run(); }
  catch (error) { failed++; console.error(`FAIL ${entry.name}\n${error.stack}`); }
}
console.log(`${tests.length - failed}/${tests.length} computer opponent integration checks passed.`);
process.exitCode = failed ? 1 : 0;
