/* Rendered UI only. Set LITTLEGAMES_ART_TARGET to a phone or emulator explicitly. */
process.env.LITTLEGAMES_ART_TARGET ||= '127.0.0.1:5555';
process.env.LITTLEGAMES_ART_OUTPUT ||= 'docs/device-acceptance/toy-art-2026-10-19';
const c = require('./device-art-review.cjs');
const strings=JSON.parse(c.fs.readFileSync('entry/src/main/resources/zh_CN/element/string.json','utf8')).string;
for(const item of strings)if(/^game_.+_name$/.test(item.name))c.names[item.name.slice(5,-5)]=item.value;
function category(){let ns=c.layout();if(ns.some(n=>n.type==='TextInput'))return ns;
  if(ns.some(n=>n.id==='game-settings-button'))return c.back();
  c.tap('分类',ns);return c.wait(a=>a.some(n=>n.type==='TextInput'));
}
function open(id){category();c.open(id);c.sleep(600);return c.layout();}
function front(id,tag=id+'-ready'){open(id);c.capture(tag);console.log('CAPTURE '+tag);}
function theme(mode){category();let ns=c.layout();c.click(ns.find(n=>n.id==='home_settings_button'));
  ns=c.wait(a=>c.find(a,'主题模式'));
  const originalFile=c.path.join(c.dir,'original-settings.json');
  if(!c.fs.existsSync(originalFile)){
    const selected=ns.filter(n=>n.type==='Button'&&n.description==='已选择').flatMap(c.descendants).map(n=>n.text);
    const selectedTheme=selected.find(t=>['浅色','深色','跟随系统'].includes(t));c.assert(selectedTheme,'Selected theme absent');
    c.fs.writeFileSync(originalFile,JSON.stringify({theme:selectedTheme},null,2)+'\n');
  }
  const label=mode==='restore'?JSON.parse(c.fs.readFileSync(originalFile)).theme:mode==='dark'?'深色':'浅色';
  c.tap(label,ns);c.sleep(400);c.capture('settings-'+mode);c.shell('uitest','uiInput','keyEvent','Back');
  c.wait(a=>a.some(n=>n.id==='home_settings_button'));category();
}
function result(ns){return !!c.find(ns,'再来一局');}
function solved(id){const ns=c.capture(id+'-result');c.assert(result(ns),'Natural result dialog absent');
  if(id!=='jumpjump')c.assert(c.text(ns).includes(strings.find(s=>s.name==='collection_win').value),'A winning result was required');
  c.log('toy-interaction-passed',{id,scope:'rendered UI on explicit HDC target',text:c.text(ns)});console.log('PASS '+id);}
function screws(){let ns=c.layout();
  if(!ns.some(n=>n.id==='toy-screw-board')){open('screwout');ns=c.layout();}
  if(ns.some(n=>n.id==='toy-screw-tray-count')){
    const plates=ns.filter(n=>n.id?.startsWith('toy-plate-')).map(n=>{const b=c.bounds(n);return {id:Number(n.id.slice(10)),x:b[0],y:b[1],w:b[2]-b[0],h:b[3]-b[1]};});
    const screws=[];let owner=-1;
    for(const n of ns){
      if(n.id?.startsWith('toy-plate-'))owner=Number(n.id.slice(10));
      if(/^toy-screw-\d+$/.test(n.id||'')){
        const b=c.bounds(n),color=c.descendants(n).find(d=>d.type==='Text'&&/^[1-5]$/.test(d.text));c.assert(color,'Expected numbered screw head');
        screws.push({id:Number(n.id.slice(10)),color:Number(color.text),owner,x:(b[0]+b[2])/2,y:(b[1]+b[3])/2,r:(b[2]-b[0])*.4});
      }
    }
    const capacity=Number(ns.find(n=>n.id==='toy-screw-tray-count').text.match(/\/\s*(\d+)/)[1]);
    for(const color of [1,2,3,4,5])c.assert.equal(screws.filter(s=>s.color===color).length%3,0,'Rendered colors must remain balanced after restart or a difficulty change');
    const solution=require('./screw-layout-solver.cjs').solve(plates,screws,capacity);c.assert(solution.route,'No solution found from rendered geometry');
    c.capture('screwout-layered-ready');c.log('toy-screw-ui-route',{plates:plates.length,screws:screws.length,capacity,visited:solution.visited});
    const expectedHolding=[0,0,0,0,0,0];
    for(let i=0;i<solution.route.length;i++){
      const id=solution.route[i];ns=c.layout();const button=ns.find(n=>n.id==='toy-screw-'+id);
      const holding=[0,0,0,0,0,0];for(const slot of ns.filter(n=>/^toy-screw-slot-\d+$/.test(n.id||''))){
        const color=c.descendants(slot).find(d=>d.type==='Text'&&/^[1-5]$/.test(d.text));if(color)holding[Number(color.text)]++;
      }c.assert.deepEqual(holding,expectedHolding,'Rendered holding colors must follow each actual removal and triple recycle');
      c.assert(button&&button.enabled==='true','Planned screw is not exposed in the actual UI: '+id);c.click(button);c.sleep(220);
      const color=screws.find(s=>s.id===id).color;expectedHolding[color]=(expectedHolding[color]+1)%3;
      if(i===0){c.capture('screwout-tray-filled');c.tap('撤销上一步');c.assert(c.layout().some(n=>n.id==='toy-screw-'+id));c.click(button);c.sleep(220);}
    }
    c.wait(result);solved('screwout');return;
  }
  for(let i=0;i<18;i++){const ns=c.layout();if(result(ns)){solved('screwout');return;}
    const buttons=ns.filter(n=>n.id?.startsWith('toy-screw-')&&n.enabled==='true');c.assert(buttons.length);
    buttons.sort((a,b)=>c.bounds(b)[1]-c.bounds(a)[1]||c.bounds(a)[0]-c.bounds(b)[0]);c.click(buttons[0]);c.sleep(200);
    if(i===0)c.capture('screwout-tray-filled');
  }throw Error('Screw result absent');
}
function parking(){open('parkingjam');
  for(let i=0;i<30;i++){const ns=c.layout();if(result(ns)){solved('parkingjam');return;}
    const cars=ns.filter(n=>n.id?.startsWith('toy-car-'));
    const car=cars.find(a=>!cars.some(b=>{if(a===b)return false;const x=c.bounds(a),y=c.bounds(b),dir=c.descendants(a).find(d=>/^[↑→↓←]$/.test(d.text)).text;
      return dir==='↑'?y[3]<=x[1]&&y[0]<x[2]&&y[2]>x[0]:dir==='↓'?y[1]>=x[3]&&y[0]<x[2]&&y[2]>x[0]:dir==='←'?y[2]<=x[0]&&y[1]<x[3]&&y[3]>x[1]:y[0]>=x[2]&&y[1]<x[3]&&y[3]>x[1];}));
    c.assert(car,'No observed clear exit');c.click(car);c.sleep(200);
    if(i===0){c.capture('parkingjam-one-left');c.tap('撤销上一步');c.assert.equal(c.layout().filter(n=>n.id?.startsWith('toy-car-')).length,cars.length);c.click(car);}
  }throw Error('Parking result absent');
}
function jumps(){let ns=open('jumpjump');for(let i=0;i<3;i++){
    const area=c.bounds(ns.find(n=>n.id==='jumpjump_area')),x=Math.round((area[0]+area[2])/2),y=Math.round(area[1]+(area[3]-area[1])*.65);
    c.shell('uitest','uiInput','longClick',''+x,''+y);c.sleep(900);ns=c.layout();
    c.assert.equal(ns.find(n=>n.id==='jumpjump_score').text,''+(i+1));c.capture('jumpjump-landed-'+(i+1));
  }
  const area=c.bounds(ns.find(n=>n.id==='jumpjump_area'));c.shell('uitest','uiInput','click',''+Math.round((area[0]+area[2])/2),''+Math.round((area[1]+area[3])/2));
  c.wait(result);solved('jumpjump');
}
function rolling(){let ns=open('rollingball');c.capture('rollingball-before');
  c.tap('点击开始',ns);
  for(const [tx,ty]of [[325,410],[325,275],[40,275],[40,175],[325,175],[325,45]]){
    let reached=false;
    for(let step=0;step<20;step++){
      ns=c.capture('rollingball-motion');if(result(ns)){solved('rollingball');return;}
      const area=c.bounds(ns.find(n=>n.id==='toy-rolling-scene')),scale=(area[2]-area[0])/360;
      const png=c.path.join(c.dir,'rollingball-motion.jpeg');
      const p=JSON.parse(c.cp.execFileSync('C:/Users/29186/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe',
        ['scripts/toy-ball-pixels.py',png,JSON.stringify(area)],{encoding:'utf8'}));
      const x=(p.x-area[0])/scale,y=(p.y-area[1])/scale;
      c.log('toy-ball-observed',{x,y,waypoint:[tx,ty],pixels:p.pixels});
      const dx=tx-x,dy=ty-y;
      if(Math.hypot(dx,dy)<14){reached=true;break;}
      // Reissue the visible waypoint while the inertial ball moves; screenshot latency
      // must not turn an old relative offset into a target behind the moving ball.
      for(let sample=0;sample<6;sample++){
        c.shell('uitest','uiInput','click',''+Math.round(area[0]+tx*scale),''+Math.round(area[1]+ty*scale));c.sleep(120);
      }
    }
    c.assert(reached,'Rendered ball did not reach the waypoint');
  }
  c.wait(result);solved('rollingball');
}
async function main(){const action=process.argv[2],id=process.argv[3];
  if(action==='front')front(id,process.argv[4]);
  else if(action==='observe')console.log(JSON.stringify(c.layout().filter(n=>n.text||n.description||n.clickable==='true').map(n=>({type:n.type,text:n.text,description:n.description,bounds:n.bounds,id:n.id,enabled:n.enabled}))));
  else if(action==='capture')c.capture(id);
  else if(action==='back')c.back();
  else if(action==='tap')c.tap(id);
  else if(action==='screws')screws();
  else if(action==='parking')parking();
  else if(action==='jumps')jumps();
  else if(action==='rolling')rolling();
  else if(action==='theme')theme(id);
  else throw Error('Expected front, observe, capture, back or tap');
}
if(require.main===module)main().catch(e=>{console.error(e);process.exitCode=1;});
module.exports={...c,open,category,front,theme};
