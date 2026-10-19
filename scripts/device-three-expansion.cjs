module.exports = c => {
  const { assert, layout, texts, descendants, bounds, center, find, click, tap, batch, wait, sleep, outcome, shell, swipe, strings } = c;
  const v = require('./device-three-vision-api.cjs')(c), solvers = {};
  const label = n => n.text || n.description || descendants(n).filter(d => d.text).map(d => d.text).join(' ');
  const visible = (n, ns) => v.opacity(n, ns) > .5 && n.enabled !== 'false';
  solvers.parkingjam = () => {
    for (let moves = 0; moves < 30; moves++) {
      const ns = layout(); if (outcome(ns)) return { strategy: 'removed cars with clear visible exit rays', moves };
      const cars = ns.filter(n => n.type === 'Button' && visible(n, ns) && descendants(n).some(d => /^[↑→↓←]$/.test(d.text)));
      const car = cars.find(a => !cars.some(b => {
        if (a === b) return false; const x = bounds(a), y = bounds(b), dir = descendants(a).find(d => /^[↑→↓←]$/.test(d.text)).text;
        return dir === '↑' ? y[3] <= x[1] && y[0] < x[2] && y[2] > x[0] : dir === '↓' ? y[1] >= x[3] && y[0] < x[2] && y[2] > x[0] : dir === '←' ? y[2] <= x[0] && y[1] < x[3] && y[3] > x[1] : y[0] >= x[2] && y[1] < x[3] && y[3] > x[1];
      })); assert(car, 'No visible clear car ray'); click(car);
    } throw Error('Parking did not settle');
  };
  solvers.screwout = () => {
    for (let moves = 0; moves < 18; moves++) {
      const ns = layout(); if (outcome(ns)) return { strategy: 'removed top plate screws before lower plates', moves };
      const screws = ns.filter(n => n.type === 'Button' && bounds(n)[1] > 350 && bounds(n)[2] - bounds(n)[0] > 60 && bounds(n)[2] - bounds(n)[0] < 150 &&
        visible(n, ns) && descendants(n).filter(d => d.type === 'Image').length === 1);
      assert(screws.length); const top = Math.max(...screws.map(n => bounds(n)[1])); click(screws.filter(n => bounds(n)[1] > top - 10).sort((a, b) => bounds(a)[0] - bounds(b)[0])[0]);
    } throw Error('Screws did not settle');
  };
  solvers.blockfit = () => {
    for (let moves = 0; moves < 100; moves++) {
      const ns = layout(); if (outcome(ns)) return { strategy: 'placed actual preview shapes into free cells until natural result', moves };
      const cells = v.cells(ns), n = Math.sqrt(cells.length); assert.equal(n, 6);
      const values = v.classify(cells, ['exp_empty', ...v.family('exp_block_', 3)]).map(n => n !== 'exp_empty');
      const slots = ns.filter(n => n.type === 'Button' && descendants(n).some(d => /^拼块 [123]$/.test(d.text)) && n.enabled === 'true');
      let move;
      for (const slot of slots) {
        const images = descendants(slot).filter(d => d.type === 'Image'), shape = images.map((d, i) => +d.opacity > .5 ? i : -1).filter(i => i >= 0);
        for (let i = 0; i < cells.length; i++) if (shape.length && shape.every(j => i % n + j % 3 < n && Math.floor(i / n) + Math.floor(j / 3) < n && !values[i + Math.floor(j / 3) * n + j % 3])) { move = [slot, cells[i]]; break; }
        if (move) break;
      }
      assert(move, 'No legal visible preview placement'); batch(move);
    } throw Error('Blockfit move limit');
  };
  solvers.tilestack = () => {
    for (let moves = 0; moves < 65; moves++) {
      const ns = layout(); if (outcome(ns)) return { strategy: 'selected visible stacked tiles to natural tray/full-clear result', moves };
      const cells = v.cells(ns).filter(n => visible(n, ns)); assert(cells.length); click(cells[moves % cells.length]);
    } throw Error('Stack did not settle');
  };
  solvers.slotpair = () => {
    for (let moves = 0; moves < 45; moves++) {
      const ns = layout(); if (outcome(ns)) return { strategy: 'dropped successive real tiles into the same column', moves };
      const buttons = ns.filter(n => n.type === 'Button' && label(n) === '↓');
      assert.equal(buttons.length, 6);
      const cells = v.cells(ns), values = v.classify(cells, ['exp_empty', ...v.family('exp_tile_', 3)]);
      const available = buttons.filter((n, i) => values[i] === 'exp_empty'); assert(available.length);
      click(available[moves % available.length]);
    } throw Error('Slotpair did not settle');
  };
  solvers.groupclear = () => {
    for (let moves = 0; moves < 30; moves++) {
      const ns = layout(); if (outcome(ns)) return { strategy: 'removed largest screenshot-derived equal groups', moves };
      const cells = v.cells(ns); assert.equal(cells.length, 48);
      const values = v.classify(cells, v.family('exp_tile_', 3)).map((value, i) => visible(cells[i], ns) ? value : '');
      const seen = new Set(), groups = [];
      for (let i = 0; i < 48; i++) if (values[i] && !seen.has(i)) {
        const q = [i]; seen.add(i); for (let k = 0; k < q.length; k++) for (const j of [q[k] - 6, q[k] + 6, q[k] % 6 ? q[k] - 1 : -1, q[k] % 6 < 5 ? q[k] + 1 : -1])
          if (j >= 0 && j < 48 && values[j] === values[i] && !seen.has(j)) { seen.add(j); q.push(j); }
        if (q.length > 1) groups.push(q);
      }
      groups.sort((a, b) => b.length - a.length); assert(groups.length); click(cells[groups[0][0]]);
    } throw Error('Groupclear did not settle');
  };
  const linkable = (a, from, to, rows) => {
    const width = 8, height = rows + 2, start = (Math.floor(from / 6) + 1) * width + from % 6 + 1, end = (Math.floor(to / 6) + 1) * width + to % 6 + 1;
    const occupied = new Set(a.flatMap((v, i) => v ? [(Math.floor(i / 6) + 1) * width + i % 6 + 1] : [])), q = [0, 1, 2, 3].map(dir => ({ at: start, dir, turns: 0 })), seen = new Map();
    for (let k = 0; k < q.length; k++) {
      const p = q[k]; if (p.at === end) return true;
      for (let d = 0; d < 4; d++) { const turns = p.turns + +(d !== p.dir), x = p.at % width + [0, 1, 0, -1][d], y = Math.floor(p.at / width) + [-1, 0, 1, 0][d], at = y * width + x, key = at * 4 + d;
        if (turns > 2 || x < 0 || x >= width || y < 0 || y >= height || (at !== end && occupied.has(at)) || (seen.has(key) && seen.get(key) <= turns)) continue;
        seen.set(key, turns); q.push({ at, dir: d, turns }); }
    } return false;
  };
  solvers.linktiles = () => {
    for (let moves = 0; moves < 40; moves++) {
      const ns = layout(); if (outcome(ns)) return { strategy: 'matched screenshot-identical tiles with paths of at most two turns', moves };
      const cells = v.cells(ns); assert.equal(cells.length, 24);
      const values = v.classify(cells, v.family('exp_tile_', 3)).map((value, i) => visible(cells[i], ns) ? value : '');
      let pair;
      for (let i = 0; i < values.length && !pair; i++) if (values[i]) for (let j = i + 1; j < values.length; j++) if (values[i] === values[j] && linkable(values, i, j, 4)) { pair = [i, j]; break; }
      if (pair) batch(pair.map(i => cells[i])); else tap(strings.get('expansion_rearrange'), ns);
    } throw Error('Linktiles move limit');
  };
  solvers.mahjongsolitaire = () => {
    for (let moves = 0; moves < 35; moves++) {
      const ns = layout(); if (outcome(ns)) return { strategy: 'matched actually free same-picture tiles', moves };
      const cells = v.cells(ns).filter(n => visible(n, ns)); const values = v.classify(cells, v.family('exp_tile_', 3));
      let pair; for (let i = 0; i < cells.length && !pair; i++) for (let j = i + 1; j < cells.length; j++) if (values[i] === values[j]) { pair = [i, j]; break; }
      if (pair) batch(pair.map(i => cells[i])); else tap(strings.get('expansion_rearrange'), ns);
    } throw Error('Mahjong solitaire move limit');
  };
  solvers.sand = () => {
    for (let moves = 0; moves < 65; moves++) {
      const ns = layout(); if (outcome(ns)) return { strategy: 'pumped screenshot colors into corresponding containers', moves };
      const cells = v.cells(ns); assert.equal(cells.length, 48);
      const pumps = ns.filter(n => n.type === 'Button' && descendants(n).some(d => /^\d+ \/ 16$/.test(d.text)));
      assert.equal(pumps.length, 3);
      const values = v.classify(cells, v.family('exp_sand_', 3));
      const i = cells.findIndex((n, i) => visible(n, ns) && values[i]); assert(i >= 0); batch([pumps[+values[i].slice(-1)], cells[i]]);
    } throw Error('Sand move limit');
  };
  solvers.untangle = () => {
    const nodes = ns => ns.filter(n => n.type === 'Text' && /^[1-6]$/.test(n.text) && bounds(n)[1] > 350 && bounds(n)[2] - bounds(n)[0] > 80 && Math.abs(bounds(n)[2] - bounds(n)[0] - bounds(n)[3] + bounds(n)[1]) < 12).sort((a, b) => +a.text - +b.text);
    let ns = layout(), all = nodes(ns); assert.equal(all.length, 6);
    const arena = ns.find(n => n.type === 'Stack' && n.backgroundImage === 'true' && all.every(a => a.hierarchy.startsWith(n.hierarchy + ','))); assert(arena);
    const b = bounds(arena), scale = (b[2] - b[0]) / 360;
    for (const i of [1, 2, 3, 4, 5, 0]) {
      ns = layout(); if (outcome(ns)) return { strategy: 'dragged numbered graph to planar wheel', movedNodes: i };
      const node = nodes(ns).find(n => +n.text === i + 1), angle = (i - 1) * Math.PI * 2 / 5 - Math.PI / 2 + Math.PI / 9;
      const dest = i === 0 ? [180, 230] : [180 + Math.cos(angle) * 130, 230 + Math.sin(angle) * 170];
      const xy = center(node); swipe(...xy, b[0] + dest[0] * scale, b[1] + dest[1] * scale, 700);
    }
    return { strategy: 'dragged all six numbered nodes to planar wheel' };
  };
  solvers.buscolor = () => {
    const visited = new Set(), launched = [0, 0, 0]; let moves = 0;
    const play = () => {
      const ns = layout(); if (outcome(ns)) return true;
      const key = launched.join(','); if (visited.has(key)) return false; visited.add(key);
      const buses = ns.filter(n => n.type === 'Button' && n.enabled === 'true' && bounds(n)[1] > 800 && descendants(n).filter(d => d.type === 'Text' && /^[●○]$/.test(d.text)).length === 3);
      if (!buses.length) return false;
      const queue = ns.filter(n => n.type === 'Image' && bounds(n)[3] - bounds(n)[1] >= 125 && bounds(n)[3] - bounds(n)[1] <= 135).sort((a,b)=>bounds(a)[0]-bounds(b)[0]);
      assert(queue.length); const next = v.classify([queue[0]], v.family('exp_person_', 3))[0].slice(-1);
      const colors = v.classify(buses.map(n=>descendants(n).find(d=>d.type==='Image')), v.family('exp_bus_', 3));
      const options = buses.map((node,i)=>({node,lane:Math.min(2,Math.floor(center(node)[0]/420)),match:colors[i].slice(-1)===next})).sort((a,b)=>Number(b.match)-Number(a.match));
      for (const option of options) {
        click(option.node); launched[option.lane]++; moves++;
        if (play()) return true;
        tap(strings.get('expansion_undo')); launched[option.lane]--;
      }
      return false;
    };
    assert(play(), 'No successful launch order found through actual head selection and undo');
    return { strategy: 'matched visible queue colors, searched blocked lane orders with real undo', moves };
  };
  return solvers;
};
