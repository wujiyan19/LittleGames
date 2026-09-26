# LittleGames 模拟器实测与产品审查（2026-09-25）

## 修复回归记录（同日追加）

本节记录本报告提出问题后的修复结果；下方原始发现保留为修复前证据。修复包在 DevEco Studio 6.1.1 / API 24 下重新构建成功，并分别安装到手机和 Mate X7 展开态模拟器。

| 原问题 | 修复与实测结果 |
| --- | --- |
| 俄罗斯方块棋盘覆盖页头和操作区 | 棋盘按可用区域宽高共同限制，弹性容器固定为页面宽度。手机和展开态的页头、棋盘、方向键与加速下落键均清楚分离；展开态连续加速落下可触发结算。[手机](screenshots/reg-phone-tetris-fixed.jpeg) · [展开态](screenshots/reg-fold-tetris-fixed.jpeg) |
| 折叠屏 2048 提示与棋盘重叠 | 棋盘按实际弹性区域高度缩放，提示位于棋盘下方；手机与展开态均未重叠。[手机](screenshots/reg-phone-2048-fixed.jpeg) · [展开态](screenshots/reg-fold-2048-fixed.jpeg) |
| 全屏结算文字低对比 | 全屏遮罩中加入使用应用实体表面色的卡片；俄罗斯方块结算在手机和展开态实测标题、成绩、按钮清晰可读。[手机结算](screenshots/reg-phone-result-fixed.jpeg) · [展开态结算](screenshots/reg-fold-result-fixed.jpeg) |
| 最近玩过按次数排序、统计重复 | 数据层保存最近进入的游戏 ID 顺序；个人页显示俄罗斯方块、2048 的实际进入顺序，游戏总数 13 与已玩游戏 4 分开。[个人页](screenshots/reg-fold-profile.jpeg) |
| 设置切换后立即强杀可能丢失 | 设置修改与切后台改为同步刷盘；展开态切换震动反馈后立即 force-stop 并重启，开关保持关闭。[重启后](screenshots/reg-fold-setting-persist.jpeg) |
| 跳一跳后台计时器 | 切后台停止跳跃和坠落计时器，回前台稳定结算待完成动作。手机上长按起跳后立即回桌面、等待 2 秒再回应用，画面可继续且得分为 1；[恢复截图](screenshots/reg-phone-jump-resume.jpeg)。命令间延迟无法证明一定卡在空中/坠落帧，仍需精确时机专项复测。 |
| 其他棋盘窗口变化 | 贪吃蛇、扫雷、数独、滑动拼图、记忆翻牌、消消乐、华容道在页面区域变化时重算格长；极窄窗口不再被固定最小格长撑破。重新构建成功，手机首屏抽查[数独](screenshots/reg-phone-sudoku-resize.jpeg)和[记忆翻牌](screenshots/reg-phone-memory-resize.jpeg)正常。模拟器尚未完成应用运行中的实际分屏/折叠状态切换。 |
| 游戏数量测试、资源重名 | 断言改为 13 并加入最近玩过顺序测试；`app_name` 统一归入 AppScope，并补齐中英文应用名资源，构建不再出现资源冲突警告。测试任务尚未在当前工程命令行任务列表中找到，新增单测未宣称已执行。 |

**仍待处理/验证**：运行中的分屏、旋转与折叠状态切换尚未在设备上复测；既有 `getStringSync` 弃用警告仍存在；当前 HAP 未配置发布签名；本轮也未覆盖真机、暗色模式、屏幕阅读器与性能专项。以上不影响本节列出的两台模拟器上的已复测结果。

## 测试口径

- 对象：当前**未提交的工作区**，未覆盖或改写原有代码改动。
- 构建：DevEco Studio 6.1.1、HarmonyOS API 24；`assembleHap` 成功，产物为 `entry-default-unsigned.hap`（18,421,745 B）。
- 设备：API 24 手机模拟器 LittleGamesPhone，1256×2760；API 24 折叠屏 Mate X7 展开态，2210×2416。
- 交互：手机上逐一进入 13 款游戏并核对标题和首屏；实际操作了跳一跳蓄力落台、数独填数、消消乐有效交换、2048 滑动、分类搜索、系统返回确认、设置切换与重启持久化。折叠屏检查首页、分类、2048 滑动、俄罗斯方块、难度菜单，并让打地鼠完整倒计时至结算后返回。
- 本轮没有完成 13 款游戏各自的通关/失败全路径，也没有真机、平板、折叠态切换、系统暗色模式、屏幕阅读器和帧率/功耗专项测试。以下把**模拟器复现**与**代码风险**分开记录。

## 已在模拟器复现

### P1｜俄罗斯方块棋盘覆盖页头和操作区

手机与折叠屏展开态均复现。进入俄罗斯方块后，20 行棋盘从页面顶部溢出，盖住标题、比分卡，并延伸到方向键和“加速下落”区域；等待数秒后仍然如此。返回按钮虽被遮挡，点击原位置仍能弹出退出确认，说明主要是可见性和布局层级问题。证据：[手机截图](screenshots/test-tetris-later.jpeg)、[折叠屏截图](screenshots/test-fold-tetris-actual.jpeg)。

原因线索：[TetrisGamePage.ets](../entry/src/main/ets/pages/classic/TetrisGamePage.ets#L45)只按窗口**宽度**计算格长，随后以该格长固定棋盘高度为 20 格；[布局](../entry/src/main/ets/pages/classic/TetrisGamePage.ets#L123)又把棋盘放入需要与页头、统计卡和控制键分享高度的弹性区域。建议以实际剩余高度和宽度共同限制格长，并在手机及展开态回归触控和动画。

### P2｜折叠屏 2048 操作提示压在棋盘下沿

Mate X7 展开态进入 2048，底部“上下左右滑动操作”文字与棋盘下边缘重叠；滑动仍能改变棋盘。证据：[展开态截图](screenshots/test-fold-2048.jpeg)。[Game2048Page.ets](../entry/src/main/ets/pages/classic/Game2048Page.ets#L94)同样只按宽度给方形棋盘定尺寸，[棋盘容器](../entry/src/main/ets/pages/classic/Game2048Page.ets#L317)占据弹性高度。建议按内容区高度约束棋盘，并给提示留明确空间。

### P2｜全屏结算层的标题对比度不足

打地鼠倒计时归零后显示结算层，标题“时间到！”以深色文字直接叠在变暗、模糊的地鼠画面上，文字与背景混在一起；“再来一局”和“返回”仍可点击并正常返回分类页。证据：[结算截图](screenshots/test-whack-over.jpeg)。[GameResultDialog.ets](../entry/src/main/ets/components/GameResultDialog.ets#L76)全屏模式只铺 `scrim`，而[标题](../entry/src/main/ets/components/GameResultDialog.ets#L98)继续使用适用于浅色表面的 `textPrimary`。建议给内容加不透明卡片，或在全屏遮罩模式使用明确的高对比前景色；其他复用此组件的游戏一并回归。

### P2｜“最近玩过”显示的是“最常玩”

手机上刚进入消消乐、记忆翻牌等游戏后，“最近玩过”仍优先列出历史游玩次数更多的跳一跳、2048 等；顺序未体现最近进入时间。证据：[个人页截图](screenshots/test-profile-stable.jpeg)。实现中 [ProfileTab.ets](../entry/src/main/ets/pages/home/ProfileTab.ets#L55)直接调用 `getMostPlayed(5)`。应记录最近游玩时间并按时间排序，或者把标题改为“最常玩”。

### P3｜“已收录”统计与“游戏总数”完全相同

个人页两张统计卡均显示 13，且 [ProfileTab.ets](../entry/src/main/ets/pages/home/ProfileTab.ets#L189)两处均传入 `totalGames`。如果“已收录”意指用户收藏或解锁，应使用独立数据；如果只是展示应用收录量，则与相邻卡片重复，建议合并或换成已玩游戏数。

### P3｜快速强杀存在设置保存窗口

手机上将震动反馈切换后立即 `force-stop`，重启时开关回到旧状态；等待约 1 秒后强杀则保存成功，切到桌面后立即强杀也保存成功。正常切后台路径**未复现丢失**。当前 [GameData.ets](../entry/src/main/ets/model/GameData.ets#L12)使用 200 ms 防抖，`flushNow()` 发起异步 `flush()` 后不等待完成。建议把“立即结束进程”视为边界用例，明确所需的数据可靠性并补充持久化完成/失败验证。

## 代码与交付风险，尚未在本轮交互复现

| 优先级 | 问题 | 依据与建议 |
| --- | --- | --- |
| P2 | 跳一跳在空中或坠落时切后台，动画计时器可能继续推进 | [JumpJumpViewModel.ets](../entry/src/main/ets/viewmodel/JumpJumpViewModel.ets#L313)的 `onAppHidden()`只终止蓄力，跳跃/坠落计时器仅在 `dispose()`统一停止。分别在蓄力、空中、坠落时做后台恢复专项测试。 |
| P2 | 窗口尺寸变化后可能继续使用旧棋盘尺寸 | 多个页面只在 `aboutToAppear()` 调用 `ScreenUtils.calcCell()`，例如 [2048](../entry/src/main/ets/pages/classic/Game2048Page.ets#L69)。折叠/分屏变化后需重算当前页面尺寸并检查命中区域。 |
| P2 | 现有游戏数量单元测试与产品清单冲突 | [GameDataManager.test.ets](../entry/src/test/GameDataManager.test.ets#L11)两处仍断言 10，当前实际为 13；构建成功不代表测试通过。本工程任务列表没有直接暴露可运行的 `test` 任务，本轮未执行测试套件。 |
| P3 | 旧问题台账状态已过时 | [2026-09-24 台账](known-issues-2026-09-24.md)仍列 N1、B1、M1 待修；当前工作区分别已转发返回值、管理关卡延时句柄、处理消消乐死局。应更新台账，避免修复排期被旧状态误导；J2 与测试清单问题仍需处理。 |
| 发布门槛 | 当前产物未签名 | 构建提示 `No signingConfig found for product default`，输出文件为 `entry-default-unsigned.hap`。模拟器安装成功；发布或真机分发前需配置签名并做签名包验证。 |
| P3 | 构建警告待清理 | `app_name` 在 AppScope 与 entry 的 `base/element/string.json` 重复；多个 `getStringSync` 调用收到弃用警告。建议分别消除重复资源和升级 API。 |

## 通过与未发现异常的项目

- 13 款游戏均能从分类或精选页进入，没有在此路径观察到崩溃或空白页。
- 跳一跳长按约 1.2 秒后落到下一平台，得分由 0 到 1；系统返回在进行中弹出“确认退出”。证据：[落台后截图](screenshots/test-jump-after.jpeg)。
- 数独空格输入数字后显示在选中格；消消乐有效交换后得分 0→30、步数 30→29。证据：[数独操作](screenshots/test-sudoku-play.jpeg)、[消消乐首屏](screenshots/test-match3.jpeg)。
- 分类页搜索“数独”只返回对应卡片；难度菜单显示简单、普通、困难；震动开关在正常切后台后重启保持状态。
- 打地鼠从 30 秒自然倒数到 0 秒，出现“时间到！”及成绩，点击“返回”回到分类页；此流程功能正常，结算画面的可读性问题见上。
- 资源键静态核对：`base`、`zh_CN`、`en_US` 各 180 个字符串键且无缺项；`base` 与 `dark` 各 106 个颜色键且无缺项。这只证明资源完整，不代表语言和暗色页面视觉效果已全部验收。
- 折叠屏展开态首页以 4 列显示游戏卡片，首页、分类导航可用。证据：[展开态首页](screenshots/test-fold-home.jpeg)。

## 建议修复与复测顺序

1. 修复俄罗斯方块布局溢出，再复测手机和展开态的可见区域、返回键、方向键和自动下落。
2. 给 2048 棋盘加高度约束，并提高全屏结算层文字对比度。
3. 修正个人页“最近玩过”和“已收录”的产品口径。
4. 更新 13 款清单测试并补齐可执行的自动测试流程；验证跳一跳后台状态和动态窗口变化。
5. 清理构建警告、配置签名，再做暗色模式、真机、平板和性能专项验收。
