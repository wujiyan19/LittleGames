# 构建验收与来源

## 构建

先读取目标项目构建配置和说明，使用实际 SDK/API Level。LittleGames 的基线是 DevEco Studio 内置 HarmonyOS 6.1.1 / API 24；根目录没有 hvigorw，使用 `tools/hvigor/bin/hvigorw.js`。下面是该项目默认安装位置下的 PowerShell 命令，不是所有机器的硬编码要求：

```powershell
$studio = 'C:\Program Files\Huawei\DevEco Studio'
$env:DEVECO_SDK_HOME = "$studio\sdk"
$env:JAVA_HOME = "$studio\jbr"
$env:PATH = "$studio\tools\node;$studio\tools\ohpm\bin;$studio\jbr\bin;$env:PATH"
& "$studio\tools\node\node.exe" "$studio\tools\hvigor\bin\hvigorw.js" assembleHap --mode module -p product=default --no-daemon
```

在目标仓库根目录执行。输出在 `entry/build/default/outputs/default/`。Git Bash 的 node 路径参数使用 `C:/...`，不能将 `/c/...` 作为 node 脚本参数。其他工程有 wrapper 时沿用其 wrapper，不强制 DevEco 的绝对位置。

签名使用项目已有合法配置或 DevEco 本机设置。不要把机器证书、私钥、密码或签名路径复制到 skill、代码示例或共享配置。区分 unsigned 构建与具备真实安装条件的 signed 包。

## 按变更选择验证

以下是 LittleGames 已有测试入口，检查文件仍存在后按涉及职责运行，不要求每次跑所有游戏回归：

| 变更范围 | 相关现有入口（`node scripts/<name>.cjs`） |
| --- | --- |
| 原游戏规则、性能/偏好 | `test-performance`、`test-generation-logic`、对应规则审计 |
| 设置与游玩记录/时长 | `test-game-settings`、`test-play-history`、`test-play-time` |
| 经典合集与扩充玩法 | `test-collection`、`test-expansion`、`test-expansion-completion` |
| 窗口计算与接续 | `test-window-sizing`、`test-continuation` |
| LAN 状态与传输 | `test-lan-multiplayer`、`test-lan-transport` |
| 电脑对手 | `test-computer-opponents`、`test-poker-ai`、`test-chess-ai`、`test-card-ai` |
| 素材与互动反馈 | `test-expansion-art`；必要时运行对应素材渲染检查 |

桌面运行器转换 `.ets`，替代部分原生服务与时钟。它能验证业务不变量，不能证明 ArkTS 编译、原生 Socket 行为、设备画面或性能。使用仓库配置的 Node 与 TypeScript 模块；必要时按项目说明配置 `ARKTS_TYPESCRIPT_PATH`。

新增测试仅在行为或风险值得验证时编写；验证非法输入、规则边界、完整流程、竞态或协议不变量，避免仅匹配实现文本。低影响样式或文档改动不需要镜像测试。

`.ets` 修改执行原生构建。完成后检查本次 diff 及 `git diff --check`，保留已有未提交工作。旧测试/构建报告不能当成本次结果；若已有改动导致失败，说明证据与影响范围，不随意回退用户工作。

## 设备与后端验收

- 页面/组件：浅色与深色、长文本与大字号、实际触区、状态提示、原生返回、筛选/滚动位置、弹层快速双击与取消。
- 适配：本次支持设备的竖/横屏、窗口变小、分屏/悬浮窗；棋盘同时受宽高约束，底部操作和浮栏留白可用。
- 生命周期：进入、暂停、设置遮挡、后台/前台、返回确认、结束、重开、恢复。自动恢复不能解除手动暂停。
- 接续：区分序列化规则测试与真实跨设备迁移；检查路径恢复、未就绪接收、无效版本、恢复失败及实时场景先暂停。
- LAN：两台真实设备在适用 Wi-Fi/热点下握手、双方操作、重开、失联、后台断线；受控桌面传输不能替代此项。
- 云端：真实契约成功与错误、非法/缺失字段、权限、超时、重复提交、取消/旧请求、冲突和分页；记录服务环境与是否为 mock。
- 性能：只有实际测量后才报告帧率、内存、耗电等；截图只能说明采样帧的视觉状态。

只验证任务涉及的关键范围。设备不可用时交付可完成的构建和回归，并列明尚未实测项；不从未验证状态推断所有机型与功能通过。设备验收记录包身份、实际场景与截图/日志来源，测试后恢复临时修改的用户设置。

## 来源与维护

此 skill 提炼日期为 2026-10-09。项目规范、现行源码和资源是实现依据；历史截图与文档提供背景，遇到冲突先核对源码与本次用户要求。以下路径相对 LittleGames 根目录；在其他工程中不要求存在，不作为运行依赖。

| 提炼内容 | 项目依据 |
| --- | --- |
| ArkTS 严格约束与 SDK 构建 | `AGENTS.md`、`entry/oh-package.json5`、`entry/src/main/module.json5`、`build-profile.json5` 的 SDK 字段 |
| 系统语义色与设计令牌 | `entry/src/main/ets/common/DesignTokens.ets`、`entry/src/main/resources/base/element`、`entry/src/main/resources/dark/element` |
| 当前页面层级和尺寸 | `docs/ui-polish-plan-2026-10-07.md`、`docs/device-acceptance/ui-polish-2026-10-08/REPORT.md`、`entry/src/main/ets/components/HomeHeader.ets` / `GameCard.ets`、`entry/src/main/ets/pages/home/FeaturedTab.ets` |
| 截图与素材复核 | `docs/device-acceptance/ui-polish-2026-10-07/light-featured.jpeg`、`docs/art/legacy-gameplay-2026-10-08/dark.png` |
| 原生动效与防穿透 | `entry/src/main/ets/common/HarmonyMotion.ets`、`entry/src/main/ets/components/GameResultDialog.ets`、`docs/harmony-native-motion-2026-10-03.md` |
| 导航/状态/窗口 | `entry/src/main/ets/pages/Index.ets`、`entry/src/main/ets/router`、`entry/src/main/ets/viewmodel/SudokuViewModel.ets`、`entry/src/main/ets/common/ScreenUtils.ets` |
| 本地数据/生命周期 | `entry/src/main/ets/model/GameData.ets`、`entry/src/main/ets/common/GameLifecycleBus.ets`、`entry/src/main/ets/model/game/RandomSource.ets` |
| 接续 | `entry/src/main/ets/common/AppContinuation.ets` / `GameSessionTransfer.ets`、`docs/harmonyos-continuation-immersive-light.md` |
| LAN | `entry/src/main/ets/common/LanProtocol.ets` / `LanFraming.ets` / `LanTransport.ets`、`docs/lan-multiplayer.md` |
| 统一素材 | `docs/art/unified-icons.md`、`docs/art/legacy-gameplay-2026-10-08/README.md`、`scripts/game-art-palette.cjs` |

`README.md` 部分段落仍反映旧状态，例如仅有振动权限的表述；当前模块还包括 LAN 网络权限。当前最终美化包的手机验收未完成，前一版本截图不能证明最终包已验收。此 skill 不继承任何“全部通过”结论。

## 官方资料入口

以下是相关官方资料入口；每次新增/更换能力仍按目标版本核实。部分网页依赖动态加载，本轮浏览未取得完整正文，不能把入口可打开等同于已核实具体 API 签名。

- [ArkTS 官方说明](https://developer.huawei.com/consumer/en/arkts/)：语言定位与静态检查；具体约束继续核对目标编译器与 TypeScript 转 ArkTS 文档。
- [MVVM V2 官方指南（版本化资料）](https://developer.huawei.com/consumer/en/doc/harmonyos-guides-V14/arkts-mvvm-v2-V14)：Model/View/ViewModel 与 V2 状态管理；该页面不是 API 24 全量参考。
- [数据存储方案选择](https://developer.huawei.com/consumer/cn/doc/doccenter-dev-faq/faqs-local-database-management-38)：按数据类型与访问需求选择存储。
- [Preferences 指南入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/data-persistence-by-preferences)：查当前偏好存储文档，并核对本地 SDK 的 preferences 声明。
- [Network Kit 数据传输能力目录](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-v5/network-kit-data-transmission-V5)：从目录进入 HTTP、WebSocket 或 Socket 文档，选择目标 API 版本。
- [UI Design Kit 目录](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/ui-design-arkts)：核对 HDS 组件与材质定义。
- [应用接续最佳实践](https://developer.huawei.com/consumer/cn/doc/best-practices/bpta-application-continue-progess)：已有工程接续路线的官方参考，具体回调与参数需再核实。

本机官方 SDK 可从 `C:/Program Files/Huawei/DevEco Studio/sdk` 定位，示例路径仅作本机查找提示；先确认目标安装位置。网页不完整时同时查本地声明和原生构建，仍不确定的能力不要猜造。
