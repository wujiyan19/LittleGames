# 100 款游戏美术补全与交互反馈

2026-10-03：保留原有 33 款的对局美术，为新增 67 款补齐场景、角色、道具与棋具，重绘 67 款入口图标。已检查全部 100 个游戏入口的资源引用。

新增 261 个对局资源名，每个提供 base / dark 两套，共 522 个 SVG；另有 134 个重绘入口 SVG 与图片拼图的深色场景。全部为项目内原创矢量图形，不依赖外部字体、图片、远程下载或新运行库。浅深色调整场景和材质亮度，水果、身份色、白方棋子与母球保留辨识特征。数字、汉字、牌面文字、状态与规则由 ArkUI 显示。

| 玩法 | 补齐内容 |
| --- | --- |
| 消除与整理 | 六色图案砖、泡泡、拼块、十级水果、玻璃瓶与水层、箭头、螺丝与板材、车辆、巴士、乘客、卷轴、毛线、沙粒与吸管 |
| 动作与射击 | 跑者、机器人、小鸟、钩点、平台、柱体、敌人、战机、坦克、炮塔、弹丸、炸弹、金币与路障 |
| 体育与双人 | 球场、球门网、篮球与篮筐、足球、球杆挡板、曲棍球器具、台球、母球、保龄球与球瓶、终点旗和赛车 |
| 棋牌与纸牌 | 纸牌正反面、麻将牌材质、象棋棋具、国际象棋双方六种棋子、飞行棋场地与飞机 |
| 解谜与文字 | 仓库、箱子、目标、16 种管道连接、找不同与隐藏物品图案、小狗与蜜蜂、拼图深色场景、书本与文具材质 |
| 节奏与经营 | 音符、琴键、农田四状态、沙发、桌子、植物、台灯、三种餐品、顾客、鱼、浮标和咬钩提示 |

## 交互特效

- 棋具按压缩小、松开回弹、选中放大与描边，点击调用现有触感工具并遵循震动设置。
- 新增游戏发生实际得分时显示飘字、扩散光圈与六枚星点；失误或受伤显示短提示。
- 所有游戏的共用结算弹窗增加入场缩放、上移和淡入。新增游戏及原有明确通关的玩法显示奖杯与一次星点庆祝；失败不触发庆祝。
- 旋律琴键高亮与缩放、钓鱼咬钩放大、拔河人物位移，动作游戏沿用原有坐标与帧循环。
- 反馈只动画化 scale / translate / rotate / opacity。复杂控件采用 renderGroup；不新增常驻循环，也不通过布局属性实现反馈动画。
- 暂停、后台、退出确认、销毁和终局关闭新增反馈。重开、撤销和接续清除短暂反馈，不将特效状态写入存档。启动动画的短计时器在组件销毁时清理。

## 预览

以下是素材组合图，使用真实模型状态，**不是 ArkUI 页面截图，也不能替代设备验收**。

[浅色入口图标](expansion-icons-light.png) · [深色入口图标](expansion-icons-dark.png)

[浅色角色与道具](expansion-sprites-light.png) · [深色角色与道具](expansion-sprites-dark.png)

| 组合图批次 | 浅色 | 深色 |
| --- | --- | --- |
| 1：消除、整理、跑酷、吞噬与推箱子 | [预览](expansion-gameplay-light-1.png) | [预览](expansion-gameplay-dark-1.png) |
| 2：管道、找不同、塔防、篮球、纸牌、餐厅等 | [预览](expansion-gameplay-light-2.png) | [预览](expansion-gameplay-dark-2.png) |
| 3：整理、动作与射击 | [预览](expansion-gameplay-light-3.png) | [预览](expansion-gameplay-dark-3.png) |
| 4：生存、装备、体育与赛车 | [预览](expansion-gameplay-light-4.png) | [预览](expansion-gameplay-dark-4.png) |
| 5：双人、棋牌与解谜 | [预览](expansion-gameplay-light-5.png) | [预览](expansion-gameplay-dark-5.png) |
| 6：文字、节奏、农场、装饰与钓鱼 | [预览](expansion-gameplay-light-6.png) | [预览](expansion-gameplay-dark-6.png) |

## 维护与检查

- `scripts/generate-expansion-art.cjs`：生成两套 SVG、入口、资源选择器和清单；目录生成器会调用它，重建目录不会还原旧图标。
- `entry/src/main/ets/common/ExpansionArt.ets`：资源选择器，所有选择均引用编译期资源名。
- `GameArtTile.ets` / `ExpansionFeedback.ets`：棋具交互与临时得分反馈。`ExpansionViewModel.ets` 按实际状态变化发送反馈。
- [资源清单](expansion-art-manifest.json)记录全部 67 款与 261 个资源名；[栅格化记录](expansion-art-render-check.json)确认 658 个 SVG（两套对局、两套入口、两套拼图）全部可渲染。
- [桌面验证记录](expansion-art-tests.json)：9 个检查脚本合计 883/883 通过，包含 7 项资源及反馈专项检查，覆盖非法输入、得分、失误、撤销、重开、生命周期、终局和接续。
- DevEco / HarmonyOS 6.1.1 / API 24 的 assembleHap 构建通过。新增代码没有编译警告；工程现有 I18n 等警告保持原状。
- `hdc list targets` 返回 Empty；尚未验证设备上的实际触控、帧率、原生动画与读屏表现。

重建美术：`node scripts/generate-expansion-art.cjs`。检查资源与反馈：`node scripts/test-expansion-art.cjs`。预览需要 `sharp`，可使用 Codex 工作区自带的 Node 包路径设置 NODE_PATH 后运行 `node scripts/preview-expansion-art.cjs`。

实现对照：[华为属性动画说明](https://developer.huawei.com/consumer/cn/doc/doccenter-dev-faq/faqs-arkui-1009)、[背景图片属性](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-universal-attributes-background)，并以本机 API 24 编译结果检查接口兼容性。
