// UI strategies. Never read live application state or force a result.
module.exports = c => {
  const { assert, layout, texts, descendants, bounds, center, byId, find, click, tap, batch, wait, sleep, outcome, board, grid, nums, shell, swipe, strings } = c;
  const solvers = {};
  const arenaIds = ['fisheat', 'blackhole', 'fruitslice', 'shooter', 'tanks', 'fortress', 'survival', 'pingpong', 'airhockey'];
  const start = () => { const ns = layout(), button = find(ns, '点击开始') || find(ns, '开始游戏') || find(ns, '开始'); if (button) click(button); };
  const timed = (seconds, action) => {
    start(); const started = Date.now(), deadline = started + seconds * 1000; let ns, captured = false;
    do { ns = wait(nodes => outcome(nodes) || !arenaIds.includes(c.activeId) || nodes.some(n => n.type === 'Stack' && n.backgroundImage === 'true' && n.clip === 'true'));
      if (outcome(ns)) return { strategy: 'normal controls then natural timed/collision result', text: texts(ns) };
      if (action) action(ns);
      if (!captured && Date.now() - started > 4000 && c.activeId) { c.shot(c.activeId + '-r' + c.activeRound + '-play'); captured = true; }
      sleep(900);
    } while (Date.now() < deadline);
    throw Error('No natural result in ' + seconds + ' seconds');
  };
  solvers.snake = () => timed(30, ns => { const buttons = ns.filter(n => n.type === 'Button' && bounds(n)[1] > 1900); const n = buttons.sort((a, b) => bounds(b)[0] - bounds(a)[0])[0]; assert(n); click(n); });
  solvers.tetris = () => timed(70, ns => { const n = find(ns, strings.get('game_tetris_drop')); assert(n, 'Hard drop absent'); batch(Array(4).fill(n)); });
  solvers.whackmole = () => timed(75, ns => {
    const hole = ns.find(n => n.type === 'Stack' && n.clickable === 'true' && descendants(n).filter(d => d.type === 'Image').length === 2 && bounds(n)[1] > 450);
    if (hole) click(hole);
  });
  solvers.brickbreaker = () => timed(100, ns => {
    const area = ns.find(n => n.type === 'Stack' && bounds(n)[1] > 450 && bounds(n)[2] - bounds(n)[0] > 900);
    if (area) { const b = bounds(area); swipe(b[0] + 70, b[3] - 110, b[0] + 140, b[3] - 110); }
  });
  solvers.jumpjump = () => {
    for (let jumps = 0; jumps < 12; jumps++) {
      const ns = layout(); if (outcome(ns)) return { strategy: 'real charge, jump and landing/collision', jumps };
      const target = byId(ns, 'jumpjump_area'); assert(target, 'Jump input absent');
      shell('uitest', 'uiInput', jumps === 0 ? 'longClick' : 'click', ...center(target).map(String)); sleep(900);
    } throw Error('Jump game did not settle after twelve real jumps');
  };
  for (const id of ['runner', 'rhythm', 'restaurant', 'fisheat', 'blackhole', 'platformer', 'grapple', 'flappy', 'fruitslice', 'shooter', 'tanks', 'fortress', 'survival', 'drift', 'hillclimb', 'pingpong', 'airhockey', 'beatjump', 'melody']) {
    solvers[id] = () => timed(160, ns => {
      if (id === 'restaurant') {
        const foodNames = [0, 1, 2].map(i => strings.get('expansion_food_' + i));
        const menu = ns.filter(n => n.type === 'Button' && descendants(n).some(d => /^备餐 \d+$/.test(d.text)));
        const customers = ns.filter(n => n.type === 'Button' && descendants(n).some(d => /^顾客 \d+/.test(d.text)));
        assert.equal(menu.length, 3); assert(customers.length);
        const order = descendants(customers[0]).find(d => foodNames.includes(d.text)).text;
        const dish = menu.find(n => descendants(n).some(d => d.text === order)); assert(dish);
        const stock = +descendants(dish).find(d => /^备餐 \d+$/.test(d.text)).text.match(/\d+/)[0];
        click(stock > 0 ? customers[0] : dish); return;
      }
      if (id === 'platformer' || id === 'hillclimb') {
        const control = find(ns, id === 'platformer' ? '→' : strings.get('expansion_gas')); assert(control);
        shell('uitest', 'uiInput', 'longClick', ...center(control).map(String)); return;
      }
      if (id === 'grapple') { batch([find(ns, strings.get('expansion_hook')), find(ns, strings.get('expansion_release'))]); return; }
      if (['fruitslice', 'shooter', 'tanks', 'fortress', 'survival', 'pingpong', 'airhockey'].includes(id)) {
        const field = ns.find(n => n.type === 'Stack' && n.backgroundImage === 'true' && n.clip === 'true'); assert(field);
        const b = bounds(field), y = Math.round(b[1] + (b[3] - b[1]) * (id === 'fruitslice' ? .65 : .85));
        if (id === 'fruitslice') swipe(b[0] + 40, y, b[2] - 40, y, 1300);
        else shell('uitest', 'uiInput', 'click', String(b[0] + 70), String(y));
        return;
      }
      if (id === 'fisheat' || id === 'blackhole') {
        const field = ns.find(n => n.type === 'Stack' && n.backgroundImage === 'true' && n.clip === 'true'); assert(field);
        const b = bounds(field); shell('uitest', 'uiInput', 'click', String(Math.round((b[0] + b[2]) / 2)), String(Math.round(b[1] + (b[3] - b[1]) * .6))); return;
      }
      const n = ns.find(n => n.type === 'Button' && n.enabled !== 'false' && bounds(n)[1] > 1600 && !['game-settings-button'].includes(n.id) && !descendants(n).some(d => /撤销|暂停/.test(d.text)));
      if (n) click(n);
    });
  }
  solvers.minesweeper = () => {
    let ns = layout(), cells = grid(ns); assert.equal(cells.length, 81);
    click(cells[40]);
    for (let i = 0; i < 81; i += 3) { ns = layout(); if (outcome(ns)) return { strategy: 'safe first reveal then real cell reveals', revealed: i };
      batch(cells.slice(i, i + 3)); }
    wait(outcome); return { strategy: 'opened all reachable cells' };
  };
  const options = ns => ns.filter(n => n.type === 'Button' && bounds(n)[1] > 380 && descendants(n).some(d => d.type === 'Text' && /^[-\d＜＝＞]+$/.test(d.text)))
    .map(n => ({ node: n, value: descendants(n).find(d => d.type === 'Text' && /^[-\d＜＝＞]+$/.test(d.text)).text }));
  const solvePrompt = (id, p) => {
    const n = p.match(/\d+/g).map(Number);
    if (id === 'arithmetic') return p.includes('+') ? n[0] + n[1] : /[−-]/.test(p) ? n[0] - n[1] : n[0] * n[1];
    if (id === 'compare') return ['＜', '＝', '＞'][Math.sign(n[0] + n[1] - n[2] - n[3]) + 1];
    if (id === 'sequence') return n[2] - n[1] === n[1] - n[0] ? n[3] + n[1] - n[0] : n[3] * 2;
    if (id === 'binary') return parseInt(p.split('₂')[0], 2);
    return n[2] - n[0] - n[1];
  };
  for (const id of ['arithmetic', 'compare', 'sequence', 'binary', 'targetsum', 'missing']) solvers[id] = () => {
    for (let q = 0; q < 10; q++) {
      let ns = wait(ns => texts(ns).some(t => t.startsWith('第 ' + (q + 1) + ' / 10')));
      let answer;
      if (id === 'missing') {
        const cards = n => n.filter(t => t.type === 'Text' && /^\d+$/.test(t.text) && bounds(t)[1] > 600 &&
          !options(n).some(o => descendants(o.node).some(d => d.hashcode === t.hashcode))).map(t => t.text);
        const before = cards(ns); tap('记好了', ns); ns = wait(n => !find(n, '记好了')); answer = before.find(v => !cards(ns).includes(v));
      } else {
        const p = texts(ns).find(t => id === 'arithmetic' ? t.includes(' = ?') : id === 'compare' ? t.includes(')  ?') : id === 'sequence' ? t.includes(' · ?') : id === 'binary' ? t.includes('₂ =') : t.includes(' + ? ='));
        assert(p, 'Rendered question absent'); answer = solvePrompt(id, p);
      }
      const correct = options(ns).find(o => o.value === String(answer)); assert(correct, 'Answer absent: ' + answer); click(correct.node); sleep(650);
    }
    return { strategy: 'solved ten actual rendered questions', answered: 10 };
  };
  solvers.schulte = () => {
    const cells = board(); const values = cells.map(n => nums(n)[0]); assert(values.includes(1));
    batch(Array.from({ length: cells.length }, (_, i) => cells[values.indexOf(i + 1)]));
    return { strategy: 'tapped actual shuffled numbers in order', count: cells.length };
  };
  solvers.memorysequence = () => {
    const ns = layout(), cells = board(ns), top = bounds(cells[0])[1];
    const seq = ns.filter(n => n.type === 'Text' && /^\d+$/.test(n.text) && bounds(n)[1] < top && bounds(n)[1] > 380).map(n => +n.text);
    assert(seq.length); tap('记好了', ns); batch(seq.map(v => cells[v - 1]));
    return { strategy: 'recalled actual displayed sequence', sequence: seq };
  };
  solvers.reaction = round => {
    tap('点击开始'); if (round === 1) tap('等待信号…');
    else { const ns = wait(ns => !!find(ns, '现在点击！'), 10000); tap('现在点击！', ns); }
    return { strategy: round === 1 ? 'early-tap failure' : 'waited for rendered signal and reacted' };
  };
  solvers.guessnumber = () => {
    const ns = layout(), hint = texts(ns).find(t => /猜一个由\d+个/.test(t)); const length = +hint.match(/\d+/)[0];
    const keys = Array.from({ length: 10 }, (_, i) => find(ns, String(i))); const submit = find(ns, strings.get('guess_confirm'));
    let candidates = [];
    const gen = s => { if (s.length === length) { candidates.push(s); return; } for (let i = 0; i < 10; i++) if (!s.includes(String(i))) gen(s + i); }; gen('');
    const feedback = (a, b) => { let x = 0, y = 0; for (let i = 0; i < a.length; i++) if (a[i] === b[i]) x++; else if (a.includes(b[i])) y++; return x + 'A' + y + 'B'; };
    for (let i = 0; i < 12; i++) {
      const guess = candidates[0]; assert(guess); batch([...guess].map(d => keys[+d]).concat([submit]));
      const after = layout(); if (outcome(after)) return { strategy: 'deduced password from native A/B feedback', guesses: i + 1 };
      const fb = texts(after).find(t => /^\d+A\d+B$/.test(t)); assert(fb); candidates = candidates.filter(secret => feedback(secret, guess) === fb);
    }
    throw Error('Password did not settle');
  };
  Object.assign(solvers, require('./device-three-puzzles.cjs')(c));
  Object.assign(solvers, require('./device-three-expansion.cjs')(c));
  Object.assign(solvers, require('./device-three-classic.cjs')(c));
  Object.assign(solvers, require('./device-three-extra.cjs')(c));
  Object.assign(solvers, require('./device-three-cards.cjs')(c));
  delete require.cache[require.resolve('./device-three-board-games.cjs')];
  Object.assign(solvers, require('./device-three-board-games.cjs')(c));
  return solvers;
};
