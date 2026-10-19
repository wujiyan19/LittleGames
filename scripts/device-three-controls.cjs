// Supplement three-settlement coverage with normal positive/control paths.
const c = require('./device-three-settlements.cjs');
const requested = process.argv.slice(2);
const field = ns => ns.find(n => n.type === 'Stack' && n.backgroundImage === 'true' && n.clip === 'true');
const solvers = {
  billiards() { return require('./device-three-extra.cjs')(c).billiards(); },
  golf() { return require('./device-three-extra.cjs')(c).golf(); },
  blackhole() {
    for (let move = 0; move < 80; move++) {
      const ns = c.layout(); if (c.outcome(ns)) return { moves: move };
      const arena = field(ns); c.assert(arena);
      const items = ns.filter(n => n.type === 'Image' && n.hierarchy.startsWith(arena.hierarchy + ',')).slice(1);
      c.assert(items.length);
      items.sort((a, b) => c.bounds(a)[2] - c.bounds(a)[0] - c.bounds(b)[2] + c.bounds(b)[0]);
      c.click(items[0]);
      if (move === 3) c.shot('blackhole-controls-play');
    }
    throw Error('Visible black-hole objects did not settle after eighty moves');
  },
  characters() {
    const recipes = { 明: ['日', '月'], 林: ['木', '木'], 休: ['人', '木'], 好: ['女', '子'], 男: ['田', '力'], 炎: ['火', '火'], 森: ['木', '木', '木'], 品: ['口', '口', '口'] };
    for (let word = 0; word < 8; word++) {
      const ns = c.layout(), prompt = c.texts(ns).find(text => text.startsWith('目标汉字：'));
      c.assert(prompt); const parts = recipes[prompt.trim().slice(-1)]; c.assert(parts);
      c.batch(parts.map(part => c.find(ns, part)).concat([c.find(ns, c.strings.get('expansion_check'))]));
      if (word === 1) c.shot('characters-controls-play');
    }
    return { solvedWords: 8 };
  },
  flappy() {
    for (let trial = 0; trial < 6; trial++) {
      if (trial) { c.restart(); c.shot('flappy-controls-start'); }
      const ns = c.layout(), flap = c.find(ns, c.strings.get('expansion_flap')), start = c.find(ns, '点击开始');
      c.assert(flap && start);
      // Measure normal input latency while the scene is still awaiting Start.
      const before = Date.now(); c.click(flap); const latency = (Date.now() - before) / 1000;
      const pause = Math.max(.01, .83 - latency + (trial % 3 - 1) * .04);
      const command = 'uitest uiInput click ' + c.center(flap).join(' ');
      const sequence = ['uitest uiInput click ' + c.center(start).join(' ')];
      for (let i = 0; i < 18; i++) {
        sequence.push(command);
        if (i === 3) sequence.push('snapshot_display -f /data/local/tmp/lg-flappy-controls.jpeg');
        sequence.push('sleep ' + pause.toFixed(3));
      }
      c.shell(sequence.join('; '));
      c.run('file', 'recv', '/data/local/tmp/lg-flappy-controls.jpeg', c.path.join(c.output, 'flappy-controls-trial-' + trial + '-play.jpeg'));
      const after = c.wait(c.outcome, 15000), progress = c.texts(after).find(text => /^进度 \d+ \/ 8$/.test(text));
      c.shot('flappy-controls-trial-' + trial + '-result');
      if (progress && +progress.match(/\d+/)[0] > 0) return { trial: trial + 1, progress, latency, pause };
    }
    throw Error('Normal rapid flap input did not pass the first pipe in six observed trials');
  }
};
c.shell('aa', 'start', '-b', 'com.littlegames.collection', '-a', 'EntryAbility');
for (const id of requested) {
  c.assert(solvers[id], id); c.open(id); const difficulty = c.difficulty('简单'); c.restart();
  c.activeId = id; c.activeRound = 0;
  const startedAt = new Date().toISOString(); c.shot(id + '-controls-start');
  try {
    const detail = solvers[id](); c.wait(c.outcome, 12000); const result = c.shot(id + '-controls-result');
    c.restart(); c.shot(id + '-controls-restarted');
    c.report.games.find(game => game.id === id).controlsCheck = { startedAt, finishedAt: new Date().toISOString(), packageSha256: c.report.packageSha256, detail, resultText: c.texts(result), evidence: [id + '-controls-start.jpeg', id + '-controls-result.jpeg', id + '-controls-restarted.jpeg'], restartVerified: true, visualReview: 'pending' };
    c.save(); console.log('CONTROL CHECK ' + id + ' ' + JSON.stringify(detail));
  } finally {
    c.difficulty(difficulty); c.category();
  }
}
