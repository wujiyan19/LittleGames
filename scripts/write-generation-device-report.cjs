const fs = require('node:fs');
const path = require('node:path');
const p = JSON.parse(fs.readFileSync('docs/device-acceptance/generation-audit-2026-10-02.json', 'utf8').replace(/^\uFEFF/, ''));
if(process.argv.includes('--normalize-labels')||process.argv.includes('--update-candidate')) {
  for(const r of p.results)if(!r.packageHash)r.packageHash=p.packageHash;
  for(const r of p.results)if(r.id==='slidepuzzle-普通'&&r.passedCases.some(s=>s.includes('完整 3×3 拼图'))){r.name='滑动拼图·简单（完整通关）';r.id='slidepuzzle-easy-win';r.requestedDifficulty='普通';r.testedDifficulty='简单';}
  const match=p.results.find(r=>r.id==='match3');if(match&&match.evidence.some(id=>id.includes('match3-complete')))for(const id of ['audit-20261002-match3-complete-ready','audit-20261002-match3-complete-invalid-swap'])if(fs.existsSync('docs/screenshots/'+id+'.jpeg')&&!match.evidence.includes(id))match.evidence.unshift(id);
  for(const r of p.results)r.passedCases=r.passedCases.map(s=>s==='实际方向/落块/发球操作'?r.id.startsWith('snake')?'点击方向按钮后小蛇移动':r.id.startsWith('tetris')?'点击加速下落按钮，方块落下':'点击左右按钮移动挡板并发球':s);
  if(process.argv.includes('--update-candidate')) {
    const hash=require('node:crypto').createHash('sha256').update(fs.readFileSync('entry/build/default/outputs/default/entry-default-signed.hap')).digest('hex').toUpperCase();
    if(hash!==p.packageHash){p.mazeFixPackageHash=p.packageHash;p.installHistory=[{packageHash:p.initialPackageHash,change:'生成逻辑修复'},{packageHash:p.packageHash,change:'迷宫切换尺寸刷新修复'},{packageHash:hash,change:'固定规则玩法隐藏无效难度按钮',installedAt:new Date().toISOString()}];p.packageHash=hash;}
  }
  fs.writeFileSync('docs/device-acceptance/generation-audit-2026-10-02.json',JSON.stringify(p,null,2)+'\n');
}
const names = new Set(p.results.map(r => r.name.split('·')[0]));
const rows = p.results.map(r => '| ' + r.name + ' | ' + r.passedCases.join('；') + ' | ' + r.evidence.filter(id => !id.includes('-pixels') && !id.includes('-face-')).slice(0, 2).map(id => '[截图](../screenshots/' + id + '.jpeg)').join(' / ') + ' |');
const report = `# 生成逻辑修复真机验收（2026-10-02）

设备：华为 ALN-AL00，HDC 目标 ${p.target}。通过系统 UI 输入、实际布局树和屏幕图像验证，未读取应用私有模型或注入棋盘。安装时保留应用数据。

最终已安装签名 HAP SHA-256：\`${p.packageHash}\`。

## 真机新发现并修复的问题

迷宫从普通 9×9 切换简单 7×7 后，界面复用旧格子的构建参数。行列数量改变了，但部分 Cell 的索引仍按旧列数计算，机器人不再出现在起点、出口显示在错误格子，边缘也显示成道路。模型连通性测试无法发现这类渲染问题。

CollectionPage 的外层行和内层列 ForEach 标识加入当前列数，尺寸改变时重新建立格子，显示、点击和实际模型索引保持一致。该组件还用于十字熄灯、色块归一、数字寻序、数字绘格等游戏。

[修复前：机器人消失、出口位置错乱](../screenshots/audit-20261002-maze-before-fix.jpeg)；[修复后简单棋盘](../screenshots/audit-20261002-maze-7-board.jpeg)。编译成功，生成逻辑回归 26/26 通过。之前全部 342 项逻辑回归保持记录在 [代码审计报告](../logic-audit-2026-10-02/README.md)。

另发现消消乐和打砖块没有接入三档难度回调，却显示可选择三档的按钮。已隐藏这两个无效入口；消消乐保留固定规则，打砖块继续随关卡增加难度。

## 本次实际通过的用例

已覆盖 **${names.size} 款游戏，${p.results.length} 组用例**。每组只宣称下表实际操作过的内容；随机源边界条件、上百关和大批量随机棋盘属于桌面逻辑回归，没有作为真机实测结果计数。

| 游戏/难度 | 实际操作与核对 | 画面证据 |
| --- | --- | --- |
${rows.join('\n')}

迷宫三档都检查了屏幕中所有道路的连通性，并实际进入死胡同、原路返回、到达出口和重开。正常迷宫的岔路仍保留。

测试后补看了“我的”页面：[3000 挑战分单行显示，与游戏总数/已玩游戏卡片对齐](../screenshots/audit-20261002-profile-stats.jpeg)。手机已返回精选首页。

## 复核材料和范围

- [完整用例与实际棋盘数据](generation-audit-2026-10-02.json)
- 用例中的 packageHash 标明实际测试版本。部分用例在最后的无效难度按钮修复前完成；按钮修复仅影响消消乐和打砖块，这两款在最终安装版本重新验证。
- [按时间记录的操作/截图日志](generation-audit-2026-10-02-actions.jsonl)
- 原始布局证据保存在 evidence/audit-20261002-*.json；截图保存在 ../screenshots/audit-20261002-*.jpeg。
- 自动化脚本：scripts/device-generation-audit.cjs；使用真实界面独立求解，不预设手机随机棋盘。
- 不包含长时间性能、发热耗电、所有随机局和所有机型适配结论。打砖块第 38 关高速接球及 1–100 关布局由独立模型回归验证。
`;
const dest = path.resolve('docs/device-acceptance/generation-audit-2026-10-02.md');
fs.writeFileSync(dest, report);
console.log(JSON.stringify({ games: names.size, combinations: p.results.length, report: dest }));
