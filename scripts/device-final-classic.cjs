// Native UI acceptance only: real gestures, rendered attributes and screenshots.
// Run one game at a time from 分类 / 全部. No models or application state injection.
process.env.LITTLEGAMES_ART_OUTPUT ||= 'docs/device-acceptance/final-2026-10-09';
const c = require('./device-art-review.cjs');
const crypto = require('node:crypto');
const strings = new Map(JSON.parse(c.fs.readFileSync('entry/src/main/resources/zh_CN/element/string.json', 'utf8')).string
  .map(s => [s.name, s.value]));
const supported = ['2048', 'jumpjump', 'minesweeper', 'snake', 'tetris', 'whackmole', 'brickbreaker', 'guessnumber'];
const id = process.argv[2];
if (id === '--help' || id === '--list') {
  console.log(id === '--list' ? supported.join('\n') :
    'node scripts/device-final-classic.cjs <game-id>\n' + supported.join(', ') + '\n' +
    'LITTLEGAMES_ART_TARGET / LITTLEGAMES_ART_OUTPUT select device and evidence.\n' +
    'One-game checkpoints in classics.json. Selected lifecycle and rendering checks, not all goals.');
  process.exit(0);
}
c.assert.equal(process.argv.length, 3, 'Supply exactly one game ID');
c.assert(supported.includes(id), 'Unsupported game ID: ' + id);
const reportFile = c.path.join(c.dir, 'classics.json');
const report = c.fs.existsSync(reportFile) ? JSON.parse(c.fs.readFileSync(reportFile, 'utf8')) : {
  schemaVersion: 1, packageSha256: c.packageHash, target: c.target,
  scope: 'Selected real UI lifecycle/rendering checks. No claim of full game completion, random win rates or frame rate.', games: []
};
c.assert.equal(report.packageSha256, c.packageHash, 'Choose a new evidence directory for another HAP');
c.assert.equal(report.target, c.target, 'Evidence belongs to another device');
const attemptId = new Date().toISOString().replace(/[^0-9]/g, '');
const result = { id, name: c.names[id], attemptId, status: 'running', startedAt: new Date().toISOString(), checks: [], evidence: [], observations: [] };
report.games.push(result);
const save = () => {
  report.updatedAt = new Date().toISOString();
  c.fs.writeFileSync(reportFile, JSON.stringify(report, null, 2) + '\n');
};
const verifyPackage = () => c.assert.equal(crypto.createHash('sha256')
  .update(c.fs.readFileSync('entry/build/default/outputs/default/entry-default-signed.hap')).digest('hex'),
  c.packageHash, 'HAP changed during device acceptance');
const byId = (ns, value) => ns.find(n => n.id === value);
const sheet = ns => !!byId(ns, 'game-settings-panel');
const outcome = ns => !!c.find(ns, strings.get('result_play_again'));
let originalDifficulty = null;
const tag = suffix => 'classic-' + id + '-' + attemptId + '-' + suffix;
const shot = suffix => {
  const label = tag(suffix), ns = c.capture(label);
  result.evidence.push(label + '.jpeg'); save(); return ns;
};
const check = (name, detail = {}) => {
  result.checks.push({ name, at: new Date().toISOString(), ...detail }); save();
  c.log('classic-check-passed', { id, name, ...detail }); console.log('CLASSIC ' + id + ' ' + name);
};
const observe = (name, detail) => {
  result.observations.push({ name, at: new Date().toISOString(), ...detail }); save();
};
function tap(label, ns) {
  // Alert actions follow the sheet in the native tree. Select the actual button,
  // not the same label in the sheet or a dialog title behind it.
  const buttons = ns.filter(n => n.type === 'Button' && n.enabled !== 'false' &&
    (n.text === label || n.description === label || c.descendants(n).some(child => child.type === 'Text' && child.text === label)));
  c.click(buttons.at(-1) || c.find(ns, label));
}
function active(ns) {
  c.assert(byId(ns, 'game-settings-button') && !sheet(ns), 'Expected the game page');
  c.assert(!outcome(ns), 'Natural outcome interrupted sampling; this is incomplete, not a confirmed defect');
}
function settings(ns = c.layout()) {
  active(ns); c.click(byId(ns, 'game-settings-button'));
  return c.wait(nodes => sheet(nodes) && byId(nodes, 'game-settings-return'));
}
function selectedDifficulty(ns) {
  return ns.filter(n => n.type === 'Button' && n.description === '已选择')
    .flatMap(n => c.descendants(n).filter(child => child.type === 'Text').map(child => child.text))
    .find(label => ['简单', '普通', '困难'].includes(label)) || null;
}
function rememberDifficulty() {
  if (id === 'brickbreaker') return;
  const ns = settings(); originalDifficulty = selectedDifficulty(ns);
  c.assert(originalDifficulty, 'Could not read the originally selected difficulty');
  result.originalDifficulty = originalDifficulty; save(); closeSettings(ns);
}
function restoreDifficulty() {
  if (!originalDifficulty) return;
  difficulty(originalDifficulty); result.restoredDifficulty = originalDifficulty; save();
}
function closeSettings(ns) {
  c.click(byId(ns, 'game-settings-return'));
  return c.wait(nodes => !sheet(nodes) && byId(nodes, 'game-settings-button'));
}
function confirmedAction(label, messageKey, ns) {
  tap(label, ns);
  ns = c.wait(nodes => !sheet(nodes) || c.text(nodes).includes(strings.get(messageKey)));
  if (c.text(ns).includes(strings.get(messageKey))) {
    tap(messageKey === 'game_settings_difficulty_confirm' ? strings.get('game_settings_change_action') : label, ns);
    ns = c.wait(nodes => !sheet(nodes) && !c.text(nodes).includes(strings.get(messageKey)));
  }
  return ns;
}
function difficulty(label) {
  let ns = settings();
  const selected = ns.filter(n => n.type === 'Button' && n.description === '已选择')
    .flatMap(n => c.descendants(n).filter(child => child.type === 'Text').map(child => child.text));
  if (selected.includes(label)) { closeSettings(ns); return; }
  confirmedAction(label, 'game_settings_difficulty_confirm', ns);
  ns = settings();
  c.assert(ns.filter(n => n.type === 'Button' && n.description === '已选择')
    .some(n => c.descendants(n).some(child => child.text === label)), 'Difficulty was not selected: ' + label);
  closeSettings(ns);
}
function restart() {
  let ns = c.layout();
  if (outcome(ns)) {
    observe('natural-outcome-before-restart', { text: c.text(ns) });
    tap(strings.get('result_play_again'), ns);
    ns = c.wait(nodes => !outcome(nodes) && byId(nodes, 'game-settings-button'));
  } else ns = confirmedAction(strings.get('header_restart'), 'game_settings_restart_confirm', settings(ns));
  active(ns); return ns;
}
function seconds(ns) {
  const node = ns.find(n => n.type === 'Text' && /^\d+s$/.test(n.text));
  c.assert(node, 'Visible game timer absent'); return Number(node.text.slice(0, -1));
}
function metric(ns, label) {
  const node = ns.find(n => n.type === 'Text' && n.text === label); c.assert(node, 'Metric label absent: ' + label);
  const values = (node.parent.children || []).map(child => child.attributes).filter(n => n.type === 'Text' && /^\d+$/.test(n.text));
  c.assert.equal(values.length, 1, 'Metric value not uniquely visible: ' + label); return Number(values[0].text);
}
function frame(suffix, ns = c.layout()) {
  const file = tag(suffix) + '.json';
  c.fs.copyFileSync(c.path.join(c.dir, 'current.json'), c.path.join(c.dir, file));
  const header = byId(ns, 'game-settings-button'); c.assert(header);
  const bottom = c.bounds(header)[3];
  return { file, at: new Date().toISOString(),
    images: ns.filter(n => n.type === 'Image' && c.bounds(n)[1] > bottom)
      .map(n => ({ bounds: n.origBounds || n.bounds, opacity: n.opacity, backgroundImage: n.backgroundImage }))
      .sort((a, b) => JSON.stringify(a).localeCompare(JSON.stringify(b))),
    text: c.text(ns).filter(value => /^(\d+s|\d+|\d+\/\d+)$/.test(value)),
    holes: ns.filter(n => n.type === 'Stack' && /^第\d+个地鼠洞/.test(n.description || ''))
      .map(n => ({ description: n.description, bounds: n.bounds })) };
}
const signature = f => ({ images: f.images, text: f.text, holes: f.holes });
const motionSignature = f => id === 'whackmole' ?
  { images: f.images, timer: f.text.filter(value => /^\d+s$/.test(value)) } : { images: f.images };
function background(waitMs = 3000) {
  c.shell('uitest', 'uiInput', 'keyEvent', 'Home');
  c.sleep(waitMs / 2); c.sleep(waitMs / 2);
  const output = c.shell('aa', 'start', '-b', 'com.littlegames.collection', '-a', 'EntryAbility');
  c.assert(!/error|fail/i.test(output), output);
  return c.wait(nodes => byId(nodes, 'game-settings-button'));
}
function headerBack(ns) {
  const gear = byId(ns, 'game-settings-button'); c.assert(gear);
  const gb = c.bounds(gear);
  const button = ns.find(n => n.type === 'Button' && n.clickable === 'true' &&
    c.bounds(n)[0] < gb[0] && Math.abs(c.bounds(n)[1] - gb[1]) < 15);
  c.assert(button, 'Observed header back button absent'); c.click(button);
}
function pauseFromReady(ready) {
  // Use the observed header immediately after starting, before a slow dump can
  // let Snake hit a wall or a real-time game reach its natural result.
  c.click(byId(ready, 'game-settings-button'));
  let ns = c.wait(nodes => sheet(nodes) || outcome(nodes));
  if (outcome(ns)) return null;
  c.assert(c.find(ns, strings.get('a11y_header_pause')), 'Playing game did not offer pause');
  tap(strings.get('a11y_header_pause'), ns);
  return c.wait(nodes => !sheet(nodes) && byId(nodes, 'game-settings-button'));
}
function pausedSheetCheck() {
  const ns = settings();
  c.assert(c.find(ns, strings.get('a11y_header_resume')), 'Manual pause was lost'); closeSettings(ns);
}
function startRealTime(ns) {
  const gb = c.bounds(byId(ns, 'game-settings-button'));
  const controls = ns.filter(n => n.type === 'Button' && n.clickable === 'true' && c.bounds(n)[1] > gb[3]);
  if (id === 'snake') {
    c.assert.equal(controls.length, 5, 'Five native direction-pad buttons absent');
    c.click(controls.sort((a, b) => c.bounds(b)[1] - c.bounds(a)[1])[0]);
  } else if (id === 'brickbreaker') {
    c.assert.equal(controls.length, 2, 'Two native paddle-control buttons absent');
    c.click(controls.sort((a, b) => c.bounds(a)[0] - c.bounds(b)[0])[0]);
  }
  // Tetris and WhackMole start their actual timers when their page starts.
}
function classicLifecycle() {
  if (id !== 'brickbreaker') difficulty('简单');
  let ns, paused;
  for (let attempt = 0; attempt < 3 && !paused; attempt++) {
    ns = restart(); startRealTime(ns); paused = pauseFromReady(ns);
    if (!paused) observe('natural-outcome-before-pause', { attempt, text: c.text(c.layout()) });
  }
  c.assert(paused, 'Could not sample a live game before natural results; acceptance incomplete');
  pausedSheetCheck();
  const before = frame('paused-before'); shot('paused');
  c.sleep(1200); const after = frame('paused-after');
  c.assert.deepEqual(signature(after), signature(before), 'Game changed during manual pause');
  check('manual-pause-freezes', { frames: [before, after], waitMs: 1200 });
  ns = c.layout(); headerBack(ns);
  ns = c.wait(nodes => c.find(nodes, strings.get('exit_confirm_title')));
  shot('paused-exit-confirm'); tap(strings.get('exit_confirm_stay'), ns);
  c.wait(nodes => !c.find(nodes, strings.get('exit_confirm_title'))); pausedSheetCheck();
  const cancelled = frame('paused-exit-cancel');
  c.assert.deepEqual(signature(cancelled), signature(before), 'Exit cancellation changed a manually paused game');
  check('paused-exit-confirm-cancel-keeps-pause', { before, after: cancelled });
  background(); pausedSheetCheck(); const restored = frame('paused-background-return');
  c.assert.deepEqual(signature(restored), signature(before), 'Manually paused game changed across background');
  shot('paused-background-return'); check('manual-pause-background-3s', { before, after: restored, waitMs: 3000 });
  let resumed, changed = false, motionBefore = before;
  for (let attempt = 0; attempt < 3 && !changed; attempt++) {
    if (attempt > 0) {
      ns = restart(); startRealTime(ns); const newPause = pauseFromReady(ns);
      if (!newPause) { observe('natural-outcome-before-resume-retry', { attempt }); continue; }
      motionBefore = frame('resume-retry-paused-' + attempt);
    }
    ns = settings(); tap(strings.get('a11y_header_resume'), ns);
    ns = c.wait(nodes => !sheet(nodes));
    for (let sample = 0; sample < 4 && !changed; sample++) {
      if (outcome(ns)) { observe('natural-outcome-during-resume-sampling', { attempt, sample, text: c.text(ns) }); break; }
      resumed = frame('resumed-' + attempt + '-' + sample, ns);
      changed = JSON.stringify(motionSignature(resumed)) !== JSON.stringify(motionSignature(motionBefore));
      if (!changed) { c.sleep(450); ns = c.layout(); }
    }
  }
  c.assert(changed, 'Could not observe post-resume movement/countdown before a result; acceptance incomplete');
  shot('resumed'); check('manual-resume-visible-updates', { before: motionBefore, after: resumed,
    observed: id === 'whackmole' ? 'hole occupancy or countdown changed' : 'rendered game image position/occupancy changed' });
  const reset = restart(); shot('restart');
  c.assert.equal(metric(reset, strings.get('score_label')), 0);
  if (id === 'snake') c.assert(c.text(reset).includes('按方向键开始'));
  if (id === 'brickbreaker') c.assert(c.text(reset).includes(strings.get('game_brickbreaker_hint')));
  check('restart-score-zero', { text: c.text(reset) });
  if (id === 'whackmole') whackHit();
  if (id === 'brickbreaker') brickRestore();
}
function limitation(name, detail) {
  result.limitations ||= []; result.limitations.push({ name, ...detail }); save();
  c.log('classic-check-not-established', { id, name, ...detail });
}
function whackHit() {
  let ns = c.layout(), hit = false;
  for (let attempt = 0; attempt < 8 && !hit; attempt++) {
    if (outcome(ns)) { observe('natural-outcome-during-whack-probe', { attempt }); ns = restart(); }
    const score = metric(ns, strings.get('score_label'));
    const occupied = ns.find(n => n.type === 'Stack' && n.clickable === 'true' &&
      (n.raw.children || []).filter(child => child.attributes.type === 'Image').length === 2);
    if (occupied) {
      const observedBounds = occupied.bounds; c.click(occupied); ns = c.layout();
      if (!outcome(ns)) {
        const after = metric(ns, strings.get('score_label'));
        if (after > score) {
          hit = true; shot('actual-whack-score'); check('actual-visible-mole-hit-score', { before: score, after, observedHole: observedBounds });
        } else observe('mole-expired-before-real-touch', { attempt, observedHole: observedBounds });
      }
    } else { c.sleep(180); ns = c.layout(); }
  }
  if (!hit) limitation('actual-mole-hit-not-established', {
    reason: 'No score increase established from eight real UI observations/touches; sampled moles may expire before HDC delivers touch.' });
  restart();
}
function brickBoard(ns) {
  const gb = c.bounds(byId(ns, 'game-settings-button'));
  const board = ns.find(n => n.type === 'Stack' && n.clickable === 'true' && c.bounds(n)[1] > gb[3] &&
    (n.raw.children || []).filter(child => child.attributes.type === 'Stack' &&
      (child.children || []).some(grandchild => grandchild.attributes.type === 'Image')).length >= 8);
  c.assert(board, 'Observed native brick arena absent'); return board;
}
function liveBricks(ns) {
  return (brickBoard(ns).raw.children || []).filter(child => child.attributes.type === 'Stack' &&
    (child.children || []).some(grandchild => grandchild.attributes.type === 'Image') && Number(child.attributes.opacity) > 0.99)
    .map(child => ({ bounds: child.attributes.origBounds || child.attributes.bounds, hashcode: child.attributes.hashcode }));
}
function brickRestore() {
  let ns = restart(); const full = liveBricks(ns); c.assert(full.length >= 8);
  shot('brick-wall-full'); startRealTime(ns);
  let removed = null;
  for (let sample = 0; sample < 8 && !removed; sample++) {
    c.sleep(180); ns = c.layout();
    if (outcome(ns)) { observe('natural-outcome-during-brick-probe', { sample, text: c.text(ns) }); break; }
    const current = liveBricks(ns), score = metric(ns, strings.get('score_label'));
    if (current.length < full.length && score > 0) removed = { before: full.length, after: current.length, score, bricks: current };
    else {
      // Move the native paddle under the observed ball using a real horizontal
      // gesture. Its path is derived only from direct arena image geometry.
      const arena = brickBoard(ns), directImages = (arena.raw.children || []).filter(child => child.attributes.type === 'Image')
        .map(child => child.attributes);
      const ball = directImages.find(n => { const b = c.bounds(n); return Math.abs(b[2] - b[0] - b[3] + b[1]) < 8; });
      const paddle = directImages.find(n => { const b = c.bounds(n); return b[2] - b[0] > (b[3] - b[1]) * 4; });
      if (ball && paddle) {
        const b = c.bounds(ball), p = c.bounds(paddle), y = Math.round((p[1] + p[3]) / 2);
        c.shell('uitest', 'uiInput', 'swipe', String(Math.round((p[0] + p[2]) / 2)), String(y),
          String(Math.round((b[0] + b[2]) / 2)), String(y), '700');
      }
    }
  }
  if (removed) {
    shot('actual-brick-removed'); check('actual-ball-breaks-brick-and-scores', removed);
    ns = restart(); c.assert.equal(liveBricks(ns).length, full.length);
    c.assert.deepEqual(liveBricks(ns).map(brick => brick.bounds), full.map(brick => brick.bounds));
    shot('brick-wall-restored'); check('restart-restores-actual-brick-wall-after-hit', { brickCount: full.length, score: metric(ns, strings.get('score_label')) });
  } else {
    limitation('brick-hit-and-restoration-not-established', { initialBrickCount: full.length,
      reason: 'Eight real input/sampling attempts did not establish both a missing brick and a positive score. Lifecycle checks do not prove this reset regression.' });
    restart();
  }
}
function tiles(ns) {
  return ns.filter(n => n.type === 'Stack' && (n.raw.children || []).some(child => child.attributes.type === 'Image') &&
    (n.raw.children || []).some(child => child.attributes.type === 'Text' && /^\d+$/.test(child.attributes.text)))
    .map(n => ({ value: Number(n.raw.children.find(child => child.attributes.type === 'Text').attributes.text),
      bounds: n.origBounds || n.bounds, hashcode: n.hashcode }));
}
function swipe2048(ns, direction) {
  const tileNodes = ns.filter(n => n.type === 'Stack' && (n.raw.children || []).some(child => child.attributes.type === 'Image') &&
    (n.raw.children || []).some(child => child.attributes.type === 'Text' && /^\d+$/.test(child.attributes.text)));
  const first = c.bounds(tileNodes[0]);
  const candidates = ns.filter(n => n.type === 'Column' && Math.abs(c.bounds(n)[2] - c.bounds(n)[0] - c.bounds(n)[3] + c.bounds(n)[1]) < 30 &&
    c.bounds(n)[2] - c.bounds(n)[0] > (first[2] - first[0]) * 3.5 &&
    tileNodes.every(tile => tile.hierarchy.startsWith(n.hierarchy + ',')));
  const board = candidates.sort((a, b) => { const x = c.bounds(a), y = c.bounds(b); return (x[2] - x[0]) * (x[3] - x[1]) - (y[2] - y[0]) * (y[3] - y[1]); })[0];
  c.assert(board, 'Observed 2048 board with gesture absent');
  const b = c.bounds(board), x = Math.round((b[0] + b[2]) / 2), y = Math.round((b[1] + b[3]) / 2);
  const points = { left: [b[2] - 60, y, b[0] + 60, y], right: [b[0] + 60, y, b[2] - 60, y],
    up: [x, b[3] - 60, x, b[1] + 60], down: [x, b[1] + 60, x, b[3] - 60] };
  c.shell('uitest', 'uiInput', 'swipe', ...points[direction].map(String), '700'); c.sleep(250);
}
function game2048() {
  difficulty('简单'); let ns = restart();
  c.assert.equal(tiles(ns).length, 2, 'New 2048 board did not render exactly two tiles'); shot('two-tiles');
  let score = metric(ns, strings.get('score_label'));
  for (let i = 0; i < 16 && score === 0; i++) {
    const before = tiles(ns); swipe2048(ns, ['left', 'down', 'right', 'up'][i % 4]); ns = c.layout(); active(ns);
    const after = tiles(ns); score = metric(ns, strings.get('score_label'));
    observe('real-swipe', { direction: ['left', 'down', 'right', 'up'][i % 4], before, after, score });
  }
  c.assert(score > 0 && tiles(ns).some(tile => tile.value >= 4), 'No actual merge and visible score reached');
  shot('merged'); check('real-swipes-merge-and-score', { score, tiles: tiles(ns) });
  for (const mode of ['困难', '普通', '简单']) {
    difficulty(mode); ns = c.layout(); c.assert.equal(tiles(ns).length, 2); c.assert.equal(metric(ns, strings.get('score_label')), 0);
    shot('difficulty-' + (mode === '困难' ? 'hard' : mode === '普通' ? 'normal' : 'easy'));
    check('difficulty-resets-two-tiles-' + mode, { tiles: tiles(ns) });
  }
  for (let attempt = 0; attempt < 3; attempt++) {
    ns = restart(); c.assert.equal(tiles(ns).length, 2); c.assert.equal(metric(ns, strings.get('score_label')), 0);
    shot('restart-' + attempt); check('repeat-restart-two-tiles-' + attempt, { tiles: tiles(ns) });
  }
}
function jumpjump() {
  difficulty('简单'); let ns = restart();
  const initial = ns.filter(n => /^jumpjump_platform_\d+$/.test(n.id || '') || n.id === 'jumpjump_next_platform')
    .map(n => ({ id: n.id, bounds: n.origBounds || n.bounds }));
  c.assert(initial.length >= 2); c.assert.equal(Number(byId(ns, 'jumpjump_score').text), 0); shot('ready-platforms');
  for (let jump = 1; jump <= 3; jump++) {
    const area = byId(ns, 'jumpjump_area'); c.assert(area); const b = c.bounds(area);
    const point = [Math.round((b[0] + b[2]) / 2), Math.round((b[1] + b[3]) / 2)].map(String);
    const output = c.shell('uinput', '-T', '-d', ...point, '-i', '1300', '-u', ...point);
    c.assert(!/parameter error|unable to run/i.test(output), output);
    ns = c.wait(nodes => Number(byId(nodes, 'jumpjump_score')?.text) === jump || outcome(nodes));
    c.assert(!outcome(ns), 'Real jump missed; record incomplete, not an inferred model defect');
    c.assert(byId(ns, 'jumpjump_player') && byId(ns, 'jumpjump_next_platform'));
    shot('landed-' + jump); check('actual-landing-' + jump, { score: jump, player: byId(ns, 'jumpjump_player').bounds,
      nextPlatform: byId(ns, 'jumpjump_next_platform').bounds });
  }
  for (let attempt = 0; attempt < 2; attempt++) {
    ns = restart(); c.assert.equal(Number(byId(ns, 'jumpjump_score').text), 0);
    const reset = ns.filter(n => /^jumpjump_platform_\d+$/.test(n.id || '') || n.id === 'jumpjump_next_platform')
      .map(n => ({ id: n.id, bounds: n.origBounds || n.bounds }));
    c.assert.deepEqual(reset, initial, 'Restart did not restore the actual platform geometry');
    shot('restart-platforms-' + attempt); check('restart-platforms-' + attempt, { platforms: reset });
  }
}
function minesCells(ns) {
  const gb = c.bounds(byId(ns, 'game-settings-button'));
  const cells = ns.filter(n => n.type === 'Stack' && n.clickable === 'true' && c.bounds(n)[1] > gb[3] &&
    Math.abs(c.bounds(n)[2] - c.bounds(n)[0] - c.bounds(n)[3] + c.bounds(n)[1]) < 5);
  c.assert.equal(cells.length, 81, 'Native Minesweeper grid is not 81 observable cells');
  return cells.sort((a, b) => Math.abs(c.bounds(a)[1] - c.bounds(b)[1]) < 10 ?
    c.bounds(a)[0] - c.bounds(b)[0] : c.bounds(a)[1] - c.bounds(b)[1]);
}
const cellImages = n => (n.raw.children || []).filter(child => child.attributes.type === 'Image').length;
function longClick(n) {
  const b = c.bounds(n); c.shell('uitest', 'uiInput', 'longClick',
    String(Math.round((b[0] + b[2]) / 2)), String(Math.round((b[1] + b[3]) / 2)));
}
function minesweeper() {
  difficulty('简单'); let ns = restart(), cells = minesCells(ns);
  c.assert.equal(seconds(ns), 0); c.click(cells[40]);
  ns = c.wait(nodes => outcome(nodes) || cellImages(minesCells(nodes)[40]) === 0);
  c.assert(!outcome(ns), 'First actual reveal unexpectedly reached an outcome; capture for review');
  c.assert.equal(cellImages(minesCells(ns)[40]), 0);
  shot('first-safe-reveal'); check('first-real-reveal-safe', { cellIndex: 40, bounds: minesCells(ns)[40].bounds });
  const cellIndex = minesCells(ns).findIndex(n => cellImages(n) === 1); c.assert(cellIndex >= 0);
  let hidden = minesCells(ns)[cellIndex]; const position = hidden.bounds; longClick(hidden);
  ns = c.wait(nodes => c.text(nodes).includes('1/10') && cellImages(minesCells(nodes)[cellIndex]) === 2);
  c.assert(c.text(ns).includes('1/10')); shot('flagged');
  hidden = minesCells(ns)[cellIndex]; longClick(hidden);
  ns = c.wait(nodes => c.text(nodes).includes('0/10') && cellImages(minesCells(nodes)[cellIndex]) === 1);
  c.assert(c.text(ns).includes('0/10')); check('long-press-flag-toggle', { position });
  ns = settings(); const a = seconds(ns); c.sleep(1500); c.sleep(1500); const b = seconds(c.layout());
  c.assert.equal(b, a); shot('settings-frozen'); check('settings-freezes-timer-3s', { before: a, after: b });
  ns = closeSettings(c.layout()); const activeSeconds = seconds(ns);
  ns = c.wait(nodes => seconds(nodes) > activeSeconds, 5000); check('settings-close-resumes-timer', { before: activeSeconds, after: seconds(ns) });
  headerBack(ns);
  ns = c.wait(nodes => c.find(nodes, strings.get('exit_confirm_title')));
  const exitSeconds = seconds(ns); c.sleep(1500); c.sleep(1500); const exitAfter = seconds(c.layout());
  c.assert.equal(exitAfter, exitSeconds); shot('exit-confirm-frozen'); check('exit-confirm-freezes-timer-3s', { before: exitSeconds, after: exitAfter });
  // Keeping the exit dialog visible isolates background suspension without HDC
  // launch latency adding active foreground time to the observation.
  ns = background(); c.assert(c.find(ns, strings.get('exit_confirm_title'))); c.assert.equal(seconds(ns), exitSeconds);
  shot('background-dialog-frozen'); check('exit-dialog-background-3s', { before: exitSeconds, after: seconds(ns), waitMs: 3000 });
  tap(strings.get('exit_confirm_stay'), ns); ns = c.wait(nodes => !c.find(nodes, strings.get('exit_confirm_title')));
  const resumedSeconds = seconds(ns); ns = c.wait(nodes => seconds(nodes) > resumedSeconds, 5000);
  check('exit-cancel-restores-timer', { before: resumedSeconds, after: seconds(ns) });
  ns = restart(); c.assert.equal(seconds(ns), 0); c.assert(c.text(ns).includes('0/10'));
  c.assert(minesCells(ns).every(n => cellImages(n) === 1));
  shot('restart-zero'); check('restart-zero-timer-flags-hidden-grid', { text: c.text(ns) });
}
function guessnumber() {
  difficulty('普通'); let ns = restart();
  const hint = c.text(ns).find(value => /^猜一个由\d+个不重复数字组成的密码$/.test(value)); c.assert(hint);
  const length = Number(hint.match(/\d+/)[0]); c.assert(length >= 3 && length <= 5);
  const guesses = Array.from({ length: 7 }, (_, i) => Array.from({ length }, (_, j) => String((i + j) % 10)).join(''));
  for (let i = 0; i < guesses.length; i++) {
    for (const digit of guesses[i]) { tap(digit, ns); }
    tap(strings.get('guess_confirm'), c.layout());
    ns = c.wait(nodes => c.text(nodes).includes('#' + (i + 1)) || outcome(nodes));
    if (outcome(ns)) {
      observe('natural-guess-win', { guess: guesses[i], text: c.text(ns) }); shot('early-win');
      throw Error('Random password matched before seven records; scroll acceptance incomplete, not a defect');
    }
    c.assert(c.text(ns).includes(guesses[i])); check('submitted-legal-guess-' + (i + 1), { guess: guesses[i], length });
  }
  shot('seven-records-before-scroll');
  const list = ns.find(n => n.type === 'List'); c.assert(list, 'Observed guess record List absent');
  const bounds = c.bounds(list), x = Math.round((bounds[0] + bounds[2]) / 2);
  c.shell('uitest', 'uiInput', 'swipe', String(x), String(bounds[3] - 25), String(x), String(bounds[1] + 25), '500');
  ns = c.wait(nodes => c.text(nodes).includes('#1'));
  c.assert(c.text(ns).includes(guesses[0]), 'Oldest clue was not visible after scrolling');
  const oldest = ns.find(n => n.type === 'Text' && n.text === '#1');
  c.assert((oldest.parent.children || []).some(child => /^\d+A\d+B$/.test(child.attributes.text || '')),
    'Oldest guess lost its A/B clue');
  shot('oldest-record-visible'); check('seven-records-scroll-retains-first-clue', { guesses, oldestGuess: guesses[0], text: c.text(ns) });
}
function run() {
  save(); verifyPackage(); let ns = c.layout();
  c.assert(byId(ns, 'home_category_search'), 'Start on 分类');
  const all = byId(ns, 'category_filter_all'); c.assert(all, '全部 filter absent');
  if (all.description !== '已选择') { c.click(all); c.wait(nodes => byId(nodes, 'category_filter_all')?.description === '已选择'); }
  c.open(id); shot('opened'); check('real-page-opened', { title: c.names[id] }); rememberDifficulty();
  if (id === '2048') game2048();
  else if (id === 'jumpjump') jumpjump();
  else if (id === 'minesweeper') minesweeper();
  else if (id === 'guessnumber') guessnumber();
  else classicLifecycle();
  restoreDifficulty(); c.back(); c.assert(byId(c.layout(), 'home_category_search'));
  verifyPackage(); result.status = 'passed-selected-checks'; result.finishedAt = new Date().toISOString(); save();
  console.log('CLASSIC COMPLETE ' + id + ' (selected checks only)');
}
try { run(); }
catch (error) {
  result.status = 'incomplete'; result.finishedAt = new Date().toISOString(); result.error = error.message;
  try { result.observedText = c.text(shot('incomplete')); }
  catch (captureError) { result.captureError = captureError.message; }
  try {
    let ns = c.layout();
    if (c.find(ns, strings.get('exit_confirm_title'))) {
      tap(strings.get('exit_confirm_stay'), ns); ns = c.wait(nodes => !c.find(nodes, strings.get('exit_confirm_title')));
    }
    if (sheet(ns)) ns = closeSettings(ns);
    if (byId(ns, 'game-settings-button')) {
      if (outcome(ns)) restart();
      restoreDifficulty(); c.back();
    }
  } catch (restoreError) { result.restoreError = restoreError.message; }
  save(); c.log('classic-check-incomplete', { id, message: error.stack }); console.error(error.stack); process.exitCode = 1;
}
