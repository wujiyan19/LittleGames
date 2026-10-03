/* Original vector artwork. No fonts, external images, filters, or runtime downloads. */
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const catalog = fs.readFileSync(path.join(root, 'entry/src/main/ets/model/ExpansionCatalog.ets'), 'utf8');
const ids = [...catalog.matchAll(/\{ id: '([^']+)'/g)].map(m => m[1]);
const assets = new Map();
const groups = {
  sky: ['platformer', 'grapple', 'flappy', 'hillclimb'],
  water: ['fisheat', 'fishing'],
  space: ['shooter', 'survival', 'rhythm', 'beatjump', 'melody'],
  garden: ['differences', 'hiddenobjects', 'farm', 'linerescue'],
  wood: ['screwout', 'sokoban', 'yarn', 'sand', 'characters', 'idiom', 'xiangqi', 'bowling'],
  street: ['parkingjam', 'buscolor', 'runner', 'blackhole', 'drift'],
  felt: ['solitaire', 'spider', 'freecell', 'doudizhu', 'guandan', 'mahjong', 'billiards'],
  court: ['basketball', 'penalty', 'pingpong', 'airhockey', 'golf'],
  room: ['restaurant', 'decorate', 'roomdefense', 'fortress', 'tanks', 'backpack'],
};
const groupFor = id => Object.keys(groups).find(k => groups[k].includes(id)) || 'ceramic';
const rect = (x,y,w,h,r,fill,stroke='none',sw=1) => `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${r}" fill="${fill}" stroke="${stroke}" stroke-width="${sw}"/>`;
const circle = (x,y,r,fill,stroke='none',sw=1) => `<circle cx="${x}" cy="${y}" r="${r}" fill="${fill}" stroke="${stroke}" stroke-width="${sw}"/>`;
const ellipse = (x,y,rx,ry,fill,opacity=1) => `<ellipse cx="${x}" cy="${y}" rx="${rx}" ry="${ry}" fill="${fill}" opacity="${opacity}"/>`;
const line = (d,stroke,width=3,opacity=1) => `<path d="${d}" fill="none" stroke="${stroke}" stroke-width="${width}" stroke-linecap="round" stroke-linejoin="round" opacity="${opacity}"/>`;
const shape = (d,fill,stroke='none',sw=2) => `<path d="${d}" fill="${fill}" stroke="${stroke}" stroke-width="${sw}" stroke-linejoin="round"/>`;
const grad = (id,a,b) => `<linearGradient id="${id}" x2="0" y2="1"><stop stop-color="${a}"/><stop offset="1" stop-color="${b}"/></linearGradient>`;
function generate() {
  for (const theme of ['base', 'dark']) {
    const dark = theme === 'dark';
    const p = { ink:dark?'#DAE8FF':'#304A69', edge:dark?'#516884':'#9CB7D0', paper:dark?'#30445F':'#FFFAF0', low:dark?'#1C2B42':'#DCE8F1',
      wood:dark?'#6C4F3C':'#D5AC7C', sky:dark?'#142945':'#CAE8F6', blue:'#438ADF', coral:'#EB857C', gold:'#EABB63', mint:'#6CBFA4', violet:'#9988D3', cyan:'#66C2D5' };
    const colors = ['blue','coral','gold','mint','violet','cyan'];
    const defs = grad('paper',p.paper,p.low)+grad('blue','#9AD2F7','#397ACB')+grad('coral','#FFC0A5','#CF645F')+grad('gold','#FFE7AD','#D7A04A')+
      grad('mint','#B7EACD','#4D9E85')+grad('violet','#DCD2FA','#8470C2')+grad('cyan','#B8EDF1','#4AA3BF')+
      grad('wood',dark?'#9F7754':'#F0D1A2',p.wood)+grad('metal','#DBEAF2','#6386A8')+grad('ink','#62788E','#20364F')+grad('ivory','#FFF8E7','#C9D8E6');
    const bodyByName = new Map();
    const put = (name,body,w=100,h=100) => {
      const resource = 'exp_'+name;
      const dir=path.join(root,'entry/src/main/resources',theme,'media'); fs.mkdirSync(dir,{recursive:true});
      fs.writeFileSync(path.join(dir,resource+'.svg'),`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}"><defs>${defs}</defs>${body}</svg>\n`);
      assets.set(resource,{name:resource,width:w,height:h}); bodyByName.set(name,body);
    };
    const shadow = ellipse(50,87,32,6,'#122B45',.16);
    const bevel = (fill) => shadow+rect(6,12,88,78,18,p.edge)+rect(6,6,88,78,18,fill,p.edge,2)+line('M22 14H76','#FFFFFF',3,.5);
    const star = shape('M50 19L59 39L81 41L64 56L69 79L50 67L31 79L36 56L19 41L41 39Z','#FFF1C5');
    const symbols = [shape('M50 22L78 48L50 75L22 48Z','#F5FCFF'),circle(50,48,24,'#FFF5E5'),star,shape('M50 22L79 73H21Z','#EAFFF5'),
      shape('M50 74C8 49 22 19 42 32L50 40L58 32C78 19 92 49 50 74Z','#FFF0EE'),[0,60,120,180,240,300].map(a=>`<g transform="rotate(${a} 50 48)">${ellipse(50,29,8,15,'#F0FFFF')}</g>`).join('')+circle(50,48,9,'#E8CB7C')];
    colors.forEach((c,i)=>{
      put('tile_'+i,bevel('url(#'+c+')')+`<g transform="translate(10 10) scale(.8)">${symbols[i]}</g>`);
      put('bubble_'+i,circle(50,51,44,p.edge)+circle(50,47,42,'url(#'+c+')')+ellipse(37,27,17,9,'#FFFFFF',.65)+`<g transform="translate(23 20) scale(.54)">${symbols[i]}</g>`);
      put('block_'+i,bevel('url(#'+c+')')+rect(18,18,64,50,10,'none','#FFFFFF',2));
      put('bus_'+i,shadow+rect(8,22,84,50,15,'url(#'+c+')',p.ink,2)+rect(16,30,52,22,6,'#253E5B')+rect(73,30,10,31,4,'#DCF1F7')+line('M33 32V49M50 32V49','#B4DAEB',2)+circle(26,75,11,p.ink)+circle(74,75,11,p.ink)+circle(26,75,5,'#CADDE8')+circle(74,75,5,'#CADDE8'));
      put('car_'+i,shadow+rect(28,8,44,81,14,'url(#'+c+')',p.ink,2)+rect(34,27,32,17,7,'#254A6E')+rect(35,59,30,14,6,'#36546D')+line('M37 15H63','#FFFFFF',5,.8)+line('M22 27V43M78 27V43M22 60V77M78 60V77',p.ink,8));
      put('yarn_'+i,ellipse(50,55,45,29,'url(#'+c+')',1)+line('M12 50Q50 16 88 50M12 62Q50 28 88 62M22 76Q52 46 81 68','#FFFFFF',3,.45));
      put('reel_'+i,shadow+rect(24,20,52,60,7,'url(#'+c+')')+rect(13,13,74,15,6,'url(#wood)',p.edge,2)+rect(13,77,74,15,6,'url(#wood)',p.edge,2)+line('M26 35H74M26 44H74M26 53H74M26 62H74M26 71H74','#FFFFFF',3,.4));
      put('sand_'+i,bevel('url(#'+c+')')+Array.from({length:16},(_,j)=>circle(24+j%4*17,24+Math.floor(j/4)*15,2.5,'#FFFFFF')).join(''));
      put('nozzle_'+i,shadow+rect(24,12,52,44,12,'url(#'+c+')',p.ink,2)+shape('M33 56H67L60 82H40Z','url(#metal)',p.ink)+circle(50,30,10,'#FFFFFF')+circle(50,30,5,p[c]));
      put('fish_'+i,ellipse(51,49,32,25,'url(#'+c+')')+shape('M20 47L4 26V71Z',p[c])+shape('M47 24L62 12L69 29Z',p[c])+circle(67,40,8,'#FFFFFF')+circle(69,40,4,'#223951')+line('M61 59Q70 63 77 56',p.ink,2));
      put('person_'+i,shadow+rect(25,45,50,41,16,'url(#'+c+')')+circle(50,31,20,'#F5C7A6')+shape('M30 29Q23 4 48 7Q77 3 70 30L62 20H37Z','#3A536F')+circle(43,32,2,p.ink)+circle(57,32,2,p.ink)+line('M45 41Q50 45 55 41',p.ink,2));
      put('water_'+i,rect(0,0,100,30,0,'url(#'+c+')')+line('M0 5Q25 0 50 5T100 5','#FFFFFF',2,.65),100,30);
      put('sportball_'+i,shadow+circle(50,46,39,'url(#'+c+')',p.ink,2)+circle(50,46,16,'url(#paper)',p.edge,1)+ellipse(31,27,10,6,'#FFFFFF',.5));
    });
    put('tube',shape('M23 10H77V72Q77 94 50 94Q23 94 23 72Z','none',p.edge,4)+line('M29 18V68Q29 83 41 87','#FFFFFF',3,.55)+line('M19 10H81',p.edge,5));
    put('empty',rect(9,9,82,82,16,'none',p.edge,2));
    put('floor',rect(2,2,96,96,8,'url(#paper)',p.edge)+line('M7 24H93M7 72H93M30 3V23M70 25V72M30 74V97',p.edge,1,.4));
    put('wall',bevel('url(#metal)')+line('M10 36H90M10 61H90M32 12V35M65 37V60M34 62V82',p.ink,2,.35));
    put('crate',bevel('url(#wood)')+rect(19,19,62,55,3,'none','#876044',4)+line('M22 22L78 71M78 22L22 71','#A67349',8)+line('M26 23L78 68','#F7E0B6',2));
    put('goal',circle(50,50,38,'none',p.mint,5)+circle(50,50,24,'none',p.mint,3)+circle(50,50,7,p.mint));
    for(let direction=0;direction<4;direction++)put('arrow_'+direction,bevel('url(#blue)')+`<g transform="rotate(${direction*90} 50 50)">${line('M50 76V24M29 44L50 23L71 44','#F0FAFF',8)}</g>`);
    for(let mask=0;mask<16;mask++) {
      let pipe=bevel('url(#paper)');
      const ends=[[50,0],[100,50],[50,100],[0,50]];
      ends.forEach((end,i)=>{if(mask&(1<<i))pipe+=line(`M50 50L${end[0]} ${end[1]}`,p.edge,23)+line(`M50 50L${end[0]} ${end[1]}`,p.cyan,14);});
      put('pipe_'+mask,pipe+circle(50,50,13,'url(#metal)',p.edge,2)+circle(50,50,6,p.cyan));
    }
    put('robot',shadow+rect(21,28,58,51,17,'url(#blue)',p.ink,2)+rect(29,39,42,24,9,'#244965')+circle(40,50,5,'#BBFFFF')+circle(60,50,5,'#BBFFFF')+line('M50 28V18',p.ink,3)+circle(50,13,7,p.gold)+rect(15,70,16,18,6,'url(#metal)')+rect(69,70,16,18,6,'url(#metal)'));
    put('runner',shadow+circle(54,22,15,'#F5C7A6')+shape('M40 18Q36 3 56 5L70 12L41 23Z',p.blue)+shape('M43 35L64 38L61 62L38 58Z','url(#blue)',p.ink)+line('M40 43L24 55L14 41M62 42L78 51M43 60L25 80M57 63L77 84',p.ink,10)+line('M20 84H33M72 87H85',p.coral,8));
    put('coin',shadow+circle(50,47,36,'url(#gold)','#B07A38',3)+circle(50,47,26,'none','#FFF1BD',3)+shape('M50 25L57 40L73 42L61 53L64 69L50 61L36 69L39 53L27 42L43 40Z','#FFF1BD'));
    put('barrier',shadow+rect(10,24,80,39,6,'url(#coral)',p.ink,2)+shape('M16 24H30L15 63H10V41ZM50 24H65L50 63H35ZM85 24H90V45L83 63H68Z','#FFEBC9')+line('M24 67V88M77 67V88',p.ink,7));
    put('hole',ellipse(50,54,47,31,p.edge)+ellipse(50,49,43,26,'#17283C')+ellipse(50,50,32,16,'#070F1C')+line('M12 43Q48 20 86 44',p.cyan,4,.6));
    put('door',shadow+rect(17,9,66,81,12,'url(#wood)',p.ink,3)+rect(27,19,46,64,8,'#6E5146')+rect(34,29,30,27,3,'#B88968')+circle(65,62,4,p.gold));
    put('tower',shadow+rect(18,58,64,28,8,'url(#metal)',p.ink,2)+circle(50,54,24,'url(#blue)',p.ink,2)+rect(44,7,12,50,4,'url(#metal)',p.ink,2)+circle(50,56,10,p.gold));
    put('enemy',shadow+shape('M18 73V45Q18 14 50 14Q82 14 82 45V73L70 65L59 78L47 66L33 78Z','url(#coral)',p.ink)+ellipse(37,43,9,12,'#FFF1D7')+ellipse(63,43,9,12,'#FFF1D7')+circle(39,47,4,p.ink)+circle(61,47,4,p.ink)+line('M38 61H62',p.ink,3));
    put('hoop',rect(13,8,74,42,5,'url(#paper)',p.edge,2)+rect(33,19,34,23,2,'none',p.coral,3)+shape('M29 54L38 88H64L73 54Z','none',p.edge,2)+line('M30 54L64 88M45 54L72 70M72 54L38 88M58 54L31 68',p.edge,2)+ellipse(50,53,34,9,'none')+line('M16 53Q50 68 84 53Q50 40 16 53',p.coral,5));
    put('basketball',circle(50,50,43,'url(#coral)',p.ink,2)+line('M7 50H93M50 7V93M22 18Q76 48 22 82M78 18Q24 48 78 82',p.ink,3));
    put('note',bevel('url(#violet)')+ellipse(37,60,12,8,'#F6F0FF')+line('M48 60V28L69 34V50','#F6F0FF',5));
    put('screw',shadow+circle(50,45,37,'url(#metal)',p.ink,3)+circle(50,45,26,'none','#EAF7FF',2)+line('M33 45H67M50 28V62',p.ink,7));
    put('plate',bevel('url(#metal)')+circle(23,24,7,p.ink)+circle(77,24,7,p.ink)+circle(50,70,7,p.ink));
    put('platform',rect(2,20,96,65,8,'url(#wood)',p.ink,2)+rect(2,12,96,25,8,'url(#mint)',p.ink,2)+line('M16 50L30 65M50 49L64 64M79 50L89 60','#D9B487',3));
    put('anchor',circle(50,50,34,'url(#metal)',p.ink,3)+circle(50,50,17,'#244565')+line('M29 24L39 19','#F5FAFF',5));
    put('flag',ellipse(49,87,29,8,p.ink,.2)+line('M37 15V86',p.ink,5)+shape('M40 16H84L72 33L84 50H40Z','url(#mint)',p.ink));
    put('bird',shadow+ellipse(51,49,30,26,'url(#gold)')+ellipse(40,55,18,12,p.coral)+circle(64,41,10,'#FFFCF3')+circle(67,41,4,p.ink)+shape('M79 47L96 53L78 61Z',p.coral)+shape('M21 45L4 32L8 56L22 62Z',p.gold));
    put('bomb',shadow+circle(49,54,32,'url(#ink)',p.edge,2)+rect(43,16,16,12,4,p.edge)+line('M52 17Q53 5 69 9',p.gold,4)+line('M70 4V14M64 8L76 11',p.coral,3)+ellipse(36,43,9,5,'#AAC7DC',.65));
    put('plane',shadow+shape('M50 8L60 38L90 62V74L61 64L64 85L50 78L36 85L39 64L10 74V62L40 38Z','url(#blue)',p.ink)+ellipse(50,35,7,12,'#DBF5FF')+line('M45 88L50 97L55 88',p.gold,4));
    put('tank',shadow+rect(10,15,20,71,8,'url(#ink)')+rect(70,15,20,71,8,'url(#ink)')+rect(24,22,52,59,10,'url(#mint)',p.ink,2)+circle(50,48,18,'url(#metal)',p.ink,2)+rect(45,4,10,45,3,p.mint,p.ink,2));
    put('bullet',ellipse(50,61,14,30,'#C1E9FC',.45)+rect(43,15,14,55,7,'url(#gold)')+ellipse(50,27,4,11,'#FFFFFF'));
    put('ball',shadow+circle(50,46,37,'url(#blue)',p.ink,2)+ellipse(37,29,16,8,'#FFFFFF',.65));
    put('soccer',circle(50,50,43,'url(#paper)',p.edge,2)+shape('M50 29L70 43L62 66H38L30 43Z',p.ink)+line('M50 29V7M70 43L91 35M62 66L77 83M38 66L23 83M30 43L9 35',p.ink,4));
    put('pin',shadow+shape('M40 13Q50 5 60 13L59 34Q54 43 65 60Q83 88 50 91Q17 88 35 60Q46 43 41 34Z','url(#paper)',p.edge)+line('M42 31H58M42 39H58',p.coral,5));
    put('cueball',shadow+circle(50,46,39,'url(#ivory)',p.edge,2)+ellipse(34,28,12,7,'#FFFFFF',.65));
    put('bowlingball',bodyByName.get('ball')+circle(41,33,6,p.ink)+circle(57,32,6,p.ink)+circle(49,48,6,p.ink));
    put('gate',rect(15,3,70,94,0,'url(#mint)',p.ink,2)+rect(4,74,92,21,4,'url(#mint)',p.ink,2)+line('M26 9V69','#D5F6E2',4,.6));
    put('book',shadow+shape('M8 20Q31 8 50 24Q70 8 92 20V80Q70 69 50 85Q30 69 8 80Z','url(#paper)',p.edge)+line('M50 25V80M19 31H38M19 44H38M19 57H38M63 31H82M63 44H82M63 57H82',p.blue,3));
    put('brush',shadow+shape('M22 80Q8 94 12 66L31 44L47 60Z',p.ink)+shape('M31 43L63 7Q72 0 82 9Q89 17 79 27L46 61Z','url(#wood)',p.ink)+line('M34 45L49 58',p.gold,6));
    put('paddle',rect(3,27,94,39,12,'url(#coral)',p.ink,3)+line('M14 36H83','#FFE8D5',3,.6));
    put('puck',shadow+circle(50,47,38,'url(#ink)',p.edge,3)+circle(50,47,24,'none',p.cyan,3));
    put('striker',shadow+circle(50,57,41,'url(#blue)',p.ink,2)+ellipse(50,44,20,24,'url(#metal)',1)+ellipse(50,28,19,9,'#D9ECF5'));
    put('glove',shape('M17 57L10 32Q10 20 19 24L30 45L24 15Q25 6 33 10L42 37L40 8Q47 0 53 10L56 35L61 9Q69 4 73 13L73 43L82 26Q95 24 91 38L83 70Q70 94 45 88Z','url(#gold)',p.ink)+line('M30 59Q49 43 68 58',p.ink,3));
    const fruits = ['cherry','berry','grape','orange','apple','pear','peach','mango','melon','watermelon'];
    fruits.forEach((f,i)=>{
      let b=shadow;
      if(i===0) b+=circle(30,64,21,'url(#coral)',p.ink)+circle(69,64,21,'url(#coral)',p.ink)+line('M30 42Q31 10 56 15Q74 17 69 42',p.mint,5)+shape('M55 17Q73 1 87 17Q70 28 55 17Z',p.mint);
      else if(i===2) b+=[ [50,30],[32,43],[67,43],[30,62],[50,57],[68,63],[48,79] ].map(v=>circle(v[0],v[1],14,'url(#violet)',p.ink,1)).join('')+shape('M38 15Q58 3 70 15L51 24Z',p.mint);
      else {
        const c=['coral','coral','violet','gold','coral','mint','coral','gold','mint','mint'][i];
        b+=shape(i===5?'M44 17Q36 40 25 48Q7 86 50 90Q93 86 75 48Q62 40 58 17Z':i===1?'M19 32Q50 12 81 32Q85 53 50 88Q15 53 19 32Z':'M50 23Q10 8 11 52Q8 93 50 88Q92 93 89 52Q90 8 50 23Z','url(#'+c+')',p.ink);
        b+=line('M50 23V11','#715844',4)+shape('M53 17Q70 0 83 16Q70 29 53 17Z',p.mint)+ellipse(31,42,8,13,'#FFFFFF',.35);
        if(i===1)b+=[ [30,42],[53,41],[65,52],[44,58],[49,75] ].map(v=>ellipse(v[0],v[1],2,3,'#FFEBB4')).join('');
        if(i>=8)b+=line('M35 27Q19 58 36 84M51 27V85M66 26Q81 57 65 84','#347F6B',4,.7);
      }
      put('fruit_'+i,b);
    });
    const tree=rect(44,61,13,28,3,'url(#wood)')+circle(50,41,30,'url(#mint)',p.ink)+circle(32,54,21,'url(#mint)')+circle(70,52,22,'url(#mint)');
    const flower=line('M50 50V90',p.mint,5)+shape('M49 77Q18 62 23 80L48 87Z',p.mint)+[0,72,144,216,288].map(a=>`<g transform="rotate(${a} 50 40)">${ellipse(50,22,10,17,p.coral)}</g>`).join('')+circle(50,40,12,p.gold);
    const house=rect(20,42,62,45,5,'url(#wood)',p.ink,2)+shape('M10 45L50 11L92 45Z','url(#coral)',p.ink)+rect(45,61,17,26,3,p.ink)+rect(27,51,13,14,2,'#C7EFF4');
    const mushroom=rect(41,43,20,44,10,'url(#paper)',p.edge,2)+shape('M10 53Q12 7 50 9Q88 7 90 53Z','url(#coral)',p.ink)+circle(29,32,7,'#FFF1E1')+circle(64,23,8,'#FFF1E1')+circle(74,43,5,'#FFF1E1');
    const butterfly=ellipse(28,32,20,24,'url(#violet)')+ellipse(73,32,20,24,'url(#cyan)')+ellipse(30,69,18,20,'url(#cyan)')+ellipse(69,69,18,20,'url(#violet)')+line('M50 25V80',p.ink,8)+line('M50 24L38 9M50 24L62 9',p.ink,3);
    const cat=shadow+shape('M22 47V13L42 31H60L80 13V47Q89 78 51 85Q13 80 22 47Z','url(#gold)',p.ink)+circle(37,49,4,p.ink)+circle(65,49,4,p.ink)+shape('M46 60H56L51 66Z',p.coral)+line('M25 62L9 56M25 68L7 70M74 62L91 56M74 68L93 70',p.ink,2);
    [tree,flower,house,mushroom,tree+circle(29,44,8,p.coral)+circle(65,35,8,p.coral),butterfly,cat,bodyByName.get('bird'),shape('M50 9L85 44L50 79L15 44Z','url(#coral)',p.ink)+line('M50 79Q63 86 47 98',p.ink,2)].forEach((b,i)=>put('object_'+i,b));
    put('dog',shadow+ellipse(49,68,29,19,'url(#gold)')+circle(48,37,25,'url(#gold)',p.ink)+ellipse(22,36,10,23,'#855E47')+ellipse(74,36,10,23,'#855E47')+circle(39,34,3,p.ink)+circle(57,34,3,p.ink)+ellipse(49,49,13,9,'#FFEDD0')+circle(49,46,4,p.ink));
    put('bee',ellipse(30,30,19,14,'#D6EEFA',.8)+ellipse(68,28,19,14,'#D6EEFA',.8)+ellipse(50,53,33,24,'url(#gold)')+line('M38 32V74M55 31V76',p.ink,8)+circle(74,45,3,p.ink)+shape('M18 53L4 60L20 64Z',p.ink));
    put('soil',bevel('url(#wood)')+line('M19 32H81M19 47H81M19 62H81','#8D6348',5));
    put('seedling',bodyByName.get('soil')+line('M50 70V39',p.mint,5)+shape('M48 51Q16 21 16 44Q20 58 48 51Z','url(#mint)')+shape('M52 44Q83 11 86 36Q79 50 52 44Z','url(#mint)'));
    put('watered',bodyByName.get('seedling')+shape('M75 58Q50 83 75 87Q96 83 75 58Z','url(#cyan)'));
    put('crop',bodyByName.get('soil')+line('M50 76V19M36 28L50 37L65 26M31 43L50 54L70 41M32 58L50 67L69 56',p.gold,9)+line('M50 17V77','#8B763D',2));
    put('sofa',shadow+rect(12,33,76,49,13,'url(#violet)',p.ink,2)+rect(20,20,60,42,13,'url(#violet)',p.ink,2)+rect(8,47,17,33,7,'url(#violet)',p.ink,2)+rect(75,47,17,33,7,'url(#violet)',p.ink,2)+line('M27 66H73M29 87V92M72 87V92',p.ink,3));
    put('table',shadow+line('M23 52V89M77 52V89',p.ink,8)+ellipse(50,44,43,20,'url(#wood)',1)+ellipse(50,40,43,17,'#EBCB99',1));
    put('plant',shape('M29 60H74L66 90H37Z','url(#coral)',p.ink)+line('M51 66V19',p.mint,5)+shape('M50 43Q15 5 13 34Q14 52 50 43Z','url(#mint)')+shape('M51 36Q85 0 88 26Q87 46 51 36Z','url(#mint)'));
    put('lamp',shadow+line('M50 44V82',p.ink,7)+ellipse(50,85,27,6,'url(#metal)')+shape('M32 9H68L84 49H16Z','url(#gold)',p.ink));
    put('bobber',line('M50 8V29',p.ink,2)+ellipse(50,54,21,28,'url(#paper)')+shape('M29 54Q29 82 50 82Q71 82 71 54Z',p.coral)+line('M22 85Q50 96 78 85',p.cyan,3));
    put('bite',circle(50,50,42,'url(#gold)',p.ink,2)+line('M50 25V56',p.ink,9)+circle(50,73,5,p.ink));
    put('sword',shadow+shape('M64 7L84 11L49 65L32 55Z','url(#metal)',p.ink)+line('M24 52L57 74',p.gold,8)+line('M34 66L20 85',p.ink,9));
    put('shield',shadow+shape('M50 8L84 23L78 65L50 91L22 65L16 23Z','url(#blue)',p.ink)+shape('M50 23L66 32L62 57L50 70L38 57L34 32Z','none','#D9EEFF',3));
    put('potion',shadow+rect(38,8,24,18,4,'url(#wood)',p.ink)+shape('M38 24H62V40Q90 55 80 79Q70 94 49 91Q20 90 18 69Q14 53 38 40Z','url(#coral)',p.ink)+line('M39 61H62M50 50V72','#FFF1DA',6));
    put('boots',shadow+shape('M27 12H60V58L82 66Q96 87 71 89H23V47Z','url(#wood)',p.ink)+line('M34 25H54M34 37H54M34 49H54','#FFF1D8',4));
    put('food_0',shadow+shape('M14 78Q13 66 41 23Q50 10 60 23Q88 66 88 78Z','url(#paper)',p.edge)+rect(36,53,28,35,4,p.ink));
    put('food_1',shadow+shape('M12 53H88Q81 90 50 92Q19 90 12 53Z','url(#coral)',p.ink)+ellipse(50,51,38,12,'#EDC785')+line('M25 48Q35 35 45 48T70 47M31 53Q42 38 53 51',p.paper,4)+line('M68 8L63 42M82 10L73 42',p.wood,4));
    put('food_2',shadow+line('M22 89L77 11',p.wood,5)+[ [31,72],[49,48],[67,25] ].map((v,i)=>circle(v[0],v[1],14,'url(#'+colors[i]+')',p.ink)).join(''));
    put('card_front',rect(3,5,94,124,10,p.edge)+rect(3,1,94,124,10,'url(#paper)',p.edge,2)+rect(11,10,78,105,7,'none',p.edge),100,132);
    put('card_back',rect(3,5,94,124,10,p.edge)+rect(3,1,94,124,10,'url(#blue)',p.edge,2)+rect(12,10,76,105,7,'none','#D8EEFF',2)+`<g transform="translate(1 16)">${star}</g>`+line('M18 22L82 102M82 22L18 102','#DBEEFF',2,.3),100,132);
    put('mahjong',rect(3,9,94,119,10,'url(#mint)',p.ink,2)+rect(3,1,94,118,10,'url(#paper)',p.edge,2)+rect(11,10,78,98,7,'none',p.edge),100,132);
    put('chip',shadow+circle(50,47,38,'url(#wood)',p.ink,2)+circle(50,47,29,'url(#paper)',p.wood,2));
    for (const side of [0,1]) {
      const fill=side===0?'url(#ivory)':'url(#ink)', edge=side===0?p.edge:'#A1B6CB';
      const tops=[line('M50 5V25M42 14H58',edge,6)+shape('M28 30L34 49H66L72 30Z',fill,edge),shape('M20 24L28 49H72L80 24L61 35L50 17L39 35Z',fill,edge),
        shape('M22 14H35V27H44V14H56V27H65V14H78V43H22Z',fill,edge),shape('M50 11Q23 33 39 49H61Q77 33 50 11Z',fill,edge)+line('M50 18L40 37',edge,4),
        shape('M32 52L25 36L39 14L61 11L72 29L59 37L52 31L48 51Z',fill,edge)+circle(56,24,3,edge),circle(50,29,17,fill,edge,2)];
      tops.forEach((top,i)=>put('chess_'+side+'_'+i,shadow+shape('M37 48H63L68 76H32Z',fill,edge)+rect(23,76,54,13,5,fill,edge,2)+top));
    }
    put('spark',star+circle(15,20,5,p.cyan)+circle(84,77,4,p.coral)+line('M82 12V28M74 20H90',p.gold,3));
    put('ripple',circle(50,50,39,'none',p.cyan,3)+circle(50,50,27,'none',p.blue,2));
    put('trophy',shadow+shape('M25 13H75V41Q72 63 50 67Q28 63 25 41Z','url(#gold)','#B38542')+line('M25 20H10Q5 52 34 50M75 20H90Q95 52 66 50','#D5A455',6)+rect(45,65,10,17,2,'url(#gold)')+rect(29,82,42,9,4,'url(#gold)')+`<g transform="translate(28 13) scale(.44)">${star}</g>`);
    const heroFor = {
      blockfit:'block_0',tilestack:'tile_2',bubbleshooter:'bubble_0',fruitmerge:'fruit_9',watersort:'tube',arrowclear:'flag',screwout:'screw',parkingjam:'car_1',runner:'runner',blackhole:'hole',fisheat:'fish_0',sokoban:'crate',pipes:'pipe_3',differences:'object_2',roomdefense:'tower',basketball:'basketball',solitaire:'card_back',characters:'floor',rhythm:'note',restaurant:'food_1',linktiles:'tile_1',mahjongsolitaire:'mahjong',groupclear:'block_3',slotpair:'tile_4',buscolor:'bus_0',yarn:'reel_4',sand:'nozzle_2',untangle:'anchor',platformer:'robot',grapple:'robot',flappy:'bird',fruitslice:'fruit_4',rollingball:'ball',shooter:'plane',tanks:'tank',fortress:'tower',survival:'enemy',backpack:'shield',billiards:'ball',penalty:'soccer',pingpong:'paddle',bowling:'pin',golf:'flag',drift:'car_0',hillclimb:'car_3',airhockey:'striker',tug:'person_1',dots:'tile_0',doudizhu:'card_front',guandan:'card_front',mahjong:'mahjong',xiangqi:'chip',chess:'chess_0_1',ludo:'plane',spider:'card_back',freecell:'card_front',onestroke:'anchor',hiddenobjects:'object_6',linerescue:'dog',picturepuzzle:'object_2',idiom:'floor',wordtower:'tower',beatjump:'ball',melody:'note',farm:'crop',decorate:'sofa',fishing:'fish_3'
    };
    const surface={sky:p.sky,water:dark?'#17394B':'#A5D9E8',space:dark?'#14223C':'#D7E0F1',garden:dark?'#26483F':'#D2E9C8',wood:dark?'#44362E':'#ECDAC0',street:dark?'#253348':'#DFE7EC',felt:dark?'#20453F':'#BEDFD3',court:dark?'#284A54':'#AED1D9',room:dark?'#303B4E':'#F2E4D2',ceramic:p.low};
    ids.forEach(id=>{
      const family=groupFor(id); let bg=rect(0,0,360,460,0,surface[family]);
      if(family==='sky')bg+=circle(290,65,28,dark?'#BCD5E9':'#FFE1A1')+line('M30 75H110M185 105H250',dark?'#3F5871':'#F6FCFF',17)+shape('M0 300L65 220L145 290L240 180L360 275V460H0Z',dark?'#254D58':'#8DBBA9')+shape('M0 355Q130 260 360 340V460H0Z',dark?'#346567':'#6C9C8C');
      if(family==='water')bg+=Array.from({length:8},(_,i)=>line(`M0 ${40+i*51}Q70 ${19+i*51} 140 ${40+i*51}T280 ${40+i*51}T420 ${40+i*51}`,dark?'#30708A':'#DBF6FA',2,.6)).join('')+shape('M0 420Q100 390 180 435Q280 398 360 416V460H0Z',dark?'#48776A':'#9DD0AF');
      if(family==='space')bg+=Array.from({length:27},(_,i)=>circle(13+i*71%336,19+i*53%408,i%3===0?2:1,dark?'#ABC9EA':'#7F9CC1')).join('')+circle(312,80,27,'none','#637A9D',2)+line('M275 95L346 61','#637A9D',2);
      if(family==='garden')bg+=circle(302,48,24,dark?'#BAD3CD':'#FFE4A0')+line('M12 410Q80 389 167 411T348 410',dark?'#406858':'#A1C7A5',8)+Array.from({length:12},(_,i)=>circle(14+i*29,443-i%3*9,3,i%2?p.coral:p.gold)).join('');
      if(['wood','room'].includes(family)) bg+=Array.from({length:8},(_,i)=>line(`M0 ${40+i*57}H360`,dark?'#614D42':'#CDB798',2,.25)).join('');
      if(family==='ceramic')bg+=Array.from({length:35},(_,i)=>circle(16+i%5*81,17+Math.floor(i/5)*68,2,p.edge)).join('');
      if(family==='felt')bg+=rect(9,9,342,442,20,'none',dark?'#4D736A':'#97BCA1',4)+Array.from({length:18},(_,i)=>line(`M20 ${25+i*23}H340`,dark?'#28534A':'#639D8C',1)).join('');
      if(family==='street')bg+=Array.from({length:10},(_,i)=>line(`M0 ${20+i*49}H360`,p.edge,1,.22)).join('');
      if(id==='runner') bg+=rect(25,0,310,460,0,dark?'#263E54':'#B6CBD7')+line('M128 0V460M232 0V460','#EDF1DC',2,.7);
      if(id==='basketball')bg=rect(0,0,360,460,0,dark?'#604935':'#E6BC89')+line('M0 230H360M180 0V460','#F8E6C9',2,.75)+circle(180,230,48,'none','#F8E6C9',2)+rect(35,15,290,87,0,'none','#F8E6C9',2)+rect(35,358,290,87,0,'none','#F8E6C9',2);
      if(id==='bowling')bg+=line('M42 0V460M318 0V460',p.ink,5)+Array.from({length:7},(_,i)=>line(`M${70+i*36} 0V460`,p.edge,1,.3)).join('');
      if(id==='penalty') bg=rect(0,0,360,460,0,dark?'#284F44':'#83B896')+Array.from({length:8},(_,i)=>rect(0,i*60,360,30,0,dark?'#2D584A':'#92C3A1')).join('')+rect(30,28,300,67,4,'none','#EFF6E8',3)+line('M30 48H330M30 69H330M60 28V95M90 28V95M120 28V95M150 28V95M180 28V95M210 28V95M240 28V95M270 28V95M300 28V95','#DCEBD7',1)+circle(180,280,43,'none','#EFF6E8',2);
      if(['pingpong','airhockey'].includes(id))bg+=rect(16,12,328,436,7,'none','#D9F0F2',3)+line('M16 230H344M180 12V448','#D9F0F2',2)+circle(180,230,id==='airhockey'?50:1,'none','#D9F0F2',2);
      if(id==='golf')bg=rect(0,0,360,460,0,dark?'#2A5544':'#91C79F')+rect(10,10,340,440,17,'none',dark?'#537B53':'#CBE0A6',8);
      if(id==='ludo')bg=rect(0,0,360,460,0,p.low)+[ [20,15],[244,15],[244,355],[20,355] ].map((v,i)=>rect(v[0],v[1],94,96,14,'url(#'+colors[i]+')')).join('')+Array.from({length:52},(_,i)=>circle(180+Math.cos(i*Math.PI*2/52-Math.PI/2)*140,230+Math.sin(i*Math.PI*2/52-Math.PI/2)*175,6,'url(#paper)',p.edge,1)).join('')+`<g transform="translate(130 180)">${star}</g>`;
      // Low contrast backdrop: game geometry and text remain native and visible above it.
      const hero=id==='arrowclear'?'arrow_1':id==='characters'?'brush':id==='idiom'?'book':heroFor[id]; if(!hero||!bodyByName.has(hero))throw new Error('Missing hero for '+id);
      put('board_'+id,bg+`<g opacity=".06" transform="translate(246 351) scale(.9)">${bodyByName.get(hero)}</g>`,360,460);

    });
    // Puzzle art is opaque and readable in both modes, with the same shapes and crop boundaries.
    const original=fs.readFileSync(path.join(root,'entry/src/main/resources/base/media/expansion_puzzle_scene.svg'),'utf8');
    if(dark)fs.writeFileSync(path.join(root,'entry/src/main/resources/dark/media/expansion_puzzle_scene.svg'),original.replaceAll('#C9E8F4','#24445F').replaceAll('#83BCA1','#417567').replaceAll('#4F987F','#2D6255').replaceAll('#F3D3A5','#B48D68').replaceAll('#FFFFFF','#B9D6E7'));
  }
  const method=(name,prefix,count)=>`  static ${name}(value: number): Resource {\n    const images: Resource[] = [${Array.from({length:count},(_,i)=>`$r('app.media.exp_${prefix}_${i}')`).join(', ')}];\n    return images[Math.max(0, Math.min(${count-1}, Math.floor(value)))];\n  }`;
  const methods=[method('sportBall','sportball',6),method('water','water',6),method('arrow','arrow',4),method('pipe','pipe',16),method('tile','tile',6),method('block','block',6),method('bubble','bubble',6),method('fruit','fruit',10),method('object','object',9),method('fish','fish',6),method('bus','bus',6),method('car','car',6),method('yarn','yarn',6),method('reel','reel',6),method('sand','sand',6),method('nozzle','nozzle',6),method('person','person',6),method('food','food',3)];
  const source=`/** Generated resource selectors; see scripts/generate-expansion-art.cjs. */\nimport { ExpansionPiece } from '../model/game/ExpansionState';\n\nexport class ExpansionArt {\n  static board(id: string): Resource {\n${ids.map(id=>`    if (id === '${id}') { return $r('app.media.exp_board_${id}'); }`).join('\n')}\n    return $r('app.media.exp_board_blockfit');\n  }\n${methods.join('\n')}\n  static chess(piece: number): Resource {\n    const light: Resource[] = [${Array.from({length:6},(_,i)=>`$r('app.media.exp_chess_0_${i}')`).join(', ')}];\n    const dark: Resource[] = [${Array.from({length:6},(_,i)=>`$r('app.media.exp_chess_1_${i}')`).join(', ')}];\n    return (piece > 10 ? dark : light)[Math.max(0, Math.min(5, piece % 10 - 1))];\n  }\n  static farm(value: number): Resource {\n    const images: Resource[] = [$r('app.media.exp_soil'), $r('app.media.exp_seedling'), $r('app.media.exp_watered'), $r('app.media.exp_crop')];\n    return images[Math.max(0, Math.min(3, value))];\n  }\n  static furniture(value: number): Resource {\n    const images: Resource[] = [$r('app.media.exp_floor'), $r('app.media.exp_sofa'), $r('app.media.exp_table'), $r('app.media.exp_plant'), $r('app.media.exp_lamp')];\n    return images[Math.max(0, Math.min(4, value))];\n  }\n  static equipment(value: number): Resource {\n    const images: Resource[] = [$r('app.media.exp_sword'), $r('app.media.exp_shield'), $r('app.media.exp_potion'), $r('app.media.exp_boots')];\n    return images[Math.max(0, Math.min(3, value))];\n  }\n  static piece(id: string, p: ExpansionPiece): Resource {\n    if (id === 'fruitmerge') { return ExpansionArt.fruit(p.color); }\n    if (id === 'fisheat') { return ExpansionArt.fish(p.kind === 10 ? 0 : (p.color + 1) % 6); }\n    if (id === 'bubbleshooter') { return ExpansionArt.bubble(p.color - 1); }\n    if (p.kind === 6) { return $r('app.media.exp_runner'); }\n    if (p.kind === 7) { return p.color === 1 ? $r('app.media.exp_coin') : $r('app.media.exp_barrier'); }\n    if (p.kind === 8 || p.kind === 42) { return $r('app.media.exp_hole'); }\n    if (p.kind === 9) { return ExpansionArt.object((p.color - 1) % 6); }\n    if (p.kind === 13) { return $r('app.media.exp_door'); }\n    if (p.kind === 14) { return $r('app.media.exp_tower'); }\n    if (p.kind === 15 || p.kind === 56) { return id === 'linerescue' ? $r('app.media.exp_bee') : $r('app.media.exp_enemy'); }\n    if (p.kind === 16) { return $r('app.media.exp_hoop'); }\n    if (p.kind === 17) { return $r('app.media.exp_basketball'); }\n    if (p.kind === 18) { return $r('app.media.exp_note'); }\n    if (p.kind === 24) { return id === 'shooter' ? $r('app.media.exp_plane') : id === 'tanks' ? $r('app.media.exp_tank') : id === 'fortress' ? $r('app.media.exp_tower') : id === 'flappy' ? $r('app.media.exp_bird') : $r('app.media.exp_robot'); }\n    if (p.kind === 25 || p.kind === 26) { return $r('app.media.exp_platform'); }\n    if (p.kind === 27 || p.kind === 43) { return $r('app.media.exp_flag'); }\n    if (p.kind === 28) { return $r('app.media.exp_anchor'); }\n    if (p.kind === 30) { return ExpansionArt.fruit([0, 3, 4, 5, 6, 1][Math.max(0, (p.color - 1) % 6)]); }\n    if (p.kind === 31) { return $r('app.media.exp_bomb'); }\n    if (p.kind === 58) { return $r('app.media.exp_ball'); }
    if (p.kind === 32 && (id === 'billiards' || id === 'golf')) { return p.color === 1 || id === 'golf' ? $r('app.media.exp_cueball') : ExpansionArt.sportBall(p.color - 2); }
    if (p.kind === 32 && id === 'bowling') { return $r('app.media.exp_bowlingball'); }
    if (p.kind === 32) { return id === 'penalty' ? $r('app.media.exp_soccer') : id === 'airhockey' ? $r('app.media.exp_puck') : $r('app.media.exp_ball'); }\n    if (p.kind === 33) { return id === 'tanks' ? $r('app.media.exp_tank') : $r('app.media.exp_enemy'); }\n    if (p.kind === 34) { return $r('app.media.exp_bullet'); }\n    if (p.kind === 36) { return ExpansionArt.car(id === 'drift' ? 0 : 3); }\n    if (p.kind === 37) { return $r('app.media.exp_pin'); }\n    if (p.kind === 39) { return id === 'airhockey' ? $r('app.media.exp_striker') : $r('app.media.exp_paddle'); }\n    if (p.kind === 44) { return $r('app.media.exp_glove'); }\n    if (p.kind === 55) { return $r('app.media.exp_dog'); }\n    return ExpansionArt.tile(Math.max(0, p.color - 1) % 6);\n  }\n}\n`;
  fs.writeFileSync(path.join(root,'entry/src/main/ets/common/ExpansionArt.ets'),source);
  const strings=JSON.parse(fs.readFileSync(path.join(root,'entry/src/main/resources/zh_CN/element/string.json'))).string;
  const games=ids.map(id=>({id,name:strings.find(s=>s.name==='game_'+id+'_name').value,icon:'game_'+id,board:'exp_board_'+id,family:groupFor(id)}));
  const out=path.join(root,'docs/art');fs.mkdirSync(out,{recursive:true});
  fs.writeFileSync(path.join(out,'expansion-art-manifest.json'),JSON.stringify({generator:'scripts/generate-expansion-art.cjs',themes:['base','dark'],games,assets:[...assets.values()]},null,2)+'\n');
  require('./generate-game-icons.cjs').generate();
  console.log(`Generated ${assets.size} gameplay resources × 2 themes; icons use the shared 100-game system.`);
}
if(require.main===module)generate();
module.exports={generate};
