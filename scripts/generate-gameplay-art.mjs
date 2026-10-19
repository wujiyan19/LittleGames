/** The original thirteen games share the soft vector materials of their current icons. */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import artStyle from './game-art-palette.cjs';
import svgResources from './svg-resource-utils.cjs';
const { pruneSvgDefs } = svgResources;
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const rect = (x,y,w,h,r,fill,stroke='none',sw=2) => `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${r}" fill="${fill}" stroke="${stroke}" stroke-width="${sw}"/>`;
const ellipse = (x,y,rx,ry,fill,opacity=1) => `<ellipse cx="${x}" cy="${y}" rx="${rx}" ry="${ry}" fill="${fill}" opacity="${opacity}"/>`;
const circle = (x,y,r,fill,stroke='none',sw=2) => `<circle cx="${x}" cy="${y}" r="${r}" fill="${fill}" stroke="${stroke}" stroke-width="${sw}"/>`;
const shape = (d,fill,stroke='none',sw=2) => `<path d="${d}" fill="${fill}" stroke="${stroke}" stroke-width="${sw}" stroke-linejoin="round"/>`;
const line = (d,color,w=2,opacity=1) => `<path d="${d}" fill="none" stroke="${color}" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round" opacity="${opacity}"/>`;
const generated = [];
for (const theme of ['base','dark']) {
  const dark = theme === 'dark', p = artStyle.palette(theme), defs = artStyle.gradients(theme);
  const colorFile = path.join(root,`entry/src/main/resources/${theme}/element/color.json`);
  const resources = JSON.parse(fs.readFileSync(colorFile,'utf8'));
  const colors = artStyle.resourceColors(theme);
  for (const [name,value] of Object.entries(colors)) {
    const existing = resources.color.find(color=>color.name===name);
    if (existing) existing.value=value;
    else resources.color.push({name,value});
  }
  fs.writeFileSync(colorFile,JSON.stringify(resources,null,2)+'\n');
  const save = (name,w,h,body) => {
    fs.writeFileSync(path.join(root,`entry/src/main/resources/${theme}/media/play_${name}.svg`),
      pruneSvgDefs(`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}"><defs>${defs}</defs>${body}</svg>\n`));
    if (theme === 'base') generated.push({ name:'play_'+name, width:w, height:h });
  };
  const tile = (w,h,color,r=12) => rect(3,5,w-6,h-8,r,p.edge)+rect(3,2,w-6,h-8,r,`url(#${color})`,p.edge)+
    line(`M${r+5} 9H${w-r-8}`,'#FFFFFF',2,.48);
  const gloss = (w,h,r=12) => rect(2,2,w-4,h-4,r,'none',p.edge,2)+
    line(`M${r+4} 8H${w-r-6}`,'#FFFFFF',3,dark?.3:.5)+line(`M${r+4} ${h-8}H${w-r-4}`,p.edge,2,.36);
  // Right-facing head. Openings of body, elbow and tail retain the existing connection directions.
  save('snake_head',100,100,shape('M0 25H30C38 10 64 8 80 23C101 39 100 63 83 77C66 92 40 88 30 75H0Z','url(#mint)','#4D9E85',2)+
    ellipse(68,34,12,11,'#FFFAF0')+ellipse(68,67,12,11,'#FFFAF0')+circle(72,34,5,'#304A69')+circle(72,67,5,'#304A69')+
    ellipse(84,51,11,7,'#C7EDD0')+line('M90 51H96L99 46M96 51L99 56',p.coral,3));
  save('snake_body',100,100,rect(0,25,100,50,0,'url(#mint)')+line('M0 25H100M0 75H100','#4D9E85',2)+line('M0 33H100','#D8F6DB',3,.55));
  save('snake_corner',100,100,shape('M0 25H50C64 25 75 36 75 50V100H25V75H0Z','url(#mint)')+
    line('M0 25H50C64 25 75 36 75 50V100M0 75H25V100','#4D9E85',2)+line('M0 33H50Q67 33 67 50V100','#D8F6DB',3,.5));
  save('snake_tail',100,100,shape('M100 25H73C48 25 17 38 2 50C17 62 48 75 73 75H100Z','url(#mint)','#4D9E85',2)+line('M100 33H74Q43 33 16 49','#D8F6DB',3,.5));
  save('snake_food',64,64,shape('M32 19C20 10 8 20 9 34C10 49 23 57 32 52C42 57 54 48 55 34C56 20 43 10 32 19Z','url(#coral)',p.edge)+
    line('M32 21Q33 11 39 7',p.woodEdge,3)+shape('M36 13Q44 3 54 7Q48 17 36 13Z','url(#mint)')+ellipse(21,29,5,3,'#FFFFFF',.5));
  save('tetris_gloss',100,100,gloss(100,100,12));
  save('2048_surface',100,100,gloss(100,100,14));
  save('sudoku_cell',100,100,rect(1,1,98,98,5,'none',p.edge,1)+line('M9 10H33','#FFFFFF',2,dark?.18:.4));
  save('slide_tile',100,100,gloss(100,100,12));
  save('guess_key',100,100,gloss(100,100,12));
  save('klotski_board',320,400,tile(320,400,'wood',22)+rect(13,12,294,374,14,p.woodInset,p.woodEdge,2)+
    line('M118 385H202',p.gold,7)+line('M135 371L160 382L185 371',p.gold,3));
  save('klotski_target',128,128,tile(128,128,'coral',14)+line('M49 62H79M64 47V77','#FFF1C5',4,.65));
  save('klotski_vertical',80,160,tile(80,160,'gold',10));
  save('klotski_horizontal',160,80,tile(160,80,'wood',10));
  save('klotski_soldier',80,80,tile(80,80,'wood',10));
  save('mole',100,100,ellipse(50,82,35,7,p.edge,.32)+ellipse(50,61,29,25,'url(#wood)')+
    circle(28,31,10,'url(#wood)')+circle(72,31,10,'url(#wood)')+ellipse(50,43,28,24,'url(#wood)')+
    ellipse(50,58,17,10,'#FFE7AD')+circle(39,42,4,'#304A69')+circle(61,42,4,'#304A69')+
    ellipse(50,51,6,4,'#304A69')+ellipse(29,79,10,5,'url(#wood)')+ellipse(71,79,10,5,'url(#wood)'));
  save('whack_hole',128,92,ellipse(64,51,60,32,p.edge)+ellipse(64,49,53,26,'#20364F')+
    line('M14 54Q64 89 114 54',dark?'#516884':'#9CB7D0',7));
  save('mine',100,100,Array.from({length:8},(_,i)=>`<g transform="rotate(${i*45} 50 50)">${line('M50 8V26','#6386A8',7)}</g>`).join('')+
    circle(50,50,29,'url(#ink)',p.edge)+ellipse(41,38,10,5,'#FFFFFF',.5));
  save('flag',100,100,line('M27 15V87',p.ink,5)+shape('M30 17H81L65 43L30 47Z','url(#coral)',p.edge)+line('M14 88H48',p.ink,5));
  save('memory_back',100,120,tile(100,120,'blue',14)+rect(11,10,78,97,9,'none','#DCE8F1',2)+
    shape('M50 27L59 48L81 50L65 64L71 86L50 74L29 86L35 64L19 50L41 48Z','url(#gold)'));
  const motifs = [
    ['sun',circle(50,50,21,'url(#gold)')+line('M50 12V23M50 77V88M12 50H23M77 50H88M23 23L31 31M69 69L77 77M77 23L69 31M31 69L23 77',p.gold,5)],
    ['moon',shape('M68 18A31 31 0 1 0 82 71A33 33 0 0 1 68 18Z','url(#violet)')],
    ['star',shape('M50 15L60 38L85 40L66 57L72 82L50 68L28 82L34 57L15 40L40 38Z','url(#gold)')],
    ['heart',shape('M50 80L20 52C1 32 21 12 40 27L50 37L60 27C79 12 99 32 80 52Z','url(#coral)')],
    ['clover',[38,62].map(x=>[38,62].map(y=>circle(x,y,15,'url(#mint)')).join('')).join('')],
    ['bolt',shape('M56 14L26 54H46L40 87L75 42H54Z','url(#blue)')],
    ['crown',shape('M20 35L34 48L50 22L66 48L80 35L74 76H26Z','url(#gold)')],
    ['diamond',shape('M50 13L83 50L50 87L17 50Z','url(#cyan)',p.edge)+line('M50 13V87M17 50H83','#FFFFFF',2,.6)],
    ['spiral',line('M65 44C60 33 40 36 40 50C40 63 63 67 74 54C89 35 70 13 48 14C20 16 8 49 25 71C42 93 78 88 88 63',p.violet,9)],
    ['leaf',shape('M21 75C19 40 43 19 82 18C84 57 62 83 28 80Z','url(#mint)')+line('M25 76L74 28','#4D9E85',4)],
    ['shell',shape('M18 69C17 40 31 20 50 20S83 40 82 69Z','url(#coral)')+line('M50 22V68M33 29L40 68M67 29L60 68','#CF645F',3)],
    ['flame',shape('M51 13C60 32 35 39 38 56C27 48 27 38 29 32C14 50 25 84 50 86C77 84 87 56 69 40C68 55 56 56 60 42C63 33 58 22 51 13Z','url(#gold)')]
  ];
  for (const [name,body] of motifs) save('memory_'+name,100,100,circle(50,50,45,p.low)+body);
  save('jump_frog',100,100,ellipse(50,52,29,22,'url(#mint)')+circle(33,31,12,'url(#mint)')+circle(67,31,12,'url(#mint)')+
    circle(33,31,7,'#FFFAF0')+circle(67,31,7,'#FFFAF0')+circle(35,33,3,'#304A69')+circle(69,33,3,'#304A69')+
    ellipse(50,61,21,12,'#C7EDD0')+line('M40 63Q50 71 61 63','#304A69',2)+ellipse(21,73,16,7,'url(#mint)')+ellipse(79,73,16,7,'url(#mint)'));
  save('jump_platform',160,52,tile(160,52,'wood',13));
  save('brick_gloss',160,64,gloss(160,64,10));
  save('brick_paddle',160,32,tile(160,32,'blue',12));
  save('brick_ball',64,64,circle(32,33,27,p.edge)+circle(32,30,27,'url(#ivory)',p.edge)+ellipse(24,21,9,5,'#FFFFFF',.65));
  const outlines = ['M50 5L91 30L82 78L50 96L18 78L9 30Z','M50 3L94 50L50 97L6 50Z',
    'M25 10H75L95 42L75 90H25L5 42Z','M50 5L91 27L91 73L50 95L9 73L9 27Z',
    'M50 9C68-1 91 13 91 35C91 59 67 78 50 93C33 78 9 59 9 35C9 13 32-1 50 9Z',
    'M50 4L86 21L96 60L70 93H30L4 60L14 21Z'];
  const gemColors = ['coral','gold','mint','blue','coral','violet'];
  for (let i=0;i<6;i++) save('gem_'+i,100,100,shape(outlines[i],`url(#${gemColors[i]})`,p.edge)+
    shape('M50 12L24 33L50 70L76 33Z','#FFFFFF','none')+shape('M50 12L50 70L76 33Z',p.low,'none')+
    line('M50 12V70M24 33H76','#FFFFFF',2,.6));
  save('jump_scene',400,500,rect(0,0,400,500,24,'url(#paper)')+
    shape('M0 449Q100 409 211 458Q315 417 400 442V500H0Z',dark?'#263F3A':'#D1E5DB')+
    ellipse(74,81,50,15,p.paper,.6)+ellipse(287,125,67,17,p.paper,.45));
  save('whack_scene',400,400,rect(0,0,400,400,24,'url(#paper)')+
    shape('M0 332Q103 302 200 339Q299 312 400 329V400H0Z',dark?'#263F3A':'#D1E5DB')+
    line('M28 365L33 350L39 365M350 378L357 358L365 377',dark?'#416251':'#A4C6B3',3,.5));
  save('brick_scene',400,500,rect(0,0,400,500,20,'url(#paper)')+rect(8,8,384,484,16,'none',p.edge,2)+line('M31 35H92M308 465H369',p.edge,2,.3));
}
fs.writeFileSync(path.join(root,'docs/art/legacy-gameplay-manifest.json'),JSON.stringify({
  style:'Shared icon palette; soft vector toy materials; base and dark', games:13, assets:generated
},null,2)+'\n');
console.log(`Generated ${generated.length} original-game resources in both themes.`);
