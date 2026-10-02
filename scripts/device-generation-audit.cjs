// Acceptance of the installed generation fixes through real rendered device UI.
// Existing gameplay cases are reused with a fresh evidence prefix and checkpoint.
const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');
process.env.LITTLEGAMES_DEVICE_CHECKPOINT = 'generation-audit-2026-10-02.json';
process.env.LITTLEGAMES_DEVICE_LOG = 'generation-audit-2026-10-02-actions.jsonl';
const checkpoint = path.resolve('docs/device-acceptance', process.env.LITTLEGAMES_DEVICE_CHECKPOINT);
fs.writeFileSync(checkpoint, fs.readFileSync(checkpoint, 'utf8').replace(/^\uFEFF/, ''));
const c = require('./device-acceptance-core.cjs');
c.log('audit-session',{mode:process.argv[2],args:process.argv.slice(3),packageHash:JSON.parse(fs.readFileSync(checkpoint,'utf8')).packageHash});
const { assert, layout, text, find, click, tap, wait, open, back, capture, board, bounds, descendants, sleep, record } = c;
const strings = JSON.parse(fs.readFileSync('entry/src/main/resources/zh_CN/element/string.json')).string;
const label = id => strings.find(s => s.name === 'game_' + id + '_name').value;
const prefix = 'audit-20261002';
const initialUi=layout();if(find(initialUi,'精选')&&find(initialUi,'分类')&&find(initialUi,'我的')){tap('分类',initialUi);wait(a=>a.some(n=>n.type==='TextInput'));}
let caseId, evidence = [];
const shot = tag => { const id = prefix + '-' + caseId + '-' + tag; evidence.push(id); return capture(id); };
function reuse(filename, suffix) {
  const full = path.resolve('scripts', filename);
  let source = fs.readFileSync(full, 'utf8');
  const marker = filename.includes('collection') ? 'const selected=process.argv.slice(2)' : 'for(const id of process.argv.slice(2))';
  source = source.slice(0, source.indexOf(marker)).replaceAll('play-mate60-all-', prefix + '-' + suffix + '-');
  source = source.replace('const options=choices(ns),correct=', 'const options=choices(ns);assert.equal(new Set(options.map(o=>o.value)).size,options.length,"Duplicate rendered choices");const correct=');
  if(suffix.endsWith('-简单'))source=source.replaceAll('1800','900');
  if(suffix.endsWith('-困难'))source=source.replaceAll('1800','2700');
  // Klotski retains the selected piece after a move. Repeatedly tapping it
  // would deselect it, so consecutive moves of one piece only use the arrows.
  source=source.replace('let currentPieces=pieces;for(const step of route)', 'let currentPieces=pieces,lastPiece=-1;for(const step of route)')
    .replace('const p=currentPieces[step.piece];c.shell(', 'const p=currentPieces[step.piece];if(lastPiece!==step.piece)c.shell(')
    .replace('click(controls[step.dir]);currentPieces=step.a;', 'click(controls[step.dir]);lastPiece=step.piece;currentPieces=step.a;');
  source += filename.includes('collection') ? '\nmodule.exports = { run(id) { current=id; evidence.length=0; const cases=specs[id](); return {cases,evidence:evidence.slice()}; } };' : '\nmodule.exports = { grid, nums, headerRestart, run(id) { current=id; ev=[]; const cases=spec[id](); return {cases,evidence:ev.slice()}; } };';
  const mod = new Module(full, module); mod.filename=full; mod.paths=module.paths; mod._compile(source,full); return mod.exports;
}
function difficulty(name) {
  let ns=layout(); const header=find(ns, strings.find(s=>s.name==='a11y_header_difficulty').value)||ns.filter(n=>n.type==='Button'&&bounds(n)[1]<300).sort((a,b)=>bounds(a)[0]-bounds(b)[0])[1];
  assert(header, 'Difficulty control absent'); click(header); ns=wait(a=>find(a,'简单')&&find(a,'普通')&&find(a,'困难'));
  tap(name,ns); sleep(250); return wait(a=>!a.some(n=>n.type==='MenuItem'));
}
const neighbors=(i,n)=>[i-n,i%n<n-1?i+1:-1,i+n,i%n?i-1:-1].filter(v=>v>=0&&v<n*n);
const routeTo=(prev,start,end)=>{const out=[];for(let p=end;p!==start;p=prev.get(p)){assert(prev.has(p));out.unshift(p);}return out;};
function maze(name,n) {
  caseId='maze-'+n; evidence=[]; back();open(label('maze')); difficulty(name);
  const ns=shot('board'),bs=board(ns); assert.equal(bs.length,n*n);
  const values=c.pixels(prefix+'-'+caseId+'-pixels',bs,'maze');evidence.push(prefix+'-'+caseId+'-pixels');
  const imageCount=b=>descendants(b).filter(d=>d.type==='Image').length;
  const start=n+1,end=n*n-n-2;assert.equal(imageCount(bs[start]),2);assert.equal(imageCount(bs[end]),2);
  values[start]=values[end]=0;const walls=values.map(v=>v===1);
  const q=[start],prev=new Map([[start,-1]]); for(let k=0;k<q.length;k++)for(const j of neighbors(q[k],n))if(!walls[j]&&!prev.has(j)){q.push(j);prev.set(j,q[k]);}
  assert(prev.has(end),'Displayed maze exit unreachable');assert.equal(q.length,walls.filter(v=>!v).length,'Disconnected floor');
  const winPath=routeTo(prev,start,end),pathSet=new Set([start,...winPath]);
  const dead=q.find(i=>i!==start&&i!==end&&!pathSet.has(i)&&neighbors(i,n).filter(j=>!walls[j]).length===1);
  click(bs[0]);assert(text(layout()).includes('已用 0 步'),'Wall tap changed maze');
  let detour=[];
  if(dead!==undefined){detour=routeTo(prev,start,dead);for(const i of detour)click(bs[i]);
    assert.equal(imageCount(board()[dead]),2);shot('dead-end');
    for(const i of [...detour.slice(0,-1).reverse(),start])click(bs[i]);
    assert.equal(imageCount(board()[start]),2);shot('backtracked');}
  for(const i of winPath)click(bs[i]); const result=shot('win');assert(find(result,'再来一局'));assert(text(result).some(s=>s.includes('挑战完成')));
  tap('再来一局',result);assert.equal(board().length,n*n);shot('restart');back();
  record(label('maze')+'·'+name,caseId,['屏幕 '+n+'×'+n+' 地图全部道路连通','墙格不能穿越',dead===undefined?'本张随机地图没有额外死胡同':('进入死胡同 '+detour.length+' 步并原路返回'),'合法相邻移动到出口，主路线 '+winPath.length+' 步','结算及同难度重新生成'],evidence,{floorCount:q.length,route:winPath,detour,grid:n});
}
function legacy(id,name,which) {
  if(id==='match3'){match3();return;}
  caseId=id+(name?'-'+name:''); evidence=[]; back();open(label(id));if(name)difficulty(name);
  shot('ready'); const suite=reuse(which==='collection'?'device-collection-continuous.cjs':'device-standalone-continuous.cjs',caseId);
  if(id==='peg'){const count=board().filter(b=>descendants(b).filter(d=>d.type==='Image').length===2).length;assert.equal(count,{'简单':5,'普通':6,'困难':7}[name]);}
  const extraCases=[];
  if(id==='sudoku'){wait(a=>!find(a,'正在准备题目…'),30000);const initial=suite.grid().map(b=>suite.nums(b)[0]||0),clues=initial.filter(Boolean).length;assert(name==='简单'?clues===45:name==='普通'?clues===29:clues>=23&&clues<29);assert.equal(sudokuSolutions(initial),1);extraCases.push('实际题面提示数 '+clues+'，独立求解确认唯一解','切换后重开保持本难度题面');
    const header=layout().filter(n=>n.type==='Button'&&bounds(n)[1]<300).sort((a,b)=>bounds(a)[0]-bounds(b)[0]);click(header.at(-1));tap('重新开始',wait(a=>find(a,'重新开始')));wait(a=>suite.grid(a).length===81&&!a.some(n=>n.type==='MenuItem'));assert.deepEqual(suite.grid().map(b=>suite.nums(b)[0]||0),initial);shot('same-difficulty-restart');}
  const result=suite.run(id); evidence.push(...result.evidence);shot('finished');back();
  record(label(id)+(id==='slidepuzzle'?'·简单（完整通关）':name?'·'+name:''),id==='slidepuzzle'?'slidepuzzle-easy-win':caseId,[...extraCases,...result.cases,'返回分类列表及退出确认'],evidence);
}
function match3() {
  caseId='match3-final';evidence=[];const resume=process.argv.includes('--resume');if(!resume){back();open(label('match3'));}else assert(text(layout()).includes(label('match3')));const suite=reuse('device-standalone-continuous.cjs',caseId);assert.equal(layout().filter(n=>n.type==='Button'&&bounds(n)[1]<300).length,2,'Fixed-rule game should only show back/restart');if(!resume)suite.headerRestart();shot(resume?'resume-after-pixel-calibration':'ready');
  const stats=ns=>ns.filter(n=>n.type==='Text'&&/^\d+$/.test(n.text)&&bounds(n)[1]>300&&bounds(n)[1]<550).map(n=>Number(n.text));
  const hasMatch=a=>a.some((v,i)=>(i%8<6&&v===a[i+1]&&v===a[i+2])||(i<48&&v===a[i+8]&&v===a[i+16]));
  let ns=layout(),status=stats(ns),steps=resume?30-status[2]:0,invalid=resume;const initial=30;
  while(status[2]>0){const bs=suite.grid(ns);assert.equal(bs.length,64);const colors=c.pixels(prefix+'-'+caseId+'-board-'+steps,bs,'gems'),legal=[],other=[];
    for(let i=0;i<64;i++)for(const j of [i%8<7?i+1:-1,i<56?i+8:-1])if(j>=0){const a=colors.slice();[a[i],a[j]]=[a[j],a[i]];(colors[i]!==colors[j]&&hasMatch(a)?legal:other).push([i,j]);}
    if(!invalid){const p=other[0];click(bs[p[0]]);sleep(350);click(bs[p[1]]);sleep(350);assert.deepEqual(stats(layout()),status);invalid=true;shot('invalid-swap');}
    let advanced=false;for(const [i,j]of [...legal,...other]){const current=suite.grid();const selected=current.find(b=>b.raw.children.length===3);if(selected)click(selected);click(current[i]);sleep(350);click(current[j]);sleep(450);ns=layout();const next=stats(ns);if(next[2]<status[2]){assert.equal(next[2],status[2]-1);assert(next[0]>status[0]);status=next;advanced=true;break;}}
    assert(advanced,'No swap advances the rendered game');steps++;if(steps%5===0)console.log('MATCH3 '+steps+'/'+initial+' score='+status[0]);}
  assert(find(ns,'再来一局'));shot('result');tap('再来一局',ns);assert.deepEqual([stats(layout())[0],stats(layout())[2]],[0,initial]);shot('restart');back();
  record(label('match3'),'match3',['固定规则游戏的标题只显示返回和重开','无三连交换还原且不扣步数','根据实际宝石画面完成 '+steps+' 次有效交换，结算 '+status[0]+' 分','剩余步数归零结束','重开恢复得分 0、步数 '+initial,'返回分类及退出确认'],evidence);
}
function sudokuSolutions(initial) {
  assert.equal(initial.length,81);const a=initial.slice();let count=0;
  for(let i=0;i<81;i++)if(a[i]){assert(a[i]>=1&&a[i]<=9);for(let j=0;j<i;j++)if(a[i]===a[j])assert(Math.floor(i/9)!==Math.floor(j/9)&&i%9!==j%9&&(Math.floor(i/27)!==Math.floor(j/27)||Math.floor(i%9/3)!==Math.floor(j%9/3)),'Conflicting Sudoku clues');}
  const search=()=>{let at=-1,opts=[];for(let i=0;i<81;i++)if(!a[i]){const row=Math.floor(i/9),col=i%9,used=new Set();for(let j=0;j<9;j++){used.add(a[row*9+j]);used.add(a[j*9+col]);used.add(a[(Math.floor(row/3)*3+Math.floor(j/3))*9+Math.floor(col/3)*3+j%3]);}const next=[1,2,3,4,5,6,7,8,9].filter(v=>!used.has(v));if(!next.length)return;if(at<0||next.length<opts.length){at=i;opts=next;}}
    if(at<0){count++;return;}for(const v of opts){a[at]=v;search();a[at]=0;if(count>=2)return;}};
  search();return count;
}
function mines(name,total) {
  caseId='mines-'+total;evidence=[];back();open(label('minesweeper'));difficulty(name);
  const suite=reuse('device-standalone-continuous.cjs',caseId),bs=suite.grid(layout(),'Column');assert.equal(bs.length,81);assert(text(layout()).includes('0/'+total));shot('board');
  const z=bounds(bs[0]),long=()=>c.shell('uitest','uiInput','longClick',''+Math.round((z[0]+z[2])/2),''+Math.round((z[1]+z[3])/2));
  long();assert(text(layout()).includes('1/'+total));click(bs[0]);assert(!find(layout(),'再来一局'));long();click(bs[40]);assert(!find(layout(),'再来一局'));const first=shot('safe-first');
  const revealedFirst=suite.grid(first,'Column');assert.equal(suite.nums(revealedFirst[40]).length,0);for(let r=3;r<=5;r++)for(let col=3;col<=5;col++){const b=revealedFirst[r*9+col];assert.equal(b.backgroundColor,revealedFirst[40].backgroundColor);assert(!descendants(b).some(d=>d.type==='Image'));}
  let current=layout();for(let i=0;i<81&&!find(current,'再来一局');i++){click(bs[i]);current=layout();}
  assert(find(current,'再来一局'));const revealed=suite.grid(current,'Column');const bombs=revealed.map((b,i)=>descendants(b).some(d=>d.type==='Image')?i:-1).filter(i=>i>=0);assert(bombs.length>=1&&bombs.length<=total,'Hit mine not shown');
  for(const b of bombs)assert(Math.abs(Math.floor(b/9)-4)>1||Math.abs(b%9-4)>1,'Mine in first-click safety zone');
  shot('result');tap('再来一局',current);assert(text(layout()).includes('0/'+total));shot('restart');back();
  record(label('minesweeper')+'·'+name,caseId,['插旗、取消与旗格不能揭开','首点及周围 3×3 安全揭开，中心为空白','界面雷数标记 '+total+'，三档设置正确','踩雷后立即结算并显示踩中的雷','重新开始旗数及时间清零'],evidence,{displayedMineCount:total,visibleHitMines:bombs});
}
function realtime(id,name) {
  caseId=id+(name?'-'+name:'');evidence=[];back();open(label(id));if(name)difficulty(name);let ns=layout();
  const headers=ns.filter(n=>n.type==='Button'&&bounds(n)[1]<300).sort((a,b)=>bounds(a)[0]-bounds(b)[0]);const pause=headers.at(-2);
  if(id==='brickbreaker')assert.equal(headers.length,3,'Automatic-level game should only show back/pause/restart');
  const sig=ns=>JSON.stringify({text:text(ns),images:ns.filter(n=>n.type==='Image'&&bounds(n)[1]>550&&bounds(n)[3]<2350).map(n=>n.bounds)});
  if(id==='whackmole'){
    const seconds={'简单':40,'普通':30,'困难':20}[name];let hit=false,observed=[];const deadline=Date.now()+14000;
    while(Date.now()<deadline&&!hit){ns=layout();assert(!find(ns,'再来一局'));const holes=ns.filter(n=>n.type==='Stack'&&n.clickable==='true'&&bounds(n)[1]>500&&descendants(n).filter(d=>d.type==='Image').length===2);assert(holes.length<=2);observed.push(holes.length);if(holes.length)click(holes[0]);hit=text(layout()).some(t=>/^\d+$/.test(t)&&Number(t)>0);}
    assert(hit,'No mole hit observed');shot('hit');click(pause);const paused=shot('paused');sleep(2000);assert.equal(sig(layout()),sig(paused));click(pause);wait(a=>find(a,'再来一局'),seconds*1000+5000);shot('time-up');tap('再来一局');back();
    record(label(id)+'·'+name,caseId,['观察生成地鼠数量为 1–2，只点击实际出洞位置','击中后加分','暂停冻结倒计时和洞位','倒计时结束结算及重新开始'],evidence,{spawnCounts:observed});return;
  }
  const controls=ns.filter(n=>n.type==='Button'&&bounds(n)[1]>1900).sort((a,b)=>bounds(a)[1]-bounds(b)[1]||bounds(a)[0]-bounds(b)[0]);
  assert(controls.length);shot('ready');click(controls[id==='tetris'?controls.length-1:0]);sleep(id==='snake'?100:500);click(pause);const paused=shot('paused');
  const saved=sig(paused);sleep(1000);assert.equal(sig(layout()),saved);c.shell('uitest','uiInput','keyEvent','Home');sleep(2000);c.shell('aa','start','-b','com.littlegames.collection','-a','EntryAbility');sleep(250);assert.equal(sig(layout()),saved);shot('background-resumed');
  click(pause);sleep(id==='snake'?200:600);click(pause);assert.notEqual(sig(layout()),saved,'Game did not resume advancing');shot('advanced');click(headers.at(-1));shot('restart');back();
  record(label(id)+(name?'·'+name:''),caseId,['实际方向/落块/发球操作','暂停后画面保持','切后台 2 秒返回保持暂停棋盘','继续游戏后画面推进','重新开始与返回'],evidence);
}
function jump(name) {
  caseId='jump-'+name;evidence=[];back();open(label('jumpjump'));difficulty(name);let ns=shot('ready');const area=ns.find(n=>n.id==='jumpjump_area');assert(area);const z=bounds(area);
  for(let i=0;i<3;i++){c.shell('uitest','uiInput','longClick',''+Math.round((z[0]+z[2])/2),''+Math.round((z[1]+z[3])/2));sleep(800);ns=layout();assert(!find(ns,'再来一局'));assert.equal(Number(ns.find(n=>n.id==='jumpjump_score').text),i+1);}
  shot('three-landings');back();record(label('jumpjump')+'·'+name,caseId,['真实长按蓄满后落到下一平台','连续 3 次成功跳跃、加分到 3','返回确认'],evidence);
}
function slide(name,n) {
  caseId='slide-'+n;evidence=[];back();open(label('slidepuzzle'));difficulty(name);
  const suite=reuse('device-standalone-continuous.cjs',caseId),bs=suite.grid(),a=bs.map(b=>suite.nums(b)[0]||0); assert.equal(a.length,n*n);
  assert.deepEqual(a.slice().sort((a,b)=>a-b),Array.from({length:n*n},(_,i)=>i));let inversions=0;for(let i=0;i<a.length;i++)for(let j=i+1;j<a.length;j++)if(a[i]&&a[j]&&a[i]>a[j])inversions++;
  const z=a.indexOf(0);assert(n%2?inversions%2===0:(inversions+n-Math.floor(z/n))%2===1,'Displayed puzzle parity unsolvable');shot('board');
  const next=neighbors(z,n)[0];click(bs[next]);const updated=suite.grid().map(b=>suite.nums(b)[0]||0);const expected=a.slice();expected[z]=a[next];expected[next]=0;assert.deepEqual(updated,expected);shot('move');suite.headerRestart();shot('restart');back();
  record(label('slidepuzzle')+'·'+name,caseId,['棋盘 '+n+'×'+n+'，数字与空格恰好各出现一次','独立逆序数校验确认可还原','相邻方块移动及空格交换正确','重新生成'],evidence,{inversions,blankRowFromBottom:n-Math.floor(z/n)});
}
const collectionIds=['tictactoe','gomoku','fourline','reversi','nim','hanoi','schulte','memorysequence','arithmetic','compare','sequence','binary','targetsum','missing','reaction','lights','flood','peg','nonogram'];
const errors=[];
function checked(id,action){console.log('START '+id);try{action();console.log('PASS '+id);}catch(e){errors.push({id,error:e.stack});console.error('FAIL '+id+' '+e.stack);try{shot('failure');back();}catch(x){console.error('RECOVERY '+x.message);throw e;}c.log('audit-failure',{id,error:e.message});}}
const mode=process.argv[2];
if(mode==='maze')for(const [name,n]of [['简单',7],['普通',9],['困难',11]])checked('maze-'+n,()=>maze(name,n));
else if(mode==='collection')for(const id of (process.argv.slice(3).length?process.argv.slice(3):collectionIds))checked(id,()=>legacy(id,['tictactoe','gomoku','fourline','reversi','reaction'].includes(id)?null:'普通','collection'));
else if(mode==='standalone')for(const id of process.argv.slice(3).filter(s=>!s.startsWith('--')))checked(id,()=>legacy(id,['match3','2048'].includes(id)?null:'普通','standalone'));
else if(mode==='variants')for(const id of process.argv.slice(3))for(const [name,n]of [['简单',3],['普通',4],['困难',5]])checked(id+'-'+name,()=>id==='slidepuzzle'?slide(name,n):id==='minesweeper'?mines(name,{'简单':8,'普通':10,'困难':14}[name]):legacy(id,name,['peg','flood','lights','arithmetic','sequence','binary','targetsum'].includes(id)?'collection':'standalone'));
else if(mode==='realtime')for(const id of process.argv.slice(3))for(const name of(id==='brickbreaker'?[null]:['简单','普通','困难']))checked(id+'-'+name,()=>id==='jumpjump'?jump(name):realtime(id,name));
else if(mode==='finish'){
  back();if(!find(layout(),'我的')){c.shell('uitest','uiInput','keyEvent','Back');wait(a=>find(a,'我的'));}tap('我的');caseId='profile';evidence=[];const ns=shot('stats');
  const p=JSON.parse(fs.readFileSync(checkpoint,'utf8'));p.uiChecks=[{checkedOn:p.checkedOn,packageHash:p.packageHash,name:'我的页面测试后的实际统计',evidence:evidence.slice(),text:text(ns)}];fs.writeFileSync(checkpoint,JSON.stringify(p,null,2)+'\n');
  tap('精选');caseId='finish';shot('home');console.log('FINISHED: returned to home');
}
else throw Error('Specify maze, collection, standalone, variants, realtime or finish');
if(errors.length){fs.writeFileSync(path.resolve('docs/device-acceptance',prefix+'-'+mode+'-errors.json'),JSON.stringify(errors,null,2));process.exitCode=1;}
