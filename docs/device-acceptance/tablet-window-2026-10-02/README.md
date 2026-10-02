# WEB-W00 平板窗口实测

日期：2026-10-02。通过 HDC 的真实界面输入、系统窗口操作、截图和 ArkUI 布局树检查。没有注入游戏状态或替换随机棋盘。

设备型号 WEB-W00，设备接口报告 OpenHarmony 7.0.0.105、API 26。屏幕横向 2880 × 1920 px、纵向 1920 × 2880 px；系统设置界面显示 HarmonyOS 7.0.0.109 SP6，两种版本来源分别保留。候选为 API 24 Debug 签名包，构建、桌面逻辑与设备渲染分别验证。

## 发现与修复

| 问题 | 实测证据 | 修复 |
| --- | --- | --- |
| 打地鼠按整个宽屏分配洞位，横屏只有前两排部分可见，第三排超出屏幕 | [横屏旧界面](landscape-full-whackmole.jpeg) | 九洞棋盘按实际剩余宽、高共同计算，并限制最大宽度 |
| 精选页内容短于高窗口时，整个 Scroll 被 TabContent 居中，顶部出现大片空白 | [修复前竖屏](portrait-home.jpeg)、[修复后](portrait-home-fixed-v2.jpeg) | Scroll 填满 TabContent，并把内容对齐顶部；仅设置 align 不足以消除 Scroll 自身的居中 |
| 贪吃蛇方向键与棋盘重叠；华容道棋盘底部及出口被裁切；记忆翻牌底排被裁切 | [等分窗口汇总 1](portrait-split-sheet-1.jpeg)、[汇总 2](portrait-split-sheet-2.jpeg) | 读取已扣除标题、指标和操作区的棋盘容器宽高，按行列数约束格子／卡片大小 |
| 继续缩小分屏高度后，扫雷、数独、滑动拼图、消消乐及打砖块的游戏区域被裁切 | [矮窗口修复前](portrait-split-short-sheet-1.jpeg)、[修复后 1](portrait-split-short-fixed-sheet-1.jpeg)、[修复后 2](portrait-split-short-fixed-sheet-2.jpeg) | 棋盘同时受宽高限制；打砖块按同一比例显示砖块、小球和挡板，拖动距离换算回游戏坐标 |

修改只涉及布局和输入坐标换算，游戏规则及物理场地尺寸保留。滑动拼图与翻牌的难度切换使用当前棋盘区域，避免切换难度后恢复为整屏宽度。

## 覆盖与证据

| 批次 | 实际覆盖 | 结论范围 |
| --- | --- | --- |
| landscape-full | 33 款横屏入口及返回，6 张汇总图 | 33/33 入口返回通过；视觉检查发现打地鼠裁切 |
| portrait-full | 33 款竖屏入口及返回，6 张汇总图 | 33/33 入口返回通过；打地鼠九洞完整，精选页空白另行修复 |
| portrait-split | 13 款选定游戏，上下等分窗口，应用矩形 1920 × 1432 px | 入口返回通过；视觉检查发现贪吃蛇、华容道、翻牌适配问题 |
| portrait-split-short | 5 款选定游戏，应用矩形 1920 × 955 px | 入口返回通过；视觉检查发现上述 5 款游戏裁切 |
| portrait-split-short-fixed | 新包下 11 款选定游戏，应用矩形 1920 × 955 px | 入口返回 11/11，已复核完整棋盘及操作区 |

以上“入口返回通过”只表示实际进入页面并完成返回，不等同于完整玩法通关。修复包没有重新执行全部横竖屏 66 个入口；后续复测按修改页和交互范围记录。

真实交互的详细结果在 [progress.json](progress.json) 的 `interaction` 组；截图包括：

- [扫雷最后一格插旗](short-minesweeper-last-cell-flag.jpeg)：81 个格子均完整可见，最后一格长按后插旗数为 1/10。
- [困难翻牌最后一张](short-memory-hard-last-card.jpeg)：24 张卡牌均完整可见，最后一张实际翻开。
- [滑动拼图有效移动](short-slide-move.jpeg)：16 个格子均完整可见，合法移动后步数为 1。
- [矮窗口退出确认](short-exit-confirm.jpeg)：说明及两个按钮完整显示，点击“继续对局”保留当前棋盘。
- [分屏恢复全屏后的拼图](portrait-slide-state.jpeg)：恢复全屏后棋盘数值顺序保持一致。

待补充：当前已移动 1 步的拼图正在等待用户解锁并转回横屏，以核对真实旋转后的棋盘与步数。该项尚未计为通过；结算及打砖块缩放拖动的补充检查也未计为通过。

## 候选身份

各批次的包 SHA-256 在 [actions.jsonl](actions.jsonl) 和 progress 中单独记录，不将多个包合并宣称为同一包的完整发布验收。

| SHA-256 | 用途 |
| --- | --- |
| `5B340F4AED371FDA4E50FBC8F180F468B785FC7D5B927AFE9537055BE7AAA93B` | 初始横屏 33 款与缺陷复现 |
| `2C7CEE973A4413E20793FD2CAD0D9D7F24B6C3288B68852AB5ED94F207DF7D1D` | 打地鼠修复及竖屏 33 款检查 |
| `DD152E03A03452922C5F561CE41AD794A8DDAD735B67E89B1B03B99E732C3916` | 精选页首次仅 align 调整与悬浮窗检查；顶部空白仍存在 |
| `FB107F5B926C60BA6178BB17C501AE46EF74AFC2A4F98E1AEA960C837826FF77` | 精选页填满 TabContent 修复；分屏缺陷复现 |
| `DA75C39A7BFD4ED4930ED72D3F8F44F79B239D1AAA37F57224F39EFFDB8294E6` | 游戏区域宽高约束修复、矮分屏复测及真实交互 |

桌面检查 350/350：性能及设置 159、合集 82、接续 72、华容道界面状态 3、生成与难度 26、窗口尺寸 8；最终 API 24 assembleHap 构建通过。故障历史按应用名查询返回“no records found”，详见 [fault-list.txt](fault-list.txt)；这不替代长局性能验收。

## 范围限制与复现

本轮为单台平板、中文、当前系统字体、Debug 包的窗口适配验收；完整随机局通关、英文及最大字体、长局性能／耗电、折叠与真实跨设备接续、Release 包没有执行。非常矮的分屏会缩小棋盘，应结合可读性选择窗口大小。

公开截图只保留被测应用窗口；系统桌面、分屏另一侧及个人设置截图留在被 Git 忽略的构建目录。布局树坐标仍为屏幕坐标，悬浮窗截图原点为应用窗口左上角。

设备检查脚本为 `scripts/device-tablet-window.cjs`，通过 `LITTLEGAMES_TABLET_TARGET` 指定设备；HDC、Python 路径可用 `LITTLEGAMES_HDC`、`LITTLEGAMES_PYTHON` 覆盖。先构建和安装所记录的包，再运行 `node scripts/device-tablet-window.cjs smoke <批次名> <可选英文游戏ID列表>`。检查过程中不要重新构建，否则本机 HAP 身份与已安装包可能不一致。窗口切换和真实旋转需通过系统菜单／实际设备完成。汇总图由 `scripts/tablet-contact-sheets.py` 生成；窗口计算回归为 `node scripts/test-window-sizing.cjs`。

补充交互脚本为 `scripts/device-tablet-interactions.cjs`，参数 `rotation`、`brick`、`result`；旋转检查需要先保留当前棋盘数值基准文件。各检查通过后才写入 interaction 组。
