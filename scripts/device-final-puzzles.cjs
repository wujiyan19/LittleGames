// Actual phone UI observations and touches only; no model imports or state injection.
process.env.LITTLEGAMES_ART_OUTPUT ||= 'docs/device-acceptance/final-2026-10-08';
const c = require('./device-art-review.cjs');
const crypto = require('node:crypto');
const framePixels = new WeakMap();
const frameFiles = new WeakMap();
const tileClasses = [];
const pixelWorker = `const sharp=require('sharp');const fs=require('fs');const file=process.argv[1],boxes=JSON.parse(process.argv[2]);
(async()=>{const image=sharp(file);const meta=await image.metadata();const result=[];for(const b of boxes){const left=Math.max(0,Math.round(b[0]+(b[2]-b[0])*.15)),top=Math.max(0,Math.round(b[1]+(b[3]-b[1])*.15)),right=Math.min(meta.width,Math.round(b[2]-(b[2]-b[0])*.15)),bottom=Math.min(meta.height,Math.round(b[3]-(b[3]-b[1])*.15));if(right<=left||bottom<=top)throw Error('Image target outside captured screen');result.push([...await sharp(file).extract({left,top,width:right-left,height:bottom-top}).removeAlpha().resize(8,8,{fit:'fill'}).raw().toBuffer()]);}process.stdout.write(JSON.stringify(result));})().catch(error=>{console.error(error);process.exitCode=1});`;
function pixelSamples(file, nodes) {
  const runtimeModules = c.path.resolve(c.path.dirname(process.execPath), '..', 'node_modules');
  return JSON.parse(c.cp.execFileSync(process.execPath, ['-e', pixelWorker, file, JSON.stringify(nodes.map(node => c.bounds(node)))], {
    encoding: 'utf8', timeout: 20000, env: { ...process.env, NODE_PATH: [process.env.NODE_PATH, runtimeModules].filter(Boolean).join(c.path.delimiter) }
  }));
}
const pixelDistance = (a, b) => a.reduce((total, value, index) => total + (value - b[index]) ** 2, 0) / a.length;
const strings = new Map(JSON.parse(c.fs.readFileSync('entry/src/main/resources/zh_CN/element/string.json', 'utf8')).string
  .map(s => [s.name, s.value]));
for (const [key, value] of strings) if (/^game_.+_name$/.test(key)) c.names[key.slice(5, -5)] = value;
const supported = ['blockfit', 'groupclear', 'linktiles', 'slotpair', 'parkingjam', 'screwout', 'buscolor', 'untangle'];
const id = process.argv[2];
if (id === '--list' || id === '--help') {
  console.log(id === '--list' ? supported.join('\n') :
    'node scripts/device-final-puzzles.cjs <game-id>\nIDs: ' + supported.join(', ') + '\n' +
    'Start on 分类 / 全部. Evidence is saved to puzzles.json, bound to the HAP hash and device.');
  process.exit(0);
}
c.assert.equal(process.argv.length, 3, 'Supply one supported game ID');
c.assert(supported.includes(id), 'Unsupported game ID: ' + id);
const reportFile = c.path.join(c.dir, 'puzzles.json');
const report = c.fs.existsSync(reportFile) ? JSON.parse(c.fs.readFileSync(reportFile, 'utf8')) : {
  schemaVersion: 1, packageSha256: c.packageHash, target: c.target,
  scope: 'Real native UI removal, placement, movement and undo; short interactions, not all full-game goals.', games: []
};
c.assert.equal(report.packageSha256, c.packageHash, 'Choose another evidence directory for a changed HAP');
c.assert.equal(report.target, c.target, 'Evidence belongs to another device');
const attemptId = new Date().toISOString().replace(/[^0-9]/g, '');
const result = { id, name: c.names[id], attemptId, status: 'running', startedAt: new Date().toISOString(), checks: [], evidence: [] };
report.games.push(result);
function save() { report.updatedAt = new Date().toISOString(); c.fs.writeFileSync(reportFile, JSON.stringify(report, null, 2) + '\n'); }
function check(name, details) {
  result.checks.push({ name, at: new Date().toISOString(), ...details }); save();
  c.log('puzzle-check-passed', { id, name, ...details }); console.log('PUZZLE ' + id + ' ' + name);
}
function shot(name) {
  const tag = 'puzzle-' + id + '-' + attemptId + '-' + name, ns = c.capture(tag);
  frameFiles.set(ns, c.path.join(c.dir, tag + '.jpeg'));
  if (['groupclear', 'linktiles', 'slotpair'].includes(id)) {
    const nativeCells = cellNodes(ns), samples = pixelSamples(c.path.join(c.dir, tag + '.jpeg'), nativeCells.map(cell => cell.node));
    nativeCells.forEach((cell, index) => {
      if (nativeAncestors(ns, cell.node).some(parent => Number(parent.opacity) < 0.5)) { cell.value = ''; return; }
      let klass = tileClasses.findIndex(sample => pixelDistance(sample, samples[index]) < 180);
      if (klass < 0) { tileClasses.push(samples[index]); klass = tileClasses.length - 1; }
      cell.value = 'visual-' + (klass + 1);
    });
    framePixels.set(ns, nativeCells);
  }
  result.evidence.push(tag + '.jpeg'); save(); return ns;
}
const byId = (ns, key) => ns.find(n => n.id === key);
const sheet = ns => !!byId(ns, 'game-settings-panel');
const visible = n => { const b = c.bounds(n); return b[2] > b[0] && b[3] > b[1]; };
function settings(ns = c.layout()) {
  const gear = byId(ns, 'game-settings-button'); c.assert(gear && !sheet(ns)); c.click(gear);
  return c.wait(nodes => sheet(nodes) && byId(nodes, 'game-settings-return'));
}
function closeSettings(ns = c.layout()) {
  c.click(byId(ns, 'game-settings-return'));
  return c.wait(nodes => !sheet(nodes) && byId(nodes, 'game-settings-button'));
}
function confirmAction(label, message, ns) {
  if (c.text(ns).includes(message)) {
    const actualButton = ns.filter(node => node.type === 'Button' &&
      (node.text === label || c.descendants(node).some(child => child.type === 'Text' && child.text === label))).at(-1);
    c.assert(actualButton, 'Actual confirmation action was absent'); c.click(actualButton);
    return c.wait(nodes => !sheet(nodes) && !c.text(nodes).includes(message));
  }
  return ns;
}
function difficulty(label = '简单') {
  let ns = settings();
  const selected = ns.filter(n => n.type === 'Button' && n.description === '已选择')
    .flatMap(n => c.descendants(n).filter(child => child.type === 'Text').map(child => child.text));
  if (!result.originalDifficulty) {
    result.originalDifficulty = selected.find(value => ['简单', '普通', '困难'].includes(value));
    c.assert(result.originalDifficulty, 'Current difficulty selection was not exposed by native UI'); save();
  }
  if (selected.includes(label)) { closeSettings(ns); return; }
  c.tap(label, ns);
  const message = strings.get('game_settings_difficulty_confirm');
  ns = c.wait(nodes => !sheet(nodes) || c.text(nodes).includes(message));
  confirmAction('切换并重开', message, ns);
  ns = settings();
  c.assert(ns.filter(n => n.type === 'Button' && n.description === '已选择')
    .some(n => c.descendants(n).some(child => child.text === label)), 'Requested difficulty was not selected');
  closeSettings(ns);
}
function restart() {
  let ns = c.layout();
  if (c.find(ns, '再来一局')) { c.tap('再来一局', ns); return c.wait(nodes => !c.find(nodes, '再来一局')); }
  ns = settings(ns); c.tap('重新开始', ns);
  const message = strings.get('game_settings_restart_confirm');
  ns = c.wait(nodes => !sheet(nodes) || c.text(nodes).includes(message));
  confirmAction('重新开始', message, ns);
  ns = c.wait(nodes => !sheet(nodes) && byId(nodes, 'game-settings-button'));
  c.assert(c.text(ns).some(value => /^得分 0 · 最高 \d+$/.test(value)), 'Visible score did not reset'); return ns;
}
function scroll(direction) {
  const ns = c.layout(), scroller = ns.find(n => n.type === 'Scroll' && n.scrollable === 'true');
  c.assert(scroller, 'Observed native game scroll absent');
  const b = c.bounds(scroller), x = Math.round((b[0] + b[2]) / 2), top = Math.round(b[1] + (b[3] - b[1]) * 0.25), bottom = Math.round(b[1] + (b[3] - b[1]) * 0.85);
  c.shell('uitest', 'uiInput', 'swipe', '' + x, '' + (direction === 'down' ? bottom : top), '' + x, '' + (direction === 'down' ? top : bottom), '1000');
  c.sleep(180); return c.layout();
}
function undo() {
  let ns = c.layout(), button = c.find(ns, strings.get('expansion_undo')), scrolled = 0;
  for (let i = 0; i < 3 && (!button || !visible(button)); i++) { ns = scroll('down'); scrolled++; button = c.find(ns, strings.get('expansion_undo')); }
  c.assert(button && button.enabled === 'true', 'Actual Undo button is unavailable'); c.click(button); c.sleep(180);
  for (let i = 0; i < scrolled; i++) scroll('up');
  return c.layout();
}
const cellPattern = /^第 (\d+) 行第 (\d+) 列：(.*)$/;
function nativeAncestors(ns, node) {
  return ns.filter(parent => parent.hierarchy && node.hierarchy?.startsWith(parent.hierarchy + ','))
    .sort((a, b) => b.hierarchy.length - a.hierarchy.length);
}
function cellNodes(ns) {
  const described = ns.filter(n => n.type === 'Button' && cellPattern.test(n.description || ''));
  if (described.length) return described.map(n => {
    const match = n.description.match(cellPattern); return { row: +match[1], col: +match[2], value: match[3], color: n.backgroundColor, node: n };
  }).sort((a, b) => a.row - b.row || a.col - b.col);
  const native = ns.filter(n => {
    if (n.type !== 'Button') return false;
    const b = c.bounds(n), width = b[2] - b[0], height = b[3] - b[1];
    return b[1] > 350 && width > 50 && width < 280 && Math.abs(width - height) < 12 &&
      c.descendants(n).filter(child => child.type === 'Image').length === 1;
  }).sort((a, b) => Math.abs(c.bounds(a)[1] - c.bounds(b)[1]) < 20 ? c.bounds(a)[0] - c.bounds(b)[0] : c.bounds(a)[1] - c.bounds(b)[1]);
  let row = 0, previousTop = -Infinity, col = 0;
  return native.map(node => {
    const top = c.bounds(node)[1]; if (Math.abs(top - previousTop) > 20) { row++; col = 0; previousTop = top; } col++;
    const column = nativeAncestors(ns, node).find(parent => parent.type === 'Column' && parent.backgroundColor !== '#00000000');
    return { row, col, value: '', color: column?.backgroundColor || node.backgroundColor, node };
  });
}
const cells = ns => framePixels.get(ns) || cellNodes(ns);
const cellValues = ns => cells(ns).map(cell => ({ row: cell.row, col: cell.col, value: cell.value }));
const cellColors = ns => cells(ns).map(cell => ({ row: cell.row, col: cell.col, color: cell.color }));
const occupied = ns => cells(ns).filter(cell => cell.value !== '');
function undoCells(before, mode = 'value') {
  undo(); const after = shot('undo');
  c.assert.deepEqual(mode === 'color' ? cellColors(after) : cellValues(after), mode === 'color' ? cellColors(before) : cellValues(before), 'Undo did not restore rendered cells');
  check('undo-restores-native-board', { cellCount: cells(after).length, comparison: mode }); return after;
}
function matching() {
  let before = shot('before'), all = cells(before); c.assert(all.length);
  if (id === 'slotpair') {
    c.assert.equal(occupied(before).length, 0, 'Restart board was not empty');
    const drop = before.find(n => n.type === 'Button' && n.description === '投放到第 1 列') || all[all.length - 6].node;
    c.click(drop); c.sleep(180); const placed = shot('placed');
    c.assert.equal(occupied(placed).length, 1, 'The actual dropped tile was not rendered');
    c.assert(c.text(placed).includes('进度 1 / 40'), 'Drop progress was not refreshed');
    check('drop-refreshes-board-and-progress', { tile: occupied(placed).map(cell => ({ row: cell.row, col: cell.col, symbol: cell.value })) });
    undoCells(before); return;
  }
  let pair;
  for (let attempt = 0; attempt < 6; attempt++) {
    all = cells(before);
    const pairs = all.flatMap(a => all.filter(b => a.value && a.value === b.value && Math.abs(a.row - b.row) + Math.abs(a.col - b.col) === 1).map(b => [a, b]));
    pair = id === 'groupclear' ? pairs.findLast(items => items[0].row > 1) || pairs[0] : pairs[0];
    if (pair) break;
    c.assert.equal(id, 'linktiles', 'No adjacent equal group in actual opening');
    c.tap(strings.get('expansion_rearrange'), before); c.sleep(180); before = shot('rearrange-' + attempt);
  }
  c.assert(pair, 'No adjacent equal pair observed after actual rearrangements');
  if (id === 'linktiles') { c.click(pair[0].node); c.sleep(180); c.click(cells(c.layout()).find(cell => cell.row === pair[1].row && cell.col === pair[1].col).node); }
  else c.click(pair[0].node);
  c.sleep(180); const after = shot('cleared');
  if (id === 'linktiles') {
    for (const cell of pair) c.assert.equal(cells(after).find(current => current.row === cell.row && current.col === cell.col).value, '', 'Selected pair did not disappear');
    c.assert.equal(occupied(before).length - occupied(after).length, 2);
    check('adjacent-equal-pair-disappears', { pair: pair.map(cell => ({ row: cell.row, col: cell.col, symbol: cell.value })) });
  } else {
    const count = occupied(before).length - occupied(after).length; c.assert(count >= 2, 'Actual group did not disappear');
    const group = [pair[0]], seen = new Set([pair[0].row + ':' + pair[0].col]);
    for (let at = 0; at < group.length; at++) for (const neighbor of all) {
      const key = neighbor.row + ':' + neighbor.col;
      if (!seen.has(key) && neighbor.value === pair[0].value && Math.abs(neighbor.row - group[at].row) + Math.abs(neighbor.col - group[at].col) === 1) { seen.add(key); group.push(neighbor); }
    }
    c.assert.equal(count, group.length, 'Rendered removal count differed from the observed connected group');
    const columns = [];
    for (let col = 1; col <= 6; col++) {
      const retained = all.filter(cell => cell.col === col && cell.value && !seen.has(cell.row + ':' + cell.col)).map(cell => cell.value);
      if (retained.length) columns.push(retained);
    }
    const expected = cells(after).map(cell => {
      const column = columns[cell.col - 1] || [], offset = cell.row - (8 - column.length + 1);
      return { row: cell.row, col: cell.col, value: offset < 0 ? '' : column[offset] || '' };
    });
    c.assert.deepEqual(cellValues(after), expected, 'Actual screenshot did not settle the retained tiles downward and collapse empty columns');
    for (let col = 1; col <= 6; col++) {
      const column = cells(after).filter(cell => cell.col === col); let foundTile = false;
      for (const cell of column) { if (cell.value) foundTile = true; else c.assert(!foundTile, 'Gap remained below a settled group-clear tile'); }
    }
    check('equal-group-removal-and-gravity', { removed: count, board: cellValues(after) });
  }
  undoCells(before);
}
function traySlots(ns) {
  return ns.filter(n => n.type === 'Button' && c.descendants(n).some(child => child.type === 'Text' && /^拼块 [123]$/.test(child.text)))
    .sort((a, b) => c.bounds(a)[0] - c.bounds(b)[0]);
}
function blockfit() {
  let before = shot('before'), slots = traySlots(before); c.assert.equal(slots.length, 3);
  c.assert(slots.every(slot => slot.enabled === 'true'), 'Initial slot unavailable');
  c.click(slots[0]); c.sleep(180); before = c.layout(); const board = cells(before); c.assert.equal(board.length, 36);
  c.click(board[0].node); c.sleep(180); const after = shot('placed'), consumed = traySlots(after);
  c.assert.equal(consumed[0].enabled, 'false', 'Consumed slot remained enabled');
  const previews = c.descendants(consumed[0]).filter(node => node.type === 'Image'); c.assert.equal(previews.length, 9);
  c.assert(previews.every(node => Number(node.opacity) === 0), 'Consumed shape preview remained visible');
  c.assert.notDeepEqual(cellColors(after), cellColors(before), 'Placed shape did not change any real cell color');
  check('slot-consumption-clears-preview-and-updates-board', { enabled: consumed[0].enabled, previewOpacities: previews.map(node => node.opacity) });
  const restored = undoCells(before, 'color'); c.assert.equal(traySlots(restored)[0].enabled, 'true');
  c.assert(c.descendants(traySlots(restored)[0]).some(node => node.type === 'Image' && Number(node.opacity) > 0));
  check('undo-restores-slot-shape-and-enabled-state', { enabled: traySlots(restored)[0].enabled });
}
function cars(ns) {
  return ns.filter(n => n.type === 'Button' && c.descendants(n).some(child => child.type === 'Text' && /^[↑→↓←]$/.test(child.text)))
    .map(node => ({ ...node, description: node.description || '车辆 UI ' + (node.origBounds || node.bounds) + '，方向 ' + c.descendants(node).find(child => /^[↑→↓←]$/.test(child.text)).text }));
}
function carClear(car, all) {
  const b = c.bounds(car), direction = car.description.slice(-1);
  return !all.some(other => {
    if (other === car) return false; const o = c.bounds(other);
    if (direction === '↑') return o[3] <= b[1] && o[0] < b[2] && o[2] > b[0];
    if (direction === '↓') return o[1] >= b[3] && o[0] < b[2] && o[2] > b[0];
    if (direction === '←') return o[2] <= b[0] && o[1] < b[3] && o[3] > b[1];
    return o[0] >= b[2] && o[1] < b[3] && o[3] > b[1];
  });
}
function parking() {
  const before = shot('before'), all = cars(before); c.assert(all.length > 1);
  const car = all.find(candidate => carClear(candidate, all)); c.assert(car, 'No car with clear visible ray');
  c.click(car); c.sleep(180); const after = shot('departed');
  c.assert(!cars(after).some(other => other.description === car.description), 'Departed car remains in native UI');
  c.assert.equal(cars(after).length, all.length - 1); check('clear-ray-car-disappears', { car: car.description, bounds: car.bounds, remaining: cars(after).length });
  undo(); const restored = shot('undo');
  c.assert.deepEqual(cars(restored).map(node => node.description).sort(), all.map(node => node.description).sort());
  check('undo-restores-departed-car', { car: car.description });
}
function screws(ns) {
  const all = ns.filter(n => n.type === 'Button' && (n.description?.includes('块板的螺丝') ||
    (c.bounds(n)[1] > 350 && c.bounds(n)[2] - c.bounds(n)[0] < 150 && c.bounds(n)[2] - c.bounds(n)[0] > 60 && c.descendants(n).filter(child => child.type === 'Image').length === 1)));
  const ys = [...new Set(all.map(n => c.bounds(n)[1]))].sort((a, b) => a - b);
  return all.map(node => ({ ...node, description: node.description || '第 ' + (ys.indexOf(c.bounds(node)[1]) + 1) + ' 块板的螺丝' }));
}
function plateImages(ns) {
  return ns.filter(n => n.type === 'Image' && n.parent?.attributes?.type === 'Stack' &&
    n.parent.attributes.backgroundImage === 'true' && n.hitTestBehavior === 'HitTestMode.None' && Number(n.opacity) > 0);
}
function screwout() {
  const before = shot('before'), all = screws(before); c.assert(all.length >= 9);
  const topY = Math.max(...all.map(node => c.bounds(node)[1]));
  const top = Math.max(...all.map(node => +node.description.match(/\d+/)[0]));
  const topButtons = nodes => screws(nodes).filter(node => Math.abs(c.bounds(node)[1] - topY) < 10);
  c.assert.equal(topButtons(before).length, 3);
  const plateCount = plateImages(before).length; c.assert(plateCount >= 3, 'Rendered plate images were not identified');
  for (let i = 0; i < 3; i++) {
    const ns = c.layout(), screw = topButtons(ns).sort((a, b) => c.bounds(a)[0] - c.bounds(b)[0])[0];
    c.assert(screw); c.click(screw); c.sleep(180); const after = shot('screw-' + (i + 1));
    c.assert.equal(topButtons(after).length, 2 - i, 'Unscrewed button remained visible');
  }
  const cleared = c.layout(); c.assert.equal(plateImages(cleared).length, plateCount - 1, 'Top plate did not disappear after its final screw');
  check('three-screws-and-top-plate-disappear', { topPlate: top, platesBefore: plateCount, platesAfter: plateImages(cleared).length });
  undo(); const restored = shot('undo');
  c.assert.equal(topButtons(restored).length, 1);
  c.assert.equal(plateImages(restored).length, plateCount); check('undo-restores-final-screw-and-plate', { topPlate: top });
}
function rawNodes(raw) {
  const out = []; const visit = node => { out.push(node.attributes); (node.children || []).forEach(visit); }; visit(raw); return out;
}
function followingRow(ns, label) {
  const title = ns.find(node => node.type === 'Text' && node.text === label); c.assert(title && title.parent, 'Observed section label absent: ' + label);
  const siblings = title.parent.children, at = siblings.indexOf(title.raw), row = siblings.slice(at + 1).find(raw => raw.attributes.type === 'Row');
  c.assert(at >= 0 && row, 'Observed section row absent: ' + label); return row;
}
function busSnapshot(ns) {
  const queueRow = followingRow(ns, strings.get('expansion_passenger_queue'));
  const parkedLabel = c.text(ns).find(value => /^候车位 \d+ \/ 3$/.test(value)); c.assert(parkedLabel);
  const parkedRow = followingRow(ns, parkedLabel), parked = rawNodes(parkedRow);
  const queueImages = rawNodes(queueRow).filter(node => node.type === 'Image');
  const queue = busColors(ns, queueImages, 'person');
  const progressLabel = c.text(ns).find(value => /^进度 \d+ \/ 36$/.test(value)); c.assert(progressLabel);
  const laneLabels = ns.filter(node => node.type === 'Text' && /^轨道 [123]$/.test(node.text || ''));
  const buses = [];
  for (const title of laneLabels) {
    const buttons = (title.parent.children || []).filter(raw => raw.attributes.type === 'Button' && raw.attributes.enabled === 'true');
    const busImages = buttons.map(raw => rawNodes(raw).find(node => node.type === 'Image'));
    const colors = busColors(ns, busImages, 'bus');
    buttons.forEach((raw, index) => buses.push({ lane: +title.text.match(/\d+/)[0], position: index + 1,
      color: colors[index], enabled: raw.attributes.enabled, node: raw.attributes }));
  }
  c.assert(buses.length >= 1 && buses.length <= 3, 'Visible bus lane heads were not identified');
  c.assert(queue.length && queue.every(color => color.startsWith('visual-color-')), 'Actual passenger colors were not classified');
  const parkedImages = parked.filter(node => node.type === 'Image');
  const seats = [];
  const seatRows = raw => {
    if (raw.attributes.type === 'Row' && raw.children?.length === 3 && raw.children.every(child => child.attributes.type === 'Text' && /^[●○]$/.test(child.attributes.text)))
      seats.push(...raw.children.map(child => child.attributes.text));
    (raw.children || []).forEach(seatRows);
  };
  seatRows(parkedRow);
  return { queue, progress: +progressLabel.match(/\d+/)[0], buses,
    parkedColors: busColors(ns, parkedImages, 'bus'),
    occupiedSeats: seats.filter(value => value === '●').length,
    emptySeats: seats.filter(value => value === '○').length };
}
function busColors(ns, images, kind) {
  if (!images.length) return [];
  const file = frameFiles.get(ns); c.assert(file, 'Bus colors require the matching native screenshot');
  const regions = images.map(node => {
    const b = c.bounds(node), size = Math.min(b[2] - b[0], b[3] - b[1]), left = (b[0] + b[2] - size) / 2, top = (b[1] + b[3] - size) / 2;
    return { bounds: '[' + Math.round(left + size * (kind === 'person' ? .3 : .15)) + ',' + Math.round(top + size * .56) + '][' +
      Math.round(left + size * (kind === 'person' ? .7 : .85)) + ',' + Math.round(top + size * (kind === 'person' ? .8 : .69)) + ']' };
  });
  const hues = [212, 12, 40, 152, 257, 194];
  return pixelSamples(file, regions).map(sample => {
    const rgb = [0, 0, 0]; for (let i = 0; i < sample.length; i++) rgb[i % 3] += sample[i] / (sample.length / 3);
    const max = Math.max(...rgb), min = Math.min(...rgb), delta = max - min; c.assert(delta > 20, 'Bus/person crop has insufficient chromatic pixels');
    let hue = (max === rgb[0] ? (rgb[1] - rgb[2]) / delta : max === rgb[1] ? (rgb[2] - rgb[0]) / delta + 2 : (rgb[0] - rgb[1]) / delta + 4) * 60;
    hue = (hue + 360) % 360;
    const distances = hues.map(reference => Math.min(Math.abs(reference - hue), 360 - Math.abs(reference - hue))), closest = Math.min(...distances);
    c.assert(closest < 17, 'Screenshot hue is ambiguous: ' + hue.toFixed(1));
    return 'visual-color-' + (distances.indexOf(closest) + 1);
  });
}
const simpleBus = state => ({ queue: state.queue, progress: state.progress,
  buses: state.buses.map(bus => ({ lane: bus.lane, position: bus.position, color: bus.color, enabled: bus.enabled })),
  parkedColors: state.parkedColors, occupiedSeats: state.occupiedSeats, emptySeats: state.emptySeats });
function buscolor() {
  difficulty('普通');
  let before, state, first;
  for (let attempt = 0; attempt < 8; attempt++) {
    restart(); before = shot('candidate-' + attempt); state = busSnapshot(before);
    first = state.buses.find(bus => bus.enabled === 'true' && bus.color === state.queue[0]);
    if (first && state.queue.slice(0, 3).some(color => color !== first.color)) break;
  }
  c.assert(first && state.queue.slice(0, 3).some(color => color !== first.color), 'No visible mixed FIFO opening with a matching lane head after actual new games');
  shot('before'); c.click(first.node); c.sleep(180); const seatedNs = shot('seated'), seated = busSnapshot(seatedNs);
  let boarded = 0; while (boarded < 3 && state.queue[boarded] === first.color) boarded++;
  c.assert.equal(seated.progress, boarded, 'FIFO progress did not match contiguous passenger colors');
  c.assert(seated.parkedColors.includes(first.color), 'Part-filled bus did not enter a parking slot');
  c.assert.equal(seated.occupiedSeats, boarded, '● seat symbols did not update after boarding');
  c.assert.equal(seated.emptySeats, 3 - boarded, '○ seat symbols did not reflect remaining seats');
  c.assert.deepEqual(seated.queue.slice(0, state.queue.length - boarded), state.queue.slice(boarded), 'Passenger queue did not shift in FIFO order');
  c.assert(!seated.buses.some(bus => bus.node.hashcode === first.node.hashcode), 'Launched lane bus remained in the lane');
  check('native-seat-count-and-fifo-queue-refresh', { before: simpleBus(state), after: simpleBus(seated), launched: { lane: first.lane, position: first.position, color: first.color } });
  let current = seated, departed = false;
  for (let move = 0; move < 5 && !departed; move++) {
    const choice = current.buses.find(bus => bus.enabled === 'true' && bus.color === current.queue[0]);
    c.assert(choice, 'Observed FIFO needs a lane opening not covered by this short scenario');
    c.click(choice.node); c.sleep(180); const afterNs = shot('boarding-' + (move + 1)), after = busSnapshot(afterNs);
    c.assert(after.progress > current.progress, 'Matched head passenger did not board');
    departed = !after.parkedColors.includes(first.color);
    current = after;
  }
  c.assert(departed, 'The first filled bus did not visibly leave the parking slot');
  check('filled-bus-departs', { firstColor: first.color, after: simpleBus(current), scope: 'Departure disappearance after native FIFO boarding, not an intermediate animation frame.' });
}
function knotNodes(ns) {
  return ns.filter(node => node.type === 'Text' && /^\d+$/.test(node.text || '') && Number(node.backgroundColor?.slice(-6)) !== 0 &&
    c.bounds(node)[1] > 350 && Math.abs(c.bounds(node)[2] - c.bounds(node)[0] - c.bounds(node)[3] + c.bounds(node)[1]) < 12).map(node => ({
    number: +node.text, hashcode: node.hashcode, bounds: node.origBounds || node.bounds, node
  })).sort((a, b) => a.number - b.number);
}
function untangle() {
  const before = shot('before'), nodes = knotNodes(before); c.assert.equal(nodes.length, 6);
  const field = before.find(node => node.type === 'Stack' && node.backgroundImage === 'true' &&
    nodes.every(item => item.node.hierarchy.startsWith(node.hierarchy + ','))); c.assert(field, 'Observed knot board absent');
  const b = c.bounds(field), width = b[2] - b[0], height = b[3] - b[1], node = nodes[0], nb = c.bounds(node.node);
  const start = [Math.round((nb[0] + nb[2]) / 2), Math.round((nb[1] + nb[3]) / 2)];
  const candidate = [[0.12, 0.15], [0.85, 0.15], [0.15, 0.85], [0.85, 0.85], [0.45, 0.35]]
    .map(point => [Math.round(b[0] + width * point[0]), Math.round(b[1] + height * point[1])])
    .find(point => Math.hypot(point[0] - start[0], point[1] - start[1]) > width * 0.15 &&
      nodes.slice(1).every(item => { const other = c.bounds(item.node); return Math.hypot(point[0] - (other[0] + other[2]) / 2, point[1] - (other[1] + other[3]) / 2) > width * 0.13; }));
  c.assert(candidate, 'No free visible node destination');
  c.shell('uitest', 'uiInput', 'swipe', ...start.map(String), ...candidate.map(String), '1000'); c.sleep(180);
  const after = shot('dragged'), moved = knotNodes(after).find(item => item.number === node.number); c.assert(moved);
  c.assert.equal(moved.hashcode, node.hashcode, 'Drag rebuilt the native node rather than updating its position');
  c.assert.notEqual(moved.bounds, node.bounds, 'Native knot node stayed at its old position');
  const lineCount = ns => ns.filter(item => item.type === 'Line' && item.hierarchy.startsWith(field.hierarchy + ',')).length;
  c.assert.equal(lineCount(after), lineCount(before));
  check('drag-updates-same-native-node', { number: node.number, hashcode: moved.hashcode, before: node.bounds, after: moved.bounds,
    lines: lineCount(after), lineEndpoints: 'dumpLayout does not expose Line endpoints; before/dragged screenshots require visual inspection to confirm lines follow the node.' });
  undo(); const restored = shot('undo');
  c.assert.deepEqual(knotNodes(restored).map(item => ({ number: item.number, bounds: item.bounds })),
    nodes.map(item => ({ number: item.number, bounds: item.bounds })), 'Undo did not restore actual node positions');
  check('undo-restores-node-positions', { nodes: nodes.length });
}
function finishKnownUi() {
  let ns = c.layout();
  if (byId(ns, 'home_category_search')) { result.returnedToCatalog = true; save(); return; }
  if (sheet(ns)) ns = closeSettings(ns);
  if (c.find(ns, '再来一局') && c.find(ns, '退出') && result.originalDifficulty) {
    c.tap('再来一局', ns); ns = c.wait(nodes => !c.find(nodes, '再来一局') && byId(nodes, 'game-settings-button'));
  }
  const modal = ns.some(node => /^(AlertDialog|Dialog|ModalDialog)$/.test(node.type)) ||
    c.find(ns, '确认退出？') || c.text(ns).includes(strings.get('game_settings_restart_confirm')) ||
    c.text(ns).includes(strings.get('game_settings_difficulty_confirm'));
  c.assert(byId(ns, 'game-settings-button') && !modal, 'Unknown or unresolved UI: leave phone for manual observation');
  if (result.originalDifficulty) {
    difficulty(result.originalDifficulty); result.difficultyRestored = result.originalDifficulty; save();
  }
  c.back(); result.returnedToCatalog = true; save();
}
function main() {
  save(); c.assert.equal(crypto.createHash('sha256').update(c.fs.readFileSync('entry/build/default/outputs/default/entry-default-signed.hap')).digest('hex'), c.packageHash);
  c.assert(byId(c.layout(), 'home_category_search'), 'Start this independent check on 分类');
  c.open(id); difficulty(); restart();
  if (['groupclear', 'linktiles', 'slotpair'].includes(id)) matching();
  else if (id === 'blockfit') blockfit(); else if (id === 'parkingjam') parking(); else if (id === 'screwout') screwout();
  else if (id === 'buscolor') buscolor(); else untangle();
  restart(); shot('restart'); check('restart-visible-score-zero', { text: c.text(c.layout()) });
  finishKnownUi(); result.status = 'passed'; result.finishedAt = new Date().toISOString(); save();
}
try { main(); } catch (error) {
  result.status = 'incomplete'; result.error = error.stack; result.finishedAt = new Date().toISOString(); save();
  try { shot('incomplete'); } catch (captureError) { result.captureError = captureError.message; save(); }
  try { finishKnownUi(); } catch (cleanupError) { result.cleanupError = cleanupError.message; save(); }
  c.log('puzzle-check-incomplete', { id, message: error.stack }); console.error(error.stack); process.exitCode = 1;
}
