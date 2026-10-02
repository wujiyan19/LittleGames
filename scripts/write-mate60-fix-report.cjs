const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const dir='docs/device-acceptance',p=JSON.parse(fs.readFileSync(path.join(dir,'mate60-fix-progress.json')));
const passed=id=>p.results.some(r=>r.id===id&&r.status==='passed-selected-cases');
const categories=[
  ['记忆缺项与顺序记忆保留旧数字',['missing','memorysequence'],'连续十题全对得 2000 分；三个含重复数字的序列在重开后均通关'],
  ['华容道棋块位置与点击坐标不刷新',['klotski'],'右移、下移与新坐标选择正确；普通难度 9 步通关及重开'],
  ['扫雷旗格中心长按无法取消',['minesweeper'],'四角中心长按均能插旗和取消，旗格短按不揭开，首点安全'],
  ['设置选中显示滞后及文字对比度不足',['settings'],'三主题、三难度立即更新选中标记；浅/深色文字清晰；冷启动保存与默认难度生效'],
  ['返回游戏后最近列表不刷新',['recent'],'同一进程新开游戏返回后立即排列在最近列表首位']
];
const closed=categories.filter(([,ids])=>ids.every(passed)).length;
const full=closed===5&&p.smoke.light.length===33&&p.smoke.dark.length===33&&p.visualReview?.reviewed===66&&p.finalState==='original-preferences-restored-home';
p.summary={closedIssueCategories:closed,totalIssueCategories:5,selectedRegressionGroups:p.results.length,lightEntryReturn:p.smoke.light.length,darkEntryReturn:p.smoke.dark.length,automatedTests:316,repairVerificationComplete:full};
fs.writeFileSync(path.join(dir,'mate60-fix-progress.json'),JSON.stringify(p,null,2)+'\n');
const lines=[
'# Mate 60 Pro 验收问题修复与复测','',
'日期：2026-09-30。设备 Mate 60 Pro，用户系统 7.0.0.709 SP6，设备 API 26；候选 1.0.0 / API 24 Debug。','',
full?'**全部五类已确认缺陷修复并完成真机闭环复测。316 项自动回归通过，33 款游戏浅色/深色入口及返回各 33/33 通过。原偏好已恢复，手机停在精选首页。**':`**五类原问题已关闭 ${closed}/5；新包浅色/深色入口分别 ${p.smoke.light.length}/33、${p.smoke.dark.length}/33。其余检查继续以新包证据更新，尚未满足全部复测完成条件。**`,'',
'## 原缺陷关闭记录','',
'| 原问题 | 真机复测结果 | 状态 |','| --- | --- | --- |',
...categories.map(([name,ids,detail])=>`| ${name} | ${detail} | ${ids.every(passed)?'通过，关闭':'待完成'} |`),'',
'## 修复行为','',
'- 记忆卡片的复用标识包含位置和数字，删除、换题和重开后显示当前值。',
'- 华容道保留可观察棋块实例，在选择、移动、重开、难度切换及接续恢复时同步位置和选中状态。',
'- 扫雷装饰图片和数字不接收触摸、关闭拖拽，棋格统一接收操作。',
'- 设置选项和开关使用响应式组件；选中项采用浅/深色资源背景和高对比文字。',
'- 主页重新可见及标签切换时更新记录；统计卡片随新数据刷新。',
'- 标题栏支持资源类型副标题，补回华容道步数等信息。','',
'## 新包选定回归用例','',
...p.results.map(r=>`- **${r.name}**：${r.passedCases.join('；')}。证据：${r.evidence.map(id=>`[${id}](../screenshots/${id}.jpeg)`).join('、')}。`),'',
'## 全部入口与视觉复核','',
`新包浅色入口和返回 ${p.smoke.light.length}/33；深色 ${p.smoke.dark.length}/33。标题栏改动的共同影响范围通过全部入口检查；${p.visualReview?.reviewed||0} 张截图已人工视觉复核。`,'',
...(p.visualReview?.sheets||[]).map(s=>`- [${s}](visual-review/${s}.jpeg)`),'',
'每款检查为进入、首屏主体和返回流程。合集规则说明可以通过滚动查看；入口通过不表示重新完整通关了所有游戏。原包 29 款玩法选定用例保留在历史报告，不能冒充新包玩法结果。','',
'## 构建、自动回归与设备诊断','',
'签名构建成功；159 项性能/设置等已有回归、82 项合集回归、72 项接续回归及 3 项新增华容道显示状态回归，总计 **316/316**。新增回归覆盖移动后的坐标与选择、重开复位、三难度接续恢复。','',
'[自动回归原始结果](mate60-fix-unit-results.json)；[复测检查点](mate60-fix-progress.json)；[操作日志](mate60-fix-actions.jsonl)。每张截图配有 evidence/ 中同名布局 JSON。',
fs.existsSync(path.join(dir,'mate60-fix-diagnostics-2026-09-30.json'))?'[设备诊断原始记录](mate60-fix-diagnostics-2026-09-30.json)。应用故障记录查询的结论以该文件为准；单次内存/CPU采样不用于判断长局性能或泄漏。':'设备诊断待完成。','',
'## 候选身份与边界','',
`新包 SHA-256：\`${p.packageHash}\`。已成功覆盖安装，保留游戏战绩；安装响应保存在检查点。`,
`历史包 SHA-256：\`${p.baselinePackageHash}\`。保留[原问题](mate60-issues-2026-09-30.md)和[原完整报告](mate60-full-2026-09-30.md)用于对照。`,'',
'本轮关闭的是此设备、此 Debug 包上的五类已确认问题。长局帧率、功耗、温升、人手触感、其他字体/语言/设备和 Release 包专项未在此复测中量化，不能据此宣称完整发布验收通过。','',
'## API 核对','',
'主页刷新采用 SDK 已有的 Navigation.onNavBarStateChange（API 9 起），用途由[华为 Navigation 生命周期说明](https://developer.huawei.com/consumer/cn/doc/doccenter-dev-faq/faqs-arkui-504?docScope=all)确认。触摸和拖拽修正依据[命中测试说明](https://developer.huawei.com/consumer/cn/doc/doccenter-dev-faq/faqs-arkui-1131)及[拖拽事件文档](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/ts-universal-events-drag-drop)。设置刷新依据[Builder 参数说明](https://developer.huawei.com/consumer/cn/doc/doccenter-dev-faq/faqs-arkui-1009)。均通过 API 24 编译，无新增权限或依赖。',''
];
const report=lines.join('\n');
for(const match of report.matchAll(/\]\(([^)]+)\)/g)){if(/^https:/.test(match[1]))continue;assert(fs.existsSync(path.resolve(dir,match[1])),'Missing evidence '+match[1]);}
fs.writeFileSync(path.join(dir,'mate60-fix-2026-09-30.md'),report);
console.log(JSON.stringify(p.summary));
