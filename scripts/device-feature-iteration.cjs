/* Development emulator checks through rendered UI only; no application-state injection. */
process.env.LITTLEGAMES_ART_TARGET ||= '127.0.0.1:5555';
process.env.LITTLEGAMES_ART_OUTPUT ||= 'docs/device-acceptance/features-2026-10-13-v3';
const c = require('./device-art-review.cjs');
const strings = new Map(JSON.parse(c.fs.readFileSync('entry/src/main/resources/zh_CN/element/string.json', 'utf8')).string.map(s => [s.name, s.value]));
for (const [key,value] of strings) if (/^game_.+_name$/.test(key)) c.names[key.slice(5,-5)] = value;
const reportFile = c.path.join(c.dir, 'features.json');
const report = c.fs.existsSync(reportFile) ? JSON.parse(c.fs.readFileSync(reportFile,'utf8')) : {
  packageSha256:c.packageHash, target:c.target, scope:'Selected feature interactions on API 24 emulator; development test package', passed:[], failures:[]
};
c.assert.equal(report.packageSha256,c.packageHash,'Test package changed; choose a new evidence directory');
const byId = (ns,id) => ns.find(n=>n.id===id);
function save(){report.updatedAt=new Date().toISOString();c.fs.writeFileSync(reportFile,JSON.stringify(report,null,2)+'\n');}
function passed(name,details){report.passed.push({name,details,at:new Date().toISOString()});for(const failure of report.failures)if(failure.action===process.argv[2])failure.resolvedAt=new Date().toISOString();save();console.log('PASS '+name);}
function home(){
  let ns=c.layout();
  for(let i=0;i<8&&!c.find(ns,'精选');i++){
    if(c.find(ns,strings.get('exit_confirm_title')))c.tap(strings.get('exit_confirm_leave'),ns);
    else c.shell('uitest','uiInput','keyEvent','Back');
    c.sleep(200);ns=c.layout();
  }
  c.tap('精选',ns);return c.wait(a=>!byId(a,'home_category_search')&&!byId(a,'game-settings-button')&&a.some(n=>n.type==='Scroll'));
}
function category(){let ns=home();c.tap('分类',ns);return c.wait(a=>byId(a,'home_category_search'));}
function start(){c.shell('aa','start','-a','EntryAbility','-b','com.littlegames.collection');c.sleep(1200);return home();}
function vertical(ns,up){
  const scroll=ns.filter(n=>n.type==='Scroll').sort((a,b)=>{const x=c.bounds(a),y=c.bounds(b);return (y[2]-y[0])*(y[3]-y[1])-(x[2]-x[0])*(x[3]-x[1]);})[0];
  c.assert(scroll,'Vertical content not found');const b=c.bounds(scroll),x=Math.round((b[0]+b[2])/2);
  const top=Math.round(b[1]+(b[3]-b[1])*.2),bottom=Math.round(b[1]+(b[3]-b[1])*.75);
  c.shell('uitest','uiInput','swipe',''+x,''+(up?bottom:top),''+x,''+(up?top:bottom),'1800');c.sleep(200);return c.layout();
}
function top(){let ns=home();for(let i=0;i<5;i++){
  if(byId(ns,'featured-daily-inspiration')&&c.bounds(byId(ns,'featured-daily-inspiration'))[1]>300)return ns;
  ns=vertical(ns,false);
}return ns;}
const recommendationIds=ns=>ns.filter(n=>n.id?.startsWith('daily-game-')).map(n=>n.id.slice(11));
function recommendations(){let ns=top(),ids=new Set(recommendationIds(ns));for(let i=0;i<4&&ids.size<6;i++){ns=vertical(ns,true);for(const id of recommendationIds(ns))ids.add(id);}c.assert.equal(ids.size,6);return [...ids].sort();}
function daily(){
  let ns=top();const quote=byId(ns,'featured-daily-inspiration').text;const first=recommendations();
  c.capture('daily-before');ns=top();c.click(byId(ns,'featured-refresh-button'));c.sleep(250);
  const second=recommendations();c.assert(second.every(id=>!first.includes(id)));ns=top();c.assert.equal(byId(ns,'featured-daily-inspiration').text,quote);
  c.capture('daily-after-top');ns=vertical(ns,true);c.capture('daily-after-games');
  c.shell('aa','force-stop','com.littlegames.collection');start();c.assert.deepEqual(recommendations(),second);
  ns=top();c.assert.equal(byId(ns,'featured-daily-inspiration').text,quote);c.capture('daily-after-relaunch');
  passed('daily-refresh-and-persistence',{quote,before:first,after:second});
}
function enterGame(id){
  let ns=category();const clear=byId(ns,'home_search_clear');if(clear){c.click(clear);ns=c.layout();}
  const filterId='category_filter_'+(id==='linerescue'?1:3);
  for(let i=0;i<5&&!byId(ns,filterId);i++){
    const b=c.bounds(byId(ns,'home_category_filters')),right=id==='linerescue';c.shell('uitest','uiInput','swipe',''+Math.round(b[0]+(b[2]-b[0])*(right?.2:.9)),''+Math.round((b[1]+b[3])/2),''+Math.round(b[0]+(b[2]-b[0])*(right?.9:.2)),''+Math.round((b[1]+b[3])/2),'1600');ns=c.layout();
  }
  c.click(byId(ns,filterId));ns=c.layout();
  const scroll=()=>{const b=c.bounds(byId(c.layout(),'home_category_games'));return b;};
  for(let i=0;i<7;i++){const b=scroll(),x=Math.round((b[0]+b[2])/2);c.shell('uitest','uiInput','swipe',''+x,''+Math.round(b[1]+.2*(b[3]-b[1])),''+x,''+Math.round(b[1]+.8*(b[3]-b[1])),'3000');}
  const name=c.names[id],grid=scroll(),tabTop=c.bounds(ns.find(n=>n.type==='TabBar'))[1],card=n=>{const b=c.bounds(n),cy=(b[1]+b[3])/2;return n.type==='Column'&&n.clickable==='true'&&cy>grid[1]&&cy<Math.min(grid[3],tabTop)&&[n.text,n.description].some(text=>text?.startsWith(name+',')||text?.startsWith(name+'，'));};
  ns=c.layout();for(let i=0;i<18&&!ns.some(card);i++){const b=scroll(),x=Math.round((b[0]+b[2])/2);c.shell('uitest','uiInput','swipe',''+x,''+Math.round(b[1]+.8*(b[3]-b[1])),''+x,''+Math.round(b[1]+.2*(b[3]-b[1])),'2000');ns=c.layout();}
  c.assert(ns.some(card),'Game card absent: '+name);c.capture(id+'-entry-card');c.click(ns.find(card));return c.wait(a=>byId(a,'game-settings-button'));
}
function open(id){let ns=enterGame(id);if(byId(ns,id+'-save-prompt')){c.tap(strings.get('save_continue'),ns);ns=c.wait(a=>!byId(a,id+'-save-prompt'));}return ns;}
function rescue(){
  let ns=open('linerescue');const original=c.bounds(byId(ns,'linerescue-drawing-area'));c.assert.equal(byId(ns,'linerescue-start').enabled,'false');c.capture('rescue-ready');
  const point=(x,y)=>[Math.round(original[0]+x/360*(original[2]-original[0])),Math.round(original[1]+y/460*(original[3]-original[1]))];
  let previous=point(245,250);
  for(let i=1;i<=24;i++){const angle=i*2*Math.PI/24,next=point(180+65*Math.cos(angle),250+65*Math.sin(angle));c.shell('uitest','uiInput','swipe',''+previous[0],''+previous[1],''+next[0],''+next[1],'350');previous=next;}
  ns=c.layout();c.assert.deepEqual(c.bounds(byId(ns,'linerescue-drawing-area')),original,'Drawing scrolled the board');
  c.assert.equal(byId(ns,'linerescue-start').enabled,'true');const lines=ns.filter(n=>n.type==='Line').length;c.assert(lines>24,'Dense real drawing must exceed old sampling cap');c.capture('rescue-closed-line');
  c.click(byId(ns,'linerescue-start'));ns=c.wait(a=>c.find(a,strings.get('result_play_again')),35000);c.capture('rescue-win');
  c.assert(c.text(ns).includes(strings.get('collection_win')),'Protective circle did not win');
  c.assert(c.text(ns).includes(strings.get('expansion_progress').replace('%d','10').replace('%d','10')),'Rescue elapsed-time progress did not reach 10/10');
  c.tap(strings.get('result_play_again'),ns);ns=c.wait(a=>byId(a,'linerescue-start'));
  c.assert.equal(byId(ns,'linerescue-start').enabled,'false');const b=c.bounds(byId(ns,'linerescue-drawing-area'));
  c.shell('uitest','uiInput','swipe',''+Math.round(b[0]+20/360*(b[2]-b[0])),''+Math.round(b[1]+20/460*(b[3]-b[1])),''+Math.round(b[0]+90/360*(b[2]-b[0])),''+Math.round(b[1]+20/460*(b[3]-b[1])),'350');
  ns=c.wait(a=>byId(a,'linerescue-start')?.enabled==='true');c.click(byId(ns,'linerescue-start'));
  ns=c.wait(a=>c.find(a,strings.get('result_play_again')),35000);c.capture('rescue-loss');c.assert(c.text(ns).some(text=>/失败|结束/.test(text)));
  passed('line-rescue-drawing-win-loss-restart',{denseRenderedLines:lines,boardBounds:original});category();
}
function board(ns) {
  const squares=ns.filter(n=>['Stack','Column'].includes(n.type)&&Math.abs((c.bounds(n)[2]-c.bounds(n)[0])-(c.bounds(n)[3]-c.bounds(n)[1]))<10);
  const square=squares.sort((a,b)=>(c.bounds(b)[2]-c.bounds(b)[0])-(c.bounds(a)[2]-c.bounds(a)[0]))[0];c.assert(square,'Visible board absent');return c.bounds(square);
}
function boardSignature(ns,id){
  const b=board(ns),size=id==='2048'?4:9;
  return ns.filter(n=>n.type==='Text'&&/^\d+$/.test(n.text)).flatMap(n=>{
    const t=c.bounds(n),x=(t[0]+t[2])/2,y=(t[1]+t[3])/2;
    if(x<=b[0]||x>=b[2]||y<=b[1]||y>=b[3])return [];
    return [Math.floor((y-b[1])/(b[3]-b[1])*size)+':'+Math.floor((x-b[0])/(b[2]-b[0])*size)+':'+n.text];
  }).sort();
}
function saves(){
  for(const id of process.argv[3]?[process.argv[3]]:['2048','sudoku']){
    let ns=open(id);
    if(id==='2048'){
      const candidates=ns.filter(n=>n.type==='Stack'&&Math.abs((c.bounds(n)[2]-c.bounds(n)[0])-(c.bounds(n)[3]-c.bounds(n)[1]))<10);
      const square=candidates.sort((a,b)=>(c.bounds(b)[2]-c.bounds(b)[0])-(c.bounds(a)[2]-c.bounds(a)[0]))[0];c.assert(square);const b=c.bounds(square),cx=Math.round((b[0]+b[2])/2),cy=Math.round((b[1]+b[3])/2);
      for(let i=0;i<4;i++){c.shell('uitest','uiInput','swipe',''+Math.round(b[0]+.75*(b[2]-b[0])),''+cy,''+Math.round(b[0]+.25*(b[2]-b[0])),''+cy,'1000');c.shell('uitest','uiInput','swipe',''+cx,''+Math.round(b[1]+.25*(b[3]-b[1])),''+cx,''+Math.round(b[1]+.75*(b[3]-b[1])),'1000');}
    }else{
      const b=board(ns),blank=ns.find(n=>{const t=c.bounds(n);return n.type==='Stack'&&n.clickable==='true'&&t[0]>=b[0]&&t[1]>=b[1]&&t[2]<=b[2]&&t[3]<=b[3]&&!c.descendants(n).some(child=>child.type==='Text'&&/^\d+$/.test(child.text));});c.assert(blank,'No blank Sudoku cell');c.click(blank);ns=c.layout();
      const key=ns.find(n=>n.type==='Button'&&(n.text==='5'||c.descendants(n).some(child=>child.text==='5')));c.assert(key);c.click(key);
    }
    ns=c.capture(id+'-save-before');const signature=boardSignature(ns,id);c.assert(signature.length>0,'Visible board values missing');
    c.shell('aa','force-stop','com.littlegames.collection');start();ns=enterGame(id);c.assert(byId(ns,id+'-save-prompt'),'Resume choice missing after restart');c.capture(id+'-resume-prompt');
    c.tap(strings.get('save_continue'),ns);ns=c.wait(a=>!byId(a,id+'-save-prompt'));c.assert.deepEqual(boardSignature(ns,id),signature);c.capture(id+'-save-restored');
    passed(id+'-local-save-after-process-restart',{observedBoard:signature});category();
  }
}
function appearance(){
  home();
  try {
    c.theme('dark');top();c.capture('dark-daily');
    let ns=enterGame('sudoku');c.assert(byId(ns,'sudoku-save-prompt'));c.capture('dark-sudoku-save-prompt');
    c.tap(strings.get('save_continue'),ns);home();open('linerescue');c.capture('dark-rescue-ready');
  } finally { home();c.theme('restore');top();c.capture('theme-restored-home'); }
  passed('dark-feature-screens-and-theme-restoration',{screens:['dark-daily','dark-sudoku-save-prompt','dark-rescue-ready']});
}
const action=process.argv[2]||'daily';
try{start();if(action==='daily')daily();else if(action==='rescue')rescue();else if(action==='saves')saves();else if(action==='appearance')appearance();else throw Error('Unknown feature check');}
catch(error){report.failures.push({action,error:error.stack,at:new Date().toISOString()});save();try{c.capture(action+'-incomplete');}catch{}console.error(error.stack);process.exitCode=1;}
