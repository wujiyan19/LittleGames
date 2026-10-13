// Native HDC UI regression: inspect rendered nodes and send real touch gestures.
process.env.LITTLEGAMES_ART_TARGET ||= '49X0224C24001554';
process.env.LITTLEGAMES_ART_OUTPUT ||= 'docs/device-acceptance/fruitslice-refresh-2026-10-03';
const c = require('./device-art-review.cjs');
c.names.fruitslice = '切水果'; c.names.pingpong = '乒乓球'; c.names.shooter = '雷电战机';
const mode = process.argv[2] || 'light';
const checks = [];
const check = (name, details = {}) => { checks.push({ name, ...details }); c.log('fruitslice-check-passed', { mode, name, ...details }); console.log('PASS ' + name); };
const arena = ns => ns.find(n => n.type === 'Stack' && n.backgroundImage === 'true' && n.clip === 'true');
const sprites = ns => {
  const a = arena(ns); c.assert(a);
  return ns.filter(n => n.type === 'Image' && n.hierarchy.startsWith(a.hierarchy + ','))
    .map(n => ({ hashcode: n.hashcode, bounds: n.origBounds }));
};
const control = (ns, position) => ns.filter(n => n.type === 'Button' && c.bounds(n)[1] < 200)
  .sort((a, b) => c.bounds(a)[0] - c.bounds(b)[0])[position];
const restart = () => {
  const ns = c.layout();
  if (c.find(ns, '再来一局')) c.tap('再来一局', ns);
  else {
    c.click(control(ns, 3));
    const menu = c.wait(ns => c.find(ns, '重新开始') || c.find(ns, '点击开始') || c.find(ns, '再来一局'));
    if (c.find(menu, '重新开始')) c.tap('重新开始', menu);
    else if (c.find(menu, '再来一局')) c.tap('再来一局', menu);
  }
  return c.wait(ns => c.find(ns, '点击开始'));
};
const observedFrame = tag => {
  const ns = c.layout();
  const frame = { at: new Date().toISOString(), sprites: sprites(ns), text: c.text(ns) };
  c.fs.copyFileSync(c.path.join(c.dir, 'current.json'), c.path.join(c.dir, tag + '.json'));
  return frame;
};
const category = () => {
  const ns = c.layout();
  if (c.find(ns, '分类')) { c.tap('分类', ns); return c.wait(a => a.some(n => n.type === 'TextInput')); }
  return c.back();
};
try {
  if (mode === 'restore') {
    category(); c.theme('restore'); c.tap('精选', c.tabs()); c.capture('final-restored');
  } else {
    category(); c.theme(mode); c.open('fruitslice');
    c.capture('final-' + mode + '-ready');
    const ready = c.layout(); c.assert(c.text(ready).includes('失误 0 / 5'));
    check('five-miss counter and empty new game', { sprites: sprites(ready) });

    c.tap('点击开始', ready);
    const frames = [0, 1, 2].map(i => observedFrame('final-' + mode + '-frame-' + i));
    let movement;
    for (let i = 1; i < frames.length; i++) for (const p of frames[i - 1].sprites) {
      const q = frames[i].sprites.find(q => q.hashcode === p.hashcode);
      if (q && p.bounds !== q.bounds) movement = { hashcode: p.hashcode, before: p.bounds, after: q.bounds };
    }
    c.assert(movement, 'No reused image moved between native UI frames');
    check('same native fruit image updates its position', movement);

    const next = restart(), pause = control(next, 2);
    c.tap('点击开始', next); c.sleep(300); c.click(pause);
    c.wait(ns => c.find(ns, '继续游戏'));
    const frozen = observedFrame('final-' + mode + '-paused-a');
    c.assert(frozen.sprites.length > 0);
    c.capture('final-' + mode + '-paused');
    const still = observedFrame('final-' + mode + '-paused-b');
    c.assert.deepEqual(still.sprites, frozen.sprites);
    check('pause freezes fruit images', { sprites: frozen.sprites });
    c.tap('继续游戏'); const resumed = observedFrame('final-' + mode + '-resumed');
    c.assert.notDeepEqual(resumed.sprites, frozen.sprites);
    check('resume refreshes fruit images');

    let score = 0;
    for (let attempt = 0; attempt < 6 && score === 0; attempt++) {
      const ready = restart(), b = c.bounds(arena(ready));
      c.tap('点击开始', ready);
      for (const fraction of [0.9, 0.76, 0.68, 0.68, 0.78, 0.9]) {
        const y = Math.round(b[1] + (b[3] - b[1]) * fraction);
        c.shell('uitest', 'uiInput', 'swipe', '' + (b[0] + 20), '' + y, '' + (b[2] - 20), '' + y, '5000');
      }
      const after = observedFrame('final-' + mode + '-cut-attempt-' + attempt);
      score = Number(after.text.find(t => /^得分 \d+/.test(t)).match(/^得分 (\d+)/)[1]);
      c.log('native-fruit-swipes', { mode, attempt, score, text: after.text });
    }
    c.assert(score > 0, 'Real swipes did not cut a visible fruit');
    c.capture('final-' + mode + '-cut');
    check('real swipe cuts fruit and updates score', { score });
    const reset = restart(); c.assert.equal(sprites(reset).length, 0);
    c.assert(c.text(reset).includes('进度 0 / 30')); c.assert(c.text(reset).includes('失误 0 / 5'));
    c.capture('final-' + mode + '-restart');
    check('restart clears previous fruit images and progress');
    c.back();
    c.fs.writeFileSync(c.path.join(c.dir, 'final-' + mode + '-summary.json'), JSON.stringify({ target: c.target, packageHash: c.packageHash, mode, checks }, null, 2));
  }
} catch (e) { c.log('fruitslice-check-incomplete', { mode, message: e.stack }); console.error(e.stack); process.exitCode = 1; }
