module.exports = c => {
  const { assert, layout, texts, descendants, bounds, center, find, click, tap, wait, sleep, outcome, shell, swipe, strings } = c;
  const solvers = {}, suits = ['♠', '♥', '♦', '♣'], ranks = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
  const normalize = text => (text || '').replace(/\uFE0E/g, '').replace(/♤/g, '♠').replace(/♡/g, '♥').replace(/♢/g, '♦').replace(/♧/g, '♣');
  const cardText = n => [n.text, n.description, ...descendants(n).map(d => d.text)].map(normalize).find(text => /^(?:[♠♥♦♣](?:A|[2-9]|10|J|Q|K)|▧)$/.test(text)) || '';
  const value = text => text === '▧' ? -1 : suits.indexOf(text[0]) * 13 + ranks.indexOf(text.slice(1));
  const label = n => normalize(n.text || descendants(n).filter(d => d.text).map(d => d.text).join(' '));
  const scan = (raw, out = []) => { out.push({ ...raw.attributes, raw }); (raw.children || []).forEach(child => scan(child, out)); return out; };
  function tableaux(ns, classic = false) {
    const seen = new Set(), raw = ns.filter(n => n.type === 'Scroll').flatMap(n => scan(n.raw)).filter(n => { if (seen.has(n.hierarchy)) return false; seen.add(n.hierarchy); return true; });
    const all = raw.filter(n => { const b = bounds({ bounds: n.origBounds || n.bounds }); return n.type === 'Stack' && b[1] > 500 && b[2] - b[0] > 90 && b[2] - b[0] < 200 && b[3] - b[1] > 300; });
    return all.filter(n => scan(n.raw).some(d => d.type === 'Button' && label(d) === (classic ? 'K' : '○'))).sort((a, b) => bounds({ bounds: a.origBounds || a.bounds })[0] - bounds({ bounds: b.origBounds || b.bounds })[0]).map(n => ({
      node: n, cards: scan(n.raw).filter(d => d.type === 'Button' && (classic ? /^(?:[♠♥♦♣](?:A|[2-9]|10|J|Q|K)|▧)$/.test(cardText(d)) : descendants(d).some(child => child.type === 'Image'))).map(node => ({ node, card: cardText(node) ? value(cardText(node)) : -1 }))
    }));
  }
  function tapCard(node) {
    const b = bounds(node); assert(b[2] > b[0] && b[3] > b[1]);
    shell('uitest', 'uiInput', 'click', String(Math.round((b[0] + b[2]) / 2)), String(Math.round(b[1] + Math.min(28, (b[3] - b[1]) / 2))));
  }
  const red = card => Math.floor(card / 13) === 1 || Math.floor(card / 13) === 2;
  const compatible = (card, top, spider = false) => top % 13 === card % 13 + 1 && (spider || red(card) !== red(top));
  function cardView(expected) {
    const seen = new Map(), order = []; let latest;
    const observe = ns => {
      latest = ns;
      const columns = tableaux(ns);
      for (const column of columns) {
        const id = column.node.hashcode;
        if (!seen.has(id)) order.push(id);
        seen.set(id, column);
      }
      return columns;
    };
    const horizontal = (ns, right) => {
      const columns = tableaux(ns); assert(columns.length);
      const scroll = ns.filter(n => n.type === 'Scroll' && columns[0].node.hierarchy.startsWith(n.hierarchy + ',')).sort((a, b) => b.hierarchy.length - a.hierarchy.length)[0]; assert(scroll);
      const b = bounds(scroll), y = Math.round(b[1] + Math.min(250, (b[3] - b[1]) / 2));
      swipe(b[0] + (b[2] - b[0]) * (right ? .85 : .15), y, b[0] + (b[2] - b[0]) * (right ? .15 : .85), y, 900); sleep(180);
    };
    let ns = layout(); horizontal(ns, false); ns = layout(); observe(ns);
    horizontal(ns, true); observe(layout()); assert.equal(order.length, expected, 'Actual horizontal scroll did not reveal every card column');
    return {
      initial: order.map(id => seen.get(id)),
      column(index, ns = layout()) {
        let found = observe(ns).find(column => column.node.hashcode === order[index]);
        if (!found || bounds(found.node)[2] - bounds(found.node)[0] < 70) {
          horizontal(ns, index >= expected / 2); ns = layout(); found = observe(ns).find(column => column.node.hashcode === order[index]);
        }
        assert(found, 'Expected card column not visible after real scroll'); return found;
      },
      snapshot() { return latest; },
      all() { observe(layout()); return order.map(id => seen.get(id)); }
      , refresh() { let ns = layout(); horizontal(ns, false); observe(layout()); horizontal(layout(), true); observe(layout()); }
    };
  }
  solvers.freecell = () => {
    const view = cardView(8); let ns = layout(), columns = view.initial;
    const piles = columns.map(p => p.cards.map(c => c.card)); assert.equal(piles.flat().length, 52); assert.equal(new Set(piles.flat()).size, 52);
    const input = c.path.join(c.output, 'freecell-visible-deal.json'); c.fs.writeFileSync(input, JSON.stringify({ piles: [...piles, [], [], [], []], home: [0, 0, 0, 0] }));
    const solved = JSON.parse(c.cp.execFileSync(process.execPath, [c.path.join(__dirname, 'device-three-freecell-search.cjs'), input], { encoding: 'utf8', timeout: 180000, maxBuffer: 4 * 1024 * 1024 }));
    const topSlots = ns => ns.filter(n => n.type === 'Row' && (n.raw.children || []).filter(d => d.attributes.type === 'Button').length === 8).map(n => scan(n.raw).filter(d => d.type === 'Button'))[0];
    for (let i = 0; i < solved.moves.length; i++) {
      ns = layout(); if (outcome(ns)) return { strategy: 'independent search of actual face-up deal followed by native moves', moves: i, explored: solved.explored };
      const slots = topSlots(ns); assert(slots && slots.length === 8); const move = solved.moves[i];
      const source = move.from < 8 ? view.column(move.from, ns).cards.find(card => card.card === move.card)?.node : slots[move.from - 8]; assert(source, 'Expected visible source card missing');
      tapCard(source);
      if (move.to >= 8) click(slots[move.to - 8]);
      else { const dest = view.column(move.to, move.from < 8 ? view.snapshot() : ns); click(dest.cards.at(-1)?.node || scan(dest.node.raw).find(n => n.type === 'Button' && label(n) === '○')); }
      if (i % 15 === 0) c.shot('freecell-r' + c.activeRound + '-move-' + i);
    }
    return { strategy: 'completed searched actual face-up deal with native controls', moves: solved.moves.length, explored: solved.explored };
  };
  solvers.solitaire = () => {
    const read = () => {
      const ns = layout(); if (outcome(ns)) return { ns, settled: true };
      const columns = tableaux(ns, true); assert.equal(columns.length, 7);
      const stock = ns.find(n => n.type === 'Button' && /^牌库 \d+$/.test(label(n))); assert(stock);
      const row = ns.filter(n => n.type === 'Row' && stock.hierarchy.startsWith(n.hierarchy + ',')).at(-1); assert(row);
      const waste = scan(row.raw).find(n => n.type === 'Button' && cardText(n));
      const foundation = ns.filter(n => n.type === 'Row').map(n => (n.raw.children || []).filter(d => d.attributes.type === 'Button').map(d => ({ ...d.attributes, raw: d })))
        .find(buttons => buttons.length === 4 && buttons.every(n => suits.includes(label(n)) || cardText(n)));
      assert(foundation);
      return { ns, columns, stock, waste, foundation, home: foundation.map(n => cardText(n) ? value(cardText(n)) % 13 + 1 : 0) };
    };
    let totalMoves = 0;
    for (let deal = 0; deal < 12; deal++) {
      if (deal) { c.shot('solitaire-r' + c.activeRound + '-redeal-' + deal); c.restart(); }
      let ui = read(); const waste = [];
      while (+label(ui.stock).match(/\d+/)[0] > 0) {
        click(ui.stock); ui = read(); assert(ui.waste); waste.push(value(cardText(ui.waste))); totalMoves++;
      }
      let state = { stock: [], waste, piles: ui.columns.map(p => p.cards.map(card => card.card)), home: ui.home };
      assert.equal(waste.length + state.piles.flat().length, 52);
      for (let stage = 0; stage < 30; stage++) {
        const input = c.path.join(c.output, 'solitaire-visible-deal.json'); c.fs.writeFileSync(input, JSON.stringify(state));
        const plan = JSON.parse(c.cp.execFileSync(process.execPath, [c.path.join(__dirname, 'device-three-klondike-search.cjs'), input], { encoding: 'utf8', timeout: 120000, maxBuffer: 4 * 1024 * 1024 }));
        console.log('KLONDIKE round=' + c.activeRound + ' deal=' + (deal + 1) + ' stage=' + stage + ' hidden=' + plan.hidden + ' planned=' + plan.moves.length + ' explored=' + plan.explored);
        if (!plan.solved) break;
        for (const move of plan.moves) {
          ui = read(); if (ui.settled) return { strategy: 'searched observed Klondike cards, revealed hidden cards through legal moves, then won on phone', totalMoves, deals: deal + 1 };
          if (move.draw) click(ui.stock);
          else {
            const source = move.from === 7 ? ui.waste : ui.columns[move.from].cards[move.pos].node;
            assert.equal(value(cardText(source)), move.card, 'Visible Klondike source differs from planned card');
            tapCard(source);
            const dest = move.to >= 8 ? ui.foundation[move.to - 8] : ui.columns[move.to].cards.at(-1)?.node || scan(ui.columns[move.to].node.raw).find(n => n.type === 'Button' && label(n) === 'K');
            tapCard(dest);
          }
          totalMoves++;
        }
        ui = read(); if (ui.settled) return { strategy: 'searched observed Klondike cards and completed natural phone victory', totalMoves, deals: deal + 1 };
        const observed = ui.columns.map(p => p.cards.map(card => card.card));
        for (let i = 0; i < 7; i++) {
          assert.equal(observed[i].length, plan.final.piles[i].length, 'Native Klondike move did not change expected pile');
          for (let j = 0; j < observed[i].length; j++) if (plan.final.piles[i][j] >= 0) assert.equal(observed[i][j], plan.final.piles[i][j]);
        }
        assert.deepEqual(ui.home, plan.final.home);
        state = { stock: plan.final.stock, waste: plan.final.waste, piles: observed, home: ui.home };
        c.shot('solitaire-r' + c.activeRound + '-deal-' + deal + '-stage-' + stage);
      }
    }
    throw Error('Twelve actual Klondike deals exhausted without a phone victory');
  };
  solvers.spider = () => {
    let totalMoves = 0, stockDeals = 0;
    for (let deal = 0; deal < 12; deal++) {
      if (deal) { c.shot('spider-r' + c.activeRound + '-redeal-' + deal); c.restart(); }
      const view = cardView(10);
      for (let stage = 0; stage < 100; stage++) {
        const ns = layout(); if (outcome(ns)) return { strategy: 'searched exposed one-suit ranks and completed eight runs using native card controls', totalMoves, stockDeals, deals: deal + 1 };
        const columns = view.all(), piles = columns.map(p => p.cards.map(card => card.card < 0 ? -1 : card.card % 13));
        const stockButton = ns.find(n => n.type === 'Button' && /^牌库 \d+$/.test(label(n))); assert(stockButton);
        const stockCount = +label(stockButton).match(/\d+/)[0];
        const input = c.path.join(c.output, 'spider-visible-deal.json'); c.fs.writeFileSync(input, JSON.stringify({ piles, stock: stockCount }));
        const plan = JSON.parse(c.cp.execFileSync(process.execPath, [c.path.join(__dirname, 'device-three-spider-search.cjs'), input], { encoding: 'utf8', timeout: 120000, maxBuffer: 4 * 1024 * 1024 }));
        console.log('SPIDER round=' + c.activeRound + ' deal=' + (deal + 1) + ' stage=' + stage + ' stock=' + stockCount + ' hidden=' + piles.flat().filter(rank => rank < 0).length + ' planned=' + plan.moves.length + ' explored=' + plan.explored);
        if (plan.solved) {
          for (const move of plan.moves) {
            const src = view.column(move.from).cards[move.pos]; assert.equal(src.card % 13, move.rank);
            tapCard(src.node);
            const dest = view.column(move.to); tapCard(dest.cards.at(-1)?.node || scan(dest.node.raw).find(n => n.type === 'Button' && label(n) === '○'));
            totalMoves++;
          }
          if (outcome(layout())) return { strategy: 'completed eight actual Spider runs and natural phone victory', totalMoves, stockDeals, deals: deal + 1 };
          view.refresh();
          const after = view.all().map(p => p.cards.map(card => card.card < 0 ? -1 : card.card % 13));
          for (let i = 0; i < 10; i++) {
            assert.equal(after[i].length, plan.final[i].length, 'Native Spider move did not change expected column');
            for (let j = 0; j < after[i].length; j++) if (plan.final[i][j] >= 0) assert.equal(after[i][j], plan.final[i][j]);
          }
        } else {
          if (!stockCount) break;
          let filled = view.all();
          while (filled.some(pile => !pile.cards.length)) {
            const to = filled.findIndex(pile => !pile.cards.length), from = filled.findIndex(pile => pile.cards.length > 1);
            assert(from >= 0, 'Not enough visible cards to prepare ten stock columns');
            const src = view.column(from).cards.at(-1); tapCard(src.node);
            const dest = view.column(to); tapCard(scan(dest.node.raw).find(n => n.type === 'Button' && label(n) === '○'));
            totalMoves++; filled = view.all();
          }
          click(layout().find(n => n.type === 'Button' && /^牌库 [1-9]\d*$/.test(label(n)))); stockDeals++; view.refresh();
        }
        if (stage % 5 === 0) c.shot('spider-r' + c.activeRound + '-deal-' + deal + '-stage-' + stage);
      }
    }
    throw Error('Twelve actual Spider deals exhausted without a phone victory');
  };
  return solvers;
};
