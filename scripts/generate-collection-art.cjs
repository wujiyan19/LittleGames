/* First-party vector game art. Basic SVG geometry only: no fonts, filters, masks,
 * external images or game-brand assets. Shared materials, game-specific silhouettes.
 * Run with Node; source of truth for Collection gameplay materials; icons use generate-game-icons.cjs. */
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const ids = ['tictactoe','gomoku','reversi','fourline','nim','lights','flood','maze','hanoi','peg',
  'nonogram','arithmetic','compare','sequence','binary','targetsum','schulte','memorysequence','missing','reaction'];
const labels = ['井字棋','五子棋','翻转棋','落子四连','取石子','十字熄灯','色块归一','迷宫寻路','汉诺塔','跳子独留',
  '数字绘格','心算十题','算式比大小','数列推演','二进制解码','补数求和','数字寻序','顺序记忆','记忆缺项','信号反应'];
const assets = new Map();
const rect = (x,y,w,h,r,fill,stroke='none',sw=2) => `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${r}" fill="${fill}" stroke="${stroke}" stroke-width="${sw}"/>`;
const circle = (x,y,r,fill,stroke='none',sw=2) => `<circle cx="${x}" cy="${y}" r="${r}" fill="${fill}" stroke="${stroke}" stroke-width="${sw}"/>`;
const line = (d,color,width=3,opacity=1) => `<path d="${d}" fill="none" stroke="${color}" stroke-width="${width}" opacity="${opacity}" stroke-linecap="round" stroke-linejoin="round"/>`;
const group = (body,x=0,y=0,scale=1,rotate=0) => `<g transform="translate(${x} ${y}) scale(${scale}) rotate(${rotate})">${body}</g>`;
const grad = (id,a,b) => `<linearGradient id="${id}" x1="0" y1="0" x2=".25" y2="1"><stop offset="0" stop-color="${a}"/><stop offset="1" stop-color="${b}"/></linearGradient>`;
const ellipse = (x,y,rx,ry,color,opacity=1) => `<ellipse cx="${x}" cy="${y}" rx="${rx}" ry="${ry}" fill="${color}" opacity="${opacity}"/>`;
const save = (theme,name,w,h,body,defs) => {
  const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}"><defs>${defs}</defs>${body}</svg>\n`;
  const dest=path.join(root,'entry/src/main/resources',theme,'media');fs.mkdirSync(dest,{recursive:true});fs.writeFileSync(path.join(dest,name+'.svg'),svg);
  if(theme==='base')assets.set(name,{name,width:w,height:h});
};

for(const theme of ['base','dark']) {
  const dark=theme==='dark';
  const p={ink:dark?'#DAE8FF':'#263E60',edge:dark?'#536680':'#A8BCD6',paper:dark?'#253751':'#F4F8FF',
    paperLow:dark?'#1B2C43':'#DDE8F8',wood:dark?'#96704E':'#E6BD83',woodLow:dark?'#674D39':'#B37E4C',
    woodEdge:dark?'#B38D63':'#8C5D3B',woodInset:dark?'#684F3D':'#ECCE9D',navy:'#203E69',blue:'#397DE0',
    cyan:'#67CDE0',gold:'#F0BB65',coral:'#EF8979',mint:'#76C4AD',white:'#FFF7E8'};
  const defs=grad('paper',p.paper,p.paperLow)+grad('wood',p.wood,p.woodLow)+grad('blue','#7BBFF3','#3974CD')+
    grad('coral','#FFB79B','#D36663')+grad('gold','#FFE3A0','#D69A4B')+grad('mint','#AAE2C9','#58A891')+
    grad('violet','#CBC0F6','#8574C2')+grad('darkstone','#64748E','#1C2D46')+grad('whitestone','#FFFDF3','#C5D6E5')+
    grad('jade',dark?'#285D58':'#5B9B84',dark?'#1B3D41':'#367460')+grad('night','#365983','#182C49')+
    grad('glow','#FFF5CA','#F1C16D')+grad('tile',dark?'#304D70':'#EBF4FF',dark?'#1D314B':'#CCDDF2');
  const put=(name,w,h,body)=>save(theme,name,w,h,body,defs);
  const bevel=(w,h,fill,edge=p.edge,r=16)=>rect(3,8,w-6,h-10,r,edge)+rect(3,2,w-6,h-10,r,fill,edge)+
    line(`M${r+5} 10H${w-r-6}`, '#FFFFFF',3,.45);
  const grain=(w,h)=>Array.from({length:6},(_,i)=>line(`M14 ${22+i*(h-40)/6}Q${w*.32} ${12+i*(h-40)/6} ${w*.55} ${23+i*(h-40)/6}T${w-14} ${20+i*(h-40)/6}`,p.woodEdge,1,.16)).join('');
  const frame=(fill,edge=p.edge)=>bevel(400,400,fill,edge,24)+rect(15,14,370,370,17,'none',edge,2);
  const disc=(color)=>ellipse(50,82,37,9,'#132B4C',.22)+circle(50,47,38,'url(#'+color+')',color==='whitestone'?'#9BACBE':'#344C6B',2)+
    ellipse(38,31,15,7,'#FFFFFF',color==='darkstone'?.18:.48)+line('M26 69Q50 85 74 68','#183352',2,.15);
  const cross=line('M29 27L73 71M73 27L29 71','#244C87',17)+line('M29 23L73 67M73 23L29 67','#72B1F0',13)+line('M29 21L46 38','#CEE8FF',3,.8);
  const ring=circle(50,51,27,'none','#AF5A59',15)+circle(50,47,27,'none','#F59A86',13)+line('M29 32Q38 20 53 22','#FFE5C9',3,.8);
  const gem=(color)=>ellipse(50,85,31,7,'#162B45',.18)+`<path d="M26 18L74 18L89 40L50 80L11 40Z" fill="url(#${color})" stroke="#395575" stroke-width="2"/>`+
    line('M26 18L34 40H66L74 18M11 40H89M34 40L50 80L66 40','#FFFFFF',2,.47);
  const stone=ellipse(50,83,34,8,'#24354E',.2)+`<path d="M18 42Q20 17 48 16Q79 16 84 47Q91 75 60 79Q27 85 17 65Z" fill="url(#blue)" stroke="#3566A0" stroke-width="2"/>`+
    line('M29 32Q43 21 62 27','#D9F1FF',6,.7)+circle(66,58,4,'#A7D2F3');
  const peg=ellipse(50,82,32,9,'#32251F',.25)+rect(28,43,44,34,17,'url(#gold)','#9E6C42')+
    ellipse(50,43,24,17,'#EDC788')+ellipse(43,37,12,5,'#FFF2CD',.7)+line('M28 48V60','#FFF0C3',2,.5);
  const robot=ellipse(50,87,28,7,'#183845',.24)+rect(21,29,58,49,18,'url(#blue)','#315E8B',3)+
    rect(29,42,42,21,10,'#193B60')+circle(40,52,4,'#D9FFFF')+circle(60,52,4,'#D9FFFF')+
    line('M50 29V19','#456D91',4)+circle(50,15,7,'#FFD68E')+rect(16,71,15,15,5,'#C1D8EB')+rect(69,71,15,15,5,'#C1D8EB');
  const portal=ellipse(50,83,35,8,'#285C66',.22)+rect(21,14,58,71,23,'url(#mint)','#3E7F79',3)+
    rect(32,27,36,55,15,'#246175')+line('M50 39V65M40 55L50 65L60 55','#C5FFEE',5)+circle(70,20,5,'#FFF0B7');
  const lamp=(on)=>bevel(100,100,on?'url(#glow)':'url(#night)',on?'#AD8450':'#172D48',18)+
    circle(50,46,25,on?'#FFF1B3':'#36536F',on?'#E3AB58':'#6B89A4',2)+
    line('M38 39Q50 27 62 39M40 61H60M44 67H56',on?'#C98B3E':'#7E9DB6',4)+
    circle(50,46,11,on?'#FFFDE6':'#27455F');
  const hole=ellipse(50,54,37,32,'#B88B58')+ellipse(50,51,32,27,dark?'#243032':'#514D41')+line('M20 60Q47 91 80 60','#F2CD91',3,.6);
  const pill=(color)=>bevel(100,100,'url(#'+color+')','#617DA1',19)+rect(13,14,74,66,12,'none','#FFFFFF',2);
  const card=(back)=>bevel(100,120,back?'url(#violet)':'url(#paper)',back?'#655893':p.edge,15)+
    rect(12,12,76,91,10,'none',back?'#E4DCFF':p.edge,2)+
    (back?`<path d="M50 27L60 46L80 56L60 66L50 86L40 66L20 56L40 46Z" fill="#F0E9FF"/>`+circle(50,56,9,'#B1A0E4'):line('M18 25V19H26M82 91V99H74',p.blue,3));
  const chip=(color)=>disc(color)+circle(50,47,23,'none','#FFFFFF',2);
  const lantern=(phase)=>{
    const color=phase===2?'mint':phase===1?'gold':'blue';
    return ellipse(50,88,39,8,'#122A47',.24)+bevel(100,100,'url(#night)','#142C49',22)+
      circle(50,46,33,'#152C45','#6486A9',3)+circle(50,46,25,'url(#'+color+')')+
      (phase===2?line('M35 46L46 57L65 34','#F4FFED',6):phase===1?line('M50 29V47L61 54','#654624',5):`<path d="M43 32L64 46L43 60Z" fill="#EFF7FF"/>`)+
      [30,50,70].map((x,i)=>rect(x-6,84,12,4,2,i===phase?'#C4F5DE':'#4D6B8B')).join('');
  };
  const pieces={stone_dark:disc('darkstone'),stone_light:disc('whitestone'),cross,ring,chip_blue:chip('blue'),chip_coral:chip('coral'),
    stone,peg,robot,portal,light_on:lamp(true),light_off:lamp(false),peg_hole:hole};
  for(const [name,body] of Object.entries(pieces))put('col_'+name,100,100,body);
  for(const color of ['blue','mint','gold','coral','violet'])put('col_gem_'+color,100,100,gem(color));
  ['blue','mint','gold','coral'].forEach((c,i)=>put('col_flood_'+i,100,100,pill(c)));
  put('col_card_front',100,120,card(false));put('col_card_back',100,120,card(true));
  put('col_ceramic_cell',100,100,bevel(100,100,'url(#tile)',p.edge,14));
  put('col_paper_cell',100,100,rect(1,1,98,98,6,p.paper,p.edge,2)+line('M9 14H34',p.edge,2,.6));
  put('col_ink_cell',100,100,rect(1,1,98,98,6,dark?'#789EE1':'#4878C2',p.edge,2)+line('M16 77L73 20M32 85L84 33','#BBD7FF',4,.3));
  put('col_go_cell',100,100,line('M0 50H100M50 0V100',p.woodEdge,2));
  put('col_jade_cell',100,100,rect(1,1,98,98,5,'none',dark?'#3A7068':'#8BC0A3',2));
  put('col_drop_hole',100,100,circle(50,50,42,dark?'#182F4D':'#265795','#6EAAF0',3)+circle(50,54,33,dark?'#13263F':'#164170'));
  put('col_path',100,100,rect(0,0,100,100,5,dark?'#36494D':'#E1E4C7')+
    line('M18 32L36 25M59 79L72 73',dark?'#526665':'#BDCAA7',3));
  put('col_wall',100,100,rect(0,6,100,94,9,dark?'#243C3D':'#3C7065')+
    rect(2,2,96,85,13,dark?'#3D6961':'#7FAE8D',dark?'#294E47':'#68947A',2)+
    line('M11 24Q30 6 49 23M55 68Q77 49 88 64',dark?'#547E70':'#ADD0A2',5,.7));
  put('col_table_board',400,400,frame('url(#wood)',p.woodEdge)+grain(400,400));
  put('col_jade_board',400,400,frame('url(#jade)',dark?'#387062':'#2F665C'));
  put('col_blue_board',400,400,frame('url(#blue)','#2B5896'));
  put('col_ceramic_board',400,400,frame('url(#paper)'));
  put('col_garden_board',400,400,frame(dark?'#283F43':'#C3D5B6',dark?'#426358':'#7B9F83'));
  put('col_night_board',400,400,frame('url(#night)','#59789D')+
    line('M12 74H23V116M386 290H376V330','#729AB8',3,.5));
  put('col_paper_board',400,400,frame('url(#paper)')+Array.from({length:10},(_,i)=>line(`M20 ${40+i*34}H380`,p.edge,1,.2)).join(''));
  put('col_table_tray',500,190,bevel(500,190,'url(#wood)',p.woodEdge,22)+grain(500,190)+rect(14,16,472,156,16,'none',p.woodEdge,2));
  put('col_hanoi_post',120,220,rect(53,13,14,177,7,'url(#wood)',p.woodEdge,2)+
    group(bevel(120,30,'url(#wood)',p.woodEdge,10),0,187)+circle(60,16,5,'#F5D4A0'));
  for(let i=0;i<5;i++)put('col_disc_'+i,180,40,bevel(180,40,'url(#'+['blue','mint','gold','coral','violet'][i]+')','#627B93',18));
  for(let i=0;i<3;i++)put('col_signal_'+i,100,100,lantern(i));

  // Low-contrast decorative paper around live text; math and clues stay native/accessibile.
  put('col_question_paper',500,200,bevel(500,200,'url(#paper)',p.edge,20)+
    line('M36 25V174',dark?'#845B75':'#E6ADB5',2,.5)+
    Array.from({length:5},(_,i)=>line(`M48 ${45+i*28}H478`,p.edge,1,.22)).join(''));
  put('col_question_binary',500,200,bevel(500,200,'url(#paper)',p.edge,20)+
    line('M17 30H70V17M480 170H430V182M17 147H30V170H57',p.blue,3,.35)+
    circle(74,17,4,p.cyan)+circle(426,182,4,p.cyan));
  put('col_question_memory',500,200,bevel(500,200,'url(#paper)',p.edge,20)+
    [22,478].map(x=>circle(x,32,5,'#B2A0E0')+circle(x,166,5,'#B2A0E0')).join('')+
    line('M55 15H445M55 179H445','#A999D0',2,.3));

  // Icon geometry is owned by the shared 100-game generator.
  for(const id of ids)assets.set('game_'+id,{name:'game_'+id,width:120,height:120});

}
const manifest={style:'LittleGames / soft tactile miniatures',source:'First-party SVG geometry; no external assets',games:ids.map((id,i)=>({id,name:labels[i],icon:'game_'+id})),assets:[...assets.values()]};
const updateElements=(theme,type,values)=>{
  const file=path.join(root,'entry/src/main/resources',theme,'element',type+'.json');
  const data=JSON.parse(fs.readFileSync(file,'utf8'));
  for(const [name,value] of Object.entries(values)){
    const item=data[type].find(x=>x.name===name);if(item)item.value=value;else data[type].push({name,value});
  }
  fs.writeFileSync(file,JSON.stringify(data,null,2)+'\n');
};
updateElements('base','color',{collection_art_ink:'#263E60'});
updateElements('dark','color',{collection_art_ink:'#DAE8FF'});
updateElements('base','float',{
  collection_art_beacon:'88vp',collection_art_turn:'32vp',collection_art_question_icon:'48vp',
  collection_art_question_height:'180vp',collection_art_card_width:'44vp',collection_art_card_height:'56vp',
  collection_art_stone:'36vp',collection_art_tray_height:'190vp',collection_art_disc_height:'26vp',collection_art_tower_height:'232vp'
});
fs.mkdirSync(path.join(root,'docs/art'),{recursive:true});fs.writeFileSync(path.join(root,'docs/art/collection-art-manifest.json'),JSON.stringify(manifest,null,2)+'\n');
console.log(`Generated ${assets.size} SVG resources × 2 themes (including 20 game-specific icons).`);

module.exports={ids,labels};

require('./generate-game-icons.cjs').generate();
