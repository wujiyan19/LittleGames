/* Independent generation and difficulty audit. Runs the actual ArkTS model code;
 * native UI compilation and real-device checks are separate validation steps. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { fixture } = require('./test-performance.cjs');
const f = fixture();
const tests = [];
const details = {};
const test = (name, run) => tests.push({ name, run });
const difficulties = ['easy', 'normal', 'hard'];
const { CollectionModel, COLLECTION_IDS } = f.rules('Collection');
const create = (id, level, seed) => {
  const model = new CollectionModel(f.rng(seed)); model.start(id, level); return model;
};
const bounded = (value, budget = 10000) => {
  let calls = 0;
  return { next() { assert(++calls <= budget, 'random generation exceeded its finite work budget'); return value; } };
};
function neighbors(at, cols, length) {
  const r = Math.floor(at / cols), c = at % cols;
  return [r > 0 ? at - cols : -1, c + 1 < cols ? at + 1 : -1,
    at + cols < length ? at + cols : -1, c > 0 ? at - 1 : -1].filter(n => n >= 0);
}
function mazePath(s) {
  const q = [s.cursor], previous = new Map([[s.cursor, -1]]);
  for (let i = 0; i < q.length; i++) {
    for (const n of neighbors(q[i], s.cols, s.board.length)) {
      if (s.board[n] === 0 && !previous.has(n)) { previous.set(n, q[i]); q.push(n); }
    }
  }
  assert(previous.has(s.answer), 'maze exit is unreachable');
  assert.equal(previous.size, s.board.filter(v => v === 0).length, 'maze has isolated floor cells');
  const result = [];
  for (let at = s.answer; at !== s.cursor; at = previous.get(at)) result.unshift(at);
  return result;
}
function slideParity(board, size) {
  assert.equal(board.length, size * size);
  assert.deepEqual(board.slice().sort((a, b) => a - b), Array.from({ length: size * size }, (_, i) => i));
  let inversions = 0;
  for (let i = 0; i < board.length; i++) for (let j = i + 1; j < board.length; j++) {
    if (board[i] && board[j] && board[i] > board[j]) inversions++;
  }
  const row = size - Math.floor(board.indexOf(0) / size);
  return size % 2 ? inversions % 2 === 0 : (inversions + row) % 2 === 1;
}
// The solver computes occupancy and unit moves independently of KlotskiRules.
function solveKlotski(blocks) {
  const groups = blocks.map(b => b.target ? 'target' : b.w + ',' + b.h);
  const kinds = [...new Set(groups)];
  const key = positions => kinds.map(g => positions.filter((p, i) => groups[i] === g)
    .sort((a, b) => a - b).join(',')).join('|');
  const initial = blocks.map(b => b.y * 4 + b.x);
  const q = [{ positions: initial, parent: -1, move: null, depth: 0 }], seen = new Set([key(initial)]);
  const target = blocks.findIndex(b => b.target);
  for (let qi = 0; qi < q.length; qi++) {
    const current = q[qi];
    if (current.positions[target] === 13) {
      const moves = [];
      for (let at = qi; q[at].parent >= 0; at = q[at].parent) moves.unshift(q[at].move);
      return { depth: current.depth, moves, visited: seen.size };
    }
    const board = Array(20).fill(-1);
    current.positions.forEach((p, i) => {
      const b = blocks[i]; assert(p % 4 + b.w <= 4 && Math.floor(p / 4) + b.h <= 5);
      for (let dr = 0; dr < b.h; dr++) for (let dc = 0; dc < b.w; dc++) {
        assert.equal(board[p + dr * 4 + dc], -1, 'overlapping Klotski pieces'); board[p + dr * 4 + dc] = i;
      }
    });
    for (let i = 0; i < blocks.length; i++) {
      const b = blocks[i], x = current.positions[i] % 4, y = Math.floor(current.positions[i] / 4);
      for (const [dx, dy] of [[0, -1], [1, 0], [0, 1], [-1, 0]]) {
        const nx = x + dx, ny = y + dy;
        if (nx < 0 || ny < 0 || nx + b.w > 4 || ny + b.h > 5) continue;
        let legal = true;
        for (let dr = 0; dr < b.h; dr++) for (let dc = 0; dc < b.w; dc++) {
          const at = (ny + dr) * 4 + nx + dc; if (board[at] !== -1 && board[at] !== i) legal = false;
        }
        if (!legal) continue;
        const positions = current.positions.slice(); positions[i] = ny * 4 + nx;
        const k = key(positions);
        if (!seen.has(k)) { seen.add(k); q.push({ positions, parent: qi, move: { id: b.id, dx, dy }, depth: current.depth + 1 }); }
      }
    }
    assert(seen.size <= 500000, 'Klotski solver exceeded audit budget');
  }
  assert.fail('Klotski layout has no legal solution');
}
// Independent Sudoku solver: candidate sets, duplicate validation, stop after two solutions.
function sudokuSolutions(input) {
  if (input.length !== 81 || input.some(v => !Number.isInteger(v) || v < 0 || v > 9)) return 0;
  const board = input.slice();
  const peers = i => [...new Set(Array.from({ length: 9 }, (_, j) => Math.floor(i / 9) * 9 + j)
    .concat(Array.from({ length: 9 }, (_, j) => j * 9 + i % 9),
      Array.from({ length: 9 }, (_, j) => Math.floor(i / 27) * 27 + Math.floor(i % 9 / 3) * 3 + Math.floor(j / 3) * 9 + j % 3)))].filter(j => j !== i);
  const allPeers = Array.from({ length: 81 }, (_, i) => peers(i));
  if (board.some((v, i) => v && allPeers[i].some(j => board[j] === v))) return 0;
  let count = 0;
  function search() {
    if (count >= 2) return;
    let cell = -1, choices = null;
    for (let i = 0; i < 81; i++) if (!board[i]) {
      const used = new Set(allPeers[i].map(j => board[j]));
      const options = [1, 2, 3, 4, 5, 6, 7, 8, 9].filter(v => !used.has(v));
      if (!options.length) return;
      if (!choices || options.length < choices.length) { cell = i; choices = options; if (options.length === 1) break; }
    }
    if (cell < 0) { count++; return; }
    for (const v of choices) { board[cell] = v; search(); board[cell] = 0; if (count >= 2) return; }
  }
  search(); return count;
}
function solveLights(m) {
  const s = m.state, size = s.board.length;
  assert(s.board.some(Boolean), 'lights starts completed');
  const rows = s.board.map((v, i) => Array.from({ length: size + 1 }, (_, j) =>
    j === size ? v : Number(i === j || neighbors(j, s.cols, size).includes(i))));
  let rank = 0; const pivots = [];
  for (let col = 0; col < size; col++) {
    const found = rows.findIndex((r, i) => i >= rank && r[col]); if (found < 0) continue;
    [rows[rank], rows[found]] = [rows[found], rows[rank]];
    for (let i = 0; i < size; i++) if (i !== rank && rows[i][col]) for (let j = col; j <= size; j++) rows[i][j] ^= rows[rank][j];
    pivots.push(col); rank++;
  }
  assert(rows.slice(rank).every(r => r[size] === 0), 'lights has no solution');
  for (let i = 0; i < rank; i++) if (rows[i][size]) m.tap(pivots[i]);
  assert.equal(m.state.outcome, 1);
}
function solvePeg(m) {
  const seen = new Set();
  function search(board) {
    if (board.filter(v => v === 1).length === 1) return [];
    const key = board.join(','); if (seen.has(key)) return null; seen.add(key);
    for (let at = 0; at < board.length; at++) if (board[at] === 1) {
      for (const mid of neighbors(at, 5, 25)) {
        const end = 2 * mid - at;
        if (!neighbors(mid, 5, 25).includes(end) || board[mid] !== 1 || board[end] !== 0) continue;
        const next = board.slice(); next[at] = next[mid] = 0; next[end] = 1;
        const result = search(next); if (result) return [[at, end], ...result];
      }
    }
    return null;
  }
  const route = search(m.state.board); assert(route && route.length > 0, 'peg has no legal solution');
  for (const [at, end] of route) { m.tap(at); m.tap(end); }
  assert.equal(m.state.outcome, 1);
}
function floodRegion(board, cols) {
  const q = [0], seen = new Set(q);
  for (let i = 0; i < q.length; i++) for (const n of neighbors(q[i], cols, board.length)) {
    if (board[n] === board[0] && !seen.has(n)) { q.push(n); seen.add(n); }
  }
  return q;
}
function solveFlood(m) {
  assert(new Set(m.state.board).size > 1, 'flood starts completed');
  while (!m.state.outcome) {
    const s = m.state, region = floodRegion(s.board, s.cols);
    let best = -1, size = -1;
    for (let color = 0; color < 4; color++) if (color !== s.board[0]) {
      const trial = s.board.slice(); for (const at of region) trial[at] = color;
      const gained = floodRegion(trial, s.cols).length;
      if (gained > size) { best = color; size = gained; }
    }
    const oldSize = region.length; m.choose(best);
    assert(floodRegion(m.state.board, s.cols).length > oldSize, 'flood does not advance');
  }
  assert.equal(m.state.outcome, 1, 'flood move limit excludes its verified solution');
}

for (let level = 0; level < 3; level++) {
  test(`maze/${difficulties[level]}: 1000 connected boards, legal finish and reversible dead ends`, () => {
    let deadEnds = 0, shortest = Infinity, longest = 0;
    for (let seed = 1; seed <= 1000; seed++) {
      const m = create('maze', level, seed), s = m.state;
      assert.equal(s.cols, 7 + level * 2); assert.equal(s.board[s.cursor], 0); assert.equal(s.board[s.answer], 0);
      const route = mazePath(s); shortest = Math.min(shortest, route.length); longest = Math.max(longest, route.length);
      for (let at = 0; at < s.board.length; at++) {
        if (s.board[at] || at === s.cursor || at === s.answer) continue;
        const exits = neighbors(at, s.cols, s.board.length).filter(n => s.board[n] === 0);
        if (exits.length === 1) {
          deadEnds++; const cursor = s.cursor, moves = s.moves;
          s.cursor = exits[0]; m.tap(at); assert.equal(s.cursor, at); m.tap(exits[0]); assert.equal(s.cursor, exits[0]);
          s.cursor = cursor; s.moves = moves;
        }
      }
      for (const at of route) m.tap(at);
      assert.equal(m.state.outcome, 1); const result = JSON.stringify(m.state); m.tap(0); assert.equal(JSON.stringify(m.state), result);
    }
    details[`maze/${difficulties[level]}`] = { boards: 1000, deadEnds, shortest, longest };
  });
  test(`slide/${difficulties[level]}: 500 valid, solvable, unfinished boards and bounded random sources`, () => {
    const size = 3 + level, rules = new (f.rules('SlidePuzzle').SlidePuzzleRules)(size);
    for (let seed = 1; seed <= 500; seed++) {
      const board = rules.shuffle(f.rng(seed)); assert(slideParity(board, size)); assert(!rules.isSolved(board));
    }
    for (const value of [0, 0.5, 0.999999]) {
      const board = rules.shuffle(bounded(value)); assert(slideParity(board, size)); assert(!rules.isSolved(board));
    }
    // First shuffle swaps 1/2; every subsequent shuffle is the identity permutation.
    let calls = 0;
    const board = rules.shuffle({ next() { return calls++ === size * size - 2 ? 0 : 0.999999; } });
    assert(slideParity(board, size), 'retry exhaustion returned an unsolvable puzzle');
  });
  test(`mines/${difficulties[level]}: 100 seeds × all 81 first cells preserve count, clues and safe opening`, () => {
    const rules = new (f.rules('Minesweeper').MinesweeperRules)(9, 9), count = [8, 10, 14][level];
    for (let seed = 1; seed <= 100; seed++) for (let first = 0; first < 81; first++) {
      const r = Math.floor(first / 9), c = first % 9, board = rules.placeMines(rules.emptyBoard(), count, r, c, f.rng(seed));
      assert.equal(board.flat().filter(v => v === -1).length, count); assert.equal(board[r][c], 0);
      for (let y = 0; y < 9; y++) for (let x = 0; x < 9; x++) {
        if (Math.abs(y - r) <= 1 && Math.abs(x - c) <= 1) assert.notEqual(board[y][x], -1);
        if (board[y][x] === -1) continue;
        let adjacent = 0;
        for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) if (board[y + dy]?.[x + dx] === -1) adjacent++;
        assert.equal(board[y][x], adjacent);
      }
    }
    for (const value of [0, 0.5, 0.999999]) {
      const board = rules.placeMines(rules.emptyBoard(), count, 0, 0, bounded(value));
      assert.equal(board.flat().filter(v => v === -1).length, count);
    }
  });
  test(`peg/${difficulties[level]}: 300 seeds have the requested move depth`, () => {
    for (let seed = 1; seed <= 300; seed++) {
      const m = create('peg', level, seed); assert.equal(m.state.board.filter(v => v === 1).length, 5 + level); solvePeg(m);
    }
    for (const value of [0, 0.5, 0.999999]) {
      const m = new CollectionModel(bounded(value)); m.start('peg', level); assert.equal(m.state.board.filter(v => v === 1).length, 5 + level); solvePeg(m);
    }
  });
  test(`lights and flood/${difficulties[level]}: 300 seeds and repeated random sources finish within their rules`, () => {
    for (let seed = 1; seed <= 300; seed++) { solveLights(create('lights', level, seed)); solveFlood(create('flood', level, seed)); }
    for (const value of [0, 0.5, 0.999999]) for (const id of ['lights', 'flood']) {
      const m = new CollectionModel(bounded(value)); m.start(id, level); if (id === 'lights') solveLights(m); else solveFlood(m);
    }
  });
  test(`sudoku/${difficulties[level]}: 50 independently unique puzzles, fixed clues and no consecutive duplicate`, () => {
    const rules = new (f.rules('Sudoku').SudokuRules)(); let previous = '', min = 81, max = 0;
    for (let seed = 1; seed <= 50; seed++) {
      const result = rules.generatePuzzle(difficulties[level], previous, f.rng(seed));
      assert.equal(sudokuSolutions(result.puzzle), 1); assert.equal(result.key, result.puzzle.join('')); assert.notEqual(result.key, previous);
      previous = result.key; const clues = result.puzzle.filter(v => v !== 0).length; min = Math.min(min, clues); max = Math.max(max, clues);
    }
    details[`sudoku/${difficulties[level]}`] = { puzzles: 50, minimumClues: min, maximumClues: max };
  });
}
test('Klotski: all layouts solve through legal unit moves and hard requires more moves than normal', () => {
  const rules = new (f.rules('Klotski').KlotskiRules)(4, 5); const results = [];
  for (const difficulty of difficulties) {
    let blocks = rules.layout(difficulty); const result = solveKlotski(blocks);
    for (const move of result.moves) {
      assert(rules.canMove(blocks, rules.buildGrid(blocks), move.id, move.dx, move.dy));
      blocks = rules.apply(blocks, move.id, move.dx, move.dy);
    }
    assert(rules.isWin(blocks.find(b => b.target))); results.push(result.depth);
  }
  details.klotski = { minimumUnitMoves: results };
  assert(results[0] < results[1] && results[1] < results[2], 'difficulty order is reversed');
});
test('mole: each spawn contains 1–2 distinct targets and terminates for a repeated random value', () => {
  const rules = new (f.rules('WhackMole').WhackMoleRules)();
  for (let seed = 1; seed <= 500; seed++) {
    const holes = rules.spawnHoles(f.rng(seed)); assert.equal(holes.length, 9); assert([1, 2].includes(holes.filter(Boolean).length));
  }
  for (const value of [0, 0.1, 0.5, 0.999999]) assert([1, 2].includes(rules.spawnHoles(bounded(value)).filter(Boolean).length));
});
test('quiz: 18000 rounds have one distinct correct option and repeated RNG cannot block generation', () => {
  for (const id of ['arithmetic', 'compare', 'sequence', 'binary', 'targetsum', 'missing']) for (let level = 0; level < 3; level++) {
    for (let seed = 1; seed <= 100; seed++) {
      const m = create(id, level, seed);
      for (let round = 0; round < 10; round++) {
        const s = m.state;
        assert.equal(new Set(s.choices).size, s.choices.length); assert.equal(s.choices.filter(v => v === s.answer).length, 1);
        const numbers = s.prompt.match(/\d+/g)?.map(Number) || [];
        if (id === 'arithmetic') assert.equal(s.answer, s.prompt.includes('+') ? numbers[0] + numbers[1] : s.prompt.includes('−') ? numbers[0] - numbers[1] : numbers[0] * numbers[1]);
        if (id === 'compare') assert.equal(s.answer, Math.sign(numbers[0] + numbers[1] - numbers[2] - numbers[3]));
        if (id === 'sequence') assert.equal(s.answer, s.target[1] - s.target[0] === s.target[2] - s.target[1] ? s.target[3] + s.target[1] - s.target[0] : s.target[3] * 2);
        if (id === 'binary') assert.equal(s.answer, parseInt(s.prompt.split('₂')[0], 2));
        if (id === 'targetsum') assert.equal(s.answer, numbers[2] - numbers[0] - numbers[1]);
        if (id === 'missing') assert.deepEqual(s.target.filter(v => !s.board.includes(v)), [s.answer]);
        if (id === 'missing') m.action(); m.choose(s.choices.indexOf(s.answer));
      }
      assert.equal(m.state.score, (level + 1) * 1000); assert.equal(m.state.outcome, 1);
    }
    for (const value of [0, 0.5, 0.999999]) {
      const m = new CollectionModel(bounded(value)); m.start(id, level);
      assert.equal(new Set(m.state.choices).size, m.state.choices.length); assert(m.state.choices.includes(m.state.answer));
    }
  }
});
test('Sudoku rejects duplicate, malformed, fractional and out-of-range grids', () => {
  const rules = new (f.rules('Sudoku').SudokuRules)(), solved = rules.generateSolution(f.rng(5));
  for (const value of [solved[1], 10, -1, 1.5, NaN]) {
    const bad = solved.slice(); bad[0] = value; assert.equal(rules.countSolutions(bad), 0); assert.equal(rules.isComplete(bad), false);
  }
  assert.equal(rules.countSolutions(solved.slice(0, 80)), 0); assert.equal(rules.isComplete(solved.slice(0, 80)), false);
});
test('Sudoku: restart during a difficulty change never restores the previous difficulty puzzle', async () => {
  const fixtureAt = fixture(), vm = fixtureAt.vm('SudokuViewModel', fixtureAt.rng(8));
  vm.difficulty = 'easy'; vm.newGame(); const easy = vm.board.slice();
  vm.changeDifficulty('hard'); const obsolete = fixtureAt.tasks[0]; vm.restartGame();
  assert.equal(vm.isGenerating, true, 'restart relabeled the easy puzzle as hard');
  const current = fixtureAt.tasks.at(-1); assert.equal(current.task.args[0], 'hard');
  const hard = current.task.callback(...current.task.args); current.resolve(hard); await Promise.resolve();
  assert.deepEqual(vm.board, hard); assert.notDeepEqual(vm.board, easy); assert.equal(vm.isGenerating, false);
  obsolete.resolve(easy); await Promise.resolve(); assert.deepEqual(vm.board, hard);
  vm.changeDifficulty('normal'); fixtureAt.tasks.at(-1).reject(new Error('simulated worker failure')); await Promise.resolve();
  assert.equal(vm.generationFailed, true); vm.restartGame(); assert.equal(vm.isGenerating, true);
  const retry = fixtureAt.tasks.at(-1); retry.resolve(retry.task.callback(...retry.task.args)); await Promise.resolve();
  assert.equal(vm.generationFailed, false); assert.equal(vm.difficulty, 'normal'); vm.dispose();
});
test('collection: every difficulty initializes, restarts and rejects invalid inputs without changing the board', () => {
  for (const id of COLLECTION_IDS) for (let level = 0; level < 3; level++) for (let seed = 1; seed <= 100; seed++) {
    const m = create(id, level, seed); const snapshot = JSON.stringify(m.state);
    for (const invalid of [-1, NaN, Infinity, 1.5, 100000]) { m.tap(invalid); m.choose(invalid); }
    assert.equal(JSON.stringify(m.state), snapshot); m.start(id, level); assert.equal(m.state.moves, 0); assert.equal(m.state.outcome, 0);
  }
});
test('brick levels: every generated layout stays inside the board and high-level balls still hit the paddle', () => {
  const { BrickBreakerRules, BallState } = f.rules('BrickBreaker'), rules = new BrickBreakerRules();
  for (let level = 1; level <= 100; level++) {
    const layout = rules.generateLayout(level); assert(layout.length >= 40 && layout.length <= 64);
    assert.equal(new Set(layout.map(b => b.row + ':' + b.col)).size, layout.length);
    for (const brick of layout) { const rect = rules.brickRect(brick.row, brick.col); assert(rect.left >= 0 && rect.right <= 320 && rect.top >= 0 && rect.bottom < rules.paddleY()); }
    let ball = new BallState(160, rules.paddleY() - 15, 0, rules.getBallSpeed(level), 6), bounced = false;
    for (let tick = 0; tick < 10; tick++) { const result = rules.step(ball, [], [], 160); ball = result.ball; if (ball.vy < 0) { bounced = true; break; } }
    assert(bounced, `level ${level} ball tunnels through the paddle`);
  }
});
test('classic generators: 2048 mass, distinct memory pairs, unique secrets, reachable jumps, food and tetrominoes', () => {
  const { Game2048Rules } = f.rules('Game2048'), merge = new Game2048Rules(4);
  const memory = new (f.rules('MemoryCard').MemoryCardRules)(), guess = new (f.rules('GuessNumber').GuessNumberRules)();
  const { JumpJumpRules, JumpPlatform } = f.rules('JumpJump');
  const snake = new (f.rules('Snake').SnakeRules)(20, 20);
  const { TetrisRules, SHAPES } = f.rules('Tetris'), tetris = new TetrisRules(10, 20);
  for (let seed = 1; seed <= 500; seed++) {
    const rng = f.rng(seed), board = Array.from({ length: 4 }, () => Array.from({ length: 4 }, () => rng.next() < 0.3 ? 0 : 2 ** (1 + Math.floor(rng.next() * 4))));
    const original = JSON.stringify(board), mass = board.flat().reduce((a, b) => a + b, 0);
    for (let direction = 0; direction < 4; direction++) { const result = merge.swipe(board, direction); assert.equal(result.board.flat().reduce((a, b) => a + b, 0), mass); }
    assert.equal(JSON.stringify(board), original);
    for (const d of difficulties) {
      const pairs = memory.pairCount(d), cards = memory.deal(pairs, rng), groups = new Map();
      assert.equal(cards.length, pairs * 2); assert.equal(new Set(cards.map(c => c.id)).size, cards.length);
      for (const c of cards) { assert(!c.flipped && !c.matched); groups.set(c.emoji, (groups.get(c.emoji) || 0) + 1); }
      assert.equal(groups.size, pairs); assert([...groups.values()].every(n => n === 2));
      const secret = guess.generateSecret(guess.secretLength(d), rng); assert(/^\d+$/.test(secret)); assert.equal(new Set(secret).size, guess.secretLength(d));
      assert.equal(guess.evaluate(secret, secret).a, secret.length);
      const cfg = JumpJumpRules.configFor(d), current = new JumpPlatform(100, cfg.width), target = JumpJumpRules.spawnNext(current, d);
      const charge = (target.centerX - current.centerX) / JumpJumpRules.maxJumpDistance(d); assert(charge > 0 && charge <= 1);
      assert(JumpJumpRules.judge(current.centerX + JumpJumpRules.jumpDistance(charge, d), target).landed);
      assert(JumpJumpRules.judge(current.centerX + JumpJumpRules.jumpDistance(1, d), target).landed);
    }
    const body = snake.initialSnake(), food = snake.spawnFood(body, rng); assert(food.x >= 0 && food.x < 20 && food.y >= 0 && food.y < 20);
    assert(!body.some(p => p.x === food.x && p.y === food.y));
    const piece = tetris.spawn(rng); assert(tetris.canPlace(tetris.emptyBoard(), piece, 0, 0)); assert.equal(SHAPES[piece.idx][piece.rot].flat().filter(Boolean).length, 4);
    piece.y = tetris.hardDropY(tetris.emptyBoard(), piece); assert(tetris.canPlace(tetris.emptyBoard(), piece, 0, 0)); assert(!tetris.canPlace(tetris.emptyBoard(), piece, 0, 1));
  }
});

(async () => {
  const results = [];
  for (const t of tests) {
    const started = Date.now();
    try { await t.run(); results.push({ name: t.name, passed: true, ms: Date.now() - started }); }
    catch (e) { results.push({ name: t.name, passed: false, ms: Date.now() - started, error: e.message }); console.error('FAIL', t.name, e.message); }
  }
  const failed = results.filter(r => !r.passed);
  console.log(`${results.length - failed.length}/${results.length} generation/difficulty regressions passed.`);
  console.log(JSON.stringify(details));
  const reportAt = process.argv.indexOf('--report');
  if (reportAt >= 0) {
    const report = path.resolve(process.argv[reportAt + 1]); fs.mkdirSync(path.dirname(report), { recursive: true });
    fs.writeFileSync(report, JSON.stringify({ date: new Date().toISOString(), passed: results.length - failed.length,
      total: results.length, details, results }, null, 2) + '\n');
  }
  process.exitCode = failed.length ? 1 : 0;
})().catch(e => { console.error(e.stack); process.exitCode = 1; });
