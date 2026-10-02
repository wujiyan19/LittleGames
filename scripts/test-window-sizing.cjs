const assert = require('node:assert/strict');
const { fixture } = require('./test-performance.cjs');
const sizing = fixture().load('entry/src/main/ets/common/ScreenUtils.ets').ScreenUtils;
let passed = 0;
const check = (name, run) => { run(); passed++; console.log('PASS ' + name); };

// Test the production calculation against board containment, including the
// short, wide split window reproduced on the tablet. UI evidence is separate.
for (const board of [
  ['snake', 20, 20, 560, 24, 40],
  ['minesweeper', 9, 9, 520, 20, 4],
  ['sudoku', 9, 9, 520, 24, 8],
  ['slide-3', 3, 3, 520, 40, 20],
  ['slide-5', 5, 5, 520, 40, 28],
  ['klotski', 4, 5, 560, 28, 48],
  ['match3', 8, 8, 360, 32, 29]
]) {
  check(board[0] + ': board fits every tested area and remains width-capped', () => {
    const [, columns, rows, maxWidth, widthPadding, heightPadding] = board;
    for (const [width, height] of [[960, 1600], [1440, 720], [960, 240], [480, 850], [320, 220]]) {
      const cell = sizing.calcCellForArea(width, height, columns, rows, maxWidth, widthPadding, heightPadding);
      assert(cell >= 1 && Number.isInteger(cell));
      assert(cell * columns + widthPadding <= Math.min(width, maxWidth));
      assert(cell * rows + heightPadding <= height);
      assert(cell <= sizing.calcCellForWidth(width, columns, maxWidth, widthPadding));
    }
    assert(sizing.calcCellForArea(960, 240, columns, rows, maxWidth, widthPadding, heightPadding)
      < sizing.calcCellForArea(960, 1600, columns, rows, maxWidth, widthPadding, heightPadding));
  });
}
check('unavailable area returns a finite positive fallback', () => {
  for (const [width, height, columns, rows] of [[0, 0, 9, 9], [100, 100, 0, 9], [100, 100, 9, 0], [5, 5, 9, 9]]) {
    assert.equal(sizing.calcCellForArea(width, height, columns, rows, 520, 24, 8), 1);
  }
});
console.log(passed + '/8 window sizing regressions passed.');
