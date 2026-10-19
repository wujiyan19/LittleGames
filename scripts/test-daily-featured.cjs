const assert = require('node:assert/strict');
const fs = require('node:fs');
const { fixture } = require('./test-performance.cjs');
const tests = [], test = (name, run) => tests.push({ name, run });
const day = new Date(2026, 9, 13, 12);
function create(values = {}) {
  const f = fixture(values); f.data().init({});
  const vm = new (f.load('entry/src/main/ets/viewmodel/DailyFeaturedViewModel.ets').DailyFeaturedViewModel)();
  return { f, vm, catalog: f.data().getAllGames() };
}
const ids = vm => vm.recommendations.map(game => game.id);
test('calendar-day inspiration is stable within a day and changes across 32 consecutive days', () => {
  const { vm, catalog } = create(); const messages = new Set();
  for (let i = 0; i < 32; i++) {
    vm.update(catalog, new Date(2026, 9, 13 + i, 0, 1)); const message = vm.inspiration;
    vm.update(catalog, new Date(2026, 9, 13 + i, 23, 59)); assert.equal(vm.inspiration, message); messages.add(message);
  }
  assert.equal(messages.size, 32);
});
test('first batch has six different categories and refresh changes all six games', () => {
  const { vm, catalog } = create(); vm.update(catalog, day); const first = ids(vm);
  assert.equal(new Set(vm.recommendations.map(game => game.category)).size, 6);
  vm.refresh(catalog, day); assert.equal(ids(vm).length, 6); assert.equal(new Set(ids(vm)).size, 6);
  assert.ok(ids(vm).every(id => !first.includes(id)));
});
test('refresh can reach all 76 published games without bringing back withdrawn games', () => {
  const { vm, catalog } = create(); const seen = new Set(); vm.update(catalog, day);
  for (let i = 0; i < 20; i++) {
    for (const id of ids(vm)) seen.add(id); const before = ids(vm); vm.refresh(catalog, day);
    assert.ok(ids(vm).every(id => !before.includes(id)));
  }
  assert.equal(seen.size, 76); assert.deepEqual([...seen].sort(), catalog.map(game => game.id).sort());
});
test('refreshed recommendations survive process restart and ordinary score updates', () => {
  const { f, vm, catalog } = create(); vm.update(catalog, day); vm.refresh(catalog, day); const expected = ids(vm);
  f.data().updateHighScore('2048', 5000); f.data().flushNow(); vm.update(catalog, day); assert.deepEqual(ids(vm), expected);
  const next = create(Object.fromEntries(f.values)); next.vm.update(next.catalog, day); assert.deepEqual(ids(next.vm), expected);
});
test('a new day resets to its own batch, independent of yesterday refreshes', () => {
  const { vm, catalog } = create(); vm.update(catalog, day); for (let i = 0; i < 4; i++) vm.refresh(catalog, day);
  const tomorrow = new Date(2026, 9, 14); vm.update(catalog, tomorrow);
  const fresh = create(); fresh.vm.update(fresh.catalog, tomorrow); assert.deepEqual(ids(vm), ids(fresh.vm));
});
test('catalog sorting and locale-dependent display names do not change the recommendation IDs', () => {
  const one = create(), two = create(); one.vm.update(one.catalog, day); two.vm.update(two.catalog.slice().reverse(), day);
  assert.deepEqual(ids(one.vm), ids(two.vm));
});
test('empty and small catalogs are safe and never duplicate cards', () => {
  const { vm, catalog } = create(); vm.update([], day); vm.refresh([], day); assert.deepEqual(ids(vm), []);
  vm.update(catalog.slice(0, 3), day); assert.equal(new Set(ids(vm)).size, 3);
  vm.refresh(catalog.slice(0, 3), day); assert.equal(new Set(ids(vm)).size, 3);
});
test('malformed persisted batch counters fall back without dropping recommendations', () => {
  const serial = Math.floor(Date.UTC(2026, 9, 13) / 86400000), baseline = create(); baseline.vm.update(baseline.catalog, day);
  for (const state of ['bad', serial + ':-1', serial + ':NaN', serial + ':1.5', serial + ':1000001', serial + ':2:3']) {
    const next = create({ settings: JSON.stringify({ dailyFeaturedBatch: state }) }); next.vm.update(next.catalog, day);
    assert.deepEqual(ids(next.vm), ids(baseline.vm));
  }
});
test('manual recommendation refresh retains today encouragement', () => {
  const { vm, catalog } = create(); vm.update(catalog, day); const message = vm.inspiration;
  vm.refresh(catalog, day); vm.refresh(catalog, day); assert.equal(vm.inspiration, message);
});
test('all daily inspiration resources exist in every supported locale', () => {
  const { f } = create(); const catalog = f.load('entry/src/main/ets/model/DailyInspirationCatalog.ets').DAILY_INSPIRATIONS;
  for (const locale of ['base', 'zh_CN', 'en_US']) {
    const entries = JSON.parse(fs.readFileSync('entry/src/main/resources/' + locale + '/element/string.json', 'utf8')).string;
    const texts = new Map(entries.map(entry => [entry.name, entry.value]));
    assert.equal(texts.size, entries.length);
    for (const resource of catalog) assert.ok(texts.get(resource.replace('app.string.', ''))?.trim());
  }
});
test('invalid dates retain the last valid content without persisting invalid counters', () => {
  const { vm, catalog } = create(); vm.update(catalog, day); const before = ids(vm), message = vm.inspiration;
  vm.refresh(catalog, new Date(NaN)); assert.deepEqual(ids(vm), before); assert.equal(vm.inspiration, message);
});

let passed = 0;
for (const t of tests) { try { t.run(); passed++; } catch (error) { console.error('FAIL', t.name, error); } }
console.log(`${passed}/${tests.length} daily-featured regressions passed.`);
if (passed !== tests.length) process.exitCode = 1;
