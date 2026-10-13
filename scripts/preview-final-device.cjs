// Contact sheets from captured phone pixels and observed icon bounds.
// This script does not operate the phone or synthesize game screens.
const fs = require('node:fs');
const path = require('node:path');
const sharp = require('C:/Users/29186/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const dir = path.resolve(process.argv[2] || 'docs/device-acceptance/final-2026-10-08');
const report = JSON.parse(fs.readFileSync(path.join(dir, 'catalog.json')));
const entries = report.passed;
const escape = value => value.replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&apos;' })[c]);
function iconBounds(id) {
  const root = JSON.parse(fs.readFileSync(path.join(dir, 'catalog-' + id + '-icon.json')));
  const images = [];
  const visit = node => {
    if (node.attributes?.type === 'Image' && node.attributes.visible !== 'false') images.push(node.attributes);
    (node.children || []).forEach(visit);
  };
  visit(root);
  const image = images.find(n => {
    const b = n.bounds.match(/-?\d+/g).map(Number);
    return b[1] > 600 && b[3] < 1600 && b[2] - b[0] >= 90;
  });
  if (!image) throw Error('No captured catalog icon for ' + id);
  const b = image.bounds.match(/-?\d+/g).map(Number);
  return { left: b[0], top: b[1], width: b[2] - b[0], height: b[3] - b[1] };
}
async function main() {
  const files = [];
  for (let start = 0; start < entries.length; start += 8) {
    const batch = entries.slice(start, start + 8), layers = [];
    for (let index = 0; index < batch.length; index++) {
      const item = batch[index], left = index % 4 * 420, top = Math.floor(index / 4) * 540;
      const heading = Buffer.from('<svg width="420" height="540" xmlns="http://www.w3.org/2000/svg"><rect width="420" height="540" fill="#f1f3f5"/><rect x="5" y="5" width="410" height="530" rx="16" fill="white"/><text x="18" y="37" font-family="Microsoft YaHei, sans-serif" font-size="23" fill="#17212b">' + escape(item.name) + '</text><text x="18" y="67" font-family="sans-serif" font-size="16" fill="#607080">' + escape(item.id) + '</text><text x="18" y="264" font-family="Microsoft YaHei, sans-serif" font-size="17" fill="#607080">真机图标</text></svg>');
      layers.push({ input: heading, left, top });
      const icon = await sharp(path.join(dir, 'catalog-' + item.id + '-icon.jpeg')).extract(iconBounds(item.id)).resize(140, 140).png().toBuffer();
      const page = await sharp(path.join(dir, 'catalog-' + item.id + '-page.jpeg')).extract({ left: 0, top: 123, width: 1260, height: 2500 }).resize(226, 448).png().toBuffer();
      layers.push({ input: icon, left: left + 18, top: top + 100 });
      layers.push({ input: page, left: left + 174, top: top + 80 });
    }
    const file = 'visual-' + String(Math.floor(start / 8) + 1).padStart(2, '0') + '.png';
    await sharp({ create: { width: 1680, height: Math.ceil(batch.length / 4) * 540, channels: 3, background: '#f1f3f5' } }).composite(layers).png().toFile(path.join(dir, file));
    files.push({ file, games: batch.map(item => item.id) });
  }
  fs.writeFileSync(path.join(dir, 'visual-sheets.json'), JSON.stringify({ source: 'Captured native UI screenshots; only cropped/resized for comparison', packageSha256: report.packageSha256, files }, null, 2) + '\n');
  console.log(JSON.stringify({ sheets: files.length, games: entries.length }));
}
main().catch(error => { console.error(error.stack); process.exitCode = 1; });
