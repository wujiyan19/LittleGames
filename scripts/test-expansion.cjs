const assert = require('node:assert/strict');
const fs = require('node:fs');
const { fixture } = require('./test-performance.cjs');
const f = fixture();
const { ExpansionModel, PLAYABLE_EXPANSION_IDS } = f.rules('Expansion');
const { ExpansionPiece } = f.load('entry/src/main/ets/model/game/ExpansionState.ets');
const tests = [];
const test = (name, callback) => tests.push({name, callback});
const create = (id, level = 1, seed = 8) => { const m = new ExpansionModel(f.rng(seed)); m.start(id, level); return m; };
const snapshot = m => JSON.stringify(m.state);

for (const id of PLAYABLE_EXPANSION_IDS) for (const level of [0, 1, 2]) {
  test(`${id}/${level}: valid state and rejected invalid input`, () => {
    const m = create(id, level); assert(m.valid(m.state)); const before = snapshot(m);
    for (const invalid of [-1, NaN, 1001, 0.5, Infinity]) { m.tap(invalid); m.choose(invalid); }
    m.aim(NaN, 1); m.aim(1, Infinity); m.aim(-1, 1); assert.equal(snapshot(m), before);
    const malformed = JSON.parse(before); malformed.board.push(99); assert.equal(m.valid(malformed), false);
  });
}
for (const id of ['tilestack', 'watersort', 'arrowclear', 'screwout', 'parkingjam']) for (const level of [0, 1, 2]) {
  test(`${id}/${level}: 80 generated boards have a legal complete solution`, () => {
    for (let seed = 1; seed <= 80; seed++) {
      const m = create(id, level, seed); const solution = [...m.state.target];
      if (id === 'watersort') for (let i = 0; i < solution.length && !m.state.outcome; i += 2) {
        m.state.selected = -1; m.tap(solution[i]); m.tap(solution[i + 1]);
      } else for (const step of solution) m.tap(step);
      assert.equal(m.state.outcome, 1, `${id} level ${level} seed ${seed}`);
      assert(m.valid(m.state), `${id} finished validation`);
      const finished = snapshot(m); m.tap(0); m.choose(0); m.aim(100, 100); m.step(0.008); assert.equal(snapshot(m), finished);
    }
  });
}
for (const level of [0, 1, 2]) test(`sokoban/pipes/${level}: legal generated solutions across 100 seeds`, () => {
  for (let seed = 1; seed <= 100; seed++) {
    const boxes = create('sokoban', level, seed); assert(boxes.valid(boxes.state));
    for (const d of [...boxes.state.target]) boxes.tap(d); assert.equal(boxes.state.outcome, 1, `sokoban ${seed}`);
    const pipes = create('pipes', level, seed); assert(pipes.valid(pipes.state));
    for (let i = 0; i < pipes.state.board.length && !pipes.state.outcome; i++) {
      let tries = 0; while (pipes.state.board[i] !== pipes.state.target[i] && !pipes.state.outcome) { pipes.tap(i); assert(++tries < 4); }
    } assert.equal(pipes.state.outcome, 1, `pipes ${seed}`);
  }
});
test('differences reject repeats and fail only after three errors', () => {
  const m = create('differences'); m.tap(m.state.target[0]); const once = snapshot(m); m.tap(m.state.target[0]); assert.equal(snapshot(m), once);
  for (const i of m.state.target.slice(1)) m.tap(i); assert.equal(m.state.outcome, 1);
  const fail = create('differences'); const wrong = fail.state.board.findIndex((_, i) => !fail.state.target.includes(i));
  fail.tap(wrong); fail.tap(wrong); assert.equal(fail.state.outcome, 0); fail.tap(wrong); assert.equal(fail.state.outcome, 2);
});
test('runner collisions, fish predation and hole growth have distinct outcomes', () => {
  const runner = create('runner'); runner.activate(); runner.state.cooldown = 1;
  const obstacle = new ExpansionPiece(); obstacle.id = runner.state.serial++; obstacle.kind = 7; obstacle.x = 180; obstacle.y = 388; obstacle.r = 24; obstacle.color = 2;
  runner.state.pieces.push(obstacle); runner.step(0.008); assert.equal(runner.state.outcome, 2);
  const fish = create('fisheat'); fish.aim(180,230); fish.state.pieces[1].x = 180; fish.state.pieces[1].y = 230; fish.state.pieces[1].r = 26;
  fish.step(0.008); assert.equal(fish.state.outcome, 2);
  const hole = create('blackhole'); hole.aim(180,230); const before = hole.state.pieces[0].r;
  hole.state.pieces[1].x = 180; hole.state.pieces[1].y = 230; hole.state.pieces[1].r = 8;
  hole.step(0.008); assert(hole.state.pieces[0].r > before); assert(hole.state.moves > 0); assert(hole.valid(hole.state));
});
test('constant random sources terminate with solvable boards', () => {
  for (const value of [0, 0.999999]) for (const id of ['watersort', 'tilestack', 'arrowclear', 'screwout', 'parkingjam']) {
    const m = new ExpansionModel({next: () => value}); m.start(id, 2); assert(m.valid(m.state));
    const solution = [...m.state.target];
    if (id === 'watersort') for (let i = 0; i < solution.length && !m.state.outcome; i += 2) { m.state.selected = -1; m.tap(solution[i]); m.tap(solution[i + 1]); }
    else for (const step of solution) m.tap(step);
    assert.equal(m.state.outcome, 1, `${id} RNG ${value}`);
  }
});
test('solitaire deals 52 unique cards, enforces sequence rules, reveals covered cards and completes foundations', () => {
  const m = create('solitaire'); assert.equal(m.state.piles[0].cards.length, 24);
  for (let col = 0; col < 7; col++) assert.equal(m.state.piles[col+2].cards.length, col+1);
  for (const p of m.state.piles) p.cards = []; m.state.piles[0].cards = Array.from({length:52}, (_,i)=>i);
  const take = (id, pile) => { m.state.piles[0].cards.splice(m.state.piles[0].cards.indexOf(id),1); m.state.piles[pile].cards.push(id); m.state.pieces[id].w = 1; };
  take(24,2); take(10,2); take(12,3); m.tap(24); m.tap(12); assert.deepEqual(m.state.piles[3].cards,[12,24,10]);
  take(0,1); m.tap(0); m.tap(101); assert.deepEqual(m.state.piles[9].cards,[0]); assert(m.valid(m.state));
  m.undo(); assert.equal(m.state.piles[9].cards.length,0); assert.equal(m.state.score,0);
  for (const p of m.state.piles) p.cards = [];
  for (let suit=0;suit<4;suit++) { m.state.piles[9+suit].cards=Array.from({length:12},(_,rank)=>suit*13+rank); m.state.piles[2+suit].cards=[suit*13+12]; }
  m.state.pieces.forEach(p=>p.w=1); m.state.selected=-1;
  for (let suit=0;suit<4;suit++) { m.tap(suit*13+12); m.tap(101); }
  assert.equal(m.state.outcome,1); assert(m.valid(m.state));
});
test('character builder supports repeated radicals and eight complete combinations', () => {
  const m = create('characters',2);
  while(!m.state.outcome) { const parts=[...m.state.target]; for(const part of parts) m.tap(m.state.board.indexOf(part)); m.action(); }
  assert.equal(m.state.outcome,1); assert.equal(m.state.moves,8); assert.equal(m.state.score,800);
});
test('basketball scores only descending hoop crossings and has a playable five-basket solution', () => {
  const m=create('basketball',0);
  while(!m.state.outcome) {
    m.aim(260,145); assert.equal(m.state.pieces.length,2);
    for(let i=0;i<600&&m.state.pieces.length>1;i++) m.step(0.008);
  }
  assert.equal(m.state.outcome,1); assert.equal(m.state.data[0],5); assert(m.valid(m.state));
});
test('rhythm admits a full timed sequence and five misses fail', () => {
  const m=create('rhythm',2); m.activate();
  for(let i=0;i<10000&&!m.state.outcome;i++) { m.step(0.008); for(const note of [...m.state.pieces]) if(note.y>=390) m.tap(note.owner); }
  assert.equal(m.state.outcome,1); assert.equal(m.state.errors,0); assert.equal(m.state.moves,m.state.goal); assert(m.valid(m.state));
  const miss=create('rhythm'); miss.activate(); for(let i=0;i<10000&&!miss.state.outcome;i++) miss.step(0.008); assert.equal(miss.state.outcome,2);
});
test('restaurant orders consume prepared dishes, earn coins and finish before the clock expires', () => {
  const m=create('restaurant',2); m.activate();
  for(let i=0;i<15000&&!m.state.outcome;i++) {
    for(const customer of [...m.state.pieces].filter(p=>p.kind===19)) {
      if(m.state.board[customer.color]>0) m.tap(100+customer.id); else m.tap(customer.color);
    } m.step(0.008);
  }
  assert.equal(m.state.outcome,1); assert.equal(m.state.moves,m.state.goal); assert(m.valid(m.state));
});
test('room defense costs coins, caps upgrades, kills attackers and repairs only damaged doors', () => {
  const m=create('roomdefense',0); m.tap(0); m.tap(1); assert.equal(m.state.data[0],0); const before=snapshot(m); m.tap(2); assert.equal(snapshot(m),before);
  m.activate();
  for(let i=0;i<12000&&!m.state.outcome;i++) { for(let slot=0;slot<6;slot++) m.tap(slot); if(m.state.data[1]<75)m.tap(6); m.step(0.008); }
  assert.equal(m.state.outcome,1); assert.equal(m.state.moves,m.state.goal); assert(m.valid(m.state));
});
test('block fit clears row/column simultaneously and rejects occupied or out-of-bounds shapes', () => {
  const m = create('blockfit', 0); const n = m.state.cols;
  m.state.tray = [0, 0, 0]; m.state.board.fill(0);
  for (let i = 1; i < n; i++) { m.state.board[i] = 1; m.state.board[i * n] = 2; }
  m.tap(0); assert.equal(m.state.score, 410); assert(m.state.board.every(v => v === 0));
  m.state.tray = [5, -1, -1]; m.state.selected = 0; const before = snapshot(m); m.tap(n - 1); assert.equal(snapshot(m), before);
  m.state.board[0] = 1; const occupied = snapshot(m); m.tap(0); assert.equal(snapshot(m), occupied);
  m.state.board.fill(1); m.state.board[n * n - 1] = 0; m.state.tray = [0, 5, -1]; m.tap(n * n - 1);
  assert.equal(m.state.outcome, 1); // simultaneous full rows and columns reach the target
});
test('tray failure, blocked arrows and turn undo do not duplicate points', () => {
  const stack = create('tilestack'); stack.state.board.fill(0);
  for (let i = 0; i < 8; i++) stack.state.board[i] = i < 2 ? 1 : i < 4 ? 2 : i < 6 ? 3 : 4;
  for (let i = 0; i < 7; i++) stack.tap(i); assert.equal(stack.state.outcome, 2);
  const arrow = create('arrowclear'); arrow.state.board.fill(0); arrow.state.board[0] = 2; arrow.state.board[1] = 4;
  arrow.tap(0); assert.equal(arrow.state.errors, 1); arrow.undo(); assert.equal(arrow.state.errors, 0);
  arrow.tap(0); arrow.tap(0); arrow.tap(0); assert.equal(arrow.state.outcome, 2);
  const water = create('watersort'); water.state.selected = water.state.cols - 1; water.tap(water.state.cols - 2); assert(water.valid(water.state));
});
test('bubble physics matches, drops unanchored clusters, waits for the final shot and rejects duplicate fire', () => {
  const m = create('bubbleshooter'); m.state.board.fill(0); m.state.board[3] = 1; m.state.board[4] = 1; m.state.board[12] = 2; m.state.next = 1;
  m.state.moves = m.state.goal - 1; m.aim(150, 1); const once = snapshot(m); m.aim(50, 1); assert.equal(snapshot(m), once);
  assert.equal(m.state.outcome, 0);
  for (let i = 0; i < 2000 && m.state.outcome === 0; i++) m.step(0.008);
  assert.equal(m.state.outcome, 1); assert(m.state.score >= 90); assert(m.valid(m.state));
  const bounce = create('bubbleshooter'); bounce.aim(0, 395); let flipped = false;
  for (let i = 0; i < 1000 && bounce.state.pieces.length; i++) { bounce.step(0.008); if (bounce.state.pieces[0]?.vx > 0) flipped = true; }
  assert(flipped); assert(bounce.valid(bounce.state));
});
test('fruit collisions merge once, conserve finite bounds, allow cooldown and do not lose during free fall', () => {
  const m = create('fruitmerge'); m.aim(180, 0); const first = snapshot(m); m.aim(180, 0); assert.equal(snapshot(m), first);
  for (let i = 0; i < 250; i++) m.step(0.008); assert.equal(m.state.outcome, 0); assert(m.valid(m.state));
  const p = new ExpansionPiece(); p.id = m.state.serial++; p.kind = 4; p.color = m.state.pieces[0].color; p.r = m.physics.fruitRadius(p.color); p.x = 180; p.y = 460 - p.r;
  m.state.pieces.push(p); m.state.phase=1; m.step(0.008); assert.equal(m.state.pieces.length, 1); assert(m.state.score > 0);
  for (let i = 0; i < 1000; i++) m.step(0.008); assert(m.valid(m.state));
  const a = m.state.pieces[0]; a.color = 8; a.r = m.physics.fruitRadius(8); a.y = 460 - a.r;
  const b = new ExpansionPiece(); b.id = m.state.serial++; b.kind = 4; b.color = 8; b.r = a.r; b.x = a.x; b.y = a.y;
  m.state.pieces.push(b); m.state.phase=1; m.step(0.008); assert.equal(m.state.outcome, 1);
});
test('settled fruit stops its frame loop and dropping the next fruit wakes it', () => {
  const m=create('fruitmerge'); m.aim(140,20);
  for(let i=0;i<1600&&m.state.phase!==0;i++) m.step(0.008);
  assert.equal(m.state.phase,0); assert.equal(m.state.outcome,0);
  const resting=snapshot(m); m.step(0.008); assert.equal(snapshot(m),resting);
  m.aim(200,20); assert.equal(m.state.phase,1); assert.equal(m.state.pieces.length,2);
});
test('catalog and resources are complete for every registered expansion', () => {
  const ids = f.load('entry/src/main/ets/model/ExpansionCatalog.ets').EXPANSION_IDS;
  assert.deepEqual(ids, PLAYABLE_EXPANSION_IDS);
  const games = f.data().getAllGames(); assert.equal(games.length, 33 + ids.length);
  assert.equal(new Set(games.map(g => g.id)).size, games.length);
  const routes = f.load('entry/src/main/ets/router/GameRouteRegistry.ets').GameRoutes;
  for (const id of ids) assert.equal(routes.gameIdForRoute(routes.routeName(id)), id);
  for (const locale of ['base', 'zh_CN', 'en_US']) {
    const strings = JSON.parse(fs.readFileSync(`entry/src/main/resources/${locale}/element/string.json`)).string;
    assert.equal(strings.length, new Set(strings.map(s => s.name)).size);
    for (const id of ids) for (const suffix of ['name', 'desc', 'rules']) assert(strings.find(s => s.name === `game_${id}_${suffix}`)?.value);
  }
  for (const theme of ['base', 'dark']) for (const id of ids) assert(fs.existsSync(`entry/src/main/resources/${theme}/media/game_${id}.svg`));
});

for (const id of PLAYABLE_EXPANSION_IDS) test(`${id}: continuation rejects malformed saves atomically and does not count another play`, () => {
  const source = f.vm('ExpansionViewModel'); source.init(id); source.startGame();
  const target = f.vm('ExpansionViewModel'); target.init(id);
  const plays = f.data().getGameById(id).playCount; assert(target.importContinuation(source.exportContinuation()));
  assert.deepEqual(JSON.parse(target.exportContinuation()), JSON.parse(source.exportContinuation()));
  assert.equal(f.data().getGameById(id).playCount, plays);
  const before = target.exportContinuation();
  for (const value of ['null', '{}', '[]', '{bad', 'x'.repeat(65537)]) { assert.equal(target.importContinuation(value), false); assert.equal(target.exportContinuation(), before); }
  for (const field of ['cols', 'rows', 'phase', 'outcome', 'serial', 'level']) {
    const malformed = JSON.parse(before); malformed.state[field] = field === 'serial' ? 1000001 : 99999;
    assert.equal(target.importContinuation(JSON.stringify(malformed)), false); assert.equal(target.exportContinuation(), before);
  }
  const foreign = JSON.parse(before); foreign.state.id = 'snake'; assert.equal(target.importContinuation(JSON.stringify(foreign)), false);
  source.dispose(); target.dispose();
});
test('all registered games transfer after actual input, including live physics and selected cards', () => {
  for(const id of PLAYABLE_EXPANSION_IDS) {
    const source=f.vm('ExpansionViewModel'); source.init(id); source.startGame();
    if(['fruitmerge','bubbleshooter','basketball','blackhole','fisheat'].includes(id)) { source.aim(180,150); source.advance(160); }
    else if(['runner','roomdefense','rhythm','restaurant'].includes(id)) { source.activate(); source.advance(160); }
    else if(id==='solitaire') source.tap(100);
    else if(id==='characters') source.tap(0);
    else if(id==='mahjongsolitaire') source.tap(source.state.target[0]);
    else if(id==='yarn') { source.choose(1); source.tap(0); }
    else if(id==='sand') { source.choose(source.state.board[0]-1); source.tap(0); }
    else if(id==='untangle') { source.tap(0); source.aim(30,230); source.setDragging(false); }
    else source.tap(['arrowclear','screwout','parkingjam','sokoban'].includes(id)?source.state.target[0]:0);
    const saved=JSON.parse(source.exportContinuation()); const receiver=f.vm('ExpansionViewModel'); receiver.init(id);
    assert(receiver.importContinuation(JSON.stringify(saved)),id); assert.deepEqual(JSON.parse(receiver.exportContinuation()).state,saved.state,id);
    source.dispose(); receiver.dispose();
  }
});
test('all new routes and game payloads work through application-level continuation', () => {
  const App=f.load('entry/src/main/ets/common/AppContinuation.ets').AppContinuation;
  const Bus=f.load('entry/src/main/ets/common/GameLifecycleBus.ets').GameLifecycleBus;
  const routes=f.load('entry/src/main/ets/router/GameRouteRegistry.ets').GameRoutes;
  for(const id of PLAYABLE_EXPANSION_IDS) {
    const vm=f.vm('ExpansionViewModel'); vm.init(id); vm.startGame(); Bus.attach(vm);
    App.connect(()=>({tab:0, paths:[routes.routeName(id)]}),()=>{});
    const payload=App.capture(); assert(payload.length<App.MAX_PAYLOAD_LENGTH,id); assert(App.receive(payload),id);
    Bus.detach(vm); vm.dispose(); App.disconnect();
  }
});
test('live frames pause in background and confirmation, resume correctly, and stop on disposal', () => {
  let callback = null; let running = false; let disposed = false;
  const frame = {start(fn) { callback = fn; running = true; }, stop() { running = false; }, dispose() { disposed = true; running = false; }};
  const vm = f.vm('ExpansionViewModel'); vm.init('fruitmerge', frame); vm.startGame(); assert.equal(running, false);
  vm.aim(150, 20); assert(running); callback(100); const moving = vm.exportContinuation();
  vm.setDragging(true); assert(vm.dragging); vm.onAppHidden(); assert.equal(vm.dragging,false); assert.equal(running, false); callback(100); vm.aim(100, 20); assert.equal(vm.exportContinuation(), moving);
  vm.onAppShown(); assert(running); vm.togglePause(); assert.equal(running, false); const paused = vm.exportContinuation();
  vm.onAppHidden(); vm.onAppShown(); assert.equal(running, false); callback(100); assert.equal(vm.exportContinuation(), paused);
  vm.togglePause(); assert(running); assert(vm.requestBack()); assert.equal(running, false);
  const confirming = vm.exportContinuation(); callback(100); assert.equal(vm.exportContinuation(), confirming); vm.dismissExitConfirm(); assert(running);
  const receiver = f.vm('ExpansionViewModel'); receiver.init('fruitmerge'); assert(receiver.importContinuation(vm.exportContinuation())); assert(receiver.paused);
  vm.dispose(); assert(disposed); assert.equal(running, false); receiver.dispose();
});

for (const id of ['linktiles', 'mahjongsolitaire', 'slotpair', 'buscolor', 'yarn', 'sand', 'untangle']) for (const level of [0,1,2]) {
  test(`${id}/${level}: 100 generated boards complete through legal input`, () => {
    for (let seed=1;seed<=100;seed++) {
      const m=create(id,level,seed); assert(m.valid(m.state));
      if(id==='linktiles') {
        let safety=0;
        while(!m.state.outcome) {
          let pair=m.matching.linkPair(m.state); if(!pair.length){m.action();pair=m.matching.linkPair(m.state);}
          assert.equal(pair.length,2);m.tap(pair[0]);m.tap(pair[1]);assert(++safety<60);
        }
      } else if(id==='mahjongsolitaire') {
        for(const step of [...m.state.target]) m.tap(step);
      } else if(id==='slotpair') {
        for(let i=0;i<m.state.goal;i++) m.tap(i%2===0?i%6:(i-1)%6);
      } else if(id==='buscolor') {
        for(const lane of m.state.data.slice(3)) m.tap(lane);
      } else if(id==='yarn') {
        m.choose(0);
        for(const color of m.state.target) {
          let safety=0;
          while(m.state.data[color-1]!==8) {
            const col=Array.from({length:m.state.cols},(_,i)=>i).find(i=>{const h=m.sorting.yarnHeight(m.state,i);return h>0&&m.state.board[i*8+h-1]===color;});
            assert.notEqual(col,undefined);m.tap(col);assert(++safety<50);
          }
        }
      } else if(id==='sand') {
        for(let color=1;color<=3+level;color++) {
          m.choose(color-1);while(m.state.board.includes(color)) m.tap(m.state.board.indexOf(color));
        }
      } else {
        assert(m.state.data[0]>0,'initial knots must have crossings');
        let safety=0;
        while(!m.state.outcome&&m.state.pieces.some((p,i)=>p.x!==m.state.target[i*2]||p.y!==m.state.target[i*2+1])) {
          let id=m.state.pieces.findIndex((p,i)=>(p.x!==m.state.target[i*2]||p.y!==m.state.target[i*2+1])&&!m.state.pieces.some(q=>q.id!==i&&Math.hypot(q.x-m.state.target[i*2],q.y-m.state.target[i*2+1])<36));
          if(id>=0){m.tap(id);m.aim(m.state.target[id*2],m.state.target[id*2+1]);m.releaseNode();}
          else {
            id=m.state.pieces.findIndex((p,i)=>p.x!==m.state.target[i*2]||p.y!==m.state.target[i*2+1]);
            let point;
            for(let y=30;y<=430&&!point;y+=40)for(let x=30;x<=330&&!point;x+=40)
              if(!m.state.pieces.some(p=>Math.hypot(p.x-x,p.y-y)<36)&&!Array.from({length:m.state.cols},(_,i)=>i).some(i=>Math.hypot(m.state.target[i*2]-x,m.state.target[i*2+1]-y)<36))point=[x,y];
            assert(point);m.tap(id);m.aim(...point);m.releaseNode();
          }assert(++safety<50);
        }
      }
      assert.equal(m.state.outcome,1,`${id}/${level}/${seed}`);assert(m.valid(m.state),`${id} completed validation`);
      const ended=snapshot(m);m.tap(0);m.choose(1);m.action();m.aim(30,30);assert.equal(snapshot(m),ended);
    }
  });
}
test('matching paths support zero, one and two turns including the outside border',()=>{
  const m=create('linktiles',0);const s=m.state;
  s.board.fill(0);s.board[0]=s.board[5]=1;assert(m.matching.linkPath(s,0,5).length);
  s.board[0]=s.board[13]=1;assert(m.matching.linkPath(s,0,13).length);
  s.board.fill(2);s.board[0]=s.board[5]=1;const path=m.matching.linkPath(s,0,5);assert(path.some(i=>Math.floor(i/8)===0));
  s.board.fill(2);s.board[7]=s.board[16]=1;assert.equal(m.matching.linkPath(s,7,16).length,0);
  s.board.fill(0);s.board[0]=1;s.board[1]=2;m.tap(0);m.tap(1);assert.equal(s.moves,0);
});
test('mahjong checks coverage and both side neighbors; shuffle preserves removed tiles',()=>{
  const m=create('mahjongsolitaire',2);assert.equal(m.matching.tileFree(m.state,8),false);assert.equal(m.matching.tileFree(m.state,1),false);
  const before=snapshot(m);m.tap(8);assert.equal(snapshot(m),before);
  const pair=m.state.target.slice(0,2);m.tap(pair[0]);m.tap(pair[1]);assert.equal(m.state.pieces.filter(p=>!p.alive).length,2);
  m.action();assert(pair.every(i=>!m.state.pieces[i].alive));const order=[...m.state.target];for(const i of order)m.tap(i);assert.equal(m.state.outcome,1);
});
test('group clear rejects singletons and compacts down then left with squared scoring',()=>{
  const m=create('groupclear');m.state.board.fill(0);m.state.board[42]=m.state.board[36]=1;m.state.board[45]=2;m.state.board[46]=3;
  m.tap(45);assert.equal(m.state.moves,0);m.tap(36);assert.equal(m.state.board[42],2);assert.equal(m.state.board[43],3);assert.equal(m.state.score,40);assert.equal(m.state.outcome,2);
  const win=create('groupclear');win.state.board.fill(1);win.tap(0);assert.equal(win.state.score,48*48*10+500);assert.equal(win.state.outcome,1);
});
test('drop pairs cascade after gravity and reject full columns',()=>{
  const m=create('slotpair');m.state.board.fill(0);m.state.board[24]=1;m.state.board[30]=2;m.state.board[31]=2;m.state.target[0]=1;m.state.next=1;
  m.tap(1);assert.equal(m.state.board.filter(Boolean).length,0);assert.equal(m.state.score,160);
  m.state.board.fill(3);const before=snapshot(m);m.tap(0);assert.equal(snapshot(m),before);
});
test('bus capacity respects FIFO, waits on other colors, and undo restores dispatch',()=>{
  const m=create('buscolor',0);m.state.target.fill(1);m.state.pieces.forEach(p=>p.color=1);m.state.board.fill(1);
  m.state.target[0]=2;m.state.pieces[0].color=2;m.state.board.splice(3,3,2,2,2);
  m.tap(0);assert.equal(m.state.cursor,0);assert.deepEqual(m.state.tray,[0]);m.tap(1);assert.equal(m.state.cursor,6);assert.equal(m.state.pieces[0].w,3);assert.equal(m.state.pieces[4].w,3);
  m.undo();assert.equal(m.state.cursor,0);assert.deepEqual(m.state.tray,[0]);assert(m.valid(m.state));
});
test('yarn reels reject other colors, collect runs, finish at eight and undo',()=>{
  const m=create('yarn',0);m.state.board=Array.from({length:32},(_,i)=>Math.floor(i/8)+1);
  m.state.board[7]=2;m.state.board[15]=1;m.choose(0);m.tap(0);assert.deepEqual(m.state.tray.slice(0,2),[2,1]);
  const before=snapshot(m);m.tap(1);assert.equal(snapshot(m),before);m.choose(1);m.tap(1);m.choose(0);m.tap(1);
  assert.equal(m.state.data[1],8);assert.equal(m.state.tray[0],0);assert(m.valid(m.state));m.undo();assert.equal(m.state.data[1],0);
});
test('sand vacuum obeys selected color and can capacity, preserves every grain and undo',()=>{
  const m=create('sand',0);m.state.board=[...new Array(16).fill(1),...new Array(16).fill(2),...new Array(16).fill(3)];
  m.choose(1);const before=snapshot(m);m.tap(0);assert.equal(snapshot(m),before);m.choose(0);m.tap(0);
  assert.equal(m.state.data[0],8);assert.equal(m.state.cursor,8);assert.equal(m.state.score,130);assert(m.valid(m.state));
  m.undo();assert.equal(m.state.cursor,0);assert.equal(m.state.board.length,48);
});
test('untangle counts crossing/touching edges, rejects node collapse, and undo covers a drag',()=>{
  const m=create('untangle',2);const before=snapshot(m);m.tap(0);const p=m.state.pieces[1];m.aim(p.x,p.y);assert.notEqual(m.state.pieces[0].x,p.x);
  m.aim(30,230);m.aim(50,230);m.releaseNode();assert.equal(m.state.moves,1);m.undo();assert.equal(snapshot(m),before);
  for(let i=0;i<m.state.cols;i++){m.state.pieces[i].x=m.state.target[i*2];m.state.pieces[i].y=m.state.target[i*2+1];}
  assert.equal(m.sorting.crossings(m.state),0);const t=m.state.pieces[1];m.state.pieces[1].x=m.state.pieces[2].x;m.state.pieces[1].y=m.state.pieces[2].y;assert(m.sorting.crossings(m.state)>0);
});
test('new sorting and matching saves reject corrupted conservation and graph topology',()=>{
  for(const id of ['linktiles','mahjongsolitaire','slotpair','buscolor','yarn','sand','untangle']){
    const m=create(id);const s=JSON.parse(snapshot(m));
    if(id==='mahjongsolitaire')s.pieces[0].owner=7;
    else if(id==='buscolor')s.pieces[0].w=1;
    else if(id==='yarn'||id==='sand')s.board[0]=0;
    else if(id==='untangle')s.board[0]=3;
    else if(id==='linktiles')s.board[0]=0;
    else s.next=99;
    assert.equal(m.valid(s),false,id);
  }
});
test('untangle ends the drag on background/exit and cannot move through a stale selection',()=>{
  const vm=f.vm('ExpansionViewModel');vm.init('untangle');vm.startGame();vm.tap(0);vm.setDragging(true);vm.aim(30,230);
  vm.onAppHidden();assert.equal(vm.dragging,false);assert.equal(vm.state.selected,-1);const hidden=vm.exportContinuation();vm.aim(60,230);assert.equal(vm.exportContinuation(),hidden);
  vm.onAppShown();vm.aim(60,230);assert.equal(vm.exportContinuation(),hidden);vm.tap(0);vm.setDragging(true);assert(vm.requestBack());assert.equal(vm.dragging,false);assert.equal(vm.state.selected,-1);vm.dispose();
});
test('extreme random sources create playable matching and sorting boards',()=>{
  for(const value of [0,0.999999])for(const id of ['linktiles','mahjongsolitaire','slotpair','buscolor','yarn','sand','untangle']){
    const m=new ExpansionModel({next:()=>value});m.start(id,2);assert(m.valid(m.state),id);
    if(id==='mahjongsolitaire') {for(const i of [...m.state.target])m.tap(i);assert.equal(m.state.outcome,1);}
    if(id==='untangle')assert(m.state.data[0]>0);
  }
});

let failed = 0;
for (const t of tests) { try { t.callback(); console.log(`PASS ${t.name}`); } catch(e) { failed++; console.error(`FAIL ${t.name}: ${e.stack}`); } }
console.log(`${tests.length - failed}/${tests.length} expansion checks passed`);
if (failed) process.exitCode = 1;
