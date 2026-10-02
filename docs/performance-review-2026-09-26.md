# 性能检查与优化建议（2026-09-26）

> 本文保留优化前的检查结论；本轮已完成代码优化，实施和验证结果见 [性能优化记录](performance-optimization-2026-09-26.md)。下文的代码行号对应检查时的版本。

本轮检查当前工作区代码、图片资源和本机 API 24 SDK，并对部分纯逻辑进行桌面抽测。没有修改应用代码，也没有真机帧率、功耗或温度采样。因此，下文区分可确认的额外工作和需要设备测量的性能风险，不把代码问题等同于已经测出的掉帧或发热。

## 建议优先级

| 顺序 | 优化项 | 主要场景 | 判断 |
| --- | --- | --- | --- |
| 1 | 动态位移由 offset 改为 translate | 跳一跳、打砖块、2048、数独缩放 | 高频布局属性更新，优先优化并对比布局耗时 |
| 2 | 暂停、后台、待发和退出弹窗期间停止循环 | 贪吃蛇、俄罗斯方块、打砖块、打地鼠 | 代码与逻辑验证确认仍有周期回调 |
| 3 | 跳一跳清理已离屏的历史平台 | 长时间连续游玩 | 数据和每次落地的工作量持续增长 |
| 4 | 缩小首页图标和地鼠图片 | 冷启动、分类页、打地鼠 | 图片原始尺寸显著超过展示需求 |
| 5 | 连续运动采用系统动画或与显示刷新同步的循环 | 跳一跳、打砖块 | 当前更新节奏与屏幕刷新不同步 |
| 6 | 减少实时模糊，先冻结弹窗下的游戏 | 游戏页头、退出确认 | 明确存在实时模糊；实际 GPU 成本待测 |
| 7 | 棋盘按格更新，静态背景与活动内容分开 | 贪吃蛇、俄罗斯方块 | 共享状态使大量格子有重新计算的可能 |
| 8 | 缓存碰撞矩形，减少热路径临时对象 | 打砖块、长蛇吃食物 | 确认存在重复计算和分配；收益待测 |

## 1. 高频位移使用图形变换

- [跳一跳角色](../entry/src/main/ets/pages/classic/JumpJumpPage.ets#L149)每约 16ms 更新一次 offset；平台落地归一化时也更新 offset。
- [打砖块](../entry/src/main/ets/pages/classic/BrickBreakerPage.ets#L140)挡板随拖动更新 offset，小球每约 30ms 更新 offset。
- [2048](../entry/src/main/ets/pages/classic/Game2048Page.ets#L308)对 offset 做隐式动画。
- [数独](../entry/src/main/ets/pages/puzzle/SudokuPage.ets#L157)双指缩放时同步修改 offset。

跳一跳文件注释把 offset 称为“不触发布局的合成属性”，这个描述应纠正。华为官方将 position、offset 列为布局属性，对应的图形变换替代方式是 translate；图形变换在布局后改变显示结果，避免重新布局计算。详见[官方动画性能指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-animation-usage-guide)。

建议保持组件的布局位置和尺寸固定，通过 translate、scale 表达运动；不必替换仅在初始化或窗口变化时设置的静态 offset。更改后检查数独缩放中心、拖动坐标、点击命中和无障碍定位。

## 2. 停止闲置循环，并修复贪吃蛇重开残留计时器

[贪吃蛇](../entry/src/main/ets/viewmodel/SnakeViewModel.ets#L242)、[俄罗斯方块](../entry/src/main/ets/viewmodel/TetrisViewModel.ets#L174)、[打砖块](../entry/src/main/ets/viewmodel/BrickBreakerViewModel.ets#L262)、[打地鼠](../entry/src/main/ets/viewmodel/WhackMoleViewModel.ets#L95)的后台处理改变 status，没有清理周期定时器。回调仍会进入，只是通过状态判断跳过业务。手动暂停存在相同模式。

桌面逻辑验证中，四款游戏启动后切后台，分别仍保留 1、1、1、2 个周期回调。打砖块的间隔为 30ms，暂停期间仍有每秒约 33 次回调请求；后台实际调度频率受系统策略影响，这里不是后台实测唤醒次数。

[退出请求](../entry/src/main/ets/viewmodel/BrickBreakerViewModel.ets#L288)等路径仅设置 confirmExit，游戏继续推进。退出确认弹窗遮住游戏后，CPU 运算、界面刷新和动态背景模糊可能同时继续。

另有一个具体问题：[贪吃蛇 startGame](../entry/src/main/ets/viewmodel/SnakeViewModel.ets#L150)没有停止旧定时器，而 stepOnce 只检查 status。因此运行中重开后，started 虽为 false，旧回调仍会移动新蛇。逻辑验证已确认这个行为，会造成待开始界面的意外更新。

建议统一处理“循环是否需要运行”：页面可见、应用前台、没有遮挡弹窗、状态为进行中、已经开始。暂停和后台时清理句柄，恢复时按需要重建；打砖块漏球待发也停表；贪吃蛇重开先停旧表。恢复时保留用户主动暂停状态，并为倒计时明确剩余时间口径。

## 3. 跳一跳平台使用有界窗口

[ensurePlatforms](../entry/src/main/ets/viewmodel/JumpJumpViewModel.ets#L150)每次追加 6 个平台，从不删除历史平台；[normalize](../entry/src/main/ets/viewmodel/JumpJumpViewModel.ets#L163)每次落地遍历全部平台，逐个修改带 @Trace 的 centerX。[页面](../entry/src/main/ets/pages/classic/JumpJumpPage.ets#L131)虽只创建可见图片，ForEach 输入仍是全部平台，屏外判断不能清理数组数据。

桌面逻辑验证模拟 1000 次成功落地后，数组仍保留 1008 个平台。这会让内存、状态更新和落地遍历成本随游戏时长增长。

建议只保留少量历史平台及当前/未来平台，删除已离屏且不再参与判定的平台，同时调整 currentIndex，继续使用稳定 id。进阶方案是用统一镜头偏移平移平台容器，减少逐平台状态写入；保留对象数量有界应先完成。目标是玩 100 次和 1000 次后，平台数量、落地耗时都保持稳定。

## 4. 图片资源与展示尺寸匹配

[卡片图标](../entry/src/main/ets/components/GameCard.ets#L37)仅显示 42×42vp，但 13 张 game_*.png 都是 1254×1254，文件合计约 13.9 MiB。按全部原尺寸 RGBA 像素计算约 78 MiB，这只是尺寸换算，不是实测内存；实际解码尺寸、缓存共享及驻留数量取决于框架和页面状态。

[地鼠](../entry/src/main/ets/pages/classic/WhackMolePage.ets#L142)使用 1312×1199 PNG，约 1.33 MiB，用于小洞中的角色。其余多数游戏素材已经是小 SVG，不需要一并替换。

建议根据最大展示尺寸和设备像素密度生成合适的小尺寸版本，首页图标可从 128–256px 档位试起，再核对其它引用场景。地鼠同样按实际显示需求制作资源；保留透明度和视觉细节。先减少像素数量，再评估压缩格式。以首次解码耗时、进入分类页的卡顿和内存峰值验证，不能仅以安装包变小判断收益。

## 5. 改善连续运动的帧节奏

[打砖块](../entry/src/main/ets/viewmodel/BrickBreakerViewModel.ets#L16)用 30ms 定时器，理论上约 33.3 次位置更新/秒；小球没有位置插值。在 60Hz 屏幕上位置更新会跨不均匀的显示帧，即使系统没有掉帧，也可能看到不均匀的运动。

[跳一跳](../entry/src/main/ets/viewmodel/JumpJumpViewModel.ets#L237)用 16ms 定时器更新抛物线，它不是屏幕垂直同步回调；UI线程忙时也可能延后执行。跳跃结果在起跳前已判定，可以优先评估用原生属性动画表达已知轨迹，完成后结算；蓄力达到 100% 时也可以停止重复 tick。

需要实时物理计算的打砖块，可评估 SDK 中的 displaySync（API 11 起提供）控制更新节奏，并将物理步进与显示插值分开。本机 API 24 声明文件已确认存在 setExpectedFrameRateRange、frame 回调及 start/stop。

不要直接把打砖块 30ms 改为 16ms：其速度是 vp/步，直接提高回调频率会改变玩法。可保留固定物理步长并插值显示，或改为时间差驱动并限制补步量。也不要让静态棋盘持续跑 60/120fps 循环。原生属性动画与逐帧动画的取舍参见[官方帧动画说明](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/arkts-animator)。

## 6. 实时模糊与缓存有选择地使用

[GameHeader](../entry/src/main/ets/components/GameHeader.ets#L143)使用 backdropBlur(20)；[退出弹窗](../entry/src/main/ets/components/ExitConfirmDialog.ets#L82)同时有卡片模糊和全屏模糊；[结果弹窗](../entry/src/main/ets/components/GameResultDialog.ets#L59)也采用类似叠加。

官方明确说明 blur/backdropBlur 是实时模糊接口，渲染负载较高，详见[背景设置说明](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V13/ts-universal-attributes-background-V13)。先停止弹窗下的游戏更新，再对比移除全屏模糊、减少模糊层数或改用纯色遮罩的效果。头部背景较简单时也可评估去掉模糊。

renderGroup 适合内容稳定、整体移动或缩放的复杂子树。数独棋盘缩放已有缓存；首页卡片整体缩放可做对比。不要给每帧改变内容的整张游戏棋盘或每个单图片节点无差别开启缓存，缓存重建可能抵消收益。官方指南也强调固定内容与整体动效的适用条件。

## 7. 棋盘避免共享状态驱动大量格子重算

[贪吃蛇](../entry/src/main/ets/pages/classic/SnakeGamePage.ets#L101)有 400 个格子，每格查询共享的 occupied、snake 或 food；移动会整体替换数组、Set 和外观 Map。[俄罗斯方块](../entry/src/main/ets/pages/classic/TetrisGamePage.ets#L119)有 200 个格子，渲染读取同一个 piece，颜色与内容又分别调用 cellMark。

这意味着一次只改变少量格子的操作，也可能令大量订阅重新计算。稳定 ForEach key 能复用节点，但不保证仅更新变化格子；实际更新数量需用 ArkUI Inspector/Profiler 确认。

优先方案是具备显式类型的每格 @ObservedV2 数据，仅修改显示发生变化的格子，并拆分静态背景与活动蛇身/方块层。贪吃蛇需要正确处理头尾、转角及食物变化，不能假设只变头尾两格。若测量仍显示节点成本较高，再评估 Canvas，保留输入和无障碍能力；现阶段不建议直接重写所有棋盘。

## 8. 减少热路径重复分配

[打砖块碰撞](../entry/src/main/ets/model/game/BrickBreakerModel.ets#L217)每步为每个活砖调用 brickRect 并创建矩形，尽管砖块几何在整关固定。40–64 个活砖、30ms 循环时，未提前命中场景会请求约 1300–2100 个矩形对象/秒，另有球状态和结果对象。

建议关卡初始化时缓存矩形和固定尺寸，步进时只读取。是否进一步复用球/结果对象应结合 GC 测量，并保留模型测试的输入输出语义。砖块数量很小，当前没有必要先引入复杂空间索引。

[贪吃蛇生成食物](../entry/src/main/ets/model/game/SnakeModel.ets#L99)遍历 400 个格子，每格线性扫描蛇身，成本约为 O(400×蛇长)，还创建空格 Point 列表。可复用占用集合做 O(1) 判定，仅记录格子编号或采用均匀抽样，最后只创建选中的食物 Point。蛇已占满棋盘时必须有限时间退出。

## 暂不作为首轮主项

- 数独生成在 UI 调用路径同步执行，包含回溯唯一解检查，存在长尾风险。桌面 Node 抽测每档 150 个种子，困难档 P95 约 2.56ms、最大 4.30ms；这不能代表 ArkTS 真机耗时，暂不把它判为已确认卡顿。先测真机长尾，必要时才把纯计算移至 TaskPool，并处理重开/退出后的过期结果。单纯加 async 或 Promise 不会把计算移出 UI 线程。
- 消消乐同样有同步生成与连锁循环。桌面生成抽测 150 个种子，P95 约 0.13ms、最大 2.73ms；退化种子出现过 1000 次生成尝试。生产随机源下的分布和连锁极端情况需另测。可以改为填格时避免三连，连锁按轮分批处理，但不应仅根据循环存在就认定必须多线程。
- 持久化已有 200ms 防抖，日常 flush 为异步；后台和设置使用 flushSync。可添加 dirty 标记，避免无变化的后台切换仍全量写盘，但规模只有 13 个游戏，优先级低于动画和循环。必须保留已验证的数据可靠性，不能简单删除关键同步刷盘。
- 首页只有 13 款游戏，优先优化图片，暂不需要为了数量小的列表强行引入复杂懒加载。

## 验证方式

本轮桌面验证将模型转成 JS，移除观察装饰器，并替代存储、屏幕和定时器；验证的是数据增长、句柄管理和规则耗时，不覆盖 ArkUI 渲染、SDK 构建、真实定时调度或设备功耗。

后续采用同一真机、相同构建模式、亮度、初始温度和操作脚本，对比优化前后：

1. 打砖块连续运行 3–5 分钟，记录帧时间、丢帧、主线程布局、GC 和 CPU/GPU 负载；区分系统掉帧与 33fps 逻辑更新造成的运动不均匀。
2. 游戏运行后分别暂停、打开退出弹窗、切后台，验证周期循环停止，恢复后没有重复计时器或异常加速。
3. 跳一跳长局检查平台数量、内存曲线及落地耗时；贪吃蛇运行中重开必须保持待开始状态。
4. 冷启动和首次进入分类页记录图片解码与内存峰值；连续游玩 10–15 分钟比较温升、耗电和降频后的帧稳定性。

DevEco Profiler 的 Energy 模板可用于定位高负载线程；参见[官方 CPU 高负载分析](https://developer.huawei.com/consumer/cn/doc/doccenter-app-quality/bpta-high-cpu-load-analysis)。优化收益应以这些设备数据确认，不能由代码改动直接承诺温度或帧率降幅。
