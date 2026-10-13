# 第 62—83 款扩充游戏的截图复核

复核日期：2026-10-09。使用本轮 `catalog.json` 对应的 22 张原始游戏页截图，并对照 `visual-08.png` 至 `visual-11.png` 中从真实分类截图裁出的图标。原始截图为 1260×2720，图集只作对照，细节以原始截图和相邻原生布局 JSON 为准。

包 SHA256：`e14b33644f6a0f72964c96e56f0a692c70680db11437152601f9a241e4911757`；设备：`FMR0224521016052`。本次没有操作 HDC，也没有修改应用或验收脚本。

22 款标题均完整可见；未见固定浮层压住棋盘、手牌或主要操作按钮。开始、左右、跳跃、挂钩、振翅、升级、漂移、刹车和油门等当前可见按钮均位于首屏内容区域。斗地主 20 张手牌、掼蛋 27 张手牌分行排列，没有互相覆盖；两款的提示和出牌按钮均在当前首屏可见。图标和场内人物、球、坦克、车辆、平台及牌面保持同一套配色与扁平插画风格，未见明显画风断裂。

## 已观察到的可读性与样式问题

1. **台球主球、高尔夫主球和保龄球瓶身在浅蓝背景上较难辨认。** 两款主球呈浅蓝灰色，与背景接近；保龄球瓶身轮廓很淡，较醒目的部分主要是颈部红条和地面落影。高尔夫原生图像节点为 58×58 设备像素、台球主球为 77×77，素材内部还留有空白；高尔夫主球因尺寸与颜色共同作用更难发现。节点均实际存在，不能把这项描述成实体消失或渲染未更新。建议加强主球及瓶身轮廓，不需要改变碰撞半径。证据：[台球](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-billiards-page.jpeg)、[高尔夫](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-golf-page.jpeg)、[保龄球](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-bowling-page.jpeg)。
2. **单键漂移的道路边界很淡。** 蓝色车辆清晰，但浅蓝场地内只有两条很淡的弯曲边线，可行驶带不够清楚。建议加强两条边界的颜色区别。截图不能证明车辆越界规则、行驶更新或通关有问题。证据：[单键漂移](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-drift-page.jpeg)。
3. **背包战斗的已选装备仍为直角蓝框。** 与圆角棋盘格、素材容器及其余圆角控件不一致，和第 34—46 款报告中的拼块/管道选中框属于同一局部样式问题。证据：[背包战斗](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-backpack-page.jpeg)。
4. **双人拔河右下背景水印明显被纵向压扁。** 前景两个玩家比例正常，右下淡色人物装饰却被压成几层椭圆和短线。只读源码确认：`exp_board_tug.svg` 使用 360×460 的纵向画布，而当前 `Tug` 横向 banner 把背景宽高均设为 100%，导致装饰被拉伸。它属于低优先级装饰失真，没有遮挡玩家按钮，也不证明拔河逻辑异常。证据：[双人拔河](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-tug-page.jpeg)，[背景资源](E:/lianxi/LittleGames/entry/src/main/resources/base/media/exp_board_tug.svg)，[场景组件](E:/lianxi/LittleGames/entry/src/main/ets/pages/collection/ExpansionWorldBoard.ets)。

![高尔夫主球较难辨认的原始截图](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-golf-page.jpeg)

![保龄球瓶身低对比的原始截图](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-bowling-page.jpeg)

## 首屏与滚动边界

斗地主和掼蛋的原生布局均记录 `Scroll.bounds = [0,318][1260,2538]`、`scrollable = true`；其内容由 `ExpansionPage` 的原生 `Scroll` 承载。掼蛋首屏没有显示更下方的“撤销上一步”，这是内容超出当前滚动视口，不是固定浮层遮挡。当前提示、跳过和出牌按钮均已完整显示。此次只读复核没有实际执行滚动，因此不把“滑动到撤销成功”列为通过项。

台球、保龄球和高尔夫初始页没有“点击开始”按钮；现有场景组件明确让这三款直接通过场内手势开始，不能把它归类为按钮消失。实时游戏当前截于待开始阶段，空场或尚未进场的敌人/柱子也不能从单张截图推断成逻辑故障。

## 逐款覆盖

| 序号 | 游戏 | 当前首屏健康状况 | 原始游戏页 |
| --- | --- | --- | --- |
| 62 | 横版跳跃闯关 | 标题、玩家和平台可见，开始/左右/跳跃完整 | [截图](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-platformer-page.jpeg) |
| 63 | 钩索摆荡 | 标题、玩家和锚点可见，开始/挂钩/松开完整 | [截图](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-grapple-page.jpeg) |
| 64 | 飞行穿柱 | 标题、鸟和进度可见，开始/振翅完整 | [截图](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-flappy-page.jpeg) |
| 65 | 切水果 | 标题、进度和失误可见，完整待开始场地与开始按钮 | [截图](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-fruitslice-page.jpeg) |
| 66 | 滚动球闯关 | 标题、球/平台/障碍/终点和开始完整 | [截图](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-rollingball-page.jpeg) |
| 67 | 雷电战机 | 标题、生命/进度、飞机和开始可见 | [截图](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-shooter-page.jpeg) |
| 68 | 坦克对战 | 标题、生命/进度、坦克和开始可见 | [截图](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-tanks-page.jpeg) |
| 69 | 射击守城 | 标题、生命/进度/金币、塔、开始/升级可见 | [截图](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-fortress-page.jpeg) |
| 70 | 自动攻击生存 | 标题、生命/进度、玩家和开始可见 | [截图](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-survival-page.jpeg) |
| 71 | 背包战斗 | 完整装备栏/4×4 棋盘/战斗/撤销；选中装备为直角框 | [截图](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-backpack-page.jpeg) |
| 72 | 台球 | 标题、完整球台/彩球/洞可见；浅色主球对比弱 | [截图](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-billiards-page.jpeg) |
| 73 | 足球点球 | 标题、射门/进球、守门员/球/开始可见 | [截图](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-penalty-page.jpeg) |
| 74 | 乒乓球 | 标题、比分、两侧球拍/球/开始可见 | [截图](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-pingpong-page.jpeg) |
| 75 | 保龄球 | 标题、场地/球/瓶可见；浅色瓶身对比弱 | [截图](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-bowling-page.jpeg) |
| 76 | 迷你高尔夫 | 标题、杆数、平台/旗帜/球可见；主球小且对比弱 | [截图](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-golf-page.jpeg) |
| 77 | 单键漂移 | 标题、时间/车辆/开始/换向可见；道路边界偏淡 | [截图](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-drift-page.jpeg) |
| 78 | 爬坡越野 | 标题、进度、地形/车辆/开始/刹车/油门完整 | [截图](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-hillclimb-page.jpeg) |
| 79 | 空气曲棍球 | 标题、比分、击球器/球/开始可见 | [截图](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-airhockey-page.jpeg) |
| 80 | 双人拔河 | 联机入口、绳标、双方玩家/进度/按钮/撤销完整；背景水印失真 | [截图](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-tug-page.jpeg) |
| 81 | 点格棋 | 联机入口、回合提示、完整 5×5 点阵及撤销可见 | [截图](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-dots-page.jpeg) |
| 82 | 斗地主 | 人机状态、对手牌数、20 张手牌、提示/跳过/出牌/撤销可见 | [截图](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-doudizhu-page.jpeg) |
| 83 | 掼蛋 | 人机状态、对手牌数、27 张手牌、提示/跳过/出牌可见；下方内容由 Scroll 承载 | [截图](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-guandan-page.jpeg) |

## 证据边界

静态截图和布局 JSON 能支持当前画面、布局、层次和节点尺寸的结论，不能支持命中率、碰撞、动作持续、帧率、胜负、暂停/恢复、大字号、横屏、深色主题或其他设备的通过结论。当前没有发现可由截图证明的逻辑故障，也没有把风格或可读性建议升级为未经实测的玩法问题。
