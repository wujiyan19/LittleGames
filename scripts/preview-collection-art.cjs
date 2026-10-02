/* Asset contact sheets, not device screenshots. Requires sharp on NODE_PATH. */
const fs = require('node:fs');
const path = require('node:path');
const sharp = require('sharp');
const { fixture } = require('./test-performance.cjs');
const root = path.resolve(__dirname, '..');
const out = path.join(root, 'docs/art');
const manifest = JSON.parse(fs.readFileSync(path.join(out, 'collection-art-manifest.json')));
const f = fixture();
const { CollectionModel } = f.rules('Collection');
const esc = s => String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;');
const text = (s,x,y,size,color,anchor='middle') => `<text x="${x}" y="${y}" font-family="Microsoft YaHei, sans-serif" font-size="${size}" text-anchor="${anchor}" fill="${color}">${esc(s)}</text>`;
const rectangle = (x,y,w,h,fill,r=16) => `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${r}" fill="${fill}"/>`;
const doc = (w,h,body) => `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="${w}" height="${h}">${body}</svg>`;
const palettes = {base:{bg:'#F2F6FC',panel:'#FFFFFF',ink:'#263E60',muted:'#677992'},dark:{bg:'#111D2F',panel:'#1D2C42',ink:'#DAE8FF',muted:'#9CB0CF'}};
async function main() {
  for (const theme of ['base','dark']) {
    const p=palettes[theme], images={};
    for (const asset of manifest.assets) {
      const file=path.join(root,'entry/src/main/resources',theme,'media',asset.name+'.svg');
      // Render every resource at source size as a compatibility/syntax check.
      const data=await sharp(file).png().toBuffer(); images[asset.name]=data.toString('base64');
    }
    const img=(name,x,y,w,h=w)=>`<image x="${x}" y="${y}" width="${w}" height="${h}" preserveAspectRatio="none" xlink:href="data:image/png;base64,${images[name]}"/>`;
    let icons=rectangle(0,0,1100,980,p.bg,0)+text('20 款新游戏 · 专属入口美术',40,52,27,p.ink,'start')+text('原创矢量素材 / '+(theme==='base'?'浅色主题':'深色主题'),40,82,15,p.muted,'start');
    for (let i=0;i<manifest.games.length;i++) {
      const g=manifest.games[i],x=30+i%5*215,y=112+Math.floor(i/5)*211;
      icons+=rectangle(x,y,200,195,p.panel)+img(g.icon,x+34,y+8,132)+text(g.name,x+100,y+164,17,p.ink)+
        img(g.icon,x+157,y+154,32)+text(g.id,x+100,y+187,11,p.muted);
    }
    await sharp(Buffer.from(doc(1100,980,icons))).png().toFile(path.join(out,`collection-icons-${theme==='base'?'light':'dark'}.png`));
    let boards=rectangle(0,0,1280,1910,p.bg,0)+text('游戏内美术 · 20 款素材场景',28,43,26,p.ink,'start')+text('使用真实开局数据组合的素材预览，非设备截图',28,73,15,p.muted,'start');
    for (let i=0;i<manifest.games.length;i++) {
      const g=manifest.games[i],id=g.id,m=new CollectionModel(f.rng(7));m.start(id,1);const s=m.state;
      const x=20+i%4*315,y=99+Math.floor(i/4)*356;
      boards+=rectangle(x,y,300,340,p.panel)+img(g.icon,x+12,y+8,38)+text(g.name,x+58,y+34,18,p.ink,'start');
      let body='';
      if (id==='nim') {
        body+=img('col_table_tray',8,44,264,175);
        for(let j=0;j<s.board[0];j++)body+=img('col_stone',22+j%6*40,56+Math.floor(j/6)*46,37);
      } else if (id==='hanoi') {
        for(let post=0;post<3;post++)body+=img('col_hanoi_post',4+post*92,35,88,205);
        for(let disc=3;disc>=0;disc--){const w=38+disc*14;body+=img('col_disc_'+disc,48-w/2,104+disc*26,w,26)+text(disc+1,48,122+disc*26,12,'#263E60');}
      } else if (id==='reaction') {
        body+=img('col_signal_2',58,32,164)+text('现在点击！',140,230,22,p.ink);
      } else if(id==='missing') {
        body+=img('col_question_memory',0,15,280,230);
        s.target.forEach((v,j)=>{body+=img('col_card_front',25+j%4*58,39+Math.floor(j/4)*88,48,64)+text(v,49+j%4*58,80+Math.floor(j/4)*88,24,p.ink);});
      } else if(m.isQuiz()) {
        body+=img(id==='binary'?'col_question_binary':'col_question_paper',0,22,280,178)+img(g.icon,109,33,62)+text(s.prompt,140,136,20,p.ink);
        s.choices.forEach((v,j)=>{body+=img('col_ceramic_cell',10+j%2*135,205+Math.floor(j/2)*34,125,31)+text(id==='compare'?['＜','＝','＞'][v+1]:v,72+j%2*135,226+Math.floor(j/2)*34,16,p.ink);});
      } else {
        const material=id==='gomoku'||id==='peg'?'table':id==='reversi'?'jade':id==='fourline'?'blue':id==='maze'?'garden':id==='lights'||id==='memorysequence'?'night':id==='nonogram'?'paper':'ceramic';
        let offset=id==='memorysequence'?55:0;
        if(offset) s.target.forEach((v,j)=>{body+=img('col_card_front',10+j*43,0,38,48)+text(v,29+j*43,31,18,p.ink);});
        const size=offset?222:278,left=(280-size)/2,rows=Math.ceil(s.board.length/s.cols),gap=id==='gomoku'||id==='maze'?0:3;
        const cw=(size-20-(s.cols-1)*gap)/s.cols,ch=(size-20-(rows-1)*gap)/rows;
        body+=img('col_'+material+'_board',left,offset,size);
        // Show a few legal moves for board games; remaining games use a real initial state.
        if(['tictactoe','gomoku','fourline'].includes(id)){m.tap(0);m.tap(1);m.tap(id==='tictactoe'?4:2);}
        for(let j=0;j<s.board.length;j++) {
          const v=s.board[j];if(v<0)continue;const xx=left+10+j%s.cols*(cw+gap),yy=offset+10+Math.floor(j/s.cols)*(ch+gap);
          const cell=id==='gomoku'?'go_cell':id==='reversi'?'jade_cell':id==='fourline'?'drop_hole':id==='flood'?'flood_'+v:id==='maze'?(v===1?'wall':'path'):id==='lights'?'light_'+(v===1?'on':'off'):id==='peg'?'peg_hole':id==='nonogram'?(v===1?'ink_cell':'paper_cell'):'ceramic_cell';
          body+=img('col_'+cell,xx,yy,cw,ch);
          let piece='';
          if(m.isDuel()&&v>0)piece=id==='tictactoe'?(v===1?'cross':'ring'):id==='fourline'?(v===1?'chip_blue':'chip_coral'):(v===1?'stone_dark':'stone_light');
          if(id==='peg'&&v===1)piece='peg';if(id==='maze'&&j===s.cursor)piece='robot';else if(id==='maze'&&j===s.answer)piece='portal';
          if(piece)body+=img('col_'+piece,xx,yy,cw,ch);
          if(['flood','schulte','memorysequence'].includes(id))body+=text(id==='flood'?v+1:v,xx+cw/2,yy+ch*.61,16,id==='flood'?'#263E60':p.ink);
          if(id==='reversi'&&m.flips(j,s.player).length)body+=text('·',xx+cw/2,yy+ch*.61,26,'#FFFFFF');
        }
      }
      boards+=`<g transform="translate(${x+10} ${y+54})">${body}</g>`;
    }
    await sharp(Buffer.from(doc(1280,1910,boards))).png().toFile(path.join(out,`collection-gameplay-${theme==='base'?'light':'dark'}.png`));
  }
  console.log('Rendered all 144 theme assets and four preview sheets.');
}
main().catch(e=>{console.error(e);process.exitCode=1;});
