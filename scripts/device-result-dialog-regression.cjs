// Exercises result overlays using only the rendered real-device UI.
process.env.LITTLEGAMES_DEVICE_CHECKPOINT='mate60-result-dialog-progress.json';
process.env.LITTLEGAMES_DEVICE_LOG='mate60-result-dialog-actions.jsonl';
const c=require('./device-acceptance-core.cjs');
const {assert,fs,layout,text,find,click,tap,bounds,descendants,capture,sleep,open,back}=c;
const file='docs/device-acceptance/mate60-result-dialog-progress.json';
const update=fn=>{const p=JSON.parse(fs.readFileSync(file));fn(p);fs.writeFileSync(file,JSON.stringify(p,null,2)+'\n');};
const shot=id=>capture('result-mate60-'+id);
const tabs=()=>{let ns=layout();if(!find(ns,'我的')&&ns.some(n=>n.type==='TextInput'))c.shell('uitest','uiInput','keyEvent','Back');return c.wait(n=>find(n,'我的'));};
const settings=()=>{tabs();tap('我的');c.wait(n=>find(n,'设置'));tap('设置');return c.wait(n=>find(n,'主题模式'));};
const leaveSettings=()=>{c.shell('uitest','uiInput','keyEvent','Back');c.wait(n=>find(n,'分类'));tap('分类');c.wait(n=>n.some(x=>x.type==='TextInput'));};
const move=(cells,index)=>{click(cells[index]);sleep(120);};
const headerRestart=ns=>ns.find(n=>n.type==='Button'&&bounds(n)[0]>1000&&bounds(n)[1]<300);
const record=(id,cases,evidence)=>{update(p=>{p.results=p.results.filter(r=>r.id!==id);p.results.push({id,passedCases:cases,evidence,status:'passed-selected-cases',at:new Date().toISOString()});});console.log('PASS '+id);};
const mode=process.argv[2];
if(mode==='dark'||mode==='light'){
  settings();tap(mode==='dark'?'深色':'浅色');leaveSettings();
  open('井字棋');let ns=layout(),cells=c.board(ns),reset=headerRestart(ns);assert.equal(cells.length,9);assert(reset);
  for(const i of [0,3,1,4,2])move(cells,i);
  ns=c.result();assert(text(ns).includes('玩家 1 获胜'));shot(mode+'-win-after');
  // A tap on the covered restart button must not dismiss the modal.
  click(reset);sleep(250);assert(find(layout(),'再来一局'));shot(mode+'-blocked-after');
  c.restart();ns=layout();assert(text(ns).some(t=>t.includes('玩家 1 回合')));shot(mode+'-restart-after');
  cells=c.board(ns);assert.equal(cells.length,9);for(const i of [0,1,2,4,3,5,7,6,8])move(cells,i);
  ns=c.result();assert(text(ns).some(t=>t.includes('平局')));shot(mode+'-draw-after');
  back();record(mode+'-collection',['胜利和平局结算显示','遮罩拦住底层重开按钮','再来一局恢复空棋盘及首回合','结算退出返回列表'],[mode+'-win-after',mode+'-blocked-after',mode+'-restart-after',mode+'-draw-after'].map(s=>'result-mate60-'+s));
  open('扫雷');ns=layout();const grid=ns.filter(n=>n.type==='Column'&&n.clickable==='true'&&bounds(n)[1]>550&&bounds(n)[3]<2350).sort((a,b)=>Math.abs(bounds(a)[1]-bounds(b)[1])<20?bounds(a)[0]-bounds(b)[0]:bounds(a)[1]-bounds(b)[1]);assert.equal(grid.length,81);
  click(grid[40]);assert(!find(layout(),'再来一局'));
  for(let i=0;i<grid.length;i++){click(grid[i]);if(i%3===0&&find(layout(),'再来一局'))break;}
  ns=c.result();assert(text(ns).includes('踩到雷了'));shot(mode+'-loss-after');
  c.restart();assert(text(layout()).includes('0/10'));shot(mode+'-loss-restart-after');
  c.shell('uitest','uiInput','keyEvent','Back');ns=c.wait(n=>find(n,'确认退出？'));shot(mode+'-exit-confirm-after');tap('继续对局',ns);c.wait(n=>!find(n,'确认退出？'));assert(!layout().some(n=>n.type==='TextInput'));back();
  record(mode+'-full',['踩雷失败结算显示','再来一局恢复旗数','退出确认显示、取消后留在游戏、确认退出'],['loss-after','loss-restart-after','exit-confirm-after'].map(s=>'result-mate60-'+mode+'-'+s));
}else if(mode==='restore'){
  settings();const p=JSON.parse(fs.readFileSync(file));const original=p.original;assert(original);const theme=original.selected.find(s=>['跟随系统','浅色','深色'].includes(s));assert(theme);tap(theme);let ns=shot('settings-restored');
  const selected=ns.filter(n=>n.type==='Button'&&n.description==='已选择').flatMap(n=>descendants(n).filter(d=>d.type==='Text').map(d=>d.text));assert(original.selected.every(s=>selected.includes(s)));
  const labels={settings_remember_difficulty:'记住各游戏难度',settings_haptics:'震动反馈',settings_confirm_exit:'退出对局前确认'};
  for(const state of original.toggles){const row=ns.find(n=>n.type==='Row'&&descendants(n).some(d=>d.text===labels[state.key])&&descendants(n).some(d=>d.type==='Toggle'));assert(row);assert.equal(descendants(row).find(n=>n.type==='Toggle').checked,state.checked);}
  leaveSettings();tabs();tap('精选');shot('finished-home');update(p=>{p.finalState='original-preferences-restored-home';p.completedAt=new Date().toISOString();});
}else throw Error('Use dark, light or restore');
