# 鸿蒙审查复核报告（第二轮）

日期：2026-10-18（Asia/Shanghai） <br>
审查对象：E:\lianxi\LittleGames（`entry`，`com.littlegames.collection`） <br>
基线：HEAD `2937e69` + 当前未提交工作区改动（14 个源文件 M / 若干新增文档与脚本） <br>
本轮手段：源码与配置实证、真实原生构建、真实桌面回归、数学复算、资源全量校验 <br>
前序文档：`docs/harmony-audit-2026-10-13.md`（第一轮）、`docs/harmony-audit-verification-2026-10-13.md`（外部核验）

---

## 一、结论

| 项 | 结果 |
| --- | --- |
| 兼容性判定 | **CONDITIONAL_PASS**（相较上一轮实质改善，但发布链路仍未闭环） |
| 上一轮 5 项缺陷的最终判定 | 成立 3 项（R1/R3/R4，力度需修正） · **误报 2 项（R2/R5，我方算错，撤回）** |
| 本轮新发现的阻断项 | 无新增代码级阻断项 |
| 仍阻断发布的事项 | 签名仍为 debug Profile；设备验收 86/89 未完成 |
| 本轮实测 | 原生构建 `BUILD SUCCESSFUL`；8 套回归 **660 项全过**；`$r(app.*)` 1836 处全部可解析 |

**最重要的一句话：上一轮报告中的 R2（触控 Y 轴反算）与 R5（恢复首帧回弹）是误报，责任在我，特此撤回。** 详见第二节的数学复算。`docs/harmony-audit-verification-2026-10-13.md` 对这两项的反驳是正确的。

---

## 二、我方错误更正（必须先读）

### 2.1 R2「触控 Y 轴反算遗漏」——撤回

**我错在哪里**：我上轮断言 `ExpansionPage.ets:454` 的 `touches[0].y / arenaScale()` 缺少 Y 轴换算，并按「底部 22% 不可达、中心偏移到 294」下结论。复算证明这套推导的分母用错了。

设容器宽 `W`，容器声明 `.aspectRatio(360 / 460)`，则：

```text
H  = W × 460 / 360
sx = W / 360
sy = H / 460 = (W × 460/360) / 460 = W / 360 = sx      ← 两轴比例恒等
世界坐标 = 触摸局部坐标 / (W / 360)
```

因为容器本身是等比容器，X、Y 的缩放系数**在数学上必然相等**，所以双轴同除 `arenaScale()` 是正确的。数值复算（宽度 180/320/336/360/400/720/1024）：

| 容器宽 W | 容器高 H | 中心屏Y→世界Y | 底部屏Y→世界Y | 期望 (230 / 460) |
| ---: | ---: | ---: | ---: | --- |
| 320 | 408.889 | 230.0000 | 460.0000 | PASS |
| 360 | 460.000 | 230.0000 | 460.0000 | PASS |
| 1024 | 1308.444 | 230.0000 | 460.0000 | PASS |

我原报告的 294 是怎么来的：`(H/2) / (W/460) = 293.8889`——我把分母错拿成了 `W/460`，而正确分母是 `W/360`。同一错误连带产生了「底部 22% 不可达」的结论。

**连带纠正**：我原报告称 `ExpansionWorldBoard` / `ExpansionSortingBoard` / `ExpansionBrainBoard` 为「同类高风险点位、须同步回归」，也一并撤回。它们同样是等比容器 + 双轴同除，语义一致。我原建议改成的 `localY / (arenaWidth / WORLD_W)` 与现有实现**完全等价**，即该修复本身并无修复效果；若按我原报告字面改成除以世界高 460，反而会引入真实失配。

### 2.2 R5「恢复首帧 delta=0 造成回弹」——撤回

**我错在哪里**：我只看到 `DisplayFrameLoop` 在恢复首帧下发 `delta=0`，就推断插值会跳变；没有回到 `BrickBreakerViewModel` 核对该帧实际用的是什么。

`BrickBreakerViewModel.ets:170-182` 的插值因子是 `alpha = this.accumulator / PHYSICS_STEP_MS`，**不是** `delta / PHYSICS_STEP_MS`。而 accumulator 在暂停/恢复之间不被清零。`delta=0` 时：accumulator 不变 → `while` 不进循环 → `previousBallX/ball.x` 都不变 → 重算出的 `ballX/ballY` 与暂停前逐位相同。所以首帧是「重复绘制同一位置」，视觉无变化。

后台会主动 `abortCharge()`，我关于 JumpJump 蓄力停滞的附加说法同样缺乏依据。

**结论**：`delta=0` 这一事实成立，但其后果不成立。我为它配的修复方案也无效（只移除 `start` 的重置、保留 `stop` 的重置，仍会得到 `delta=0`）。

### 2.3 我上一轮「实证通过项」里的三处错误

| 我上轮的原话 | 事实 | 性质 |
| --- | --- | --- |
| 「无废弃 API」 | **错**。当时存在 25 处 `getStringSync` 的 `Resource` 重载废弃告警（该重载自 API 20 废弃）。我只 grep 了 `@ohos.` 导入与前缀形态，漏掉了「同一个 API 的不同重载有的废弃、有的没废弃」这种形态。 | 方法漏检 |
| 「清理 LAN 可省约 1 MB」 | **无依据**。5 个 LAN 源文件合计约 33 KB，`lan_*` 字符串每语种仅数 KB。我未做任何包体积差分就给了量级。 | 臆测数字 |
| 「13 处页生命周期均配对」 | **计数错**。我同段实际列出了 15 个游戏页。配对关系本身成立，但数量写错。 | 内部不一致 |

这三处我不做辩解，均属我应有的严谨度不足。教训明确：**结论必须来自可复算的证据，不能来自模式匹配和量级直觉。**

---

## 三、本轮实际验证结果

### 3.1 真实原生构建（本轮亲自执行）

```powershell
node "C:/Program Files/Huawei/DevEco Studio/tools/hvigor/bin/hvigorw.js" assembleHap --mode module -p product=default --no-daemon --no-incremental
```

| 项 | 结果 |
| --- | --- |
| 结果 | `BUILD SUCCESSFUL in 20 s 96 ms`（`CompileArkTS`/`PackageHap`/`SignHap` 均实际执行） |
| 产物 | `entry-default-signed.hap`，11,615,806 字节，2026-10-18 11:08:46 |
| SHA-256 | `7B32F5CDEB842844FF1E973DF55BF81B9802BB7B661AEA3C1DCD5837121FCB91` |
| 包内 `module.json` | `compileSdkVersion=6.1.1.125`、`targetAPIVersion=60101024`、`minAPIVersion=60101024` |
| **包内构建属性** | **`buildMode=debug`、`debug=true`** |
| 废弃 API 告警 | **0 处**（上一轮整理出的 25 处已归零） |
| 剩余告警 | 8 处 `Function may throw exceptions`，位于 `GameData.ets:215-255` |

> 说明：命令退出码为 1 是 PowerShell 把 hvigor 的 stderr 当 `NativeCommandError` 处理所致，构建本身成功（已由 `BUILD SUCCESSFUL` 与产物时间戳证实）。
>
> 关于那 8 处 `may throw` 告警：**它们不构成崩溃路径**。`GameData.ets:200-211` 的 `init()` 用 try/catch 包住了 `getPreferencesSync` 与 `restore()`，任一 `getSync` 抛错都会落到 `:204` 的 catch，记日志并把 `store` 置空，退化为「成绩不持久化」而非闪退。属可接受降级，但建议把这些读取改为 `tryGetSync`/逐项 try，避免整块失败导致所有成绩同时丢失。

### 3.2 全量资源引用校验（本轮编写脚本实跑）

| 项 | 结果 |
| --- | --- |
| 扫描 `.ets` | 131 个文件 |
| `$r(app.*)` 引用 | **1836 处，全部能在资源字典中解析，0 处悬空** |
| 资源规模 | string 823 / float 85 / color 133 / media 653 |
| 三语种一致性 | base 822 · zh_CN 822 · en_US 822，缺失 0、多余 0 |

### 3.3 桌面回归（本轮实跑，共 660 项）

| 套件 | 结果 |
| --- | --- |
| `test-continuation` | 83/83 |
| `test-performance` | 165/165 |
| `test-expansion` | 331/331 |
| `test-window-sizing` | 8/8 |
| `test-single-player-catalog` | 17/17 |
| `test-game-settings` | 12/12 |
| `test-play-history` | 10/10 |
| `test-play-time` | 34/34 |

### 3.4 上轮缺陷的修复状态

| 编号 | 状态 | 证据 |
| --- | --- | --- |
| R1 调试签名 | **未修复（符合预期）** | 本轮构建产物 `buildMode=debug`、`debug=true`；用户已确认发布材料尚未申请 |
| R2 触控反算 | **误报，撤回** | 见 2.1 数学复算 |
| R3 Haptics Promise | **已修复且正确** | `Haptics.ets:16-24`、`:30-38`：同步 `try/catch` + `.catch()` 双保险，两条路径都记 `error.code`。这正是「同步抛 + 异步拒」都覆盖的正解 |
| R4 验收缺口 | **大幅改善** | `docs/device-acceptance/three-settlements-2026-10-14/`：Mate 60 Pro 真机，86/89 款达成三次结算，已记录 261/267 次结算，P5 包已 `hdc install -r` 覆盖安装 |
| R5 首帧回弹 | **误报，撤回** | 见 2.2 |
| 废弃 API | **已修复** | 25 → 0；仅余 `CollectionPage.ets:33` 与 `I18nUtils.ets:22` 的**数字 ID 重载**，该重载未废弃，合规 |

---

## 四、本轮新代码的审查意见

本轮改动约 1042 行新增，主要集中在音量子系统、背包界面重写、接续校验收紧、常量提取。逐项结论：

### 4.1 音量子系统（新增）

`GameSound`（volume/MIN/MAX/STEP/normalizeVolume）、`SettingsVolumeRow`、`GameSoundPlayer.updateVolume`。

- **并发处理是正确的**：`updateVolume()` 用 `volumeDirty` + `updatingVolume` 双标志，先置脏再判守卫，运行中的循环会在下一轮取走脏标记，不存在丢失更新；`pool` 为空时 `continue` 前已清脏标记，不会死循环。
- **音量取值路径正确**：`play()` 每次按 `gameSound.volume` 现算增益，因此 `init()` 阶段 `volumeChanged` 回调尚为空实现也不会导致首音用错音量。
- **持久化与校验完整**：`restore()` 对 `soundVolume` 做了 `Number.isFinite` + 区间限定 + `normalizeVolume`，非法存档回退默认值；`setSoundVolume` 拖拽中合并落盘、结束时 `flushNow()`；`resetSettings()` 同步复位。
- 新增字符串占位符与调用一致：`settings_sound_volume_value = "%d%"` ↔ 单数字参数；`expansion_billiards_fouls = "犯规 %d / %d"` ↔ 双数字；`expansion_cell = "第 %d 行第 %d 列：%s"` ↔ 两数字一字符串。
- **可选微调**：`play()` 内 `this.updateVolume()` 是 fire-and-forget（未 await）。当前函数体内所有可能抛出的调用都被 try/catch 包住，不会产生未处理拒绝；若未来在循环里加入会 reject 的调用，需补 `.catch()`。

### 4.2 背包界面重写（`ExpansionWorldBoard.ets` +87/-40）

- 用 `Grid` + `columnsTemplate/rowsTemplate` 替换嵌套 `Row/Column`，并给每个格子叠加 `.renderGroup(true)`，符合本工程动画/渲染批处理规范。
- `ForEach(this.vm.state.board, ...)` 以 `index:value` 为键，占格值变化会重建对应单元格，撤销后能立即刷新——这是正确的响应式粒度。
- 新增 `packCellDescription()` 走 `resolveString` + `$r('app.string.expansion_cell', 行, 列, 描述)`，资源键经本轮全量校验确认存在。
- 新增媒体 `exp_pack_slot.svg` 在 `base` 与 `dark` 两套目录均已就位，深色主题无缺图。
- 背包自带了「战斗/撤销」按钮，因此 `ExpansionPage` 顶部对 `backpack` 隐藏了重复的撤销按钮，逻辑自洽。

### 4.3 接续校验收紧（`SnakeViewModel`）

- 新增四条不变量：蛇身相邻性、食物不得落在蛇身上、`food=(-1,-1)` 仅允许在「棋盘占满且已结束」时出现、`pendingTurn` 必须可合法转向。
- **不变量与生产路径一致**：`stepOnce()` 吃食后若 `spawnFoodFromOccupancy` 返回 `(-1,-1)`，:222 立即 `gameOver()`，故 `food=(-1,-1)` 与 `status=OVER` 必然同时成立，校验不会误杀正常存档。
- `scripts/test-continuation.cjs` 新增 7 条针对性用例（断开蛇身/食物在蛇身/半缺食物/未完成却无食物/反向转向/未变化转向），并新增一条「棋盘占满可合法接续」的正向用例，覆盖到位。
- 说明：未开局（`IDLE`）状态下导出会因 `snake.length < 1` 被拒，该行为在本次改动**之前就存在**，非本轮引入。

### 4.4 常量提取

`FRUIT_WARNING_Y = 50`、`BILLIARDS_FOUL_LIMIT = 4` 从 `ExpansionPhysics`/`ExpansionSports` 导出，模型判定与 UI 共用同一常量。这消除了「UI 画线位置与判定线漂移」的隐患，是正向改动。`ExpansionPage:444` 现在用同一常量画警戒线，与模型 `:137/:140` 判定线严格一致。

---

## 五、仍然阻断发布的事项

### B1 — 签名仍为调试 Profile【阻断发布】

本轮构建产物确证 `buildMode=debug`、`debug=true`，Profile 为 `type=debug`。这与代码质量无关，但决定了包不能进入正式分发。

补充一条上一轮没说清的工程细节：**把签名配置改名叫 `release` 并不会自动切换构建模式**。发布必须同时满足三件事：① 使用发布证书与发布 Profile；② 构建模式为 release；③ 提交的产物就是该次 release 构建的输出。建议在 AGC 取得发布材料后，用 `--mode module -p product=default -p buildMode=release` 出包，并回读包内 `module.json` 的 `buildMode`/`debug` 字段自证，而不是只看文件名。

另需注意：`build-profile.json5` 被 git 跟踪且内含加密后的口令字段；`.p12` 含私钥、`.cer` 是证书，不能一概称「私钥文件」。当前 `git ls-files` 未包含这些材料，实际路径在仓库外，属可控状态，但建议把签名材料后缀加入 `.gitignore` 以防误提交。

### B2 — 设备验收尚未闭环【阻断上架声明，不阻断代码】

真机记录显示 86/89 款达成三次结算、261/267 次结算，文档自身明确写明「本次验收尚未全部完成。未完成的项目不计为通过」。我认可这种不夸大的表述。

需要补齐：剩余 3 款玩法各 3 次结算。同时提醒：桌面回归（660 项）与真机截图都不能替代**帧率与音频的实测**——`docs/device-acceptance/.../README.md` 也注明了「截图只证明采样时的显示状态，不代表已经测量帧率或验证音频」。这两项若要作为上架质量证据，需单独采集。

---

## 六、非阻断观察（建议，非缺陷）

| 项 | 说明 |
| --- | --- |
| `CollectionPage.ets:33` | 自行写了 `getStringSync(label.id)` 的 try/catch，与 `I18nUtils.resolveString` 重复。建议统一收敛到一个入口，避免日后改错误处理时漏改一处。 |
| `docs/device-acceptance/**/before-*/entry-default-signed.hap` | 证据目录里存了多份约 11 MB 的 HAP 快照，目前为未跟踪状态。若打算纳入版本库，建议只存 SHA-256 与外部归档位置，避免 git 仓库被数十 MB 二进制长期占据。 |
| `I18nUtils.resolveString` 的空串回退 | `context` 缺失时返回 `''`。用于无障碍文本可接受；用于卡片标题/搜索匹配则会造成可见退化。当前组件内 `getUIContext().getHostContext()` 常态可用，属理论风险；若想更稳，可在返回空串时回退到 `defaultValue` 而非空。 |
| 无障碍字符串在 `aboutToAppear` 预解析 | 若该时机 `context` 为 undefined，字符串会被永久缓存为空串且不再重试。建议缓存失败时置标志，在下一次可用时重试。 |

---

## 七、本轮证据清单

| 证据 | 位置/值 |
| --- | --- |
| 原生构建 | `BUILD SUCCESSFUL in 20 s 96 ms`，产物 11,615,806 字节 |
| 产物哈希 | `7B32F5CDEB842844FF1E973DF55BF81B9802BB7B661AEA3C1DCD5837121FCB91` |
| 包内构建属性 | `buildMode=debug`、`debug=true`、`compileSdkVersion=6.1.1.125` |
| 资源校验脚本 | `entry/build/check-res-refs.js`（1836 引用 / 0 悬空） |
| R2 数学复算脚本 | `entry/build/recheck-r2.js`（7 组宽度全部 PASS） |
| 桌面回归 | 8 套 660 项全过 |
| 设备验收 | `docs/device-acceptance/three-settlements-2026-10-14/`（86/89、261/267） |

---

## 八、与上一轮的关系

- 上一轮 `docs/harmony-audit-2026-10-13.md` 的 **R2、R5 已作废**，请勿据此改动代码；该文件顶部已加更正横幅指向本报告。
- 上一轮的 R1、R3、R4 方向正确，力度与表述已在本报告修正（R1 不作为「代码兼容性缺陷」，R3 的后果描述降级为「处理缺口」而非「必然刷屏」，R4 的证据边界收紧）。
- 外部核验文档 `docs/harmony-audit-verification-2026-10-13.md` 的 R2/R5 反驳成立，我采纳；其对「无废弃 API」「LAN 体积」「页数」三处的纠错同样成立。
