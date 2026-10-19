const fs = require('node:fs');
const path = require('node:path');
const folder = path.resolve(__dirname, '..', process.env.LITTLEGAMES_THREE_OUTPUT || 'docs/device-acceptance/three-settlements-2026-10-14');
const report = JSON.parse(fs.readFileSync(path.join(folder, 'progress.json')));
const reviews = JSON.parse(fs.readFileSync(path.join(folder, 'visual-reviews.json')));
const findingsFile = path.join(folder, 'ui-findings.json');
const findings = fs.existsSync(findingsFile) ? JSON.parse(fs.readFileSync(findingsFile)).findings : [];
const complete = report.games.filter(g => g.rounds.length >= 3).length;
const count = report.games.reduce((sum, g) => sum + g.rounds.length, 0);
const lines = ['# 真机逐游戏结算验收记录', '', '生成时间：' + new Date().toISOString(), '',
  `当前达到三次结算的游戏：**${complete} / 89**；已记录完整结算：**${count} / 267**；已视觉复核：**${reviews.passed.length} / 89**。`, '',
  complete === 89 && reviews.passed.length === 89 ? '本次 89 款游戏均完成至少三次真实结算和截图复核。' : '**本次验收尚未全部完成。未完成的项目不计为通过。**', '',
  '设备：HUAWEI Mate 60 Pro（ALN-AL00），HDC FMR0224521016052。包名：com.littlegames.collection。',
  '当前签名包 SHA-256：`' + report.packageSha256 + '`。API 24 原生构建与覆盖安装已完成。', '',
  ...(report.packages || []).map(pkg => `${pkg.label}：\`${pkg.sha256}\`；已记录 ${report.games.reduce((sum, game) => sum + game.rounds.filter(round => round.packageSha256 === pkg.sha256).length, 0)} 次结算。`),
  ...(report.packages?.length > 1 ? ['', '本记录按安装包分阶段统计。修复前已完成的游戏保留原包标识；不能将该部分描述为当前包重新完整实测。', ''] : []),
  '计数规则：实际操作后出现自然结算，保存结果截图和界面树，并成功重开。胜利、失败和分数结算均单独保留；退出、重开、桌面模型测试不计入结算数。', '',
  '| 游戏 | 真实结算 | 胜利 / 其他自然结算 | 测试包 | 截图复核 | 当前记录 |', '| --- | ---: | ---: | --- | --- | --- |'];
for (const game of report.games) {
  const attempt = game.attempts.at(-1);
  const state = game.rounds.length >= 3 ? '完成三次结算' : attempt?.status === 'incomplete' ? '未完成，需按截图复核原因' : attempt ? '执行中或等待续跑' : '待测试';
  const wins = game.rounds.filter(round => round.result === 'win' || round.resultText.some(text => /全部找到/.test(text))).length;
  const packages = [...new Set(game.rounds.map(round => report.packages?.find(pkg => pkg.sha256 === round.packageSha256)?.label || 'P0'))].join(', ') || '—';
  lines.push(`| ${game.name} (${game.id}) | ${game.rounds.length} / 3 | ${wins} / ${game.rounds.length - wins} | ${packages} | ${reviews.passed.includes(game.id) ? '已复核' : '待复核'} | ${state} |`);
}
if (findings.length) {
  lines.push('', '## 已确认的界面与玩法问题', '');
  for (const finding of findings) {
    const fixed = Array.isArray(finding.fixedEvidence) ? finding.fixedEvidence : finding.fixedEvidence ? [finding.fixedEvidence] : [];
    lines.push(`- ${finding.id}（${finding.severity}，${finding.status}）：${finding.description} 原始证据：\`${finding.evidence}\`。${fixed.length ? ' 修复证据：' + fixed.map(file => '`' + file + '`').join('、') + '。' : ''}`);
  }
}
const controlChecks = report.games.filter(game => game.controlsCheck);
if (controlChecks.length) {
  lines.push('', '## 补充控制与修复复测', '', '以下额外局单独记录，不替代上表的三局原始证据。', '');
  for (const game of controlChecks) {
    const check = game.controlsCheck, pkg = report.packages.find(pkg => pkg.sha256 === check.packageSha256)?.label || '待标记';
    lines.push(`- ${game.name}：${pkg}；${check.resultText.filter(text => /挑战完成|本局结束|犯规/.test(text)).join('；')}；视觉复核：${check.visualReview}。结果截图：\`${check.evidence[1]}\`。`);
  }
}
lines.push('', '## 证据与执行', '',
  '- `progress.json`：逐局结果文字、策略说明、截图位置、重开验证及失败尝试。',
  '- `actions.jsonl`：手机实际触控和采样记录。',
  '- `device.json`：本次设备、安装包和 SDK 身份。',
  '- `visual-review/`、`visual-reviews.json`：截图联系表和人工视觉复核范围。',
  '- 系统通知曾遮挡一次打地鼠页头，该次未计数，随后补测。', '',
  '本轮以手机当前深色界面为主。截图和界面树证明所记录时刻的显示及交互结果；没有据此声称测得帧率、音频听感、所有机型兼容或长期稳定性。', '',
  '续跑：`node scripts/device-three-settlements.cjs run`；只读查询：`node scripts/device-three-report.cjs`。同一时间只运行一个手机控制脚本。', '');
fs.writeFileSync(path.join(folder, 'REPORT.md'), lines.join('\n'));
console.log(JSON.stringify({ completedGames: complete, settlements: count, visualReviewedGames: reviews.passed.length,
  running: report.games.filter(game => game.attempts.at(-1)?.status === 'running').map(game => game.id),
  needsRetry: report.games.filter(game => game.rounds.length < 3 && game.attempts.at(-1)?.status === 'incomplete').map(game => game.id),
  report: path.join(folder, 'REPORT.md') }));
