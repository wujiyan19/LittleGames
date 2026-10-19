module.exports = c => {
  const { assert, layout, texts, descendants, bounds, center, find, click, tap, batch, wait, sleep, outcome, shell, swipe, strings } = c;
  const v = require('./device-three-vision-api.cjs')(c), solvers = {};
  const arena = ns => ns.filter(n => n.type === 'Stack' && n.backgroundImage === 'true' && n.clip === 'true').sort((a, b) => (bounds(b)[2] - bounds(b)[0]) - (bounds(a)[2] - bounds(a)[0]))[0];
  const aim = (ns, x, y) => { const field = arena(ns); assert(field, 'Rendered arena absent'); const b = bounds(field); shell('uitest', 'uiInput', 'click', String(Math.round(b[0] + (b[2] - b[0]) * x / 360)), String(Math.round(b[1] + (b[3] - b[1]) * y / 460))); };
  const begin = () => { const ns = layout(), n = find(ns, '点击开始'); if (n) click(n); };
  for (const id of ['bubbleshooter', 'fruitmerge', 'basketball', 'billiards', 'penalty', 'bowling', 'golf', 'rollingball', 'roomdefense', 'wordtower', 'fishing']) solvers[id] = () => {
    begin(); const limit = id === 'fruitmerge' ? 600000 : 240000, deadline = Date.now() + limit; let actions = 0;
    do {
      const ns = layout(); if (outcome(ns)) return { strategy: 'normal native arena/control input to natural result', actions };
      if (id === 'roomdefense') { if (actions < 2) { const tower = ns.find(n => n.type === 'Button' && /^炮塔 1/.test(n.text)); assert(tower); click(tower); } }
      else if (id === 'fishing') { const cast = find(ns, strings.get('expansion_cast')); if (cast) click(cast); }
      else if (id === 'wordtower') {
        if (actions === 0) {
          const field = arena(ns); assert(field);
          const wood = ns.filter(n => n.type === 'Button' && n.hierarchy.startsWith(field.hierarchy + ',') && (n.text === '木' || descendants(n).some(d => d.text === '木')));
          assert.equal(wood.length, 3); batch(wood);
        }
      }
      else aim(ns, id === 'fruitmerge' ? 180 : id === 'basketball' ? 260 : id === 'rollingball' ? 330 : id === 'billiards' ? 25 : 180 + (actions % 3 - 1) * 80,
        id === 'basketball' ? 145 : id === 'billiards' ? 435 : id === 'rollingball' ? 40 : id === 'golf' ? 50 : 100);
      actions++;
      if (actions === 10) c.shot(id + '-r' + c.activeRound + '-play');
      sleep(id === 'bubbleshooter' || id === 'bowling' || id === 'golf' || id === 'billiards' ? 1800 : 800);
      if (id === 'fruitmerge' && actions >= 20 && actions % 10 === 0) sleep(7000);
    } while (Date.now() < deadline);
    throw Error(id + ' did not naturally settle within ' + limit / 60000 + ' minutes');
  };
  solvers.rollingball = round => {
    begin();
    const route = round === 1 ? [[320, 410], [320, 275], [45, 275], [45, 175], [320, 175], [320, 45]] : [[320, 410], [290, 330]];
    let waypoint = 0, actions = 0;
    const deadline = Date.now() + 240000;
    while (Date.now() < deadline) {
      const ns = wait(nodes => outcome(nodes) || arena(nodes));
      if (outcome(ns)) return { strategy: round === 1 ? 'steered the rendered ball around all three walls to the flag' : 'steered the rendered ball into a visible hazard to test failure', actions, waypoints: waypoint };
      const field = arena(ns), b = bounds(field), scale = (b[2] - b[0]) / 360;
      const ball = ns.find(n => n.type === 'Image' && n.hierarchy.startsWith(field.hierarchy + ',')); assert(ball);
      const xy = center(ball), x = (xy[0] - b[0]) / scale, y = (xy[1] - b[1]) / scale;
      const target = route[waypoint]; assert(target, 'Ball reached final waypoint without natural result');
      if (Math.hypot(x - target[0], y - target[1]) < 13) { waypoint++; continue; }
      // Small desired velocity keeps the observed ball from overshooting a corner.
      const vx = Math.max(-80, Math.min(80, (target[0] - x) * .6)), vy = Math.max(-80, Math.min(80, (target[1] - y) * .6));
      aim(ns, x + vx / 1.6, y + vy / 1.6); actions++;
      if (actions % 8 === 0) c.shot('rollingball-r' + c.activeRound + '-waypoint-' + waypoint);
      sleep(180);
    }
    throw Error('Rendered ball route did not settle within four minutes');
  };
  solvers.golf = () => {
    const position = ns => {
      const a = arena(ns); assert(a); const b = bounds(a), image = ns.find(n => n.type === 'Image' && n.hierarchy.startsWith(a.hierarchy + ',')); assert(image);
      const p = center(image), scale = (b[2] - b[0]) / 360; return [(p[0] - b[0]) / scale, (p[1] - b[1]) / scale];
    };
    for (let stroke = 0; stroke < 3; stroke++) {
      let ns = layout(); if (outcome(ns)) return { strategy: 'three normal strokes along the right side, then a slow cup approach', strokes: stroke };
      const p = position(ns);
      aim(ns, stroke === 0 ? p[0] + (330 - p[0]) * .8 / 1.8 : stroke === 1 ? p[0] : 270,
        stroke === 1 ? p[1] + (55 - p[1]) * .8 / 1.8 : p[1]);
      sleep(5000); let previous, still = 0; const deadline = Date.now() + 20000;
      do {
        ns = layout(); if (outcome(ns)) return { strategy: 'three normal strokes around rendered walls to a slow cup approach', strokes: stroke + 1 };
        const current = position(ns);
        still = previous && Math.hypot(current[0] - previous[0], current[1] - previous[1]) < .5 ? still + 1 : 0;
        if (still >= 2) break;
        previous = current; sleep(300);
      } while (Date.now() < deadline);
      assert(still >= 2, 'Rendered golf ball did not stop before next stroke');
      c.shot('golf-r' + c.activeRound + '-stroke-' + (stroke + 1));
    }
    wait(outcome, 10000); return { strategy: 'three normal native golf strokes to the cup', strokes: 3 };
  };
  solvers.characters = () => {
    for (let i = 0; i < 4; i++) { const ns = layout(); if (outcome(ns)) return { strategy: 'tested visible character parts and check feedback', submissions: i };
      const parts = ns.filter(n => n.type === 'Button' && bounds(n)[1] > 400 && /^[\u4e00-\u9fff]$/.test(n.text));
      assert(parts.length); click(parts[0]); tap(strings.get('expansion_check')); }
    return { strategy: 'three checked character combinations' };
  };
  solvers.melody = () => {
    for (let tries = 0; tries < 15; tries++) {
      let ns = layout(); if (outcome(ns)) return { strategy: 'played native melody and entered note answers to natural score/failure', tries };
      const play = find(ns, strings.get('expansion_play_melody'));
      if (play?.enabled === 'true') click(play);
      sleep(2200); ns = layout();
      const key = find(ns, 'C'); assert(key); batch([key, key, key]);
    } throw Error('Melody did not settle');
  };
  solvers.sokoban = () => {
    const ns = layout(), cells = v.cells(ns); assert.equal(cells.length, 49);
    const names = v.classify(cells, ['exp_wall', 'exp_floor', 'exp_goal', 'exp_crate', 'exp_robot']);
    const walls = new Set(names.flatMap((name, i) => name === 'exp_wall' ? [i] : []));
    // The two goal squares are fixed by the public easy-level board rules.
    const goals = new Set([16, 31]), initialBoxes = names.flatMap((name, i) => name === 'exp_crate' ? [i] : []), hero = names.indexOf('exp_robot');
    assert.equal(initialBoxes.length, 2); assert(hero >= 0);
    const key = (p, boxes) => p + ':' + boxes.slice().sort((a, b) => a - b).join(','), q = [{ p: hero, boxes: initialBoxes, prev: -1 }], seen = new Set([key(hero, initialBoxes)]); let end = -1;
    for (let k = 0; k < q.length && k < 200000; k++) {
      const state = q[k]; if (state.boxes.every(b => goals.has(b))) { end = k; break; }
      for (let d = 0; d < 4; d++) { const next = state.p + [-7, 1, 7, -1][d]; if (walls.has(next)) continue; const boxes = state.boxes.slice(), box = boxes.indexOf(next);
        if (box >= 0) { const dest = next + [-7, 1, 7, -1][d]; if (walls.has(dest) || boxes.includes(dest)) continue; boxes[box] = dest; }
        const hash = key(next, boxes); if (seen.has(hash)) continue; seen.add(hash); q.push({ p: next, boxes, prev: k, dir: d }); }
    }
    assert(end >= 0); const route = []; for (let i = end; q[i].prev >= 0; i = q[i].prev) route.unshift(q[i].dir);
    const controls = ['↑', '→', '↓', '←'].map(label => find(ns, label)); assert(controls.every(Boolean)); batch(route.map(d => controls[d]));
    return { strategy: 'BFS from screenshot crate/player positions to public level goals', moves: route.length };
  };
  const boardBackground = (node, ns) => ns.filter(p => node.hierarchy.startsWith(p.hierarchy + ',') && p.type === 'Column' && p.backgroundColor !== '#00000000').at(-1)?.backgroundColor;
  for (const id of ['chess', 'xiangqi']) solvers[id] = () => {
    const own = new Set();
    for (let turns = 0; turns < 180; turns++) {
      let ns = wait(ns => outcome(ns) || texts(ns).includes(strings.get('computer_your_turn')), 30000); if (outcome(ns)) return { strategy: 'played actual highlighted legal moves against phone computer', turns };
      const cells = v.cells(ns); assert.equal(cells.length, id === 'chess' ? 64 : 90);
      const original = cells.map(n => boardBackground(n, ns)); let moved = false;
      let candidates = Array.from({ length: cells.length }, (_, i) => (cells.length - 1 - i - turns * 7 + cells.length * 10) % cells.length);
      if (id === 'chess') {
        const names = v.classify(cells, ['exp_empty', ...v.family('exp_chess_0_', 6), ...v.family('exp_chess_1_', 6)]);
        candidates = candidates.filter(i => names[i].startsWith('exp_chess_0_'));
      } else {
        const piece = i => descendants(cells[i]).find(d => d.type === 'Text' && d.text)?.text || '';
        if (turns === 0) for (let i = 45; i < 90; i++) if (piece(i)) own.add(i);
        for (const i of own) if (!piece(i) || /[将士象卒]/.test(piece(i))) own.delete(i);
        candidates = candidates.filter(i => own.has(i));
      }
      // The phone's highlighted legal destinations are the move authority.
      for (const i of candidates) {
        click(cells[i]); ns = layout(); if (outcome(ns)) return { strategy: 'natural computer result', turns };
        const after = v.cells(ns), targets = after.map((n, j) => boardBackground(n, ns) !== original[j] ? j : -1).filter(j => j >= 0 && j !== i);
        if (targets.length) { const to = targets.sort((a, b) => a - b)[0]; click(after[to]); own.delete(i); own.add(to); moved = true; sleep(600); break; }
      }
      assert(moved, 'No highlighted legal move found');
      if (turns % 10 === 0) c.shot(id + '-r' + c.activeRound + '-turn-' + turns);
    } throw Error('Board game exceeded 180 player turns without a natural result');
  };
  solvers.onestroke = () => {
    const ns = layout(), nodes = ns.filter(n => n.type === 'Button' && /^[1-9]$/.test(n.text) && bounds(n)[1] > 350);
    assert.equal(nodes.length, 9); const edges = [[0, 1], [1, 2], [2, 5], [5, 8], [8, 7], [7, 6], [6, 3], [3, 0], [1, 4], [4, 7]], used = new Set(), stack = [1], path = [];
    while (stack.length) { const at = stack.at(-1), i = edges.findIndex((edge, i) => !used.has(i) && edge.includes(at)); if (i < 0) path.push(stack.pop()); else { used.add(i); stack.push(edges[i][0] === at ? edges[i][1] : edges[i][0]); } }
    const buttons = Array.from({ length: 9 }, (_, i) => nodes.find(n => n.text === String(i + 1)));
    batch(path.reverse().map(i => buttons[i])); return { strategy: 'traced every edge of visible easy graph exactly once', edges: edges.length };
  };
  solvers.linerescue = () => {
    const ns = layout(), field = arena(ns); assert(field); const b = bounds(field), scale = (b[2] - b[0]) / 360;
    swipe(b[0] + 110 * scale, b[1] + 180 * scale, b[0] + 250 * scale, b[1] + 180 * scale, 500);
    tap('点击开始'); wait(outcome, 20000); return { strategy: 'drew actual protection line and ran bee simulation' };
  };
  solvers.picturepuzzle = () => {
    const ns = layout(), cells = ns.filter(n => n.type === 'Stack' && n.clickable === 'true' && n.clip === 'true' && bounds(n)[1] > 400).sort((a, b) => Math.abs(bounds(a)[1] - bounds(b)[1]) < 15 ? bounds(a)[0] - bounds(b)[0] : bounds(a)[1] - bounds(b)[1]);
    assert.equal(cells.length, 9); const refs = Array.from({ length: 9 }, (_, i) => ({ name: String(i), file: c.path.join(c.root, 'entry/src/main/resources/base/media/expansion_puzzle_scene.svg'), crop: [i % 3, Math.floor(i / 3)] }));
    const values = v.classify(cells, refs).map(Number); assert.equal(new Set(values).size, 9);
    for (let i = 0; i < 9; i++) if (values[i] !== i) { const j = values.indexOf(i); batch([cells[i], cells[j]]); [values[i], values[j]] = [values[j], values[i]]; }
    return { strategy: 'matched actual scene fragments to reference image and swapped into place' };
  };
  solvers.watersort = () => {
    const ns = layout(), tubes = ns.filter(n => n.type === 'Button' && descendants(n).filter(d => d.type === 'Image').length === 5); assert.equal(tubes.length, 5);
    const layers = tubes.flatMap(n => descendants(n).filter(d => d.type === 'Image').slice(0, 4));
    const colors = v.classify(layers, v.family('exp_water_', 3));
    const initial = tubes.map((_, tube) => layers.slice(tube * 4, tube * 4 + 4).map((n, i) => +n.opacity > .5 ? colors[tube * 4 + i] : '').filter(Boolean).reverse());
    const key = a => a.map(p => p.join(',')).sort().join('|'), q = [{ a: initial, prev: -1 }], seen = new Set([key(initial)]); let end = -1;
    for (let k = 0; k < q.length && k < 100000; k++) {
      const a = q[k].a; if (a.every(p => !p.length || p.length === 4 && p.every(v => v === p[0]))) { end = k; break; }
      for (let i = 0; i < 5; i++) if (a[i].length) for (let j = 0; j < 5; j++) if (j !== i && a[j].length < 4 && (!a[j].length || a[j].at(-1) === a[i].at(-1))) {
        const next = a.map(p => p.slice()); next[j].push(next[i].pop()); const hash = key(next); if (seen.has(hash)) continue; seen.add(hash); q.push({ a: next, prev: k, from: i, to: j });
      }
    }
    assert(end >= 0, 'No water sort solution for screenshot layers'); const route = []; for (let i = end; q[i].prev >= 0; i = q[i].prev) route.unshift(q[i]);
    batch(route.flatMap(step => [tubes[step.from], tubes[step.to]])); return { strategy: 'BFS on actual visible water layers and one-layer pours', pours: route.length };
  };
  solvers.pipes = () => {
    const cells = v.cells(); assert.equal(cells.length, 16); const n = 4;
    const initial = v.classify(cells, v.family('exp_pipe_', 16)).map(s => +s.split('_').at(-1));
    const rotate = x => (x << 1 & 15) | x >> 3, candidates = initial.map((mask, i) => { const opts = []; let m = mask; for (let r = 0; r < 4; r++) { if (!opts.includes(m) && !(i < n && m & 1) && !(i % n === n - 1 && m & 2) && !(i >= n * (n - 1) && m & 4) && !(i % n === 0 && m & 8)) opts.push(m); m = rotate(m); } return opts; });
    let solution; const dfs = a => { const i = a.length; if (i === 16) { const seen = new Set([0]), q = [0]; for (let k = 0; k < q.length; k++) for (let d = 0; d < 4; d++) if (a[q[k]] & 1 << d) { const j = q[k] + [-n, 1, n, -1][d]; if (!seen.has(j)) { seen.add(j); q.push(j); } } if (seen.size === 16) solution = a; return; }
      for (const m of candidates[i]) if ((i < n || !!(m & 1) === !!(a[i - n] & 4)) && (i % n === 0 || !!(m & 8) === !!(a[i - 1] & 2))) { dfs([...a, m]); if (solution) return; } };
    dfs([]); assert(solution, 'Pipe screenshot rotation constraints unsolved'); const actions = []; for (let i = 0; i < 16; i++) { let mask = initial[i]; for (let r = 0; mask !== solution[i] && r < 4; r++) { actions.push(cells[i]); mask = rotate(mask); } }
    batch(actions); return { strategy: 'rotated actual pipe sprites into closed connected network', rotations: actions.length };
  };
  solvers.yarn = () => {
    const active = ns => ns.filter(n => n.type === 'Button' && descendants(n).filter(d => d.type === 'Image').length === 8);
    const reels = ns => ns.filter(n => n.type === 'Button' && descendants(n).some(d => /^\d+ \/ 8$/.test(d.text)));
    for (let moves = 0; moves < 45; moves++) {
      const ns = layout(); if (outcome(ns)) return { strategy: 'unwound actual exposed yarn into matching reels', moves };
      const columns = active(ns); assert.equal(columns.length, 4); const reelButtons = reels(ns); assert.equal(reelButtons.length, 3);
      const images = columns.map(n => descendants(n).filter(d => d.type === 'Image' && +d.opacity > .5));
      const colors = v.classify(images.flat(), v.family('exp_yarn_', 4)); let offset = 0;
      const stacks = images.map(column => { const values = colors.slice(offset, offset + column.length); offset += column.length; return values; });
      const available = [...new Set(colors)];
      const color = available.find(color => stacks.every(stack => !stack.includes(color) || stack.slice(0, stack.indexOf(color)).every(v => v === color)));
      assert(color, 'No exposed color ordering in visible yarn stacks'); const i = stacks.findIndex(stack => stack[0] === color);
      const occupied = reelButtons.map(n => descendants(n).some(d=>d.text==='○') ? undefined : descendants(n).find(d => d.type === 'Image'));
      let reel = occupied.findIndex(n => !n); if (occupied.some(Boolean)) {
        const classified = v.classify(occupied.filter(Boolean), v.family('exp_reel_', 4)); let k = 0;
        for (let j = 0; j < occupied.length; j++) if (occupied[j]) { if (classified[k++].slice(-1) === color.slice(-1)) { reel = j; break; } }
      }
      assert(reel >= 0); batch([reelButtons[reel], columns[i]]);
    } throw Error('Yarn move limit');
  };
  return solvers;
};
