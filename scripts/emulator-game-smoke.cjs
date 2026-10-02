// Verify actual pages with device UI input and layout observations, without test hooks in the app.
const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const target = process.argv[2];
const label = process.argv[3];
assert(target, 'Specify a connected device');
assert.match(label, /^[a-z0-9-]+$/);
const options = process.argv.slice(4);
const limitAt = options.indexOf('--limit');
const limit = limitAt < 0 ? 4 : Number(options[limitAt + 1]);
assert(Number.isInteger(limit) && limit >= 1 && limit <= 33, '--limit must be an integer from 1 to 33');
for (let index = 0; index < options.length; index++) {
  if (options[index] === '--plan') { continue; }
  assert(options[index] === '--limit' && index === limitAt && index + 1 < options.length, 'Supported options: --plan, --limit N');
  index++;
}
const packageFile = path.resolve('entry/build/default/outputs/default/entry-default-signed.hap');
assert(fs.existsSync(packageFile), 'Build the signed candidate before testing');
const packageHash = crypto.createHash('sha256').update(fs.readFileSync(packageFile)).digest('hex').toUpperCase();
const progressFile = path.resolve('docs/device-acceptance', label + '-progress.json');
const progress = fs.existsSync(progressFile) ? JSON.parse(fs.readFileSync(progressFile, 'utf8')) :
  { version: 1, target, label, packageHash, scope: 'entry-return', results: [] };
assert(progress.version === 1 && progress.target === target && progress.label === label && progress.scope === 'entry-return', 'Progress belongs to a different device or scope; use a new label');
assert(progress.packageHash === packageHash, 'Candidate package changed; use a new label to keep earlier evidence');
assert(Array.isArray(progress.results), 'Invalid saved progress');
const saveProgress = () => {
  fs.mkdirSync(path.dirname(progressFile), { recursive: true });
  progress.at = new Date().toISOString();
  // Write a complete temporary record before atomically replacing the checkpoint.
  fs.writeFileSync(progressFile + '.tmp', JSON.stringify(progress, null, 2));
  fs.renameSync(progressFile + '.tmp', progressFile);
};
const hdc = 'C:/Program Files/Huawei/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe';
const run = (...args) => cp.execFileSync(hdc, ['-t', target, ...args], { encoding: 'utf8', timeout: 20000 });
const shell = (...args) => run('shell', ...args);
const sleep = () => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 600);
const scratch = path.resolve('entry/build/emulator-acceptance');
fs.mkdirSync(scratch, { recursive: true });
const layout = () => {
  shell('uitest', 'dumpLayout', '-p', '/data/local/tmp/lg-smoke.json');
  const file = path.join(scratch, label + '-layout.json');
  run('file', 'recv', '/data/local/tmp/lg-smoke.json', file);
  const nodes = [];
  const visit = (n, parent) => {
    if (n.attributes?.visible !== 'false') nodes.push({ ...n.attributes, parent, node: n });
    for (const child of n.children || []) visit(child, n);
  };
  visit(JSON.parse(fs.readFileSync(file, 'utf8')), null);
  return nodes;
};
const waitFor = predicate => {
  for (let attempt = 0; attempt < 10; attempt++) {
    sleep();
    const nodes = layout();
    if (predicate(nodes)) return nodes;
  }
  throw new Error('Timed out waiting for expected page');
};
const coords = a => a.bounds.match(/\d+/g).map(Number);
const click = node => {
  assert(node, 'Required observed UI element is absent');
  const b = coords(node);
  shell('uitest', 'uiInput', 'click', String(Math.round((b[0] + b[2]) / 2)), String(Math.round((b[1] + b[3]) / 2)));
};
const capture = name => {
  shell('snapshot_display', '-f', '/data/local/tmp/lg-smoke.jpeg');
  run('file', 'recv', '/data/local/tmp/lg-smoke.jpeg', path.resolve('docs/screenshots', name + '.jpeg'));
};
const games = [['2048','2048'], ['猜数字','guess'], ['打地鼠','whack'], ['打砖块','brick'],
  ['俄罗斯方块','tetris'], ['华容道','klotski'], ['滑动拼图','slide'], ['记忆翻牌','memory'],
  ['扫雷','mines'], ['数独','sudoku'], ['贪吃蛇','snake'], ['跳一跳','jump'], ['消消乐','match3'],
  ['井字棋','tictactoe'], ['五子棋','gomoku'], ['翻转棋','reversi'], ['落子四连','fourline'],
  ['取石子','nim'], ['十字熄灯','lights'], ['色块归一','flood'], ['迷宫寻路','maze'],
  ['汉诺塔','hanoi'], ['跳子独留','peg'], ['数字绘格','nonogram'], ['心算十题','arithmetic'],
  ['算式比大小','compare'], ['数列推演','sequence'], ['二进制解码','binary'], ['补数求和','targetsum'],
  ['数字寻序','schulte'], ['顺序记忆','memorysequence'], ['记忆缺项','missing'], ['信号反应','reaction']];
const isGameCard = (node, name) => node.type === 'Column' && node.clickable === 'true' &&
  [node.text, node.description].some(text => typeof text === 'string' &&
    (text.startsWith(name + ',') || text.startsWith(name + '，')));
const results = progress.results;
const pending = games.filter(([name]) => !results.some(result => result.name === name && result.entered === true && result.returned === true &&
  typeof result.screenshot === 'string' && fs.existsSync(path.resolve('docs', result.screenshot))));
const batch = pending.slice(0, limit);
console.log('Recorded: ' + (games.length - pending.length) + '/' + games.length + '; next batch: ' + batch.map(([name]) => name).join('、'));
if (options.includes('--plan') || batch.length === 0) { process.exit(0); }
for (const [name, slug] of batch) {
  let nodes = waitFor(ns => ns.some(n => n.type === 'TextInput'));
  let input = nodes.find(n => n.type === 'TextInput');
  if (input.text) {
    const button = input.parent.children.find(n => n.attributes.type === 'Button');
    click(button?.attributes);
    nodes = waitFor(ns => ns.some(n => n.type === 'TextInput' && n.text === ''));
    input = nodes.find(n => n.type === 'TextInput');
  }
  const b = coords(input);
  shell('uitest', 'uiInput', 'inputText', String(Math.round((b[0]+b[2])/2)), String(Math.round((b[1]+b[3])/2)), name);
  nodes = waitFor(ns => ns.some(n => isGameCard(n, name)));
  click(nodes.find(n => isGameCard(n, name)));
  nodes = waitFor(ns => !ns.some(n => n.type === 'TextInput') && ns.some(n => n.type === 'Text' && n.text === name && coords(n)[1] < 400));
  assert(!nodes.some(n => n.type === 'TabBar'), 'Home tab bar should not overlay game');
  capture('accept-' + label + '-' + slug);
  shell('uitest', 'uiInput', 'keyEvent', 'Back');
  nodes = waitFor(ns => ns.some(n => n.type === 'TextInput' || n.text === '确认退出？'));
  if (nodes.some(n => n.text === '确认退出？')) {
    click(nodes.find(n => n.text === '退出' && n.type === 'Text'));
    nodes = waitFor(ns => ns.some(n => n.type === 'TextInput'));
  }
  const result = { name, slug, scope: 'entry-return', screenshot: 'screenshots/accept-' + label + '-' + slug + '.jpeg', entered: true, returned: true, checkedAt: new Date().toISOString() };
  const existing = results.findIndex(saved => saved.name === name);
  if (existing >= 0) { results[existing] = result; } else { results.push(result); }
  saveProgress();
  fs.writeFileSync(path.join(scratch, label + '-smoke-results.json'), JSON.stringify({ target, label, at: new Date().toISOString(), results }, null, 2));
  console.log('PASS ' + label + ' ' + name + ': entered, title present, no home tabs, returned');
}
console.log('PASS ' + label + ' batch ' + batch.length + '/' + batch.length + '; recorded ' + (games.length - pending.length + batch.length) + '/' + games.length + ' game entry and return flows');
