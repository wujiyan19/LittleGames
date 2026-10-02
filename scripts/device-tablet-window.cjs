// Tablet window checks through rendered UI, real input and HDC evidence.
const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const target = process.env.LITTLEGAMES_TABLET_TARGET || '49X0224C24001554';
const hdc = process.env.LITTLEGAMES_HDC || 'C:/Program Files/Huawei/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe';
const bundle = 'com.littlegames.collection';
const evidence = path.resolve('docs/device-acceptance/tablet-window-2026-10-02');
const scratch = path.resolve('entry/build/tablet-acceptance');
const python = process.env.LITTLEGAMES_PYTHON || 'C:/Users/29186/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe';
fs.mkdirSync(evidence,{recursive:true}); fs.mkdirSync(scratch,{recursive:true});
const packageHash = () => crypto.createHash('sha256').update(fs.readFileSync('entry/build/default/outputs/default/entry-default-signed.hap')).digest('hex').toUpperCase();
const sleep = ms => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)),0,0,ms);
const run = (...args) => {
  const out = cp.execFileSync(hdc,['-t',target,...args],{encoding:'utf8',timeout:20000});
  assert(!/^\s*\[Fail\]/m.test(out),'HDC channel failed'); return out;
};
const shell = (...args) => run('shell',...args);
const bounds = n => (n.bounds || '').match(/-?\d+/g)?.map(Number) || [];
let root, nodes;
function layout(system=false) {
  const file=path.join(scratch,system?'system-current.json':'current.json');
  const args=['uitest','dumpLayout','-p','/data/local/tmp/lg-tablet-window.json'];
  if(!system)args.push('-b',bundle);
  const out=shell(...args); assert(out.includes('saved to:'),'Layout dump failed');
  run('file','recv','/data/local/tmp/lg-tablet-window.json',file);
  root=JSON.parse(fs.readFileSync(file));nodes=[];
  const visit=(raw,parent)=>{if(raw.attributes?.bounds&&raw.attributes.visible!=='false')nodes.push({...raw.attributes,raw,parent});(raw.children||[]).forEach(n=>visit(n,raw));};visit(root,null);
  return nodes;
}
const text = ns => ns.filter(n=>n.text).map(n=>n.text);
const find = (ns,label) => ns.find(n=>n.clickable==='true'&&(n.text===label||n.description===label)) || ns.find(n=>n.text===label||n.description===label);
function click(n) {assert(n,'Observed UI target absent');const b=bounds(n);assert(b[2]>b[0]&&b[3]>b[1],'UI target has no area');shell('uitest','uiInput','click',String(Math.round((b[0]+b[2])/2)),String(Math.round((b[1]+b[3])/2)));}
function tap(label,ns=layout()) {click(find(ns,label));sleep(150);}
function wait(pred,timeout=15000) {const end=Date.now()+timeout;do{const ns=layout();if(pred(ns))return ns;sleep(180);}while(Date.now()<end);throw Error('Expected UI absent: '+text(nodes).join('|'));}
function open(name) {
  let ns=layout();if(!ns.some(n=>n.type==='TextInput')){tap('分类',ns);ns=wait(a=>a.some(n=>n.type==='TextInput'));}
  let input=ns.find(n=>n.type==='TextInput');
  if(input.text){const clear=input.parent.children.find(n=>n.attributes?.type==='Button');assert(clear,'Clear search absent');click(clear.attributes);ns=wait(a=>a.some(n=>n.type==='TextInput'&&!n.text));input=ns.find(n=>n.type==='TextInput');}
  const b=bounds(input);shell('uitest','uiInput','inputText',String(Math.round((b[0]+b[2])/2)),String(Math.round((b[1]+b[3])/2)),name);
  const card=n=>n.type==='Column'&&n.clickable==='true'&&[n.text,n.description].some(t=>t?.startsWith(name+',')||t?.startsWith(name+'，'));
  ns=wait(a=>a.some(card));click(ns.find(card));
  return wait(a=>a.some(n=>n.type==='Text'&&n.text===name)&&!a.some(n=>n.type==='TextInput')&&!find(a,'正在生成题目…'));
}
function back() {
  let ns=layout();if(ns.some(n=>n.type==='TextInput'))return ns;
  if(find(ns,'再来一局')&&find(ns,'退出'))tap('退出',ns);
  else{shell('uitest','uiInput','keyEvent','Back');ns=wait(a=>find(a,'确认退出？')||a.some(n=>n.type==='TextInput'));if(find(ns,'确认退出？'))tap('退出',ns);}
  return wait(a=>a.some(n=>n.type==='TextInput'));
}
function capture(id,system=false) {
  assert(/^[a-z0-9-]+$/.test(id));const ns=layout(system);
  const image=path.join(evidence,id+'.jpeg'),json=path.join(evidence,id+'.json');
  fs.writeFileSync(json,JSON.stringify(root));
  const fullImage=path.join(scratch,'full-display.jpeg');
  shell('snapshot_display','-f','/data/local/tmp/lg-tablet-window.jpeg');run('file','recv','/data/local/tmp/lg-tablet-window.jpeg',fullImage);
  const window=ns.find(n=>n.type==='Navigation'||n.type==='NavDestination');
  assert(window,'App window absent; system screenshots stay in scratch');
  const rectangle=bounds({bounds:window.origBounds||window.bounds});
  cp.execFileSync(python,[path.resolve('scripts/tablet-crop-evidence.py'),fullImage,image,...rectangle.map(String)],{timeout:20000});
  const record={at:new Date().toISOString(),target,packageHash:packageHash(),id,text:text(ns),window:ns.filter(n=>['Window','NavDestination','Navigation','Root','TabBar'].includes(n.type)).map(n=>({type:n.type,bounds:n.bounds})),image:path.relative(evidence,image)};
  fs.appendFileSync(path.join(evidence,'actions.jsonl'),JSON.stringify(record)+'\n');return ns;
}
const games=[['snake','贪吃蛇'],['tetris','俄罗斯方块'],['2048','2048'],['whackmole','打地鼠'],['minesweeper','扫雷'],['sudoku','数独'],['slidepuzzle','滑动拼图'],['klotski','华容道'],['guessnumber','猜数字'],['memorycard','记忆翻牌'],['jumpjump','跳一跳'],['brickbreaker','打砖块'],['match3','消消乐'],['tictactoe','井字棋'],['gomoku','五子棋'],['reversi','翻转棋'],['fourline','落子四连'],['nim','取石子'],['lights','十字熄灯'],['flood','色块归一'],['maze','迷宫寻路'],['hanoi','汉诺塔'],['peg','跳子独留'],['nonogram','数字绘格'],['arithmetic','心算十题'],['compare','算式比大小'],['sequence','数列推演'],['binary','二进制解码'],['targetsum','补数求和'],['schulte','数字寻序'],['memorysequence','顺序记忆'],['missing','记忆缺项'],['reaction','信号反应']];
function record(group,result) {const file=path.join(evidence,'progress.json');const p=fs.existsSync(file)?JSON.parse(fs.readFileSync(file)):{target,groups:{}};p.groups[group] ||= [];p.groups[group].push(result);fs.writeFileSync(file,JSON.stringify(p,null,2)+'\n');}
function summary(ns) {return ns.filter(n=>n.text||n.description||n.clickable==='true'||['Root','Window','NavDestination','Navigation'].includes(n.type)).map(n=>({type:n.type,text:n.text,description:n.description,bounds:n.bounds,origBounds:n.origBounds,clickable:n.clickable,id:n.id}));}
function smoke(mode,only) {
  for(const game of games.filter(g=>!only||only.split(',').includes(g[0]))) {
    const id=mode+'-'+game[0];
    try{let ns=open(game[1]);capture(id);const title=find(ns,game[1]);assert(title);assert(ns.some(n=>n.clickable==='true'&&bounds(n)[2]>bounds(n)[0]),'No touch targets');back();record(mode,{id:game[0],name:game[1],status:'entry-return-passed',evidence:id,packageHash:packageHash()});console.log('PASS '+game[1]);}
    catch(e){try{capture(id+'-failure');}catch(ignore){}record(mode,{id:game[0],name:game[1],status:'failed',error:e.message,evidence:id+'-failure'});console.log('FAIL '+game[1]+': '+e.message);throw e;}
  }
}
module.exports={fs,path,assert,target,bundle,evidence,scratch,run,shell,sleep,bounds,layout,text,find,click,tap,wait,open,back,capture,games,record,summary,smoke,packageHash};
if(require.main===module){const action=process.argv[2]||'observe';const args=process.argv.slice(3);if(action==='smoke')smoke(args[0],args[1]);else if(action==='open'){open(args[0]);console.log(JSON.stringify(summary(layout())));}else if(action==='tap'){tap(args[0]);console.log(JSON.stringify(summary(layout())));}else if(action==='back'){back();console.log(JSON.stringify(summary(layout())));}else if(action==='capture'){capture(args[0],args[1]==='system');console.log(JSON.stringify(summary(nodes)));}else console.log(JSON.stringify(summary(layout(action==='system'))));}
