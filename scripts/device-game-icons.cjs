/* Representative catalog icon acceptance through rendered device UI. */
process.env.LITTLEGAMES_ART_OUTPUT=process.env.LITTLEGAMES_ART_OUTPUT||'docs/device-acceptance/unified-icons-2026-10-03';
const c=require('./device-art-review.cjs');
const manifest=JSON.parse(c.fs.readFileSync('docs/art/game-icon-manifest.json','utf8'));
for(const game of manifest.games)c.names[game.id]=game.name;
const selected=['snake','tetris','2048','whackmole','memorycard','tictactoe','gomoku','arithmetic',
  'memorysequence','reaction','blockfit','watersort','fruitslice','chess','guandan','decorate'];
const passed=[];
function search(id) {
  let ns=c.wait(a=>a.some(n=>n.type==='TextInput'));
  let input=ns.find(n=>n.type==='TextInput');
  if(input.text) {
    const clear=input.parent.children.find(n=>n.attributes.type==='Button');c.assert(clear);
    c.click(clear.attributes);ns=c.wait(a=>a.some(n=>n.type==='TextInput'&&!n.text));input=ns.find(n=>n.type==='TextInput');
  }
  const b=c.bounds(input);
  c.shell('uitest','uiInput','inputText',''+Math.round((b[0]+b[2])/2),''+Math.round((b[1]+b[3])/2),c.names[id]);
  const card=n=>n.type==='Column'&&n.clickable==='true'&&[n.text,n.description].some(s=>s?.startsWith(c.names[id]+'，')||s?.startsWith(c.names[id]+','));
  ns=c.wait(a=>a.some(card));
  c.assert(c.descendants(ns.find(card)).some(n=>n.type==='Image'),id+' catalog icon');
  c.shell('uitest','uiInput','keyEvent','Back');
  return c.wait(a=>a.some(card)&&c.find(a,'我的'));
}
function visiblePage(label,tag) { c.tap(label,c.tabs()); c.sleep(300);c.capture(tag); }
function restore() {
  c.theme('restore');
  const raw=JSON.parse(c.fs.readFileSync(c.path.join(c.dir,'settings-restore.json'),'utf8'));
  const original=JSON.parse(c.fs.readFileSync(c.path.join(c.dir,'original-settings.json'),'utf8'));
  const nodes=[];const visit=n=>{nodes.push(n);(n.children||[]).forEach(visit);};visit(raw);
  const themes=nodes.filter(n=>n.attributes.type==='Button'&&n.attributes.description==='已选择').flatMap(n=>{
    const labels=[];const visitLabel=a=>{if(a.attributes.type==='Text')labels.push(a.attributes.text);(a.children||[]).forEach(visitLabel);};visitLabel(n);return labels;
  });
  c.assert(themes.includes(original.theme));
  c.assert.deepEqual(nodes.filter(n=>n.attributes.type==='Toggle').map(n=>n.attributes.checked),original.toggles.map(n=>n.checked));
  visiblePage('精选','finished-home');
  return {theme:original.theme,toggles:original.toggles.map(n=>n.checked),verified:true};
}
function main() {
  for(const mode of ['light','dark']) {
    c.theme(mode);
    visiblePage('精选',mode+'-featured');
    visiblePage('分类',mode+'-category');
    for(const id of selected) {
      search(id);const nodes=c.capture(mode+'-catalog-'+id);
      const expected=mode==='dark'?'#FF24395A':'#FFDDEBFA';
      if(process.env.LITTLEGAMES_ICON_CHECK_BACKGROUND==='true') {
        const image=nodes.find(n=>n.type==='Image');c.assert(image,id+' visible Image');
        c.assert.equal(image.parent.attributes.backgroundColor,expected,id+' theme badge');
      }
      passed.push({mode,id,name:c.names[id]});c.log('catalog-icon-passed',{mode,id});
      console.log('ICON '+mode+' '+id);
    }
    // Seed mixed recent entries through normal navigation to inspect the Profile badges.
    if(process.env.LITTLEGAMES_ICON_SEED_RECENTS!=='false') {
      for(const id of ['snake','tictactoe','fruitslice','guandan']) {c.open(id);c.back();}
    }
    visiblePage('我的',mode+'-profile');
    visiblePage('分类',mode+'-category-return');
  }
  const settings=restore();
  const summary={at:new Date().toISOString(),device:c.target,packageSha256:c.packageHash,
    selectedGames:selected.length,catalogChecks:passed.length,passed,settingsRestored:settings,
    pages:['精选','分类','我的'],scope:'Representative icon display; gameplay and full 100-game device coverage are not claimed.'};
  c.fs.writeFileSync(c.path.join(c.dir,'summary.json'),JSON.stringify(summary,null,2)+'\n');
  console.log('PASS '+passed.length+' catalog checks; original settings restored.');
}
try {main();}catch(e){c.log('check-incomplete',{message:e.stack});console.error(e.stack);process.exitCode=1;}
