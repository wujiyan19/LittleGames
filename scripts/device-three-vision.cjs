// Compare screenshot crops with the shipped artwork. Input is rendered pixels.
const fs = require('node:fs');
const sharp = require('sharp');
(async () => {
  const request = JSON.parse(fs.readFileSync(process.argv[2]));
  if (request.operation === 'red-text') {
    const samples = [];
    for (const box of request.boxes) {
      const width = box[2] - box[0], height = box[3] - box[1];
      const data = await sharp(request.file).extract({ left: Math.round(box[0] + width * .3), top: Math.round(box[1] + height * .3), width: Math.round(width * .4), height: Math.round(height * .4) }).resize(20, 20).removeAlpha().raw().toBuffer();
      let red = 0;
      for (let i = 0; i < data.length; i += 3) if (data[i] > 110 && data[i] > data[i + 1] * 1.5 && data[i] > data[i + 2] * 1.3) red++;
      samples.push({ redPixels: red, red: red > 5 });
    }
    process.stdout.write(JSON.stringify(samples)); return;
  }
  const frame = sharp(request.file), meta = await frame.metadata(), references = [];
  for (const ref of request.references) {
    const themedFile = ref.file.replace(/[/\\]base[/\\]media[/\\]/, '/dark/media/');
    const referenceFile = request.theme === 'light' || !fs.existsSync(themedFile) ? ref.file : themedFile;
    let renderer = sharp(referenceFile);
    if (ref.crop) renderer = sharp(await renderer.resize(120, 120).toBuffer()).extract({ left: ref.crop[0] * 40, top: ref.crop[1] * 40, width: 40, height: 40 });
    const result = await renderer.resize(40, 40, { fit: 'fill' }).ensureAlpha().raw().toBuffer();
    references.push({ name: ref.name, data: result });
  }
  const samples = [];
  for (const box of request.boxes) {
    const left = Math.round(box[0]), top = Math.round(box[1]), width = Math.round(box[2]) - left, height = Math.round(box[3]) - top;
    if (left < 0 || top < 0 || left + width > meta.width || top + height > meta.height) throw Error('Crop outside screen: ' + box);
    const data = await sharp(request.file).extract({ left, top, width, height }).resize(40, 40, { fit: 'fill' }).removeAlpha().raw().toBuffer();
    const matches = references.map(ref => {
      if (ref.name === 'exp_empty') {
        const channels = [[], [], []];
        for (let y = 12; y < 28; y++) for (let x = 12; x < 28; x++) for (let ch = 0; ch < 3; ch++) channels[ch].push(data[(y * 40 + x) * 3 + ch]);
        const means = channels.map(a => a.reduce((a, b) => a + b, 0) / a.length);
        const variance = channels.reduce((sum, a, ch) => sum + a.reduce((s, v) => s + (v - means[ch]) ** 2, 0) / a.length, 0) / 3;
        return { name: ref.name, distance: variance * 5 + (Math.max(...means) - Math.min(...means)) * 20 };
      }
      let sum = 0, count = 0;
      const compareChroma = /^(exp_(water|sand|yarn|reel|person|bus)|play_gem)_\d+$/.test(ref.name);
      for (let y = 6; y < 34; y++) for (let x = 6; x < 34; x++) {
        const i = y * 40 + x, alpha = ref.data[i * 4 + 3] / 255;
        if (alpha < .8) continue;
        const a = [0, 1, 2].map(ch => data[i * 3 + ch]), b = [0, 1, 2].map(ch => ref.data[i * 4 + ch]);
        const minA = Math.min(...a), minB = Math.min(...b), rangeA = Math.max(...a) - minA, rangeB = Math.max(...b) - minB;
        if (compareChroma && (rangeA < 20 || rangeB < 20)) continue;
        for (let ch = 0; ch < 3; ch++) sum += compareChroma ?
          ((a[ch] - minA) / rangeA * 255 - (b[ch] - minB) / rangeB * 255) ** 2 : (a[ch] - b[ch]) ** 2;
        count += 3;
      }
      return { name: ref.name, distance: count ? sum / count : Infinity };
    }).sort((a, b) => a.distance - b.distance);
    samples.push({ match: matches[0].name, distance: matches[0].distance, alternatives: matches.slice(0, 3) });
  }
  process.stdout.write(JSON.stringify(samples));
})().catch(e => { console.error(e.stack); process.exitCode = 1; });
