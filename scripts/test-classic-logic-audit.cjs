/* Original 13 audit regressions: run actual ViewModels and extracted 2048 page
 * methods. The retained-key model follows ForEach's unchanged-key contract;
 * ArkUI compilation and visual acceptance are performed separately. */
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const ts = require(process.env.ARKTS_TYPESCRIPT_PATH ||
  'C:/Program Files/Huawei/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const { fixture, Frames } = require('./test-performance.cjs');
const root = path.resolve(__dirname, '..');
const tests = [];
function test(name, run) { tests.push({ name, run }); }
function source(relative) { return fs.readFileSync(path.join(root, relative), 'utf8'); }
function bodyEnd(text, opening) {
  let depth = 0;
  for (let i = opening; i < text.length; i++) {
    if (text[i] === '{') { depth++; }
    if (text[i] === '}' && --depth === 0) { return i + 1; }
  }
  throw new Error('Unclosed source body');
}
function method(text, name) {
  const match = new RegExp(`^  (?:private )?${name}\\([^\\n]*`, 'm').exec(text);
  assert.ok(match, name);
  return text.slice(match.index, bodyEnd(text, text.indexOf('{', match.index)));
}
function page2048(vm) {
  const text = source('entry/src/main/ets/pages/classic/Game2048Page.ets');
  const tile = /class TileData \{[\s\S]*?\n\}/.exec(text)[0].replace(/@Trace\s*/g, '');
  const code = `const SIZE = 4; ${tile}
    class Page {
      tiles: TileData[] = []; tileIdCounter: number = 0;
      settleTimer: number = -1; animationDuration: number = 150;
      viewModel: Object;
      constructor(vm: Object) { this.viewModel = vm; }
      ${['clearSettleTimer', 'startGame', 'swipe', 'rebuildTiles', 'settleScales'].map(name => method(text, name)).join('\n')}
    }
    return new Page(vm);`;
  const js = ts.transpileModule(code, { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText;
  const timers = new Map(); let timerId = 0;
  const page = new Function('vm', 'setTimeout', 'clearTimeout', js)(vm,
    callback => { timers.set(++timerId, callback); return timerId; }, id => timers.delete(id));
  const arrowStart = text.indexOf('(d: GameDifficulty) => {', text.indexOf('onDifficultyChange:'));
  const callback = text.slice(arrowStart, bodyEnd(text, text.indexOf('{', arrowStart)));
  const callbackJs = ts.transpileModule(`const callback = ${callback}; return callback;`, {
    compilerOptions: { target: ts.ScriptTarget.ES2020 }
  }).outputText;
  page.changeDifficulty = new Function(callbackJs).call(page);
  page.settle = () => { for (const callback of timers.values()) { callback(); } timers.clear(); };
  return page;
}
function boardLayout(vm) { return vm.board.flatMap((row,r) => row.flatMap((v,c) => v ? [[r,c,v]] : [])); }
function tileLayout(tiles) { return tiles.map(t => [t.row,t.col,t.value]).sort((a,b) => a[0]-b[0] || a[1]-b[1]); }
function retained(oldItems, newItems) {
  const bound = new Map(oldItems.map(item => [String(item.id), item]));
  return newItems.map(item => bound.get(String(item.id)) || item);
}
function disjointIds(oldItems, newItems) {
  const oldIds = new Set(oldItems.map(item => item.id));
  assert.ok(newItems.every(item => !oldIds.has(item.id)), 'new objects must not bind an old subtree');
  assert.equal(new Set(newItems.map(item => item.id)).size, newItems.length);
}
function jumpKeys(vm) {
  const text=source('entry/src/main/ets/pages/classic/JumpJumpPage.ets');
  const expression=/\}, \(p: PlatformData\) => (.+)\)/.exec(text)[1];
  const key=new Function('p',`return ${expression};`);
  return vm.platforms.map(p=>key.call({viewModel:vm},p));
}
function disjointKeys(before,after) {
  const old=new Set(before);
  assert.ok(after.every(key=>!old.has(key)),'new platform objects must not bind an old subtree');
  assert.equal(new Set(after).size,after.length);
}
function retainedWithKeys(oldItems,newItems,before,after) {
  const bound=new Map(oldItems.map((item,index)=>[before[index],item]));
  return newItems.map((item,index)=>bound.get(after[index]) || item);
}
function jumpFixture() {
  const f = fixture(); const vm = f.vm('JumpJumpViewModel'); const frames = new Frames();
  vm.setFrameLoop(frames); vm.startGame(); return { f,vm,frames };
}
function brickFixture() {
  const f = fixture(); const vm = f.vm('BrickBreakerViewModel', f.rng(8)); const frames = new Frames();
  vm.setFrameLoop(frames); vm.startGame(); return { f,vm,frames };
}

test('2048 difficulty callback synchronizes visible tiles with the new board', () => {
  const f = fixture(); const vm = f.vm('Game2048ViewModel', f.rng(1)); const page = page2048(vm);
  page.startGame();
  for (const move of ['swipeLeft','swipeDown','swipeRight','swipeUp']) { page.swipe(() => vm[move]()); }
  const old = page.tiles.slice(); page.changeDifficulty('hard');
  assert.equal(vm.difficulty, 'hard'); assert.equal(vm.score, 0);
  assert.deepEqual(tileLayout(page.tiles), boardLayout(vm));
  disjointIds(old,page.tiles);
  page.settle(); assert.ok(page.tiles.every(tile => tile.scale === 1));
});

test('2048 repeated restarts create fresh visible identities', () => {
  const f = fixture(); const vm = f.vm('Game2048ViewModel', f.rng(1)); const page = page2048(vm);
  page.startGame();
  for (let i=0;i<8;i++) {
    const old = page.tiles.slice(); page.startGame();
    disjointIds(old,page.tiles); assert.deepEqual(retained(old,page.tiles),page.tiles);
    assert.deepEqual(tileLayout(page.tiles),boardLayout(vm));
  }
});

test('2048 a normal swipe preserves surviving objects for movement animation', () => {
  const f = fixture(); const vm = f.vm('Game2048ViewModel', f.rng(1)); const page = page2048(vm);
  page.startGame(); page.settle(); const old = page.tiles.slice();
  page.swipe(() => vm.swipeLeft());
  assert.ok(page.tiles.some(tile => old.includes(tile)), 'ordinary moves should retain object identity');
  assert.deepEqual(tileLayout(page.tiles),boardLayout(vm));
  page.settle(); assert.ok(page.tiles.every(tile => tile.scale === 1));
});

test('brick restart restores a brick actually broken through public play', () => {
  const { vm } = brickFixture(); vm.launchBall(); let steps=0;
  while (!vm.bricks.some(brick => !brick.alive) && steps++<5000 && vm.status!=='over') {
    vm.dragPaddle(vm.ballX); vm.stepOnce();
  }
  assert.ok(vm.bricks.some(brick => !brick.alive));
  const old=vm.bricks.slice(); vm.startGame();
  disjointIds(old,vm.bricks); assert.ok(retained(old,vm.bricks).every(brick=>brick.alive));
  assert.equal(vm.started,false); assert.equal(vm.level,1); vm.dispose();
});

test('brick importing into a mounted game replaces view identity while preserving layout', () => {
  const { vm } = brickFixture(); const old=vm.bricks.slice(); const payload=vm.exportContinuation();
  assert.equal(vm.importContinuation(payload),true);
  disjointIds(old,vm.bricks);
  assert.deepEqual(vm.bricks.map(b=>[b.row,b.col,b.scoreValue,b.alive]),old.map(b=>[b.row,b.col,b.scoreValue,b.alive]));
  vm.dispose();
});

test('brick level transition replaces all old brick bindings and waits for launch', () => {
  const { f,vm } = brickFixture(); const s=JSON.parse(vm.exportContinuation());
  // A reachable near-clear continuation isolates the final collision and level boundary.
  s.bricksAlive.fill(false); s.bricksAlive[0]=true;
  s.score=s.layouts.slice(1).reduce((sum,b)=>sum+b.scoreValue,0); s.highScore=s.score;
  s.ball.x=vm.sidePadding()+vm.brickWidth()/2;
  s.ball.y=vm.topPadding()+vm.brickHeight()+vm.ballRadius()+1;
  s.ball.vx=0; s.ball.vy=-3; s.started=true;
  assert.equal(vm.importContinuation(JSON.stringify(s)),true);
  const old=vm.bricks.slice(); vm.togglePause(); vm.stepOnce();
  assert.equal(vm.level,2); assert.equal(vm.levelClearMsg,true);
  f.clock.advance(2000); disjointIds(old,vm.bricks);
  assert.ok(retained(old,vm.bricks).every(brick=>brick.alive));
  assert.equal(vm.status,'playing'); assert.equal(vm.started,false); vm.dispose();
});

test('brick normal physics preserves remaining brick objects', () => {
  const { vm }=brickFixture(); const old=vm.bricks.slice(); vm.launchBall();
  for(let i=0;i<150;i++) { vm.dragPaddle(vm.ballX); vm.stepOnce(); }
  assert.ok(vm.bricks.every((brick,i)=>brick===old[i])); vm.dispose();
});

test('jump restart after a successful landing replaces all platform bindings', () => {
  const { f,vm,frames }=jumpFixture(); vm.beginCharge(); f.clock.advance(1200); vm.endCharge(); frames.tick(1000);
  assert.equal(vm.score,1); const old=vm.platforms.slice(); const before=jumpKeys(vm); vm.startGame();
  const after=jumpKeys(vm); disjointKeys(before,after);
  assert.deepEqual(retainedWithKeys(old,vm.platforms,before,after),vm.platforms);
  assert.equal(vm.currentIndex,0); assert.equal(vm.playerX,vm.currentPlatform().centerX); vm.dispose();
});

test('jump import changes UI identities but preserves indices and in-flight geometry', () => {
  const { f,vm,frames }=jumpFixture(); vm.beginCharge(); f.clock.advance(1200); vm.endCharge(); frames.tick(80);
  const keys=jumpKeys(vm); const before=JSON.parse(vm.exportContinuation());
  assert.equal(vm.importContinuation(JSON.stringify(before)),true);
  disjointKeys(keys,jumpKeys(vm)); const after=JSON.parse(vm.exportContinuation());
  assert.deepEqual(after,before);
  frames.tick(1000); assert.equal(vm.score,1); vm.dispose();
});

test('jump normal landing retains existing platform objects for position updates', () => {
  const { f,vm,frames }=jumpFixture(); const old=vm.platforms.slice(); const keys=jumpKeys(vm);
  vm.beginCharge(); f.clock.advance(1200); vm.endCharge(); frames.tick(1000);
  assert.equal(vm.score,1); assert.ok(vm.platforms.every((platform,i)=>platform===old[i]));
  assert.deepEqual(jumpKeys(vm),keys); vm.dispose();
});

test('minesweeper repeated hidden events exclude settings and background time', () => {
  const f=fixture(); f.data().init({}); const vm=f.vm('MinesweeperViewModel',f.rng(1));
  const bus=f.load('entry/src/main/ets/common/GameLifecycleBus.ets').GameLifecycleBus;
  vm.startGame(); bus.attach(vm); vm.reveal(4,4); bus.updatePlayTime(vm); f.clock.advance(2000);
  bus.setSettingsVisible('minesweeper',true); assert.equal(vm.elapsed,2);
  f.clock.advance(9000); bus.notifyHidden(); assert.equal(vm.elapsed,2);
  f.clock.advance(6000); bus.notifyShown(); assert.equal(vm.elapsed,2);
  bus.setPageVisible('minesweeper',false); bus.setSettingsVisible('minesweeper',false);
  assert.equal(vm.elapsed,2); bus.setPageVisible('minesweeper',true);
  f.clock.advance(1000); assert.equal(vm.elapsed,3); bus.detach(vm); vm.dispose();
});

test('minesweeper restart and a single pause still reset and resume time', () => {
  const f=fixture(); const vm=f.vm('MinesweeperViewModel',f.rng(1)); vm.startGame(); vm.reveal(4,4);
  f.clock.advance(3000); vm.onAppHidden(); f.clock.advance(5000); vm.onAppShown(); f.clock.advance(1000);
  assert.equal(vm.elapsed,4); vm.startGame(); assert.equal(vm.elapsed,0);
  f.clock.advance(5000); assert.equal(vm.elapsed,0); vm.dispose();
});

test('minesweeper preserves fractional seconds across repeated visibility pauses', () => {
  const f=fixture(); const vm=f.vm('MinesweeperViewModel',f.rng(1)); vm.startGame(); vm.reveal(4,4);
  f.clock.advance(600); vm.onAppHidden(); assert.equal(vm.elapsed,0);
  f.clock.advance(8000); vm.onAppHidden(); vm.onAppShown();
  f.clock.advance(600); vm.onAppHidden(); assert.equal(vm.elapsed,1);
  assert.equal(JSON.parse(vm.exportContinuation()).elapsed,1);
  vm.onAppShown(); f.clock.advance(800); vm.onAppHidden(); assert.equal(vm.elapsed,2);
  vm.startGame(); assert.equal(vm.elapsed,0); vm.reveal(4,4);
  f.clock.advance(600); vm.onAppHidden(); assert.equal(vm.elapsed,0); vm.dispose();
});

test('minesweeper exit confirmation suspends the timer and retains the partial second', () => {
  const f=fixture(); const vm=f.vm('MinesweeperViewModel',f.rng(1)); vm.startGame(); vm.reveal(4,4);
  f.clock.advance(600); assert.equal(vm.requestBack(),true);
  f.clock.advance(4400); assert.equal(vm.elapsed,0);
  assert.equal(JSON.parse(vm.exportContinuation()).elapsed,0);
  vm.onAppHidden(); f.clock.advance(2000); vm.onAppShown();
  f.clock.advance(3000); assert.equal(vm.elapsed,0); assert.equal(vm.confirmExit,true);
  vm.dismissExitConfirm(); f.clock.advance(600); vm.onAppHidden(); assert.equal(vm.elapsed,1); vm.dispose();
});

test('minesweeper dismissing confirmation under settings, page hiding or background waits for visibility', () => {
  const f=fixture(); const vm=f.vm('MinesweeperViewModel',f.rng(1));
  const bus=f.load('entry/src/main/ets/common/GameLifecycleBus.ets').GameLifecycleBus;
  vm.startGame(); bus.attach(vm); vm.reveal(4,4); f.clock.advance(600);
  assert.equal(bus.notifyBackRequested(),true); bus.setSettingsVisible('minesweeper',true);
  vm.dismissExitConfirm(); f.clock.advance(5000); assert.equal(vm.elapsed,0);
  bus.notifyHidden(); bus.setSettingsVisible('minesweeper',false);
  f.clock.advance(4000); assert.equal(vm.elapsed,0);
  bus.setPageVisible('minesweeper',false); bus.notifyShown();
  f.clock.advance(3000); assert.equal(vm.elapsed,0);
  bus.setPageVisible('minesweeper',true); f.clock.advance(600); bus.notifyHidden();
  assert.equal(vm.elapsed,1); bus.detach(vm); vm.dispose();
});

test('minesweeper settles the final partial interval before scoring a 1.2-second win', () => {
  const f=fixture(); const vm=f.vm('MinesweeperViewModel',f.rng(1)); vm.startGame(); vm.reveal(4,4);
  f.clock.advance(600); vm.onAppHidden(); f.clock.advance(8000); vm.onAppShown();
  f.clock.advance(600); assert.equal(vm.elapsed,0);
  for(let row=0;row<vm.rows();row++) {
    for(let col=0;col<vm.cols();col++) {
      if(!vm.isMine(row,col) && !vm.isRevealed(row,col)) { vm.reveal(row,col); }
    }
  }
  assert.equal(vm.gameResult,true); assert.equal(vm.status,'over'); assert.equal(vm.elapsed,1);
  assert.equal(f.data().getGameById('minesweeper').highScore,995);
  f.clock.advance(5000); vm.onAppShown(); assert.equal(vm.elapsed,1); vm.dispose();
});

test('minesweeper continuation seeds the millisecond timer from the existing integer snapshot', () => {
  const f=fixture(); const vm=f.vm('MinesweeperViewModel',f.rng(1)); vm.startGame(); vm.reveal(4,4);
  f.clock.advance(1200); const payload=vm.exportContinuation(); assert.equal(JSON.parse(payload).elapsed,1);
  const target=f.vm('MinesweeperViewModel',f.rng(2)); assert.equal(target.importContinuation(payload),true);
  f.clock.advance(600); target.onAppHidden(); assert.equal(target.elapsed,1);
  f.clock.advance(3000); target.onAppShown(); f.clock.advance(600); target.onAppHidden();
  assert.equal(target.elapsed,2); target.dispose(); vm.dispose();
});

test('guess history keeps early clues after seven guesses within a six-row scroll window', () => {
  const f=fixture(); const vm=f.vm('GuessNumberViewModel',f.rng(7)); vm.startGame();
  const first=vm.secret.split('').reverse().join('');
  for(let i=0;i<7;i++) {
    for(const digit of first) { vm.pushDigit(digit); }
    vm.submit();
  }
  assert.equal(vm.status,'playing'); assert.equal(vm.records.length,7);
  const page=source('entry/src/main/ets/pages/puzzle/GuessNumberPage.ets');
  const records=/ForEach\((this\.viewModel\.records[^,]*),/.exec(page)[1];
  const rendered=new Function(`return ${records};`).call({viewModel:vm});
  assert.equal(rendered.length,7); assert.equal(rendered.at(-1).seq,1);
  assert.equal(rendered.at(-1).guess,first);
  const height=/\}\.height\((Math\.min\(this\.viewModel\.records\.length \* 40, 240\))\)/.exec(page)[1];
  assert.equal(new Function(`return ${height};`).call({viewModel:vm}),240);
  vm.dispose();
});

function pausable(name) {
  const f=fixture(); const vm=f.vm(name,f.rng(8)); const frames=new Frames();
  if(name==='BrickBreakerViewModel') { vm.setFrameLoop(frames); }
  vm.startGame();
  if(name==='SnakeViewModel') { vm.turnRight(); }
  if(name==='BrickBreakerViewModel') { vm.launchBall(); }
  return { f,vm,frames };
}
function progress(name,vm) {
  if(name==='SnakeViewModel') { return JSON.stringify(vm.snake); }
  if(name==='TetrisViewModel') { return JSON.stringify(vm.piece); }
  if(name==='WhackMoleViewModel') { return String(vm.timeLeft); }
  return JSON.stringify([vm.ballX,vm.ballY]);
}
function advance(name,f,frames) {
  f.clock.advance(name==='WhackMoleViewModel'?1100:800);
  if(name==='BrickBreakerViewModel') { frames.tick(60); }
}
for(const name of ['SnakeViewModel','TetrisViewModel','WhackMoleViewModel','BrickBreakerViewModel']) {
  test(`${name}: both back routes confirm manual pause and cancelling retains frozen state`, () => {
    const {f,vm,frames}=pausable(name); vm.togglePause();
    const before=progress(name,vm);
    assert.equal(vm.requestBack(),true); assert.equal(vm.confirmExit,true);
    advance(name,f,frames); assert.equal(progress(name,vm),before);
    vm.dismissExitConfirm(); assert.equal(vm.status,'paused'); assert.equal(vm.confirmExit,false);
    advance(name,f,frames); assert.equal(progress(name,vm),before);
    assert.equal(vm.onBackRequested(),true); vm.dismissExitConfirm();
    vm.togglePause(); advance(name,f,frames);
    assert.equal(vm.status,'playing'); assert.notEqual(progress(name,vm),before); vm.dispose();
  });
  test(`${name}: cancelling an active-game confirmation resumes progression`, () => {
    const {f,vm,frames}=pausable(name); const before=progress(name,vm);
    assert.equal(vm.onBackRequested(),true); advance(name,f,frames);
    assert.equal(progress(name,vm),before); vm.dismissExitConfirm(); advance(name,f,frames);
    assert.equal(vm.status,'playing'); assert.notEqual(progress(name,vm),before); vm.dispose();
  });
  test(`${name}: disabled confirmation and finished games exit directly`, () => {
    const {f,vm}=pausable(name); vm.togglePause(); f.data().setSetting('confirmExitEnabled',false);
    assert.equal(vm.requestBack(),false); assert.equal(vm.confirmExit,false);
    vm.togglePause(); assert.equal(vm.onBackRequested(),false); assert.equal(vm.confirmExit,false);
    f.data().setSetting('confirmExitEnabled',true); vm.status='over';
    assert.equal(vm.requestBack(),false); assert.equal(vm.onBackRequested(),false);
    assert.equal(vm.confirmExit,false); vm.dispose();
  });
}

test('jump repeated continuation replaces rendering keys and preserves the complete game before landing', () => {
  const {f,vm,frames}=jumpFixture();
  for(let jump=0;jump<8;jump++) {
    vm.beginCharge(); f.clock.advance(1200); vm.endCharge(); frames.tick(80);
    const keys=jumpKeys(vm); const payload=vm.exportContinuation();
    assert.equal(vm.importContinuation(payload),true); disjointKeys(keys,jumpKeys(vm));
    assert.deepEqual(JSON.parse(vm.exportContinuation()),JSON.parse(payload));
    frames.tick(1000); assert.equal(vm.score,jump+1);
    assert.equal(new Set(vm.platforms.map(p=>p.id)).size,vm.platforms.length);
    assert.equal(vm.playerX,vm.currentPlatform().centerX);
    assert.equal(vm.playerX,vm.baseScreenX());
  }
  vm.dispose();
});

test('jump many self-imports remain valid and a fresh VM can still resume the stored game', () => {
  const {vm}=jumpFixture(); const original=vm.platforms.map(p=>[p.centerX,p.width]);
  for(let restore=0;restore<64;restore++) {
    const keys=jumpKeys(vm); const payload=vm.exportContinuation();
    assert.equal(vm.importContinuation(payload),true,`restore ${restore+1}`);
    disjointKeys(keys,jumpKeys(vm));
    assert.deepEqual(JSON.parse(vm.exportContinuation()),JSON.parse(payload));
    assert.deepEqual(vm.platforms.map(p=>[p.centerX,p.width]),original);
  }
  const f=fixture(); const target=f.vm('JumpJumpViewModel'); const frames=new Frames();
  target.setFrameLoop(frames); const sourcePayload=vm.exportContinuation();
  assert.equal(target.importContinuation(sourcePayload),true);
  const validation=f.load('entry/src/main/ets/common/GameSessionTransfer.ets').ContinuationValidation;
  const stored=JSON.parse(target.exportContinuation());
  assert.deepEqual(stored,JSON.parse(sourcePayload));
  assert.equal(validation.integer(stored.platformId),true);
  assert.ok(stored.platforms.every(p=>validation.integer(p.id,1)));
  for(let jump=0;jump<8;jump++) {
    target.beginCharge(); f.clock.advance(1200); target.endCharge(); frames.tick(1000);
    assert.equal(target.score,jump+1);
    assert.equal(new Set(target.platforms.map(p=>p.id)).size,target.platforms.length);
  }
  assert.equal(vm.importContinuation(target.exportContinuation()),true);
  assert.equal(vm.score,8); vm.dispose(); target.dispose();
});

let failed=0;
for(const entry of tests) {
  try { entry.run(); } catch(error) { failed++; console.error(`FAIL ${entry.name}\n${error.stack}`); }
}
console.log(`${tests.length-failed}/${tests.length} classic logic audit regressions passed.`);
process.exitCode=failed?1:0;
