# 鸿蒙原生游戏方案合规与架构审查报告

日期：2026-10-13

审查对象：E:\lianxi\LittleGames（模块 `entry`，bundleName `com.littlegames.collection`）

审查基线：HEAD `555aaed`（工作区另有未提交变更 ` M build-profile.json5`）
审查方式：源码与配置实证核对（静态审查 + 哈希比对 + 官方文档交叉验证）；**未执行**原生构建与真机验收

---

## 一、结论

| 项 | 结果 |
| --- | --- |
| 鸿蒙兼容性判定 | **CONDITIONAL_PASS（有条件通过）** |
| 阻断项 | 签名配置为 **debug Profile**，AGC 无法分发（与代码质量无关） |
| 最实质代码缺陷 | `ExpansionPage.ets:454` 触控 **Y 轴反算遗漏**，影响 blackhole / fisheat 两款实时拖动玩法 |
| 缺陷等级分布 | CRITICAL 1 项 · MAJOR 3 项 · MINOR 1 项 |

---

## 二、审查基线校正（重要）

提交物声明的技术栈为「ArkTS / ArkGraphics 2D / Native(C/C++) / XComponent / N-API」，但**实际代码中不存在 Native 层**：

| 核查项 | 命令/路径 | 结果 |
| --- | --- | --- |
| Native 源码目录 | glob `entry/src/main/cpp/**/*` | 无文件 |
| N-API 符号 | grep `napi_*`、`libace_napi` | 无命中 |
| XComponent | grep `XComponent`、`OH_NativeXComponent` | 无命中 |
| CMake | glob `**/CMakeLists.txt` | 无文件 |
| 三方依赖 | `oh-package.json5`（根与 entry） | `dependencies` 均为 `{}` |

**实际架构**：纯 ArkTS + 声明式 ArkUI + ArkGraphics2D `displaySync` 帧源的游戏合集（89 款）。

**由此判定为「不适用」而非「通过」的维度**：ArkTS↔Native 跨语言开销、`napi_value` 生命周期野指针、Native 渲染线程与 ArkTS UI 线程竞态、XComponent Surface 丢失重建。本工程无对应代码，不构成风险项。审查基线据此校正为 ArkTS 运行时。

---

## 三、风险清单

### R1 — 签名 Profile 为 debug 类型【CRITICAL / 上架被拒】

- **位置**：`build-profile.json5:2-17` → `signingConfigs[0].material.profile`
- **证据**：指向 `C:\Users\29186\.ohos\config\default_LittleGames_...p7b`，实测其载荷含 `"type":"debug"`、`"apl":"normal"`、`"app-feature":"hos_normal_app"`、`bundle-name: com.littlegames.collection`；`keyAlias` 为 `debugKey`
- **机理**：工程唯一签名配置指向 DevEco 自动生成的**调试**证书与调试 Profile。调试 Profile 由 IDE 本地生成、绑定特定设备指纹白名单，不具备分发资质
- **后果**：AGC 上架校验直接拒绝；即便强行提交，安装到未登记设备会因 Profile 校验失败而无法安装。**当前唯一的上架一票否决项**
- **修复**：在 AGC 申请发布证书与发布 Profile，新增独立 `signingConfig` 而非覆盖调试配置：

```json5
"signingConfigs": [
  { "name": "default", "type": "HarmonyOS", "material": { /* 保留现有调试配置，勿动 */ } },
  {
    "name": "release",
    "type": "HarmonyOS",
    "material": {
      "certpath": "C:\\keys\\littlegames_release.cer",
      "storeFile": "C:\\keys\\littlegames_release.p12",
      "keyAlias": "littlegamesRelease",
      "keyPassword": "<加密串，用 DevEco 生成>",
      "storePassword": "<加密串>",
      "profile": "C:\\keys\\littlegames_release.p7b",
      "signAlg": "SHA256withECDSA"
    }
  }
],
"products": [
  { "name": "default", "signingConfig": "release", "compileSdkVersion": "6.1.1(24)",
    "compatibleSdkVersion": "6.1.1(24)", "targetSdkVersion": "6.1.1(24)", "runtimeOS": "HarmonyOS" }
]
```

- **附带风险**：根 `.gitignore` 仅忽略 `/local.properties` 与 `**/build`，**签名私钥 `.p12/.cer/.p7b` 与 `build-profile.json5` 内的加密口令当前不在忽略范围**。提交前须确认这些文件不进入版本库；密钥一经泄露需吊销重签。

---

### R2 — 触控 Y 轴坐标反算遗漏【MAJOR / 玩法不可用】

- **位置**：`entry/src/main/ets/pages/collection/ExpansionPage.ets:454`（Arena Builder `:420-456`，容器 `:448` 为 `.aspectRatio(360 / 460)`）
- **缺陷代码**：

```ts
this.vm.aim(event.touches[0].x / this.arenaScale(),
            event.touches[0].y / this.arenaScale());
```

- **机理**：
  - 世界空间由模型硬约束为 **360×460**：`ExpansionModel.ets:99` 对 `x < 0 || x > 360 || y < 0 || y > 460` 直接 `return`；`ExpansionPhysics.ets:4` 注释「Coordinates are logical units in a 360 by 460 arena」
  - 渲染侧统一走 `world * arenaScale()`，其中 `arenaScale() = arenaWidth / 360`
  - 容器宽高由 `aspectRatio(360/460)` 绑定，故 **Y 方向真实比例同样是 `arenaWidth/360`**
  - X 用 `touches[0].x / (arenaWidth/360)` 正确还原世界坐标；Y 却用同一个 `arenaScale()` 去除屏幕 vp 值，等价于**把手指数值原样当作世界 Y**（误差因子 360/460 ≈ 0.78）
- **数学后果**：
  - 容器视觉高度 = `arenaWidth × 460/360 ≈ 1.278 × arenaWidth`
  - aim 的 y 上界在 y=460 时才取到 `arenaWidth` → **容器底部约 22% 区域永远无法命中**
  - 瞄准视觉中心时 `y = 0.639 × arenaWidth` → 送入模型的 `y = 294`，而真实世界中心是 **230**，系统性偏移约 +28%
- **受影响玩法**：走该分支的 blackhole / fisheat（`:451`、`:453` 的 gameId 白名单）。表现为手指与目标明显错位、拖到画面下半部无法到达（y 超出 460 即被 `ExpansionModel.ets:99` 静默丢弃），直接造成操作不可用
- **回归证据**：该缺陷在 HEAD(`555aaed`) 与上一版(`7ac157f`) **均存在**（`git diff 7ac157f..HEAD` 未触及该行）；`docs/single-player-validation-2026-10-12.json` 的 1267/1267 用例全部是纯逻辑/ViewModel 层回归，**不经过 ArkUI 触控链路**，故从未被覆盖
- **修复**：Y 轴按世界高换算，并抽出共享换算函数：

```ts
private static readonly WORLD_W: number = 360;
private static readonly WORLD_H: number = 460;

private toWorldX(localX: number): number {
  const s: number = this.arenaWidth / ExpansionPage.WORLD_W;
  return s > 0 ? localX / s : 0;
}
private toWorldY(localY: number): number {
  const s: number = this.arenaWidth / ExpansionPage.WORLD_W; // 等比缩放：y 同样除以 arenaScale
  return s > 0 ? localY / s : 0;
}

.onTouch((event: TouchEvent) => {
  if (event.type === TouchType.Down && ['blackhole', 'fisheat'].includes(this.gameId)) { this.vm.setDragging(true); }
  if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.vm.setDragging(false); }
  if ((event.type === TouchType.Down || (event.type === TouchType.Move && ['blackhole', 'fisheat'].includes(this.gameId)))
      && event.touches.length > 0 && this.arenaScale() > 0) {
    this.vm.aim(this.toWorldX(event.touches[0].x), this.toWorldY(event.touches[0].y));
  }
})
```

若要严格各向同性，应以容器实测高宽反算（`measureArena` 需同时记录 width 与 height，并在窗口尺寸变化回调中一并更新）：

```ts
const sx = this.arenaWidth / 360;
const sy = this.arenaHeight / 460;
```

- **同类高风险点位（须同步回归）**：
  - `ExpansionWorldBoard.ets:39-45`
  - `ExpansionSortingBoard.ets:27-35`
  - `ExpansionBrainBoard.ets:45-51`

  这三处为双轴同除 `arenaScale()`，与本页语义不一致。建议统一收敛到一个共享坐标换算函数，避免逐页手写再次漏轴。

---

### R3 — Haptics 未处理 Promise rejection【MAJOR】

- **位置**：`entry/src/main/ets/common/Haptics.ets:16` 与 `:27`

```ts
vibrator.startVibration({ type: 'time', duration: 10 }, { usage: 'touch' });
```

- **机理**：`startVibration` 的 2 参重载返回 `Promise<void>`，本处未接 `then/await`，仅包在 `try/catch`。官方文档明确错误码 201/401/801/14600101「会以异常的形式抛出……需要使用 try catch 捕获」，但 `try/catch` 只能捕获**同步**抛出；Promise 重载下的运行时失败（801 Capability not supported、14600101 Device operation failed，如无马达的平板/折叠屏内屏）走 **rejected promise** 路径
- **后果**：每次点按（方向键、翻牌、敲地鼠等高频操作）产生一个未处理 rejection，日志被刷屏；`Haptics.ets:19`、`:29` 精心写的「静默跳过」日志**永远不会执行**，错误处理形同虚设
- **修复**：改用 callback 重载（错误经 `error` 参数回传）：

```ts
import { vibrator } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';

static tap(): void {
  if (!GameDataManager.getSetting('hapticsEnabled', true)) { return; }
  try {
    vibrator.startVibration({ type: 'time', duration: 10 }, { usage: 'touch' },
      (error: BusinessError) => {
        if (error) {
          hilog.debug(0x0000, 'LittleGames', 'Haptics.tap failed: %{public}d', error.code);
        }
      });
  } catch (e) {
    hilog.debug(0x0000, 'LittleGames', 'Haptics.tap threw (device may not support vibration)');
  }
}
```

- **附加建议**：官方文档指出 `VibrateTime` 仅控制时长、「无法满足精致体验」，推荐 `VibratePreset` 以保证与系统振感一致。高频轻触可改为 `{ type: 'preset', effectId: 'haptic.effect.soft', count: 1 }`，并用 `vibrator.isSupportEffect()` 探测一次后缓存，避免每次点按都发起能力探测 IPC

---

### R4 — 构建产物与验收状态不一致【MAJOR】

- **位置**：`docs/single-player-validation-2026-10-12.json:224-231`；`entry/build/default/outputs/default/entry-default-signed.hap`
- **证据**：工程自述 `nativeBuild.executed=false`、`deviceAcceptance.executed=false`、`existingHapIsHistorical=true`；现存唯一产物时间戳为 2026/10/13 19:35（11.56 MB），属历史包
- **机理与后果**：上架提交的 HAP 必须与当前源码、当前 SDK 一致。用历史包提交等于提交未经本轮验证、且可能以旧 SDK 构建的产物，与声明的 API 24 基线不符；同时 89 款玩法的真机帧率、触控、折叠屏分屏表现均无实测证据
- **修复**：三条闭环
  1. 明确 `build-profile.json5` 最终变更并复核三处 SdkVersion
  2. 用 DevEco 自带 hvigor 重新出 release 包并记录产物哈希：

```bash
cd E:/lianxi/LittleGames
export DEVECO_SDK_HOME="C:/Program Files/Huawei/DevEco Studio/sdk"
export PATH="/c/Program Files/Huawei/DevEco Studio/tools/node:/c/Program Files/Huawei/DevEco Studio/tools/ohpm/bin:/c/Program Files/Huawei/DevEco Studio/jbr/bin:$PATH"
export JAVA_HOME="C:/Program Files/Huawei/DevEco Studio/jbr"
node "C:/Program Files/Huawei/DevEco Studio/tools/hvigor/bin/hvigorw.js" assembleHap --mode module -p product=default --no-daemon
```

  3. 补真机验收：折叠屏展开/折叠重算棋盘、平板自由多窗口、挖孔屏安全区、后台切回帧率恢复，并**补一条覆盖 touch→world 换算的测试**（现有 1267 项用例无一覆盖该链路）

---

### R5 — 恢复后首帧 delta=0 造成单帧回弹【MINOR】

- **位置**：`entry/src/main/ets/common/DisplayFrameLoop.ets:12-19`、`:34`、`:40-44`
- **机理**：`stop()` 与 `start()` 都把 `lastTimestamp` 重置为 0，恢复后第一帧在 `:16` 命中 `this.lastTimestamp === 0 ? 0`，下发 `onFrame(0)`
- **后果**：不产生物理跳变（未累积后台时间，这点实现是对的），但恢复后第一个渲染帧用 delta=0 推进：`BrickBreakerViewModel.ets:180-182` 的插值 alpha 会算出 0，使球体先回显到 `previousBallX/Y` 再于第二帧跳回；JumpJump 蓄力读数同帧停滞。属后台切回的可见瑕疵
- **修复**：只在真正首帧丢弃时间，恢复时保留单调时间基准；并为 `runScopedTask` 加保护，避免会话已结束时异常沿 `notifyShown → onAppShown → startFrames → start` 冒泡成未捕获异常：

```ts
start(onFrame: (deltaMs: number) => void): void {
  this.onFrame = onFrame;
  if (this.running) { return; }
  try {
    this.context.runScopedTask(() => {
      if (this.sync === null) {
        this.sync = displaySync.create();
        this.sync.setExpectedFrameRateRange({ min: 30, max: 60, expected: 60 });
        this.sync.on('frame', this.handleFrame);
        this.lastTimestamp = 0;   // 仅首次创建时丢弃首帧
      }
      this.running = true;
      this.sync.start();
    });
  } catch (e) {
    this.running = false;
    hilog.warn(0x0000, 'LittleGames', 'DisplayFrameLoop.start skipped: UIContext session unavailable');
  }
}
```

---

## 四、实证通过的项

以下为本次核对通过项，用于界定已覆盖的审查面与残余风险边界。

### 生命周期与渲染循环

- **displaySync 帧源封装合格**：`DisplayFrameLoop.ets:31` 将帧率锁在 60（避免高刷无谓跑 120fps）；`:46-51` 的 `dispose()` 正确执行 `stop → off('frame') → 置空 → 释放回调引用`，无监听器残留
- **物理循环抗卡顿设计正确**：`BrickBreakerViewModel.ets:170-183` 用 accumulator 定步长累积，并以 `Math.min(Math.max(deltaMs, 0), PHYSICS_STEP_MS * 3)` 封顶，避免长卡顿后在 UI 线程追赶数百步导致「死亡螺旋」。这是移动端物理渲染的正解
- **后台暂停链路完整且无累积误差**：13 处游戏页在 `aboutToDisappear` 全部成对调用 `GameLifecycleBus.detach` + `viewModel.dispose()`——SudokuPage:55/60、GuessNumberPage:28/34、CollectionPage:36/40、ExpansionPage:49/53、MemoryCardPage:46/53、SlidePuzzlePage:39/46、BrickBreakerPage:34/40、KlotskiPage:41/51、Game2048Page:79/91、JumpJumpPage:45/51、Match3Page:43/49、SnakeGamePage:39/45、MinesweeperPage:51/57、TetrisGamePage:52/69、WhackMolePage:42/48，**无遗漏页**；`onAppHidden` 统一 `frames.stop()`（如 `JumpJumpViewModel.ets:407-413`），`onAppShown` 走 `startFrames()` 且明确「不补后台经过的时间」
- **观察者注册表设计正确**：`GameLifecycleBus.ets:66-73` 在 detach 时校验身份 `if (observer === GameLifecycleBus.observer)`，杜绝「旧页面销毁误删新页面注册」这类经典回调错配
- **音频焦点释放正确**：`onBackground → notifyHidden() → gameSound.setVisible(false)`（`:79`）→ `GameSound.ets:30-33` 触发 `halt() → GameSoundPlayer.stop()` 逐流 `pool.stop()`；第二套音频 `ExpansionTonePlayer` 亦经 `ExpansionViewModel.stop()`（`:149` `toneStop()`）在 `onAppHidden`（`:152-155`）中停振，**无后台持续出声**

### 资源与内存

- **无 N-API/XComponent/Native 内存面**：无 cpp 目录、无 CMakeLists、无 `napi_value` 生命周期、无 GPU 写入失效 Surface，相关风险项不适用
- **计时器无泄漏**：`GameDataManager` 落盘防抖句柄在 `flushNow()`（`GameData.ets:374-377`）中 `clearTimeout` 并复位为 -1；`GameLifecycleBus.playTimeTimer` 在 `stopPlayTime()`（`:197-201`）中 `clearInterval`
- **SoundPool 资源边界正确**：`GameSoundPlayer.loadGame` 仅按当前 gameId 加载 action/reward + 4 个通用音效（`:56-57`），析构走 `dispose() → release()`（`:117-122`）；rawfile 音频共 182 文件、合计 3.69 MB、最大单文件 52 KB，每局仅驻留 6 个音效
- **无常驻增长容器**：存档串设 `MAX_SAVED_GAME_LENGTH = 8192`（`GameData.ets:22`）；`ExpansionTonePlayer.streams` 有 `> 8` 裁剪（`:34`）；`LanTransport` 有 `MAX_PENDING_BYTES = 1 MB` 背压（`:26`）

### 多设备适配

- **未硬编码物理分辨率**：全仓无 1920/1080/2560 等物理像素常量；`ScreenUtils.ets:93-115` 的 `calcCell / calcCellForArea` 以 vp 为基准并按 min(宽,高) 双向约束；窗口宽度取 `getWindowProperties().windowRect.width`（**窗口**而非整屏），注释 `:4-11` 显式纠正了旧实现取整屏宽度导致分屏/折叠屏棋盘溢出的问题
- **窗口变化监听到位**：`EntryAbility.ets:83-92` 同时监听 `avoidAreaChange`（手势条避让）与 `windowSizeChange`（分屏/自由窗口/折叠展开/旋转）
- **安全区单位换算正确**：`SafeAreaInsets.ets:45` 将 `getWindowAvoidArea` 的 **px** 结果除以 `densityPixels` 转为 vp 再使用，无 px/vp 混用
- **布局适配手段合规**：动画一律用 `translate/scale` 而非改 width/height（`JumpJumpPage.ets:150/212`），符合 AGENTS.md「禁止在动画过程中改变布局属性」的性能红线

### 权限、规范与上架

- **权限极简**：`module.json5:13-22` 仅声明 `ohos.permission.VIBRATE`，且带 `reason`/`usedScene`。这是**有意收敛**的结果——`docs/single-player-scope-2026-10-12.md:35` 明确记载「应用撤下 `ohos.permission.INTERNET` 与 `ohos.permission.GET_NETWORK_INFO`」，静态检查确认入口依赖的 122 个 ArkTS 文件不再触达 Lan 模块。未声明任何敏感硬件权限或后台常驻任务
- **无支付/账号/联网面**：全仓无 IAP、无华为账号登录、无 `@kit.GameServiceKit`、无 HTTP/网络调用。Lan 子系统（`LanTransport.ets:1` 引入 `@kit.NetworkKit` 的 TCPSocketServer/TCPSocket/connection）**确认不可达**——`LanRoomPanel` 未被任何页面 import，grep 全 `entry/src` 无实例化点
  - **澄清常见误报**：`@kit.NetworkKit` 接口本身无需在 `module.json5` 声明权限，故「有网络代码但无权限声明」在当前不可达状态下**不构成运行时缺陷**；但该模块一旦被重新接线，将立即因缺 INTERNET 权限而失败
- **无废弃 API 与旧版 API**：无 `@ohos.*` 前缀 import（全部 `@kit.*`）、无 `AppStorage/LocalStorage`、无 `getContext(this)`、无 `featureAbility/router.pushUrl` 等旧用法；弹窗与动画统一走 `this.getUIContext().showAlertDialog/animateTo/getPromptAction()`
- **ArkTS 约束合规**：grep 未发现 `any/unknown` 标注、`var`、`require`、`export =`、`globalThis`、`Symbol()`、`Function.apply/call/bind`、`for..in` 遍历对象。命中的 `.apply(` 均为业务自定义方法（如 `KlotskiViewModel.ets:97` `this.rules.apply(...)`、`AppTheme.apply`），非 `Function.apply`，属误报排除
- **国际化完备**：base / zh_CN / en_US 三份 `string.json` 各 818 条，键集合完全一致（缺失 0、多余 0、重复 0）
- **工程与 SDK 基线正确**：`runtimeOS` 为 HarmonyOS、三处 SdkVersion 均为 `6.1.1(24)`、设备类型 `phone + tablet`、`continuable` 与 `UIAbility.onContinue`（`EntryAbility.ets:32-43`）配套实现系统接续；`.gitignore` 已排除 `local.properties` 与 build 产物

---

## 五、性能与能效优化建议

按投入产出排序。

### 1) 触控期间的渲染节流（最高收益）

`ExpansionViewModel.advance`（`:142-148`）以 `renderElapsed >= 32` 作 sync() 节流阈值（约 31Hz 状态同步），但 `aim()`（`:121-123`）每次触控事件都无条件 `this.sync(true, true); this.run();` 全量同步。Move 事件在 120Hz 触控采样下最高 120 次/秒，等于把节流设计整体旁路。

**建议**：把 `aim` 的同步并入同一节流窗口，仅更新模型内部目标点，由 `advance` 的 `renderElapsed` 统一驱动 `sync`；拖拽结束（`setDragging(false)`）时再强制一次全量同步保证落点精确。

### 2) 音效资源格式（立竿见影的体积收益）

182 个音效全为未压缩 PCM WAV，合计 3.69 MB 并直接线性计入 HAP 体积。改为 OGG Vorbis（SoundPool 原生支持），同听感下通常可压到 1/5~1/10，预计节省约 3 MB 包体。

**注意**：WAV 无需解码、延迟最低。若某些需要极低延迟的击打音（action）保留 WAV、其余转 OGG，是更稳的折中。

### 3) 消除 `getDefaultDisplaySync()` 的重复 IPC

`ScreenUtils.ets:23-34` 与 `SafeAreaInsets.ets:25-36` 各自实现一份 `density()`，且 `windowWidthVp()/windowHeightVp()` 在每次棋盘尺寸计算时都会调用一次。密度是稳定值。

**建议**：在 `EntryAbility.onWindowStageCreate` 时取一次并缓存到静态字段（该时机已在调用 `updateFromWindow`，可顺带写入），棋盘计算路径改为纯算术。

### 4) 复用高刷能力做「感知更跟手」而非「跑更多帧」

当前 `setExpectedFrameRateRange` 固定 `{min:30, max:60, expected:60}`。对 Snake/Tetris/2048 等离散跳变玩法，60 已足够且省电；但对 shooter/tanks/fisheat 这类连续拖拽玩法，可在交互期间按需放宽 max（如 90/120）并在静止时回落到 30，用动态帧率区间换取跟手感。配合第 1 点效果最好。

### 5) 清理不可达代码以缩小体积与攻击面

Lan 子系统（`LanTransport / LanGameSession / LanProtocol / LanFraming / LanRoomPanel` 及 20+ 条 `lan_*` 字符串资源）已确认从产品撤下但源码仍在编译树内，其字符串仍参与三语种资源打包。

**建议**：若确定不再恢复，应从 `src/main` 移除并同步清理 `resources` 中的 `lan_*` 条目（保留 docs 中的实现记录即可）；若计划恢复，建议移入独立 feature 模块按需构建，避免每次出包携带约 1 MB 无效资源与 socket 代码。

### 6) 结算路径的写盘合并

当前 `updatePlayTime/checkpointPlayTime` 以 5s 间隔计时（`GameLifecycleBus.ets:148`），叠加 `flushNow()` 的 200ms 防抖（`GameData.ets:26`），落盘策略已相当克制，无明显优化空间。唯一建议：确认 `addPlayTime` 触发的全量序列化不会在长时长对局中随历史记录条目线性变慢，必要时把历史记录改为定长环形缓冲。

### 7) 动画性能

已合规，无需改动。各页动画均以 `translate/scale` 驱动（不触发布局重排）；复杂子树可用 `renderGroup(true)` 进一步合并渲染批次，属可选微调。

---

## 六、审查方法与证据

| 手段 | 用途 |
| --- | --- |
| glob / grep | 全仓结构测绘、Native 层确认、废弃 API 与 ArkTS 约束扫描 |
| 源码精读 | 生命周期、帧源、音频、坐标换算、数据落盘全链路 |
| 文件哈希比对 | 与 `docs/single-player-validation-2026-10-12.json` 记录的 SHA-256 比对，证明缺陷存在于 HEAD 而非仅工作区 |
| git 历史 | `git log / git diff 7ac157f..HEAD` 确认缺陷跨版本存在 |
| 官方文档交叉验证 | `vibrator.startVibration` 重载语义与错误码抛出方式 |
| 资源实测 | rawfile 音频数量/体积、三语种字符串键集合比对 |

### 本次未覆盖（残余风险）

- **未执行原生构建**：未运行 hvigor，故未取得编译级证据
- **未执行真机/模拟器验收**：折叠屏、分屏、挖孔屏安全区、后台切回帧率均无实测数据
- **触控链路无自动化覆盖**：R2 这类缺陷落在 ArkUI 事件层，现有 1267 项桌面用例全部是纯逻辑层回归，无法拦截

---

## 附录：结构化判定（JSON）

```json
{
  "harmony_compatibility_verdict": "CONDITIONAL_PASS",
  "critical_risks": [
    { "dimension": "权限合规", "severity": "CRITICAL (闪退/被拒)", "culprit_reference": "build-profile.json5:2-17 signingConfigs[0].material.profile（实测 type=debug）", "root_cause": "唯一签名配置指向 DevEco 调试证书与调试 Profile，keyAlias=debugKey，绑定本机设备指纹", "remediation": "在 AGC 申请发布证书与 Profile，新增独立 signingConfig 并构建 release 变体" },
    { "dimension": "设备适配", "severity": "MAJOR (掉帧/内存泄漏)", "culprit_reference": "entry/src/main/ets/pages/collection/ExpansionPage.ets:454", "root_cause": "世界空间 360×460 与容器 aspectRatio(360/460) 等比，X 已做 touches[0].x / arenaScale() 反算而 Y 复用同一比例，导致 Y 被当成世界值，偏差因子 360/460≈0.78，底部约 22% 不可达、中心偏移 +28%", "remediation": "Y 轴按世界高独立换算，并抽出共享 toWorldX/toWorldY；同步回归 WorldBoard/SortingBoard/BrainBoard 同类点位" },
    { "dimension": "权限合规", "severity": "MAJOR", "culprit_reference": "entry/src/main/ets/common/Haptics.ets:16,27", "root_cause": "startVibration 两参重载返回 Promise，未接 then/await，try/catch 无法捕获 rejected promise，导致高频未处理 rejection 且原定静默日志永不执行", "remediation": "改用 callback 重载处理 BusinessError，或显式吞掉 rejection" },
    { "dimension": "权限合规", "severity": "MAJOR", "culprit_reference": "docs/single-player-validation-2026-10-12.json:224-231 与 entry/build/default/outputs/default/entry-default-signed.hap", "root_cause": "现存产物为历史包，工程自述本轮未构建、未设备验收，与声明的 API 24 基线及当前源码不一致", "remediation": "重出 release 包记录哈希，并补折叠屏/分屏/安全区/后台恢复真机验收" },
    { "dimension": "生命周期", "severity": "MINOR (体验欠佳)", "culprit_reference": "entry/src/main/ets/common/DisplayFrameLoop.ets:12-19,34,40-44", "root_cause": "stop/start 均将 lastTimestamp 归零，恢复后首帧下发 delta=0，插值 alpha=0 造成单帧回弹", "remediation": "仅首次创建 sync 时丢弃首帧；并为 runScopedTask 增加异常保护" }
  ],
  "performance_suggestions": "1) 触控期渲染节流：aim() 每次 Move 无条件全量 sync，旁路了 advance() 的 32ms 节流窗口，应并入统一节流。2) 182 个未压缩 WAV 共 3.69MB，转 OGG 可省约 3MB，极低延迟音效可保留 WAV。3) density() 重复 IPC，应在 EntryAbility 缓存静态密度值。4) 按玩法类型动态调整 expectedFrameRateRange，连续拖拽玩法交互期放宽上限、静止回落。5) 清理已撤下的 Lan 子系统与 lan_* 资源约 1MB。6) 历史记录必要时改定长环形缓冲。7) 动画已用 translate/scale 合规，可用 renderGroup(true) 微调。"
}
```
