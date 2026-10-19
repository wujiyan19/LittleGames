/** Original procedural toy models. Build tools only; the HAP has no JS 3D dependency.
 * npm install --prefix .local-tools/toy-art three@0.180.0 playwright-core@1.56.1
 * node scripts/generate-toy-art.mjs
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import * as T from '../.local-tools/toy-art/node_modules/three/build/three.module.js';
import { RoundedBoxGeometry } from '../.local-tools/toy-art/node_modules/three/examples/jsm/geometries/RoundedBoxGeometry.js';
import http from 'node:http';
import { chromium } from '../.local-tools/toy-art/node_modules/playwright-core/index.mjs';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const media = path.join(root, 'entry/src/main/resources/base/media');
const raw = path.join(root, 'entry/src/main/resources/rawfile/toy');
const docs = path.join(root, 'docs/art/toy');
fs.mkdirSync(raw, { recursive: true }); fs.mkdirSync(docs, { recursive: true });
const palette = ['#EC947F', '#E7BE6F', '#83BCA5', '#8DB8D0', '#ADA0C7', '#C4A17F'];
const light = new T.Vector3(-.45, .65, 1).normalize();
const assets = [];
const jobs = [];
const geometries = new Map();
function geometry(key, create) {if(!geometries.has(key))geometries.set(key,create());return geometries.get(key);}
function group(name) { const g = new T.Group(); g.name = name; return g; }
function mesh(g, geometry, color, x=0, y=0, z=0) {
  const m = new T.Mesh(geometry, new T.MeshBasicMaterial({color})); m.position.set(x,y,z); g.add(m); return m;
}
function box(g,w,h,d,r,color,x=0,y=0,z=0) { return mesh(g,geometry(['box',w,h,d,r].join(':'),()=>new RoundedBoxGeometry(w,h,d,2,r)),color,x,y,z); }
function ball(g,r,color,x=0,y=0,z=0,sx=1,sy=1,sz=1) {const m=mesh(g,geometry('ball:'+r,()=>new T.SphereGeometry(r,20,12)),color,x,y,z);m.scale.set(sx,sy,sz);return m;}
function cylinder(g,r,h,color,x=0,y=0,z=0) { const m=mesh(g,new T.CylinderGeometry(r,r,h,24),color,x,y,z);m.rotation.x=Math.PI/2;return m; }
function ring(g,r,t,color,x=0,y=0,z=0) { return mesh(g,new T.TorusGeometry(r,t,6,32),color,x,y,z); }
function screw() {
  const g=group('screw'); cylinder(g,7,13,'#A4A3A0',0,0,-3);
  cylinder(g,13,5,'#AAB6BE',0,0,4); ball(g,12,'#DCE2E0',0,0,5,1,1,.34);
  box(g,16,3,2,1,'#52646D',0,0,9); box(g,3,16,2,1,'#52646D',0,0,9);
  return g;
}
function plate(color) {
  const g=group('plate'); box(g,218,94,12,7,color,110,48,0);
  // Recesses correspond to the existing screw centres, with a shallow wood grain.
  for(const x of [26,104,182]) {cylinder(g,16,1,'#6F685A',x,66,7);cylinder(g,12,1,'#B8A28A',x,66,8);}
  for(const y of [16,24,37])box(g,110,1,.3,.2,'#FFFFFF',124,y,6.2).material.color.multiplyScalar(.83);
  return g;
}
function car(color) {
  const g=group('car');
  for(const x of [-15,15])for(const y of [-28,28])box(g,8,17,10,3,'#45525D',x,y,2);
  box(g,31,84,13,7,color,0,0,6); box(g,25,39,13,6,color,0,-3,16);
  box(g,23,10,2,3,'#486579',0,19,21); box(g,21,8,2,3,'#486579',0,-24,16);
  box(g,18,18,2,4,'#FFF4D8',0,-3,23);
  for(const x of [-10,10]) {box(g,7,4,2,1,'#FFF1C4',x,37,13);box(g,6,3,2,1,'#C46558',x,-38,12);}
  return g;
}
function frog() {
  const g=group('player');
  ball(g,16,'#6EA88A',0,17,0,1,.95,.8);ball(g,16,'#A6CC9F',0,30,1,1,.7,.82);
  for(const x of [-11,11]) {ball(g,7,'#9FC99D',x,39,2);ball(g,4.2,'#FFF6DE',x,40,7);ball(g,2,'#344D58',x,40,10);ball(g,7,'#76AD89',x,3,4,1,.5,.8);}
  ball(g,8,'#E2DFAB',0,19,11,1,1.1,.25);
  box(g,10,1.8,1.5,.7,'#527C65',0,29,13);
  return g;
}
function platform(color) {
  const g=group('platform');box(g,100,29,56,6,'#C5AA82',0,-16,0);box(g,100,10,58,4,color,0,0,1);
  // A bevel and visible top surface retain a precise horizontal landing edge.
  box(g,76,3,42,1,'#EFE4C4',0,6,-1);return g;
}
function floor(g,w,h,color) {box(g,w,h,12,10,'#B79A77',0,0,-12);box(g,w-10,h-10,9,8,color,0,0,-5);}
function rolling(dark=false) {
  const g=group('world');floor(g,358,458,dark?'#465867':'#EAE1CD');
  for(const x of [-174,174])box(g,8,450,10,3,'#BBA17D',x,0,2);
  for(const y of [-224,224])box(g,350,8,10,3,'#BBA17D',0,y,2);
  const b=group('ball');ball(b,16,'#81B7BD');
  const stripe=ring(b,15.6,2,'#F8EBD0');stripe.rotation.y=Math.PI/2;g.add(b);
  for(let i=0;i<3;i++){const w=group('wall'+i);box(w,240,16,22,4,palette[i+1],120,0,6);g.add(w);}
  for(let i=0;i<3;i++){const h=group('hole'+i);cylinder(h,15,1,'#B6A289',0,0,.2);cylinder(h,12,1,'#34444C',0,0,1);g.add(h);}
  const end=group('goal');ring(end,19,3,'#86B497',0,0,1);cylinder(end,15,1,'#B9D6AF',0,0,.5);
  box(end,3,30,3,1,'#725E4A',0,13,3);box(end,15,11,2,2,'#E3B96B',8,24,3);g.add(end);
  return g;
}
function jump(dark=false) {
  const g=group('world');
  for(let i=0;i<14;i++){const p=platform(palette[i%palette.length]);p.name='platform'+i;g.add(p);}
  g.add(frog());
  const shadow=group('shadow');ball(shadow,15,dark?'#314450':'#B5B59D',0,0,-28,1,.23,.05);g.add(shadow);
  return g;
}
// Render the actual geometry offline with vertex lighting, matching the GLB material.
function render(g, name, bounds, w, h) {
  const copy=g.clone(true);copy.traverse(m=>{if(m.isMesh)m.geometry=new T.BufferGeometry().copy(m.geometry);});
  copy.updateMatrixWorld(true);
  jobs.push({name,bounds,w,h,object:copy.toJSON()});
}
// Compact glTF 2.0 writer: shared mesh buffers, vertex-baked lighting and no textures.
function glb(g,name,cameraBounds) {
  const json={asset:{version:'2.0',generator:'LittleGames original procedural toy art'},scene:0,scenes:[{nodes:[]}],nodes:[],meshes:[],materials:[{name:'matte-toy',pbrMetallicRoughness:{baseColorFactor:[1,1,1,1],metallicFactor:0,roughnessFactor:.85},extensions:{KHR_materials_unlit:{}}}],extensionsUsed:['KHR_materials_unlit'],accessors:[],bufferViews:[],buffers:[],cameras:[{type:'orthographic',orthographic:{xmag:cameraBounds[0],ymag:cameraBounds[1],znear:.1,zfar:3000}}]};
  const chunks=[];let size=0;const geometries=new Map();
  const acc=(array,type,componentType,min,max)=>{const buf=Buffer.from(array.buffer,array.byteOffset,array.byteLength);const padded=Buffer.alloc(Math.ceil(buf.length/4)*4);buf.copy(padded);const view=json.bufferViews.length;json.bufferViews.push({buffer:0,byteOffset:size,byteLength:buf.length});chunks.push(padded);size+=padded.length;const index=json.accessors.length;json.accessors.push({bufferView:view,componentType,count:array.length/(type==='SCALAR'?1:3),type,...(min?{min,max}:{})});return index;};
  const visit=o=>{const node={name:o.name||'part',translation:o.position.toArray(),rotation:o.quaternion.toArray(),scale:o.scale.toArray()};const id=json.nodes.length;json.nodes.push(node);
    if(o.isMesh){const key=o.geometry.uuid+o.material.color.getHexString();let mi=geometries.get(key);
      if(mi===undefined){const geom=o.geometry,p=geom.attributes.position,n=geom.attributes.normal,positions=new Float32Array(p.array),colors=new Float32Array(p.count*3),normals=new Float32Array(n.array);const box3=new T.Box3().setFromBufferAttribute(p);
        // glTF vertex colors are linear. The phone renderer performs display conversion.
        for(let i=0;i<p.count;i++){const normal=new T.Vector3().fromBufferAttribute(n,i);const c=o.material.color.clone().multiplyScalar(.76+.24*Math.max(0,normal.dot(light)));colors.set([c.r,c.g,c.b],i*3);}
        const primitive={attributes:{POSITION:acc(positions,'VEC3',5126,box3.min.toArray(),box3.max.toArray()),NORMAL:acc(normals,'VEC3',5126),COLOR_0:acc(colors,'VEC3',5126)},material:0};
        if(geom.index)primitive.indices=acc(new Uint16Array(geom.index.array),'SCALAR',5123);
        mi=json.meshes.length;json.meshes.push({primitives:[primitive]});geometries.set(key,mi);
      }node.mesh=mi;
    }
    if(o.children.length)node.children=o.children.map(visit);return id;
  };
  json.scenes[0].nodes.push(visit(g));json.nodes.push({name:'ToyCamera',camera:0,translation:[0,0,1000]});json.scenes[0].nodes.push(json.nodes.length-1);
  json.buffers.push({byteLength:size});let j=Buffer.from(JSON.stringify(json));const padded=Buffer.alloc(Math.ceil(j.length/4)*4,32);j.copy(padded);const bin=Buffer.concat(chunks);
  const header=Buffer.alloc(12);header.writeUInt32LE(0x46546c67);header.writeUInt32LE(2,4);header.writeUInt32LE(28+padded.length+bin.length,8);
  const jh=Buffer.alloc(8);jh.writeUInt32LE(padded.length);jh.writeUInt32LE(0x4e4f534a,4);const bh=Buffer.alloc(8);bh.writeUInt32LE(bin.length);bh.writeUInt32LE(0x004e4942,4);
  const data=Buffer.concat([header,jh,padded,bh,bin]);fs.writeFileSync(path.join(raw,name+'.glb'),data);assets.push({name:'toy/'+name+'.glb',bytes:data.length,nodes:json.nodes.length,meshes:json.meshes.length});
}
render(screw(),'toy_screw',[-18,18,18,-18],108,108);
const slot=group('slot');cylinder(slot,16,1,'#BDAB90');cylinder(slot,12,1,'#766C60',0,0,1);cylinder(slot,9,1,'#514E49',0,0,2);
render(slot,'toy_slot',[-18,18,18,-18],108,108);
for(let i=0;i<5;i++)render(plate(palette[i]),'toy_plate_'+i,[0,220,96,0],660,288);
for(let i=0;i<6;i++)render(car(palette[i]),'toy_car_'+i,[-22,22,46,-46],132,276);
for(const theme of ['base','dark']) {
  const dark=theme==='dark',bg=dark?'#344653':'#F1E8D4',edge=dark?'#6D756E':'#C7B38E',line=dark?'#536671':'#D8CBB2';
  const frame=(h)=>`<rect x="1" y="1" width="358" height="${h-2}" rx="18" fill="${edge}"/><rect x="7" y="7" width="346" height="${h-14}" rx="13" fill="${bg}"/>`;
  const svg=(h,body)=>`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 360 ${h}" width="360" height="${h}">${frame(h)}${body}</svg>\n`;
  const screws=[[17,17],[343,17],[17,443],[343,443]].map(([x,y])=>`<circle cx="${x}" cy="${y}" r="4" fill="${line}"/><path d="M${x-2} ${y}h4" stroke="${edge}" stroke-width="1.5"/>`).join('');
  const grid=Array.from({length:17},(_,i)=>{const p=10+i*21.25;return `<path d="M10 ${p}H350M${p} 10V350" stroke="${line}" stroke-width=".6" opacity=".5"/>`;}).join('');
  const dir=path.join(root,`entry/src/main/resources/${theme}/media`);fs.mkdirSync(dir,{recursive:true});
  for(const [name,body]of [['toy_screw_board.svg',svg(460,screws)],['toy_parking_board.svg',svg(360,grid)]]){
    fs.writeFileSync(path.join(dir,name),body);assets.push({name:theme+'/'+name,bytes:Buffer.byteLength(body),packaged:true});
  }
}
for(const dark of [false,true]) {
  const suffix=dark?'_dark':'';const j=jump(dark);glb(j,'jump'+suffix,[180,230]);
  const r=rolling(dark);glb(r,'rolling'+suffix,[180,230]);
  for(let i=0;i<3;i++){const n=r.getObjectByName('wall'+i);n.position.set(i%2===0?-180:-60,110-i*100,0);}
  for(let i=0;i<3;i++)r.getObjectByName('hole'+i).position.set(110-i*70,-100+i*100,0);
  r.getObjectByName('ball').position.set(-140,-180,15);r.getObjectByName('goal').position.set(140,185,0);
  render(r,'toy_rolling_preview'+suffix,[-180,180,230,-230],720,920);
  j.children.filter(n=>n.name.startsWith('platform')).forEach((p,i)=>{p.visible=i<3;p.position.set(-115+i*145,0,0);});
  // Offline renderer traverses visible meshes only in the preview scene below.
  for(const p of [...j.children])if(p.name.startsWith('platform')&&Number(p.name.slice(8))>=3)j.remove(p);
  j.getObjectByName('player').position.set(-115,0,18);j.getObjectByName('shadow').position.set(-115,0,0);
  render(j,'toy_jump_preview'+suffix,[-180,180,160,-300],720,920);
}
const server=http.createServer((req,res)=>{
  if(req.url==='/'){res.setHeader('Content-Type','text/html');res.end('<!doctype html><html><body></body></html>');return;}
  const file=path.resolve(root,'.'+decodeURIComponent(req.url));
  const allowed=path.join(root,'.local-tools','toy-art','node_modules')+path.sep;
  if(!file.startsWith(allowed)||!fs.existsSync(file)){res.writeHead(404);res.end();return;}
  res.setHeader('Content-Type','text/javascript');res.end(fs.readFileSync(file));
});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const port=server.address().port;
const browser=await chromium.launch({executablePath:process.env.TOY_ART_BROWSER||'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
try {
  const page=await browser.newPage({viewport:{width:1080,height:1080},deviceScaleFactor:1});
  await page.goto(`http://127.0.0.1:${port}/`);
  await page.evaluate(async url=>{window.T=await import(url);},`http://127.0.0.1:${port}/.local-tools/toy-art/node_modules/three/build/three.module.js`);
  for(const job of jobs){
    await page.setViewportSize({width:job.w,height:job.h});
    await page.evaluate(job=>{
      const T=window.T;window.renderer?.dispose();document.body.innerHTML='';document.body.style.margin='0';document.body.style.background='transparent';
      const renderer=new T.WebGLRenderer({alpha:true,antialias:true,preserveDrawingBuffer:true});window.renderer=renderer;renderer.setClearColor(0,0);renderer.setSize(job.w,job.h);document.body.append(renderer.domElement);
      const g=new T.ObjectLoader().parse(job.object),light=new T.Vector3(-.45,.65,1).normalize();
      g.traverse(m=>{if(!m.isMesh)return;const geom=m.geometry.clone(),n=geom.attributes.normal,colors=new Float32Array(n.count*3);
        for(let i=0;i<n.count;i++){const normal=new T.Vector3().fromBufferAttribute(n,i);const c=m.material.color.clone().multiplyScalar(.76+.24*Math.max(0,normal.dot(light)));colors.set([c.r,c.g,c.b],i*3);}
        geom.setAttribute('color',new T.BufferAttribute(colors,3));m.geometry=geom;m.material=new T.MeshBasicMaterial({vertexColors:true});
      });
      const scene=new T.Scene();scene.add(g);const camera=new T.OrthographicCamera(...job.bounds,.1,3000);camera.position.z=1000;renderer.render(scene,camera);
    },job);
    const preview=job.name.includes('_preview');const output=path.join(preview?docs:media,job.name+'.png');
    await page.locator('canvas').screenshot({path:output,omitBackground:true});
    assets.push({name:preview?'preview/'+job.name+'.png':job.name+'.png',bytes:fs.statSync(output).size,packaged:!preview});
    const old=path.join(media,job.name+'.png');if(preview&&fs.existsSync(old))fs.unlinkSync(old);
  }
} finally {await browser.close();await new Promise(resolve=>server.close(resolve));}
fs.writeFileSync(path.join(docs,'manifest.json'),JSON.stringify({style:'fixed camera, matte toy materials, original geometry, no external textures',dependencies:{three:'0.180.0','playwright-core':'1.56.1'},assets,totalBytes:assets.filter(a=>a.packaged!==false).reduce((n,a)=>n+a.bytes,0)},null,2)+'\n');
console.log(JSON.stringify({assets:assets.length,packagedBytes:assets.filter(a=>a.packaged!==false).reduce((n,a)=>n+a.bytes,0)}));
