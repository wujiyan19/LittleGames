module.exports = c => {
  const media = c.path.join(c.root, 'entry/src/main/resources/base/media');
  const scratch = c.path.join(c.output, 'vision'); c.fs.mkdirSync(scratch, { recursive: true });
  const screen = () => {
    c.shell('snapshot_display', '-f', '/data/local/tmp/lg-vision.jpeg');
    const file = c.path.join(scratch, 'current.jpeg'); c.run('file', 'recv', '/data/local/tmp/lg-vision.jpeg', file); return file;
  };
  const samples = (nodes, names, file = screen()) => {
    const input = c.path.join(scratch, 'request.json');
    c.fs.writeFileSync(input, JSON.stringify({ file, theme: process.env.LITTLEGAMES_THREE_THEME || 'dark', boxes: nodes.map(c.bounds), references: names.map(name => typeof name === 'string' ? ({ name, file: c.path.join(media, name + '.svg') }) : name) }));
    return JSON.parse(c.cp.execFileSync(process.execPath, [c.path.join(__dirname, 'device-three-vision.cjs'), input], {
      encoding: 'utf8', timeout: 30000, env: { ...process.env, NODE_PATH: 'C:/Users/29186/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules' }
    }));
  };
  const classify = (nodes, names) => samples(nodes, names).map(s => s.match);
  const redText = (nodes, file = screen()) => {
    const input = c.path.join(scratch, 'red-text-request.json');
    c.fs.writeFileSync(input, JSON.stringify({ operation: 'red-text', file, boxes: nodes.map(c.bounds) }));
    return JSON.parse(c.cp.execFileSync(process.execPath, [c.path.join(__dirname, 'device-three-vision.cjs'), input], {
      encoding: 'utf8', timeout: 30000, env: { ...process.env, NODE_PATH: 'C:/Users/29186/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules' }
    }));
  };
  const opacity = (node, ns) => ns.filter(p => p === node || node.hierarchy?.startsWith(p.hierarchy + ',')).reduce((v, p) => v * Number(p.opacity || 1), 1);
  const cells = (ns = c.layout()) => ns.filter(n => n.type === 'Button' && c.bounds(n)[1] > 350 &&
    c.bounds(n)[2] - c.bounds(n)[0] > 45 && Math.abs(c.bounds(n)[2] - c.bounds(n)[0] - c.bounds(n)[3] + c.bounds(n)[1]) < 14 &&
    c.descendants(n).some(d => d.type === 'Image')).sort((a, b) => Math.abs(c.bounds(a)[1] - c.bounds(b)[1]) < 18 ? c.bounds(a)[0] - c.bounds(b)[0] : c.bounds(a)[1] - c.bounds(b)[1]);
  const family = (name, count) => Array.from({ length: count }, (_, i) => name + i);
  return { screen, samples, classify, redText, opacity, cells, family };
};
