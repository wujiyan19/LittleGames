# HarmonyOS API 24 → API 26 升级评估

> 此文保留升级前评估快照。工程配置、实际构建结果和待验收项见[升级实施记录](api26-upgrade-implementation-2026-10-18.md)。

日期：2026-10-18（Asia/Shanghai）。对象：LittleGames 当前工作区，包含已有未提交改动。本轮仅新增评估文档，未修改工程配置、业务代码、SDK 安装或手机应用。

## 结论

**技术上适合升级，建议分两步将编译与目标版本升级到 `26.0.0`，最低兼容版本继续保持 `6.1.1(24)`。整体暂评为中等风险：业务模型迁移压力较低，工具链与 UI 行为验证是主要工作。**

这不是“换三个版本号即可交付”。本机尚无 API 26 配套工具链，本轮没有执行 API 26 编译、API Change Assistant 扫描或新旧系统运行验证。因此，尚不能承诺无需修改源码，也没有确认升级后的性能收益。

华为官方的升级指导明确对应 HarmonyOS 7.0 / API `26.0.0`，要求评估废弃接口与行为变化，并在新老系统设备上验证。API 26 已有 Release 配套工具，不必采用 Beta。[官方升级指导](https://developer.huawei.com/consumer/cn/doc/doccenter-release-notes/upgrade-adaptation)、[DevEco Studio 配套关系](https://developer.huawei.com/consumer/en/doc/harmonyos-releases/deveco-studio-new-features-2600)。

## 当前工程与环境

以下为本轮直接读取或扫描结果，不沿用历史构建通过结论。

| 项目 | 当前情况 | 对迁移的含义 |
| --- | --- | --- |
| compile / target / compatible SDK | `build-profile.json5:22-24` 均为 `6.1.1(24)` | 必须区分编译、目标行为和最低安装门槛 |
| DevEco Studio | 本机 `product-info.json` 为 `6.1.1.300` | 先准备与 API 26 配套的工具链 |
| 实际内置 SDK | `sdk/default/sdk-pkg.json`、OpenHarmony ETS 与 HMS ETS 元数据均为 API 24、`6.1.1.125 Release` | 当前默认 SDK 不能直接验证 API 26 |
| 开发态版本 | `oh-package.json5`、`hvigor/hvigor-config.json5` 的 modelVersion 均为 `6.1.1` | 随新版工具迁移，官方 API 26 配套表列出 modelVersion `26.0.0` |
| 应用结构 | 单 entry 模块，Stage 模型，phone / tablet | 无多模块 HSP 迁移负担 |
| UI | 131 个 ETS 文件；50 处 `@ComponentV2`，无 `@Component`；Navigation + NavDestination | 已采用 V2，不需要为了升级整体重写状态管理 |
| 依赖 | 根与 entry 的运行时 dependencies 为空；entry 测试依赖 Hypium；Node 工具依赖 hypium-driver | 官方 API 为主；测试驱动仍需核对新版工具兼容性 |
| 权限 | 当前 module 仅声明 VIBRATE | 不因 SDK 升级新增权限；保留 LAN 源文件不等于当前产品开放联网 |
| 数据 | Preferences `little_games_data`；包含成绩、游玩时长、历史、设置、2048 / 数独存档 | 升级 SDK 本身没有提出变更数据结构的需求，但必须验证覆盖安装保留数据 |

`local.properties` 另有 OpenHarmony sdk.dir，不能只改该路径就认定 HarmonyOS SDK 已切换；应以实际构建工具、SDK 元数据和产物配置为准。

## 推荐的版本策略

| 阶段 | compileSdkVersion | targetSdkVersion | compatibleSdkVersion | 目的 |
| --- | --- | --- | --- | --- |
| 当前 | `6.1.1(24)` | `6.1.1(24)` | `6.1.1(24)` | 保留可回退基线 |
| A：工具链验证 | `26.0.0` | `6.1.1(24)` | `6.1.1(24)` | 先识别新版编译器、资源与构建工具问题 |
| B：完成目标适配 | `26.0.0` | `26.0.0` | `6.1.1(24)` | 启用新版目标行为，同时继续支持 API 24 设备 |

API 26 的官方配置值采用 `26.0.0`，不要照旧版本格式自行写成 `26.0.0(26)`。上述是计划配置，尚未应用或构建验证。

保留 compatible=24 允许兼容旧系统，但不自动保证兼容：将来使用 API 26 新接口时，仍需按官方指导增加版本判断和旧系统路径。target=24 也不能屏蔽所有系统变化，例如图片超大尺寸解码变化属于所有应用生效项。[工程配置说明](https://developer.huawei.com/consumer/cn/doc/doccenter-deveco-studio/ide-hmos-hvigor-build-profile-app)、[官方升级指导](https://developer.huawei.com/consumer/cn/doc/doccenter-release-notes/upgrade-adaptation)。

不建议将 compatible 同时提高到 `26.0.0`：这会让低于该版本的设备无法安装，而当前玩法没有显示出必须放弃 API 24 的需求。

## 已确认的行为变化与代码对应

### 1. 阴影半径：存在具体代码命中

API 26 的 target 隔离行为为：`ShadowOptions.radius=0` 从“无阴影”变为“无模糊的阴影”；负数变为无阴影。若要保持原先无阴影语义，官方建议从 0 改为 -1。[Beta1 所有应用变更](https://developer.huawei.com/consumer/cn/doc/doccenter-release-notes/changelogs-for-all-apps-7001)。

工程 `DesignTokens.ets:131-133` 的 card / button 为 radius=0，float 为 radius=8。`GuessNumberPage.ets:80-84` 在输入完成时返回 ShadowTokens.button，随后在第 248 行调用 shadow，因此 button 存在真实使用路径。card 当前未检索到使用路径。

建议迁移时明确无阴影令牌的语义，必要时移除该调用或改为负半径；不要批量调整 radius=8 的浮层。当前 button 的偏移也是 0，因此不能仅凭规则变化断言已经出现可见重影，应检查猜数字提交状态的浅 / 深色画面。

### 2. 系统确认框、Toast 与文本：高优先级验证

target≥26.0.0 后，系统 Dialog、Toast 等默认开启沉浸式材质；主动设置背景、模糊、阴影或边框会影响默认生效。部分内置文本的换行与行高也变化，且取决于系统语言。[UX 行为变化](https://developer.huawei.com/consumer/cn/doc/doccenter-release-notes/changelogs-ux-7001)。

工程实际命中：

- `GameSettingsPanel.ets:35`：重开、新局、难度变更确认框。
- `SettingsPage.ets:55/74`：清除数据等确认框；第 37 行有 Toast。
- `Index.ets:86`：接续成功 / 失败 Toast。
- `SettingsVolumeRow.ets:23`：Slider，包含提示文本。

验证焦点为文字对比度、长文本、大字号、按钮与取消行为、浅 / 深色和低 / 高算力设备上的实际效果。系统材质变化可能带来视觉收益，不能据此承诺更低功耗或更高帧率。

### 3. 自绘结算框与 HDS：需要区分两条路径

`GameResultDialog`、`ExitConfirmDialog` 是 `@ComponentV2` 自绘遮罩与卡片；它们不是系统 CustomDialog。前者明确使用不透明背景，不能将“系统 Dialog 默认变为新材质”直接套用于这些组件。

首页现有 `ImmersiveLight.ets` 使用 `@kit.UIDesignKit` 的 hdsMaterial，`Index.ets:229/270` 使用 HdsTabs 底部浮动栏。它并非 API 26 新增的普通组件 uiMaterial 路线。

正式版新增的普通组件沉浸光感范围约束主要针对 API 26 Beta 新接口：除指定弹窗、Slider / Toggle / Select 等外，其他组件通常需要放在标题栏或底部 TabBar 才能生效。因此不能为升级而给全页 Column、棋盘或自绘结算卡片直接添加新材质，也不能据此断言现有 HDS 失效。[Release 所有应用变更](https://developer.huawei.com/consumer/cn/doc/doccenter-release-notes/changelogs-for-all-apps-7003)。

### 4. 图片与热区：本工程当前风险较低

Image.autoResize 的正式版变化只针对解码像素数超过 5000 万的图片。本轮检查打包资源中的 6 个 PNG：5 个为 1024×1024，1 个为 256×256；其余图片资源主要是 SVG，未发现网络图片加载链路。因此该变更暂不构成已确认的主要阻断，不应给所有图片批量加 autoResize(false)。[Release 所有应用变更](https://developer.huawei.com/consumer/cn/doc/doccenter-release-notes/changelogs-for-all-apps-7003)。

28vp→32vp 的默认最小热区变化针对 SMALL Button、Button 型 Toggle、Select、Chip / ChipGroup。当前未检索到这些用法；SettingsSwitchRow 使用的是 Switch 型 Toggle，分类页 CategoryChip 是自定义 Builder，不能因名字含 Chip 就算命中。[UX 行为变化](https://developer.huawei.com/consumer/cn/doc/doccenter-release-notes/changelogs-ux-7001)。

### 5. 暂未命中的行为项与未完成的扫描

对官方汇总列出的 NodeAdapter、LayoutPolicy.matchParent、WithTheme、queryNavDestinationInfo / onResult、ReusableV2、EmbeddedComponent、JSVM、ConvertXML、网络流量统计和新增国际化格式化接口等进行了定向源码搜索，未发现直接使用。[官方行为变更汇总](https://developer.huawei.com/consumer/cn/doc/doccenter-release-notes/changelogs-overview-pre)。

这只是静态筛查，不是全量 API 差异证明。须在新版 DevEco Studio 的 Tools → API Change Assistant 对 API 24 至 26.0.0 扫描并导出结果，再确认接口删除、废弃、签名与其他行为变化。

Preferences、SoundPool、displaySync、TaskPool、振动与 UIAbility 生命周期仍列入运行回归；本轮没有取得它们在新版 SDK 下完全兼容的编译证据。

## 实施与验收建议

1. 保留当前 API 24 工具和候选包，先建立隔离的迁移基线。工作区已有未提交改动，尤其 build-profile 包含本机配置，迁移不能覆盖或误提交本机签名信息。
2. 准备官方 26.0.0 Release 配套 DevEco / SDK / Hvigor / Node / ohpm；若使用独立 Command Line Tools，也与 IDE 对齐。现有测试脚本硬编码了 DevEco 的 TypeScript 与 hdc 路径，安装目录改变时一并调整。
3. 迁移 modelVersion 等工程开发态配置，按阶段 A 做全量编译，记录实际 SDK、编译错误与告警；运行 API Change Assistant。
4. 处理实际命中的问题，再按阶段 B 提高 target，保留 compatible=24。按当前范围预计是局部适配，无依据进行页面或游戏模型整体重写。
5. 使用新工具链运行现有 `scripts/run-regressions.cjs`。重点覆盖 continuation、local-game-saves、data-recovery、game-settings、game-sounds、window-sizing；这些是桌面逻辑证据，不能替代 ArkTS 编译和设备画面。
6. 在 API 24 与 26.0.0 系统分别验证同一候选包：启动 / 导航 / 退出、设置半模态与确认框、猜数字按钮、首页 HDS、结算遮罩、触控、后台恢复、音频、振动、主题、大字号和小窗口。平板 / 折叠场景关注半模态可用高度与底部操作区。缺少真机时可评估 AGC 云调试，模拟器证据单独标记。
7. 对旧包先写入成绩、设置、历史与 2048 / 数独进度，再使用同一合法签名身份与适当 versionCode 的候选包覆盖安装，确认保留和后续写入；不要通过卸载重装测试“升级保留数据”。
8. 按当前 89 款可用游戏目录检查入口、图标与棋盘；延续每款三次结算验收时，将新包与旧包证据分开统计。原 API 24 包的记录不能直接证明 API 26 候选包通过。发布前还需 Release 构建与相应验证。

## 收益、成本与决策

| 方面 | 评估 |
| --- | --- |
| 长期维护 | 正向：跟进 HarmonyOS 7 配套 SDK、检查工具和后续 API 能力 |
| 立即可见收益 | 主要可能来自系统弹窗材质与工具改进；现有 HDS 已有原生材质，游戏规则不会因版本号变化而增强 |
| 性能 / 包体 | 未测量，不能承诺自动改善；不要把升级与新增重材质合并成一次改动 |
| 代码成本 | 暂估低到中；已有 V2、单模块、无三方运行时依赖有利，首次 API 26 编译后才能收敛范围 |
| 验证成本 | 中到高，来自 89 款玩法及新旧系统、主题、数据保留、音频与生命周期；高于单纯改配置的成本 |
| 排期粗估 | 在工具可下载、设备可用且无重大编译阻断的前提下，环境与局部适配约 0.5–1.5 人日，关键场景的新旧系统回归约 1–2 人日起；89 款完整三结算、长局性能和上架专项另计。不是已验证工期 |

建议现在开展隔离迁移并保持最低 API 24；若当前版本已接近提交审核，应先保留现有候选包，待 API 26 的构建与双版本回归完成后再替换。升级 SDK 本身不构成上架批准、激励资格或完整设备验收。

## 本轮验证边界

- 已完成：项目规范 / 配置 / 依赖读取，本机 IDE 与 SDK 元数据核对，131 个 ETS 的定向扫描，PNG 像素检查，官方升级指导和 Beta1 / Release 行为文档正文读取。
- 本轮未运行：API Change Assistant、原生构建、桌面回归、手机安装、性能 / 音频 / 接续实测。历史 API 24 报告没有作为 API 26 通过证据。
- 本轮仅新增此文档，保留工作区原有修改；未安装软件、升级系统或调整项目 SDK。
