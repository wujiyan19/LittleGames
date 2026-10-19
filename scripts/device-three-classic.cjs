module.exports = c => {
  const { assert, layout, texts, descendants, bounds, center, find, click, tap, batch, wait, sleep, outcome, grid, nums, shell, swipe } = c;
  const v = require('./device-three-vision-api.cjs')(c), solvers = {};
  solvers['2048'] = round => {
    const ns = layout(), area = ns.find(n => n.type === 'Stack' && n.clickable !== 'true' && bounds(n)[1] > 500 && bounds(n)[2] - bounds(n)[0] > 900);
    assert(area); const xy = center(area), d = 280, dirs = [[xy[0] + d, xy[1], xy[0] - d, xy[1]], [xy[0], xy[1] + d, xy[0], xy[1] - d], [xy[0] - d, xy[1], xy[0] + d, xy[1]], [xy[0], xy[1] - d, xy[0], xy[1] + d]];
    let seed = 119 + round;
    for (let moves = 0; moves < 900; moves += 8) {
      if (outcome(layout())) return { strategy: 'real four-direction swipe game to natural blocked/win result', swipes: moves };
      const commands = []; for (let j = 0; j < 8; j++) { seed = (seed * 1664525 + 1013904223) >>> 0; commands.push('uitest uiInput swipe ' + dirs[seed >>> 28 & 3].join(' ') + ' 12000'); }
      shell(commands.join('; '));
    } throw Error('2048 swipe limit');
  };
  solvers.memorycard = () => {
    const cells = grid(); assert([12, 16, 24].includes(cells.length));
    const names = ['sun', 'moon', 'star', 'heart', 'clover', 'bolt', 'crown', 'diamond', 'spiral', 'leaf', 'shell', 'flame'].map(n => 'play_memory_' + n), known = [], done = new Set();
    const sample = i => {
      const b = bounds(cells[i]), xy = center(cells[i]), half = (b[2] - b[0]) * .35;
      const face = { bounds: '[' + Math.round(xy[0] - half) + ',' + Math.round(xy[1] - half) + '][' + Math.round(xy[0] + half) + ',' + Math.round(xy[1] + half) + ']' };
      return v.classify([face], names)[0];
    };
    let pairs = 0;
    for (let i = 0; i < cells.length; i++) if (!done.has(i)) {
      click(cells[i]); sleep(60); known[i] = sample(i);
      const knownPair = known.findIndex((name, at) => at !== i && name === known[i] && !done.has(at));
      const other = knownPair >= 0 ? knownPair : cells.findIndex((node, at) => at !== i && !done.has(at)); assert(other >= 0);
      click(cells[other]); sleep(900);
      const ns = layout(), matched = texts(ns).find(t => /^已配对 \d+ \/ \d+$/.test(t)); assert(matched);
      const now = +matched.match(/\d+/)[0];
      if (now > pairs) { known[other] = known[i]; done.add(i); done.add(other); }
      if (knownPair >= 0) assert(now > pairs, 'Actual pair did not match the remembered first-card artwork');
      pairs = now;
    }
    assert.equal(done.size, cells.length);
    return { strategy: 'memorized actual revealed face artwork and matched all pairs', faces: known };
  };
  solvers.match3 = () => {
    const matchesAt = (a, i) => {
      for (const d of [1, 8]) {
        let count = 1;
        for (const sign of [-1, 1]) for (let j = i + d * sign; j >= 0 && j < 64 && (d === 8 || Math.floor(j / 8) === Math.floor(i / 8)) && a[j] === a[i]; j += d * sign) count++;
        if (count >= 3) return true;
      }
      return false;
    };
    const rejected = new Set(); let previous = '', previousMove = '';
    for (let moves = 0; moves < 80; moves++) {
      const ns = layout(); if (outcome(ns)) return { strategy: 'spent actual moves using screenshot-derived legal gem swaps', moves };
      const cells = grid(ns); assert.equal(cells.length, 64);
      const images = cells.map(n => descendants(n).find(d => d.type === 'Image')); assert(images.every(Boolean));
      const names = c.fs.readdirSync(c.path.join(c.root, 'entry/src/main/resources/base/media')).filter(n => /^play_gem_.*\.svg$/.test(n)).map(n => n.slice(0, -4)); assert.equal(names.length, 6);
      const a = v.classify(images, names), signature = a.join(','); let move;
      if (signature === previous) rejected.add(previousMove);
      for (let i = 0; i < 64 && !move; i++) for (const j of [i % 8 < 7 ? i + 1 : -1, i < 56 ? i + 8 : -1]) if (j >= 0) {
        const next = a.slice(); [next[i], next[j]] = [next[j], next[i]];
        if (a[i] !== a[j] && !rejected.has(signature + ':' + i + ',' + j) && (matchesAt(next, i) || matchesAt(next, j))) { move = [i, j]; break; }
      }
      assert(move, 'Screenshot has no identified legal match3 move'); previous = signature; previousMove = signature + ':' + move.join(','); batch(move.map(i => cells[i])); sleep(350);
    } throw Error('Match3 move limit');
  };
  solvers.klotski = () => {
    const ns = layout(), blocks = ns.filter(n => n.type === 'Stack' && n.clickable === 'true' && descendants(n).some(d => ['曹', '将', '兵'].includes(d.text))); assert(blocks.length >= 5);
    const sizes = blocks.map(n => { const b = bounds(n); return { w: b[2] - b[0], h: b[3] - b[1] }; }), unit = Math.min(...sizes.map(p => p.w)) + 13;
    const x0 = Math.min(...blocks.map(n => bounds(n)[0])), y0 = Math.min(...blocks.map(n => bounds(n)[1]));
    const initial = blocks.map(n => { const b = bounds(n); return { w: Math.round((b[2] - b[0]) / unit), h: Math.round((b[3] - b[1]) / unit), x: Math.round((b[0] - x0) / unit), y: Math.round((b[1] - y0) / unit), target: descendants(n).some(d => d.text === '曹') }; });
    const dirs = [[0, -1], [1, 0], [0, 1], [-1, 0]], key = a => a.map(p => p.w + ',' + p.h + ':' + p.x + ',' + p.y).sort().join('|');
    const q = [{ a: initial, prev: -1 }], seen = new Set([key(initial)]); let end = -1;
    for (let k = 0; k < q.length && k < 200000; k++) {
      const a = q[k].a; if (a.some(p => p.target && p.x === 1 && p.y === 3)) { end = k; break; }
      for (let i = 0; i < a.length; i++) for (let d = 0; d < 4; d++) {
        const p = a[i], x = p.x + dirs[d][0], y = p.y + dirs[d][1]; if (x < 0 || y < 0 || x + p.w > 4 || y + p.h > 5) continue;
        if (a.some((other, j) => j !== i && x < other.x + other.w && x + p.w > other.x && y < other.y + other.h && y + p.h > other.y)) continue;
        const next = a.map((p, j) => j === i ? { ...p, x, y } : p), hash = key(next); if (seen.has(hash)) continue; seen.add(hash); q.push({ a: next, prev: k, piece: i, dir: d });
      }
    }
    assert(end >= 0); const route = []; for (let at = end; q[at].prev >= 0; at = q[at].prev) route.unshift(q[at]);
    const buttons = ns.filter(n => n.type === 'Button' && bounds(n)[1] > 1900).sort((a, b) => bounds(a)[1] - bounds(b)[1] || bounds(a)[0] - bounds(b)[0]); assert.equal(buttons.length, 5);
    const controls = [buttons[0], buttons[3], buttons[4], buttons[1]]; let current = initial, last = -1;
    for (const step of route) {
      const p = current[step.piece]; if (last !== step.piece) shell('uitest', 'uiInput', 'click', String(Math.round(x0 + p.x * unit + p.w * unit / 2)), String(Math.round(y0 + p.y * unit + p.h * unit / 2)));
      click(controls[step.dir]); last = step.piece; current = step.a;
    }
    return { strategy: 'BFS of displayed block positions with legal direction controls', moves: route.length };
  };
  return solvers;
};
