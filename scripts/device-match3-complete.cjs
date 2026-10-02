const c=require('./device-acceptance-core.cjs'),{grid}=require('./device-standalone-continuous.cjs');
const {assert,layout,text,open,back,click,tap,bounds,find,capture,sleep,record}=c;
const stats=ns=>ns.filter(n=>n.type==='Text'&&/^\d+$/.test(n.text)&&bounds(n)[1]>300&&bounds(n)[1]<550).map(n=>Number(n.text));
const hasMatch=a=>a.some((v,i)=>(i%8<6&&v===a[i+1]&&v===a[i+2])||(i<48&&v===a[i+8]&&v===a[i+16]));
back();open('消消乐');click(layout().find(n=>n.type==='Button'&&bounds(n)[0]>1000&&bounds(n)[1]<300));sleep(600);capture('play-mate60-all-match3-complete-ready');let ns=layout(),status=stats(ns),steps=0,initial=status[2],invalid=false;
while(status[2]>0){
 const b=grid(layout()),a=c.pixels('play-mate60-all-match3-complete-board-'+steps,b,'gems'),legal=[],other=[];
 for(let i=0;i<64;i++)for(const j of [i%8<7?i+1:-1,i<56?i+8:-1])if(j>=0){const x=a.slice();[x[i],x[j]]=[x[j],x[i]];(a[i]!==a[j]&&hasMatch(x)?legal:other).push([i,j]);}
 if(!invalid){const p=other[0];click(b[p[0]]);sleep(350);click(b[p[1]]);sleep(350);assert.deepEqual(stats(layout()),status);invalid=true;capture('play-mate60-all-match3-complete-invalid');}
 let advanced=false;for(const [i,j]of [...legal,...other]){
  const now=grid(layout());click(now[i]);sleep(350);click(now[j]);sleep(400);ns=layout();const next=stats(ns);
  if(next[2]<status[2]){assert.equal(next[2],status[2]-1);assert(next[0]>status[0]);status=next;advanced=true;break;}
 }
 assert(advanced,'No swap advances rendered game');steps++;console.log('MATCH3 '+steps+'/'+initial+' score='+status[0]);
}
assert(find(ns,'再来一局'));capture('play-mate60-all-match3-complete-result');tap('再来一局',ns);sleep(300);assert.deepEqual([stats(layout())[0],stats(layout())[2]],[0,initial]);capture('play-mate60-all-match3-complete-restart');back();record('消消乐','match3',['不产生三连的交换还原且不扣步数','连续 '+steps+' 次成功交换与消除，结算 '+status[0]+' 分','剩余步数归零触发结束','再来一局恢复得分 0 和 '+initial+' 步','系统返回及退出确认'],['play-mate60-all-match3-complete-ready','play-mate60-all-match3-complete-invalid','play-mate60-all-match3-complete-result','play-mate60-all-match3-complete-restart']);
