/* Raster compatibility check and contact sheets from real game state. These are not device screenshots. */
const fs=require('node:fs');
const path=require('node:path');
const sharp=require('sharp');
const {fixture}=require('./test-performance.cjs');
const root=path.resolve(__dirname,'..'),out=path.join(root,'docs/art');
const manifest=JSON.parse(fs.readFileSync(path.join(out,'expansion-art-manifest.json')));
const f=fixture(),{ExpansionModel}=f.rules('Expansion'),Art=f.load('entry/src/main/ets/common/ExpansionArt.ets').ExpansionArt;
const escape=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;');
const text=(s,x,y,size,c,anchor='middle')=>`<text x="${x}" y="${y}" font-family="Microsoft YaHei, sans-serif" font-size="${size}" fill="${c}" text-anchor="${anchor}">${escape(s)}</text>`;
const rect=(x,y,w,h,c,r=0)=>`<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${r}" fill="${c}"/>`;
const line=(x,y,a,b,c,width=3)=>`<path d="M${x} ${y}L${a} ${b}" stroke="${c}" stroke-width="${width}" fill="none"/>`;
const svg=(w,h,b)=>`<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="${w}" height="${h}">${b}</svg>`;
const allNames=[...manifest.assets.map(a=>a.name),...manifest.games.map(g=>g.icon),'expansion_puzzle_scene'];
function sample(id){
 const m=new ExpansionModel(f.rng(18));m.start(id,1);
 if(id==='blockfit'){m.tap(0);m.tap(13);}
 if(id==='fruitmerge'){for(const x of [90,170,250]){m.aim(x,30);for(let i=0;i<260;i++)m.step(.008);}}
 if(id==='farm'){m.tap(0);m.tap(1);m.choose(1);m.tap(0);m.tap(1);m.tap(900);m.choose(0);m.tap(3);}
 if(id==='decorate'){m.tap(0);m.choose(1);m.tap(5);m.choose(2);m.tap(3);m.choose(3);m.tap(19);}
 if(['runner','roomdefense','shooter','tanks','survival','fortress','fruitslice','rhythm'].includes(id)){m.activate();if(id==='roomdefense')m.tap(0);for(let i=0;i<150;i++)m.step(.008);}
 if(id==='melody')m.tap(900);
 if(id==='fisheat'){m.aim(180,420);for(let i=0;i<300;i++)m.step(.008);}
 if(id==='flappy'){m.activate();for(let i=0;i<150&&!m.state.outcome;i++){if(m.state.pieces[0].y>250)m.tap(0);m.step(.008);}}
 return m;
}
async function main(){
 let checked=0;
 for(const theme of ['base','dark']){
  const dark=theme==='dark',suffix=dark?'dark':'light',ink=dark?'#DEEAFF':'#304A69',bg=dark?'#111D2F':'#F0F5FA',panel=dark?'#22344B':'#FFFFFF';
  const images={};
  for(const name of allNames){const file=path.join(root,'entry/src/main/resources',theme,'media',name+'.svg');images[name]=(await sharp(file).png().toBuffer()).toString('base64');checked++;}
  const img=(name,x,y,w,h=w)=>{name=name.replace('app.media.','');if(!images[name])throw Error('Missing preview asset '+name);return `<image x="${x}" y="${y}" width="${w}" height="${h}" preserveAspectRatio="none" xlink:href="data:image/png;base64,${images[name]}"/>`;};
  let icons=rect(0,0,1280,1670,bg)+text('67 款游戏 · 原创入口美术',30,42,25,ink,'start')+text('浅深色矢量资源 / '+suffix+' / 素材预览，非设备截图',30,70,14,ink,'start');
  manifest.games.forEach((g,i)=>{const x=20+i%8*157,y=95+Math.floor(i/8)*173;icons+=rect(x,y,145,161,panel,18)+img(g.icon,x+19,y+7,106)+text(g.name,x+73,y+136,14,ink)+text(g.id,x+73,y+153,10,ink);});
  await sharp(Buffer.from(svg(1280,1670,icons))).png().toFile(path.join(out,`expansion-icons-${suffix}.png`));
  const sprites=manifest.assets.filter(a=>!a.name.startsWith('exp_board_'));
  const sh=110+Math.ceil(sprites.length/12)*98;let pieces=rect(0,0,1280,sh,bg)+text('角色 · 棋具 · 道具 · 反馈素材',30,42,25,ink,'start')+text(sprites.length+' 种 / '+suffix+' / 无字体与外部图片依赖',30,70,14,ink,'start');
  sprites.forEach((a,i)=>{const x=10+i%12*106,y=100+Math.floor(i/12)*98;pieces+=rect(x,y,100,93,panel,10)+img(a.name,x+20,y+4,60,65)+text(a.name.replace('exp_',''),x+50,y+83,9,ink);});
  await sharp(Buffer.from(svg(1280,sh,pieces))).png().toFile(path.join(out,`expansion-sprites-${suffix}.png`));
  for(let batch=0;batch<6;batch++){
   const games=manifest.games.slice(batch*12,batch*12+12),height=100+Math.ceil(games.length/3)*484;
   let sheet=rect(0,0,1060,height,bg)+text('游戏内素材 · '+suffix+' · '+(batch+1)+'/6',20,40,25,ink,'start')+text('使用真实模型数据组合，非 ArkUI 页面截图；文字与触控由应用原生提供。',20,69,14,ink,'start');
   games.forEach((g,i)=>{
    const m=sample(g.id),s=m.state,id=g.id,x=15+i%3*350,y=90+Math.floor(i/3)*484;
    let body=img(g.board,0,0,360,460);
    if(['blockfit','tilestack','arrowclear','sokoban','pipes','linktiles','groupclear','slotpair','sand','farm','decorate','chess','xiangqi','hiddenobjects','differences'].includes(id)){
      const cols=s.cols,rows=s.rows,u=Math.min(330/cols,410/rows),ox=(360-cols*u)/2,oy=(460-rows*u)/2;
      for(let at=0;at<cols*rows;at++){
       let v=id==='tilestack'?(m.puzzle.top(s,at)<0?0:s.board[m.puzzle.top(s,at)]):s.board[at],name=v>0?'exp_tile_'+((v-1)%6):'exp_empty',label='';
       if(id==='blockfit')name=v?'exp_block_'+(v-1):'exp_empty';
       if(id==='sokoban')name=at===s.cursor?'exp_robot':s.pieces.some(p=>p.y*cols+p.x===at)?'exp_crate':v===1?'exp_wall':v===2?'exp_goal':'exp_floor';
       if(id==='pipes')name='exp_pipe_'+v;
       if(id==='arrowclear')name=v?'exp_arrow_'+(v-1):'exp_empty';
       if(id==='sand')name=v?'exp_sand_'+(v-1):'exp_empty';
       if(id==='farm')name=['exp_soil','exp_seedling','exp_watered','exp_crop'][v];
       if(id==='decorate')name='exp_floor';
       if(id==='chess')name=v?Art.chess(v):'exp_empty';
       if(id==='xiangqi'){name=v?'exp_chip':'exp_empty';label=v?['','帥','仕','相','馬','車','炮','兵'][v%10]:'';}
       if(id==='hiddenobjects')name=v===8?'exp_fruit_4':v===9?'exp_object_2':'exp_object_'+[0,1,3,5,6,7,8][v-1];
       if(id==='differences')name='exp_object_'+(v-1);
       body+=img(name,ox+at%cols*u+2,oy+Math.floor(at/cols)*u+2,u-4,u-4)+(label?text(label,ox+(at%cols+.5)*u,oy+(Math.floor(at/cols)+.62)*u,20,ink):'');
      }
      if(id==='decorate')s.pieces.forEach(p=>{body+=img(Art.furniture(p.color),ox+p.x*u,oy+p.y*u,p.w*u,p.h*u);});
    }else if(id==='mahjongsolitaire'){
      s.pieces.filter(p=>p.alive).forEach(p=>{body+=img(Art.tile(p.color-1),p.x*60+2+p.owner*2,90+p.y*60+2+p.owner*2,53,53);});
    }else if(id==='parkingjam'){
      s.pieces.forEach(p=>{body+=img(Art.car(p.id%6),p.x*360/s.cols+2,p.y*360/s.rows+2,p.w*360/s.cols-4,p.h*360/s.rows-4)+text(['↑','→','↓','←'][p.color],(p.x+p.w/2)*360/s.cols,(p.y+p.h/2)*360/s.rows+7,22,'#FFFFFF');});
    }else if(id==='screwout'){
      s.pieces.forEach(p=>{body+=p.kind===0?img('exp_plate',p.x,p.y,p.w,p.h):img('exp_screw',p.x-18,p.y-18,36);});
    }else if(['solitaire','spider','freecell','doudizhu','guandan','mahjong'].includes(id)){
      const cards=['solitaire','spider','freecell'].includes(id)?s.piles.slice(id==='solitaire'?2:0,id==='solitaire'?9:id==='spider'?10:8).flatMap(p=>p.cards).slice(0,30):s.piles[0].cards.slice(0,30);
      cards.forEach((c,i)=>{const cx=12+i%6*57,cy=48+Math.floor(i/6)*75;body+=img(id==='mahjong'?'exp_mahjong':'exp_card_front',cx,cy,50,68)+text(id==='mahjong'?(Math.floor(c/4)%9+1)+['萬','筒','索'][Math.floor(c/4/9)%3]:['A','2','3','4','5','6','7','8','9','10','J','Q','K'][c%13],cx+25,cy+40,19,ink);});
    }else if(id==='watersort'){
      for(let t=0;t<s.cols;t++){const xx=12+t%5*68,yy=30+Math.floor(t/5)*190;for(let layer=0;layer<4;layer++){const v=s.board[t*4+layer];if(v)body+=img('exp_water_'+(v-1),xx+16,yy+25+(3-layer)*33,36,33);}body+=img('exp_tube',xx,yy,66,172);}
    }else if(id==='bubbleshooter'){
      s.board.forEach((v,i)=>{if(v)body+=img(Art.bubble(v-1),m.physics.bubbleX(i)-19,m.physics.bubbleY(i)-19,38);});body+=img('exp_arrow_0',160,415,40);
    }else if(id==='yarn'){
      for(let c=0;c<s.cols;c++)for(let r=0;r<8;r++){const v=s.board[c*8+7-r];if(v)body+=img(Art.yarn(v-1),10+c*340/s.cols,25+r*38,340/s.cols-4,32);}for(let r=0;r<3;r++)body+=img(Art.reel(r),40+r*100,355,74);
    }else if(id==='untangle'||id==='onestroke'){
      const point=n=>id==='untangle'?[s.pieces[n].x,s.pieces[n].y]:[60+n%3*120,100+Math.floor(n/3)*120];
      for(let e=0;e<s.board.length;e+=2){const a=point(s.board[e]),b=point(s.board[e+1]);body+=line(a[0],a[1],b[0],b[1],id==='untangle'?'#EABB63':'#438ADF');}
      for(let n=0;n<(id==='untangle'?s.pieces.length:9);n++){const a=point(n);body+=img('exp_anchor',a[0]-20,a[1]-20,40)+text(n+1,a[0],a[1]+5,14,ink);}
    }else if(id==='picturepuzzle')body+=img('expansion_puzzle_scene',15,65,330,330);
    else if(id==='melody')for(let n=0;n<4;n++)body+=img(Art.block(n),15+n*85,170,75,160)+text(['C','D','E','G'][n],52+n*85,290,28,ink);
    else if(id==='restaurant')for(let n=0;n<3;n++)body+=img(Art.person(n),20+n*115,80,88)+img(Art.food(n),35+n*115,235,70);
    else if(id==='buscolor')for(let n=0;n<12;n++)body+=img(Art.bus(s.pieces[n].color-1),20+n%3*115,22+Math.floor(n/3)*102,90);
    else if(id==='backpack')for(let n=0;n<4;n++)body+=img(Art.equipment(n),30+n%2*170,75+Math.floor(n/2)*175,125);
    else if(id==='characters'||id==='idiom'){body+=img('exp_floor',35,60,290,180)+text(id==='characters'?'明 = 日 + 月':'一 心 一 意',180,160,28,ink);}
    else if(id==='fishing')body+=img('exp_bobber',155,150,60)+img(Art.fish(3),220,280,75);
    else if(id==='tug')body+=img(Art.person(0),30,180,90)+line(100,230,260,230,'#EABB63',6)+img(Art.person(1),240,180,90);
    else if(id==='dots'){for(let r=0;r<5;r++)for(let c=0;c<5;c++)body+=img('exp_anchor',30+c*65,55+r*72,26);}
    else if(id==='ludo'){s.pieces.forEach(p=>{body+=img('exp_plane',p.owner===0||p.owner===3?32+p.id%2*38:256+p.id%2*38,p.owner<2?25+Math.floor(p.id%4/2)*38:365+Math.floor(p.id%4/2)*38,30);});}
    else s.pieces.forEach(p=>{
      const camera=['platformer','grapple','hillclimb'].includes(id)?Math.max(0,s.pieces[0].x-160):0;
      const w=[25,26].includes(p.kind)?p.w:p.kind===39&&p.r===0?p.w:p.r*2,h=[25,26].includes(p.kind)?p.h:p.kind===39&&p.r===0?p.h:p.r*2;
      if(p.kind===29){body+=rect(p.x-p.w/2,0,p.w,p.y-p.h/2,'#6CBFA4')+rect(p.x-p.w/2,p.y+p.h/2,p.w,460-p.y-p.h/2,'#6CBFA4');}
      else if(w>0&&h>0&&p.x-camera<400)body+=img(Art.piece(id,p),(p.x-([25,26].includes(p.kind)?0:w/2))-camera,p.y-([25,26].includes(p.kind)?0:h/2),w,h);
    });
    sheet+=rect(x,y,335,470,panel,18)+img(g.icon,x+10,y+5,40)+text(g.name,x+58,y+32,17,ink,'start')+`<svg x="${x+14}" y="${y+50}" width="307" height="392" viewBox="0 0 360 460">${body}</svg>`+text(g.id,x+168,y+459,11,ink);
   });
   await sharp(Buffer.from(svg(1060,height,sheet))).png().toFile(path.join(out,`expansion-gameplay-${suffix}-${batch+1}.png`));
  }
 }
 const result={checkedSvgFiles:checked,gameplayResources:manifest.assets.length,icons:manifest.games.length,preview:'Material compositions from real model states; not device screenshots.'};
 fs.writeFileSync(path.join(out,'expansion-art-render-check.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result));
}
main().catch(e=>{console.error(e);process.exitCode=1;});
