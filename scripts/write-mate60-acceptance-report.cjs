const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const dir=path.resolve('docs/device-acceptance');
const read=n=>JSON.parse(fs.readFileSync(path.join(dir,n),'utf8'));
const game=read('mate60-gameplay-progress.json'),light=read('mate60-light-progress.json'),pub=read('mate60-public-progress.json');
assert.equal(game.results.length,33);assert.equal(light.results.length,33);assert.equal(pub.darkGames.length,33);assert.equal(pub.packageHash,game.packageHash);
const pass=game.results.filter(r=>r.status==='passed-selected-cases'),fail=game.results.filter(r=>r.status==='failed-device-cases');
const publicFailures=pub.results.filter(r=>r.status==='failed-device-cases'),findingCount=3+publicFailures.length;
const files=[];for(const r of game.results)for(const id of r.evidence){files.push(path.resolve('docs/screenshots',id+'.jpeg'));files.push(path.join(dir,'evidence',id+'.json'));}for(const r of pub.darkGames)files.push(path.resolve('docs/screenshots',r.screenshot+'.jpeg'));for(const r of pub.results)for(const id of r.evidence)files.push(path.resolve('docs/screenshots',id+'.jpeg'));
assert(files.every(f=>fs.existsSync(f)),'Referenced evidence missing');
const esc=s=>s.replace(/\|/g,'／').replace(/\n/g,' ');
const link=id=>`[截图](../screenshots/${id}.jpeg)`;
const rows=light.results.map(g=>{const r=game.results.find(r=>r.name===g.name);assert(r);return `| ${r.name} | ${r.status==='failed-device-cases'?'未通过':'选定用例通过'} | ${esc(r.passedCases.join('；'))}${r.failedCases?.length?'；**失败：'+esc(r.failedCases.join('；'))+'**':''} | ${link(r.evidence[r.evidence.length-1])} |`;}).join('\n');
const publicRows=pub.results.map(r=>`| ${r.name} | ${r.status==='failed-device-cases'?'未通过':'通过'} | ${esc(r.details)} | ${r.evidence.length?link(r.evidence[r.evidence.length-1]):'见检查点'} |`).join('\n');
const pending=game.results.filter(r=>r.pendingCases.some(s=>s!=='长局性能及人手触感未量化'&&s!=='修复后复测')).map(r=>`- ${r.name}：${r.pendingCases.join('；')}。`).join('\n');
const result=`# Mate 60 Pro 本轮设备验收报告

日期：2026-09-30。本轮连续检查全部 33 款游戏，**${pass.length} 款选定玩法用例通过，${fail.length} 款未通过，发现 ${findingCount} 类问题**。浅色和深色的入口及返回均为 33/33。**当前候选不满足主要玩法无阻断的放行条件**，需先修复问题并复测。

## 设备与候选版本

- 设备：Mate 60 Pro，调试目标 ${game.target}；系统版本 7.0.0.709 SP6 由用户提供，设备工具报告 API 26。
- 应用：玩趣盒 1.0.0，包名 com.littlegames.collection，API 24 Debug 签名包；设置和关于页面核对版本号。
- 包路径：entry/build/default/outputs/default/entry-default-signed.hap。
- SHA-256：\`${game.packageHash}\`。本轮没有修改应用代码、重新构建或替换候选包。
- 执行环境：中文、竖屏。通过真机触控输入操作，读取实际渲染画面和界面布局；没有直接改写游戏模型或注入通关状态。

## 已确认的问题与开发建议

| 优先级 | 游戏 | 问题 | 建议 |
| --- | --- | --- | --- |
| P1 | 记忆缺项、顺序记忆 | 画面显示的数字与实际作答判定不一致，重开可保留旧序列 | 优先修复卡片数据更新，复验新题、重复数字、删除中间数字和两种重开 |
| P1 | 华容道 | 初始合法移动后棋块仍停在原位置 | 修复棋块位置更新及触控绑定，复验连续移动和通关 |
| P2 | 扫雷 | 旗格中心重复长按无法取消，边缘可以 | 检查旗帜图片出现后的触点命中与整格长按行为 |
| P2 | 设置 | 修改主题、默认难度后选中标记仍是旧值，重新进入才更新 | 让选中图标、文字、颜色与描述立即跟随偏好更新 |
| P2 | 我的／最近玩过 | 返回新进入的游戏后列表顺序未刷新，冷启动才更新 | 核对导航返回与页签切换时的概要刷新 |

复现步骤、原始截图和代码原因推断见[问题记录](mate60-issues-2026-09-30.md)。代码原因尚未通过修复版验证。另记录了资源副标题可能被页头忽略的审阅意见。

## 33 款玩法结果

“选定用例通过”只表示表内实际执行路径符合观察结果，不代表所有难度、所有胜负路径或性能已通过。未通过游戏仍保留其已通过的局部操作。

| 游戏 | 结论 | 实际覆盖与观察 | 证据示例 |
| --- | --- | --- | --- |
${rows}

滑动拼图在普通 4×4 入口之后，切换简单 3×3 完成通关；不能据此认定普通和困难通关通过。2048 验证方向移动、合并和计分，没有走到 2048 获胜或满盘失败。其余未枚举的随机局面和难度边界均不属于本轮已通过用例。

## 公共功能结果

| 项目 | 结论 | 实际检查范围与结果 | 证据示例 |
| --- | --- | --- | --- |
${publicRows}

手动暂停后后台停留 5 秒已覆盖贪吃蛇、打地鼠、打砖块、俄罗斯方块；跳一跳覆盖待蓄力状态。该检查不等于运行中锁屏 30 秒、反复恢复或蓄力中恢复验收。数据清空与恢复默认只检查确认提示和取消，没有执行删除操作。验收中的正常游玩会增加本地游玩次数，并可能更新最高分。

深色 33 张首屏已单独保存；视觉复核结论见公共检查点的 visualReview 字段。设置的主题、默认难度和三个开关恢复到本轮公共功能检查前的选择。

## 回归与稳定性证据

- 桌面规则回归：合集 82/82、性能与设置相关规则 159/159、接续规则 72/72，总计 313/313。它们没有替代真机 UI 或性能测量，且未捕获本轮界面缺陷。
- 应用故障记录与内存采样见[设备诊断](mate60-diagnostics-2026-09-30.json)。查询结论只适用于查询时能获取的记录；单次内存采样不能证明无泄漏。
- 所有结果均保留截图、对应布局与逐款检查点；脚本观察、坐标排序或等待时机错误经重试后单独处理，没有计为产品缺陷。

## 未执行范围

本轮完整覆盖了 33 款的选定基础玩法及上述公共用例。发布验收还需要实际覆盖长局帧率、温升、电耗和内存趋势；人手触控/多指/震动体验；最大字体、屏幕阅读器、英文；离线条件；运行中锁屏及多次恢复；旋转、分屏、折叠和平板；覆盖升级、Release 包与跨设备接续。相关硬件或测量条件不具备的项目未标记通过。

第一批五款仍保留以下专项边界：

${pending}

修复后先复测四款未通过游戏，再回归共用的记忆卡片、棋块显示、长按和重开逻辑，最后使用新的候选包哈希另建验收记录。不要混用当前 Debug 包与后续修复包或 Release 包结果。

## 可追溯记录

- [浅色入口检查点](mate60-light-progress.json)、[玩法检查点](mate60-gameplay-progress.json)、[公共功能检查点](mate60-public-progress.json)。
- [观察日志](mate60-gameplay-actions.jsonl)，原始布局位于 evidence/，截图位于 ../screenshots/。
- 历史入口记录：[第 1 批](batch-1-2026-09-30.md)、[第 2 批](batch-2-2026-09-30.md)、[第 3 批](batch-3-2026-09-30.md)、[第 4 批](batch-4-2026-09-30.md)；[第一批玩法](gameplay-batch-1-2026-09-30.md)。总报告覆盖历史批次进度描述。
`;
fs.writeFileSync(path.join(dir,'mate60-full-2026-09-30.md'),result);
fs.writeFileSync(path.join(dir,'README.md'),`# Mate 60 Pro 设备验收

更新日期：2026-09-30。用户要求取消分段，本轮已连续完成全部 33 款游戏的选定基础玩法及公共功能检查。

**结果：${pass.length} 款选定用例通过，${fail.length} 款未通过，${findingCount} 类已确认问题。当前候选需修复后复测，不能认定为发布验收通过。**

- [总报告](mate60-full-2026-09-30.md)：33 款结果、公共功能、实际覆盖范围、未执行项目和开发建议。
- [问题记录](mate60-issues-2026-09-30.md)：四款游戏及设置、最近列表的步骤和证据。
- [玩法检查点](mate60-gameplay-progress.json)：33/33 均有检查结果；[浅色入口](mate60-light-progress.json)和[深色/公共功能](mate60-public-progress.json)：各 33/33 入口和返回。
- [诊断记录](mate60-diagnostics-2026-09-30.json)、[观察日志](mate60-gameplay-actions.jsonl)、evidence/ 原始布局及 ../screenshots/ 截图。

设备 Mate 60 Pro / 7.0.0.709 SP6（设备 API 26），候选 1.0.0 / API 24 Debug。包 SHA-256：\`${game.packageHash}\`。这些结果仅适用于此设备与此包。

本轮没有修改应用代码或替换候选包。后续应按问题记录修复并复测受影响范围；新包必须另建记录并核对哈希。无需再按“下一批”继续当前 33 款基础检查。长局性能、真实触感、其他语言/字体/设备及 Release 包等发布专项保持未执行，详见总报告。

历史入口批次：[1](batch-1-2026-09-30.md)、[2](batch-2-2026-09-30.md)、[3](batch-3-2026-09-30.md)、[4](batch-4-2026-09-30.md)；[玩法首批](gameplay-batch-1-2026-09-30.md)。历史文档保留当时结论，以总报告和最新检查点为准。
`);
console.log(JSON.stringify({findingCount,publicFailures:publicFailures.length,games:game.results.length,passed:pass.length,failed:fail.length,dark:pub.darkGames.length,evidenceReferences:files.length,report:path.join(dir,'mate60-full-2026-09-30.md')}));
