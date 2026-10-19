/* Gameplay regressions, not phone-rendering or performance claims. */
const assert = require('node:assert/strict');
const { fixture } = require('./test-performance.cjs');
const f = fixture();
const { ExpansionModel } = f.rules('Expansion');
const { ExpansionState, ExpansionPiece } = f.load('entry/src/main/ets/model/game/ExpansionState.ets');
const { ExpansionScrews: rules } = f.load('entry/src/main/ets/model/game/ExpansionScrews.ets');
const { solve } = require('./screw-layout-solver.cjs');
const tests = [];
const test = (name, run) => tests.push({ name, run });
const create = (level = 1, seed = 8) => { const m = new ExpansionModel(f.rng(seed)); m.start('screwout', level); return m; };
const json = m => JSON.stringify(m.state);
const moves = m => m.state.pieces.filter(p => rules.free(m.state, p));

for (const level of [0, 1, 2]) test(`difficulty ${level}: 100 varied layered deals are solvable through every intermediate state`, () => {
  const layouts = new Set();
  for (let seed = 1; seed <= 100; seed++) {
    const m = create(level, seed), s = m.state;
    assert.equal(s.pieces.filter(p => p.kind === 0).length, 5 + level * 2);
    assert.equal(new Set(s.pieces.filter(p => p.kind === 1).map(p => p.color)).size, 3 + level);
    assert(moves(m).length < s.target.length, 'some screws must actually be occluded');
    layouts.add(s.pieces.map(p => `${p.x},${p.y},${p.color}`).join('|'));
    for (const id of [...s.target]) {
      assert(moves(m).some(p => p.id === id), 'route must obey physical occlusion');
      m.tap(id); assert(m.valid(m.state), `invalid intermediate state ${seed}/${m.state.moves}`);
    }
    assert.equal(m.state.outcome, 1); assert.equal(m.state.tray.length, 0);
  }
  assert(layouts.size > 90, 'restarts must change layout and color distribution');
});

test('covered heads reject taps; removing their cover exposes them; undo restores the cover', () => {
  const m = create(), before = json(m), blocked = m.state.pieces.find(p => p.kind === 1 && !rules.free(m.state, p));
  m.tap(blocked.id); assert.equal(json(m), before);
  for (const id of [...m.state.target]) {
    const previous = json(m), wasBlocked = !rules.free(m.state, m.state.pieces.find(p => p.id === blocked.id));
    m.tap(id);
    if (wasBlocked && rules.free(m.state, m.state.pieces.find(p => p.id === blocked.id))) {
      m.undo(); assert.equal(json(m), previous); return;
    }
  }
  assert.fail('no newly exposed screw observed');
});

test('an independent geometry/color search solves 36 deals without reading their stored route', () => {
  for(const level of [0,1,2])for(let seed=1;seed<=12;seed++){
    const m=create(level,seed),result=solve(m.state.pieces.filter(p=>p.kind===0),m.state.pieces.filter(p=>p.kind===1),rules.capacity(m.state));
    assert(result.route);for(const id of result.route)m.tap(id);assert.equal(m.state.outcome,1);
  }
});

test('a plate falling does not recycle differently colored screws', () => {
  for (let seed = 1; seed <= 30; seed++) {
    const m = create(1, seed);
    for (const id of [...m.state.target]) {
      const prior = m.state.pieces.filter(p => p.kind === 0 && p.alive).length;
      m.tap(id);
      if (m.state.pieces.filter(p => p.kind === 0 && p.alive).length < prior && m.state.tray.length) {
        const held = m.state.tray.map(id => m.state.pieces.find(p => p.id === id));
        if (held.some(p => !m.state.pieces.find(q => q.kind === 0 && q.id === p.owner).alive)) {
          assert(m.valid(m.state)); return;
        }
      }
    }
  }
  assert.fail('plate removal incorrectly freed all holding space');
});

test('a matching triple may use the last slot and clears before overflow is checked', () => {
  const m = create(); const route = [...m.state.target];
  for (const id of route.slice(0, 5)) m.tap(id);
  assert.equal(m.state.tray.length, rules.capacity(m.state) - 1);
  m.tap(route[5]); assert.equal(m.state.tray.length, 3); assert.equal(m.state.outcome, 0);
  const after = json(m); m.undo(); assert.equal(m.state.tray.length, 5);
  m.tap(route[5]); assert.equal(json(m), after);
});

test('poor removal orders fill the tray and end the game; finished input cannot alter it', () => {
  for (let seed = 1; seed <= 30; seed++) {
    const m = create(2, seed);
    while (!m.state.outcome) m.tap(moves(m)[0].id);
    if (m.state.outcome === 2) {
      assert.equal(m.state.tray.length, 5); assert(m.valid(m.state));
      const before = json(m); m.tap(0); m.undo(); assert.equal(json(m), before); return;
    }
  }
  assert.fail('careless order never lost');
});

test('even easy mode has a real overflow risk; hard mode demands more planning', () => {
  const wins = [0, 0, 0];
  for (const level of [0, 1, 2]) for (let seed = 1; seed <= 100; seed++) {
    const m = create(level, seed), random = f.rng(seed * 97);
    while (!m.state.outcome) { const legal = moves(m); m.tap(legal[Math.floor(random.next() * legal.length)].id); }
    if (m.state.outcome === 1) wins[level]++;
  }
  assert(wins[0] < 100 && wins[0] > wins[1] && wins[1] > wins[2], JSON.stringify(wins));
});

test('hard deals cannot be cleared merely by taking the most-held color from the top layer', () => {
  for(let seed=1;seed<=100;seed++){
    const m=create(2,seed);
    while(!m.state.outcome){
      const count=color=>m.state.tray.filter(id=>m.state.pieces.find(p=>p.id===id).color===color).length;
      const legal=moves(m);legal.sort((a,b)=>count(b.color)-count(a.color)||b.owner-a.owner);m.tap(legal[0].id);
    }
    assert.equal(m.state.outcome,2);
  }
});

test('continuation retains the deal, color buffer and new rules; corrupted states are rejected', () => {
  const m = create(); for (const id of m.state.target.slice(0, 4)) m.tap(id);
  const before = json(m), fresh = create(0, 99); assert(fresh.valid(m.state)); fresh.restore(JSON.parse(before));
  for (const id of m.state.target.slice(4)) fresh.tap(id);
  assert.equal(fresh.state.outcome, 1);
  for (const mutate of [s => s.tray.pop(), s => s.tray.push(s.tray[0]), s => s.pieces[1].color = 9,
    s => s.pieces[0].x++, s => s.data[0]++, s => s.target.reverse(), s => s.moves++, s => s.outcome = 1]) {
    const s = JSON.parse(before); mutate(s); assert.equal(m.valid(s), false);
  }
  const vm = f.vm('ExpansionViewModel'); vm.init('screwout'); vm.startGame();
  const payload = JSON.stringify({version:1,state:JSON.parse(before),recorded:false,paused:false});
  assert(vm.importContinuation(payload)); assert.equal(JSON.stringify(vm.state), before);
  vm.tap(m.state.target[4]); assert.equal(vm.state.moves, 5); vm.undo();
  assert.equal(JSON.stringify(vm.state), before); vm.dispose();
});

test('a pre-upgrade saved round still validates and completes with the original rules', () => {
  const s = new ExpansionState(); s.id = 'screwout'; const plates = 4; s.cols = 3; s.rows = 3;
  for (let p = 0; p < plates; p++) {
    const b = new ExpansionPiece(); Object.assign(b,{id:p,x:22+p*22,y:48+p*52,w:220,h:96,color:p+1}); s.pieces.push(b);
    for (let j=0;j<3;j++) {const q=new ExpansionPiece();Object.assign(q,{id:plates+p*3+j,kind:1,owner:p,x:b.x+26+j*78,y:b.y+30,r:16,color:p+1});s.pieces.push(q);}
  }
  s.target=s.pieces.filter(p=>p.kind===1).sort((a,b)=>b.owner-a.owner).map(p=>p.id);
  const m=create();assert(m.valid(s));m.restore(s);
  for(const id of [...s.target]){m.tap(id);assert(m.valid(m.state));}
  assert.equal(m.state.outcome,1);assert.equal(m.state.score,760);
});

let failed=0;
for(const t of tests){try{t.run();console.log('PASS '+t.name);}catch(e){failed++;console.error('FAIL '+t.name+'\n'+e.stack);}}
console.log(`${tests.length-failed}/${tests.length} screw puzzle checks passed`);
if(failed)process.exitCode=1;
