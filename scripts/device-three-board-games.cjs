// Plan from rendered cells only. The phone's legal highlights and result dialog
// remain authoritative; this local rules instance never accesses phone app data.
module.exports = c => {
  delete require.cache[require.resolve('./device-three-vision-api.cjs')];
  const v = require('./device-three-vision-api.cjs')(c);
  const solvers = {};
  const background = (node, ns) => ns.filter(p => node.hierarchy.startsWith(p.hierarchy + ',') && p.type === 'Column' && p.backgroundColor !== '#00000000').at(-1)?.backgroundColor;
  for (const id of ['xiangqi', 'chess']) solvers[id] = () => {
    const fixture = require('./test-performance.cjs').fixture();
    const Engine = fixture.load('entry/src/main/ets/model/game/ExpansionChess.ets').ExpansionChess;
    const State = fixture.load('entry/src/main/ets/model/game/ExpansionState.ets').ExpansionState;
    const engine = new Engine({ next: () => .5 });
    for (let turns = 0; turns < 150; turns++) {
      let ns = c.wait(nodes => c.outcome(nodes) || c.texts(nodes).includes(c.strings.get('computer_your_turn')), 30000);
      if (c.outcome(ns)) return { strategy: 'screenshot-derived legal sacrificial moves exercised captures and a natural mate/draw result on phone', turns };
      const cells = v.cells(ns); c.assert.equal(cells.length, id === 'chess' ? 64 : 90);
      let board;
      if (id === 'xiangqi') {
        const colors = v.redText(cells);
        const types = { 帥: 1, 將: 1, 仕: 2, 士: 2, 相: 3, 象: 3, 馬: 4, 車: 5, 炮: 6, 砲: 6, 兵: 7, 卒: 7 };
        board = cells.map((node, i) => {
          const text = c.descendants(node).find(d => d.type === 'Text' && d.text)?.text;
          if (!text) return 0;
          c.assert(types[text], text); return types[text] + (colors[i].red ? 0 : 10);
        });
      } else {
        const names = v.classify(cells, ['exp_empty', ...v.family('exp_chess_0_', 6), ...v.family('exp_chess_1_', 6)]);
        board = names.map(name => name === 'exp_empty' ? 0 : +name.split('_')[3] + 1 + +name.split('_')[2] * 10);
      }
      c.assert.equal(board.filter(piece => piece === 1).length, 1);
      c.assert.equal(board.filter(piece => piece === 11).length, 1);
      const state = new State(); state.id = id; state.cols = id === 'chess' ? 8 : 9; state.rows = id === 'chess' ? 8 : 10;
      state.board = board; state.data = [1, 1, 1, 1, 1, 1, 0, 0, 0, 2]; state.cursor = 0;
      const legal = engine.moves(state, 1), originalBoard = state.board.slice(), originalData = state.data.slice();
      c.assert(legal.length, 'No legal move in screenshot-derived board');
      let move, best = -Infinity;
      for (const candidate of legal) {
        state.board = originalBoard.slice(); state.data = originalData.slice();
        engine.apply(state, candidate.from, candidate.to, true);
        const reply = engine.ranked(state, engine.moves(state, 2), 2)[0];
        let score = 1e9;
        if (reply) {
          engine.apply(state, reply.move.from, reply.move.to, true);
          score = engine.moves(state, 1).length ? engine.evaluate(state) + (engine.checked(state, 1) ? 10000 : 0) : 1e9;
        }
        if (score > best) { best = score; move = candidate; }
      }
      c.assert(move);
      const before = background(cells[move.to], ns);
      c.click(cells[move.from]); ns = c.layout();
      if (c.outcome(ns)) return { strategy: 'phone natural board result', turns };
      const after = v.cells(ns);
      c.assert.notEqual(background(after[move.to], ns), before, 'Phone did not highlight the planned destination as legal');
      c.click(after[move.to]); c.sleep(400);
      if (turns % 10 === 0) c.shot(id + '-r' + c.activeRound + '-planned-turn-' + turns);
    }
    throw Error('Phone board did not naturally settle within 150 player turns');
  };
  return solvers;
};
