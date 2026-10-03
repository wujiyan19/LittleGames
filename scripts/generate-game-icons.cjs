/* Canonical icon source for all 100 games. Transparent, font-free SVG miniatures.
 * Gameplay art generators call this after updating the reusable exp_* materials. */
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
const classic = ['snake','tetris','2048','whackmole','minesweeper','jumpjump','brickbreaker',
  'sudoku','slidepuzzle','klotski','guessnumber','memorycard','match3'];
const readIds = file => [...fs.readFileSync(path.join(root, file), 'utf8').matchAll(/\{ id: '([^']+)'/g)].map(m => m[1]);
const collection = readIds('entry/src/main/ets/model/CollectionCatalog.ets');
const expansion = readIds('entry/src/main/ets/model/ExpansionCatalog.ets');
const ids = [...classic, ...collection, ...expansion];
const rect = (x,y,w,h,r,fill,stroke='none',sw=2) => `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${r}" fill="${fill}" stroke="${stroke}" stroke-width="${sw}"/>`;
const circle = (x,y,r,fill,stroke='none',sw=2) => `<circle cx="${x}" cy="${y}" r="${r}" fill="${fill}" stroke="${stroke}" stroke-width="${sw}"/>`;
const ellipse = (x,y,rx,ry,fill,opacity=1) => `<ellipse cx="${x}" cy="${y}" rx="${rx}" ry="${ry}" fill="${fill}" opacity="${opacity}"/>`;
const line = (d,stroke,width=3,opacity=1) => `<path d="${d}" fill="none" stroke="${stroke}" stroke-width="${width}" stroke-linecap="round" stroke-linejoin="round" opacity="${opacity}"/>`;
const shape = (d,fill,stroke='none',width=2) => `<path d="${d}" fill="${fill}" stroke="${stroke}" stroke-width="${width}" stroke-linejoin="round"/>`;
const group = (body,x=0,y=0,s=1,angle=0) => `<g transform="translate(${x} ${y}) scale(${s}) rotate(${angle} 50 50)">${body}</g>`;
const gradient = (id,a,b) => `<linearGradient id="${id}" x1="0" y1="0" x2=".25" y2="1"><stop stop-color="${a}"/><stop offset="1" stop-color="${b}"/></linearGradient>`;
const writeChanged = (file,contents) => {
  if(fs.existsSync(file)&&fs.readFileSync(file,'utf8')===contents)return;
  fs.writeFileSync(file,contents);
};

function generate() {
  assert.equal(ids.length, 100); assert.equal(new Set(ids).size, 100);
  const strings = JSON.parse(fs.readFileSync(path.join(root,'entry/src/main/resources/zh_CN/element/string.json'))).string;
  for (const theme of ['base','dark']) {
    const dark = theme === 'dark';
    const p = {ink:dark?'#DAE8FF':'#304A69',edge:dark?'#516884':'#9CB7D0',low:dark?'#1C2B42':'#DCE8F1',
      paper:dark?'#30445F':'#FFFAF0',wood:dark?'#6C4F3C':'#D5AC7C',blue:'#438ADF',coral:'#EB857C',gold:'#EABB63',mint:'#6CBFA4',violet:'#9988D3'};
    const defs = gradient('paper',p.paper,p.low)+gradient('blue','#9AD2F7','#397ACB')+gradient('coral','#FFC0A5','#CF645F')+
      gradient('gold','#FFE7AD','#D7A04A')+gradient('mint','#B7EACD','#4D9E85')+gradient('violet','#DCD2FA','#8470C2')+
      gradient('cyan','#B8EDF1','#4AA3BF')+gradient('wood',dark?'#9F7754':'#F0D1A2',p.wood)+gradient('metal','#DBEAF2','#6386A8')+
      gradient('ink','#62788E','#20364F')+gradient('ivory','#FFF8E7','#C9D8E6');
    const tile = (x,y,w,h,color='paper',r=7) => rect(x,y+3,w,h,r,p.edge)+rect(x,y,w,h,r,'url(#'+color+')',p.edge)+line(`M${x+7} ${y+5}H${x+w-7}`,'#FFFFFF',2,.5);
    const asset = name => {
      const svg = fs.readFileSync(path.join(root,`entry/src/main/resources/${theme}/media/exp_${name}.svg`),'utf8');
      // Every icon gets one shared ground shadow, rather than a second shadow per reused piece.
      return svg.slice(svg.indexOf('</defs>')+7,svg.lastIndexOf('</svg>'))
        .replace(/<ellipse cx="50" cy="87" rx="32" ry="6"[^>]*\/>/g,'');
    };
    const small = (name,x,y,s=.5,angle=0) => group(asset(name),x,y,s,angle);
    const disc = (x,y,r,color='ink') => circle(x,y+2,r,p.edge)+circle(x,y,r,'url(#'+color+')',p.edge)+ellipse(x-r*.3,y-r*.4,r*.3,r*.15,'#FFFFFF',.55);
    const cross = (x,y,s=1) => group(line('M0 0L14 14M14 0L0 14','#397ACB',7)+line('M0 -2L14 12M14 -2L0 12','#9AD2F7',5),x,y,s);
    const ring = (x,y,r=8) => circle(x,y+2,r,'none','#CF645F',5)+circle(x,y,r,'none','#FFC0A5',4);
    const grid = (n,color='paper') => tile(10,10,80,78,color,10)+Array.from({length:n-1},(_,i)=>{
      const at=10+(i+1)*80/n; return line(`M${at} 16V83M16 ${at}H84`,p.edge,1.6);
    }).join('');
    const digit = (v,x,y,s=1,color=p.ink) => {
      const segments=['M0 0H8','M8 0V8','M8 8V16','M0 16H8','M0 8V16','M0 0V8','M0 8H8'];
      const selected=['012345','12','01346','01236','1256','02356','023456','012','0123456','012356'][v];
      return group([...selected].map(i=>line(segments[Number(i)],color,2.2)).join(''),x,y,s);
    };
    const gems = (x,y,color,s=1) => group(shape('M10 0H30L40 15L20 40L0 15Z','url(#'+color+')',p.edge)+
      shape('M10 0L20 15L30 0L40 15H0Z','#FFFFFF','none')+line('M20 15V37','#FFFFFF',2,.5),x,y,s);
    const cards = symbol => group(asset('card_front'),8,8,.67,-8)+group(asset('card_back'),31,16,.67,8)+
      (symbol ? group(shape('M25 12L33 27L25 42L17 27Z','#FFF5D6'),35,31,.9) : '');
    const notebook = () => tile(19,8,65,80,'paper',8)+line('M32 13V81',p.blue,2)+[24,42,60,78].map(y=>line(`M14 ${y}H24`,p.ink,4)).join('');
    const question = (x,y,s=1) => group(line('M0 9C0 -7 24 -7 24 8C24 20 12 15 12 28',p.ink,5)+circle(12,39,3,p.ink),x,y,s);
    const scenes = {};

    // Classic 13: redraw the former bitmap subjects with the same vector materials.
    scenes.snake=line('M76 77C64 97 22 88 25 67C28 48 57 55 57 68C57 80 38 78 39 65L50 41',p.edge,19)+
      line('M76 75C64 95 22 86 25 65C28 46 57 53 57 66C57 78 38 76 39 63L50 39','#6CBFA4',16)+
      ellipse(57,32,24,19,'url(#mint)')+ellipse(67,39,17,10,'#C7EDD0')+circle(49,25,7,'#FFFAF0')+circle(65,25,7,'#FFFAF0')+
      circle(51,25,3,'#304A69')+circle(67,25,3,'#304A69')+line('M74 40L87 43L91 38','#EB857C',3)+line('M35 58Q24 67 31 76','#D8F6DB',3,.6);
    scenes.tetris=[[12,60,'blue'],[37,60,'blue'],[62,60,'blue'],[37,35,'blue'],[62,10,'coral'],[62,35,'coral']].map(v=>tile(v[0],v[1],23,23,v[2],5)).join('');
    scenes['2048']=tile(8,8,84,82,'paper',11)+[[2,14,14,'gold'],[4,52,14,'coral'],[8,14,52,'blue'],[16,52,52,'mint']].map(v=>
      tile(v[1],v[2],34,33,v[3],6)+(v[0]===16?digit(1,v[1]+9,v[2]+9,.9,'#FFFFFF')+digit(6,v[1]+19,v[2]+9,.9,'#FFFFFF'):digit(v[0],v[1]+13,v[2]+8,1.1,'#FFFFFF'))).join('');
    scenes.whackmole=ellipse(50,79,42,13,p.edge)+ellipse(50,77,36,10,'#20364F')+ellipse(50,58,27,25,'url(#wood)')+
      circle(29,36,9,'url(#wood)')+circle(71,36,9,'url(#wood)')+ellipse(50,46,26,22,'url(#wood)')+
      ellipse(50,59,16,9,'#FFE7AD')+circle(40,43,4,'#304A69')+circle(60,43,4,'#304A69')+ellipse(50,52,6,4,'#304A69')+
      ellipse(29,75,10,5,'url(#wood)')+ellipse(71,75,10,5,'url(#wood)');
    scenes.minesweeper=Array.from({length:8},(_,i)=>group(line('M50 10V25','#6386A8',7),0,0,1,i*45)).join('')+
      disc(50,50,29,'ink')+small('flag',56,54,.42);
    scenes.jumpjump=tile(12,75,34,13,'wood',6)+tile(64,64,28,13,'wood',6)+line('M29 57Q45 4 74 45',p.blue,2,.5)+
      ellipse(52,44,21,15,'url(#mint)')+circle(40,30,9,'url(#mint)')+circle(64,30,9,'url(#mint)')+circle(40,30,5,'#FFFAF0')+
      circle(64,30,5,'#FFFAF0')+circle(41,31,2.5,'#304A69')+circle(65,31,2.5,'#304A69')+line('M44 47Q52 53 60 47','#304A69',2)+line('M34 51L21 63M68 51L78 57',p.mint,8);
    scenes.brickbreaker=Array.from({length:7},(_,i)=>tile(9+i%3*28,12+Math.floor(i/3)*16,24,12,['coral','gold','mint'][i%3],4)).join('')+
      tile(28,80,46,9,'blue',5)+disc(63,62,8,'ivory')+line('M58 74L47 55L53 42',p.blue,2,.55);
    scenes.sudoku=grid(3)+[1,5,3,4,8,2,6,7,9].map((v,i)=>digit(v,19+i%3*27,21+Math.floor(i/3)*26,.8)).join('');
    scenes.slidepuzzle=tile(8,8,84,82,'paper',11)+Array.from({length:8},(_,i)=>tile(14+i%3*26,14+Math.floor(i/3)*26,23,23,i%3===0?'gold':'blue',5)+digit(i+1,22+i%3*26,17+Math.floor(i/3)*26,.9,'#FFFFFF')).join('');
    scenes.klotski=tile(8,8,84,82,'wood',11)+tile(14,14,19,45,'gold',4)+tile(37,14,27,43,'coral',4)+tile(68,14,18,45,'gold',4)+
      tile(14,63,31,22,'wood',4)+tile(49,63,37,22,'wood',4)+line('M45 34H56M50 29V43','#FFF1C5',3);
    scenes.guessnumber=disc(47,44,32,'gold')+question(35,23,.75)+small('coin',57,59,.35)+small('coin',10,64,.28);
    scenes.memorycard=cards(true);
    scenes.match3=gems(3,43,'blue',1.05)+gems(32,12,'gold',1.12)+gems(60,47,'coral',.95);

    // The original Collection 20: the same silhouettes, now with the common palette and scale.
    scenes.tictactoe=grid(3)+cross(19,21,.7)+ring(50,51,8)+cross(71,71,.7)+ring(77,25,8);
    scenes.gomoku=grid(5,'wood')+[[26,26,'ink'],[42,42,'ink'],[58,58,'ink'],[74,74,'ink'],[58,26,'ivory']].map(v=>disc(v[0],v[1],6,v[2])).join('');
    scenes.reversi=tile(10,10,80,78,'mint',10)+line('M50 18V80M18 49H82','#D4EEDF',2)+disc(35,35,13,'ink')+disc(65,35,13,'ivory')+disc(35,64,13,'ivory')+disc(65,64,13,'ink');
    scenes.fourline=tile(10,10,80,78,'blue',10)+Array.from({length:16},(_,i)=>circle(23+i%4*18,23+Math.floor(i/4)*18,7,i>10?'url(#'+(i%2?'coral':'gold')+')':'#254A6E',p.edge,1)).join('');
    scenes.nim=tile(8,55,84,31,'wood',10)+[[24,60],[49,60],[74,60],[37,37],[62,37],[49,14]].map(v=>disc(v[0],v[1],11,'blue')).join('');
    scenes.lights=tile(10,10,80,78,'ink',10)+Array.from({length:9},(_,i)=>disc(25+i%3*25,24+Math.floor(i/3)*25,9,[1,3,4,5,7].includes(i)?'gold':'ink')).join('');
    scenes.flood=tile(10,10,80,78,'paper',10)+Array.from({length:9},(_,i)=>tile(15+i%3*25,15+Math.floor(i/3)*25,21,21,['blue','blue','gold','blue','mint','gold','mint','mint','coral'][i],5)).join('');
    scenes.maze=tile(10,10,80,78,'mint',10)+line('M28 17V39H58V70H84M15 69H38V51H15M74 16V39H84','#E7F1D7',9)+small('robot',9,49,.35)+small('flag',66,55,.33);
    scenes.hanoi=tile(5,79,90,12,'wood',6)+[24,50,76].map(x=>rect(x,13,4,66,2,'url(#wood)',p.edge,1)).join('')+
      [[12,68,76,'blue'],[21,55,58,'mint'],[30,42,40,'gold'],[39,29,22,'coral']].map(v=>tile(v[0],v[1],v[2],10,v[3],5)).join('');
    scenes.peg=tile(10,10,80,78,'wood',10)+Array.from({length:9},(_,i)=>i===4?ellipse(50,51,8,5,'#304A69'):disc(25+i%3*25,24+Math.floor(i/3)*25,7,'gold')).join('');
    scenes.nonogram=grid(5)+[1,3,5,6,7,8,9,10,11,12,13,14,16,17,18,22].map(i=>rect(12+i%5*16,12+Math.floor(i/5)*16,12,12,2,'url(#blue)')).join('');
    scenes.arithmetic=notebook()+cross(39,24,.85)+ring(69,30,8)+line('M39 64H55M47 56V72',p.blue,5)+line('M64 60H77M64 69H77',p.coral,4);
    scenes.compare=tile(32,80,37,9,'blue',5)+rect(47,23,6,56,3,'url(#blue)')+line('M15 34L86 22',p.gold,5)+
      line('M22 34L9 61H35ZM78 24L64 50H91Z',p.ink,2)+shape('M8 61H36Q33 75 22 75Q11 75 8 61Z','url(#gold)')+
      shape('M63 50H92Q89 64 77 64Q66 64 63 50Z','url(#coral)')+gems(10,37,'gold',.6)+gems(66,26,'coral',.55);
    scenes.sequence=tile(10,61,22,26,'blue',5)+tile(39,42,22,45,'mint',5)+tile(68,21,22,66,'gold',5)+line('M19 44L49 25L77 7M65 8L77 7L76 19',p.blue,4);
    scenes.binary=tile(10,10,80,78,'ink',10)+[23,41,59,77].map(v=>line(`M${v} 3V13M${v} 87V97M3 ${v}H13M87 ${v}H97`,p.edge,3)).join('')+
      tile(24,25,52,49,'blue',8)+digit(0,34,37,1.5,'#FFFFFF')+digit(1,55,37,1.5,'#FFF1C5');
    scenes.targetsum=notebook()+tile(39,30,35,40,'gold',6)+question(47,34,.65);
    scenes.schulte=grid(3)+[3,8,1,6,2,9,7,4,5].map((v,i)=>digit(v,19+i%3*27,21+Math.floor(i/3)*26,.8,i===4?p.coral:p.ink)).join('');
    scenes.memorysequence=cards(false)+line('M20 84H48L40 77M48 84L40 91',p.gold,4);
    scenes.missing=group(asset('card_front'),8,13,.7,-8)+question(32,32,.7)+group(asset('card_back'),35,18,.64,8);
    scenes.reaction=tile(13,10,74,78,'ink',14)+circle(50,46,26,'url(#mint)',p.edge)+line('M37 46L47 57L65 35','#FFFFFF',6)+line('M38 79H48M56 79H66',p.mint,3);

    // New 67: real gameplay pieces, composed with the same materials, ground and clear silhouettes.
    const hero = {blockfit:'block_0',tilestack:'tile_2',bubbleshooter:'bubble_0',fruitmerge:'fruit_9',watersort:'tube',arrowclear:'arrow_1',screwout:'screw',parkingjam:'car_1',runner:'runner',blackhole:'hole',fisheat:'fish_0',sokoban:'crate',pipes:'pipe_3',differences:'object_2',roomdefense:'tower',basketball:'basketball',solitaire:'card_back',characters:'brush',rhythm:'note',restaurant:'food_1',linktiles:'tile_1',mahjongsolitaire:'mahjong',groupclear:'block_3',slotpair:'tile_4',buscolor:'bus_0',yarn:'reel_4',sand:'nozzle_2',untangle:'anchor',platformer:'robot',grapple:'robot',flappy:'bird',fruitslice:'fruit_4',rollingball:'ball',shooter:'plane',tanks:'tank',fortress:'tower',survival:'enemy',backpack:'shield',billiards:'ball',penalty:'soccer',pingpong:'paddle',bowling:'pin',golf:'flag',drift:'car_0',hillclimb:'car_3',airhockey:'striker',tug:'person_1',dots:'tile_0',doudizhu:'card_front',guandan:'card_front',mahjong:'mahjong',xiangqi:'chip',chess:'chess_0_1',ludo:'plane',spider:'card_back',freecell:'card_front',onestroke:'anchor',hiddenobjects:'object_6',linerescue:'dog',picturepuzzle:'object_2',idiom:'book',wordtower:'tower',beatjump:'ball',melody:'note',farm:'crop',decorate:'sofa',fishing:'fish_3'};
    const detail = {fruitmerge:'fruit_3',fisheat:'fish_1',fishing:'bobber',fruitslice:'fruit_3',farm:'seedling',decorate:'plant',restaurant:'food_0',platformer:'flag',grapple:'anchor',bowling:'ball',billiards:'coin',rollingball:'flag',golf:'ball',airhockey:'puck',roomdefense:'enemy',fortress:'card_front',characters:'crate',idiom:'brush',rhythm:'tile_4',melody:'tile_0',picturepuzzle:'object_8',backpack:'sword'};
    for (const id of expansion) {
      assert(hero[id],id);
      scenes[id]=detail[id] ? group(asset(hero[id]),5,0,.86)+small(detail[id],58,54,.43) : asset(hero[id]);
    }
    scenes.blockfit=small('block_0',3,40,.5)+small('block_0',46,40,.5)+small('block_0',46,-3,.5);
    scenes.tilestack=small('tile_2',0,8,.78)+small('tile_1',35,34,.64)+small('tile_3',9,56,.45);
    scenes.bubbleshooter=small('bubble_1',0,4,.5)+small('bubble_2',46,4,.5)+small('bubble_0',23,43,.57);
    scenes.watersort=[4,49].map((x,i)=>rect(x+12,34,21,18,2,'url(#coral)')+rect(x+12,52,21,18,2,'url(#blue)')+
      rect(x+12,70,21,12,2,'url(#'+(i===0?'mint':'gold')+')')+`<g transform="translate(${x} 8) scale(.45 .82)">${asset('tube')}</g>`).join('');
    scenes.arrowclear=small('arrow_1',0,2,.65)+small('arrow_0',42,40,.57);
    scenes.sokoban=small('crate',0,11,.76)+small('robot',58,59,.38);
    scenes.pipes=group(asset('pipe_3'),10,9,.82)+small('goal',61,61,.3);
    scenes.differences=small('object_2',-1,9,.67)+small('object_2',43,35,.56)+circle(82,37,10,'none',p.coral,3);
    scenes.linktiles=small('tile_1',-2,5,.64)+small('tile_1',39,34,.64)+line('M34 86H67V69',p.gold,3);
    scenes.groupclear=small('block_3',2,2,.52)+small('block_3',47,2,.52)+small('block_3',25,46,.52);
    scenes.slotpair=small('tile_4',0,9,.65)+small('tile_4',43,33,.55);
    scenes.mahjongsolitaire=small('mahjong',0,4,.8)+small('tile_0',60,56,.4);
    scenes.sand=group(asset('nozzle_2'),0,-1,.9)+[24,41,60,76].map((x,i)=>circle(x,88-i%2*5,4,['#EABB63','#EB857C'][i%2])).join('');
    scenes.untangle=line('M19 22L78 72L81 20L23 75L19 22',p.coral,4)+[[19,22],[78,72],[81,20],[23,75]].map(v=>disc(v[0],v[1],9,'metal')).join('');
    scenes.onestroke=line('M18 22H80V77H18L80 22',p.blue,4)+[[18,22],[80,22],[18,77],[80,77]].map(v=>disc(v[0],v[1],8,'metal')).join('');
    scenes.shooter=group(asset('plane'),0,0,.86)+small('bullet',62,46,.4);
    scenes.drift=group(asset('car_0'),8,-1,.88,18)+line('M23 77Q10 89 27 95M72 76Q58 90 76 95',p.edge,3);
    scenes.hillclimb=shape('M5 87L34 67L92 47V93H5Z','url(#wood)',p.edge)+group(asset('car_3'),8,-4,.84,25);
    scenes.pingpong=small('paddle',6,-6,.92,30)+disc(75,67,11,'ivory');
    scenes.tug=small('person_1',-5,12,.63)+small('person_0',46,12,.63)+line('M22 59H79',p.gold,4)+line('M50 59V70',p.coral,4);
    scenes.dots=tile(8,8,84,82,'paper',10)+line('M26 25H73M26 25V72M26 72H73',p.blue,4)+[[26,25],[73,25],[26,72],[73,72],[50,49]].map(v=>disc(v[0],v[1],5,'gold')).join('');
    const cardFace = color => asset('card_front')+gems(29,31,color,.95);
    scenes.doudizhu=group(cardFace('coral'),2,1,.77,-9)+small('tile_4',57,52,.45);
    scenes.guandan=group(cardFace('blue'),2,1,.77,-9)+group(cardFace('gold'),40,32,.56,7);
    scenes.mahjong=group(asset('mahjong'),-3,0,.78,-7)+group(asset('mahjong'),42,27,.62,7)+[46,58,70].map(x=>circle(x,60,3,p.mint)).join('');
    scenes.xiangqi=asset('chip')+line('M32 30H68M37 41H63M50 30V67M32 68H68M38 51L31 63M62 51L69 63',p.coral,4);
    scenes.chess=group(asset('chess_0_1'),4,1,.88)+small('chess_1_5',56,54,.42);
    scenes.ludo=group(asset('plane'),-2,5,.82,45)+small('tile_2',59,59,.38);
    scenes.solitaire=group(asset('card_back'),4,2,.8,-8)+small('tile_1',55,55,.45);
    scenes.spider=group(asset('card_back'),4,2,.8,-8)+small('tile_4',55,55,.45);
    scenes.freecell=group(cardFace('mint'),4,2,.78,-8)+small('tile_3',55,55,.45);
    scenes.linerescue=line('M14 14L7 69H89L87 15H14',p.blue,3)+group(asset('dog'),16,18,.69)+small('bee',64,0,.36);
    scenes.wordtower=tile(12,74,76,14,'blue',4)+tile(23,52,54,18,'gold',4)+tile(34,30,32,18,'coral',4)+line('M27 79H42M41 58H59M45 36H55','#FFFFFF',2);
    scenes.beatjump=small('block_0',3,62,.4)+small('block_4',34,38,.4)+small('block_1',66,12,.4)+small('ball',8,-2,.53);
    const bodies=[];
    for (const id of ids) {
      assert(scenes[id], 'Missing miniature '+id);
      const body=ellipse(60,104,43,6,dark?'#050F21':'#193D6C',dark?.28:.16)+group(scenes[id],10,9,1);
      bodies.push(body);
      const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="120" height="120" viewBox="0 0 120 120"><defs>${defs}</defs>${body}</svg>\n`;
      writeChanged(path.join(root,`entry/src/main/resources/${theme}/media/game_${id}.svg`),svg);
    }
    assert.equal(new Set(bodies).size,100,'Every game needs its own visible composition');
  }
  const manifest={generator:'scripts/generate-game-icons.cjs',style:'soft tactile miniatures',canvas:120,themes:['base','dark'],
    background:'transparent; shared ArkUI badge surface',source:'First-party SVG geometry and reusable gameplay pieces',
    games:ids.map(id=>({id,name:strings.find(s=>s.name==='game_'+id+'_name').value,icon:'game_'+id,group:classic.includes(id)?'classic':collection.includes(id)?'collection':'expansion'}))};
  writeChanged(path.join(root,'docs/art/game-icon-manifest.json'),JSON.stringify(manifest,null,2)+'\n');
  for(const name of ['collection-art-manifest.json','expansion-art-manifest.json']) {
    const file=path.join(root,'docs/art',name);
    if(!fs.existsSync(file))continue;
    const art=JSON.parse(fs.readFileSync(file,'utf8'));
    art.iconGenerator=manifest.generator;
    for(const a of art.assets)if(a.name.startsWith('game_')){a.width=120;a.height=120;}
    writeChanged(file,JSON.stringify(art,null,2)+'\n');
  }
  console.log('Generated 100 unified game icons × 2 themes.');
}
if(require.main===module)generate();
module.exports={generate};
