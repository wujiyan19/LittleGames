/* Original, deterministic synthesis. No downloaded audio or runtime dependencies. */
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { fixture } = require('./test-performance.cjs');
const root = path.resolve(__dirname, '..');
const output = path.join(root, 'entry/src/main/resources/rawfile/sounds');
const sampleRate = 44100;
const families = {
  wood: 'tictactoe gomoku reversi fourline nim hanoi peg xiangqi chess ludo dots klotski',
  tile: '2048 tetris minesweeper slidepuzzle blockfit tilestack screwout parkingjam sokoban pipes picturepuzzle',
  pop: 'snake match3 bubbleshooter fruitmerge linktiles mahjongsolitaire groupclear slotpair buscolor yarn arrowclear blackhole fisheat',
  paper: 'memorycard solitaire spider freecell doudizhu guandan mahjong',
  water: 'watersort fishing sand',
  jump: 'jumpjump runner platformer grapple flappy rollingball hillclimb drift',
  hit: 'whackmole brickbreaker fruitslice basketball billiards penalty pingpong bowling golf airhockey tug',
  laser: 'shooter tanks fortress survival roomdefense backpack',
  bell: 'sudoku guessnumber lights flood maze nonogram arithmetic compare sequence binary targetsum schulte memorysequence missing reaction differences characters rhythm restaurant untangle onestroke hiddenobjects linerescue idiom wordtower beatjump melody farm decorate'
};
const labels = { wood: '木质落子', tile: '方块滑动', pop: '轻快弹消', paper: '纸牌翻动', water: '流水气泡', jump: '起跳滑行', hit: '柔和击打', laser: '街机射击', bell: '清脆提示' };
const hash = text => {
  let value = 2166136261;
  for (const c of text) { value = Math.imul(value ^ c.charCodeAt(0), 16777619); }
  return value >>> 0;
};
const rng = seed => () => {
  seed ^= seed << 13; seed ^= seed >>> 17; seed ^= seed << 5;
  return (seed >>> 0) / 4294967296 * 2 - 1;
};
const envelope = (t, duration, decay = 5) => t < 0 || t >= duration ? 0 :
  Math.min(1, t / 0.006) * Math.exp(-decay * t / duration) * Math.min(1, (duration - t) / 0.015);
const sine = (frequency, t) => Math.sin(2 * Math.PI * frequency * t);
const bell = (frequency, t) => sine(frequency, t) + 0.25 * sine(frequency * 2, t) + 0.12 * sine(frequency * 3, t);
function synth(family, event, seed) {
  const reward = event === 'reward';
  const duration = reward ? 0.30 : family === 'water' ? 0.20 : family === 'paper' ? 0.13 : 0.15;
  const samples = new Float64Array(Math.round(sampleRate * duration));
  const random = rng(seed || 1);
  const pitch = 0.9 + (seed >>> 0) / 4294967296 * 0.2;
  let lowNoise = 0;
  for (let i = 0; i < samples.length; i++) {
    const t = i / sampleRate, n = random(); lowNoise += 0.12 * (n - lowNoise);
    let sound = 0;
    if (reward) {
      const start = Math.floor(t / 0.075) * 0.075, local = t - start;
      const frequency = [523.25, 659.25, 783.99, 1046.5][Math.min(3, Math.floor(t / 0.075))] * pitch;
      sound = 0.35 * bell(frequency, local) * envelope(local, 0.09, 2.2);
      if (family === 'pop' || family === 'water') { sound += 0.18 * sine((500 + t * 1500) * pitch, t) * envelope(t, duration); }
    } else if (family === 'wood') {
      sound = (0.52 * sine(330 * pitch, t) + 0.26 * sine(920 * pitch, t) + 0.18 * lowNoise) * envelope(t, duration, 9);
    } else if (family === 'tile') {
      sound = (0.45 * sine(245 * pitch, t) + 0.2 * sine(610 * pitch, t) + 0.16 * lowNoise) * envelope(t, duration, 6);
    } else if (family === 'pop') {
      sound = (0.54 * sine((950 * t - 2350 * t * t) * pitch, 1) + 0.1 * lowNoise) * envelope(t, duration, 6);
    } else if (family === 'paper') {
      sound = (0.66 * lowNoise + 0.12 * sine(540 * pitch, t)) * envelope(t, duration, 4);
    } else if (family === 'water') {
      sound = (0.34 * sine((420 * t + 1700 * t * t) * pitch, 1) + 0.4 * lowNoise) * envelope(t, duration, 3.5);
    } else if (family === 'jump') {
      sound = (0.45 * sine((280 * t + 1200 * t * t) * pitch, 1) + 0.09 * lowNoise) * envelope(t, duration, 2.7);
    } else if (family === 'hit') {
      sound = (0.52 * sine(175 * pitch, t) + 0.27 * lowNoise + 0.13 * sine(740 * pitch, t)) * envelope(t, duration, 8);
    } else if (family === 'laser') {
      sound = (0.38 * sine((1100 * t - 3000 * t * t) * pitch, 1) + 0.15 * lowNoise) * envelope(t, duration, 4.5);
    } else { sound = 0.37 * bell(660 * pitch, t) * envelope(t, duration, 4.5); }
    samples[i] = sound * Math.min(1, (duration - t) / 0.015);
  }
  return samples;
}
function cue(event) {
  const notes = event === 'win' ? [523.25, 659.25, 783.99, 1046.5] : event === 'lose' ? [392, 329.63, 261.63] : event === 'draw' ? [440, 523.25] : [220, 207.65];
  const step = event === 'error' ? 0.065 : 0.12;
  const duration = notes.length * step + 0.12;
  return Float64Array.from({ length: Math.round(sampleRate * duration) }, (_, i) => {
    const t = i / sampleRate;
    return notes.reduce((sum, note, j) => sum + 0.34 * bell(note, t - j * step) * envelope(t - j * step, step + 0.12, 3.5), 0);
  });
}
function writeWav(file, samples) {
  const data = Buffer.alloc(44 + samples.length * 2);
  data.write('RIFF'); data.writeUInt32LE(data.length - 8, 4); data.write('WAVEfmt ', 8);
  data.writeUInt32LE(16, 16); data.writeUInt16LE(1, 20); data.writeUInt16LE(1, 22);
  data.writeUInt32LE(sampleRate, 24); data.writeUInt32LE(sampleRate * 2, 28);
  data.writeUInt16LE(2, 32); data.writeUInt16LE(16, 34); data.write('data', 36); data.writeUInt32LE(samples.length * 2, 40);
  let peak = 0;
  for (const sample of samples) { peak = Math.max(peak, Math.abs(sample)); }
  const gain = peak > 0.65 ? 0.65 / peak : 1;
  for (let i = 0; i < samples.length; i++) { data.writeInt16LE(Math.round(samples[i] * gain * 32767), 44 + i * 2); }
  fs.writeFileSync(file, data);
  return { path: 'sounds/' + path.basename(file), durationMs: Math.round(samples.length / sampleRate * 1000), bytes: data.length, sha256: crypto.createHash('sha256').update(data).digest('hex') };
}
function generate() {
  const sources = ['model/GameData.ets', 'model/CollectionCatalog.ets', 'model/ExpansionCatalog.ets'];
  const registeredIds = sources.flatMap(file => [...fs.readFileSync(path.join(root, 'entry/src/main/ets', file), 'utf8').matchAll(/\bid:\s*'([^']+)'/g)].map(match => match[1]));
  // Generate current games and preserve existing resources for withdrawn implementations.
  const ids = fixture().data().getAllGames().map(game => game.id);
  const retainedIds = registeredIds.filter(id => !ids.includes(id) && ['action', 'reward'].every(event =>
    fs.existsSync(path.join(output, id + '_' + event + '.wav'))));
  const soundIds = registeredIds.filter(id => ids.includes(id) || retainedIds.includes(id));
  const profiles = new Map(Object.entries(families).flatMap(([family, games]) => games.split(' ').map(id => [id, family])));
  if (registeredIds.length !== new Set(registeredIds).size || registeredIds.some(id => !profiles.has(id)) ||
    [...profiles.keys()].some(id => !registeredIds.includes(id)) || ids.some(id => !registeredIds.includes(id))) {
    throw new Error('Every catalog entry must have exactly one sound profile.');
  }
  fs.mkdirSync(output, { recursive: true });
  const games = soundIds.map(id => {
    const family = profiles.get(id);
    return { id, family, action: writeWav(path.join(output, id + '_action.wav'), synth(family, 'action', hash(id))),
      reward: writeWav(path.join(output, id + '_reward.wav'), synth(family, 'reward', hash(id + ':reward'))) };
  });
  const shared = ['error', 'win', 'lose', 'draw'].map(event => ({ event, ...writeWav(path.join(output, 'common_' + event + '.wav'), cue(event)) }));
  fs.mkdirSync(path.join(root, 'docs/audio'), { recursive: true });
  const manifest = { format: 'PCM WAV', sampleRate, channels: 1, bitsPerSample: 16, source: 'Original deterministic synthesis in scripts/generate-game-sounds.cjs', games, shared };
  fs.writeFileSync(path.join(root, 'docs/audio/manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
  const text = `# 游戏音效\n\n当前上架的 ${ids.length} 款单人游戏均有独立的操作、得分音效，另有错误、胜利、结束、平局四个公共提示。保留旋律记忆原有四个音符。资源目录同时保留 ${retainedIds.length} 款已撤下玩法的原有音效，共 ${games.length * 2 + shared.length} 个 WAV；资源存在不代表游戏仍然上架。生成器读取 GameDataManager 的上架策略，为开放游戏生成音效并保留撤下游戏已有的资源，不为没有资源的撤下玩法新增音效。\n\n资源由本项目脚本原创合成，无外部音频下载和第三方素材许可要求。WAV 为 44.1 kHz / 16 bit / 单声道，带短淡入淡出并限制峰值；随 HAP 打包，离线可用。\n\n生成：\n\n\`\`\`powershell\n& 'C:/Program Files/Huawei/DevEco Studio/tools/node/node.exe' scripts/generate-game-sounds.cjs\n\`\`\`\n\n播放器使用 Media Kit SoundPool（四路并发），进入页面只加载该款游戏的两个文件和四个公共提示。普通反馈间隔至少 60 ms，结算提示优先。静音、暂停、设置遮挡、切后台与离开页面停止声音，异步返回的旧播放请求会被取消。撤销和恢复存档不会重复播放结算声音；旋律示范期间保留原音符，普通操作声避免遮盖示范。\n\n音效开关继续由 GameDataManager 持久化，无新增依赖或权限。资源对应关系、长度、大小和 SHA-256 见 [manifest.json](audio/manifest.json)。\n\n官方接口依据：[SoundPool](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-inner-multimedia-soundpool) 和 [短音播放说明](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/using-soundpool-for-playback)，并核对 DevEco API 24 的 multimedia/soundPool.d.ts。\n\n| 游戏 ID | 操作音色 | 资源前缀 |\n| --- | --- | --- |\n`;
  fs.writeFileSync(path.join(root, 'docs/game-sounds.md'), text + games.map(game => `| ${game.id} | ${labels[game.family]} | sounds/${game.id}_ |`).join('\n') + '\n');
  console.log(`Generated ${games.length * 2 + shared.length} WAV resources for ${games.length} games (${games.reduce((sum, game) => sum + game.action.bytes + game.reward.bytes, shared.reduce((sum, item) => sum + item.bytes, 0))} bytes).`);
  return manifest;
}
module.exports = { generate, synth, cue };
if (require.main === module) { generate(); }
