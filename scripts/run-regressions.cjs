/* One entry point for the current single-player suites. Native build and device checks are separate. */
const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');
const root = path.resolve(__dirname, '..');
const suites = JSON.parse(fs.readFileSync(path.join(root, 'docs/single-player-validation-2026-10-12.json'), 'utf8'))
  .results.map(result => result.script).concat('test-local-game-saves', 'test-daily-featured', 'test-line-rescue', 'test-game-sounds');
const directory = process.env.LITTLEGAMES_REGRESSION_OUTPUT || path.join(root, 'entry/build/iteration-20261013/regressions');
fs.mkdirSync(directory, { recursive: true });
const report = { startedAt: new Date().toISOString(), scope: '79-game single-player desktop regression; no native/device claims', results: [] };
for (const script of suites) {
  const result = cp.spawnSync(process.execPath, [path.join(__dirname, script + '.cjs')], {
    cwd: root, encoding: 'utf8', timeout: 120000
  });
  const output = (result.stdout || '') + (result.stderr || '');
  fs.writeFileSync(path.join(directory, script + '.log'), output);
  const counts = output.match(/(\d+)\/(\d+)[^\n]*(?:passed|通过)/i) || output.match(/(?:Passed\s+)?(\d+)[^\n]*checks(?:\s+passed)?/i);
  const passed = counts ? Number(counts[1]) : null;
  const total = counts ? Number(counts[2] || counts[1]) : null;
  report.results.push({ script, exitCode: result.status, passed, total, error: result.error?.message || null });
  console.log(`${result.status === 0 ? 'PASS' : 'FAIL'} ${script}: ${passed ?? '?'}/${total ?? '?'}`);
  if (result.status !== 0) console.error(output.slice(-3000));
}
report.completedAt = new Date().toISOString();
report.complete = report.results.every(result => result.exitCode === 0);
report.passed = report.results.reduce((sum, result) => sum + (result.passed || 0), 0);
report.total = report.results.reduce((sum, result) => sum + (result.total || 0), 0);
fs.writeFileSync(path.join(directory, 'verification.json'), JSON.stringify(report, null, 2) + '\n');
console.log(`${report.passed}/${report.total} checks; ${report.results.length} suites; ${report.complete ? 'all passed' : 'failures remain'}.`);
if (!report.complete) process.exitCode = 1;
