// Asset pairing and SVG decoding checks; the sheets are not device screenshots.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const sharp = require('sharp');
const artStyle = require('./game-art-palette.cjs');
const root = path.resolve(__dirname,'..');
const out = path.join(root,'docs/art/legacy-gameplay-2026-10-08');
fs.mkdirSync(out,{recursive:true});
const manifest = JSON.parse(fs.readFileSync(path.join(root,'docs/art/legacy-gameplay-manifest.json')));
const strings = new Map(JSON.parse(fs.readFileSync(path.join(root,'entry/src/main/resources/zh_CN/element/string.json'))).string.map(s=>[s.name,s.value]));
const games = [
  ['snake',['snake_head','snake_body','snake_corner','snake_tail','snake_food']],
  ['tetris',['tetris_gloss']],['2048',['2048_surface']],
  ['whackmole',['mole','whack_hole','whack_scene']],['minesweeper',['mine','flag','2048_surface']],
  ['jumpjump',['jump_frog','jump_platform','jump_scene']],['brickbreaker',['brick_paddle','brick_ball','brick_gloss','brick_scene']],
  ['sudoku',['sudoku_cell']],['slidepuzzle',['slide_tile']],
  ['klotski',['klotski_board','klotski_target','klotski_vertical','klotski_horizontal','klotski_soldier']],
  ['guessnumber',['guess_key']],['memorycard',['memory_back','memory_star','memory_heart','memory_moon']],
  ['match3',['gem_0','gem_1','gem_2','gem_3','gem_4','gem_5']]
];
const escape = text => text.replaceAll('&','&amp;').replaceAll('<','&lt;');
const text = (value,x,y,size,color) => `<text x="${x}" y="${y}" font-family="Microsoft YaHei,sans-serif" font-size="${size}" fill="${color}">${escape(value)}</text>`;
const rect = (x,y,w,h,r,color) => `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${r}" fill="${color}"/>`;
async function main() {
  const checks=[];
  for (const theme of ['base','dark']) {
    const p=artStyle.palette(theme), colors=artStyle.resourceColors(theme), dark=theme==='dark';
    const dir=path.join(root,`entry/src/main/resources/${theme}/media`);
    for (const asset of manifest.assets) {
      const file=path.join(dir,asset.name+'.svg'), source=fs.readFileSync(file,'utf8');
      assert(!/<image|<filter|<mask|<text|https?:\/\/(?!www.w3.org)/.test(source));
      const result=await sharp(file).ensureAlpha().raw().toBuffer({resolveWithObject:true});
      assert.equal(result.info.width,asset.width); assert.equal(result.info.height,asset.height);
      let visible=0; for(let i=3;i<result.data.length;i+=4) if(result.data[i]>12) visible++;
      assert(visible>0,'Empty decoded asset: '+asset.name);
      checks.push({theme,name:asset.name,width:asset.width,height:asset.height,visiblePixels:visible});
    }
    let body=rect(0,0,1440,1170,0,dark?'#000000':'#F1F3F5')+
      text('老游戏：入口图标与对局素材',35,40,27,p.ink)+
      text((dark?'深色':'浅色')+'素材组合预览 · 不是设备截图 · 棋盘数字由界面绘制',35,70,16,p.ink);
    const images=[]; let overlay='';
    for (let i=0;i<games.length;i++) {
      const [id,assets]=games[i], x=20+(i%4)*355, y=94+Math.floor(i/4)*265;
      body+=rect(x,y,340,249,20,dark?'#1A1A1A':'#FFFFFF')+rect(x+16,y+15,76,76,16,dark?'#24395A':'#DDEBFA')+
        text(strings.get('game_'+id+'_name'),x+105,y+42,20,p.ink)+text(id,x+105,y+69,13,p.ink);
      images.push({input:await sharp(path.join(dir,'game_'+id+'.svg')).resize(68,68).png().toBuffer(),left:x+20,top:y+19});
      for (let k=0;k<assets.length;k++) {
        const ax=x+18+(k%3)*105, ay=y+105+Math.floor(k/3)*64;
        let fill=colors.play_cell_background;
        if(id==='tetris') fill=colors.shape_4;
        if(id==='2048') fill=[colors.tile_2,colors.tile_4,colors.tile_8][k%3];
        if(id==='slidepuzzle') fill=colors.play_selection_background;
        body+=rect(ax,ay,90,57,10,fill);
        images.push({input:await sharp(path.join(dir,'play_'+assets[k]+'.svg')).resize(86,53,{fit:'contain',background:'#00000000'}).png().toBuffer(),left:ax+2,top:ay+2});
        if(['2048','slidepuzzle','sudoku','guessnumber'].includes(id)) overlay+=text(id==='2048'?'2':id==='guessnumber'?'7':'5',ax+34,ay+38,28,id==='2048'?colors.tile_text_low:colors.play_piece_text);
      }
    }
    // Text belongs above the transparent artwork, as it does in the app.
    const base=await sharp(Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="1440" height="1170">${body}</svg>`)).png().toBuffer();
    images.push({input:await sharp(Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="1440" height="1170">${overlay}</svg>`)).png().toBuffer(),left:0,top:0});
    await sharp(base).composite(images).png().toFile(path.join(out,theme+'.png'));
  }
  fs.writeFileSync(path.join(out,'render-check.json'),JSON.stringify({resources:checks.length,checks},null,2)+'\n');
  console.log(`Decoded ${checks.length} classic SVG resources; paired 13 icons with gameplay assets in both themes.`);
}
main().catch(error=>{console.error(error);process.exitCode=1;});
