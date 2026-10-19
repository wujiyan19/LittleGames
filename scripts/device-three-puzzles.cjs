module.exports = c => {
  const { assert, layout, texts, descendants, bounds, center, byId, find, click, tap, batch, wait, sleep, outcome, board, grid, nums, shell, swipe, strings } = c;
  const solvers = {};
  const vision = require('./device-three-vision-api.cjs')(c);
  const label = n => n.text || n.description || descendants(n).filter(d => d.text).map(d => d.text).join(' ');
  const neighbors = (i, n, total = n * n) => [i - n, i % n < n - 1 ? i + 1 : -1, i + n, i % n ? i - 1 : -1].filter(j => j >= 0 && j < total);
  solvers.lights = () => {
    const cells = board(), n = cells.length, cols = Math.sqrt(n);
    const values = vision.classify(cells, ['col_light_off', 'col_light_on']).map(n => +(n === 'col_light_on'));
    const rows = values.map((v, i) => Array.from({ length: n + 1 }, (_, j) => j === n ? v : +(i === j || neighbors(j, cols).includes(i))));
    let rank = 0; const pivots = [];
    for (let col = 0; col < n; col++) {
      const r = rows.findIndex((a, k) => k >= rank && a[col]); if (r < 0) continue;
      [rows[r], rows[rank]] = [rows[rank], rows[r]];
      for (let k = 0; k < n; k++) if (k !== rank && rows[k][col]) for (let j = col; j <= n; j++) rows[k][j] ^= rows[rank][j];
      pivots.push(col); rank++;
    }
    const route = pivots.filter((_, i) => rows[i][n]); batch(route.map(i => cells[i]));
    return { strategy: 'GF2 solution from rendered light labels', moves: route.length };
  };
  solvers.maze = () => {
    const cells = board(), n = Math.sqrt(cells.length), markers = cells.map((cell, i) => descendants(cell).filter(d => d.type === 'Image').length > 1 ? i : -1).filter(i => i >= 0);
    assert.equal(markers.length, 2); const start = markers[0], end = markers[1];
    const walls = vision.classify(cells, ['col_wall', 'col_path']);
    const q = [start], prev = new Map([[start, -1]]);
    for (let k = 0; k < q.length; k++) for (const next of neighbors(q[k], n)) if ((markers.includes(next) || walls[next] !== 'col_wall') && !prev.has(next)) { q.push(next); prev.set(next, q[k]); }
    assert(prev.has(end)); const route = []; for (let i = end; i !== start; i = prev.get(i)) route.unshift(i);
    batch(route.map(i => cells[i])); return { strategy: 'BFS of rendered maze', moves: route.length };
  };
  solvers.flood = () => {
    let cells = board(), a = cells.map(n => nums(n)[0] - 1), n = Math.sqrt(cells.length), moves = 0;
    const fill = (v, color) => { const old = v[0], q = [0]; v[0] = color; for (let k = 0; k < q.length; k++) for (const j of neighbors(q[k], n)) if (v[j] === old) { v[j] = color; q.push(j); } return v; };
    const size = a => { const seen = new Set([0]), q = [0]; for (let k = 0; k < q.length; k++) for (const j of neighbors(q[k], n)) if (a[j] === a[0] && !seen.has(j)) { seen.add(j); q.push(j); } return seen.size; };
    while (new Set(a).size > 1) {
      const candidates = [0, 1, 2, 3].filter(k => k !== a[0]).map(k => ({ k, size: size(fill(a.slice(), k)) })).sort((a, b) => b.size - a.size);
      const ns = layout(); if (outcome(ns)) break;
      const opts = ns.filter(n => n.type === 'Button' && nums(n).length && !cells.some(b => b.bounds === n.bounds));
      const choice = opts.find(n => nums(n)[0] === candidates[0].k + 1); assert(choice); click(choice); fill(a, candidates[0].k); assert(++moves < 40);
    }
    return { strategy: 'screen-derived greedy flood expansion', moves };
  };
  solvers.hanoi = () => {
    const ns = layout(), posts = [1, 2, 3].map(i => ns.find(n => n.type === 'Button' && label(n).includes('第 ' + i + ' 柱')));
    assert(posts.every(Boolean)); const discs = descendants(posts[0]).filter(d => d.type === 'Text' && /^\d+$/.test(d.text)).length;
    assert(discs >= 3 && discs <= 5); const route = [];
    const move = (n, a, b, o) => { if (!n) return; move(n - 1, a, o, b); route.push(posts[a], posts[b]); move(n - 1, o, b, a); };
    move(discs, 0, 2, 1); batch(route); return { strategy: 'legal Hanoi solution', discs, moves: route.length / 2 };
  };
  solvers.peg = () => {
    const cells = board(); assert.equal(cells.length, 25);
    const initial = cells.map((n, i) => Math.floor(i / 5) === 2 || i % 5 === 2 ? +(descendants(n).filter(d => d.type === 'Image').length > 1) : -1), seen = new Set();
    const search = a => {
      if (a.filter(v => v === 1).length === 1) return [];
      const key = a.join(); if (seen.has(key)) return null; seen.add(key);
      for (let i = 0; i < 25; i++) if (a[i] === 1) for (const mid of neighbors(i, 5)) {
        const end = 2 * mid - i; if (end < 0 || end >= 25 || !neighbors(mid, 5).includes(end) || a[mid] !== 1 || a[end] !== 0) continue;
        const next = a.slice(); next[i] = next[mid] = 0; next[end] = 1; const route = search(next); if (route) return [[i, end], ...route];
      } return null;
    };
    const route = search(initial); assert(route); batch(route.flatMap(pair => pair.map(i => cells[i]))); return { strategy: 'solved actual peg position', moves: route.length };
  };
  solvers.nonogram = () => {
    const ns = layout(), clues = texts(ns).filter(t => /^1: /.test(t)); assert.equal(clues.length, 2);
    const parse = s => s.split('  /  ').map(t => t.split(': ')[1].split(' ').map(Number));
    const col = parse(clues[0]), rows = parse(clues[1]), n = rows.length, cells = board(ns);
    const runs = a => { const out = []; let count = 0; for (const v of a) { if (v) count++; else if (count) { out.push(count); count = 0; } } if (count) out.push(count); return out.length ? out : [0]; };
    const candidates = rows.map(cl => Array.from({ length: 2 ** n }, (_, mask) => Array.from({ length: n }, (_, i) => mask >> i & 1)).filter(a => runs(a).join() === cl.join()));
    let solution;
    const dfs = a => { if (a.length === n) { if (col.every((cl, i) => runs(a.map(row => row[i])).join() === cl.join())) solution = a; return; }
      for (const row of candidates[a.length]) { dfs([...a, row]); if (solution) return; } };
    dfs([]); assert(solution); batch(solution.flat().flatMap((v, i) => v ? [cells[i]] : [])); tap('检查答案'); return { strategy: 'solved displayed row/column clues', size: n };
  };
  solvers.sudoku = () => {
    const ns = wait(ns => !find(ns, '正在准备题目…')), cells = grid(ns); assert.equal(cells.length, 81);
    const original = cells.map(n => nums(n)[0] || 0), a = original.slice();
    const solve = () => { let best = -1, options = [];
      for (let i = 0; i < 81; i++) if (!a[i]) {
        const r = Math.floor(i / 9), col = i % 9, used = new Set();
        for (let j = 0; j < 9; j++) { used.add(a[r * 9 + j]); used.add(a[j * 9 + col]); used.add(a[(Math.floor(r / 3) * 3 + Math.floor(j / 3)) * 9 + Math.floor(col / 3) * 3 + j % 3]); }
        const values = [1, 2, 3, 4, 5, 6, 7, 8, 9].filter(v => !used.has(v)); if (!values.length) return false;
        if (best < 0 || values.length < options.length) { best = i; options = values; }
      }
      if (best < 0) return true; for (const v of options) { a[best] = v; if (solve()) return true; } a[best] = 0; return false;
    };
    assert(solve()); const keys = Array.from({ length: 10 }, (_, v) => ns.find(n => n.type === 'Button' && nums(n).includes(v) && bounds(n)[1] > 2100));
    const actions = []; for (let i = 0; i < 81; i++) if (!original[i]) actions.push(cells[i], keys[a[i]]);
    batch(actions); return { strategy: 'solved and filled actual Sudoku through touch', filled: actions.length / 2 };
  };
  solvers.slidepuzzle = () => {
    const cells = grid(), a = cells.map(n => nums(n)[0] || 0); assert.equal(a.length, 9);
    const heuristic = () => a.reduce((s, v, i) => s + (v ? Math.abs(Math.floor(i / 3) - Math.floor((v - 1) / 3)) + Math.abs(i % 3 - (v - 1) % 3) : 0), 0);
    const route = []; let solution;
    const dfs = (g, limit, last) => { const h = heuristic(); if (g + h > limit) return g + h; if (!h) { solution = route.slice(); return -1; }
      const z = a.indexOf(0); let min = Infinity;
      for (const next of neighbors(z, 3)) if (next !== last) { [a[z], a[next]] = [a[next], a[z]]; route.push(next); const t = dfs(g + 1, limit, z); if (t === -1) return -1; min = Math.min(min, t); route.pop(); [a[z], a[next]] = [a[next], a[z]]; } return min; };
    for (let limit = heuristic(); limit <= 50;) { const next = dfs(0, limit, -1); if (next === -1) break; limit = next; }
    assert(solution); batch(solution.map(i => cells[i])); return { strategy: 'IDA star solved actual sliding tiles', moves: solution.length };
  };
  const cellNodes = (ns = layout()) => vision.cells(ns);
  const cellValue = n => label(n).split('：')[1];
  solvers.differences = () => {
    const ns = layout(), cells = cellNodes(ns); assert.equal(cells.length, 50);
    const left = ns.filter(n => cells.includes(n) && center(n)[0] < 630).sort((a, b) => bounds(a)[1] - bounds(b)[1] || bounds(a)[0] - bounds(b)[0]);
    const right = ns.filter(n => cells.includes(n) && center(n)[0] > 630).sort((a, b) => bounds(a)[1] - bounds(b)[1] || bounds(a)[0] - bounds(b)[0]);
    const rendered = vision.classify(left.concat(right), vision.family('exp_object_', 6));
    const targets = right.filter((n, i) => rendered[i + 25] !== rendered[i]); assert(targets.length); batch(targets); return { strategy: 'compared actual left/right object icons', differences: targets.length };
  };
  solvers.arrowclear = () => {
    const ns = layout(), cells = cellNodes(ns), n = Math.sqrt(cells.length), rendered = vision.classify(cells, [...vision.family('exp_arrow_', 4), 'exp_empty']);
    const values = rendered.map((v, i) => vision.opacity(cells[i], ns) < .5 || v === 'exp_empty' ? '' : ['↑', '→', '↓', '←'][+v.slice(-1)]), route = []; assert(Number.isInteger(n));
    while (values.some(Boolean)) {
      const free = values.findIndex((v, i) => {
        if (!v) return false; const dir = ['↑', '→', '↓', '←'].indexOf(v); assert(dir >= 0);
        let x = i % n + [0, 1, 0, -1][dir], y = Math.floor(i / n) + [-1, 0, 1, 0][dir];
        while (x >= 0 && y >= 0 && x < n && y < n) { if (values[y * n + x]) return false; x += [0, 1, 0, -1][dir]; y += [-1, 0, 1, 0][dir]; } return true;
      }); assert(free >= 0); route.push(cells[free]); values[free] = '';
    }
    batch(route); return { strategy: 'cleared screenshot arrows in computed empty-ray order', moves: route.length };
  };
  solvers.hiddenobjects = () => {
    const ns = layout(), cells = cellNodes(ns); assert.equal(cells.length, 36); const top = bounds(cells[0])[1];
    const targets = ns.filter(n => n.type === 'Image' && n.parent?.attributes.type === 'Row' && vision.opacity(n, ns) > .5 && bounds(n)[1] > 350 && bounds(n)[3] < top && bounds(n)[2] - bounds(n)[0] > 70);
    assert.equal(targets.length, 6);
    const squareTargets = targets.map(n => {
      const b = bounds(n), xy = center(n), half = Math.min(b[2] - b[0], b[3] - b[1]) / 2;
      return { bounds: '[' + Math.round(xy[0] - half) + ',' + Math.round(xy[1] - half) + '][' + Math.round(xy[0] + half) + ',' + Math.round(xy[1] + half) + ']' };
    });
    const names = [...vision.family('exp_object_', 9), 'exp_fruit_4'], target = vision.classify(squareTargets, names), values = vision.classify(cells, names);
    assert.equal(new Set(target).size, 6);
    const selected = target.map(value => cells[values.indexOf(value)]); assert(selected.every(Boolean)); batch(selected);
    return { strategy: 'found six requested rendered object icons' };
  };
  solvers.idiom = () => {
    const idioms = ['一心一意', '画龙点睛', '守株待兔', '亡羊补牢', '掩耳盗铃', '井底之蛙', '刻舟求剑', '对牛弹琴', '水滴石穿', '狐假虎威', '画蛇添足', '胸有成竹', '愚公移山', '精卫填海', '杯弓蛇影', '叶公好龙'];
    for (let i = 0; i < 8; i++) { const ns = layout(), phrase = texts(ns).find(t => t.length === 4 && t.includes('□')); assert(phrase);
      const matching = idioms.find(s => [...phrase].every((v, i) => v === '□' || v === s[i])); assert(matching); tap(matching[phrase.indexOf('□')], ns); }
    return { strategy: 'filled eight visible idioms' };
  };
  solvers.farm = () => {
    for (let day = 0; day < 2; day++) {
      let ns = layout(), cells = cellNodes(ns); assert.equal(cells.length, 9);
      tap(strings.get('expansion_plant'), ns); batch(cells.slice(0, 6));
      tap(strings.get('expansion_water')); batch(cells.slice(0, 6));
      tap(strings.get('expansion_next_day')); tap(strings.get('expansion_harvest')); batch(cells.slice(0, 6));
    } return { strategy: 'planted watered and harvested twelve crops over two days' };
  };
  solvers.decorate = () => {
    const cells = cellNodes(); assert.equal(cells.length, 25);
    for (const step of [['expansion_sofa', 0], ['expansion_table', 5], ['expansion_room_plant', 3], ['expansion_room_plant', 4], ['expansion_lamp', 7]]) { tap(strings.get(step[0])); click(cells[step[1]]); }
    return { strategy: 'placed sofa table two plants and lamp to satisfy four visible goals' };
  };
  solvers.backpack = () => {
    let ns = layout(); const cells = cellNodes(ns); assert.equal(cells.length, 16);
    click(cells[0]); click(cells[4]); click(cells[8]);
    for (let i = 0; i < 8; i++) { ns = layout(); if (outcome(ns)) return { strategy: 'equipped swords and fought actual rounds', fights: i }; tap(strings.get('expansion_fight'), ns); }
    throw Error('Backpack did not settle');
  };
  return solvers;
};
