// Positive regression checks on the rendered UI of the replacement candidate.
process.env.LITTLEGAMES_DEVICE_CHECKPOINT='mate60-fix-progress.json';
process.env.LITTLEGAMES_DEVICE_LOG='mate60-fix-actions.jsonl';
const c=require('./device-acceptance-core.cjs');
const {assert,fs,layout,text,find,click,tap,bounds,descendants,capture,sleep,open,back}=c;
const file='docs/device-acceptance/mate60-fix-progress.json';
const read=()=>JSON.parse(fs.readFileSync(file));
const update=fn=>{const p=read();fn(p);fs.writeFileSync(file,JSON.stringify(p,null,2)+'\n');};
const strings=JSON.parse(fs.readFileSync('entry/src/main/resources/zh_CN/element/string.json')).string;
const tr=key=>strings.find(s=>s.name===key).value;
const shot=id=>capture('fix-mate60-'+id);
const restart=()=>{click(layout().find(n=>n.type==='Button'&&bounds(n)[0]>1000&&bounds(n)[1]<300));sleep(300);};
const cards=ns=>{const flex=ns.find(n=>n.type==='Flex'&&n.raw.children.length>0&&n.raw.children.every(x=>x.attributes.type==='Stack'));assert(flex);return descendants(flex).filter(n=>n.type==='Text'&&/^\d+$/.test(n.text)).map(n=>n.text);};
const tabs=()=>{let ns=layout();if(!find(ns,'我的')&&ns.some(n=>n.type==='TextInput'))c.shell('uitest','uiInput','keyEvent','Back');return c.wait(n=>find(n,'我的'));};
const settings=()=>{tabs();tap('我的');c.wait(ns=>find(ns,tr('settings_title')));tap(tr('settings_title'));return c.wait(ns=>find(ns,tr('settings_theme')));};
const leaveSettings=()=>{c.shell('uitest','uiInput','keyEvent','Back');c.wait(ns=>find(ns,'分类'));tap('分类');return c.wait(ns=>ns.some(n=>n.type==='TextInput'));};
const selected=ns=>ns.filter(n=>n.type==='Button'&&n.description===tr('settings_selected')).flatMap(n=>descendants(n).filter(d=>d.type==='Text').map(d=>d.text));
const toggle=(ns,label)=>{const row=ns.find(n=>n.type==='Row'&&descendants(n).some(d=>d.text===label)&&descendants(n).some(d=>d.type==='Toggle'));assert(row);return ns.find(n=>n.type==='Toggle'&&descendants(row).some(d=>d.hashcode===n.hashcode));};
const selectedCheck=(theme,difficulty,ns=layout())=>{const labels=selected(ns);assert.equal(labels.length,2);assert(labels.includes(tr(theme))&&labels.includes(tr(difficulty)),labels.join('|'));};
const grid=ns=>ns.filter(n=>n.type==='Column'&&n.clickable==='true'&&bounds(n)[1]>550&&bounds(n)[3]<2350).sort((a,b)=>Math.abs(bounds(a)[1]-bounds(b)[1])<20?bounds(a)[0]-bounds(b)[0]:bounds(a)[1]-bounds(b)[1]);
const phase=process.argv[2];
if(phase==='memory'){
  back();open('记忆缺项');restart();const ev=[];
  for(let q=0;q<10;q++){
    let ns=c.wait(n=>find(n,'记好了')&&text(n).some(t=>t.startsWith('第 '+(q+1)+' / 10')));
    const before=cards(ns);assert.equal(before.length,5);shot('missing-'+q+'-before');ev.push('fix-mate60-missing-'+q+'-before');
    tap('记好了',ns);ns=c.wait(n=>!find(n,'记好了')&&c.choices(n).length===5);
    const after=cards(ns),removed=before.filter(v=>!after.includes(v));assert.equal(after.length,4);assert.equal(removed.length,1);
    assert(before.every(v=>c.choices(ns).some(o=>o.value===v)));shot('missing-'+q+'-after');ev.push('fix-mate60-missing-'+q+'-after');
    click(c.choices(ns).find(o=>o.value===removed[0]).node);sleep(300);
    ns=layout();assert(!text(ns).some(t=>t.includes('正确答案')));console.log('MISSING '+(q+1)+'/10 removed '+removed[0]);
  }
  const end=shot('missing-win');assert(find(end,'再来一局'));assert(text(end).some(t=>t.includes('挑战完成')));assert(text(end).some(t=>t.includes('2000')));ev.push('fix-mate60-missing-win');
  c.record('记忆缺项','missing',['连续十题从可见数字推导缺项，全部判定正确','结算 2000 分','顶部重开刷新题面'],ev);back();
  open('顺序记忆');const sequences=[];const seqEv=[];
  for(let round=0;round<3;round++){
    if(round===0)restart();else {tap('再来一局');c.wait(n=>find(n,'记好了'));if(round===2)restart();}
    let ns=c.wait(n=>find(n,'记好了'));const shown=cards(ns);sequences.push(shown);assert(shown.length>=4);
    shot('memorysequence-'+round+'-shown');seqEv.push('fix-mate60-memorysequence-'+round+'-shown');
    tap('记好了',ns);const bs=c.board(layout());for(const value of shown){click(bs[Number(value)-1]);sleep(120);}
    ns=shot('memorysequence-'+round+'-win');assert(find(ns,'再来一局'));assert(text(ns).includes('挑战完成'));seqEv.push('fix-mate60-memorysequence-'+round+'-win');console.log('MEMORY '+shown.join(','));
  }
  c.record('顺序记忆','memorysequence',['初次顶部重开、结算重开和再次顶部重开后均按可见序列通关'],seqEv,{sequences});back();
}else if(phase==='mine'){
  back();open('扫雷');restart();let ns=layout(),bs=grid(ns);assert.equal(bs.length,81);const states=[];
  const long=n=>{const z=bounds(n);c.shell('uitest','uiInput','longClick',''+Math.round((z[0]+z[2])/2),''+Math.round((z[1]+z[3])/2));sleep(200);};
  for(const index of [0,8,72,80]){
    long(bs[index]);ns=c.wait(n=>text(n).includes('1/10'));states.push('1/10');click(bs[index]);assert(text(layout()).includes('1/10'));
    shot('mine-'+index+'-flag');long(bs[index]);ns=c.wait(n=>text(n).includes('0/10'));states.push('0/10');shot('mine-'+index+'-unflag');
  }
  click(bs[40]);ns=shot('mine-safe');assert(!find(ns,'再来一局'));long(bs[40]);assert(text(layout()).includes('0/10'));
  restart();ns=shot('mine-restart');assert(text(ns).includes('0/10'));
  c.record('扫雷','minesweeper',['四个角格中心长按均可插旗、取消','旗格短按不揭开','首点安全，已揭开格长按不插旗','顶部重开清零'],['fix-mate60-mine-0-flag','fix-mate60-mine-0-unflag','fix-mate60-mine-8-unflag','fix-mate60-mine-72-unflag','fix-mate60-mine-80-unflag','fix-mate60-mine-safe','fix-mate60-mine-restart'],{states});back();
}else if(phase==='klotski'){
  back();open('华容道');restart();
  const blocks=ns=>ns.filter(n=>n.type==='Stack'&&n.clickable==='true'&&descendants(n).some(d=>['曹','将','兵'].includes(d.text))).map(n=>({node:n,b:bounds(n),label:descendants(n).find(d=>['曹','将','兵'].includes(d.text)).text}));
  const center=p=>[(p.b[0]+p.b[2])/2,(p.b[1]+p.b[3])/2];
  let ns=shot('klotski-before'),ps=blocks(ns);const start=ps.filter(p=>p.label==='兵').sort((a,b)=>b.b[1]-a.b[1]||a.b[0]-b.b[0])[0];
  const [x,y]=center(start);click(start.node);const controls=layout().filter(n=>n.type==='Button'&&bounds(n)[1]>2000).sort((a,b)=>bounds(a)[1]-bounds(b)[1]||bounds(a)[0]-bounds(b)[0]);assert.equal(controls.length,5);
  click(controls[3]);ns=shot('klotski-right');assert(text(ns).some(t=>t.includes('步数')&&t.includes('1')));
  let moved=blocks(ns).find(p=>p.label==='兵'&&Math.abs(center(p)[1]-y)<8&&center(p)[0]>x+100&&center(p)[0]<x+400);assert(moved,'Right move was not rendered');
  click(moved.node);click(controls[4]);ns=layout();assert(text(ns).some(t=>t.includes('步数')&&t.includes('1')),'Tap at the moved coordinates must deselect');
  moved=blocks(ns).find(p=>p.label==='兵'&&Math.abs(center(p)[1]-y)<8&&center(p)[0]>x+100&&center(p)[0]<x+400);click(moved.node);click(controls[4]);ns=shot('klotski-down');assert(text(ns).some(t=>t.includes('步数')&&t.includes('2')));assert(blocks(ns).some(p=>p.label==='兵'&&center(p)[1]>y+100&&center(p)[0]>x+100&&center(p)[0]<x+400));
  restart();ns=shot('klotski-restart');assert(text(ns).some(t=>t.includes('步数')&&t.includes('0')));
  ps=blocks(ns);const widest=Math.max(...ps.map(p=>p.b[2]-p.b[0]));const cell=Math.max(...ps.map(p=>p.b[2]-p.b[0]).filter(w=>w<widest*0.75))+13;
  const x0=Math.min(...ps.map(p=>p.b[0])),y0=Math.min(...ps.map(p=>p.b[1]));
  const pieces=ps.map(p=>({w:Math.round((p.b[2]-p.b[0])/cell),h:Math.round((p.b[3]-p.b[1])/cell),x:Math.round((p.b[0]-x0)/cell),y:Math.round((p.b[1]-y0)/cell),target:p.label==='曹'}));
  const dirs=[[0,-1],[1,0],[0,1],[-1,0]],key=a=>a.map(p=>`${p.w}${p.h}:${p.x}${p.y}`).sort().join('|');
  const queue=[{a:pieces,prev:-1}],seen=new Set([key(pieces)]);let goal=-1;
  for(let at=0;at<queue.length&&at<150000;at++){
    const a=queue[at].a;if(a.some(p=>p.target&&p.x===1&&p.y===3)){goal=at;break;}
    for(let i=0;i<a.length;i++)for(let d=0;d<4;d++){
      const [dx,dy]=dirs[d],p=a[i],x=p.x+dx,y=p.y+dy;
      if(x<0||y<0||x+p.w>4||y+p.h>5||a.some((o,j)=>j!==i&&x<o.x+o.w&&x+p.w>o.x&&y<o.y+o.h&&y+p.h>o.y))continue;
      const next=a.map((o,j)=>j===i?{...o,x,y}:o),hash=key(next);if(seen.has(hash))continue;
      seen.add(hash);queue.push({a:next,prev:at,piece:i,dir:d});
    }
  }
  assert(goal>=0,'No path from the rendered starting layout');const route=[];
  for(let at=goal;queue[at].prev>=0;at=queue[at].prev)route.unshift(queue[at]);
  let live=pieces,selectedPiece=-1;const pad=[controls[0],controls[3],controls[4],controls[1]];
  for(let i=0;i<route.length;i++){
    const step=route[i],p=live[step.piece];
    if(selectedPiece!==step.piece){c.shell('uitest','uiInput','click',''+Math.round(x0+p.x*cell+(p.w*cell-13)/2),''+Math.round(y0+p.y*cell+(p.h*cell-13)/2));selectedPiece=step.piece;}
    click(pad[step.dir]);live=step.a;
    if((i+1)%10===0){assert(text(layout()).some(t=>t.includes('步数')&&t.match(/\d+/)?.[0]===''+(i+1)));console.log('KLOTSKI '+(i+1)+'/'+route.length);}
  }
  ns=shot('klotski-win');assert(find(ns,'再来一局'));assert(text(ns).some(t=>t.includes('成功')));tap('再来一局');shot('klotski-result-restart');
  c.record('华容道','klotski',['初始左下兵右移、下移实际渲染','移动后新坐标可选中/取消','步数副标题即时显示 0→1→2','重开棋块复位','按实际显示布局连续移动 '+route.length+' 步通关及结算重开'],['fix-mate60-klotski-before','fix-mate60-klotski-right','fix-mate60-klotski-down','fix-mate60-klotski-restart','fix-mate60-klotski-win','fix-mate60-klotski-result-restart'],{winSteps:route.length});back();
}else if(phase==='klotski-difficulties'){
  back();open('华容道');const ev=[];
  const blocks=ns=>ns.filter(n=>n.type==='Stack'&&n.clickable==='true'&&descendants(n).some(d=>['曹','将','兵'].includes(d.text)));
  for(const difficulty of ['easy','hard','normal']){
    let ns=layout();const header=ns.filter(n=>n.type==='Button'&&bounds(n)[1]<300).sort((a,b)=>bounds(a)[0]-bounds(b)[0]);assert.equal(header.length,3);click(header[1]);c.wait(n=>find(n,tr('diff_'+difficulty)));tap(tr('diff_'+difficulty));
    ns=c.wait(n=>text(n).includes('步数 0')&&!n.some(x=>x.type==='Menu'));const bs=blocks(ns),widths=bs.map(n=>bounds(n)[2]-bounds(n)[0]),widest=Math.max(...widths),cell=Math.max(...widths.filter(w=>w<widest*0.75))+13,x0=Math.min(...bs.map(n=>bounds(n)[0])),y0=Math.min(...bs.map(n=>bounds(n)[1]));
    const pieces=bs.map(n=>{const z=bounds(n);return {n,w:Math.round((z[2]-z[0])/cell),h:Math.round((z[3]-z[1])/cell),x:Math.round((z[0]-x0)/cell),y:Math.round((z[1]-y0)/cell)};});
    const pad=ns.filter(n=>n.type==='Button'&&bounds(n)[1]>2000).sort((a,b)=>bounds(a)[1]-bounds(b)[1]||bounds(a)[0]-bounds(b)[0]);assert.equal(pad.length,5);const directions=[[0,-1,pad[0]],[1,0,pad[3]],[0,1,pad[4]],[-1,0,pad[1]]];let move;
    for(let i=0;i<pieces.length&&!move;i++)for(const [dx,dy,button] of directions){const p=pieces[i],x=p.x+dx,y=p.y+dy;if(x<0||y<0||x+p.w>4||y+p.h>5||pieces.some((o,j)=>j!==i&&x<o.x+o.w&&x+p.w>o.x&&y<o.y+o.h&&y+p.h>o.y))continue;move={p,button,x,y};break;}
    assert(move);click(move.p.n);click(move.button);ns=c.wait(n=>text(n).includes('步数 1'));assert(blocks(ns).some(n=>{const z=bounds(n);return Math.abs((z[0]-x0)/cell-move.x)<0.1&&Math.abs((z[1]-y0)/cell-move.y)<0.1;}));
    const id='klotski-'+difficulty+'-move';shot(id);ev.push('fix-mate60-'+id);restart();assert(text(layout()).includes('步数 0'));
  }
  c.record('华容道难度切换','klotski-difficulties',['简单、困难、普通切换后棋块重新布局','各难度按可见空位执行一次合法移动，步数更新','重开复位'],ev);back();
}else if(phase==='settings'){
  back();let ns=settings();update(p=>{if(!p.original)p.original={selected:selected(ns),toggles:['settings_remember_difficulty','settings_haptics','settings_confirm_exit'].map(k=>({key:k,checked:toggle(ns,tr(k)).checked}))};});shot('settings-original');
  let difficulty='diff_normal';tap(tr(difficulty));
  for(const theme of ['settings_theme_light','settings_theme_dark','settings_theme_system']){tap(tr(theme));ns=c.wait(n=>selected(n).includes(tr(theme)));selectedCheck(theme,difficulty,ns);shot('settings-'+theme);}
  for(const key of ['diff_easy','diff_hard','diff_normal']){tap(tr(key));ns=c.wait(n=>selected(n).includes(tr(key)));selectedCheck('settings_theme_system',key,ns);difficulty=key;shot('settings-'+key);}
  for(const key of ['settings_remember_difficulty','settings_haptics','settings_confirm_exit']){ns=layout();const before=toggle(ns,tr(key)).checked;click(toggle(ns,tr(key)));c.wait(n=>toggle(n,tr(key)).checked!==before);click(toggle(layout(),tr(key)));c.wait(n=>toggle(n,tr(key)).checked===before);}
  tap(tr('settings_theme_dark'));tap(tr('diff_hard'));selectedCheck('settings_theme_dark','diff_hard');shot('settings-immediate-dark-hard');
  c.shell('aa','force-stop','com.littlegames.collection');sleep(600);c.shell('aa','start','-b','com.littlegames.collection','-a','EntryAbility');c.wait(n=>find(n,'我的'));ns=settings();selectedCheck('settings_theme_dark','diff_hard',ns);shot('settings-cold-dark-hard');
  leaveSettings();open('猜数字');assert(text(layout()).includes('_____'));shot('settings-default-hard');back();ns=settings();tap(tr('diff_normal'));selectedCheck('settings_theme_dark','diff_normal');tap(tr('settings_theme_system'));leaveSettings();
  c.record('设置','settings',['三种主题、三种难度切换立即更新选中标记','浅色/深色选中项文字可读','三个开关切换后恢复','冷启动保存深色与困难','新局采用五位密码的困难模式'],['fix-mate60-settings-original','fix-mate60-settings-settings_theme_light','fix-mate60-settings-settings_theme_dark','fix-mate60-settings-immediate-dark-hard','fix-mate60-settings-cold-dark-hard','fix-mate60-settings-default-hard']);
}else if(phase==='settings-reset'){
  back();tabs();tap('我的');let ns=c.wait(n=>find(n,'最近玩过'));const before=text(ns);shot('reset-profile-before');ns=settings();
  tap(tr('settings_theme_dark'));tap(tr('diff_hard'));
  for(const [key,value] of [['settings_remember_difficulty','true'],['settings_haptics','false'],['settings_confirm_exit','false']]){let n=toggle(layout(),tr(key));if(n.checked!==value)click(n);assert.equal(toggle(layout(),tr(key)).checked,value);}
  ns=shot('reset-changed');for(let i=0;i<3&&!find(ns,tr('settings_reset'));i++){c.shell('uitest','uiInput','swipe','620','2180','620','850','600');sleep(250);ns=layout();}
  tap(tr('settings_reset'),ns);ns=c.wait(n=>find(n,tr('settings_restore'))&&find(n,tr('settings_cancel')));shot('reset-confirm');tap(tr('settings_restore'),ns);c.wait(n=>!find(n,tr('settings_cancel')));
  for(let i=0;i<3;i++){c.shell('uitest','uiInput','swipe','620','850','620','2180','600');sleep(200);}
  ns=shot('reset-default-immediate');selectedCheck('settings_theme_system','diff_normal',ns);
  for(const [key,value] of [['settings_remember_difficulty','false'],['settings_haptics','true'],['settings_confirm_exit','true']])assert.equal(toggle(ns,tr(key)).checked,value);
  c.shell('uitest','uiInput','keyEvent','Back');ns=c.wait(n=>find(n,'最近玩过'));assert.deepEqual(text(ns),before);shot('reset-profile-after');tap('分类');c.wait(n=>n.some(x=>x.type==='TextInput'));
  c.record('恢复默认设置','settings-reset',['主题、难度和三个开关同页立即恢复默认','个人战绩和最近列表保持'],['fix-mate60-reset-changed','fix-mate60-reset-confirm','fix-mate60-reset-default-immediate','fix-mate60-reset-profile-before','fix-mate60-reset-profile-after']);
}else if(phase==='stats'){
  back();tabs();tap('我的');let ns=c.wait(n=>find(n,'最高分'));const before=text(ns);shot('stats-before');settings();tap(tr('diff_hard'));leaveSettings();open('心算十题');restart();
  for(let q=0;q<10;q++){
    ns=c.wait(n=>text(n).some(t=>t.startsWith('第 '+(q+1)+' / 10')));const prompt=text(ns).find(t=>t.includes(' = ?'));assert(prompt);const values=prompt.match(/\d+/g).map(Number);
    const answer=prompt.includes('+')?values[0]+values[1]:prompt.includes('−')?values[0]-values[1]:values[0]*values[1];const option=c.choices(ns).find(o=>o.value===''+answer);assert(option);click(option.node);sleep(200);
  }
  ns=shot('stats-score-3000');assert(find(ns,'再来一局'));assert(text(ns).some(t=>t.includes('3000')));back();tabs();tap('我的');ns=c.wait(n=>find(n,'最高分'));shot('stats-after');
  const title=find(ns,'最高分'),card=ns.find(n=>n.raw===title.parent);assert(card);assert(descendants(card).some(n=>n.text==='3000 挑战分'));
  const shown=text(ns),at=shown.indexOf('最近玩过');assert.equal(shown[at+1],'心算十题');
  c.record('个人统计','stats',['困难心算十题全对得 3000 分','同一进程返回后最高分卡片和排行榜更新','最近游戏首项立即更新'],['fix-mate60-stats-before','fix-mate60-stats-score-3000','fix-mate60-stats-after'],{before,after:shown});settings();tap(tr('diff_normal'));leaveSettings();
}else if(phase==='recent'){
  back();tabs();tap('我的');let ns=c.wait(n=>find(n,'最近玩过'));shot('recent-before');const before=text(ns);tap('分类');c.wait(n=>n.some(x=>x.type==='TextInput'));open('记忆缺项');restart();back();tabs();tap('我的');ns=c.wait(n=>find(n,'最近玩过'));shot('recent-after');const shown=text(ns),at=shown.indexOf('最近玩过');assert.equal(shown[at+1],'记忆缺项');
  c.record('最近玩过','recent',['同一进程中新开游戏、返回后立即排在最近列表首位'],['fix-mate60-recent-before','fix-mate60-recent-after'],{before,after:shown});tap('分类');c.wait(n=>n.some(x=>x.type==='TextInput'));
}else if(phase==='smoke-light'||phase==='smoke-dark'){
  back();const mode=phase.split('-')[1];settings();tap(tr('settings_theme_'+mode));tap(tr('diff_normal'));leaveSettings();
  const games=JSON.parse(fs.readFileSync('docs/device-acceptance/mate60-light-progress.json')).results;
  for(const game of games){if(read().smoke[mode].some(r=>r.name===game.name))continue;open(game.name);const slug=game.slug||game.screenshot.split('accept-mate60-light-')[1].replace('.jpeg','');const ns=shot(mode+'-'+slug);assert(!ns.some(n=>n.type==='TabBar'));back();update(p=>p.smoke[mode].push({name:game.name,slug,evidence:'fix-mate60-'+mode+'-'+slug,entered:true,returned:true}));console.log('SMOKE '+mode+' '+read().smoke[mode].length+'/33 '+game.name);}
}else if(phase==='restore'){
  back();settings();const orig=read().original;assert(orig);const theme=['settings_theme_system','settings_theme_light','settings_theme_dark'].find(k=>orig.selected.includes(tr(k)));const difficulty=['diff_easy','diff_normal','diff_hard'].find(k=>orig.selected.includes(tr(k)));assert(theme&&difficulty);tap(tr(theme));tap(tr(difficulty));
  for(const state of orig.toggles){let n=toggle(layout(),tr(state.key));if(n.checked!==state.checked)click(n);assert.equal(toggle(layout(),tr(state.key)).checked,state.checked);}selectedCheck(theme,difficulty);shot('settings-restored');leaveSettings();tabs();tap('精选');shot('finished-home');update(p=>{p.finalState='original-preferences-restored-home';p.completedAt=new Date().toISOString();});
}else throw Error('Choose memory, mine, klotski, settings, recent, smoke-light, smoke-dark or restore');
