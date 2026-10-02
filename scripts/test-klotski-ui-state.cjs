const assert = require('node:assert/strict');
const { fixture } = require('./test-performance.cjs');
const tests = [];
const test = (name, fn) => tests.push({name, fn});
test('moves and selection update retained pieces, including the new hit coordinates', () => {
  const vm = fixture().vm('KlotskiViewModel'); vm.startGame();
  const soldier = vm.piecesForView().find(p => p.x === 0 && p.y === 3);
  vm.selectBlockAt(3, 0); assert.equal(soldier.selected, true);
  vm.moveBlock(1, 0); assert.equal(soldier.x, 1); assert.equal(soldier.y, 3);
  assert.equal(vm.stepCount, 1);
  vm.selectBlockAt(soldier.y, soldier.x); assert.equal(soldier.selected, false);
  vm.selectBlockAt(soldier.y, soldier.x); vm.moveBlock(0, 1);
  assert.equal(soldier.y, 4); assert.equal(vm.stepCount, 2);
  vm.moveBlock(0, 1); assert.equal(soldier.y, 4); assert.equal(vm.stepCount, 2);
  assert.equal(vm.piecesForView().find(p => p.id === soldier.id), soldier);
});
test('restart restores positions and clears retained selection', () => {
  const vm = fixture().vm('KlotskiViewModel'); vm.startGame();
  const soldier = vm.piecesForView().find(p => p.x === 0 && p.y === 3);
  vm.selectBlockAt(3, 0); vm.moveBlock(1, 0); vm.startGame();
  assert.equal(soldier.x, 0); assert.equal(soldier.y, 3);
  assert.equal(soldier.selected, false); assert.equal(vm.stepCount, 0);
});
test('all difficulties and continuation restore expose current pieces', () => {
  for (const difficulty of ['easy', 'normal', 'hard']) {
    const vm = fixture().vm('KlotskiViewModel'); vm.changeDifficulty(difficulty); vm.startGame();
    const p = vm.piecesForView()[0]; vm.selectBlockAt(p.y, p.x);
    const payload = vm.exportContinuation(); const restored = fixture().vm('KlotskiViewModel');
    assert.equal(restored.importContinuation(payload), true);
    assert.deepEqual(JSON.parse(JSON.stringify(restored.piecesForView())), JSON.parse(JSON.stringify(vm.piecesForView())));
  }
});
let failed = 0;
for (const {name, fn} of tests) { try { fn(); } catch (e) { failed++; console.error(name, e); } }
console.log(`${tests.length - failed}/${tests.length} Klotski UI-state regressions passed`);
process.exitCode = failed ? 1 : 0;
