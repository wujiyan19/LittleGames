// Local emulator inspection helper. Uses DevEco's device CLI, never production hooks.
const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');
const hdc = 'C:/Program Files/Huawei/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe';
const target = process.argv[2];
const action = process.argv[3] || 'observe';
const args = process.argv.slice(4);
const run = (...command) => cp.execFileSync(hdc, ['-t', target, ...command], { encoding: 'utf8', timeout: 20000 });
const shell = (...command) => run('shell', ...command);
const scratch = path.resolve('entry/build/emulator-acceptance');
fs.mkdirSync(scratch, { recursive: true });
if (action === 'click') shell('uitest', 'uiInput', 'click', ...args);
if (action === 'swipe') shell('uitest', 'uiInput', 'swipe', ...args);
if (action === 'back' || action === 'home') shell('uitest', 'uiInput', 'keyEvent', action === 'back' ? 'Back' : 'Home');
if (action === 'start') shell('aa', 'start', '-b', 'com.littlegames.collection', '-a', 'EntryAbility');
if (action === 'text') shell('uitest', 'uiInput', 'inputText', ...args);
if (action !== 'observe' && action !== 'capture') Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 700);
if (action === 'capture') {
  if (!/^[a-z0-9-]+$/.test(args[0])) throw new Error('Invalid evidence name');
  shell('snapshot_display', '-f', '/data/local/tmp/lg-acceptance.jpeg');
  console.log(run('file', 'recv', '/data/local/tmp/lg-acceptance.jpeg', path.resolve('docs/screenshots', args[0] + '.jpeg')).trim());
}
shell('uitest', 'dumpLayout', '-p', '/data/local/tmp/lg-acceptance.json');
const local = path.join(scratch, target.replace(/[^a-z0-9]/gi, '-') + '.json');
run('file', 'recv', '/data/local/tmp/lg-acceptance.json', local);
const visit = node => {
  const a = node.attributes;
  if (a && a.visible !== 'false' && (a.text || a.description || a.type === 'TabBar' || a.type === 'TextInput')) {
    console.log(JSON.stringify({ text: a.text, description: a.description, type: a.type, bounds: a.bounds, selected: a.selected, clickable: a.clickable }));
  }
  for (const child of node.children || []) visit(child);
};
visit(JSON.parse(fs.readFileSync(local, 'utf8')));
