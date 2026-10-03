# 原有 33 款游戏美术与交互真机验证

2026-10-03，设备 `FMR0224521016052`，系统 `ALN-AL00 7.0.0.109(SP6C00E105R5P3)`，屏幕 1260×2720。应用 `com.littlegames.collection`，API 24 Debug 包。

**33 款老游戏浅色、深色各 33 个入口及返回通过，66 个首屏已视觉复核，未见缺图或主要操作控件遮挡。11 款重点游戏的 33 组选定交互通过；包含修复后深浅色复测，共执行 45 组检查。已修复扫雷及双人游戏玩家 2 获胜的庆祝遗漏。**

本轮针对[老游戏美术检查](../../art/legacy-art-review.md)验证实际画面和现有交互。打地鼠命中特效、翻牌翻转、三消分阶段动画和数织线索对齐仍是后续改进项，本轮未实现这些升级。

## 包身份与阶段

| 阶段 | 签名 HAP SHA-256 | 实际覆盖 |
| --- | --- | --- |
| 初始美术包 | `b263d2231a4b556b6a753d7da2468461ee0c121fed5ba7ea12301c52ce70e13b` | 浅色 33 款首屏、入口和返回；10 款 29 组交互 |
| 庆祝修复包，手机当前已安装 | `77005b32ab24e4a6275f50b809509ea5c72617b2ce69627e8ac4d9692b4fb936` | 深色 33 款首屏、入口和返回；井字棋及扫雷各在浅色、深色复测，16 组交互 |

两个阶段只相差两处结果弹窗庆祝参数。浅色首屏与其他 9 款玩法的验证记录属于初始包，不能合并称为最终包全量玩法验收。最终签名包大小 7,826,568 字节，安装更新时间 `1791001649381`；本地 HAP 哈希及设备包信息已核对，见 [metadata.json](metadata.json)、[installed-final.json](installed-final.json) 和 [summary.json](summary.json)。

## 修复及复测

1. 扫雷把胜利判定传给已有 `GameResultDialog.celebrate`，通关显示奖杯及庆祝效果。浅色实际解开一局，34 秒完成；深色实际解开一局，45 秒完成。插旗、取消插旗、首格安全及重开旗数归零通过。
2. Collection 结果弹窗对双人游戏玩家 1、玩家 2 获胜都启用庆祝，单人失败和平局保持原判定。井字棋分别完成双方胜利和平局，深浅色均复测；入场帧可见奖杯和星星粒子，稳定帧弹窗底色不透。覆盖位置的底层重开按钮无法穿透结算弹窗；“再来一局”恢复首回合。

源码：[扫雷](../../../entry/src/main/ets/pages/classic/MinesweeperPage.ets)、[Collection](../../../entry/src/main/ets/pages/collection/CollectionPage.ets)。本轮只调整已有参数，没有新增 ArkUI API。

| 证据 | 浅色 | 深色 |
| --- | --- | --- |
| 玩家 2 获胜入场与粒子 | [入场](fixed-light-play-tictactoe-player2-arrival.jpeg) | [入场](fixed-dark-play-tictactoe-player2-arrival.jpeg) |
| 玩家 2 获胜稳定弹窗 | [稳定帧](fixed-light-play-tictactoe-player2-result.jpeg) | [稳定帧](fixed-dark-play-tictactoe-player2-result.jpeg) |
| 扫雷通关奖杯 | [通关](fixed-light-play-minesweeper-win.jpeg) | [通关](fixed-dark-play-minesweeper-win.jpeg) |
| 平局结果 | [平局](fixed-light-play-tictactoe-draw-result.jpeg) | [平局](fixed-dark-play-tictactoe-draw-result.jpeg) |

## 选定交互覆盖

| 游戏 | 不重复检查组数 | 实际步骤及结果 |
| --- | ---: | --- |
| 井字棋 | 4 | 双方胜利结算；弹窗阻挡底层重开；再来一局；平局 |
| 消消乐 | 3 | 从截图宝石颜色推导无效及合法交换；无效不扣分/步数，4 次合法交换均加分且各扣 1 步；选择及重开 |
| 记忆翻牌 | 4 | 从实际牌面找齐 8 对；未匹配牌延迟盖回；配对保留牌面；通关与重开清零 |
| 打地鼠 | 3 | 点击实际出现的地鼠加分；空洞不加分；暂停后倒计时停止 |
| 滑动拼图 | 3 | 非相邻点击不移动；相邻数字进入空位；重开步数清零 |
| 2048 | 2 | 四方向共 12 次滑动产生合并与得分；重开清零 |
| 数独 | 3 | 空格填入/擦除；固定数字不可修改；选中数字及宫格边界截图 |
| 落子四连 | 2 | 两列落子最终位于底部；回合切换 |
| 翻转棋 | 2 | 实际合法位置落子并翻转被夹棋子；回合切换 |
| 数字绘格 | 3 | 填格/检查可用；未完成不提前结算；线索和棋盘布局截图 |
| 扫雷 | 4 | 长按插旗/取消；首格安全；由屏幕数字与背景色推理解开；胜利结算/重开 |

原始记录：[interactions.jsonl](interactions.jsonl)、[actions.jsonl](actions.jsonl)，检查期间未出现未完成项。程序只使用 HDC 的实际 UI 输入、布局和屏幕截图，没有导入游戏模型或注入对局状态。对应脚本为 [入口及截图](../../../scripts/device-art-review.cjs)、[交互验证](../../../scripts/device-art-interactions.cjs)、[截图像素识别](../../../scripts/device-art-pixels.ps1)。

结果变化可证明玩法输入有效；交换、下落、翻牌等中间动画仍依据源码与入场截图单独评估，不能由最终得分或最终棋盘推断动画已完善。

## 首屏视觉证据

每张索引含 11 款，共 66 张本轮设备截图。索引由 [拼图脚本](../../../scripts/device-art-contact-sheets.ps1)生成，六张均已视觉复核；单款原图和布局以 `{light,dark}-游戏ID-ready` 命名保存在本目录。

| 主题 | 1–11 | 12–22 | 23–33 |
| --- | --- | --- | --- |
| 浅色，初始包 | [拼图 1](contact-light-1.jpeg) | [拼图 2](contact-light-2.jpeg) | [拼图 3](contact-light-3.jpeg) |
| 深色，修复包 | [拼图 1](contact-dark-1.jpeg) | [拼图 2](contact-dark-2.jpeg) | [拼图 3](contact-dark-3.jpeg) |

画面改进优先级保持：打地鼠缺少场景和命中表现；记忆翻牌正反面直接切换；三消直接提交最终棋盘；数织线索需对齐行列。深色扫雷揭开/未揭开格层次偏近，数独每格装饰角线偏密，可继续细化。

## 构建、回归与收尾

- DevEco 内置 SDK / API 24 `assembleHap` 成功，见 [build.log](build.log)。
- Collection 82/82 相关回归通过，见 [collection-tests.log](collection-tests.log)。
- 美术及反馈检查 7/7 通过，见 [art-tests.log](art-tests.log)。
- 原设置恢复并核对：主题“跟随系统”、记住难度关闭、震动反馈开启、退出确认开启。见 [原设置](original-settings.json)、[恢复后设置布局](settings-restore.json)及[截图](settings-restore.jpeg)。验证产生的实际游玩次数和战绩保留。
- 应用已回到[精选首页](finished-home.jpeg)，手机保留修复包。

## 验证范围

本轮覆盖原有 33 款首屏、11 款选定交互及两处庆祝修复，未覆盖全部 100 款游戏、所有难度、其他设备/窗口和语言。截图包括部分入场帧，未连续录像、测量帧率或执行长局性能测试；远程 UI 输入不能代替用户对真实震动触感的确认。
