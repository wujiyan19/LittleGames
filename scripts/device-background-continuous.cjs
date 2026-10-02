const c=require('./device-acceptance-core.cjs');
const {fs,assert,layout,open,back,click,tap,bounds,find,capture,sleep,text}=c;
const file='docs/device-acceptance/mate60-gameplay-progress.json';
const add=(name,cases,evidence)=>{const p=JSON.parse(fs.readFileSync(file)),r=p.results.find(r=>r.name===name);assert(r);r.passedCases.push(...cases);r.pendingCases=r.pendingCases.filter(s=>s!=='后台恢复');r.evidence.push(...evidence);fs.writeFileSync(file,JSON.stringify(p,null,2)+'\n');console.log('SUPPLEMENT '+name+': '+cases.join('；'));};
const pause=ns=>click(ns.filter(n=>n.type==='Button'&&bounds(n)[1]<300).sort((a,b)=>bounds(a)[0]-bounds(b)[0])[2]);
const signature=ns=>JSON.stringify({text:text(ns),images:ns.filter(n=>n.type==='Image'&&bounds(n)[1]>550&&bounds(n)[3]<2300).map(n=>n.bounds)});
for(const [name,id]of [['贪吃蛇','snake'],['打地鼠','whackmole'],['打砖块','brickbreaker'],['俄罗斯方块','tetris']]){
 back();open(name);let ns=layout();pause(ns);sleep(400);const a='supplement-mate60-'+id+'-before',b='supplement-mate60-'+id+'-after';const before=capture(a),sig=signature(before);c.shell('uitest','uiInput','keyEvent','Home');sleep(5000);c.shell('aa','start','-b','com.littlegames.collection','-a','EntryAbility');sleep(350);const after=capture(b);assert.equal(signature(after),sig,'Manually paused state changed across background');back();add(name,['手动暂停后后台停留 5 秒，返回保持棋盘/倒计时'],[a,b]);
}
back();open('跳一跳');let ns=layout();const before=ns.filter(n=>n.id.startsWith('jumpjump_')).map(n=>({id:n.id,bounds:n.bounds,text:n.text}));capture('supplement-mate60-jump-before');c.shell('uitest','uiInput','keyEvent','Home');sleep(5000);c.shell('aa','start','-b','com.littlegames.collection','-a','EntryAbility');sleep(300);ns=capture('supplement-mate60-jump-after');assert.deepEqual(ns.filter(n=>n.id.startsWith('jumpjump_')).map(n=>({id:n.id,bounds:n.bounds,text:n.text})),before);back();add('跳一跳',['待蓄力状态后台 5 秒再返回，角色、平台和得分保持'],['supplement-mate60-jump-before','supplement-mate60-jump-after']);
