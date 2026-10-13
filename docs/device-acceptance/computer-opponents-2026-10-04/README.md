# 六款游戏人机真机验收（2026-10-04）

**验收已完成。** 流程包 `0b1df8bf…49a1` 的 32/32 项功能检查通过；最新视觉包 `d0e1fef4…1cfa` 的 12/12 组浅色、深色视觉与真实输入回合通过。两包分别统计，最新包承接流程包 AI 逻辑，本次只修改视觉资源与呈现。

## 环境与方法

- 手机：`ALN-AL00`，设备标识 `FMR0224521016052`；系统 `OpenHarmony-7.0.0.105`，API `26`。
- 应用：`com.littlegames.collection`；[最终包安装信息](final/installed-bundle.txt)。
- 使用 [device-computer-opponents.cjs](../../../scripts/device-computer-opponents.cjs) 经 HDC 输入实际操作，并保存截图及同名 UI 树 JSON。测试不注入棋局、不读取应用私有数据。
- [流程包记录](logic-and-flow/summary.json)：18 组三档回合、6 组生命周期、6 组深色功能/布局、2 组真实起飞位移，共 32 项。
- [最新视觉包记录](final/summary.json)：六款浅色、深色各实际输入并等待电脑回应，共 12 组；[最新操作日志](final/actions.jsonl)。

## 流程包结果（logic-and-flow，32/32）

流程包 **32/32 功能检查通过**。回合验证实际玩家输入、自动电脑回应、返回玩家操作及难度选中设置；生命周期验证暂停、Home 后台返回、继续、悔棋、重开。6 组深色检查只记功能与布局通过，深色扑克花色及黑棋对比问题在后续视觉包修复，不能把该列视为视觉已通过。

| 游戏 | 简单回合 | 普通回合 | 困难回合 | 暂停/后台/继续/悔棋/重开 | 深色功能/布局 |
| --- | --- | --- | --- | --- | --- |
| 斗地主 | [通过](logic-and-flow/light-doudizhu-easy-replied.jpeg) | [通过](logic-and-flow/light-doudizhu-normal-replied.jpeg) | [通过](logic-and-flow/light-doudizhu-hard-replied.jpeg) | [通过](logic-and-flow/lifecycle-doudizhu-resumed.jpeg) | [通过](logic-and-flow/dark-doudizhu-replied.jpeg) |
| 掼蛋 | [通过](logic-and-flow/light-guandan-easy-replied.jpeg) | [通过](logic-and-flow/light-guandan-normal-replied.jpeg) | [通过](logic-and-flow/light-guandan-hard-replied.jpeg) | [通过](logic-and-flow/lifecycle-guandan-resumed.jpeg) | [通过](logic-and-flow/dark-guandan-replied.jpeg) |
| 麻将 | [通过](logic-and-flow/light-mahjong-easy-replied.jpeg) | [通过](logic-and-flow/light-mahjong-normal-replied.jpeg) | [通过](logic-and-flow/light-mahjong-hard-replied.jpeg) | [通过](logic-and-flow/lifecycle-mahjong-resumed.jpeg) | [通过](logic-and-flow/dark-mahjong-replied.jpeg) |
| 象棋 | [通过](logic-and-flow/light-xiangqi-easy-replied.jpeg) | [通过](logic-and-flow/light-xiangqi-normal-replied.jpeg) | [通过](logic-and-flow/light-xiangqi-hard-replied.jpeg) | [通过](logic-and-flow/lifecycle-xiangqi-resumed.jpeg) | [通过](logic-and-flow/dark-xiangqi-replied.jpeg) |
| 国际象棋 | [通过](logic-and-flow/light-chess-easy-replied.jpeg) | [通过](logic-and-flow/light-chess-normal-replied.jpeg) | [通过](logic-and-flow/light-chess-hard-replied.jpeg) | [通过](logic-and-flow/lifecycle-chess-resumed.jpeg) | [通过](logic-and-flow/dark-chess-replied.jpeg) |
| 飞行棋 | [通过](logic-and-flow/light-ludo-easy-replied.jpeg) | [通过](logic-and-flow/light-ludo-normal-replied.jpeg) | [通过](logic-and-flow/light-ludo-hard-replied.jpeg) | [通过](logic-and-flow/lifecycle-ludo-resumed.jpeg) | [通过](logic-and-flow/dark-ludo-replied.jpeg) |

补充位移检查 **2/2 通过**：实际骰子掷出 6 点、玩家 1 蓝色飞机起飞后，亮色按钮坐标由 `[170,967][262,1059]` 变为 `[584,1013][676,1105]`，见 [起飞前](logic-and-flow/light-ludo-movement-before.jpeg)、[六点骰子](logic-and-flow/light-ludo-movement-six.jpeg)、[起飞后](logic-and-flow/light-ludo-movement-takeoff.jpeg)及同名 JSON；[深色起飞证据](logic-and-flow/dark-ludo-movement-takeoff.jpeg)同样通过。

流程包于北京时间 2026-10-04 19:10:33 收尾，`finishedAt` 已记录。六款原难度恢复为普通；原主题“跟随系统”及 4 个 Toggle 状态（`false/true/true/true`）恢复并核对，见 [原设置](logic-and-flow/original-settings.json)、[恢复后设置](logic-and-flow/settings-restore.json)、[收尾首页](logic-and-flow/finished-home.jpeg)。

## 最新视觉包结果（final，12/12）

最新包仅修改牌面、花色墨色及黑棋轮廓，AI 逻辑保持流程包实现。六款浅色、深色界面均通过实际输入、电脑回应与视觉复核，**12/12 通过**；本表只采用 `final/summary.json` 的 12 个检查。

| 游戏 | 浅色视觉与操作 | 深色视觉与操作 |
| --- | --- | --- |
| 斗地主 | [通过](final/light-doudizhu-replied.jpeg) | [通过](final/dark-doudizhu-replied.jpeg) |
| 掼蛋 | [通过](final/light-guandan-replied.jpeg) | [通过](final/dark-guandan-replied.jpeg) |
| 麻将 | [通过](final/light-mahjong-replied.jpeg) | [通过](final/dark-mahjong-replied.jpeg) |
| 象棋 | [通过](final/light-xiangqi-replied.jpeg) | [通过](final/dark-xiangqi-replied.jpeg) |
| 国际象棋 | [通过](final/light-chess-replied.jpeg) | [通过](final/dark-chess-replied.jpeg) |
| 飞行棋 | [通过](final/light-ludo-replied.jpeg) | [通过](final/dark-ludo-replied.jpeg) |

目视复核确认扑克 ♠/♣ 与红黑墨字、六类黑棋亮轮廓及白棋升变选项均清楚；六款浅深色抽查未发现新的视觉阻塞。飞行棋真实起飞的双色专项证据仍归流程包，未混入最新包 12 项。

取证截图采集存在往返延迟；例如手牌刷新修复阶段的 [麻将困难档截图](hand-refresh-only/light-mahjong-hard-thinking.jpeg)捕获到“电脑 4 正在思考…”，部分其他回合采样时电脑已经回应。不能据截图文件名推断捕获到了思考状态，最终观察以各包 summary 的 `samples` 为准。

## 真机发现与修复

国际象棋首次实测发现白棋与棋盘对比不足，王后、车等外轮廓难以辨认；第一种描边尝试仍未解决。修复把轮廓拆成独立的 `fill="none"` 图元，使填充与描边分别渲染，兼容该设备的 SVG 显示行为。该修复阶段的白棋、黑棋及升变选择有 [亮色对照截图](hand-refresh-before/light-chess-outline-check.jpeg)；最终包白棋及升变选项已完成 [浅色](final/light-chess-ready.jpeg)、[深色](final/dark-chess-ready.jpeg)目视核对。

麻将重开、换难度后点击无效的根因已确认：静态 `ForEach` 的 `Hand(cards)` 闭包捕获首次手牌数组，模型换新手牌后界面仍使用旧牌 ID，点击被模型的 `includes` 持有检查拒绝。改为 `Hand(pile: number)`，构建闭包直接读取当前 `this.vm.state.piles[pile].cards`，同步更新手牌及点击 ID。[旧包首次打开可选牌](hand-refresh-before/mahjong-first-open-select.jpeg)与 [重开后点击无效 UI 树](hand-refresh-before/mahjong-native-click-selected.json)、[截图](hand-refresh-before/mahjong-native-click-selected.jpeg)均保留。手牌刷新修复阶段麻将、斗地主各三档真实出牌与电脑回应已通过，详见 [该包记录](hand-refresh-only/summary.json)。

飞行棋随后发现逻辑操作推进但飞机位置不刷新：实际起飞操作后步数由 0 变为 10，第一枚飞机按钮仍在 `[170,967][262,1059]`，见 [操作前截图](hand-refresh-only/ludo-movement-before.jpeg)、[UI 树](hand-refresh-only/ludo-movement-before.json)及 [操作后截图](hand-refresh-only/ludo-movement-after.jpeg)、[UI 树](hand-refresh-only/ludo-movement-after.json)。根因是 `ForEach` 闭包读取旧 `token.x`；位移表达式改为直接读取当前 `this.vm.state.pieces[token.id]`。流程包亮色、深色真实起飞位移与六款功能检查全部通过。

流程包深色视觉复核又发现两项对比问题：[扑克 ♠/♣ 字形在深色牌面偏暗](logic-and-flow/dark-doudizhu-ready.jpeg)，改用亮牌面及固定深色/深红墨字，最终 [斗地主](final/dark-doudizhu-ready.jpeg)、[掼蛋](final/dark-guandan-ready.jpeg)牌面可辨；[国际象棋黑棋轮廓偏暗](logic-and-flow/dark-chess-ready.jpeg)，该设备未显示同一图元上的填充加描边，改为独立亮色轮廓图元。最终包六款浅深色视觉及真实输入回合全部通过。

| 阶段 / 证据目录 | HAP SHA-256 | 记录用途 |
| --- | --- | --- |
| 首次包：本目录 | `0b325419c19bc16e4d789ce4e1138b705c28359480c940a3d3c49594410eaaa7` | [白棋问题截图](light-chess-normal-ready.jpeg)；[阶段记录](summary.json)含国际象棋三档回合及生命周期检查，不能代替最终包结果。 |
| 第一种描边：`outline-attempt-1/` | `531edab9b26b389760a298960ec44d109bdfae9583129acf64e704a453f42c7e` | [描边仍不足截图](outline-attempt-1/light-chess-normal-ready.jpeg)；[阶段记录](outline-attempt-1/summary.json)含国际象棋、象棋三档回合检查，保留为中间包证据。 |
| 独立轮廓修复、手牌刷新前：`hand-refresh-before/` | `7aeb3af65e5358af46614700cadd660935b33539b485a698faf91b652417bc30` | [独立轮廓修复截图](hand-refresh-before/light-chess-outline-check.jpeg)；[阶段记录](hand-refresh-before/summary.json)保留斗地主、掼蛋 6 组通过及麻将点击问题证据。 |
| 手牌刷新修复、位移修复前：`hand-refresh-only/` | `2d3b68245613ded26428e5d164b0dfd89fb344f0be8595e52cb3a95ba9504238` | [阶段记录](hand-refresh-only/summary.json)保留麻将、斗地主 6 组通过及飞行棋位置不刷新证据。 |
| 功能流程包：`logic-and-flow/` | `0b1df8bf9585944e14035a11f36acd7fd77e9622d420d5fa545a95dce21b49a1` | 白棋轮廓、手牌及飞机位移刷新修复；[32 项功能检查](logic-and-flow/summary.json)完成，深色视觉问题另行修复。 |
| 最新视觉包：`final/` | `d0e1fef47407138ff0d23956cd3b0f28d811ed7acbbaae6bed90ea8551741cfa` | 扑克亮牌面、固定墨色及黑棋独立亮轮廓；[12/12 组浅深色视觉与操作检查](final/summary.json)通过，收尾完成。 |

## 证据边界与收尾

本轮手机实测验证操作、自动回合及所列生命周期/视觉项目，不包含完整对局、AI 强度评估、精确 500 ms 时序或跨设备接续。`afterTouchMs`、`sampleMs` 包含输入与取证往返，不能作为精确电脑思考时长。[桌面检查记录](final/desktop-checks.json)分别记录手牌刷新阶段 963 项通过回归（含人机相关 115 项）、位移修复后 223 项复核、最终深色视觉修复后 223 项复核，均通过；`finalBuildLog` 对应流程包 10 秒 27 毫秒构建，`finalVisualBuildLog` 对应最新视觉包 14 秒 267 毫秒构建，未混计包身份。

最新视觉包于北京时间 2026-10-04 19:21:30 收尾，`finishedAt` 为 `2026-10-04T11:21:30.052Z`。原主题“跟随系统”及 4 个 Toggle（`false/true/true/true`）恢复并核对，与原设置一致，见 [最新包原设置](final/original-settings.json)、[恢复后设置](final/settings-restore.json)、[收尾首页](final/finished-home.jpeg)。最新 summary 的 `relatedFlow` 明确引用流程包的 SHA-256 与证据路径；32 项功能与 12 项最终视觉分别归属各自实测包。
