// Real-device UI automation. Reads rendered layout/screens; never app model state.
const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');
const assert = require('node:assert/strict');
const target = 'FMR0224521016052';
const hdc = 'C:/Program Files/Huawei/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe';
const dir = path.resolve('docs/device-acceptance');
const scratch = path.resolve('entry/build/emulator-acceptance');
fs.mkdirSync(scratch, {recursive:true});
const checkpointName=process.env.LITTLEGAMES_DEVICE_CHECKPOINT || 'mate60-gameplay-progress.json';
const logName=process.env.LITTLEGAMES_DEVICE_LOG || 'mate60-gameplay-actions.jsonl';
assert.equal(path.basename(checkpointName), checkpointName);
assert.equal(path.basename(logName), logName);
const checkpoint=JSON.parse(fs.readFileSync(path.join(dir,checkpointName)));
const packageHash=require('node:crypto').createHash('sha256').update(fs.readFileSync('entry/build/default/outputs/default/entry-default-signed.hap')).digest('hex').toUpperCase();
assert.equal(checkpoint.target,target,'Device checkpoint differs');
assert.equal(checkpoint.packageHash,packageHash,'Candidate changed: start a new acceptance record');
let root, nodes;
const sleep = ms => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)),0,0,ms);
const run = (...args) => {
  const output=cp.execFileSync(hdc,['-t',target,...args],{encoding:'utf8',timeout:20000});
  // HDC sometimes returns exit code zero on a disconnected or unready channel.
  // Do not mistake a cached layout/screenshot for a new device observation.
  assert(!/^\s*\[Fail\]/m.test(output),'Device command failed: '+output.trim());
  return output;
};
const shell = (...args) => run('shell',...args);
const bounds = n => n.bounds.match(/-?\d+/g).map(Number);
const descendants = n => {const a=[];const visit=x=>{a.push(x.attributes);(x.children||[]).forEach(visit);};(n.raw.children||[]).forEach(visit);return a;};
function layout(){
  shell('uitest','dumpLayout','-p','/data/local/tmp/lg-continuous.json');
  const file=path.join(scratch,'continuous-layout.json');run('file','recv','/data/local/tmp/lg-continuous.json',file);
  root=JSON.parse(fs.readFileSync(file,'utf8'));nodes=[];
  const visit=(raw,parent)=>{if(raw.attributes?.bounds&&raw.attributes.visible!=='false')nodes.push({...raw.attributes,raw,parent});(raw.children||[]).forEach(c=>visit(c,raw));};visit(root,null);
  const gameNames=JSON.parse(fs.readFileSync('entry/src/main/resources/zh_CN/element/string.json')).string.filter(s=>/^game_.*_name$/.test(s.name)).map(s=>s.value);
  const anchor=nodes.find(n=>n.type==='Text'&&(gameNames.includes(n.text)||['玩趣盒','分类','精选','个人中心','设置','我的','关于软件'].includes(n.text)));
  assert(anchor,'Application is not foreground; unlock and launch the app before inspecting UI');
  const windows=new Set([anchor.hostWindowId]);nodes.filter(n=>['Menu','MenuItem','Dialog'].includes(n.type)).forEach(n=>windows.add(n.hostWindowId));
  nodes=nodes.filter(n=>windows.has(n.hostWindowId));return nodes;
}
const text = ns => ns.filter(n=>n.text).map(n=>n.text);
const find = (ns,label) => ns.find(n=>n.clickable==='true'&&(n.text===label||n.description===label))||ns.find(n=>n.text===label||n.description===label);
function click(n){assert(n,'UI target absent');const b=bounds(n);assert(b[2]>b[0]&&b[3]>b[1]);shell('uitest','uiInput','click',''+Math.round((b[0]+b[2])/2),''+Math.round((b[1]+b[3])/2));}
function tap(label,ns=layout()){click(find(ns,label));sleep(120);}
function wait(pred,timeout=12000){const end=Date.now()+timeout;do{const ns=layout();if(pred(ns))return ns;sleep(150);}while(Date.now()<end);throw Error('Expected UI not observed: '+text(nodes).join(' | '));}
function open(name){let ns=wait(a=>a.some(n=>n.type==='TextInput'));let input=ns.find(n=>n.type==='TextInput');if(input.text){const clear=input.parent.children.find(n=>n.attributes.type==='Button');assert(clear);click(clear.attributes);ns=wait(a=>a.some(n=>n.type==='TextInput'&&!n.text));input=ns.find(n=>n.type==='TextInput');}
 const b=bounds(input);let typed=false;for(let attempt=0;attempt<3;attempt++){shell('uitest','uiInput','inputText',''+Math.round((b[0]+b[2])/2),''+Math.round((b[1]+b[3])/2),name);sleep(350);ns=layout();if(ns.some(n=>n.type==='TextInput'&&n.text===name)){typed=true;break;}}assert(typed,'Search input was not committed');
 const card=n=>n.type==='Column'&&n.clickable==='true'&&[n.text,n.description].some(t=>t?.startsWith(name+',')||t?.startsWith(name+'，'));
 ns=wait(a=>a.some(card));click(ns.find(card));return wait(a=>a.some(n=>n.type==='Text'&&n.text===name)&&!a.some(n=>n.type==='TextInput'));
}
function back(){let ns=layout();if(ns.some(n=>n.type==='TextInput'))return ns;if(find(ns,'再来一局')&&find(ns,'退出')){tap('退出',ns);}else{shell('uitest','uiInput','keyEvent','Back');ns=wait(a=>find(a,'确认退出？')||a.some(n=>n.type==='TextInput'));if(find(ns,'确认退出？'))tap('退出',ns);}return wait(a=>a.some(n=>n.type==='TextInput'));}
function capture(id){const ns=layout();shell('snapshot_display','-f','/data/local/tmp/lg-continuous.jpeg');run('file','recv','/data/local/tmp/lg-continuous.jpeg',path.resolve('docs/screenshots',id+'.jpeg'));fs.mkdirSync(path.join(dir,'evidence'),{recursive:true});fs.writeFileSync(path.join(dir,'evidence',id+'.json'),JSON.stringify(root));log('capture',{id,text:text(ns)});return ns;}
function log(action,data){fs.appendFileSync(path.join(dir,logName),JSON.stringify({at:new Date().toISOString(),target,action,...data})+'\n');}
function record(name,id,cases,evidence,extra={}){const file=path.join(dir,checkpointName);const p=JSON.parse(fs.readFileSync(file));p.executionMode='continuous';delete p.batchSize;p.results=p.results.filter(r=>r.name!==name);p.results.push({name,id,checkedOn:p.checkedOn||'2026-09-30',packageHash,status:'passed-selected-cases',passedCases:cases,pendingCases:['长局性能及人手触感未量化'],evidence,...extra});fs.writeFileSync(file,JSON.stringify(p,null,2)+'\n');console.log('SAVED '+name+': '+cases.join('；'));}
function board(ns=layout()){return ns.filter(n=>n.type==='Button'&&bounds(n)[1]>380&&bounds(n)[2]-bounds(n)[0]>30&&Math.abs((bounds(n)[2]-bounds(n)[0])-(bounds(n)[3]-bounds(n)[1]))<8).sort((a,b)=>Math.abs(bounds(a)[1]-bounds(b)[1])<15?bounds(a)[0]-bounds(b)[0]:bounds(a)[1]-bounds(b)[1]);}
function choices(ns=layout()){return ns.filter(n=>n.type==='Button'&&bounds(n)[1]>380&&descendants(n).some(d=>d.type==='Text'&&/^[-\d＜＝＞]+$/.test(d.text))).map(n=>({node:n,value:descendants(n).find(d=>d.type==='Text'&&/^[-\d＜＝＞]+$/.test(d.text)).text}));}
function result(ns=layout()){assert(find(ns,'再来一局'),'No result dialog: '+text(ns).join('|'));return ns;}
function restart(ns=layout()){tap('再来一局',ns);return wait(a=>!find(a,'再来一局'));}
function pixels(id,buttons,kind){capture(id);const input=path.join(scratch,'pixels.json');fs.writeFileSync(input,JSON.stringify({file:path.resolve('docs/screenshots',id+'.jpeg'),bounds:buttons.map(bounds),kind}));const python='C:/Users/29186/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe';return JSON.parse(cp.execFileSync(python,[path.resolve('scripts/device-board-pixels.py'),input],{encoding:'utf8'}));}
module.exports={fs,path,assert,target,sleep,run,shell,bounds,descendants,layout,text,find,click,tap,wait,open,back,capture,log,record,board,choices,result,restart,pixels};
