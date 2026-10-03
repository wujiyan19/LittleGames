/* Contact sheet crops of actual catalog badges using their captured UI bounds. */
const fs=require('node:fs');const path=require('node:path');const sharp=require('sharp');
const dir=path.resolve(process.env.LITTLEGAMES_ART_OUTPUT||'docs/device-acceptance/unified-icons-2026-10-03');
const summary=JSON.parse(fs.readFileSync(path.join(dir,'summary.json'),'utf8'));
const esc=s=>s.replaceAll('&','&amp;').replaceAll('<','&lt;');
async function main() {
  const images=[];const bounds=[];
  for(const check of summary.passed) {
    const tag=check.mode+'-catalog-'+check.id;
    const tree=JSON.parse(fs.readFileSync(path.join(dir,tag+'.json'),'utf8'));
    let badge;
    const visit=(n,parent)=>{if(n.attributes.type==='Image')badge=parent.attributes.bounds;(n.children||[]).forEach(child=>visit(child,n));};visit(tree);
    if(!badge)throw Error('Missing captured badge '+tag);
    const b=badge.match(/\d+/g).map(Number);
    const crop={left:b[0],top:b[1],width:b[2]-b[0],height:b[3]-b[1]};
    if(crop.width<100||crop.width>250||crop.height!==crop.width)throw Error('Unexpected badge '+tag+': '+badge);
    const buffer=await sharp(path.join(dir,tag+'.jpeg')).extract(crop).resize(96,96).png().toBuffer();
    images.push({tag,name:check.name,mode:check.mode,buffer});bounds.push({tag,bounds:badge});
  }
  let svg='<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="700"><rect width="1024" height="700" fill="#F2F6FC"/>';
  for(let i=0;i<images.length;i++) {
    const item=images[i],x=18+i%8*126,y=65+Math.floor(i/8)*158;
    svg+=`<image x="${x+10}" y="${y}" width="96" height="96" href="data:image/png;base64,${item.buffer.toString('base64')}"/><text x="${x+58}" y="${y+121}" font-family="Microsoft YaHei, sans-serif" font-size="15" fill="#304A69" text-anchor="middle">${esc(item.name)}</text>`;
  }
  svg+='<text x="20" y="32" font-family="Microsoft YaHei, sans-serif" font-size="22" fill="#304A69">手机实拍 · 上两行浅色 / 下两行深色</text></svg>';
  await sharp(Buffer.from(svg)).png().toFile(path.join(dir,'catalog-icon-contact.png'));
  fs.writeFileSync(path.join(dir,'catalog-icon-crops.json'),JSON.stringify({source:'Actual HDC screenshots, cropped using observed UI bounds',bounds},null,2)+'\n');
  console.log('Cropped '+images.length+' real-device badges.');
}
main().catch(e=>{console.error(e);process.exitCode=1;});
