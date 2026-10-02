// Additional checks use only observed UI nodes and real input.
const d = require('./device-tablet-window.cjs');
const values = ns => ns.filter(n => n.type === 'Stack' && n.clickable === 'true')
  .map(n => n.raw.children.find(child => child.attributes.type === 'Text')?.attributes.text || '0');
const passed = (id, assertion) => d.record('interaction', {
  id, status: 'passed', assertion, packageHash: d.packageHash()
});

function rotation() {
  const ns = d.layout();
  const window = ns.find(n => n.type === 'NavDestination');
  const area = d.bounds(window);
  d.assert(area[2] - area[0] === 2880 && area[3] - area[1] <= 1920, 'Tablet must actually be landscape');
  const before = JSON.parse(d.fs.readFileSync(d.path.join(d.scratch, 'slide-state-before-rotate.json')));
  d.assert.deepEqual(values(ns), before, 'Rotation must preserve tile order');
  d.assert(ns.some(n => n.text === '步数'));
  d.assert(ns.some(n => n.text === '1'));
  d.capture('landscape-slide-state');
  passed('physical-rotation', 'Portrait to landscape preserves 16 tile values and step count 1');
  console.log('PASS physical rotation');
}

function brickDrag() {
  d.back();
  d.open('打砖块');
  const paddle = ns => ns.find(n => {
    if (n.type !== 'Image') return false;
    const b = d.bounds(n);
    return b[3] > b[1] && (b[2] - b[0]) / (b[3] - b[1]) > 5;
  });
  let ns = d.layout();
  const before = d.bounds(paddle(ns));
  const board = ns.find(n => n.type === 'Stack' && n.clickable === 'true');
  const b = d.bounds(board);
  d.assert(before.length === 4 && b.length === 4, 'Rendered board and paddle must exist');
  const x = Math.round((before[0] + before[2]) / 2);
  const y = Math.round((before[1] + before[3]) / 2);
  const shift = Math.round((b[2] - b[0]) * 0.15);
  d.shell('uitest', 'uiInput', 'swipe', String(x), String(y), String(x + shift), String(y), '600');
  ns = d.wait(a => {
    const after = paddle(a);
    return after && d.bounds(after)[0] > before[0] + shift * 0.5;
  });
  // Pause through the observed header button before recording the moving game.
  const headerButtons = ns.filter(n => n.type === 'Button' && d.bounds(n)[1] < b[1]);
  d.assert(headerButtons.length === 3);
  d.click(headerButtons[1]);
  d.capture('brick-scaled-drag');
  passed('brick-scaled-drag', 'Rendered paddle moves right after a real swipe on the scaled board');
  console.log('PASS brick drag');
  d.back();
}

function ticTacToeResult() {
  d.open('井字棋');
  const cells = ns => ns.filter(n => n.type === 'Button').filter(n => {
    const b = d.bounds(n);
    return b[2] - b[0] > 90 && b[3] - b[1] > 90;
  });
  let ns = d.layout();
  d.assert.equal(cells(ns).length, 9);
  // Same-screen alternating turns, X completes the top row.
  for (const index of [0, 3, 1, 4, 2]) {
    d.click(cells(d.layout())[index]);
    d.sleep(120);
  }
  ns = d.wait(a => d.find(a, '再来一局'));
  d.capture('landscape-result-dialog');
  const window = d.bounds(ns.find(n => n.type === 'NavDestination'));
  for (const label of ['再来一局', '退出']) {
    const button = d.find(ns, label);
    const b = d.bounds(button);
    d.assert(b[0] >= window[0] && b[1] >= window[1] && b[2] <= window[2] && b[3] <= window[3]);
    d.assert.equal(button.bounds, button.origBounds);
  }
  d.tap('再来一局', ns);
  d.wait(a => !d.find(a, '再来一局'));
  d.capture('landscape-result-restarted');
  passed('result-dialog', 'Five real turns produce a win; both buttons fit; restart clears the result');
  console.log('PASS result dialog');
  d.back();
}

const action = process.argv[2];
if (action === 'rotation') rotation();
else if (action === 'brick') brickDrag();
else if (action === 'result') ticTacToeResult();
else throw Error('Choose rotation, brick or result');
