# 鸿蒙审查报告核验记录

日期：2026-10-13（Asia/Shanghai）

被核验报告：`docs/harmony-audit-2026-10-13.md`

代码基线：HEAD `555aaed`；开始核验时已有 `build-profile.json5` 未提交变更及原审查报告。
方法：当前源码与配置核对、目标 SDK 声明核对、官方资料检索、全量原生构建、现有回归及针对性桌面复现。

## 结论

**报告部分属实，不能直接按其风险等级和修复建议执行。R2、R5 的核心缺陷不成立；R1 的调试签名事实与 R3 的异步错误处理遗漏成立；R4 的验收缺口成立，但“当前包与源码/SDK 不一致”的断言证据不足。**

| 项目 | 核验结果 | 正确表述 |
| --- | --- | --- |
| R1 调试签名 | 事实属实，等级需要限定场景 | 当前配置适用于调试，正式发布需要发布证书与 Profile；这不是日常调试时的代码兼容性缺陷。 |
| R2 Y 轴反算遗漏 | 不属实 | 等比缩放下 X、Y 同除 `arenaWidth / 360` 正确；报告的数学推导自相矛盾。 |
| R3 Haptics Promise rejection | 属实，但后果描述过度 | 异步 rejection 无处理；同步异常仍会被现有 catch 捕获，不能断言日志永远不执行或特定设备每次必然报错。 |
| R4 历史包/验收不一致 | 部分属实 | 昨日验收未运行原生构建/设备测试属实；不能据此证明今日 HAP 过时。已有包元数据为 API 24，本次全量构建也通过。 |
| R5 首帧 delta=0 引起回弹 | 不属实 | 首帧 delta=0 属实，但 alpha 取决于保留的 accumulator；正常恢复首帧重复暂停前位置。 |

## R1：签名事实成立，发布修复方案仍需补充

当前唯一签名配置名为 `default`，`keyAlias=debugKey`。只提取 Profile 非敏感字段核验，载荷为 `type=debug`、`apl=normal`、`app-feature=hos_normal_app`、包名 `com.littlegames.collection`。配置产品的三处 SDK 均为 `6.1.1(24)`。

华为官方发布证书文档明确正式发布需要发布证书及发布 Profile，因此当前调试签名不适合作为正式分发配置。这不等于工程无法调试、无法编译，也不证明已经发生 AGC 提交拒绝。“唯一上架一票否决项”超出该静态审查能够证明的范围。

原报告的修复命令仅执行 `assembleHap --mode module -p product=default --no-daemon`，没有明确指定 release 构建模式。本次执行该命令时，产物确为 `buildMode=debug`、`debug=true`。把签名配置命名为 `release` 本身不会自动切换构建模式；发布流程需要同时核对构建模式、发布签名和正式提交产物。

`.gitignore` 没有专门忽略签名文件后缀，但这不能证明私钥已泄漏。本次 `git ls-files` 未发现 `.p12/.p7b/.cer`；实际材料路径位于仓库外。`build-profile.json5` 被跟踪，其中口令字段须注意管理。`.p12` 可以包含私钥，`.cer` 是证书，不能将这些后缀一概称为私钥文件。

## R2：等比坐标反算正确

证据：`ExpansionPage.ets:82-85`、`:442-454`、`ExpansionModel.ets:98-105`。

设容器宽为 W，高为 H：

```text
H = W × 460 / 360
sx = W / 360
sy = H / 460 = W / 360 = sx
世界坐标 = 触摸局部坐标 / (W / 360)
```

华为触摸事件文档确认 `TouchObject.x/y` 均为相对事件响应组件的局部坐标，单位 vp。当前渲染的两个坐标也均乘 `arenaScale()`，因此反算双轴同除该比例与渲染一致。

以 W=320 为例：容器高约 408.889vp，中心局部 Y 约 204.444vp，除以 320/360 得到 **230**；底部 408.889vp 得到 **460**。原报告的“中心变成 294”“底部 22% 不可达”计算错误。

原报告给出的 `toWorldY()` 仍计算 `localY / (arenaWidth / WORLD_W)`，与现有实现等价，无法修复其声称的问题。若错误改成除以 `arenaWidth / 460`，才会引入失配。

本次从源码提取原始 `arenaScale` 表达式和 `vm.aim` 调用执行了 60 组换算，涵盖宽 180/320/360/720/1024，X=0/180/360，Y=0/230/459/460，均通过。该检查验证数学与源码表达式，不等同于原生触控和布局实测。

`ExpansionWorldBoard.ets:39-45`、`ExpansionSortingBoard.ets:27-35`、`ExpansionBrainBoard.ets:45-51` 的同除比例也不能仅因此被判为高风险；对应渲染同样使用等比比例。

## R3：确实漏处理异步失败，但同步 catch 有效

证据：`Haptics.ets:13-30`；目标 SDK `@ohos.vibrator.d.ts:141,190`。

SDK 两参重载返回 `Promise<void>`，三参 callback 重载返回 `void`。当前两个调用均未 await、未设置拒绝处理器。异步 rejection 无法被调用外层的同步 try/catch 捕获，属于真实处理缺口；callback 或 Promise.catch 方案均可保留同步 try/catch 后使用。

本次复用仓库桌面测试 fixture 注入两种失败：同步 throw 被现有 catch 捕获并记日志；Promise.reject 产生未处理 rejection，未进入该 catch。因此原报告“静默日志永远不会执行”不成立。801、14600101 在特定设备上的实际失败路径与频率、系统日志影响及用户可见程度没有真机证据，不能直接推导为每次点击刷屏或特定折叠屏必然无马达。

`haptic.effect.soft` 在目标 SDK 的 EffectId 中存在；替换预置效果属于体验优化建议，需要能力检测与回退，不能替代错误处理。

## R4：验收记录有时间和基线边界

`single-player-validation-2026-10-12.json` 记载该轮未做原生构建/设备验收属实。但它记录的 HEAD 是 `7ac157f`，当前 HEAD 是 `555aaed`，不能将昨日某个执行环境缺少 SDK 的记录视为当前机器能力或今日产物状态。

重建前的 signed HAP 时间为 2026-10-13 19:35:04，SHA-256：

```text
A650CD68106DBF1B7827D31F560F2945D1F83E9CAA3C4CA4C699292DA84437DC
```

直接读取重建前 HAP 内 `module.json` 得到 `compileSdkVersion=6.1.1.125`、`targetAPIVersion=60101024`、`minAPIVersion=60101024`、`buildMode=debug`、`debug=true`。此前本机 hvigor 日志也含 10 月 13 日构建记录。这些证据不能代替完整源码到旧包的可追溯证明，但足以否定“根据昨天的记录即可断定今日包不是 API 24”的推断。

本次先执行原报告命令，增量构建成功；随后用本机 hvigor 帮助确认的 `--no-incremental` 参数全量构建：

```powershell
node "C:/Program Files/Huawei/DevEco Studio/tools/hvigor/bin/hvigorw.js" assembleHap --mode module -p product=default --no-daemon --no-incremental
```

结果：`BUILD SUCCESSFUL in 14 s 804 ms`，CompileArkTS、PackageHap、SignHap 实际执行。新的 signed HAP SHA-256：

```text
3322422E875E99C0678A04F52DBE306D8F2829FD4B0BA06D54D211A24253AEE0
```

构建使用现有调试配置。本次未进行设备验收、正式发布构建或线上提交，不能将构建成功视为全设备/上架通过。

## R5：首帧保持当前位置，回弹推导不成立

证据：`DisplayFrameLoop.ets:12-18,25-43`；`BrickBreakerViewModel.ets:170-182,324-350`；`JumpJumpViewModel.ets:407-417`。

帧源 stop/start 清零 lastTimestamp，恢复首帧 delta=0 属实。但打砖块的 alpha 是 `accumulator / PHYSICS_STEP_MS`，并非 `delta / PHYSICS_STEP_MS`；后台/前台转换没有清零打砖块的 accumulator。输入 0 不改变该累积余量，插值结果与暂停前相同。

本次将实际 DisplayFrameLoop 与实际 BrickBreakerViewModel 连接，注入原生帧源 mock，分别在余量 0/15/29ms（alpha=0/0.5/0.9667）后台暂停并恢复。三种情况恢复首帧的 ballX、ballY、accumulator 均与暂停前严格相同，未复现报告声称的回弹。JumpJump 后台会主动 abortCharge，报告也没有证据证明恢复时的蓄力瑕疵。

报告的修复只移除 start 的重置而保留 stop 的重置，仍会得到首帧 delta=0；若进一步让 stop 也保留旧时间戳，又会把后台时间带入恢复 delta，破坏当前“不补后台时间”的语义。`runScopedTask` 异常保护可以作为独立防御性建议，但本次没有会话失效异常的复现证据。

## “通过项”与优化建议的补充校正

| 原报告表述 | 核验结果 |
| --- | --- |
| 无 Native/N-API/XComponent，运行依赖为空 | 属实；源码符号扫描无对应面，重建前 HAP 无 `.so`。entry 有 Hypium 开发依赖，需与运行依赖区分。 |
| 89 款单人游戏 | 当前 catalog 回归 17/17 通过，含 89 款数量、分类及撤下玩法路由约束。 |
| 无可达 LAN/NetworkKit | 属实；从 UIAbility 与 main_pages 联合递归得到 125 个源码依赖文件，LAN/NetworkKit 可达数为 0；原报告的 122 计数缺少复算口径。 |
| 仅振动权限，三语言各 818 条且键一致 | 属实；本次重算每种语言 818 条，键差异与重复均为 0。每种语言有 32 个 lan_* 条目。 |
| 无废弃 API | **不属实**。全量构建产生 25 处 `getStringSync` 废弃警告；例如 I18nUtils:14/29、ControlPad:32。目标 SDK 的 Resource 参数重载从 API 20 废弃；`@kit` import 不代表调用的每个重载都未废弃。另有 34 处可能抛异常的处理警告，警告本身不等于已发生运行时故障。 |
| 原验收哈希证明与当前 HEAD 一致 | 不能照单采用。14 个记录文件只有 7 个当前原始 SHA-256 相符；LF 归一化后仍只有 7 个相符。ExpansionPage/ViewModel 等已在两个提交间修改，昨日记录不能替代当前基线。 |
| 13 处页生命周期均配对 | 所列实际是 15 个游戏页；源码 detach/dispose 配对存在。保留身份校验、清计时器及后台停止设计有依据，但静态配对不能证明所有设备场景无泄漏。 |
| aim 绕过 32ms 同步节流 | 调用路径属实；每次 aim 执行 sync(true,true)，存在优化候选。不能将共享 aim 全部延迟到 advance：部分玩法在阶段 0 绘制/点击后需要立即同步，应只对连续拖动评估节流，并用设备测量判断收益。 |
| 182 个 WAV 共约 3.69MB | 对 rawfile/sounds 子目录属实：182 个、3,695,650 字节、最大 52,964 字节。全 rawfile 有 186 个 WAV、3,745,218 字节，额外含 4 个 melody 音。旧 HAP 中这些 WAV 未压缩；OGG 可用有官方示例，但“节省 3MB”仍需实际转码比较。 |
| 清理 LAN 可省约 1MB | **缺少依据**。列出的 5 个 LAN 源文件合计只有 33,477 字节，32 个字符串每语言只占少量 KB；没有单独 1MB LAN 资源或包差分证据。 |
| getDefaultDisplaySync 重复 IPC | 重复调用属实，逐次 IPC 次数及收益未测量。缓存应考虑密度/显示配置变化，不能无条件永久固定。 |
| 拖动期间放宽帧率到 90/120 提升跟手感 | 属于待测优化；当前 advance 仍按约 32ms 同步显示状态，单改帧源上限不能证明有效提升，应同时评估状态同步、帧耗时与能耗。 |
| 对局越久历史条目线性增长 | 当前记录按游戏 ID 去重并保留每游戏最近时间，不是每局追加记录。没有长时间对局导致历史无限增长的证据，环形缓冲建议缺少当前问题基础。 |

## 本次验证记录

- 全量 HarmonyOS 6.1.1/API 24 构建：通过，有上述警告。
- `scripts/test-performance.cjs`：162/162 通过。
- `scripts/test-window-sizing.cjs`：8/8 通过。
- `scripts/test-single-player-catalog.cjs`：17/17 通过。
- 针对性探针：60 组坐标反算、3 组真实 ViewModel/帧源恢复、振动同步/异步故障注入通过。
- 日志与探针位于 `entry/build/audit-verification-20261013/`（build 目录已被忽略）。仅新增本核验记录，原业务源码及原审查报告未修改。

官方参考：[触摸事件](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/ts-universal-events-touch)、[申请调试 Profile](https://developer.huawei.com/consumer/cn/doc/App/agc-help-debug-profile-0000002248181278)、[申请发布证书](https://developer.huawei.com/consumer/cn/doc/App/agc-help-release-cert-0000002283336729)、[SoundPool 指南](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/using-soundpool-for-playback)。vibrator 网页本次只返回动态页面外壳，重载以本机目标 SDK 声明核验，并参照 [OpenHarmony 官方仓库示例](https://github.com/openharmony/sensors_miscdevice) 区分同步 try/catch 与异步 Promise.catch；不将 OpenHarmony 示例视作具体 HarmonyOS 设备运行结果。

## 修复进展（2026-10-13，后续修复请求）

以上核验结论和哈希是修复前的记录。用户确认发布签名材料尚未申请，本次先完成代码修复。

- **R3 已修复**：`Haptics.ets` 的 tap/success 同时保留同步 try/catch 并处理 Promise rejection，记录错误码，振动失败不向游戏操作传播。
- **25 处废弃字符串重载已替换**：10 个页面/组件调用改用现有 `resolveString`；`I18nUtils.ets` 内两个 Resource 重载替换为数字资源 ID 重载。保留 `$r` 的字符串/数字格式参数，读取失败或上下文缺失时返回空字符串；手动格式化模板沿用既有占位符替换行为。
- **R1 待发布材料**：保持已有调试签名和用户先前的构建配置变更；未创建无效发布配置。
- **R4 当前源码构建记录已更新**：本次全量构建成功，未执行设备验收。
- **R2/R5**：误报对应代码维持原有行为；性能候选建议未作为已证实缺陷处理。

验证：`test-performance` 165/165（新增同步失败、异步 rejection、三语种资源 ID/格式参数检查）；`test-play-time` 34/34；`test-game-settings` 9/9；`test-play-history` 10/10，共 **218/218** 通过。

API 24 全量原生构建：`BUILD SUCCESSFUL in 16 s 147 ms`。废弃警告 **25 → 0**，可能抛异常的处理警告 **34 → 9**；剩余 9 处位于既有 `GameData.ets` Preferences 读取逻辑，本轮没有据此推定已发生故障。构建、性能、设置和历史日志保存在 `entry/build/audit-fixes-20261013/`。

修复后 `entry/build/default/outputs/default/entry-default-signed.hap` 的 SHA-256：`C728AEC0A23B66B61F4BCAC3EAD6C47F6095723551919A10E4E5C982E31EF763`（现有调试签名）。

本次新增的振动失败测试使用 native mock，资源测试核对真实三语种文本并验证数字 ID/格式参数传递；它们不替代设备振感与读屏验收。
