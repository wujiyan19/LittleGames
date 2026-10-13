/* First-party vector game art. Basic SVG geometry only: no fonts, filters, masks,
 * external images or game-brand assets. Shared materials, game-specific silhouettes.
 * Run with Node; source of truth for Collection gameplay materials; icons use generate-game-icons.cjs. */
const fs = require('node:fs');
const path = require('node:path');
const artStyle = require('./game-art-palette.cjs');
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
const ellipse = (x,y,rx,ry,color,opacity=1) => `<ellipse cx="${x}" cy="${y}" rx="${rx}" ry="${ry}" fill="${color}" opacity="${opacity}"/>`;
const save = (theme,name,w,h,body,defs) => {
  const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}"><defs>${defs}</defs>${body}</svg>\n`;
  const dest=path.join(root,'entry/src/main/resources',theme,'media');fs.mkdirSync(dest,{recursive:true});fs.writeFileSync(path.join(dest,name+'.svg'),svg);
  if(theme==='base')assets.set(name,{name,width:w,height:h});
};

for(const theme of ['base','dark']) {
  const dark=theme==='dark';
  const p=artStyle.palette(theme);
  const defs=artStyle.gradients(theme);
  const put=(name,w,h,body)=>save(theme,name,w,h,body,defs);
  const bevel=(w,h,fill,edge=p.edge,r=16)=>rect(3,5,w-6,h-8,r,edge)+rect(3,2,w-6,h-8,r,fill,edge,1.5)+
    line(`M${r+5} 10H${w-r-6}`, '#FFFFFF',2,.38);
  const grain=(w,h)=>Array.from({length:6},(_,i)=>line(`M14 ${22+i*(h-40)/6}Q${w*.32} ${12+i*(h-40)/6} ${w*.55} ${23+i*(h-40)/6}T${w-14} ${20+i*(h-40)/6}`,p.woodEdge,1,.12)).join('');
  const frame=(fill,edge=p.edge)=>bevel(400,400,fill,edge,24)+rect(15,14,370,370,17,'none',edge,1.5);
  const disc=(color)=>ellipse(50,82,37,9,p.navy,.14)+circle(50,47,38,'url(#'+color+')',p.edge,1.5)+
    ellipse(38,31,15,7,'#FFFFFF',color==='darkstone'?.16:.38)+line('M26 69Q50 85 74 68',p.ink,1.5,.12);
  const cross=line('M29 27L73 71M73 27L29 71','#397ACB',17)+line('M29 23L73 67M73 23L29 67','#9AD2F7',13)+line('M29 21L46 38','#FFFFFF',2,.45);
  const ring=circle(50,51,27,'none','#CF645F',15)+circle(50,47,27,'none','#FFC0A5',13)+line('M29 32Q38 20 53 22','#FFFFFF',2,.45);
  const gem=(color)=>ellipse(50,85,31,7,p.navy,.14)+`<path d="M26 18L74 18L89 40L50 80L11 40Z" fill="url(#${color})" stroke="${p.edge}" stroke-width="1.5"/>`+
    line('M26 18L34 40H66L74 18M11 40H89M34 40L50 80L66 40','#FFFFFF',1.5,.32);
  const stone=ellipse(50,83,34,8,p.navy,.14)+`<path d="M18 42Q20 17 48 16Q79 16 84 47Q91 75 60 79Q27 85 17 65Z" fill="url(#blue)" stroke="${p.edge}" stroke-width="1.5"/>`+
    line('M29 32Q43 21 62 27','#FFFFFF',3,.45)+circle(66,58,4,p.paperLow);
  const peg=ellipse(50,82,32,9,p.navy,.14)+rect(28,43,44,34,17,'url(#gold)',p.woodEdge,1.5)+
    ellipse(50,43,24,17,'#FFE7AD')+ellipse(43,37,12,5,p.white,.45)+line('M28 48V60',p.white,1.5,.38);
  const robot=ellipse(50,87,28,7,p.navy,.14)+rect(21,29,58,49,18,'url(#blue)',p.edge,1.5)+
    rect(29,42,42,21,10,p.navy)+circle(40,52,4,p.white)+circle(60,52,4,p.white)+
    line('M50 29V19',p.edge,4)+circle(50,15,7,p.gold)+rect(16,71,15,15,5,p.paperLow)+rect(69,71,15,15,5,p.paperLow);
  const portal=ellipse(50,83,35,8,p.navy,.14)+rect(21,14,58,71,23,'url(#mint)',p.edge,1.5)+
    rect(32,27,36,55,15,p.navy)+line('M50 39V65M40 55L50 65L60 55',p.white,5)+circle(70,20,5,p.gold);
  const lamp=(on)=>bevel(100,100,on?'url(#glow)':'url(#night)',p.edge,18)+
    circle(50,46,25,on?'#FFE7AD':p.navy,p.edge,1.5)+
    line('M38 39Q50 27 62 39M40 61H60M44 67H56',on?'#C98B3E':'#7E9DB6',4)+
    circle(50,46,11,on?'#FFFDE6':'#27455F');
  const hole=ellipse(50,54,37,32,p.woodLow)+ellipse(50,51,32,27,dark?p.woodInset:'#6C5947')+line('M20 60Q47 91 80 60',p.white,2,.38);
  const pill=(color)=>bevel(100,100,'url(#'+color+')',p.edge,19)+rect(13,14,74,66,12,'none','#FFFFFF',1);
  const card=(back)=>bevel(100,120,back?'url(#violet)':'url(#paper)',p.edge,15)+
    rect(12,12,76,91,10,'none',back?p.white:p.edge,1.5)+
    (back?`<path d="M50 27L60 46L80 56L60 66L50 86L40 66L20 56L40 46Z" fill="#F0E9FF"/>`+circle(50,56,9,'#B1A0E4'):line('M18 25V19H26M82 91V99H74',p.blue,3));
  const chip=(color)=>disc(color)+circle(50,47,23,'none','#FFFFFF',1.3);
  const lantern=(phase)=>{
    const color=phase===2?'mint':phase===1?'gold':'blue';
    return ellipse(50,88,39,8,p.navy,.14)+bevel(100,100,'url(#night)',p.edge,22)+
      circle(50,46,33,p.navy,p.edge,1.5)+circle(50,46,25,'url(#'+color+')')+
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
  put('col_paper_cell',100,100,rect(1,1,98,98,6,p.paper,p.edge,1.5)+line('M9 14H34',p.edge,1.5,.3));
  put('col_ink_cell',100,100,rect(1,1,98,98,6,'url(#blue)',p.edge,1.5)+line('M16 77L73 20M32 85L84 33',p.white,3,.25));
  put('col_go_cell',100,100,line('M0 50H100M50 0V100',p.woodEdge,2));
  put('col_jade_cell',100,100,rect(1,1,98,98,5,'none',p.mint,1.5));
  put('col_drop_hole',100,100,circle(50,50,42,'url(#ink)',p.edge,1.5)+circle(50,54,33,p.navy));
  put('col_path',100,100,rect(0,0,100,100,5,dark?'#36494D':'#E1E4C7')+
    line('M18 32L36 25M59 79L72 73',dark?'#526665':'#BDCAA7',3));
  put('col_wall',100,100,rect(0,6,100,94,9,dark?'#243C3D':'#3C7065')+
    rect(2,2,96,85,13,dark?'#3D6961':'#7FAE8D',dark?'#294E47':'#68947A',2)+
    line('M11 24Q30 6 49 23M55 68Q77 49 88 64',dark?'#547E70':'#ADD0A2',5,.7));
  put('col_table_board',400,400,frame('url(#wood)',p.woodEdge)+grain(400,400));
  put('col_jade_board',400,400,frame('url(#jade)',dark?'#3A655C':p.mint));
  put('col_blue_board',400,400,frame('url(#blue)',p.edge));
  put('col_ceramic_board',400,400,frame('url(#paper)'));
  put('col_garden_board',400,400,frame(dark?'#283F43':'#C3D5B6',dark?'#426358':'#7B9F83'));
  put('col_night_board',400,400,frame('url(#night)','#59789D')+
    line('M12 74H23V116M386 290H376V330','#729AB8',3,.5));
  put('col_paper_board',400,400,frame('url(#paper)')+Array.from({length:10},(_,i)=>line(`M20 ${40+i*34}H380`,p.edge,1,.2)).join(''));
  put('col_table_tray',500,190,bevel(500,190,'url(#wood)',p.woodEdge,22)+grain(500,190)+rect(14,16,472,156,16,'none',p.woodEdge,1.5));
  put('col_hanoi_post',120,220,rect(53,13,14,177,7,'url(#wood)',p.woodEdge,2)+
    group(bevel(120,30,'url(#wood)',p.woodEdge,10),0,187)+circle(60,16,5,'#F5D4A0'));
  for(let i=0;i<5;i++)put('col_disc_'+i,180,40,bevel(180,40,'url(#'+['blue','mint','gold','coral','violet'][i]+')',p.edge,18));
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
updateElements('base','color',{collection_art_ink:artStyle.palette('base').ink});
updateElements('dark','color',{collection_art_ink:artStyle.palette('dark').ink});
updateElements('base','float',{
  collection_art_beacon:'88vp',collection_art_turn:'32vp',collection_art_question_icon:'48vp',
  collection_art_question_height:'180vp',collection_art_card_width:'44vp',collection_art_card_height:'56vp',
  collection_art_stone:'36vp',collection_art_tray_height:'190vp',collection_art_disc_height:'26vp',collection_art_tower_height:'232vp'
});
fs.mkdirSync(path.join(root,'docs/art'),{recursive:true});fs.writeFileSync(path.join(root,'docs/art/collection-art-manifest.json'),JSON.stringify(manifest,null,2)+'\n');
console.log(`Generated ${assets.size} SVG resources × 2 themes (including 20 game-specific icons).`);

module.exports={ids,labels};

require('./generate-game-icons.cjs').generate();
