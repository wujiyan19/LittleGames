const fs=require('node:fs');
const assert=require('node:assert/strict');
const {fixture}=require('./test-performance.cjs');
const manifest=JSON.parse(fs.readFileSync('docs/art/expansion-art-manifest.json','utf8'));
const f=fixture(),data=f.data(),Art=f.load('entry/src/main/ets/common/ExpansionArt.ets').ExpansionArt;
let count=0;
const test=(name,fn)=>{fn();count++;console.log('PASS '+name);};
test('all 100 game icons exist, with 67 complete dedicated gameplay resource mappings',()=>{
 const games=data.getAllGames();assert.equal(games.length,100);assert.equal(manifest.games.length,67);
 for(const theme of ['base','dark']) {
  const icons=[];
  for(const g of games){
   const name=g.icon.replace('app.media.','');
   assert(!fs.existsSync(`entry/src/main/resources/${theme}/media/${name}.png`),`${g.id}: duplicate raster fallback`);
   const svg=fs.readFileSync(`entry/src/main/resources/${theme}/media/${name}.svg`,'utf8');
   assert(svg.includes('viewBox="0 0 120 120"'),`${g.id}: shared canvas`);
   assert(!/<text|<image|<filter|NaN|undefined/.test(svg),`${g.id}: standalone font-free vector`);
   const paint=new Set([...svg.matchAll(/id="([^"]+)"/g)].map(m=>m[1]));
   for(const m of svg.matchAll(/url\(#([^)]+)\)/g))assert(paint.has(m[1]),`${g.id}: ${m[1]}`);
   icons.push(svg.slice(svg.indexOf('</defs>')+7));
  }
  assert.equal(new Set(icons).size,100,'100 visibly distinct compositions');
 }
 for(const theme of ['base','dark']){
  const icons=[];for(const g of manifest.games){assert.equal(Art.board(g.id),'app.media.'+g.board);const svg=fs.readFileSync(`entry/src/main/resources/${theme}/media/${g.icon}.svg`,'utf8');assert(!svg.includes('<text'));icons.push(svg);}
  assert.equal(new Set(icons).size,67,'visually distinct icons');
 }
});
test('every generated SVG is self-contained with valid local paint references',()=>{
 for(const theme of ['base','dark'])for(const asset of manifest.assets){const s=fs.readFileSync(`entry/src/main/resources/${theme}/media/${asset.name}.svg`,'utf8');assert(!/NaN|undefined|<text|<filter|https?:\/\/(?!www.w3.org)/.test(s),asset.name);const ids=new Set([...s.matchAll(/id="([^"]+)"/g)].map(m=>m[1]));for(const m of s.matchAll(/url\(#([^)]+)\)/g))assert(ids.has(m[1]),`${asset.name}/${m[1]}`);}
});
test('all media references resolve and new strings cover every locale',()=>{
 const walk=dir=>fs.readdirSync(dir,{withFileTypes:true}).flatMap(e=>e.isDirectory()?walk(dir+'/'+e.name):[dir+'/'+e.name]);
 const media=[...fs.readdirSync('entry/src/main/resources/base/media'),...fs.readdirSync('AppScope/resources/base/media')].map(n=>n.replace(/\.[^.]+$/,''));
 for(const file of walk('entry/src/main/ets').filter(p=>p.endsWith('.ets')))for(const m of fs.readFileSync(file,'utf8').matchAll(/\$r\('app.media.([^']+)'/g))assert(media.includes(m[1]),`${file}/${m[1]}`);
 for(const lang of ['base','zh_CN','en_US']){const strings=JSON.parse(fs.readFileSync(`entry/src/main/resources/${lang}/element/string.json`)).string;for(const name of ['art_try_again','art_ludo_token'])assert(strings.some(s=>s.name===name&&s.value));}
});
const vm=id=>{const v=f.vm('ExpansionViewModel');v.init(id);v.startGame();return v;};
test('legal scoring produces one gain burst; invalid input produces none',()=>{
 const v=vm('blockfit'),serial=v.feedbackSerial;v.tap(-1);assert.equal(v.feedbackSerial,serial);v.tap(0);assert(v.state.score>0);assert.equal(v.feedbackSerial,serial+1);assert.equal(v.feedbackKind,1);assert.equal(v.feedbackGain,v.state.score);
});
test('wrong answers produce an error burst; undo and restart clear transient feedback',()=>{
 const v=vm('differences'),serial=v.feedbackSerial;v.tap(v.state.board.findIndex((_,i)=>!v.state.target.includes(i)));assert.equal(v.feedbackKind,2);assert.equal(v.feedbackSerial,serial+1);v.undo();assert.equal(v.feedbackKind,0);assert.equal(v.feedbackGain,0);v.startGame();assert.equal(v.feedbackKind,0);assert.equal(v.feedbackGain,0);
});
test('pause, background, exit confirmation and disposal disable feedback',()=>{
 const v=vm('runner');v.togglePause();assert(!v.effectsEnabled);v.onAppHidden();v.onAppShown();assert(!v.effectsEnabled);v.togglePause();assert(v.effectsEnabled);v.requestBack();assert(!v.effectsEnabled);v.dismissExitConfirm();assert(v.effectsEnabled);v.onAppHidden();assert(!v.effectsEnabled);v.dispose();assert(!v.effectsEnabled);
});
test('continuation restores gameplay without replaying a score burst; terminal state disables effects',()=>{
 const v=vm('differences');v.tap(v.state.target[0]);const payload=v.exportContinuation(),restored=vm('differences');assert(restored.importContinuation(payload));assert.equal(restored.feedbackKind,0);assert.equal(restored.feedbackGain,0);for(const i of restored.state.target.slice(1))restored.tap(i);assert.equal(restored.state.outcome,1);assert(!restored.effectsEnabled);restored.onAppHidden();restored.onAppShown();assert(!restored.effectsEnabled);assert(!restored.exportContinuation().includes('feedback'));
});
console.log(`${count}/${count} art and feedback checks passed`);
