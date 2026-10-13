// Local source previews only. These are not device captures or acceptance results.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const sharp = require('C:/Users/29186/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root = path.resolve(__dirname, '../../..');
const source = relative => path.join(root, relative);
const original = relative => path.join(__dirname, 'before', relative);
const colors = file => JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '')).color;
const getColor = (theme, name, before = false) => colors((before ? original : source)(`entry/src/main/resources/${theme}/element/color.json`)).find(entry => entry.name === name).value;
const svg = (body, width, height) => Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">${body}</svg>`);
const label = (text, width, size = 20, color = '#304A69') => svg(`<text x="0" y="${size}" font-family="Arial" font-size="${size}" fill="${color}">${text}</text>`, width, size + 8);
const hash = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');

async function renderTheme(theme) {
  const dark = theme === 'dark';
  const ink = dark ? '#DAE8FF' : '#304A69';
  const background = getColor(theme, 'board_bg');
  const layers = [];
  const addLabel = (text, x, y, size = 20) => layers.push({ input: label(text, 810, size, ink), left: x, top: y });
  const addAsset = async (relative, before, x, y, width, height) => {
    const input = await sharp((before ? original : source)(relative)).resize(width, height, { fit: 'fill' }).png().toBuffer();
    layers.push({ input, left: x, top: y });
  };
  addLabel(`${theme.toUpperCase()} | source SVG / native Line color previews`, 28, 22, 25);
  addLabel('Before', 175, 72);
  addLabel('After', 595, 72);
  addLabel('Bowling pin: enlarged + 58 px sample', 28, 116, 17);
  for (const before of [true, false]) {
    const x = before ? 125 : 545;
    await addAsset(`entry/src/main/resources/${theme}/media/exp_pin.svg`, before, x, 144, 152, 152);
    await addAsset(`entry/src/main/resources/${theme}/media/exp_pin.svg`, before, x + 177, 192, 58, 58);
  }
  addLabel('Billiards / golf cue ball: enlarged + 77 px / 58 px', 28, 326, 17);
  for (const before of [true, false]) {
    const x = before ? 102 : 522;
    await addAsset(`entry/src/main/resources/${theme}/media/exp_cueball.svg`, before, x, 358, 140, 140);
    await addAsset(`entry/src/main/resources/${theme}/media/exp_cueball.svg`, before, x + 155, 384, 77, 77);
    await addAsset(`entry/src/main/resources/${theme}/media/exp_cueball.svg`, before, x + 248, 394, 58, 58);
  }
  addLabel('Tug background stretched into a horizontal banner', 28, 538, 17);
  for (const before of [true, false]) {
    await addAsset(`entry/src/main/resources/${theme}/media/exp_board_tug.svg`, before, before ? 28 : 448, 576, 370, 120);
  }
  addLabel('Drift: same roadPoint geometry and stroke width (time = 0)', 28, 726, 17);
  for (const before of [true, false]) {
    const edge = getColor(theme, before ? 'border' : 'expansion_road_edge', before);
    let body = `<rect width="360" height="460" fill="${background}"/>`;
    for (const side of [-1, 1]) {
      const points = Array.from({ length: 11 }, (_, i) => {
        const y = i * 46;
        return `${180 + Math.sin((390 - y) / 100 * 0.65) * 90 + side * 65},${y}`;
      });
      body += `<polyline points="${points.join(' ')}" fill="none" stroke="${edge}" stroke-width="4"/>`;
    }
    const input = await sharp(svg(body, 360, 460)).resize(196, 250).png().toBuffer();
    layers.push({ input, left: before ? 116 : 536, top: 770 });
    addLabel(edge, before ? 145 : 565, 1031, 17);
  }
  addLabel('Local rasterization only. Phone verification pending.', 28, 1080, 18);
  await sharp({ create: { width: 860, height: 1130, channels: 4, background } }).composite(layers).png().toFile(path.join(__dirname, `comparison-${theme}.png`));
}

async function main() {
  await renderTheme('base');
  await renderTheme('dark');
  const baseline = JSON.parse(fs.readFileSync(path.join(__dirname, 'media-before.json'), 'utf8').replace(/^\uFEFF/, ''));
  const changed = [];
  for (const item of baseline) {
    // Snapshots of the six edited SVGs are the authoritative before contents.
    const beforePath = original(item.path);
    const beforeHash = fs.existsSync(beforePath) ? hash(beforePath) : item.sha256;
    const afterHash = hash(source(item.path));
    if (afterHash !== beforeHash) changed.push({ path: item.path, beforeSha256: beforeHash, afterSha256: afterHash });
  }
  const hapBefore = JSON.parse(fs.readFileSync(path.join(__dirname, 'hap-before.json'), 'utf8').replace(/^\uFEFF/, ''));
  const hap = hapBefore.map(item => ({ path: item.path, beforeSha256: item.Hash.toLowerCase(), afterSha256: hash(item.path), unchanged: hash(item.path) === item.Hash.toLowerCase() }));
  fs.writeFileSync(path.join(__dirname, 'scope-check.json'), JSON.stringify({ mediaChanged: changed, hap, deviceAcceptance: 'pending; local asset previews only' }, null, 2) + '\n');
  console.log(`Previewed both themes; ${changed.length} existing media files changed; HAP unchanged: ${hap.every(item => item.unchanged)}`);
}
main().catch(error => { console.error(error); process.exitCode = 1; });
