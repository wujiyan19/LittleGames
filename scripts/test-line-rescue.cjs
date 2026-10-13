const assert = require('node:assert/strict');
const { fixture, Frames } = require('./test-performance.cjs');
const tests = [], test = (name, run) => tests.push({ name, run });
function create(level) {
  const f = fixture(), vm = f.vm('ExpansionViewModel'), frames = new Frames(); vm.init('linerescue', frames);
  vm.difficulty = ['easy','normal','hard'][level]; vm.startGame(); return { f, vm, frames };
}
function circle(vm, radius = 65, samples = 240) {
  vm.setDragging(true);
  for (let i = 0; i <= samples; i++) { const angle = i * 2 * Math.PI / samples; vm.aim(180 + radius * Math.cos(angle), 250 + radius * Math.sin(angle)); }
  vm.setDragging(false);
}
for (let level = 0; level < 3; level++) test(`difficulty ${level}: a densely sampled circle closes and protects for ten seconds`, () => {
  const { f, vm, frames } = create(level); circle(vm);
  assert.ok(vm.state.target.length > 48, 'Actual continuous input must exceed the old 24-point limit');
  assert.ok(vm.state.target.length <= 256); assert.equal(frames.running, false);
  const points = vm.state.target; assert.ok(Math.hypot(points[0]-points.at(-2), points[1]-points.at(-1)) < 8);
  const copy = f.vm('ExpansionViewModel'); copy.init('linerescue'); assert.equal(copy.importContinuation(vm.exportContinuation()), true);
  vm.activate(); for (let i = 0; i < 1300 && !vm.isFinished; i++) vm.advance(8);
  assert.equal(vm.state.outcome, 1); assert.ok(vm.state.score >= 100); assert.equal(frames.running, false);
});
test('start with no line leaves the game ready and no timer runs', () => {
  const { vm, frames } = create(1); vm.activate(); assert.equal(vm.state.phase, 0); assert.equal(frames.running, false);
});
test('identical protective shapes score equally across touch sampling densities', () => {
  const scores = [];
  for (const samples of [1, 20]) {
    const { vm } = create(1), corners = [[120,190],[240,190],[240,310],[120,310],[120,190]];
    vm.aim(...corners[0]);
    for (let edge = 1; edge < corners.length; edge++) for (let i = 1; i <= samples; i++) {
      const from = corners[edge-1], to = corners[edge];
      vm.aim(from[0]+(to[0]-from[0])*i/samples, from[1]+(to[1]-from[1])*i/samples);
    }
    vm.activate(); for (let i = 0; i < 1300 && !vm.isFinished; i++) vm.advance(8);
    assert.equal(vm.state.outcome, 1); scores.push(vm.state.score);
  }
  assert.equal(scores[0], scores[1]); assert.equal(scores[0], 540);
});
test('clear and redraw remove the old path and accept a new complete stroke', () => {
  const { vm } = create(1); circle(vm); vm.tap(900); assert.deepEqual(vm.state.target, []);
  circle(vm); assert.ok(vm.state.target.length > 48); vm.activate(); assert.equal(vm.state.phase, 1);
});
test('the line is frozen after start and a poorly placed line can lose normally', () => {
  const { vm } = create(1); vm.aim(0,0); vm.aim(50,0); const before = vm.state.target.slice(); vm.activate();
  vm.aim(180,180); vm.tap(900); assert.deepEqual(vm.state.target, before);
  for (let i = 0; i < 1250 && !vm.isFinished; i++) vm.advance(8); assert.equal(vm.state.outcome, 2);
});
test('pause and background release dragging, freeze time and preserve the drawn path', () => {
  const { vm, frames } = create(2); circle(vm); vm.activate(); vm.advance(500);
  const time = vm.state.time, points = vm.state.target.slice(); vm.setDragging(true); vm.togglePause();
  assert.equal(vm.dragging, false); assert.equal(frames.running, false); vm.advance(1000); assert.equal(vm.state.time, time);
  vm.onAppHidden(); vm.onAppShown(); assert.equal(vm.paused, true); assert.deepEqual(vm.state.target, points);
  vm.togglePause(); assert.equal(frames.running, true); vm.dispose(); assert.equal(frames.running, false);
});
test('drawing stays bounded and malformed large continuation paths are rejected', () => {
  const { f, vm } = create(1); for (let i=0;i<300;i++) vm.aim(i % 2 ? 350 : 10, 230);
  assert.ok(vm.state.target.length <= 256);
  const state = JSON.parse(vm.exportContinuation()); state.state.target = Array(258).fill(0);
  const copy = f.vm('ExpansionViewModel'); copy.init('linerescue'); assert.equal(copy.importContinuation(JSON.stringify(state)), false);
});
let passed = 0;
for (const t of tests) { try { t.run(); passed++; } catch (error) { console.error('FAIL', t.name, error); } }
console.log(`${passed}/${tests.length} line-rescue regressions passed.`);
if (passed !== tests.length) process.exitCode = 1;
