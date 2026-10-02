# GitHub 小游戏合集调研与候选清单

调研日期：2026-09-27。对照当前工程 33 款游戏，从离线逻辑谜题、中文／浏览器合集、纸牌／轻量街机三个方向，用 Exa 检索 39 条结果（包含重复页），再核对代表项目的 README、作者说明、部分源码目录与许可证文件。

结论：整理出 **36 种尚未收录的候选玩法**，建议下一批先考虑其中 **12 款**。这是一份选型报告，本次没有修改游戏实现，也没有下载或导入第三方代码、美术或关卡。未逐款运行参考项目；下述实现成本是结合当前 ArkTS 工程作出的判断，不是对参考项目质量的认证。

## 最有参考价值的合集

| GitHub 项目 | 核对到的内容 | 本项目可借鉴的方向 | 许可与限制 |
| --- | --- | --- | --- |
| [chrisboyle/sgtpuzzles](https://github.com/chrisboyle/sgtpuzzles) | Simon Tatham 谜题集的 Android 移植；作者介绍 40 款单人逻辑游戏，离线、可调尺寸和难度 | 谜题生成、撤销、触屏交互、桥梁／管线／灯泡等新玩法 | [作者说明](https://chris.boyle.name/projects/android-puzzles/)明确：GitHub 源码使用 MIT，但 APK 内额外图形不包含在该许可中 |
| [KyleDSwarner/puzzles-reloaded](https://github.com/KyleDSwarner/puzzles-reloaded) | README 列出 54 款，整合原版与两个扩展谜题库，面向 iOS／iPadOS | 手机／平板交互，以及更多逻辑题型 | 仓库标注 MIT；扩展来自独立子模块，应逐一核对 |
| [SinceraXY/GameHub](https://github.com/SinceraXY/GameHub) | README 列出 42 款、7 类；已核对 games 分类目录及 Action 子目录 | 泡泡射击、叠塔、射箭、节奏点击、拼图、找不同 | 已读取根目录 [Apache-2.0 LICENSE](https://github.com/SinceraXY/GameHub/blob/main/LICENSE)；未完成逐个游戏的素材来源审查，宜作玩法与分类参考 |
| [foss-card-games/Solitairey](https://github.com/foss-card-games/Solitairey) | JavaScript 纸牌合集，明确列出 Klondike、FreeCell、Spider、Pyramid、Golf、Tri Towers 等 | 补齐单人纸牌类别，参考牌堆规则、撤销与自动收牌 | 已读取 [BSD-2-Clause LICENSE](https://github.com/foss-card-games/Solitairey/blob/master/LICENSE)；该分支专门保留了原项目带许可证的版本，不能把结论扩展到其他分支的所有素材 |
| [shlomif/PySolFC](https://github.com/shlomif/PySolFC) | 大型纸牌／牌块合集；[官方目录](https://pysolfc.sourceforge.io/all_games.html)包含多种纸牌、Shisen-Sho 和 Samegame | 规则差异、牌局分类、连连看、提示与撤销 | 已读取 [GPLv3 COPYING](https://github.com/shlomif/PySolFC/blob/master/COPYING)。优先作规则调研，直接移植代码需另行确认分发方式与许可义务；牌面、音乐另有资源包 |
| [grantjenks/free-python-games](https://github.com/grantjenks/free-python-games) | Python／Turtle 教学小游戏；README 包含 Cannon、Pong、Flappy 等及重复于现有目录的若干玩法 | 轻量物理、双拍弹球、抛射命中和单键避障 | [官方文档](https://grantjenks.com/docs/freegames/)声明 Apache-2.0；Python 代码需要重新适配 ArkTS，不能直接当原生组件使用 |

补充参考：[duqian42707/Sokoban](https://github.com/duqian42707/Sokoban)的手机推箱子实现，及 [x-sheep/puzzles-unreleased](https://github.com/x-sheep/puzzles-unreleased)中的 Boats 等扩展。后者明确称其内容为未完成贡献，适合作为后续题型线索，不能默认具备完整发行质量。

## 建议优先的 12 款

成本同时包含玩法、原生触屏交互、难度、存档与测试；“中”不代表只需要换一个现有棋盘皮肤。

| 游戏 | 新增体验 | 主要参考 | 实现成本 | 美术与核心验收点 |
| --- | --- | --- | --- | --- |
| 推箱子 | 空间规划、不可逆移动与关卡推进 | [Sokoban](https://github.com/duqian42707/Sokoban) | 中高 | 自绘人物、箱子和仓库；自己生成／设计关卡，检查死锁、撤销及可解性 |
| 连连看 | 可见牌面的连线路径消除，与记忆翻牌不同 | [Shisen-Sho 规则](https://pysolfc.sourceforge.io/doc/rules/shisensho.html) | 中 | 原创图案牌；校验最多三段直线的连接、边界绕行、无解检测和洗牌 |
| 经典纸牌接龙 | Klondike 牌堆整理 | [Solitairey](https://github.com/foss-card-games/Solitairey) | 中高 | 自绘通用扑克牌；拖动／点选、发牌、撤销、自动收牌和窄屏可读性 |
| 空当接龙 | 使用空位搬运牌组的策略 | [Solitairey](https://github.com/foss-card-games/Solitairey) | 中高 | 复用同一套原创牌面；严格计算可搬运张数，不把一整叠当作任意可移动 |
| 蜘蛛纸牌 | 整理同花连续牌组 | [Solitairey](https://github.com/foss-card-games/Solitairey) | 高 | 优先单花色，再扩展双色／四色；验证发牌限制、整组收牌和十列布局 |
| 泡泡射击 | 瞄准、反弹和连色消除 | [GameHub](https://github.com/SinceraXY/GameHub) | 中高 | 自绘有符号的彩球与发射器；验证吸附、悬空球掉落和反弹碰撞 |
| 双拍弹球 | 两侧挡板对抗，与现有打砖块不同 | [Free Python Games](https://github.com/grantjenks/free-python-games) | 中 | 自绘球场和球拍；单人电脑对手应具有不同反应延迟、速度上限和误差 |
| 方块叠塔 | 把横移平台准确叠放 | [GameHub](https://github.com/SinceraXY/GameHub) | 中 | 自绘几何塔；用交叠面积裁切平台，调节移动速度与宽度，不只累加点击分 |
| 桥梁连接 | 按岛屿数字连接全图 | [Bridges](https://www.chiark.greenend.org.uk/~sgtatham/puzzles/) | 中高 | 岛屿与桥线即可；连通性、桥数、不可交叉，以及生成题目的唯一性／合理难度 |
| 管线连接 | 旋转管件连接网络 | [Net](https://www.chiark.greenend.org.uk/~sgtatham/puzzles/) | 中 | 几何管件加通电反馈；可反向生成，检查全连通、边界和预定的无环规则 |
| 灯泡照明 | 摆放灯泡照亮空格 | [Light Up](https://www.chiark.greenend.org.uk/~sgtatham/puzzles/) | 中高 | 灯泡、墙与光路；遮挡、数字墙约束及灯泡互照；与当前十字熄灯是不同规则 |
| 解开交叉线 | 拖动节点，消除线段交叉 | [Untangle](https://www.chiark.greenend.org.uk/~sgtatham/puzzles/) | 中 | 节点和连线即可；线段相交判断、共享端点、拖动热区及可解布局 |

这 12 款全部落地后将从 33 款扩充到 45 款。建议新增“纸牌接龙”分类；必要时把“反应节奏”与“动作／体育”进一步拆分，避免把玩法差异都塞进“休闲”。

## 其余 24 款候选

以下中文名是为本项目拟定的描述性工作名，不代表沿用参考软件的品牌或本地化名称。

| 游戏 | 核心玩法 | 参考与实现关注点 |
| --- | --- | --- |
| 矩形分区 | 按数字面积把棋盘划成矩形 | [Rectangles](https://www.chiark.greenend.org.uk/~sgtatham/puzzles/)；矩形覆盖不重叠，生成器与求解器 |
| 帐篷与树 | 在树旁安排帐篷，满足行列数量 | [Tents](https://www.chiark.greenend.org.uk/~sgtatham/puzzles/)；配对关系和相邻约束 |
| 数字围环 | 根据每格数字画出一条闭环 | [Loopy](https://www.chiark.greenend.org.uk/~sgtatham/puzzles/)；手指选边、唯一闭环与错误标注 |
| 黑白平衡 | 填黑白格，避免三连并满足数量约束 | [Unruly](https://www.chiark.greenend.org.uk/~sgtatham/puzzles/)；不能仅换成不同颜色的数独 |
| 不等号填数 | 行列不重复，同时满足大小关系 | [Unequal](https://www.chiark.greenend.org.uk/~sgtatham/puzzles/)；大小关系与逻辑难度分级 |
| 高楼视野 | 用周围可见楼数推理高度 | [Towers](https://www.chiark.greenend.org.uk/~sgtatham/puzzles/)；数字格可玩，不必先做 3D |
| 多米诺配对 | 把数字矩形分成完整的一套骨牌 | [Dominosa](https://www.chiark.greenend.org.uk/~sgtatham/puzzles/)；牌对唯一性和划分覆盖 |
| 对称星域 | 把网格分成围绕指定点旋转对称的区域 | [Galaxies](https://www.chiark.greenend.org.uk/~sgtatham/puzzles/)；对称及区域连通性 |
| 箭头数链 | 沿箭头方向串起数字序列 | [Signpost](https://www.chiark.greenend.org.uk/~sgtatham/puzzles/)；路径覆盖和数字约束 |
| 磁极布局 | 按行列线索摆放磁铁正负极 | [Magnets](https://www.chiark.greenend.org.uk/~sgtatham/puzzles/)；相邻同极禁放与数量约束 |
| 地图着色 | 邻接区域使用不同颜色 | [Map](https://www.chiark.greenend.org.uk/~sgtatham/puzzles/)；颜色同时配符号，适配色觉差异 |
| 斜线迷阵 | 按节点数字连接斜线并避免回路 | [Slant](https://www.chiark.greenend.org.uk/~sgtatham/puzzles/)；点线约束与回路检测 |
| 连片消除 | 点击相邻同色块，消除后重力下落 | [Same Game](https://www.chiark.greenend.org.uk/~sgtatham/puzzles/)；与现有交换式三消不同，需验证剩余孤块 |
| 金字塔纸牌 | 移除可用牌中合计指定点数的配对 | [Solitairey](https://github.com/foss-card-games/Solitairey)；覆盖关系与发牌规则 |
| 高尔夫接龙 | 把相邻点数的牌接到废牌堆 | [Solitairey](https://github.com/foss-card-games/Solitairey)；边界点数能否循环须明确 |
| 三峰纸牌 | 拆除三峰布局中的连续点数牌 | [Solitairey](https://github.com/foss-card-games/Solitairey)；遮挡解锁关系 |
| 抛物线命中 | 调整发射方向，击中移动目标 | [Cannon](https://grantjenks.com/docs/freegames/cannon.html)；重力、碰撞、触摸瞄准 |
| 节奏点击 | 按节拍点中目标格 | [GameHub](https://github.com/SinceraXY/GameHub)；时间窗口、后台暂停，使用自制或明确授权的声音 |
| 单键飞行避障 | 点击维持高度，穿越障碍 | [Free Python Games](https://github.com/grantjenks/free-python-games)；原创角色与场景，重新设计视觉，不照搬特定成品的组合外观 |
| 射箭靶场 | 控制角度／力度射中目标 | [GameHub](https://github.com/SinceraXY/GameHub)；自绘弓箭与靶，验证命中和风力反馈 |
| 过路避障 | 把握空档逐步穿越移动障碍 | [GameHub](https://github.com/SinceraXY/GameHub)；自拟主题与名称，避免沿用现有商业品牌 |
| 图片拼合 | 拖放碎片复原画面 | [GameHub](https://github.com/SinceraXY/GameHub)；与滑动拼图不同，使用自产图像或几何图案 |
| 找不同 | 在成对图像中找出变化 | [GameHub](https://github.com/SinceraXY/GameHub)；优先程序生成场景，检查差异确实可见且可点击 |
| 舰队定位 | 根据行列线索推断隐藏船只位置 | [Boats](https://github.com/x-sheep/puzzles-unreleased)；单人逻辑题型，参考实现处于未完成扩展库中，作为后备研究 |

计数核对：优先 12 款 + 后备 24 款 = 36 款候选。纸牌花色／发牌变体未额外计数；双人模式、AI 难度也不当作新游戏数。

## 去重与暂缓项

- 已有数独、扫雷、2048、滑动拼图、熄灯、色块归一、数字绘格、跳子独留、三消、顺序记忆等，不因换英文名、换主题或参数就重新计为新增。
- 棋类 AI 是当前井字棋、五子棋、翻转棋、落子四连的功能补齐，不计入本报告 36 款。建议独立安排：井字棋完整搜索；其余棋类根据规则实现受预算约束的搜索，并通过对局测试区分强度，不能只更改难度标签。
- 大量“100／150 款”展示仓库适合作为灵感索引。本次不根据 README 的数量就认定每款完整可用，也不把知名商业游戏名称、角色或画面列为可直接移植资产。
- 纯掷骰子、点击计数器、同一算术题的不同包装，暂不作为优先扩充项。当前更需要增加真正不同的操作体验。

## 素材和许可落实方式

1. 本轮优先借鉴玩法与架构，继续独立编写 ArkTS 规则、交互、美术与说明。若实际引用 MIT／BSD／Apache 代码，应逐文件确认适用许可、保留要求的版权与许可证信息；不得把参考代码改写后宣称完全原创。
2. GPL 项目可以作为研究对象；是否直接集成，应在确定应用分发方案后评估许可条件。本报告不批准直接并入 GPL 源码。
3. 逐项记录代码、图片、字体、声音与关卡来源。仓库根许可证不能证明每个第三方资产都有可用授权；尤其不要提取 sgtpuzzles APK 中被作者明确排除的额外美术。
4. 建议先统一制作自有扑克牌、木质／扁平棋盘、彩球、按钮与背景这几套素材。逻辑谜题可沿用几何风格，推箱子、射箭、飞行类分别配置专属角色／场景，避免再次只有入口图标而游戏内全部是数字格。

以上涉及许可的判断仅基于本次读到的仓库声明和作者说明；没有做逐素材权属审计。优先级、成本与素材方案均为面向本工程的开发建议。
