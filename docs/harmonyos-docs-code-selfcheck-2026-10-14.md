# HarmonyOS 官方文档学习与代码自检

日期：2026-10-14。对象：LittleGames 当前 89 款单机游戏、应用入口、导航、状态与存储服务。结论：复现并修复两类数据边界问题；修改后 26 组桌面回归共 1339/1339 项通过，HarmonyOS 6.1.1 / API 24 原生构建与签名打包成功。

本轮使用 Exa 按状态管理、生命周期与存储、并发、音频、动画、ArkTS、接续 7 个方向检索，共取得 50 条结果，另一次检索失败后重试。结果中有重复页面、目录和无正文页面，不能把结果数量当作已读文档数量。有效官方正文与本机目标 SDK 声明交叉核对；文档中心是入口，本次学习范围围绕本应用实际使用的能力，不声称已读完整个华为文档库。

## 官方资料与应用中的对应关系

| 资料 | 本轮核实的要点 | 代码检查 |
| --- | --- | --- |
| [V2 数据对象状态变量迁移](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/arkts-v1-v2-migration-inner-class) | `@ObservedV2` 与 `@Trace` 配合观察类属性与嵌套数据；装饰器与数据实例的实际观测边界需要一致 | 游戏 ViewModel 使用 V2；`ExpansionRenderPiece` 以稳定 ID 持有带 `@Trace` 的快照；合集采用整体快照替换 |
| [Preferences 持久化](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/data-persistence-by-preferences) | 默认 XML 模式中 `putSync` 修改缓存，需 `flush` 持久化；同步接口及数据规模会影响主线程 | 普通变更合并 200ms 写入；后台、设置提交和接续边界调用 `flushNow`；异步失败保留 dirty 状态 |
| [UIAbility 生命周期](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/uiability-lifecycle) | 前台与后台有明确回调，可在后台停止无用资源 | `EntryAbility` 将前后台事件连接至 `GameLifecycleBus`；游戏计时、音效、AI 和物理循环据此停止或恢复 |
| [应用退出](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/app-stop) | 异常终止不能依赖完整销毁回调；部分设备退出路径也不保证 `onDestroy` | 保存和计时结算已经放在后台与交互边界，而非仅放在销毁回调 |
| [TaskPool 简介](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/taskpool-introduction) | 并发函数需 `@Concurrent`；参数和返回值需可跨线程传递；工作线程不操作 UI | `SudokuTask` 仅传难度、指纹、种子并返回数字数组；`SudokuViewModel` 用取消与 generation 检查阻止旧结果覆盖新局 |
| [TaskPool 与 Worker 对比](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/taskpool-vs-worker) | TaskPool 适合可取消的有限计算任务，不必自行管理工作线程生命周期 | 数独保留已有 TaskPool 出题路线；不新增 Worker 或运行依赖 |
| [SoundPool 短音频播放](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/using-soundpool-for-playback) | 收到 `loadComplete` 后播放；流操作使用 stream ID；结束时释放实例与资源 | `GameSoundPlayer` 区分 sound ID/stream ID，使用加载代次与播放代次；Raw FD 在 finally 关闭；静音与停止期间晚到的播放会停止 |
| [优化动画性能](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/arkts-animation-usage-guide) | 动画优先采用图形变换，减少反复布局；`renderGroup` 的缓存收益依赖子内容静止 | 检查共享动效、反馈组件和抽样棋盘：主要使用 scale/translate/rotate/opacity；动态子内容的缓存收益留待真机测量 |

部分 ArkTS、Navigation 和接续网页仅返回站点目录，未将其作为已核实正文。语言合规由项目强制规则与 API 24 编译器验证；Navigation、接续及计时接口进一步核对本机官方 SDK：

- `@ohos.app.ability.UIAbility.d.ts`：`onForeground`、`onBackground`、`onContinue` 的签名。
- `component/nav_destination.d.ts`：`onShown`、`onHidden`、`onBackPressed`；游戏页通过这些事件接入可见性与返回拦截。
- `@ohos.data.preferences.d.ts`：`getSync` 的异常、`flush(): Promise<void>`、API 14 起支持的 `flushSync()`。
- `@ohos.taskpool.d.ts`：`execute(Task)` 与 `cancel(Task)`。
- `@ohos.systemDateTime.d.ts` 与 `@ohos.graphics.displaySync.d.ts`：时钟和帧回调契约。

SDK 根目录为 `C:/Program Files/Huawei/DevEco Studio/sdk/default/openharmony/ets`。网站当前资料可能包含较新系统能力，本工程的 compile/compatible/target 均保持 API 24。没有新增 API、权限、依赖或调整 SDK。

## 已修复的问题

### 1. 异常最高分污染数据与排行

原来的恢复代码只检查 JSON 值是 number；`{"snake":1e309}` 在解析后得到 Infinity，仍被保存为最高分。随后正常的 120 分不能超过 Infinity，排行榜与成绩更新一直异常。负数和超过安全数值范围的成绩也会进入数据。运行时 `updateHighScore` 同样缺少数值范围检查。

修复位置：`entry/src/main/ets/model/GameData.ets`。恢复和更新共用 `validHighScore`，只接受有限、非负且不超过 `Number.MAX_SAFE_INTEGER` 的数值。无效条目保留默认分；合法成绩、设置、时长及撤下游戏的旧记录继续保留。

证据：新增 `scripts/test-data-recovery.cjs`。修复前 0/3，通过复现确认异常值进入记录；修复后 3/3，验证重启、排名、后续正常成绩更新、非法运行时输入不触发写入，以及无关数据保留。

### 2. 贪吃蛇接受领域不一致的接续状态

原校验检查了坐标范围与重复占用，但未检查相邻蛇身连续性、食物与蛇身冲突、完整的无食物哨兵或待执行转向。六类非法状态都被接受，能替换当前对局并停止原来的计时器，恢复后出现断裂蛇身、无食物或反向撞身等异常。

修复位置：`entry/src/main/ets/viewmodel/SnakeViewModel.ets`。提交恢复之前检查相邻蛇身的 Manhattan 距离为 1、食物位于空格、`(-1,-1)` 仅对应已结束且占满棋盘的状态，以及 pendingTurn 满足已有转向规则。无效输入直接拒绝，当前棋盘、分数和计时器保持原状。

证据：在 `scripts/test-continuation.cjs` 中新增 6 个拒绝用例与 1 个合法满棋盘完成用例。修复前 6 个拒绝用例失败；修复后接续套件 83/83 通过，包含原有三种难度与按用户操作恢复的路径。

## 自检覆盖与结果

| 范围 | 本轮证据 | 结论边界 |
| --- | --- | --- |
| 游戏规则与电脑对手 | 经典规则、合集、扩展玩法、牌类与棋类 AI、出题与难度回归 | 受控桌面规则与 ViewModel 验证 |
| 生命周期与时间 | 暂停、后台、设置遮挡、退出确认、物理帧循环、累计时长回归 | 无后台时间虚增、旧异步结果覆盖等已测路径失败 |
| 存储与接续 | 本地存档、数据恢复、历史、设置、接续、数据清空回归 | 受控 Preferences 和线程边界，不能代替系统磁盘故障及跨设备实测 |
| 音效 | SoundPool 原生边界模拟、静音、音量、晚到播放、资源释放回归 | 没有测量真机音频焦点、延迟或混音效果 |
| 推荐、目录与路由 | 每日推荐、89 游戏目录、撤下玩法与路由边界回归 | 当前单机发布目录；保留的 LAN 代码没有纳入运行路径 |
| 源码依赖扫描 | 从 EntryAbility 与 Index 遍历相对 import/export，共 126 个可达 ArkTS 文件 | 可达源码中没有 NetworkKit/LAN 入口；没有宣称逐行审查全部文件 |
| 字符串 | 可达源码的 764 个静态字符串资源引用；base、zh_CN、en_US 各 821 个定义 | 三个目录均无缺失引用；动态拼接资源不由该扫描证明 |
| 原生合规 | DevEco hvigor `assembleHap`、API 24、CompileArkTS、PackageHap、SignHap | 构建与签名打包成功；未进行真机安装验收 |

执行入口：`node scripts/run-regressions.cjs`。已将新增数据恢复套件纳入此入口。基线 25 组为 1329/1329；修复后 26 组为 **1339/1339**。新增 10 项边界检查，其中 9 项在修改前失败并复现问题，另 1 项保护合法的满棋盘完成状态；修改后全部通过。

原生构建使用项目规范中的 DevEco 自带 `tools/hvigor/bin/hvigorw.js`，最终结果为 `BUILD SUCCESSFUL in 14 s 847 ms`。生成 `entry/build/default/outputs/default/entry-default-signed.hap` 与 unsigned 包。已有 `build-profile.json5` 的工作区改动保留，未修改签名配置。

`git diff --check` 通过；Git 的 LF/CRLF 提示不属于空白错误。

本轮结果文件：

- `docs/harmonyos-code-selfcheck-2026-10-14.json`：本轮结果与源码/产物 SHA-256。
- `entry/build/iteration-20261013/regressions/verification.json`：本轮实际执行时间与 26 组结果；目录名是既有运行器约定，不能按目录名推断执行日期。
- `entry/build/selfcheck-native-20261014.log`：本轮最终原生构建日志。

## 剩余限制与观察

构建仍有 9 条 `GameData.restore` 中 `getSync` 可能抛异常的告警，与修改前相同。异常由 `init` 的外层 try/catch 捕获：模拟任一读取抛错时，会将 store 设为 null，并记录持久化不可用日志，后续成绩暂时只在内存中更新。这是现有故障降级策略；本轮未将其改成逐键恢复，因为简单忽略异常后写回默认值可能覆盖尚未读取的历史数据。若进一步优化，应同时设计重新读取与未读数据保护，而非仅消除编译告警。

`ExpansionFeedback` 的子图形在动画过程中变化，而整个容器开启 `renderGroup(true)`。官方说明其缓存收益依赖子内容保持静止；这是待真机 profiling 的性能观察，没有测量证据支持“已发生卡顿”或直接修改项目既有动画规范。

本轮没有真机操作。主题与字号、分屏、后台真实系统调度、SoundPool 音频焦点、跨设备接续和实际帧率/耗电仍需设备验收。桌面回归、资源扫描和签名成功不能证明这些行为全部通过。
