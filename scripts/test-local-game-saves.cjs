/* Real ViewModel snapshots and Preferences contract, with independent process fixtures. */
const assert = require('node:assert/strict');
const { fixture } = require('./test-performance.cjs');
const tests = [];
const test = (name, run) => tests.push({ name, run });
const restart = f => { const next = fixture(Object.fromEntries(f.values)); next.data().init({}); return next; };
const create = (name, seed = 7) => {
  const f = fixture(); f.data().init({}); const vm = f.vm(name + 'ViewModel', f.rng(seed));
  if (name === 'Sudoku') vm.newGame(); else vm.startGame();
  return { f, vm };
};
const editSudoku = vm => {
  const index = vm.board.findIndex((value, i) => !vm.isFixed(Math.floor(i / 9), i % 9));
  vm.selectCell(Math.floor(index / 9), index % 9); vm.setNumber(5); return index;
};

for (const name of ['Game2048', 'Sudoku']) {
  const id = name === 'Game2048' ? '2048' : 'sudoku';
  test(`${name}: exact board and difficulty survive a new process and explicit resume`, () => {
    const { f, vm } = create(name); vm.difficulty = 'hard';
    if (name === 'Sudoku') { vm.newGame(); editSudoku(vm); }
    else { vm.swipeLeft(); vm.swipeDown(); vm.swipeRight(); }
    vm.onAppHidden(); const snapshot = vm.exportContinuation(); const scores = f.data().getGameById(id).highScore;
    const next = restart(f), restored = next.vm(name + 'ViewModel', next.rng(99));
    assert.equal(restored.offerSavedGame(), true); assert.equal(restored.resumePending, true);
    assert.equal(restored.isPlayTimeActive(), false); assert.equal(restored.exportContinuation(), snapshot);
    assert.equal(next.data().getGameById(id).highScore, scores);
    restored.continueSavedGame(); assert.equal(restored.isPlayTimeActive(), true);
    assert.equal(restored.exportContinuation(), snapshot);
    restored.continueSavedGame(); assert.equal(next.data().getGameById(id).highScore, scores);
  });
  test(`${name}: pending choice blocks input and leaving it preserves the saved game`, () => {
    const { f, vm } = create(name); vm.onAppHidden(); const next = restart(f);
    const target = next.vm(name + 'ViewModel', next.rng(99)); target.offerSavedGame();
    const snapshot = target.exportContinuation();
    if (name === 'Sudoku') { target.selectCell(0, 0); target.setNumber(9); target.erase(); }
    else assert.equal(target.swipeLeft(), false);
    target.changeDifficulty('hard'); assert.equal(target.exportContinuation(), snapshot);
    assert.equal(target.requestBack(), false); target.dispose();
    assert.equal(next.data().getSavedGame(id), f.data().getSavedGame(id));
  });
  test(`${name}: malformed, wrong-version, oversized and wrong-game saves fall back safely`, () => {
    const { f, vm } = create(name); const valid = JSON.parse(vm.exportContinuation());
    const wrongVersion = { ...valid, version: 2 };
    const wrongStatus = { ...valid, status: 'over' };
    const other = create(name === 'Game2048' ? 'Sudoku' : 'Game2048').vm.exportContinuation();
    for (const payload of ['null', '{}', '{broken', JSON.stringify(wrongVersion), JSON.stringify(wrongStatus), other, 'x'.repeat(8193)]) {
      const next = fixture({ [id === '2048' ? 'savedGame2048' : 'savedGameSudoku']: payload }); next.data().init({});
      const target = next.vm(name + 'ViewModel', next.rng(4)); const before = target.exportContinuation();
      assert.equal(target.offerSavedGame(), false, payload.slice(0, 50));
      assert.equal(target.saveRestoreFailed, true); assert.equal(target.exportContinuation(), before);
      assert.equal(next.data().getSavedGame(id), '');
    }
  });
  test(`${name}: preference reset preserves saves; data clearing removes them permanently`, () => {
    const { f, vm } = create(name); vm.onAppHidden(); const payload = f.data().getSavedGame(id);
    f.data().resetSettings(); assert.equal(f.data().getSavedGame(id), payload);
    f.data().clearPlayData(); vm.onAppHidden(); vm.dispose();
    assert.equal(f.data().getSavedGame(id), ''); assert.equal(restart(f).data().getSavedGame(id), '');
  });
  test(`${name}: replayed session does not replay accumulated time or history entries`, () => {
    const { f, vm } = create(name); f.data().recordGamePlayed(id); f.data().addPlayTime(id, 12345); vm.onAppHidden();
    const next = restart(f), restored = next.vm(name + 'ViewModel', next.rng(1));
    restored.offerSavedGame(); restored.continueSavedGame(); restored.onAppHidden();
    assert.equal(next.data().getGameById(id).playTimeMs, 12345);
    assert.equal(next.data().getPlayHistory().filter(record => record.game.id === id).length, 1);
  });
}

test('independent saves coexist and ordinary settings writes preserve both', () => {
  const { f, vm } = create('Game2048'); vm.swipeLeft();
  const sudoku = f.vm('SudokuViewModel', f.rng(6)); sudoku.newGame(); editSudoku(sudoku);
  const first = f.data().getSavedGame('2048'), second = f.data().getSavedGame('sudoku');
  f.data().setSetting('hapticsEnabled', false); const next = restart(f);
  assert.equal(next.data().getSavedGame('2048'), first); assert.equal(next.data().getSavedGame('sudoku'), second);
  next.data().setSavedGame('withdrawn', 'not-a-game'); assert.equal(next.data().getSavedGame('withdrawn'), '');
});
test('2048: choosing a new round replaces the old board and resets only this round score', () => {
  const { f, vm } = create('Game2048'); for (let i = 0; i < 8; i++) { vm.swipeLeft(); vm.swipeDown(); }
  vm.onAppHidden(); const next = restart(f), target = next.vm('Game2048ViewModel', next.rng(100));
  target.offerSavedGame(); const high = target.highScore; target.startGame();
  assert.equal(target.resumePending, false); assert.equal(target.score, 0); assert.equal(target.highScore, high);
  assert.equal(target.board.flat().filter(value => value !== 0).length, 2);
  target.onAppHidden(); assert.equal(next.data().getSavedGame('2048'), target.exportContinuation());
});
test('2048: loss clears the saved board and restart remains available', () => {
  const { f, vm } = create('Game2048');
  vm.board = [[2,4,8,16],[32,64,128,256],[512,1024,2,4],[8,16,32,0]];
  vm.saveCurrentGame(); assert.equal(vm.swipeRight(), true); assert.equal(vm.status, 'over');
  vm.onAppHidden(); assert.equal(restart(f).data().getSavedGame('2048'), '');
  vm.startGame(); assert.ok(f.data().getSavedGame('2048').length > 0);
});
test('2048: terminal and empty boards cannot masquerade as resumable games', () => {
  const { f, vm } = create('Game2048'); const s = JSON.parse(vm.exportContinuation());
  for (const board of [Array.from({length:4}, () => [0,0,0,0]), [[2,4,8,16],[32,64,128,256],[512,1024,2,4],[8,16,32,64]]]) {
    f.data().setSavedGame('2048', JSON.stringify({ ...s, board })); assert.equal(vm.offerSavedGame(), false);
  }
});
test('Sudoku: erasing and restarting retain the original puzzle and its difficulty', () => {
  const { f, vm } = create('Sudoku'); vm.difficulty = 'hard'; vm.newGame(); const puzzle = vm.board.slice();
  const index = editSudoku(vm); vm.erase(); assert.equal(vm.board[index], 0);
  vm.onAppHidden(); const next = restart(f), target = next.vm('SudokuViewModel', next.rng(100));
  assert.equal(target.offerSavedGame(), true); target.continueSavedGame(); target.restartGame();
  assert.deepEqual(target.board, puzzle); assert.equal(target.difficulty, 'hard');
});
test('Sudoku: completed games award once, clear saves and cannot be erased afterward', () => {
  const { f, vm } = create('Sudoku'); const rules = new (f.rules('Sudoku').SudokuRules)();
  const solution = rules.generateSolution(f.rng(22)); const puzzle = solution.slice(); puzzle[0] = 0;
  const state = { version:1, board:puzzle, puzzle, fixed:puzzle.map(value => value !== 0), previousKey:puzzle.join(''),
    selectedRow:0, selectedCol:0, status:'playing', difficulty:'hard' };
  assert.equal(vm.importContinuation(JSON.stringify(state)), true); vm.setNumber(solution[0]);
  assert.equal(vm.status, 'over'); assert.equal(f.data().getGameById('sudoku').highScore, 300);
  vm.erase(); vm.setNumber(solution[0]); assert.deepEqual(vm.board, solution);
  vm.onAppHidden(); assert.equal(restart(f).data().getSavedGame('sudoku'), '');
});
test('Sudoku: async new game saves only its completed generation, late results cannot replace it', async () => {
  const { f, vm } = create('Sudoku'); const old = f.data().getSavedGame('sudoku');
  const puzzle = vm.board.slice(); const first = vm.newGameAsync(), second = vm.newGameAsync();
  assert.equal(f.data().getSavedGame('sudoku'), old);
  f.tasks[1].resolve(puzzle); await second; const current = vm.exportContinuation();
  assert.equal(f.data().getSavedGame('sudoku'), current);
  f.tasks[0].resolve(Array(81).fill(0)); await first; assert.equal(vm.exportContinuation(), current);
});
test('Sudoku: failed generation leaves the previous valid save available for reopening', async () => {
  const { f, vm } = create('Sudoku'); editSudoku(vm); vm.onAppHidden(); const before = f.data().getSavedGame('sudoku');
  const pending = vm.newGameAsync(); f.tasks[0].reject(new Error('generation failed')); await pending; vm.dispose();
  assert.equal(restart(f).data().getSavedGame('sudoku'), before);
});
test('save writes debounce and a failed synchronous flush can be retried', () => {
  const { f, vm } = create('Game2048'); vm.swipeLeft(); vm.swipeDown(); assert.equal(f.store.writes, 0);
  const original = f.store.flushSync; f.store.flushSync = () => { throw new Error('disk failure'); };
  vm.onAppHidden(); f.store.flushSync = original; f.data().flushNow(); assert.ok(f.store.synchronousFlushes > 0);
  assert.equal(restart(f).data().getSavedGame('2048'), vm.exportContinuation());
});
test('Sudoku: clearing data during generation prevents a late task resurrecting a save', async () => {
  const { f, vm } = create('Sudoku'); const puzzle = vm.board.slice(); const pending = vm.newGameAsync();
  f.data().clearPlayData(); f.tasks[0].resolve(puzzle); await pending; vm.onAppHidden();
  assert.equal(restart(f).data().getSavedGame('sudoku'), '');
  vm.restartGame(); vm.onAppHidden(); assert.ok(restart(f).data().getSavedGame('sudoku').length > 0);
});

(async () => {
  let passed = 0;
  for (const t of tests) { try { await t.run(); passed++; } catch (error) { console.error('FAIL', t.name, error); } }
  console.log(`${passed}/${tests.length} local-save regressions passed.`);
  if (passed !== tests.length) process.exitCode = 1;
})();
