// Device acceptance helper: normal UI input and observable evidence only.
const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');
const assert = require('node:assert/strict');
const target = process.argv[2];
const action = process.argv[3] || 'observe';
const args = process.argv.slice(4);
assert(target, 'Specify the connected device');
const hdc = 'C:/Program Files/Huawei/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe';
const scratch = path.resolve('entry/build/emulator-acceptance');
const evidence = path.resolve('docs/device-acceptance/evidence');
fs.mkdirSync(scratch, { recursive: true });
const run = (...command) => cp.execFileSync(hdc, ['-t', target, ...command], { encoding: 'utf8', timeout: 20000 });
const shell = (...command) => run('shell', ...command);
const sleep = ms => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
let root;
const layout = () => {
  shell('uitest', 'dumpLayout', '-p', '/data/local/tmp/lg-gameplay.json');
  const local = path.join(scratch, 'gameplay-layout.json');
  run('file', 'recv', '/data/local/tmp/lg-gameplay.json', local);
  root = JSON.parse(fs.readFileSync(local, 'utf8'));
  const nodes = [];
  const visit = (node, parent) => {
    if (node.attributes?.visible !== 'false') nodes.push({ ...node.attributes, parent });
    for (const child of node.children || []) visit(child, node);
  };
  visit(root, null);
  return nodes;
};
const waitFor = (predicate, timeout = 15000) => {
  const deadline = Date.now() + timeout;
  do {
    const nodes = layout();
    if (predicate(nodes)) return nodes;
    sleep(250);
  } while (Date.now() < deadline);
  throw new Error('Expected UI state did not appear');
};
const bounds = node => node.bounds.match(/-?\d+/g).map(Number);
const tap = node => {
  assert(node, 'Observed UI element is absent');
  const b = bounds(node);
  assert(b[2] > b[0] && b[3] > b[1], 'Element has no usable touch area');
  shell('uitest', 'uiInput', 'click', '' + Math.round((b[0] + b[2]) / 2), '' + Math.round((b[1] + b[3]) / 2));
};
const find = (nodes, label) => nodes.find(n => n.clickable === 'true' && (n.text === label || n.description === label)) ||
  nodes.find(n => n.text === label || n.description === label);
const summary = nodes => nodes.filter(n => n.text || n.description || n.clickable === 'true' || n.id)
  .filter(n => { const b = bounds(n); return b[1] >= 123 && b[3] <= 2670; })
  .map(n => ({ type: n.type, text: n.text, description: n.description, bounds: n.bounds, clickable: n.clickable, id: n.id }));
let nodes;
if (action === 'open') {
  const name = args[0];
  nodes = waitFor(ns => ns.some(n => n.type === 'TextInput'));
  let input = nodes.find(n => n.type === 'TextInput');
  if (input.text) {
    tap(input.parent.children.find(n => n.attributes.type === 'Button')?.attributes);
    nodes = waitFor(ns => ns.some(n => n.type === 'TextInput' && n.text === ''));
    input = nodes.find(n => n.type === 'TextInput');
  }
  const b = bounds(input);
  shell('uitest', 'uiInput', 'inputText', '' + Math.round((b[0] + b[2]) / 2), '' + Math.round((b[1] + b[3]) / 2), name);
  const card = n => n.type === 'Column' && n.clickable === 'true' && [n.text, n.description].some(t => t?.startsWith(name + ',') || t?.startsWith(name + '，'));
  nodes = waitFor(ns => ns.some(card));
  tap(nodes.find(card));
  nodes = waitFor(ns => ns.some(n => n.type === 'Text' && n.text === name) && !ns.some(n => n.type === 'TextInput'));
} else if (action === 'tap') {
  nodes = layout();
  tap(find(nodes, args[0]));
  sleep(Number(args[1] || 250));
} else if (action === 'burst') {
  const labels = args[0].split(',');
  nodes = layout();
  const targets = labels.map(label => find(nodes, label));
  for (const node of targets) { tap(node); }
  sleep(200);
} else if (action === 'at') {
  shell('uitest', 'uiInput', 'click', args[0], args[1]);
  sleep(Number(args[2] || 250));
} else if (action === 'repeat') {
  nodes = layout();
  const node = find(nodes, args[0]);
  for (let i = 0; i < Number(args[1]); i++) { tap(node); sleep(80); }
} else if (action === 'long' || action === 'swipe') {
  shell('uitest', 'uiInput', action === 'long' ? 'longClick' : 'swipe', ...args);
  sleep(600);
} else if (action === 'back') {
  shell('uitest', 'uiInput', 'keyEvent', 'Back');
  nodes = waitFor(ns => ns.some(n => n.text === '确认退出？' || n.type === 'TextInput'));
  if (nodes.some(n => n.text === '确认退出？')) tap(find(nodes, '退出'));
  nodes = waitFor(ns => ns.some(n => n.type === 'TextInput'));
} else if (action === 'wait') {
  assert(Number(args[0]) <= 45000, 'Keep waits bounded');
  sleep(Number(args[0]));
} else if (action === 'wait-text') {
  nodes = waitFor(ns => ns.some(n => n.text === args[0]), Number(args[1] || 45000));
} else if (action === 'whack') {
  const attempts = Number(args[0] || 8);
  for (let i = 0; i < attempts; i++) {
    nodes = layout();
    const holes = nodes.filter(n => n.clickable === 'true' && n.type === 'Stack' && bounds(n)[1] > 500 &&
      nodes.filter(child => child.parent?.attributes.hashcode === n.hashcode && child.type === 'Image').length === 2);
    if (holes.length) tap(holes[0]);
    console.log('ATTEMPT ' + (i + 1) + ': ' + holes.length + ' observed occupied holes, UI ' + nodes.filter(n => n.type === 'Text' && bounds(n)[1] > 300 && bounds(n)[1] < 550).map(n => n.text).join('/'));
  }
} else {
  assert(action === 'observe' || action === 'capture', 'Unknown action');
}
nodes = layout();
let screenshot;
if (action === 'capture') {
  assert.match(args[0], /^[a-z0-9-]+$/);
  screenshot = 'screenshots/' + args[0] + '.jpeg';
  shell('snapshot_display', '-f', '/data/local/tmp/lg-gameplay.jpeg');
  run('file', 'recv', '/data/local/tmp/lg-gameplay.jpeg', path.resolve('docs', screenshot));
  fs.mkdirSync(evidence, { recursive: true });
  fs.writeFileSync(path.join(evidence, args[0] + '.json'), JSON.stringify(root));
}
const state = summary(nodes);
fs.appendFileSync(path.resolve('docs/device-acceptance/mate60-gameplay-actions.jsonl'), JSON.stringify({ at: new Date().toISOString(), target, action, args, screenshot, state }) + '\n');
console.log(JSON.stringify({ screenshot, text: state.filter(n => n.text).map(n => n.text), controls: state.filter(n => n.clickable === 'true').map(n => ({ type: n.type, text: n.text, bounds: n.bounds })), ids: state.filter(n => n.id) }));
