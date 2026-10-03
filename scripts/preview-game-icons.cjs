/* Raster verification and the 100-game contact sheet; these are asset previews. */
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const sharp = require('sharp');
const root = path.resolve(__dirname,'..');
const out = path.join(root,'docs/art');
const manifest = JSON.parse(fs.readFileSync(path.join(out,'game-icon-manifest.json')));
const esc = s => s.replaceAll('&','&amp;').replaceAll('<','&lt;');
const rect = (x,y,w,h,r,c) => `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${r}" fill="${c}"/>`;
const text = (s,x,y,size,c) => `<text x="${x}" y="${y}" font-family="Microsoft YaHei, sans-serif" font-size="${size}" text-anchor="middle" fill="${c}">${esc(s)}</text>`;
async function main() {
  const results=[],problems=[];
  for (const theme of ['base','dark']) {
    const dark=theme==='dark',bg=dark?'#0C1526':'#F2F6FC',panel=dark?'#1A2941':'#FFFFFF',ink=dark?'#DAE8FF':'#304A69',badge=dark?'#24395A':'#DDEBFA';
    let body=rect(0,0,1400,1870,0,bg)+text('100 款游戏 · 统一图标',700,40,26,ink)+text('透明矢量 / '+(dark?'深色':'浅色')+' / 右下角为 42px 小尺寸 / 素材预览',700,70,15,ink);
    for (let i=0;i<manifest.games.length;i++) {
      const game=manifest.games[i],file=path.join(root,`entry/src/main/resources/${theme}/media/${game.icon}.svg`);
      const png=await sharp(file).png().toBuffer();
      const raw=await sharp(png).ensureAlpha().raw().toBuffer({resolveWithObject:true});
      let visible=0,border=0;
      for(let y=0;y<120;y++) for(let x=0;x<120;x++) {
        const a=raw.data[(y*120+x)*4+3];
        if(a>24)visible++;
        if((x===0||y===0||x===119||y===119)&&a>24)border++;
      }
      if(visible<=600||border>0)problems.push(`${theme}/${game.id}: visible=${visible}, border=${border}`);
      const small=await sharp(file).resize(42,42).ensureAlpha().raw().toBuffer();
      let smallVisible=0;for(let at=3;at<small.length;at+=4)if(small[at]>24)smallVisible++;
      if(smallVisible<=65)problems.push(`${theme}/${game.id}: invisible at 42px`);
      results.push({id:game.id,theme,bytes:fs.statSync(file).size,visiblePixels:visible,smallVisiblePixels:smallVisible,clippedPixels:border});
      const x=12+i%10*139,y=93+Math.floor(i/10)*176;
      const img=(xx,yy,size)=>`<image x="${xx}" y="${yy}" width="${size}" height="${size}" href="data:image/png;base64,${png.toString('base64')}"/>`;
      body+=rect(x,y,130,167,16,panel)+rect(x+20,y+7,90,90,20,badge)+img(x+20,y+7,90)+text(game.name,x+65,y+117,13,ink)+text(game.id,x+42,y+145,9,ink)+rect(x+84,y+119,44,44,10,badge)+img(x+85,y+120,42);
    }
    await sharp(Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="1400" height="1870">${body}</svg>`)).png().toFile(path.join(out,`game-icons-${dark?'dark':'light'}.png`));
  }
  fs.writeFileSync(path.join(out,'game-icon-render-check.json'),JSON.stringify({checked:results.length,canvas:120,smallSize:42,problems,results},null,2)+'\n');
  assert.equal(problems.length,0,problems.join('\n'));
  console.log('200/200 SVGs rendered, transparent margins and 42px visibility checked.');
}
main().catch(e=>{console.error(e);process.exitCode=1;});
