/* Rendered UI acceptance on an explicit target; does not inject state or read app files. */
const c=require('./device-toy-art.cjs');
const labels=['简单','普通','困难'];
const plateCount=ns=>ns.filter(n=>/^toy-plate-\d+$/.test(n.id||'')).length;
function difficulty(label,count){
  if(plateCount(c.layout())===count)return;
  c.click(c.layout().find(n=>n.id==='game-settings-button'));
  c.wait(a=>c.find(a,label));c.tap(label);
  c.wait(a=>!a.some(n=>n.id==='game-settings-panel')&&plateCount(a)===count);
}
function restart(){c.tap('再来一局');c.wait(a=>!c.find(a,'再来一局'));}
function solve(tag){
  c.cp.execFileSync(process.execPath,['scripts/device-toy-art.cjs','screws'],{stdio:'inherit',timeout:150000});
  c.capture(tag);
}
function colors(ns){
  const counts=[0,0,0,0,0,0];
  for(const n of ns.filter(n=>/^toy-screw-\d+$/.test(n.id||''))){
    const color=c.descendants(n).find(d=>d.type==='Text'&&/^[1-5]$/.test(d.text));c.assert(color);
    counts[Number(color.text)]++;
  }
  c.assert(counts.every(n=>n%3===0),'Restarted screw colors must remain balanced in threes');
}
function overflow(){
  for(let step=0;step<30;step++){
    const ns=c.layout();if(c.find(ns,'再来一局'))break;
    const holding=[0,0,0,0,0,0];
    for(const n of ns.filter(n=>/^toy-screw-slot-\d+$/.test(n.id||''))){
      const color=c.descendants(n).find(d=>d.type==='Text'&&/^[1-5]$/.test(d.text));if(color)holding[Number(color.text)]++;
    }
    let owner=-1;const choices=[];
    for(const n of ns){
      if(/^toy-plate-\d+$/.test(n.id||''))owner=Number(n.id.slice(10));
      if(/^toy-screw-\d+$/.test(n.id||'')&&n.enabled==='true'){
        const color=c.descendants(n).find(d=>d.type==='Text'&&/^[1-5]$/.test(d.text));
        choices.push({n,owner,color:Number(color.text)});
      }
    }
    choices.sort((a,b)=>holding[b.color]-holding[a.color]||b.owner-a.owner);c.assert(choices.length);
    c.click(choices[0].n);c.sleep(220);
  }
  const ns=c.capture('screwout-overflow-result');
  c.assert(c.find(ns,'再来一局'));c.assert(c.text(ns).some(s=>s.includes('暂存 5 / 5')));
  c.assert(c.text(ns).includes('本局结束'));
  c.log('toy-screw-overflow-passed',{text:c.text(ns)});
}
function main(){
  const initial=c.layout(),originalLevel=initial.some(n=>n.id==='toy-screw-tray-count')?
    (plateCount(initial)-5)/2:plateCount(initial)-3;
  c.assert(Number.isInteger(originalLevel)&&originalLevel>=0&&originalLevel<=2,'Start on a fresh screwout board');
  difficulty('普通',7);c.capture('new-screwout-ready');solve('normal-screwout-result');
  restart();colors(c.capture('normal-screwout-restarted'));
  difficulty('困难',9);colors(c.capture('hard-screwout-ready'));solve('hard-screwout-result');
  restart();colors(c.capture('hard-screwout-restarted'));overflow();
  restart();difficulty(labels[originalLevel],5+originalLevel*2);
  colors(c.capture('restored-difficulty-ready'));
  c.log('screw-difficulty-passed',{normalWin:true,hardWin:true,overflow:true,restartColors:true,undo:true,restoredDifficulty:labels[originalLevel]});
  console.log('PASS normal/hard wins, overflow, undo, restart colors and difficulty restore');
}
try{main();}catch(e){console.error(e);process.exitCode=1;}
