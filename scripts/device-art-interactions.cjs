const c = require('./device-art-review.cjs');
const { fs, path, cp, assert, dir, layout, text, find, descendants, bounds, click, tap, wait, sleep,
  capture, open, back, grid, board, nums, headerRestart, log, packageHash } = c;
const stats = ns => ns.filter(n => n.type === 'Text' && /^\d+$/.test(n.text) && bounds(n)[1] > 300 && bounds(n)[1] < 550).map(n => Number(n.text));
let current = '';
let evidence = [];
const phasePrefix = process.env.LITTLEGAMES_ART_RUN || '';
assert.match(phasePrefix, /^[a-z0-9-]*$/);
const shot = tag => { const name = phasePrefix + 'play-' + current + '-' + tag; evidence.push(name); return capture(name); };
function fastShot(tag, node) {
  const name = phasePrefix + 'play-' + current + '-' + tag;
  if (node) {
    const b = bounds(node), x = Math.round((b[0] + b[2]) / 2), y = Math.round((b[1] + b[3]) / 2);
    c.shell('uitest uiInput click ' + x + ' ' + y + '; snapshot_display -f /data/local/tmp/lg-art-fast.jpeg');
  } else c.shell('snapshot_display', '-f', '/data/local/tmp/lg-art-fast.jpeg');
  const file = path.join(dir, name + '.jpeg'); c.run('file', 'recv', '/data/local/tmp/lg-art-fast.jpeg', file);
  evidence.push(name); log('fast-capture', { tag: name, clickedBounds: node?.bounds }); return file;
}
function pixels(file, nodes, kind) {
  const input = path.join(dir, 'pixels.json'); fs.writeFileSync(input, JSON.stringify({ file, bounds: nodes.map(bounds), kind }));
  return JSON.parse(cp.execFileSync('pwsh', ['-NoProfile', '-File', path.resolve('scripts/device-art-pixels.ps1'), '-InputPath', input], { encoding: 'utf8', timeout: 15000 }));
}
function result(label) { return wait(ns => find(ns, '再来一局') && (!label || text(ns).includes(label))); }
const spec = {};
spec.tictactoe = () => {
  let ns = layout(), cells = board(ns); assert.equal(cells.length, 9);
  const reset = ns.find(n => n.type === 'Button' && bounds(n)[0] > 1000 && bounds(n)[1] < 300); assert(reset);
  for (const i of [0, 3, 1, 4]) click(cells[i]);
  fastShot('player1-arrival', cells[2]); result('玩家 1 获胜'); shot('player1-result');
  click(reset); assert(find(layout(), '再来一局')); shot('modal-blocks-restart');
  tap('再来一局'); ns = wait(a => !find(a, '再来一局')); cells = board(ns);
  assert.equal(cells.length, 9); assert(text(ns).some(t => t.includes('玩家 1 回合')));
  for (const i of [0, 3, 1, 4, 8]) click(cells[i]);
  fastShot('player2-arrival', cells[5]); result('玩家 2 获胜'); shot('player2-result');
  tap('再来一局'); ns = wait(a => !find(a, '再来一局')); cells = board(ns);
  for (const i of [0, 1, 2, 4, 3, 5, 7, 6, 8]) click(cells[i]); result('平局'); shot('draw-result');
  return ['玩家 1 和玩家 2 均可完成胜利结算', '覆盖的底层重开按钮无法穿透弹窗', '再来一局恢复首回合', '平局结算'];
};
spec.match3 = () => {
  let ns = layout(), cells = grid(ns); assert.equal(cells.length, 64);
  let state = stats(ns); assert.equal(state.length, 3);
  const matches = a => a.some((v, i) => (i % 8 < 6 && v === a[i + 1] && v === a[i + 2]) || (i < 48 && v === a[i + 8] && v === a[i + 16]));
  for (let turn = 0; turn < 4; turn++) {
    const file = fastShot('board-' + turn), a = pixels(file, cells, 'gems'); assert.equal(a.length, 64);
    assert(!matches(a), 'Captured board has a pre-existing match; calibrate pixel classification');
    let legal, invalid;
    for (let i = 0; i < 64; i++) for (const j of [i % 8 < 7 ? i + 1 : -1, i < 56 ? i + 8 : -1]) if (j >= 0) {
      const next = a.slice(); [next[i], next[j]] = [next[j], next[i]];
      if (a[i] !== a[j] && matches(next)) legal = legal || [i, j]; else invalid = invalid || [i, j];
    }
    assert(legal && invalid);
    if (turn === 0) {
      click(cells[invalid[0]]); shot('selected'); click(cells[invalid[1]]); sleep(250);
      assert.deepEqual(stats(layout()), state); shot('invalid-swap');
    }
    click(cells[legal[0]]); fastShot('swap-' + turn, cells[legal[1]]);
    ns = wait(a => stats(a)[0] > state[0]); const after = stats(ns);
    assert(after[0] > state[0]); assert.equal(after[2], state[2] - 1); state = after;
  }
  shot('four-swaps'); headerRestart(); assert.equal(stats(layout())[0], 0); shot('restart');
  return ['无效交换不扣步数及分数', '4 次屏幕颜色推导的合法交换均消除、得分并扣 1 步', '选中边框及重开恢复'];
};
spec.memorycard = () => {
  const cells = grid(); assert.equal(cells.length, 16);
  const known = [], done = new Set(); let mismatch = false;
  const distance = (a, b) => a.reduce((sum, v, i) => sum + (v - b[i]) ** 2, 0) / a.length;
  for (let i = 0; i < cells.length; i += 2) {
    const fileA = fastShot('face-' + i, cells[i]); known[i] = pixels(fileA, [cells[i]], 'memory')[0];
    const fileB = fastShot('face-' + (i + 1), cells[i + 1]); known[i + 1] = pixels(fileB, [cells[i + 1]], 'memory')[0];
    if (distance(known[i], known[i + 1]) < 100) { done.add(i); done.add(i + 1); } else mismatch = true;
    sleep(900);
  }
  assert(mismatch); shot('after-exploration');
  for (let i = 0; i < cells.length; i++) {
    if (done.has(i)) continue;
    let best = -1, difference = Infinity;
    for (let j = i + 1; j < cells.length; j++) if (!done.has(j)) {
      const d = distance(known[i], known[j]); if (d < difference) { difference = d; best = j; }
    }
    assert(best >= 0 && difference < 100, 'No visually matching face for card ' + i + ', difference=' + difference);
    click(cells[i]); fastShot('pair-' + i + '-' + best, cells[best]); sleep(600); done.add(i); done.add(best);
  }
  result(); shot('completed'); tap('再来一局'); wait(ns => !find(ns, '再来一局')); assert.equal(stats(layout())[0], 0); shot('restart');
  return ['根据实际牌面找齐 8 对卡牌', '不匹配的牌延迟盖回', '配对后保留牌面', '完成结算及重开清零尝试次数'];
};
spec.whackmole = () => {
  let hit = false, ns;
  for (let attempt = 0; attempt < 8 && !hit; attempt++) {
    ns = layout();
    const occupied = grid(ns).filter(n => n.raw.children.filter(raw => raw.attributes.type === 'Image').length === 2);
    if (!occupied.length) continue;
    const before = stats(ns)[0]; fastShot('hit-' + attempt, occupied[0]);
    ns = layout(); if (stats(ns)[0] > before) hit = true;
  }
  assert(hit, 'No hit observed before target disappeared'); shot('hit-score');
  ns = layout(); const before = stats(ns)[0];
  const empty = grid(ns).find(n => n.raw.children.filter(raw => raw.attributes.type === 'Image').length === 1); assert(empty);
  fastShot('empty-hit', empty); ns = layout(); assert(stats(ns)[0] <= before); shot('empty-score');
  const pause = ns.find(n => n.type === 'Button' && bounds(n)[1] < 300 && bounds(n)[0] > 800 && bounds(n)[0] < 1050); assert(pause);
  click(pause); ns = layout(); const pausedTime = text(ns).find(t => /^\d+s$/.test(t)); assert(pausedTime);
  sleep(1100); assert.equal(text(layout()).find(t => /^\d+s$/.test(t)), pausedTime); shot('paused');
  return ['点击实际出现的地鼠产生得分', '空洞点击没有增加分数', '暂停后倒计时停止'];
};
spec.slidepuzzle = () => {
  const cells = grid(); assert.equal(cells.length, 16);
  const values = () => grid().map(n => nums(n)[0] || 0), initial = values(), empty = initial.indexOf(0); assert(empty >= 0);
  const adjacent = initial.findIndex((value, i) => value && Math.abs(Math.floor(i / 4) - Math.floor(empty / 4)) + Math.abs(i % 4 - empty % 4) === 1);
  const blocked = initial.findIndex((value, i) => value && Math.abs(Math.floor(i / 4) - Math.floor(empty / 4)) + Math.abs(i % 4 - empty % 4) > 1);
  click(cells[blocked]); assert.deepEqual(values(), initial);
  fastShot('move-arrival', cells[adjacent]); const after = values(); assert.equal(after[empty], initial[adjacent]); assert.equal(after[adjacent], 0);
  shot('moved'); headerRestart(); assert.equal(stats(layout())[0], 0); shot('restart');
  return ['非相邻点击保持棋盘', '相邻数字块移入空位', '重开步数归零'];
};
spec['2048'] = () => {
  const ns = layout(); const area = ns.find(n => n.type === 'Stack' && n.clickable !== 'true' && bounds(n)[1] > 600 && bounds(n)[2] - bounds(n)[0] > 950); assert(area);
  const b = bounds(area), x = Math.round((b[0] + b[2]) / 2), y = Math.round((b[1] + b[3]) / 2), d = 300;
  const dirs = [[x + d, y, x - d, y], [x, y + d, x, y - d], [x - d, y, x + d, y], [x, y - d, x, y + d]];
  for (let i = 0; i < 12; i++) { c.shell('uitest', 'uiInput', 'swipe', ...dirs[i % 4].map(String), '3000'); sleep(100); }
  assert(stats(layout())[0] > 0); shot('merged'); headerRestart(); assert.equal(stats(layout())[0], 0); shot('restart');
  return ['12 次四方向滑动产生合并与得分', '重开清零得分'];
};
spec.sudoku = () => {
  const ns = layout(), cells = grid(ns); assert.equal(cells.length, 81);
  const empty = cells.findIndex(n => nums(n).length === 0), fixed = cells.findIndex(n => nums(n).length > 0); assert(empty >= 0 && fixed >= 0);
  const key = ns.find(n => n.type === 'Button' && nums(n).includes(1) && bounds(n)[1] > 2300); assert(key);
  click(cells[empty]); click(key); assert.equal(nums(grid()[empty])[0], 1); shot('selected-number');
  const erase = ns.find(n => n.type === 'Button' && bounds(n)[1] > 2300 && !nums(n).length); assert(erase);
  click(erase); assert.equal(nums(grid()[empty]).length, 0);
  const original = nums(cells[fixed])[0]; click(cells[fixed]); click(key); assert.equal(nums(grid()[fixed])[0], original); shot('fixed-number');
  return ['空格可填入数字并擦除', '原题固定数字无法修改', '选中格的数字与宫格边界截图'];
};
spec.fourline = () => {
  let cells = board(); assert.equal(cells.length, 42);
  fastShot('drop-arrival', cells[0]); shot('dropped');
  let ns = layout(); assert(text(ns).some(t => t.includes('玩家 2 回合')));
  click(cells[1]); ns = layout(); assert(text(ns).some(t => t.includes('玩家 1 回合'))); shot('two-players');
  return ['点击两列后棋子位于各列底部', '双方回合正确切换'];
};
spec.reversi = () => {
  const cells = board(); assert.equal(cells.length, 36);
  const legal = cells.find(n => descendants(n).some(d => d.type === 'Text' && d.text === '·')); assert(legal);
  fastShot('flip-arrival', legal); const ns = shot('flipped');
  assert(text(ns).some(t => t.includes('玩家 2 回合')));
  return ['点击实际合法位置落子并翻转被夹棋子', '回合正确切换'];
};
spec.nonogram = () => {
  const cells = board(); assert.equal(cells.length, 25);
  fastShot('fill-arrival', cells[0]); shot('filled'); tap('检查答案');
  assert(!find(layout(), '再来一局')); shot('check-again');
  return ['填格与检查操作可用', '未完成棋盘没有提前结算', '线索与棋盘的实际布局截图'];
};
spec.minesweeper = () => {
  let won = false, attempts = 0;
  const dark = process.env.LITTLEGAMES_ART_THEME === 'dark';
  const darkHidden = [27, 38, 96], darkRevealed = [19, 29, 82];
  const squareDistance = (rgb, expected) => rgb.reduce((sum, value, i) => sum + (value - expected[i]) ** 2, 0);
  const neighbors = index => {
    const out = [], row = Math.floor(index / 9), col = index % 9;
    for (let dr = -1; dr <= 1; dr++) for (let dc = -1; dc <= 1; dc++)
      if ((dr || dc) && row + dr >= 0 && row + dr < 9 && col + dc >= 0 && col + dc < 9) out.push((row + dr) * 9 + col + dc);
    return out;
  };
  for (; attempts < 4 && !won; attempts++) {
    if (attempts > 0) { tap('再来一局'); wait(ns => !find(ns, '再来一局')); }
    let cells = grid(layout(), 'Column'); assert.equal(cells.length, 81);
    if (attempts === 0) {
      const b = bounds(cells[0]);
      c.shell('uitest', 'uiInput', 'longClick', '' + Math.round((b[0] + b[2]) / 2), '' + Math.round((b[1] + b[3]) / 2));
      assert(text(layout()).includes('1/10')); shot('flagged');
      c.shell('uitest', 'uiInput', 'longClick', '' + Math.round((b[0] + b[2]) / 2), '' + Math.round((b[1] + b[3]) / 2));
      assert(text(layout()).includes('0/10'));
    }
    click(cells[40]); const knownMines = new Set();
    for (let turn = 0; turn < 90; turn++) {
      let ns = layout();
      if (find(ns, '再来一局')) {
        won = text(ns).includes('扫雷成功!'); shot(won ? 'win' : 'guess-loss-' + attempts); break;
      }
      cells = grid(ns, 'Column'); assert.equal(cells.length, 81);
      const file = fastShot('solver-' + attempts + '-' + turn), colors = pixels(file, cells, 'rgb');
      const values = cells.map((n, i) => nums(n).length ? nums(n)[0] :
        (dark ? squareDistance(colors[i], darkRevealed) < squareDistance(colors[i], darkHidden) : colors[i].reduce((a, b) => a + b, 0) > 720) ? 0 : -1);
      const safe = new Set();
      let changed = true;
      while (changed) {
        changed = false;
        const constraints = [];
        for (let i = 0; i < 81; i++) if (values[i] >= 0) {
          const around = neighbors(i), unknown = around.filter(n => values[n] < 0 && !knownMines.has(n));
          const count = values[i] - around.filter(n => knownMines.has(n)).length;
          assert(count >= 0 && count <= unknown.length, 'Rendered mines classification is inconsistent');
          if (unknown.length) constraints.push({ cells: unknown, count });
        }
        const deductions = constraints.slice();
        for (const a of constraints) for (const b of constraints)
          if (a.cells.length < b.cells.length && a.cells.every(i => b.cells.includes(i)))
            deductions.push({ cells: b.cells.filter(i => !a.cells.includes(i)), count: b.count - a.count });
        for (const rule of deductions) {
          if (rule.count === 0) for (const i of rule.cells) safe.add(i);
          if (rule.count === rule.cells.length) for (const i of rule.cells) if (!knownMines.has(i)) { knownMines.add(i); changed = true; }
        }
      }
      const candidates = values.map((v, i) => v < 0 && !knownMines.has(i) ? i : -1).filter(i => i >= 0);
      assert(candidates.length);
      let next = candidates.find(i => safe.has(i));
      if (next === undefined) {
        let risk = Infinity;
        for (const candidate of candidates) {
          let estimate = (10 - knownMines.size) / candidates.length;
          for (const clue of neighbors(candidate)) if (values[clue] >= 0) {
            const around = neighbors(clue), remaining = around.filter(i => values[i] < 0 && !knownMines.has(i));
            estimate = Math.max(estimate, (values[clue] - around.filter(i => knownMines.has(i)).length) / remaining.length);
          }
          if (estimate < risk) { risk = estimate; next = candidate; }
        }
        log('mines-guess', { attempts, turn, next, risk });
      }
      click(cells[next]);
      if (turn % 10 === 0) console.log('MINES board ' + (attempts + 1) + ', reveals ' + (turn + 1));
    }
  }
  assert(won, 'Screen-derived mines solver did not reach a win in four boards');
  tap('再来一局'); wait(ns => !find(ns, '再来一局')); assert(text(layout()).includes('0/10')); shot('restart');
  return ['长按插旗及取消', '首个揭格安全', '仅根据屏幕数字与背景色推理并完成扫雷胜利', '胜利结算及重开旗数归零'];
};
for (const id of process.argv.slice(2)) {
  current = id; evidence = [];
  try {
    back(); open(id); if (id !== 'sudoku') headerRestart(); shot('before');
    assert(spec[id], 'No scenario for ' + id); const cases = spec[id](); back();
    const record = { id, name: c.names[id], at: new Date().toISOString(), packageHash,
      status: 'passed-selected-interactions', passedCases: cases, evidence };
    fs.appendFileSync(path.join(dir, 'interactions.jsonl'), JSON.stringify(record) + '\n');
    log('interactions-passed', record); console.log('PASS ' + id + ': ' + cases.join('；'));
  } catch (e) {
    log('interaction-incomplete', { id, message: e.stack, evidence }); console.error('INCOMPLETE ' + id + ': ' + e.stack);
    try { shot('incomplete'); back(); } catch (recovery) { console.error('RECOVERY: ' + recovery.message); break; }
    process.exitCode = 1;
  }
}
