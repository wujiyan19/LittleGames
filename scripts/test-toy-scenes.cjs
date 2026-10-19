/* Native lifecycle contracts and portable asset checks. These are not device rendering claims. */
const fs = require('node:fs');
const assert = require('node:assert/strict');
const { fixture } = require('./test-performance.cjs');
global.ModelType = { TEXTURE: 0 };
let count = 0;
const test = async (name, fn) => { await fn(); count++; console.log('PASS ' + name); };
const deferred = () => { let resolve, reject; const promise = new Promise((a,b) => { resolve=a; reject=b; }); return { promise,resolve,reject }; };
function scene() {
  const camera={name:'ToyCamera',enabled:false,clearColor:null,children:{count:()=>0},getProjectionMatrix:()=>({x:{x:1/90},y:{y:-1/115}})};
  const world={name:'world',scale:{x:1,y:1,z:1},children:{count:()=>0}};
  return { camera,world,environment:{},destroyed:0, frames:0, root:{name:'root',children:{count:()=>2,get:i=>i===0?camera:world}},
    destroy(){this.destroyed++;},renderFrame(){this.frames++;return true;} };
}
function setup(load) {
  const f=fixture();f.native['@kit.ArkGraphics3D']={Scene:{load},EnvironmentBackgroundType:{BACKGROUND_NONE:0}};
  const C=f.load('entry/src/main/ets/common/ToySceneController.ets').ToySceneController;
  return new C();
}
const background={r:.96,g:.94,b:.88,a:1};
async function main() {
  await test('the authored camera is enabled and a draw requests only one frame',async()=>{
    const s=scene(),c=setup(async()=>s);assert(await c.load('model',background));
    assert.equal(c.options.scene,s);assert.equal(c.options.modelType,0);assert(s.camera.enabled);
    assert.deepEqual(s.camera.clearColor,background);assert.equal(c.node('ToyCamera'),s.camera);
    c.draw();assert.equal(s.frames,1);assert.deepEqual(s.world.scale,{x:.5,y:.5,z:1});
    s.camera.getProjectionMatrix=()=>({x:{x:1/180},y:{y:1/230}});c.draw();assert.deepEqual(s.world.scale,{x:1,y:1,z:1});
    c.dispose();c.draw();assert.equal(s.frames,2);assert.equal(s.destroyed,1);
  });
  await test('leaving during asynchronous load destroys the late native scene',async()=>{
    const pending=deferred(),s=scene(),c=setup(()=>pending.promise),loading=c.load('model',background);
    c.dispose();pending.resolve(s);assert.equal(await loading,false);assert.equal(s.destroyed,1);
    assert.equal(c.options,undefined);assert.equal(c.scene,null);assert.equal(c.failed,false);
  });
  await test('a stale load never replaces the newer scene',async()=>{
    const a=deferred(),b=deferred(),first=scene(),second=scene();let calls=0;
    const c=setup(()=>++calls===1?a.promise:b.promise),old=c.load('old',background),current=c.load('new',background);
    b.resolve(second);assert(await current);a.resolve(first);assert.equal(await old,false);
    assert.equal(first.destroyed,1);assert.equal(c.scene,second);c.dispose();assert.equal(second.destroyed,1);
  });
  await test('load failures allow a clean retry without keeping a broken scene',async()=>{
    const s=scene();let calls=0;const c=setup(async()=>{if(++calls===1)throw Error('missing');return s;});
    assert.equal(await c.load('missing',background),false);assert(c.failed);assert.equal(c.options,undefined);
    assert(await c.load('model',background));assert.equal(c.failed,false);c.dispose();
  });
  await test('a scene without the required camera is destroyed and reported as failed',async()=>{
    const s=scene();s.root.children.count=()=>0;const c=setup(async()=>s);
    assert.equal(await c.load('bad',background),false);assert(c.failed);assert.equal(s.destroyed,1);assert.equal(c.scene,null);
  });
  for(const name of ['jump','jump_dark','rolling','rolling_dark']) await test(name+' GLB buffers, camera and texture-free material are valid',()=>{
    const data=fs.readFileSync(`entry/src/main/resources/rawfile/toy/${name}.glb`);
    assert.equal(data.readUInt32LE(0),0x46546c67);assert.equal(data.readUInt32LE(4),2);assert.equal(data.readUInt32LE(8),data.length);
    const length=data.readUInt32LE(12),g=JSON.parse(data.subarray(20,20+length).toString());
    const binaryStart=28+length;assert.equal(data.readUInt32LE(20+length),data.length-binaryStart);
    assert(!g.images&&!g.textures);assert(g.materials.every(m=>m.extensions.KHR_materials_unlit));
    assert.deepEqual(g.cameras[0].orthographic,{xmag:180,ymag:230,znear:.1,zfar:3000});
    for(const view of g.bufferViews)assert(view.byteOffset+view.byteLength<=g.buffers[0].byteLength);
    for(const accessor of g.accessors){const width=accessor.type==='VEC3'?3:1,bytes=accessor.componentType===5126?4:2;assert(accessor.count*width*bytes<=g.bufferViews[accessor.bufferView].byteLength);}
    const names=new Set(g.nodes.map(n=>n.name));assert(names.has('ToyCamera'));
    for(const node of name.startsWith('jump')?['player','shadow',...Array.from({length:14},(_,i)=>'platform'+i)]:['ball','goal','wall0','wall1','wall2','hole0','hole1','hole2'])assert(names.has(node),node);
    assert(data.length<500000,'per-scene mobile resource budget');
  });
  console.log(`${count}/${count} toy scene checks passed`);
}
main().catch(e=>{console.error(e);process.exitCode=1;});
