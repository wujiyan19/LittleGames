// Short, observable native UI checks. No application model imports or state injection.
process.env.LITTLEGAMES_ART_OUTPUT ||= 'docs/device-acceptance/final-2026-10-09';
const c = require('./device-art-review.cjs');
const crypto = require('node:crypto');
const strings = new Map(JSON.parse(c.fs.readFileSync('entry/src/main/resources/zh_CN/element/string.json', 'utf8')).string
  .map(s => [s.name, s.value]));
for (const [key, value] of strings) if (/^game_.+_name$/.test(key)) c.names[key.slice(5, -5)] = value;
const supported = ['runner', 'rhythm', 'restaurant', 'fisheat', 'bubbleshooter', 'fruitmerge', 'blackhole', 'fruitslice', 'hillclimb'];
const requested = process.argv.slice(2);
if (requested[0] === '--help' || requested[0] === '--list') {
  console.log(requested[0] === '--list' ? supported.join('\n') :
    'node scripts/device-final-worlds.cjs <game-id> [game-id ...]\nIDs: ' + supported.join(', ') + '\n' +
    'Start on 分类 / 全部. LITTLEGAMES_ART_TARGET and LITTLEGAMES_ART_OUTPUT select device/evidence.\n' +
    'Each attempt appends to worlds.json with unique evidence names. A failed game returns through observed UI before the next.\n' +
    'Short native rendering/lifecycle scope; screenshot motion without matching native hashcodes requires visual review.');
  process.exit(0);
}
c.assert(requested.length, 'Supply at least one supported game ID');
for (const gameId of requested) c.assert(supported.includes(gameId), 'Unsupported game ID: ' + gameId);
const reportFile = c.path.join(c.dir, 'worlds.json');
const report = c.fs.existsSync(reportFile) ? JSON.parse(c.fs.readFileSync(reportFile, 'utf8')) : {
  schemaVersion: 2, packageSha256: c.packageHash, target: c.target,
  scope: 'Short real UI rendering, pause/resume and restart; no complete-target or same-frame outcome claim.',
  games: []
};
c.assert.equal(report.packageSha256, c.packageHash, 'Choose a new evidence directory for another HAP');
c.assert.equal(report.target, c.target, 'Evidence belongs to another device');
report.schemaVersion = 2;
// Existing records and their filenames are historical evidence, including failed attempts.
const runId = Date.now().toString(36) + '-' + crypto.randomBytes(3).toString('hex');
let id, result;
const save = () => {
  report.updatedAt = new Date().toISOString();
  c.fs.writeFileSync(reportFile, JSON.stringify(report, null, 2) + '\n');
};
const verifyPackage = () => c.assert.equal(crypto.createHash('sha256')
  .update(c.fs.readFileSync('entry/build/default/outputs/default/entry-default-signed.hap')).digest('hex'),
  c.packageHash, 'HAP changed during device acceptance');
const byId = (ns, targetId) => ns.find(n => n.id === targetId);
const sheet = ns => !!byId(ns, 'game-settings-panel');
const tag = name => 'world-' + id + '-' + result.attemptId + '-' + name;
const retainLayout = name => {
  const file = tag(name) + '.json';
  c.fs.copyFileSync(c.path.join(c.dir, 'current.json'), c.path.join(c.dir, file));
  result.evidence.push(file); save(); return file;
};
const shot = name => {
  const label = tag(name), ns = c.capture(label);
  result.evidence.push(label + '.jpeg'); save(); return ns;
};
const check = (name, detail) => {
  result.checks.push({ name, status: 'passed', at: new Date().toISOString(), ...detail }); save();
  c.log('world-check-passed', { id, name, ...detail }); console.log('WORLD ' + id + ' ' + name);
};
const arena = ns => ns.find(n => n.type === 'Stack' && n.backgroundImage === 'true' && n.clip === 'true');
const geometry = n => n.origBounds || n.bounds;
const spriteNodes = ns => {
  const field = arena(ns); c.assert(field, 'Native clipped arena absent');
  c.assert(field.hierarchy, 'Native arena hierarchy absent');
  return ns.filter(n => n.type === 'Image' && n.hierarchy?.startsWith(field.hierarchy + ','));
};
const sprites = ns => spriteNodes(ns).map(n => ({ hashcode: n.hashcode, bounds: geometry(n) }));
const customers = ns => c.text(ns).filter(text => /^顾客 \d+ · 剩余 \d+ 秒$/.test(text))
  .map(text => {
    const match = text.match(/^顾客 (\d+) · 剩余 (\d+) 秒$/);
    return { id: Number(match[1]), seconds: Number(match[2]), text };
  });
const hud = ns => c.text(ns).filter(text => /^(得分 |进度 |剩余时间 |失误 |目标|剩余炮弹|顾客 \d+|现有|库存|余额)/.test(text));
const signature = frame => ({ sprites: frame.sprites, customers: frame.customers, hud: frame.hud });
const nativeDialog = ns => ns.some(node => /^(AlertDialog|Dialog|ModalDialog)$/.test(node.type));
const normalResult = ns => byId(ns, 'game-settings-button') && c.text(ns).includes(c.names[id]) &&
  [strings.get('collection_win'), strings.get('collection_fail')].some(title => c.text(ns).includes(title)) &&
  c.find(ns, '再来一局') && c.find(ns, '退出');
class NaturalOutcome extends Error {
  constructor(ns, stage) {
    super('Observed normal result during ' + stage + ': ' + c.text(ns).join(' | '));
    this.observedText = c.text(ns);
    this.evidenceFile = retainLayout('normal-result-' + (++result.outcomeSamples));
  }
}
const active = ns => {
  c.assert(byId(ns, 'game-settings-button') && !sheet(ns), 'Expected game page, not settings');
  if (normalResult(ns)) throw new NaturalOutcome(ns, 'active sample');
  c.assert(!c.find(ns, '再来一局') && !c.find(ns, '确认退出？'),
    'Unexpected result/dialog: ' + c.text(ns).join(' | '));
  c.assert(!nativeDialog(ns), 'Unexpected native dialog: ' + c.text(ns).join(' | '));
};
function frame(name) {
  const sampleStartedAt = new Date().toISOString(), ns = c.layout();
  const file = tag(name) + '.json';
  c.fs.copyFileSync(c.path.join(c.dir, 'current.json'), c.path.join(c.dir, file));
  result.evidence.push(file); save(); active(ns);
  return { sampleStartedAt, at: new Date().toISOString(), file, sprites: id === 'restaurant' ? [] : sprites(ns),
    customers: customers(ns), hud: hud(ns) };
}
function fastShots(name, count = 4) {
  // Capture on-device frames before file transfer or dumpLayout adds sampling delay.
  // Screenshots do not establish native node identity; only movingPair can do that.
  const samples = [];
  for (let i = 0; i < count; i++) {
    const label = tag(name + '-' + i), remote = '/data/local/tmp/' + label + '.jpeg';
    const startedAt = new Date().toISOString();
    c.shell('snapshot_display', '-f', remote);
    samples.push({ file: label + '.jpeg', remote, startedAt, capturedAt: new Date().toISOString() });
    if (i + 1 < count) c.sleep(80);
  }
  for (const sample of samples) {
    c.run('file', 'recv', sample.remote, c.path.join(c.dir, sample.file));
    result.evidence.push(sample.file);
  }
  save(); return samples;
}
function movingPair(frames) {
  for (let i = 1; i < frames.length; i++) for (const before of frames[i - 1].sprites) {
    if (!before.hashcode) continue;
    const after = frames[i].sprites.find(sprite => sprite.hashcode === before.hashcode);
    if (after && before.bounds !== after.bounds) return { hashcode: before.hashcode,
      before: before.bounds, after: after.bounds, beforeFrame: frames[i - 1].file, afterFrame: frames[i].file };
  }
  return null;
}
function settings(ns = c.layout()) {
  active(ns); c.click(byId(ns, 'game-settings-button'));
  const observed = c.wait(nodes => (sheet(nodes) && byId(nodes, 'game-settings-return')) || normalResult(nodes));
  if (normalResult(observed)) throw new NaturalOutcome(observed, 'opening settings');
  return observed;
}
function closeSettings(ns = c.layout()) {
  c.click(byId(ns, 'game-settings-return'));
  return c.wait(nodes => !sheet(nodes) && byId(nodes, 'game-settings-button'));
}
function tapDialogButton(label, ns) {
  // AlertDialog actions are appended after the underlying sheet in the native tree.
  // A restart title/action in that sheet must not intercept the confirmation tap.
  const buttons = ns.filter(node => node.type === 'Button' && node.enabled !== 'false' &&
    (node.text === label || node.description === label ||
      c.descendants(node).some(child => child.type === 'Text' && child.text === label)));
  c.assert(buttons.length, 'Observed dialog action button absent: ' + label);
  c.click(buttons.at(-1)); c.sleep(100);
}
function confirmIfObserved(label, message, ns) {
  if (!c.text(ns).includes(message)) return ns;
  tapDialogButton(label, ns);
  return c.wait(nodes => !sheet(nodes) && !c.text(nodes).includes(message));
}
const difficultyLabels = ['diff_easy', 'diff_normal', 'diff_hard'].map(key => strings.get(key));
function selectedDifficulty(ns) {
  const selected = ns.filter(n => n.type === 'Button' && n.description === '已选择')
    .flatMap(n => c.descendants(n).filter(child => child.type === 'Text').map(child => child.text))
    .filter(label => difficultyLabels.includes(label));
  c.assert.equal(selected.length, 1, 'Expected exactly one observed difficulty choice');
  return selected[0];
}
function easy() {
  let ns = settings();
  result.originalDifficulty = selectedDifficulty(ns);
  const originalEvidence = tag('original-difficulty') + '.json';
  c.fs.copyFileSync(c.path.join(c.dir, 'current.json'), c.path.join(c.dir, originalEvidence));
  result.evidence.push(originalEvidence); result.originalDifficultyEvidence = originalEvidence; save();
  if (result.originalDifficulty === '简单') { closeSettings(ns); return; }
  result.difficultyChangeAttempted = true; save();
  c.tap('简单', ns);
  const message = strings.get('game_settings_difficulty_confirm');
  ns = c.wait(nodes => !sheet(nodes) || c.text(nodes).includes(message));
  confirmIfObserved('切换并重开', message, ns);
  ns = settings();
  c.assert.equal(selectedDifficulty(ns), '简单', 'Easy difficulty was not selected');
  closeSettings(ns);
}
function cancelSettingsConfirmation(ns) {
  const messages = ['game_settings_restart_confirm', 'game_settings_difficulty_confirm'].map(key => strings.get(key));
  if (!messages.some(message => c.text(ns).includes(message))) return ns;
  tapDialogButton('取消', ns);
  return c.wait(nodes => !messages.some(message => c.text(nodes).includes(message)));
}
function restoreDifficulty() {
  if (!result.originalDifficulty) {
    c.assert(!result.difficultyChangeAttempted, 'Cannot restore a changed difficulty without its original choice');
    result.difficultyRestoration = { status: 'not-changed', reason: 'No difficulty change was attempted' }; save(); return;
  }
  let ns = cancelSettingsConfirmation(c.layout());
  if (byId(ns, 'home_category_search')) ns = c.open(id);
  c.assert(c.text(ns).includes(c.names[id]), 'Cannot restore difficulty from unrelated UI');
  if (c.find(ns, '确认退出？')) {
    c.tap(strings.get('exit_confirm_stay'), ns);
    ns = c.wait(nodes => !c.find(nodes, '确认退出？'));
  }
  if (!sheet(ns)) {
    if (normalResult(ns)) ns = restart();
    try { ns = settings(ns); }
    catch (error) {
      if (!(error instanceof NaturalOutcome)) throw error;
      ns = settings(restart());
    }
  }
  const current = selectedDifficulty(ns);
  if (current !== result.originalDifficulty) {
    c.tap(result.originalDifficulty, ns);
    const message = strings.get('game_settings_difficulty_confirm');
    ns = c.wait(nodes => !sheet(nodes) || c.text(nodes).includes(message));
    confirmIfObserved('切换并重开', message, ns);
    ns = settings();
    c.assert.equal(selectedDifficulty(ns), result.originalDifficulty, 'Original difficulty was not restored');
  }
  const restoredEvidence = tag('restored-difficulty') + '.json';
  c.fs.copyFileSync(c.path.join(c.dir, 'current.json'), c.path.join(c.dir, restoredEvidence));
  result.evidence.push(restoredEvidence);
  result.difficultyRestoration = { status: 'verified', original: result.originalDifficulty,
    observed: selectedDifficulty(ns), changedForRestoration: current !== result.originalDifficulty,
    evidence: restoredEvidence, at: new Date().toISOString() }; save(); closeSettings(ns);
}
function restart() {
  let ns = c.layout();
  if (!normalResult(ns) && !sheet(ns)) {
    try { ns = settings(ns); }
    catch (error) {
      if (!(error instanceof NaturalOutcome)) throw error;
      result.transitions.push({ kind: 'normal-result-before-settings', at: new Date().toISOString(),
        text: error.observedText, evidence: error.evidenceFile });
      ns = c.layout(); c.assert(normalResult(ns), 'Previously observed result disappeared before retry');
    }
  }
  if (c.find(ns, '再来一局')) {
    c.assert(normalResult(ns), 'Unexpected dialog with a play-again label');
    result.transitions.push({ kind: 'result-to-play-again', at: new Date().toISOString(), text: c.text(ns),
      evidence: retainLayout('result-to-play-again-' + result.transitions.length) }); save();
    c.tap('再来一局', ns);
    ns = c.wait(nodes => !c.find(nodes, '再来一局'));
  } else {
    c.assert(sheet(ns), 'Restart settings panel absent'); c.tap('重新开始', ns);
    const message = strings.get('game_settings_restart_confirm');
    ns = c.wait(nodes => !sheet(nodes) || c.text(nodes).includes(message));
    ns = confirmIfObserved('重新开始', message, ns);
  }
  ns = c.wait(nodes => !sheet(nodes) && !c.find(nodes, '游戏已暂停') && byId(nodes, 'game-settings-button'));
  active(ns);
  c.assert(c.text(ns).some(text => /^得分 0 · 最高 \d+$/.test(text)), 'Restart did not reset the visible score');
  if (['runner', 'rhythm', 'restaurant', 'fruitslice', 'hillclimb'].includes(id)) c.assert(c.find(ns, '点击开始'));
  if (['rhythm', 'restaurant', 'fisheat', 'blackhole', 'fruitslice'].includes(id))
    c.assert(c.text(ns).some(text => /^进度 0 \/ \d+$/.test(text)), 'Restart did not reset visible progress');
  if (id === 'hillclimb') c.assert(c.text(ns).includes('进度 35 / 1200'));
  if (id === 'fruitslice') {
    c.assert(c.text(ns).includes(strings.get('expansion_fruitslice_errors').replace('%d', '0')));
    c.assert.equal(sprites(ns).length, 0);
  }
  if (id === 'fruitmerge') c.assert.equal(sprites(ns).length, 0);
  if (id === 'bubbleshooter') c.assert(c.text(ns).includes(strings.get('expansion_shots').replace('%d', '90')));
  return ns;
}
function point(ns, x, y) {
  const field = arena(ns); c.assert(field);
  const b = c.bounds(field);
  return [Math.round(b[0] + (b[2] - b[0]) * x), Math.round(b[1] + (b[3] - b[1]) * y)];
}
function tapPoint(ns, x, y) { c.shell('uitest', 'uiInput', 'click', ...point(ns, x, y).map(String)); }
function playerSwipe(ns, x) {
  const player = spriteNodes(ns)[0]; c.assert(player, 'Observed player image absent');
  const b = c.bounds(player), start = [Math.round((b[0] + b[2]) / 2), Math.round((b[1] + b[3]) / 2)];
  const end = point(ns, x, 0.5);
  c.shell('uitest', 'uiInput', 'swipe', ...start.map(String), ...end.map(String), '1000');
}
function gas(ns) {
  const button = c.find(ns, '油门'); c.assert(button);
  const b = c.bounds(button), xy = [Math.round((b[0] + b[2]) / 2), Math.round((b[1] + b[3]) / 2)].map(String);
  const output = c.shell('uinput', '-T', '-d', ...xy, '-i', '700', '-u', ...xy);
  c.assert(!/parameter error|unable to run/i.test(output), output);
}
function begin(ns) {
  if (c.find(ns, '点击开始')) c.tap('点击开始', ns);
  if (id === 'bubbleshooter') tapPoint(ns, 0.2, 0.08);
  else if (id === 'fruitmerge') tapPoint(ns, 0.28, 0.3);
  else if (id === 'fisheat' || id === 'blackhole') playerSwipe(ns, 0.12);
  else if (id === 'hillclimb') gas(ns);
}
function motion() {
  if (id === 'restaurant') {
    const ready = restart();
    c.tap('点击开始', ready);
    const before = frame('customer-before'); c.assert(before.customers.length);
    c.sleep(1200); const after = frame('customer-after');
    const pair = before.customers.map(customer => ({ before: customer,
      after: after.customers.find(other => other.id === customer.id) }))
      .find(pair => pair.after && pair.after.seconds < pair.before.seconds);
    c.assert(pair, 'No same customer ID visibly counted down');
    shot('customer-countdown'); check('customer-countdown', { pair, frames: [before, after] }); return;
  }
  const shortEntity = ['bubbleshooter', 'fruitmerge', 'fruitslice'].includes(id);
  let movement = null, successfulFrames = [];
  const samples = [];
  for (let trial = 1; trial <= 3 && !movement; trial++) {
    const ready = restart(), prefix = 'motion-trial-' + trial;
    const trialResult = { trial, frames: [], screenshots: [], status: 'sampling' };
    samples.push(trialResult); result.motionSampling = samples; save();
    try {
      trialResult.frames.push(frame(prefix + '-before')); begin(ready);
      if (shortEntity) trialResult.screenshots = fastShots(prefix + '-fast');
      for (let i = 0; i < 3 && !movingPair(trialResult.frames); i++) {
        if (i) c.sleep(shortEntity ? 30 : 120);
        trialResult.frames.push(frame(prefix + '-' + i));
      }
      movement = movingPair(trialResult.frames);
      trialResult.status = movement ? 'native-identity-motion-observed' : 'native-motion-not-sampled';
      if (movement) successfulFrames = trialResult.frames;
    } catch (error) {
      if (!(error instanceof NaturalOutcome)) throw error;
      trialResult.status = 'normal-outcome-before-sufficient-samples'; trialResult.observedText = error.observedText;
      trialResult.outcomeEvidence = error.evidenceFile;
    }
    save();
  }
  if (movement) {
    shot('moving'); check('native-image-position', { evidenceType: 'matching-native-hashcode', movement, frames: successfulFrames });
  } else if (shortEntity && samples.some(sample => sample.screenshots.length)) {
    result.checks.push({ name: 'rendered-motion', status: 'requires-visual-review', at: new Date().toISOString(),
      evidenceType: 'screenshot-sequence', sameNativeNodeEstablished: false, trials: samples,
      limitation: 'No same native image hashcode was sampled at two positions after three real-input trials. Review the captured frames; this is not an automatic motion pass.' });
    save(); c.log('world-motion-review-required', { id, attemptId: result.attemptId });
  } else {
    c.assert.fail('No same native image hashcode moved after three real-input trials; see retained samples/outcomes');
  }
  if (id === 'fisheat') {
    const left = shot('fish-left'); active(left); const leftPlayer = spriteNodes(left)[0]; c.assert(leftPlayer);
    playerSwipe(left, 0.86); const right = shot('fish-right'), rightPlayer = spriteNodes(right)[0]; c.assert(rightPlayer);
    active(right);
    c.assert.equal(rightPlayer.hashcode, leftPlayer.hashcode, 'Left/right movement must retain the same player image');
    c.assert.notEqual(geometry(rightPlayer), geometry(leftPlayer), 'Player position did not change after the opposite gesture');
    check('fish-left-right-gesture', { playerHashcode: leftPlayer.hashcode, before: geometry(leftPlayer), after: geometry(rightPlayer),
      facing: 'Screenshots require visual review; dumpLayout does not establish image flip.',
      leftAttributes: { scale: leftPlayer.scale, scaleX: leftPlayer.scaleX, transform: leftPlayer.transform },
      rightAttributes: { scale: rightPlayer.scale, scaleX: rightPlayer.scaleX, transform: rightPlayer.transform } });
    result.checks.push({ name: 'fish-facing', status: 'requires-visual-review', at: new Date().toISOString(),
      evidenceType: 'screenshots', files: [tag('fish-left') + '.jpeg', tag('fish-right') + '.jpeg'],
      limitation: 'Gesture/position check passed; native layout does not establish the fish image flip.' }); save();
  }
}
function lifecycleTrial(trial) {
  const prefix = 'lifecycle-trial-' + trial;
  const ready = restart(), gear = byId(ready, 'game-settings-button');
  begin(ready);
  // Use the header observed at ready, immediately after real input. Opening the sheet suspends frames.
  c.click(gear);
  let ns = c.wait(nodes => sheet(nodes) || normalResult(nodes));
  if (normalResult(ns)) throw new NaturalOutcome(ns, 'opening pause settings');
  c.assert(c.find(ns, '暂停'));
  c.tap('暂停', ns);
  ns = c.wait(nodes => (!sheet(nodes) && c.find(nodes, '游戏已暂停')) || normalResult(nodes));
  if (normalResult(ns)) throw new NaturalOutcome(ns, 'manual pause transition');
  const before = frame(prefix + '-paused-before');
  if (id === 'restaurant') c.assert(before.customers.length, 'Pause must preserve a visible customer');
  else c.assert(before.sprites.length, 'Pause check has no observable arena image');
  shot(prefix + '-paused'); c.sleep(1000); const after = frame(prefix + '-paused-after');
  c.assert.deepEqual(signature(after), signature(before), 'Native image geometry or game HUD changed during manual pause');
  check('manual-pause-freezes', { trial, frames: [before, after], waitMs: 1000,
    scope: 'Manual pause UI plus unchanged observed geometry/HUD; does not measure frame rate.' });
  ns = settings(); c.assert(c.find(ns, '继续')); c.tap('继续', ns);
  c.wait(nodes => !sheet(nodes) && !c.find(nodes, '游戏已暂停'));
  c.sleep(id === 'restaurant' ? 1100 : 120);
  let resumed = frame(prefix + '-resumed'), extraInput = null;
  if (['blackhole', 'bubbleshooter', 'fruitmerge', 'hillclimb'].includes(id) &&
    JSON.stringify(signature(resumed)) === JSON.stringify(signature(before))) {
    // These worlds can finish the prior gesture/drop while sampling. Exercise a new real control.
    ns = c.layout(); active(ns);
    if (id === 'blackhole') tapPoint(ns, 0.82, 0.75);
    else if (id === 'bubbleshooter') tapPoint(ns, 0.78, 0.08);
    else if (id === 'fruitmerge') tapPoint(ns, 0.72, 0.3);
    else gas(ns);
    extraInput = 'Observed prior state remained settled; sent a new real ' + id + ' control after resume';
    result.transitions.push({ kind: 'resume-additional-real-input', at: new Date().toISOString(), detail: extraInput });
    if (id === 'bubbleshooter' || id === 'fruitmerge') fastShots(prefix + '-resume-fast');
    c.sleep(250); resumed = frame(prefix + '-resumed-input');
  }
  c.assert.notDeepEqual(signature(resumed), signature(before), 'No visible change after resume; paused entity may have already settled');
  shot(prefix + '-resumed'); check('resume-restores-visible-updates', { trial, before, after: resumed, extraInput,
    scope: extraInput ? 'Visible response to an additional real control after resume' : 'Observed state resumes changing without another control' });
  const reset = restart(); shot('restart');
  check('restart-resets-observed-state', { text: c.text(reset), sprites: id === 'restaurant' ? [] : sprites(reset), customers: customers(reset) });
}
function lifecycle() {
  for (let trial = 1; trial <= 3; trial++) {
    try { lifecycleTrial(trial); return; }
    catch (error) {
      if (!(error instanceof NaturalOutcome)) throw error;
      result.transitions.push({ kind: 'normal-result-during-lifecycle-sampling', trial,
        at: new Date().toISOString(), text: error.observedText, evidence: error.evidenceFile });
      shot('lifecycle-trial-' + trial + '-normal-result'); save();
      if (trial === 3) throw error;
    }
  }
}
function run() {
  save(); verifyPackage();
  let ns = c.layout();
  c.assert(byId(ns, 'home_category_search'), 'Start on the 分类 tab');
  const all = byId(ns, 'category_filter_all'); c.assert(all, 'Select the 全部 category before running');
  if (all.description !== '已选择') { c.click(all); c.wait(nodes => byId(nodes, 'category_filter_all')?.description === '已选择'); }
  c.open(id); ns = c.layout();
  c.assert(byId(ns, 'game-settings-button') && c.text(ns).includes(c.names[id]), 'Expected game header/title missing');
  easy(); restart(); shot('ready');
  check('easy-ready', { difficulty: '简单' });
  motion(); lifecycle(); restoreDifficulty(); returnToCategory();
  verifyPackage(); result.status = result.checks.some(item => item.status === 'requires-visual-review') ? 'requires-visual-review' : 'passed';
  result.finishedAt = new Date().toISOString(); save();
  console.log('WORLD COMPLETE ' + id + ' ' + result.status + ' (short rendering/lifecycle scope)');
}
function returnToCategory() {
  let ns = c.layout();
  if (byId(ns, 'home_category_search')) return ns;
  c.assert(c.text(ns).includes(c.names[id]), 'Cannot recover from unrelated or unexpected UI: ' + c.text(ns).join(' | '));
  ns = cancelSettingsConfirmation(ns);
  c.assert(!nativeDialog(ns) || normalResult(ns) || c.find(ns, '确认退出？'),
    'Cannot dismiss an unexpected native dialog during recovery: ' + c.text(ns).join(' | '));
  if (sheet(ns)) ns = closeSettings(ns);
  if (normalResult(ns) || c.find(ns, '确认退出？')) {
    c.assert(c.find(ns, '退出'), 'Observed game dialog has no exit control'); c.tap('退出', ns);
  } else {
    active(ns); c.shell('uitest', 'uiInput', 'keyEvent', 'Back');
    ns = c.wait(nodes => byId(nodes, 'home_category_search') || c.find(nodes, '确认退出？') || normalResult(nodes));
    if (!byId(ns, 'home_category_search')) {
      c.assert(c.find(ns, '退出'), 'Observed game exit dialog has no exit control'); c.tap('退出', ns);
    }
  }
  ns = c.wait(nodes => byId(nodes, 'home_category_search'));
  result.transitions.push({ kind: 'returned-to-category', at: new Date().toISOString(), text: c.text(ns) }); save();
  return ns;
}
for (let index = 0; index < requested.length; index++) {
  id = requested[index];
  result = { id, name: c.names[id], attemptId: runId + '-' + (index + 1), status: 'running',
    startedAt: new Date().toISOString(), checks: [], evidence: [], transitions: [], outcomeSamples: 0 };
  report.games.push(result); save();
  try { run(); }
  catch (error) {
    result.status = 'incomplete'; result.finishedAt = new Date().toISOString(); result.error = error.message;
    result.errorType = error instanceof NaturalOutcome ? 'normal-outcome-insufficient-observation' : 'assertion-or-ui-error';
    try { result.observedText = c.text(shot('incomplete')); }
    catch (captureError) { result.captureError = captureError.message; }
    save(); c.log('world-check-incomplete', { id, attemptId: result.attemptId, message: error.stack });
    console.error(error.stack); process.exitCode = 1;
    try {
      if (result.difficultyRestoration?.status !== 'verified') {
        try { restoreDifficulty(); }
        catch (restoreError) {
          result.difficultyRestoration = { status: 'failed', original: result.originalDifficulty || null, error: restoreError.message };
          save(); console.error('WORLD DIFFICULTY RESTORE FAILED ' + id + ': ' + restoreError.message);
        }
      }
      returnToCategory(); result.recovery = 'observed-category-search'; save();
      console.log('WORLD RECOVERED ' + id + ' -> 分类; proceeding to next requested game');
    } catch (recoveryError) {
      result.recovery = 'failed'; result.recoveryError = recoveryError.message;
      report.batchStopped = { at: new Date().toISOString(), id, unstarted: requested.slice(index + 1), reason: recoveryError.message };
      save(); console.error('WORLD BATCH STOPPED: ' + recoveryError.message); break;
    }
  }
  if (result.status === 'requires-visual-review') process.exitCode = 1;
}
