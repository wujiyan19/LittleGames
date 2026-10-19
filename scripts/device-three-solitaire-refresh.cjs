// Observe five normal stock draws; each must show a different actual card.
const c = require('./device-three-settlements.cjs');
const phase = process.argv[2];
c.assert(['before', 'after'].includes(phase));
c.shell('aa', 'start', '-b', 'com.littlegames.collection', '-a', 'EntryAbility');
c.sleep(600);
c.open('solitaire');
const original = c.difficulty('简单');
try {
  c.restart();
  const observed = [];
  c.shot('solitaire-waste-' + phase + '-start');
  for (let draw = 1; draw <= 5; draw++) {
    const ns = c.layout();
    c.click(ns.find(n => n.type === 'Button' && /^牌库 \d+$/.test(n.text)));
    c.sleep(350);
    const after = c.shot('solitaire-waste-' + phase + '-draw-' + draw);
    const stock = after.find(n => n.type === 'Button' && /^牌库 \d+$/.test(n.text));
    const row = after.filter(n => n.type === 'Row' && stock.hierarchy.startsWith(n.hierarchy + ',')).at(-1);
    const card = c.texts(after).filter(text => /^[♤♡♢♧](?:A|[2-9]|10|J|Q|K)$/.test(text) &&
      after.some(n => n.type === 'Text' && n.text === text && n.hierarchy.startsWith(row.hierarchy + ',')))[0];
    c.assert(card, 'Actual waste Text missing');
    observed.push({ draw, stock: stock.text, card });
    console.log(JSON.stringify(observed.at(-1)));
  }
  c.fs.writeFileSync(c.path.join(c.output, 'solitaire-waste-' + phase + '.json'), JSON.stringify(observed, null, 2) + '\n');
  c.assert.equal(new Set(observed.map(item => item.card)).size, 5, 'Five stock draws did not render five distinct cards');
} finally {
  c.difficulty(original);
  c.category();
}
