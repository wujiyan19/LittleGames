# 第 47—61 款游戏静态视觉复核

复核日期：2026-10-09。设备：`FMR0224521016052`，原始截图 `1260 × 2720`，浅色竖屏。安装包 SHA256：`e14b33644f6a0f72964c96e56f0a692c70680db11437152601f9a241e4911757`，与本轮 `catalog.json` 一致。

本次查看了本轮 `visual-06` 至 `visual-08` 联系表，以及下面 15 款游戏各自的原始首屏 JPEG 和原生布局 JSON。没有操作手机，没有修改应用或测试脚本。结论仅覆盖首屏标题、图案、按钮、版面和图标风格；不把截图当作位置更新、动效、触控、撤销或胜负验收结果。

总体上，15 款标题均完整可读，返回和设置入口位置一致；原生蓝色控件、浅灰背景、浅蓝棋盘及圆角卡片形成统一外壳。没有从这些首屏确认固定浮层遮挡。房间塔防和乘客上车的底部内容在截图中截短，但原生树明确将它们放在可滚动的 `Scroll` 内，需区分视口裁切与固定遮挡。

## 图标与首屏对照

![本轮视觉联系表 06，第47—48款位于底行右侧](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/visual-06.png)

![本轮视觉联系表 07，第49—56款](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/visual-07.png)

![本轮视觉联系表 08，第57—61款](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/visual-08.png)

## 逐款观察

| 序号 | 游戏与首屏证据 | 静态健康度 | 可操作区域、图案和风格观察 |
|---|---|---|---|
| 47 | [找不同 / differences](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-differences-page.jpeg) | 良好，细小目标待触控核验 | 两幅图的标题、进度及失误清楚，两组 5×5 图案完整。房屋、树木、花朵与入口图标的浅暖色插画一致。每个图案原生按钮约 `103 × 97px`，小于本组其他棋盘块；图案可辨，但误触率需实际连续点击检验。 |
| 48 | [房间塔防 / roomdefense](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-roomdefense-page.jpeg) | 首屏内容清楚，底部滚动待操作 | 标题、进度、门、开始按钮、金币及房门数值清楚。首屏只出现门，与“点击开始”准备态相符，不能判定敌人或炮塔丢失。下排炮塔按钮尾部被 Scroll 视口裁切；见下文尺寸证据。 |
| 49 | [篮球投篮 / basketball](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-basketball-page.jpeg) | 良好，准备态 | 篮筐和投篮区域完整，开始入口醒目；篮筐虽相对整块场地较小，轮廓仍可辨。篮球图标与场内篮筐使用一致的珊瑚红、浅蓝及柔和插画线条。该准备态截图没有球，不能据此判定球未生成。 |
| 50 | [经典纸牌 / solitaire](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-solitaire-page.jpeg) | 可读，材质细节可继续统一 | 牌库、归位、四个基础槽、七列牌和撤销都完整；牌面点数与红黑花色可辨。入口是带阴影的插画纸牌，正文牌面是较素的白色薄边框，材质表现有所简化，但纸牌语义相符，未见“图标与玩法完全不同”的巨大差异。 |
| 51 | [汉字拆组 / characters](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-characters-page.jpeg) | 良好 | 目标汉字、六个部件、清空和检查组合都可读，触区宽裕。正文以文字为主，入口笔和木盒属于内容题材提示；不要求汉字按钮复刻笔的造型。正文留白较多，但信息关系明确。 |
| 52 | [节奏落键 / rhythm](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-rhythm-page.jpeg) | 良好，准备态 | 进度、判定线、开始及四轨按钮完整；轨道分隔较淡，判定线突出。入口音符题材正确。空轨道属于开始前截图，落键尺寸、下落与击中反馈需开始后核验。 |
| 53 | [迷你餐厅 / restaurant](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-restaurant-page.jpeg) | 良好 | 顾客卡、订单图案、剩余秒数及三种备餐卡清楚，卡片间距足够。入口汤面与订单/备餐汤面明显沿用同一插画语言，风格衔接是本组较好的例子。秒数截图只证明文字出现，不证明倒计时持续更新。 |
| 54 | [连连看 / linktiles](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-linktiles-page.jpeg) | 良好 | 棋盘四周保留连线路径边界，36 个图案完整，重排提示与撤销分层清楚。图案同时使用不同颜色和不同形状，圆角、微高光和阴影与入口配对块一致。消除、连线及撤销待操作核验。 |
| 55 | [麻将接龙 / mahjongsolitaire](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-mahjongsolitaire-page.jpeg) | 可读，叠层辨识有轻量风险 | 牌块、提示、撤销完整，同一组图案风格与连连看一致。不可自由取出的块较淡，中部上下层重叠会出现混色；首屏能感到有叠层，但具体哪层覆盖哪层不够直观。可考虑以后加强层边缘或遮挡关系提示；截图不能证明点错层或规则错误。 |
| 56 | [点击群消 / groupclear](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-groupclear-page.jpeg) | 良好 | 6×8 棋盘、48 图案、目标分数和撤销完整；块间距与图案大小均匀。颜色加形状的双重区分清楚，图标与棋盘均体现实体圆角拼块。下落和群消计数待操作核验。 |
| 57 | [落槽配对消除 / slotpair](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-slotpair-page.jpeg) | 良好，空槽提示可再优化 | 六列空槽完整，下一块、发牌进度与六个下箭头清楚。空槽轮廓刻意较淡，按钮醒目。正文与图标都用同一套圆角图案块。开局“剩余 0”表示场上块数而旁边还有 `进度 0 / 60`，措辞可能让新玩家误读为没有待放块，属文案改进机会。 |
| 58 | [乘客上车 / buscolor](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-buscolor-page.jpeg) | 首车与队列清楚，后排较淡，底部滚动待操作 | FIFO 说明、9 个乘客、候车位、轨道与首排巴士清楚，车身样式与图标高度一致。后车降低透明度后，颜色和座位圈明显变淡，会增加预判后续车色的负担。末排被 Scroll 视口裁切，未确认固定遮挡。座位填充与发车待动作验收。 |
| 59 | [毛线收卷 / yarn](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-yarn-page.jpeg) | 良好，依赖颜色区分需另验 | 五根毛线柱、说明、三个卷轴、容量与选中框完整。毛线与入口卷轴延续紫、金、蓝等柔和色和弧线纹理；正文毛线被压成扁椭圆，仍可辨认同色层。各色层的形状相同，色觉差异用户的辨识需另行验证。 |
| 60 | [沙画吸色 / sand](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-sand-page.jpeg) | 良好，依赖颜色区分需另验 | 8×8 沙粒块、说明、四个吸管、容量和选中框完整。吸管造型与图标一致，棋盘色块使用同一浅暖色系。吸管同时有形状符号，但棋盘各颜色的点阵图形相同，仍主要依靠颜色匹配；这是一项可访问性风险，尚非已证实的触控/逻辑缺陷。 |
| 61 | [绳结解开 / untangle](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/catalog-untangle-page.jpeg) | 良好，材质比图标简化 | 7 个节点数字、交叉线、剩余交叉数和撤销完整，线不会被页头/底部固定层覆盖。正文采用纯色蓝节点与原生蓝/橙直线，入口节点有插画阴影，材质更丰富；语义一致，正文的材质可继续靠近图标。拖动跟随、线端点更新及撤销需实际操作。 |

## Scroll 裁切与固定遮挡

房间塔防和乘客上车的原生 `Scroll` 都是 `[0,318][1260,2538]`，`scrollable=true`。

- 房间塔防下排炮塔 3/4：绘制原尺寸为 `y=2450..2580`，当前可见范围仅到 `2538`。正文操作区的原始底边更低，属于纵向内容超出当前视口。JSON 提供可滚动的结构路径；本次没有滑动，因此不能写成“已验证滚动可点”。
- 乘客上车末排巴士：原尺寸为 `y=2301..2606`，当前可见底边为 `2538`；场景 Column 原始底边 `2632`。同样属于 Scroll 视口裁切。首排当前可发车按钮全部在视口内，未见固定遮罩挡住它们。
- 其余 13 款所见主棋盘和本次首屏操作按钮均完整位于视口内。这只覆盖当前状态，不推及后来牌堆增高、餐厅顾客增多或字号变大时的布局。

## 后续改进与证据边界

本组没有由截图确认的 P1 阻断问题。可在已有动作验收之后处理轻量美化：提高巴士后排车色的可辨性、加强麻将叠层边缘、统一纸牌和绳结的材质细节、明确落槽“剩余”文案。找不同的小目标、沙画/毛线/巴士的颜色区分属于需要真机或辅助能力核验的风险，不能直接据图判为无法使用。

本记录没有覆盖深色、放大字号、横屏、分屏、读屏、连续触控或动画采样，也没有确认任一游戏可完成目标。开始前空场景与初始禁用撤销均不能作为状态不更新的证据。后续动作结果应引用实际触控脚本和前后状态截图，不从本视觉记录继承“玩法通过”。
