const assert = require('node:assert/strict');
const fs = require('node:fs');
const { fixture } = require('./test-performance.cjs');
const tests = [];
const test = (name, fn) => tests.push({ name, fn });
const f = fixture();
const { CollectionModel, COLLECTION_IDS } = f.rules('Collection');
const create = (id, level = 1, seed = 7) => { const m = new CollectionModel(f.rng(seed)); m.start(id, level); return m; };
const before = m => JSON.stringify(m.state);

test('catalog: all games are distinct with nonempty categories, bidirectional routes and localized assets', () => {
  const games = f.data().getAllGames(); const categories = f.load('entry/src/main/ets/common/GameConstants.ets').GAME_CATEGORIES;
  const routes = f.load('entry/src/main/ets/router/GameRouteRegistry.ets').GameRoutes;
  const expansion = f.load('entry/src/main/ets/model/ExpansionCatalog.ets').EXPANSION_IDS;
  assert.equal(games.length, 33 + expansion.length); assert.equal(new Set(games.map(g => g.id)).size, games.length); assert.equal(categories.length, 6);
  for (const cat of categories) assert(games.some(g => g.category === cat));
  for (const g of games) { assert(routes.routeName(g.id)); assert.equal(routes.gameIdForRoute(routes.routeName(g.id)), g.id); }
  assert.equal(routes.routeName('invalid'), ''); assert.equal(routes.gameIdForRoute('Collection_invalid'), '');
  for (const locale of ['base', 'zh_CN', 'en_US']) {
    const values = JSON.parse(fs.readFileSync(`entry/src/main/resources/${locale}/element/string.json`)).string;
    assert.equal(values.length, new Set(values.map(v => v.name)).size);
    for (const id of COLLECTION_IDS) {
      for (const suffix of ['name', 'desc', 'rules']) assert(values.some(v => v.name === `game_${id}_${suffix}` && v.value));
      assert(fs.existsSync(`entry/src/main/resources/base/media/game_${id}.svg`));
    }
  }
});

for (const id of COLLECTION_IDS) {
  for (const level of [0, 1, 2]) {
    test(`${id}/${level}: valid startup, rejected out-of-range input, continuation round trip`, () => {
      const model = create(id, level); const initial = before(model);
      model.tap(-1); model.tap(999); model.tap(NaN); model.choose(-1); model.choose(999); model.choose(NaN);
      assert.equal(before(model), initial);
      const source = f.vm('CollectionViewModel'); source.init(id); source.difficulty = ['easy', 'normal', 'hard'][level]; source.startGame();
      const target = f.vm('CollectionViewModel'); target.init(id);
      const count = f.data().getGameById(id).playCount;
      assert.equal(target.importContinuation(source.exportContinuation()), true);
      assert.deepEqual(JSON.parse(target.exportContinuation()), JSON.parse(source.exportContinuation()));
      assert.equal(f.data().getGameById(id).playCount, count);
      const snapshot = target.exportContinuation();
      for (const invalid of ['null', '{}', '{bad', 'x'.repeat(16385)]) { assert.equal(target.importContinuation(invalid), false); assert.equal(target.exportContinuation(), snapshot); }
      const malformed = JSON.parse(snapshot); malformed.state.cols = 200;
      assert.equal(target.importContinuation(JSON.stringify(malformed)), false); assert.equal(target.exportContinuation(), snapshot);
      assert.equal(source.requestBack(), true); source.dismissExitConfirm(); source.dispose(); target.dispose();
    });
  }
}

test('three-in-a-row: occupied squares, both winners, draw and terminal input lock', () => {
  const m = create('tictactoe'); m.tap(0); const played = before(m); m.tap(0); assert.equal(before(m), played);
  for (const i of [3, 1, 4, 2]) m.tap(i); assert.equal(m.state.outcome, 1);
  const finished = before(m); m.tap(8); assert.equal(before(m), finished);
  m.start('tictactoe', 1); for (const i of [0,3,1,4,8,5]) m.tap(i); assert.equal(m.state.outcome, 2);
  m.start('tictactoe', 1); for (const i of [0,1,2,4,3,5,7,6,8]) m.tap(i); assert.equal(m.state.outcome, 3);
});
test('five-in-a-row: horizontal, vertical, both diagonals and no row wrapping', () => {
  for (const line of [[0,1,2,3,4],[0,9,18,27,36],[0,10,20,30,40],[8,16,24,32,40]]) {
    const m = create('gomoku'); for (let i=0;i<5;i++) { m.tap(line[i]); if (i<4) m.tap(72+i*2); } assert.equal(m.state.outcome,1);
  }
  const m = create('gomoku'); for (const i of [7,60,8,62,9,64,10,66,11]) m.tap(i); assert.equal(m.state.outcome,0);
});
test('falling four: gravity, full column rejection and vertical win', () => {
  const m=create('fourline'); for (const i of [0,1,0,1,0,1,0]) m.tap(i); assert.equal(m.state.outcome,1);
  assert.equal(m.state.board[35],1); assert.equal(m.state.board[14],1);
  m.start('fourline',1); for(let i=0;i<6;i++)m.tap(0); const full=before(m);m.tap(0);assert.equal(before(m),full);
});
test('disc reversal: legal capture, forced pass and two-player terminal scoring', () => {
  const m=create('reversi'); assert.equal(m.flips(0,1).length,0); const s=before(m);m.tap(0);assert.equal(before(m),s);
  let turns=0;while(!m.state.outcome){ const legal=m.state.board.findIndex((v,i)=>m.flips(i,m.state.player).length);assert(legal>=0);m.tap(legal);assert(++turns<=32); }
  const a=m.state.board.filter(v=>v===1).length,b=m.state.board.filter(v=>v===2).length;
  assert.equal(m.state.outcome,a===b?3:a>b?1:2);
  // A legal capture with no reply hands the move back to the same player.
  const pass=create('reversi');pass.state.board.fill(1);pass.state.board[0]=0;pass.state.board[1]=2;pass.state.board[30]=0;pass.state.board[31]=2;
  pass.tap(0);assert.equal(pass.state.player,1);assert.equal(pass.state.outcome,0);pass.tap(30);assert.equal(pass.state.outcome,1);
});
test('take stones: reject overdraw and last stone determines winner', () => {
  const m=create('nim');m.state.board=[2];const s=before(m);m.choose(2);assert.equal(before(m),s);m.choose(1);assert.equal(m.state.outcome,1);
});

// Solve the binary linear system independently to verify every generated lights puzzle.
function solveLights(m) {
  const n=m.state.board.length, c=m.state.cols;
  const rows=Array.from({length:n},(_,i)=>Array.from({length:n+1},(_,j)=>j===n?m.state.board[i]:Number(i===j || (Math.abs(i-j)===c) || (Math.floor(i/c)===Math.floor(j/c)&&Math.abs(i-j)===1))));
  const pivots=[];let rank=0;
  for(let col=0;col<n;col++){let r=rows.findIndex((row,index)=>index>=rank&&row[col]);if(r<0)continue;[rows[rank],rows[r]]=[rows[r],rows[rank]];
    for(let k=0;k<n;k++)if(k!==rank&&rows[k][col])for(let j=col;j<=n;j++)rows[k][j]^=rows[rank][j];pivots.push(col);rank++;}
  for(let i=rank;i<n;i++)assert.equal(rows[i][n],0,'unsolvable generated lights board');
  for(let i=0;i<rank;i++)if(rows[i][n])m.tap(pivots[i]);assert.equal(m.state.outcome,1);
}
function solveMaze(m) {
  const start=m.state.cursor,end=m.state.answer,q=[start],prev=new Map([[start,-1]]);
  for(let i=0;i<q.length;i++)for(let d=0;d<4;d++){const n=m.neighbor(q[i],d);if(n>=0&&m.state.board[n]===0&&!prev.has(n)){prev.set(n,q[i]);q.push(n);}}
  assert(prev.has(end));const path=[];for(let at=end;at!==start;at=prev.get(at))path.unshift(at);for(const at of path)m.tap(at);assert.equal(m.state.outcome,1);
}
function solvePeg(m) {
  const seen=new Set();
  const search=board=>{
    if(board.filter(v=>v===1).length===1)return [];
    const key=board.join(',');if(seen.has(key))return null;seen.add(key);
    for(let i=0;i<board.length;i++)for(let d=0;d<4;d++){const mid=m.neighbor(i,d),end=m.neighbor(mid,d);
      if(board[i]!==1||mid<0||end<0||board[mid]!==1||board[end]!==0)continue;
      const next=board.slice();next[i]=0;next[mid]=0;next[end]=1;const path=search(next);if(path)return [[i,end],...path];}
    return null;
  };
  const path=search(m.state.board);assert(path&&path.length>0);for(const [from,to]of path){m.tap(from);m.tap(to);}assert.equal(m.state.outcome,1);
}
function floodTrial(m,color){
 const b=m.state.board.slice(),old=b[0],q=[0];b[0]=color;
 for(let i=0;i<q.length;i++)for(let d=0;d<4;d++){const n=m.neighbor(q[i],d);if(n>=0&&b[n]===old){b[n]=color;q.push(n);}}
 const region=new Set([0]),rq=[0];for(let i=0;i<rq.length;i++)for(let d=0;d<4;d++){const n=m.neighbor(rq[i],d);if(n>=0&&b[n]===color&&!region.has(n)){region.add(n);rq.push(n);}}
 return region.size;
}
for(const level of [0,1,2])test(`generated puzzles/${level}: 30 seeds each are solvable through legal actions`,()=>{
 for(let seed=1;seed<=30;seed++){
  solveLights(create('lights',level,seed));solveMaze(create('maze',level,seed));solvePeg(create('peg',level,seed));
  const m=create('flood',level,seed);while(!m.state.outcome){let color=-1,size=-1;for(let c=0;c<4;c++)if(c!==m.state.board[0]){const n=floodTrial(m,c);if(n>size){size=n;color=c;}}m.choose(color);}assert.equal(m.state.outcome,1);
  const n=create('nonogram',level,seed);n.action();assert.equal(n.state.outcome,0);n.state.target.forEach((v,i)=>{if(v)n.tap(i);});n.action();assert.equal(n.state.outcome,1);
 }
});
test('tower transfer: illegal larger disc is blocked; all difficulties solve in 2^n−1 moves',()=>{
 for(const level of [0,1,2]){const m=create('hanoi',level);m.choose(0);m.choose(1);m.choose(0);m.choose(1);assert.equal(m.state.moves,1);
  m.start('hanoi',level);const solve=(n,from,to,other)=>{if(!n)return;solve(n-1,from,other,to);m.choose(from);m.choose(to);solve(n-1,other,to,from);};solve(m.state.board.length,0,2,1);
  assert.equal(m.state.outcome,1);assert.equal(m.state.moves,2**(3+level)-1);}
});
test('nonogram accepts a different board with identical run clues',()=>{
 const m=create('nonogram',0);m.state.target=[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1];
 m.state.board=[0,0,0,1,0,0,1,0,0,1,0,0,1,0,0,0];m.action();assert.equal(m.state.outcome,1);
});
for(const id of ['arithmetic','compare','sequence','binary','targetsum','missing'])test(`${id}: 30 questions score correctly, wrong answers earn zero, terminal lock`,()=>{
 for(const level of [0,1,2]){const m=create(id,level);
  for(let q=0;q<10;q++){const a=m.state.answer;assert(m.state.choices.includes(a));assert.equal(new Set(m.state.choices).size,m.state.choices.length);
   const nums=m.state.prompt.match(/\d+/g)?.map(Number)||[];
   if(id==='arithmetic')assert.equal(a,m.state.prompt.includes('+')?nums[0]+nums[1]:m.state.prompt.includes('−')?nums[0]-nums[1]:nums[0]*nums[1]);
   if(id==='compare')assert.equal(a,Math.sign(nums[0]+nums[1]-nums[2]-nums[3]));
   if(id==='sequence'){const t=m.state.target;assert.equal(a,t[2]-t[1]===t[1]-t[0]?t[3]+t[1]-t[0]:t[3]*2);}
   if(id==='binary')assert.equal(a,parseInt(m.state.prompt.split('₂')[0],2));
   if(id==='targetsum')assert.equal(a,nums[2]-nums[0]-nums[1]);
   if(id==='missing'){const snapshot=before(m);m.choose(0);assert.equal(before(m),snapshot);m.action();assert(!m.state.board.includes(a));}
   m.choose(m.state.choices.indexOf(a));}
  assert.equal(m.state.outcome,1);assert.equal(m.state.score,1000*(level+1));const done=before(m);m.choose(0);assert.equal(before(m),done);
  m.start(id,level);for(let q=0;q<10;q++){if(id==='missing')m.action();m.choose(m.state.choices.findIndex(v=>v!==m.state.answer));}assert.equal(m.state.score,0);
 }
});
test('number search and sequence recall enforce order and errors',()=>{
 const m=create('schulte');const wrong=m.state.board.findIndex(v=>v!==1);m.tap(wrong);assert.equal(m.state.answer,1);
 for(let value=1;value<=m.state.board.length;value++)m.tap(m.state.board.indexOf(value));assert.equal(m.state.outcome,1);
 const r=create('memorysequence');const snapshot=before(r);r.tap(0);assert.equal(before(r),snapshot);r.action();for(const value of r.state.target)r.tap(value-1);assert.equal(r.state.outcome,1);
 r.start('memorysequence',1);r.action();r.tap(r.state.target[0]%9);assert.equal(r.state.outcome,2);
});
test('reaction: early taps fail, signal timing scores, background/exit cancel timer',()=>{
 const m=create('reaction');m.tap(0,100);m.tap(0,101);assert.equal(m.state.outcome,2);
 m.start('reaction',1);m.tap(0,100);const time=m.state.signalAt;m.tick(time);m.tap(0,time+235);assert.equal(m.state.answer,235);assert.equal(m.state.score,1765);
 const f=fixture(),vm=f.vm('CollectionViewModel');vm.init('reaction');vm.startGame();vm.tap(0);assert.equal(f.clock.count(),1);
 vm.onAppHidden();assert.equal(f.clock.count(),0);assert.equal(vm.state.phase,0);vm.onAppShown();vm.tap(0);f.clock.advance(5000);assert.equal(vm.state.phase,2);
 vm.requestBack();assert.equal(vm.state.phase,0);assert.equal(f.clock.count(),0);vm.dismissExitConfirm();vm.tap(0);vm.dispose();assert.equal(f.clock.count(),0);
});
test('score/round persistence: result is counted once, replay and restoration never double-award',()=>{
 const f=fixture(),vm=f.vm('CollectionViewModel');vm.init('tictactoe');vm.startGame();for(const i of [0,3,1,4,2])vm.tap(i);
 const data=f.data();assert.equal(data.getGameById('tictactoe').highScore,1);vm.tap(8);assert.equal(data.getGameById('tictactoe').highScore,1);
 const target=f.vm('CollectionViewModel');target.init('tictactoe');assert(target.importContinuation(vm.exportContinuation()));assert.equal(data.getGameById('tictactoe').highScore,1);
 vm.startGame();assert.equal(data.getGameById('tictactoe').playCount,2);assert.equal(vm.state.outcome,0);
});
test('continuation rejects malformed choices and selected pieces without mutation',()=>{
 for(const id of ['flood','nim','hanoi','nonogram','peg','memorysequence','missing']){
  const vm=f.vm('CollectionViewModel');vm.init(id);vm.startGame();const snapshot=vm.exportContinuation();const bad=JSON.parse(snapshot);
  if(['flood','nim','hanoi'].includes(id))bad.state.choices[0]=999;
  if(id==='nonogram')bad.state.target[0]=2;
  if(id==='peg')bad.state.selected=100;
  if(id==='memorysequence')bad.state.board[0]=9;
  if(id==='missing')bad.state.choices[0]=999;
  assert.equal(vm.importContinuation(JSON.stringify(bad)),false);assert.equal(vm.exportContinuation(),snapshot);
 }
});
test('reaction continuation resets an active trial without altering the source',()=>{
 const vm=f.vm('CollectionViewModel');vm.init('reaction');vm.startGame();vm.tap(0);const snapshot=vm.exportContinuation();
 const target=f.vm('CollectionViewModel');target.init('reaction');assert(target.importContinuation(snapshot));assert.equal(target.state.phase,0);
 assert.equal(vm.exportContinuation(),snapshot);vm.dispose();target.dispose();
});

let passed=0;for(const t of tests){try{t.fn();passed++;}catch(e){console.error('FAIL',t.name);console.error(e.stack);}}
console.log(`${passed}/${tests.length} collection regressions passed.`);process.exitCode=passed===tests.length?0:1;
