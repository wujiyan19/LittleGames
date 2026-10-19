// Check saved phone evidence without controlling the phone or changing progress.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const folder = path.resolve(__dirname, '..', process.env.LITTLEGAMES_THREE_OUTPUT || 'docs/device-acceptance/three-settlements-2026-10-14');
const report = JSON.parse(fs.readFileSync(path.join(folder, 'progress.json')));
const reviews = JSON.parse(fs.readFileSync(path.join(folder, 'visual-reviews.json')));
const nodes = raw => [raw.attributes, ...(raw.children || []).flatMap(nodes)];
const read = name => nodes(JSON.parse(fs.readFileSync(path.join(folder, name))));
const result = ns => ns.some(n => n.type === 'Button' && ['再来一局', '新游戏'].includes(n.text)) ||
  ns.some(n => n.type === 'Text' && ['再来一局', '新游戏'].includes(n.text));
let rounds = 0, captures = 0, supplementaryRounds = 0;
for (const game of report.games) {
  assert(game.rounds.length <= 3, game.id + ': duplicate rounds');
  let gameRound = 0;
  for (const round of game.rounds) {
    assert.equal(round.round, ++gameRound, game.id + ': round sequence');
    rounds++;
    assert.equal(round.restartVerified, true, game.id);
    assert(report.packages.some(pkg => pkg.sha256 === round.packageSha256), game.id + ': unknown package');
    assert(Date.parse(round.finishedAt) >= Date.parse(round.startedAt), game.id + ': timestamps');
    assert.equal(round.evidence.length, 3);
    const frames = round.evidence.map(name => {
      const data = fs.readFileSync(path.join(folder, name));
      assert(data.length > 10000 && data[0] === 255 && data[1] === 216, name + ': invalid JPEG');
      captures++;
      return read(name.replace(/\.jpeg$/, '.json'));
    });
    assert(!result(frames[0]), game.id + ': opening already settled');
    assert(result(frames[1]), game.id + ': result control missing');
    assert.deepEqual(frames[1].filter(n => n.type === 'Text' && n.text).map(n => n.text), round.resultText, game.id + ': recorded result differs from UI');
    assert(!result(frames[2]) && frames[2].some(n => n.id === 'game-settings-button'), game.id + ': restart evidence');
  }
  if (game.rounds.length) assert(read(game.id + '-icon.json').some(n => n.type === 'Image'), game.id + ': catalog icon');
  if (game.controlsCheck) {
    const check = game.controlsCheck;
    assert(report.packages.some(pkg => pkg.sha256 === check.packageSha256), game.id + ': supplementary package');
    assert.equal(check.restartVerified, true);
    const frames = check.evidence.map(name => {
      assert(fs.statSync(path.join(folder, name)).size > 10000, name);
      return read(name.replace(/\.jpeg$/, '.json'));
    });
    assert(!result(frames[0]) && result(frames[1]) && !result(frames[2]), game.id + ': supplementary result/restart');
    assert.deepEqual(frames[1].filter(n => n.type === 'Text' && n.text).map(n => n.text), check.resultText);
    supplementaryRounds++;
  }
}
assert.equal(rounds, report.settlements);
assert.equal(report.completedGames, report.games.filter(g => g.rounds.length === 3).length);
assert.equal(new Set(reviews.passed).size, reviews.passed.length);
for (const id of reviews.passed) assert(report.games.some(g => g.id === id && g.rounds.length === 3), id + ': visual review without three results');
let verifiedWasteDraws = 0;
const wasteAfterFile = path.join(folder, 'solitaire-waste-after.json');
if (fs.existsSync(wasteAfterFile)) {
  const before = JSON.parse(fs.readFileSync(path.join(folder, 'solitaire-waste-before.json')));
  const after = JSON.parse(fs.readFileSync(wasteAfterFile));
  assert.equal(before.length, 5);
  assert.equal(new Set(before.map(draw => draw.card)).size, 1, 'Klondike pre-fix reproduction');
  assert.equal(after.length, 5);
  assert.equal(new Set(after.map(draw => draw.card)).size, 5, 'Klondike waste refresh regression');
  for (const draw of after) {
    const ns = read('solitaire-waste-after-draw-' + draw.draw + '.json');
    assert.equal(draw.stock, '牌库 ' + (24 - draw.draw));
    assert(ns.some(n => n.type === 'Button' && n.text === draw.stock));
    assert(ns.some(n => n.type === 'Text' && n.text === draw.card));
    verifiedWasteDraws++;
  }
}
console.log(JSON.stringify({ verifiedRounds: rounds, verifiedRoundCaptures: captures, supplementaryRounds, verifiedWasteDraws, completedGames: report.completedGames, visuallyReviewedGames: reviews.passed.length, totalGames: report.games.length }));
