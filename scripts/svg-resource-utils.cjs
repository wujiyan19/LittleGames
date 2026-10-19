/* Drop unreachable gradients only. Geometry and all other XML remain untouched. */
const fs = require('node:fs');
const path = require('node:path');
function references(xml) {
  return [...xml.matchAll(/url\(\s*#([^\s)]+)\s*\)|(?:xlink:)?href=["']#([^"']+)["']/g)].map(m => m[1] || m[2]);
}
function pruneSvgDefs(svg) {
  return svg.replace(/<defs>([\s\S]*?)<\/defs>/g, (block, definitions) => {
    const gradients = [...definitions.matchAll(/<linearGradient\b[^>]*\bid=["']([^"']+)["'][^>]*>[\s\S]*?<\/linearGradient>/g)];
    const retained = new Set(references(svg.replace(block, '')));
    const other = definitions.replace(/<linearGradient\b[^>]*>[\s\S]*?<\/linearGradient>/g, '');
    for (const id of references(other)) retained.add(id);
    let changed = true;
    while (changed) {
      changed = false;
      for (const gradient of gradients) if (retained.has(gradient[1])) {
        for (const id of references(gradient[0])) if (!retained.has(id)) { retained.add(id); changed = true; }
      }
    }
    let next = definitions;
    for (const gradient of gradients) if (!retained.has(gradient[1])) next = next.replace(gradient[0], '');
    return '<defs>' + next + '</defs>';
  });
}
module.exports = { pruneSvgDefs };
if (require.main === module) {
  const root = path.resolve(__dirname, '..');
  const backup = path.join(process.env.TEMP || process.env.TMP || root, 'littlegames-ui-20261019');
  let files = 0, before = 0, after = 0;
  for (const theme of ['base', 'dark']) {
    const dir = path.join(root, 'entry/src/main/resources', theme, 'media');
    for (const name of fs.readdirSync(dir).filter(name => name.endsWith('.svg'))) {
      const file = path.join(dir, name), source = fs.readFileSync(file, 'utf8'), next = pruneSvgDefs(source);
      before += Buffer.byteLength(source); after += Buffer.byteLength(next);
      if (next !== source) {
        const snapshot = path.join(backup, path.relative(root, file));
        fs.mkdirSync(path.dirname(snapshot), { recursive: true });
        if (!fs.existsSync(snapshot)) fs.copyFileSync(file, snapshot);
        fs.writeFileSync(file, next); files++;
      }
    }
  }
  console.log(JSON.stringify({ filesChanged: files, beforeBytes: before, afterBytes: after, savedBytes: before - after }));
}
