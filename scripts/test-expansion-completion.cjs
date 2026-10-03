const assert = require('node:assert/strict');
const fs = require('node:fs');
const {fixture} = require('./test-performance.cjs');
const f=fixture(), {ExpansionModel,PLAYABLE_EXPANSION_IDS}=f.rules('Expansion');
const {PokerPattern}=f.load('entry/src/main/ets/model/game/ExpansionPoker.ets');
const {ExpansionPiece}=f.load('entry/src/main/ets/model/game/ExpansionState.ets');
const finalIds=require('./expansion-completion-catalog.cjs').games.map(g=>g[0]);
const cases=[], test=(name,run)=>cases.push({name,run});
const create=(id,level=1,seed=19)=>{const m=new ExpansionModel(f.rng(seed));m.start(id,level);return m;};
const copy=m=>JSON.stringify(m.state);
const run=(m,seconds,control=()=>{})=>{for(let i=0;i<seconds/0.008&&!m.state.outcome&&m.state.phase;i++){control(m,i);m.step(.008);if(i%32===0)assert(m.valid(m.state),`${m.state.id} frame ${i}`);}assert(m.valid(m.state),m.state.id);};
const wait=(m,limit=20)=>run(m,limit);
const card=(rank,suit=0,deck=0)=>rank>=16?52+rank-16+deck*54:(rank===14?0:rank-1)+suit*13+deck*54;
const cards=ranks=>ranks.map((r,i)=>card(r,i%4));
const tiles=types=>{const counts=new Array(34).fill(0);return types.map(t=>t*4+counts[t]++);};

test('the catalog contains exactly 100 unique implemented games with complete themed resources',()=>{
  assert.equal(finalIds.length,39);assert.equal(PLAYABLE_EXPANSION_IDS.length,67);const games=f.data().getAllGames();assert.equal(games.length,100);assert.equal(new Set(games.map(g=>g.id)).size,100);
  for(const locale of ['base','zh_CN','en_US']){
    const entries=JSON.parse(fs.readFileSync(`entry/src/main/resources/${locale}/element/string.json`)).string;assert.equal(new Set(entries.map(e=>e.name)).size,entries.length);
    for(const id of PLAYABLE_EXPANSION_IDS)for(const suffix of ['name','desc','rules'])assert(entries.find(e=>e.name===`game_${id}_${suffix}`)?.value.length>0,`${locale}/${id}/${suffix}`);
  }
  for(const theme of ['base','dark'])for(const id of PLAYABLE_EXPANSION_IDS)assert(fs.readFileSync(`entry/src/main/resources/${theme}/media/game_${id}.svg`,'utf8').includes('<svg'),`${theme}/${id}`);
  for(const theme of ['base','dark']){const icons=finalIds.map(id=>fs.readFileSync(`entry/src/main/resources/${theme}/media/game_${id}.svg`,'utf8'));assert.equal(new Set(icons).size,39);assert(icons.every(svg=>!svg.includes('<text')));}
});
for(const id of finalIds)for(const level of [0,1,2])test(`${id}/${level}: real input, runtime bounds and mid-game continuation`,()=>{
  const m=create(id,level);m.activate();
  if(id==='linerescue'){m.aim(130,180);m.aim(230,180);m.activate();}
  else if(['billiards','golf','bowling','penalty'].includes(id))m.aim(180,80);
  else if(id==='platformer'){m.tap(1);m.tap(2);}
  else if(id==='grapple')m.tap(0);
  else if(['shooter','tanks','survival','rollingball'].includes(id))m.aim(220,330);
  else if(id==='hillclimb')m.tap(0);
  else if(id==='doudizhu'||id==='guandan'){m.tap(902);m.tap(900);}
  else if(id==='mahjong'){const tile=m.state.piles[0].cards[0];m.tap(tile);m.tap(tile);}
  else if(id==='ludo')m.tap(900);
  else if(id==='spider')m.tap(900);
  else if(id==='freecell'){const top=m.state.piles[0].cards.at(-1);m.tap(top);m.tap(208);}
  else if(id==='xiangqi'){m.tap(54);m.tap(45);}
  else if(id==='chess'){m.tap(52);m.tap(36);}
  else if(id==='farm'){m.tap(0);m.choose(1);m.tap(0);m.tap(900);}
  else if(id==='decorate'){m.choose(2);m.tap(0);}
  else if(id==='picturepuzzle'){m.tap(0);m.tap(1);}
  else if(id==='idiom')m.tap(m.state.board.indexOf(m.state.target[m.state.data[1]]));
  else m.tap(0);
  if(m.realtime())run(m,4);
  assert(m.valid(m.state),id);const receiver=create(id,level,35);receiver.restore(JSON.parse(copy(m)));assert(receiver.valid(receiver.state));assert.equal(copy(receiver),copy(m));
  const vm=f.vm('ExpansionViewModel');vm.init(id);assert(vm.importContinuation(JSON.stringify({version:1,state:m.state,recorded:false,paused:false})),id);
  const before=vm.exportContinuation();const bad=JSON.parse(before);bad.state.data.push(999999);assert.equal(vm.importContinuation(JSON.stringify(bad)),false,id);assert.equal(vm.exportContinuation(),before);vm.dispose();
});
test('platform gaps require jumping and legal controls complete every difficulty',()=>{
  const walking=create('platformer');walking.activate();walking.tap(1);run(walking,10);assert.equal(walking.state.outcome,2);
  for(const level of [0,1,2]){const m=create('platformer',level);m.activate();m.tap(1);run(m,20,(m)=>{const p=m.state.pieces[0];const platform=m.state.pieces.find(q=>q.kind===25&&p.x>=q.x-10&&p.x<=q.x+q.w+10&&Math.abs(p.y+p.r-q.y)<2);if(platform&&p.vy===0&&p.x>=platform.x+platform.w-30)m.tap(2);});assert.equal(m.state.outcome,1,`platformer/${level}`);}
});
test('grapple attaches to anchors, constrains rope length and can finish by chaining hooks',()=>{
  for(const level of [0,1,2]){const m=create('grapple',level);m.activate();m.tap(0);assert(m.state.selected>=0);run(m,25,(m)=>{const p=m.state.pieces[0];if(m.state.selected>=0){const a=m.state.pieces.find(q=>q.id===m.state.selected);assert(Math.hypot(p.x-a.x,p.y-a.y)<=p.age+2);if(p.x>a.x+35){m.tap(1);m.tap(0);}}else m.tap(0);});assert.equal(m.state.outcome,1,`grapple/${level}`);}
});
test('flappy gate collision and passing the last gate give different outcomes',()=>{
  const lose=create('flappy');lose.activate();lose.state.pieces[0].y=2;lose.step(.008);assert.equal(lose.state.outcome,2);
  const win=create('flappy');win.activate();win.state.cursor=win.state.goal-1;const g=win.state.pieces[1];g.x=35;g.age=0;win.state.pieces[0].y=230;win.step(.008);assert.equal(win.state.outcome,1);assert.equal(win.state.score,100);
});
test('fruit slicing follows a segment, awards fruit, fails on bombs and forgets a released stroke',()=>{
  const m=create('fruitslice');m.activate();const fruit=new ExpansionPiece();fruit.id=m.state.serial++;fruit.kind=30;fruit.x=180;fruit.y=230;fruit.r=20;m.state.pieces=[fruit];m.aim(100,230);m.aim(250,230);assert.equal(m.state.score,50);assert.equal(m.state.moves,1);m.releaseControls();assert.equal(m.state.target.length,0);
  fruit.alive=true;fruit.kind=31;m.aim(180,230);assert.equal(m.state.outcome,2);
});
test('rolling ball has wall response, hole loss and a reachable goal',()=>{
  const m=create('rollingball');m.activate();m.state.pieces[0].x=100;m.state.pieces[0].y=110;m.state.pieces[0].vy=100;m.step(.008);assert(m.state.pieces[0].vy<0);
  const hole=m.state.pieces.find(p=>p.kind===31);m.state.pieces[0].x=hole.x;m.state.pieces[0].y=hole.y;m.step(.008);assert.equal(m.state.outcome,2);
  const win=create('rollingball');win.activate();const p=win.state.pieces[0];p.x=320;p.y=46;win.step(.008);assert.equal(win.state.outcome,1);
});
test('combat bullets damage enemies, enemies damage the defense, and upgrade spends earned coins',()=>{
  for(const id of ['shooter','tanks','fortress','survival']){
    const m=create(id);m.activate();m.state.cursor=m.state.goal-1;const enemy=new ExpansionPiece();enemy.id=m.state.serial++;enemy.kind=33;enemy.x=180;enemy.y=100;enemy.r=15;enemy.w=1;enemy.age=2;
    const bullet=new ExpansionPiece();bullet.id=m.state.serial++;bullet.kind=34;bullet.x=180;bullet.y=100;bullet.r=5;bullet.owner=0;m.state.pieces.push(enemy,bullet);m.step(.008);assert(!m.state.pieces.some(p=>p.id===enemy.id));assert(m.state.score>=100);
    const hp=m.state.data[0];const contact=new ExpansionPiece();contact.id=m.state.serial++;contact.kind=33;contact.x=m.state.pieces[0].x;contact.y=m.state.pieces[0].y;contact.r=15;contact.w=1;contact.age=2;m.state.pieces.push(contact);m.step(.008);assert(m.state.data[0]<hp);
  }
  const castle=create('fortress');castle.activate();castle.state.data[1]=20;castle.tap(0);assert.equal(castle.state.next,2);assert.equal(castle.state.data[1],0);
});
test('backpack placement respects footprint and budget, and a balanced shop strategy wins five rounds',()=>{
  const m=create('backpack');m.choose(0);m.tap(3);assert.equal(m.state.data[0],12);m.tap(0);assert.deepEqual(m.state.board.slice(0,2),[1,1]);const once=copy(m);m.tap(0);assert.equal(copy(m),once);m.undo();assert.equal(m.state.data[0],12);
  for(const item of [[0,0],[1,3],[2,8],[3,2]]){m.choose(item[0]);m.tap(item[1]);}assert.equal(m.state.data[0],0);m.tap(100);assert.equal(m.state.cursor,1);
  for(const item of [[0,4],[1,6]]){m.choose(item[0]);m.tap(item[1]);}assert.equal(m.state.data[0],0);m.tap(100);assert.equal(m.state.cursor,2);
  for(const item of [[0,14],[3,11]]){m.choose(item[0]);m.tap(item[1]);}assert.equal(m.state.board.filter(v=>v!==0).length,16);for(let i=0;i<3;i++)m.tap(100);assert.equal(m.state.outcome,1);assert(m.valid(m.state));
});
test('billiards transfers momentum and pockets colored balls but scratches the cue',()=>{
  const m=create('billiards');const a=m.state.pieces[0],b=m.state.pieces[1];a.x=90;a.y=200;b.x=114;b.y=200;a.vx=200;m.state.phase=1;m.step(.008);assert(b.vx>0);
  b.x=25;b.y=25;b.vx=0;b.vy=0;m.step(.008);assert.equal(m.state.cursor,1);a.x=25;a.y=25;m.state.phase=1;m.step(.008);assert.equal(m.state.errors,1);assert.equal(a.x,100);
});
test('penalty scoring requires crossing clear of the keeper and ends at the shot limit',()=>{
  const m=create('penalty');m.activate();m.state.pieces[0].x=40;m.state.pieces[0].y=94;m.state.pieces[0].vy=-200;m.state.data[0]=1;m.step(.008);assert.equal(m.state.data[1],1);
  const b=m.state.pieces[0],k=m.state.pieces[1];b.x=k.x;b.y=94;b.vy=-200;m.state.data[0]=8;m.step(.008);assert.equal(m.state.outcome,2);
});
test('paddle and hockey goals update the correct side and stop at the winning score',()=>{
  for(const id of ['pingpong','airhockey']){const m=create(id);m.activate();m.state.data[0]=m.state.goal-1;const b=m.state.pieces[0];b.x=180;b.y=-2;b.vy=-200;m.step(.008);assert.equal(m.state.outcome,1);assert.equal(m.state.data[0],m.state.goal);}
});
test('bowling contacts knock adjacent pins and three rolls end the frame',()=>{
  const m=create('bowling');m.aim(180,30);m.state.pieces[0].x=180;m.state.pieces[0].y=130;m.step(.008);assert(m.state.cursor>=2);m.state.data[0]=3;m.state.pieces[0].y=-30;m.step(.008);assert.equal(m.state.outcome,2);
});
test('golf cup needs a slow approach; stationary ball accepts another stroke',()=>{
  const m=create('golf');m.aim(320,410);wait(m);assert.equal(m.state.phase,0);const b=m.state.pieces[0];b.x=310;b.y=55;b.vx=200;b.vy=0;m.state.phase=1;m.step(.008);assert.equal(m.state.outcome,0);b.x=310;b.y=55;b.vx=20;m.step(.008);assert.equal(m.state.outcome,1);
});
test('drift and hill climb can finish all difficulties through their actual controls',()=>{
  for(const level of [0,1,2]){
    const drift=create('drift',level);drift.activate();run(drift,55,m=>{const p=m.state.pieces[0],c=180+Math.sin(m.state.time*.65)*90;if((p.x>c+8&&p.vx>0)||(p.x<c-8&&p.vx<0))m.tap(0);});assert.equal(drift.state.outcome,1);
    const hill=create('hillclimb',level);hill.activate();hill.tap(0);run(hill,40);assert.equal(hill.state.outcome,1);hill.releaseControls();assert.equal(hill.state.selected,-1);
  }
});
test('tug is symmetric and dots gives another turn only when a box closes',()=>{
  const tug=create('tug');tug.tap(0);tug.tap(1);assert.equal(tug.state.data[0],50);for(let i=0;i<30&&!tug.state.outcome;i++)tug.tap(1);assert.equal(tug.state.cursor,1);assert.equal(tug.state.outcome,1);
  const m=create('dots',0),n=m.state.cols,v=n*(n+1);m.tap(0);m.tap(n);m.tap(v);const player=m.state.cursor;m.tap(v+1);assert.equal(m.state.data[0],player+1);assert.equal(m.state.cursor,player);for(let i=0;i<m.state.board.length;i++)m.tap(i);assert.equal(m.state.outcome,1);
});
test('poker patterns enforce length, attachment, bomb hierarchy, level twos and heart wildcards',()=>{
  const m=create('doudizhu'),p=m.poker;
  assert.equal(p.pattern(cards([3,4,5,6,7]),false).kind,6);assert.equal(p.pattern(cards([2,3,4,5,6]),false).kind,0);
  assert.equal(p.pattern(cards([3,3,3,4,4,4,5,6]),false).kind,9);assert.equal(p.pattern(cards([3,3,3,4,4,4,5,5,6,6]),false).kind,10);
  assert.equal(p.pattern(cards([3,3,3,3,4,4,4,4]),false).kind,0);
  assert(p.beats(p.pattern([52,53],false),p.pattern(cards([14,14,14,14]),false)));
  const wild=card(2,1);assert.equal(p.pattern([wild],true).strength,15);assert.equal(p.pattern([wild,card(5,0),card(5,2)],true).kind,3);
  assert.equal(p.pattern(cards([14,2,3,4,5]),true).kind,6);assert.equal(p.pattern(cards([14,14,2,2,3,3]),true).kind,7);
  const sf=p.pattern([10,11,12,13,14].map(r=>card(r,2)),true);assert.equal(sf.kind,15);assert(p.beats(sf,new PokerPattern(13,14,5,50)));assert(!p.beats(sf,new PokerPattern(13,3,6,60)));
  assert.equal(p.pattern([52,53,106,107],true).bomb,1000);
});
for(const id of ['doudizhu','guandan'])test(`${id}: legal hint-driven rounds terminate with conserved decks and valid bot responses`,()=>{
  for(const seed of [1,12,30])for(const level of [0,1,2]){const m=create(id,level,seed);let turns=0;while(!m.state.outcome&&turns++<300){m.tap(902);if(m.state.tray.length)m.tap(900);else m.tap(901);assert(m.valid(m.state));}assert(m.state.outcome!==0,`${id}/${seed}`);}
});
test('chess castling, transit attacks, en passant and each promotion obey king safety',()=>{
  const m=create('chess');m.state.board.fill(0);m.state.board[60]=1;m.state.board[4]=11;m.state.board[56]=m.state.board[63]=3;assert(m.chess.legal(m.state,60,62));m.state.board[5]=13;assert(!m.chess.legal(m.state,60,62));m.state.board[5]=0;m.tap(60);m.tap(62);assert.equal(m.state.board[62],1);assert.equal(m.state.board[61],3);assert.equal(m.state.data[0],1);
  const ep=create('chess');ep.state.board.fill(0);ep.state.board[60]=1;ep.state.board[4]=11;ep.state.board[28]=6;ep.state.board[27]=16;ep.state.data[6]=20;ep.tap(28);ep.tap(19);assert.equal(ep.state.board[27],0);assert.equal(ep.state.board[19],6);assert(ep.valid(ep.state));
  for(let choice=0;choice<4;choice++){const promo=create('chess');promo.state.board.fill(0);promo.state.board[60]=1;promo.state.board[7]=11;promo.state.board[8]=6;promo.choose(choice);promo.tap(8);promo.tap(0);assert.equal(promo.state.board[0],choice+2);}
  const pin=create('chess');pin.state.board.fill(0);pin.state.board[60]=1;pin.state.board[4]=11;pin.state.board[12]=13;pin.state.board[52]=3;assert(!pin.chess.legal(pin.state,52,51));assert(pin.chess.legal(pin.state,52,44));
});
test('chess distinguishes checkmate from stalemate and xiangqi applies blocking and facing restrictions',()=>{
  const m=create('chess');m.state.board.fill(0);m.state.board[63]=1;m.state.board[45]=11;m.state.board[54]=12;assert(m.chess.checked(m.state,1));assert.equal(m.chess.moves(m.state,1).length,0);
  m.state.board[54]=0;m.state.board[46]=12;assert(!m.chess.checked(m.state,1));assert.equal(m.chess.moves(m.state,1).length,0);
  const x=create('xiangqi');x.state.board.fill(0);x.state.board[85]=1;x.state.board[4]=11;x.state.board[49]=5;assert(!x.chess.legal(x.state,49,48));assert(x.chess.legal(x.state,49,40));
  x.state.board[82]=4;x.state.board[73]=7;assert(!x.chess.legal(x.state,82,65));x.state.board[83]=3;assert(!x.chess.legal(x.state,83,63));
  x.state.board[64]=6;x.state.board[10]=15;x.state.board[37]=7;assert(x.chess.legal(x.state,64,10));x.state.board[37]=0;assert(!x.chess.legal(x.state,64,10));
});
test('mahjong recognizes four melds and a pair, seven pairs, exposed melds and invalid hands',()=>{
  const m=create('mahjong');assert(m.cards.mahjongWin(tiles([0,1,2,3,4,5,9,10,11,27,27,27,33,33])));assert(m.cards.mahjongWin(tiles([0,0,1,1,2,2,3,3,4,4,5,5,6,6])));assert(m.cards.mahjongWin(tiles([3,4,5,9,10,11,27,27,27,33,33]),1));assert(!m.cards.mahjongWin(tiles([0,1,2,3,4,5,9,10,11,27,27,28,33,33])));
  for(const seed of [1,12,30]){const game=create('mahjong',1,seed);let turn=0;while(!game.state.outcome&&turn++<150){if(game.cards.mahjongCan(game.state,900))game.tap(900);else if(game.state.data[0]===1){if(game.cards.mahjongCan(game.state,901))game.tap(901);else game.tap(907);}else {const tile=game.state.piles[0].cards[0];game.tap(tile);game.tap(tile);}assert(game.valid(game.state));}assert(game.state.outcome!==0);}
});
test('ludo launch, repeated six, capture and exact finish operate in complete four-player races',()=>{
  const m=create('ludo');m.state.data[0]=1;m.tap(0);assert.equal(m.state.pieces[0].x,-1);m.state.data[0]=6;m.tap(0);assert.equal(m.state.pieces[0].x,0);assert.equal(m.state.next,1);
  m.state.pieces[0].x=2;m.state.pieces[4].x=51;m.state.data[0]=6;m.tap(0);assert.equal(m.state.pieces[0].x,12);assert.equal(m.state.pieces[4].x,-1);
  for(const seed of [1,12,30]){const game=create('ludo',1,seed);let turns=0;while(!game.state.outcome&&turns++<1500){if(game.state.data[0]===0)game.tap(900);else {const token=game.state.pieces.filter(p=>p.owner===0&&p.x<57&&(p.x>=0||game.state.data[0]===6)).sort((a,b)=>b.x-a.x)[0];assert(token);game.tap(token.id);}assert(game.valid(game.state));}assert(game.state.outcome!==0);}
});
test('spider completes all eight runs and rejects stock deals with an empty column',()=>{
  const m=create('spider');for(const pile of m.state.piles)pile.cards=[];m.state.pieces.forEach(p=>p.w=1);for(let group=0;group<8;group++)m.state.piles[group].cards=Array.from({length:13},(_,i)=>group*13+12-i);m.state.piles[0].cards.pop();m.state.piles[8].cards=[0];m.tap(0);m.tap(200);assert.equal(m.state.outcome,1);assert.equal(m.state.data[0],8);assert(m.valid(m.state));
  const blocked=create('spider');blocked.state.piles[1].cards.push(...blocked.state.piles[0].cards);blocked.state.piles[0].cards=[];const before=copy(blocked);blocked.tap(900);assert.equal(copy(blocked),before);
});
test('freecell capacity depends on vacant cells and foundations complete all four suits',()=>{
  const m=create('freecell');for(const pile of m.state.piles)pile.cards=[];const moving=[24,10,22],used=[...moving,12];m.state.piles[0].cards=moving;m.state.piles[1].cards=[12];let next=0;for(let pile=2;pile<12;pile++){while(used.includes(next))next++;m.state.piles[pile].cards=[next];used.push(next++);}m.state.piles[0].cards.unshift(...Array.from({length:52},(_,i)=>i).filter(i=>!used.includes(i)));
  m.tap(24);m.tap(201);assert.equal(m.state.piles[1].cards.length,1);for(let pile=8;pile<12;pile++){m.state.piles[2].cards.push(...m.state.piles[pile].cards);m.state.piles[pile].cards=[];}m.tap(201);assert.equal(m.state.piles[1].cards.length,4);assert(m.valid(m.state));
  const win=create('freecell');for(const pile of win.state.piles)pile.cards=[];for(let suit=0;suit<4;suit++){win.state.piles[12+suit].cards=Array.from({length:12},(_,r)=>suit*13+r);win.state.piles[suit].cards=[suit*13+12];}for(let suit=0;suit<4;suit++){win.tap(suit*13+12);win.tap(900);}assert.equal(win.state.outcome,1);assert(win.valid(win.state));
});
for(const id of ['onestroke','picturepuzzle','idiom'])for(const level of [0,1,2])test(`${id}/${level}: 100 seeded complete solutions`,()=>{
  for(let seed=1;seed<=100;seed++){const m=create(id,level,seed);if(id==='onestroke'){for(const node of [...m.state.target])m.tap(node);}else if(id==='picturepuzzle'){for(let i=0;i<m.state.board.length&&!m.state.outcome;i++){if(m.state.board[i]!==i){m.tap(i);m.tap(m.state.board.indexOf(i));}}}else {while(!m.state.outcome)m.tap(m.state.board.indexOf(m.state.target[m.state.data[1]]));}assert.equal(m.state.outcome,1);assert(m.valid(m.state));}
});
test('hidden objects accept one instance per target, ignore repeats and reject wrong types',()=>{
  const m=create('hiddenobjects');for(const v of m.state.target)m.tap(m.state.board.indexOf(v));assert.equal(m.state.outcome,1);const fail=create('hiddenobjects');const v=fail.state.target[0],at=fail.state.board.indexOf(v);fail.tap(at);const once=copy(fail);fail.tap(at);assert.equal(copy(fail),once);fail.tap(fail.state.board.findIndex(v=>!fail.state.target.includes(v)));assert.equal(fail.state.errors,1);
});
test('drawn barriers protect the dog, while an open arena loses',()=>{
  const m=create('linerescue');for(let i=0;i<=12;i++){const a=i*Math.PI*2/12;m.aim(180+Math.cos(a)*65,250+Math.sin(a)*65);}m.activate();run(m,12);assert.equal(m.state.outcome,1);
  const open=create('linerescue');open.aim(0,0);open.aim(50,0);open.activate();run(open,10);assert.equal(open.state.outcome,2);
});
test('word towers merge three identical characters and purchasing defense can clear hard waves',()=>{
  const m=create('wordtower',2);m.tap(0);m.tap(1);m.tap(2);assert.deepEqual(m.state.board.slice(0,3),[5,0,0]);assert.equal(m.state.pieces.filter(p=>p.kind===57).length,1);m.choose(1);m.tap(1);m.tap(2);m.tap(3);m.tap(1);m.tap(2);m.tap(3);m.activate();run(m,90,(m)=>{if(m.state.data[0]>=6){const slot=m.state.board.indexOf(0);if(slot>=0)m.tap(slot);}});assert.equal(m.state.outcome,1);
});
test('beat jump and audible melody finish through correctly timed input, and wrong notes fail',()=>{
  for(const id of ['beatjump','melody']){const m=create(id,2);m.activate();let guard=0;while(!m.state.outcome&&guard++<30000){if(id==='beatjump'&&Math.abs(m.state.cooldown)<.008)m.tap(m.state.target[m.state.cursor]);if(id==='melody'&&m.state.phase===0)m.tap(m.state.target[m.state.data[0]]);if(m.state.phase)m.step(.008);}assert.equal(m.state.outcome,1);assert(m.valid(m.state));}
  const vm=f.vm('ExpansionViewModel');vm.init('melody');let notes=[],stops=0;vm.setToneCallbacks(n=>notes.push(n),()=>stops++);vm.startGame();vm.activate();for(let i=0;i<30;i++)vm.advance(100);assert.equal(notes.length,3);assert.equal(vm.state.phase,0);vm.onAppHidden();assert(stops>0);vm.dispose();
  const source=create('melody');source.activate();source.step(.008);const paused=f.vm('ExpansionViewModel');paused.init('melody');let replay=0;paused.setToneCallbacks(()=>replay++,()=>{});assert(paused.importContinuation(JSON.stringify({version:1,state:source.state,recorded:false,paused:false})));assert(paused.paused);assert.equal(replay,0);paused.dispose();
  for(let i=0;i<4;i++){const wav=fs.readFileSync(`entry/src/main/resources/rawfile/expansion_tone_${i}.wav`);assert.equal(wav.toString('ascii',0,4),'RIFF');assert.equal(wav.readUInt32LE(24),22050);assert.equal(wav.readUInt16LE(34),16);assert.equal(wav.length,wav.readUInt32LE(40)+44);}
});
test('farm watering, maturation and twelve harvests preserve the economy and support undo',()=>{
  const m=create('farm');m.tap(0);m.tap(900);assert.equal(m.state.board[0],0);m.undo();assert.equal(m.state.board[0],1);m.choose(1);m.tap(0);m.tap(900);m.choose(2);m.tap(0);assert.equal(m.state.cursor,1);while(!m.state.outcome){m.choose(0);m.tap(0);m.choose(1);m.tap(0);m.tap(900);m.choose(2);m.tap(0);}assert.equal(m.state.cursor,12);assert.equal(m.state.outcome,1);assert(m.valid(m.state));
});
test('decoration enforces footprint, gives full sale refunds and completes every design goal',()=>{
  const m=create('decorate');m.choose(0);m.tap(4);assert.equal(m.state.data[0],20);m.tap(0);assert.equal(m.state.data[0],14);m.choose(4);m.tap(1);assert.equal(m.state.data[0],20);assert.equal(m.state.pieces.length,0);
  for(const item of [[0,0],[1,5],[2,3],[2,4],[3,12]]){m.choose(item[0]);m.tap(item[1]);}assert.equal(m.state.outcome,1);assert.deepEqual(m.state.target,[1,1,1,1]);assert(m.valid(m.state));
});
test('fishing reacts to bites, manages tension, lands five fish and loses on three missed hooks',()=>{
  const m=create('fishing',2);let steps=0;while(!m.state.outcome&&steps++<30000){if(m.state.data[0]===0)m.tap(0);if(m.state.data[0]===2)m.tap(0);if(m.state.data[0]===3)m.tap(m.state.data[2]<62?1:2);m.step(.008);}assert.equal(m.state.outcome,1);assert.equal(m.state.cursor,5);assert(m.valid(m.state));
  const fail=create('fishing');for(let i=0;i<3;i++){fail.tap(0);run(fail,10);}assert.equal(fail.state.outcome,2);
});

for(const id of ['flappy','rollingball','shooter','tanks','fortress','survival'])test(`${id}: actual controls clear complete courses at every difficulty`,()=>{
  for(const level of [0,1,2]){
    const m=create(id,level);m.activate();let waypoint=0;const path=[[265,410],[265,270],[90,270],[90,180],[265,180],[265,60],[320,45]];
    run(m,120,(m,i)=>{
      const p=m.state.pieces[0],enemies=m.state.pieces.filter(q=>q.kind===33),t=i*.008;
      if(id==='flappy'){const g=m.state.pieces.filter(q=>q.kind===29&&q.x+q.w/2>p.x-p.r).sort((a,b)=>a.x-b.x)[0];if(g&&p.y>g.y+18&&p.vy>0)m.tap(0);}
      if(id==='rollingball'){const w=path[Math.min(waypoint,path.length-1)];if(Math.hypot(p.x-w[0],p.y-w[1])<12)waypoint++;m.aim(w[0],w[1]);}
      if(id==='shooter'&&enemies.length)m.aim(enemies[0].x,420);
      if(id==='tanks')m.aim(180+Math.sin(t*.4)*145,230+Math.cos(t*.4)*180);
      if(id==='survival')m.aim(180+Math.sin(t*.6)*145,370+Math.cos(t*.6)*50);
      if(id==='fortress'&&enemies.length){const e=enemies[0],distance=Math.hypot(e.x-p.x,e.y-p.y);m.aim(e.x,e.y+distance/300*(32+level*7));if(m.state.data[1]>=20)m.tap(0);}
    });assert.equal(m.state.outcome,1,`${id}/${level}`);
  }
});
for(const id of ['golf','bowling','penalty'])test(`${id}: actual aiming clears complete games at every difficulty`,()=>{
  for(const level of [0,1,2]){
    const m=create(id,level);
    if(id==='golf'){let b=m.state.pieces[0];m.aim(b.x+(330-b.x)*.8/1.8,b.y);wait(m);b=m.state.pieces[0];m.aim(b.x,b.y+(55-b.y)*.8/1.8);wait(m);m.aim(270,m.state.pieces[0].y);wait(m);}
    if(id==='bowling')for(const x of [180,220,140]){if(m.state.outcome)break;m.aim(x,60);wait(m);}
    if(id==='penalty'){m.activate();run(m,100,m=>{const k=m.state.pieces[1];if(m.state.pieces[0].vy===0){let x=k.x+k.vx;while(x<55||x>305){if(x<55)x=110-x;else x=610-x;}m.aim(x>180?35:325,80);}});}
    assert.equal(m.state.outcome,1,`${id}/${level}`);
  }
});
for(const id of finalIds.filter(id=>create(id).realtime()))test(`${id}: frame source stops on pause, background, exit and disposal; active continuation restores paused`,()=>{
  let callback=null,running=false,disposed=false;const frame={start(fn){callback=fn;running=true;},stop(){running=false;},dispose(){disposed=true;running=false;}};
  const vm=f.vm('ExpansionViewModel');vm.init(id,frame);vm.startGame();
  if(id==='linerescue'){vm.aim(100,180);vm.aim(260,180);}
  vm.activate();if(['billiards','golf','bowling'].includes(id))vm.aim(180,80);if(id==='fishing')vm.tap(0);
  assert(running);callback(100);vm.setDragging(true);vm.togglePause();assert(!vm.dragging&&!running);const paused=vm.exportContinuation();callback(100);vm.tap(0);vm.aim(60,60);assert.equal(vm.exportContinuation(),paused);
  vm.togglePause();assert(running);vm.onAppHidden();assert(!running);const hidden=vm.exportContinuation();callback(100);assert.equal(vm.exportContinuation(),hidden);vm.onAppShown();assert(running);
  assert(vm.requestBack());assert(!running);const confirming=vm.exportContinuation();callback(100);assert.equal(vm.exportContinuation(),confirming);vm.dismissExitConfirm();assert(running);
  const receiver=f.vm('ExpansionViewModel');receiver.init(id);assert(receiver.importContinuation(vm.exportContinuation()));assert(receiver.paused);
  vm.dispose();assert(disposed&&!running);const destroyed=vm.exportContinuation();callback(100);assert.equal(vm.exportContinuation(),destroyed);receiver.dispose();
});
test('native note service waits for every loaded pitch, closes raw handles and cancels pending playback on background',async()=>{
  const a=fixture();let complete=null,serial=0,resolvePlay=null;const closed=[],stopped=[],ready=[];
  const pool={on(event,cb){assert.equal(event,'loadComplete');complete=cb;},async load(fd,offset,length){assert.equal(offset,0);assert(length>0);const id=++serial;complete(id);return id;},play(id){assert(id>=1&&id<=4);return new Promise(resolve=>resolvePlay=resolve);},async stop(id){stopped.push(id);},async release(){}};
  a.native['@kit.MediaKit']={media:{async createSoundPool(count,info){assert.equal(count,4);assert.equal(info.usage,99);return pool;}}};a.native['@kit.AudioKit']={audio:{StreamUsage:{STREAM_USAGE_GAME:99}}};
  const Tone=a.load('entry/src/main/ets/common/ExpansionTonePlayer.ets').ExpansionTonePlayer,tones=new Tone();tones.onReady=value=>ready.push(value);
  await tones.init({async getRawFd(path){return {fd:10,offset:0,length:12368};},async closeRawFd(path){closed.push(path);}});assert.equal(closed.length,4);assert.equal(ready.at(-1),true);
  const playing=tones.play(2);assert(resolvePlay);await tones.stop();resolvePlay(72);await playing;assert(stopped.includes(72));await tones.dispose();await tones.play(0);assert.equal(stopped.length,1);
});
test('native note service handles load failure and releases a pool created after disposal',async()=>{
  const a=fixture();let released=0,closed=0,resolveCreate=null;const pool={on(){},async load(){throw new Error('load failed');},async release(){released++;}};
  a.native['@kit.MediaKit']={media:{async createSoundPool(){return pool;}}};a.native['@kit.AudioKit']={audio:{StreamUsage:{STREAM_USAGE_GAME:99}}};
  const Tone=a.load('entry/src/main/ets/common/ExpansionTonePlayer.ets').ExpansionTonePlayer,broken=new Tone();let ready=true;broken.onReady=v=>ready=v;
  await broken.init({async getRawFd(){return {fd:1,offset:0,length:44};},async closeRawFd(){closed++;}});assert.equal(ready,false);assert.equal(closed,1);await broken.dispose();assert.equal(released,1);
  a.native['@kit.MediaKit'].media.createSoundPool=()=>new Promise(resolve=>resolveCreate=resolve);const late=new Tone();const loading=late.init({});await late.dispose();resolveCreate(pool);await loading;assert.equal(released,2);
});
async function main(){let failed=0;for(const t of cases){try{await t.run();console.log(`PASS ${t.name}`);}catch(e){failed++;console.error(`FAIL ${t.name}: ${e.stack}`);}}console.log(`${cases.length-failed}/${cases.length} completion checks passed`);if(failed)process.exitCode=1;}main().catch(e=>{console.error(e);process.exitCode=1;});
