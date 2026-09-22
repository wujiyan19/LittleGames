# LittleGames 游戏模块全面检查修复计划（2026-09-21）

> 用户报告：2048 棋盘渲染出错、贪吃蛇界面不刷新，以及其他游戏可能存在的类似问题。
> 本文档基于对所有 10 个游戏模块（Model/ViewModel/Page 三层）的逐行审查。

---

## 一、问题清单与根因分析

### P0-1 贪吃蛇界面不刷新（确认 Bug）

**现象**：蛇移动时画面不更新，只有吃到食物（score 变化）或死亡（status 变化）时才刷新。

**根因**：`SnakeViewModel.occupied` 是 `private`（非 `@Trace`），但 `isSnakeCell()` 通过 `occupied` 查询蛇身占用。Build 函数调用 `getCellColor(col, row)` → `viewModel.isSnakeCell(col, row)` → `rules.isOccupied(this.occupied, x, y)`，整条链路只访问 `occupied`（非 `@Trace`），框架无法检测到依赖关系。

当蛇移动时：
- `snake`（`@Trace`）被重新赋值 → 但 build 函数不直接读 `snake`
- `occupied`（非 `@Trace`）被重新赋值 → 框架不跟踪
- `food`（`@Trace`）不变 → 不触发
- `score`（`@Trace`）不变 → 不触发

结果：**没有任何 `@Trace` 属性变化能触发 build 函数重渲染**。

**修复方案**：将 `occupied` 改为 `@Trace`：
```typescript
// SnakeViewModel.ets 第 35 行
// 原：private occupied: Set<number> = new Set<number>();
// 改：
@Trace private occupied: Set<number> = new Set<number>();
```

每次 `stepOnce()` 中 `this.occupied = this.rules.occupancy(this.snake)` 整体替换引用，`@Trace` 能检测到引用变化并触发重渲染。

---

### P0-2 2048 棋盘渲染出错（确认 Bug）

**现象**：棋盘方块位置错乱、动画异常或方块消失。

**根因**：`Game2048ViewModel.board` 初始值为空数组 `[]`，在 `aboutToAppear()` 中才通过 `startGame()` 初始化为 4×4 棋盘。但 `@Local viewModel` 在组件构造时执行 `new Game2048ViewModel()`，此时 `board = []`。

`rebuildTiles(true)` 在 `aboutToAppear()` 中调用 `viewModel.startGame()` 之后执行，此时 `board` 已是有效 4×4 数组，`cellValue(r, c)` 不会越界。但关键问题在于 **`cellValue` 方法返回 `this.board[r][c]`，而 `board` 是 `@Trace` 二维数组**——在 ArkTS V2 中，`@Trace` 只跟踪顶层引用变化，`this.board[r][c]` 读取的是嵌套元素，框架不会为这种读取建立依赖追踪。

虽然 `rebuildTiles()` 在事件处理器中同步读取 `board`（不涉及依赖追踪），且通过 `this.tiles = next`（`@Local`）触发重渲染，但 **build 函数中 `ForEach(this.tiles, ...)` 的键函数 `(tile: TileData) => tile.id.toString()` 可能导致 ForEach 无法正确识别方块身份变化**——当 `rebuildTiles` 为移动的方块复用旧 id 时，ForEach 认为组件未变化，仅更新属性。但 `.animation()` 修饰符对 `offset` 变化做隐式插值时，如果 `renderGroup(true)` 缓存了旧位图，可能出现缓存失效延迟导致方块位置闪烁/错位。

**更核心的问题**：`rebuildTiles` 中 `sourceAt()` 依赖 `lastSources`（非 `@Trace` 的 private 字段）。虽然这在事件处理器中同步读取没有时序问题，但 `spawnRow`/`spawnCol`（`@Trace`）在 `rebuildTiles` 中被读取以判断新块位置——如果框架批处理状态更新，`rebuildTiles` 可能在 `spawnRow/spawnCol` 尚未生效时执行，导致新块判定错误。

**修复方案**：

1. **确保 `board` 初始化为有效空棋盘**（而非空数组），避免任何边界情况下 `board[r][c]` 越界：
```typescript
// Game2048ViewModel.ets 第 19 行
// 原：@Trace board: number[][] = [];
// 改：
@Trace board: number[][] = [[0,0,0,0],[0,0,0,0],[0,0,0,0],[0,0,0,0]];
```

2. **移除 `renderGroup(true)`**，避免位图缓存与 `.animation()` 隐式动画冲突：
```typescript
// Game2048Page.ets 第 268 行
// 删除 .renderGroup(true)
```

3. **将 `lastSources` 改为 `@Trace`**，确保 `sourceAt()` 的读取能被框架正确追踪：
```typescript
// Game2048ViewModel.ets 第 33 行
// 原：private lastSources: number[] = [];
// 改：
@Trace private lastSources: number[] = [];
```

---

### P0-3 2048 滑动后「复用方块」不更新渲染（2026-09-22 模拟器实测确认）

**现象**（模拟器受控实验，通过 uitest dumpLayout 与截图双重确认）：

- 滑动合并：两个相邻的 4 下滑合并，**得分正确 0→8**（数据层正常），但棋盘上**不出现 8**，旧 4 停留在原位置渲染；新 spawn 的 2 与旧 4 渲染在同一格子上（两个 Text 节点 bounds 完全重叠）。
- 普通移动：开局 2@(2,2) 下滑后，数据层新块正常生成，但**移动的 2 从渲染中消失**；位置不变的 2@(4,3) 与新块渲染正常。

**根因**：`TileData` 是普通 `interface`。V2（`@ComponentV2`）中 ForEach 的 diff 规则是：**key 相同（id 复用）的项不会重新执行 itemGenerator**——即使数组被整体替换、item 属性已变，复用组件的 Text 内容、offset、backgroundColor 都停留在旧值。只有新增 key（新 spawn 的块）和删除 key（被合并吃掉的块）会触发组件创建/销毁。

这解释了所有实测现象：
- 移动块（id 复用 + row/col 变化）→ 组件不更新 → 停在旧位置或视觉上"消失"（被新块覆盖判定吞掉）。
- 合并块（id 复用 + value 4→8 + 位置变化）→ 组件不更新 → 8 永远不显示，旧 4 卡在原格。
- 不变块（id 复用但属性没变）→ 看起来正常。
- 新块（新 id）→ 正常创建渲染。

**为什么开局/新块是正常的**：开局 `rebuildTiles(true)` 与每次滑动后的 spawn 块都分配新 id → ForEach 视为新组件 → 正常渲染。

**修复方案**（V2 正确姿势：稳定组件 + @Trace 原地更新，同时保住 `.animation()` 的滑动插值）：

1. `TileData` 从 `interface` 改为 `@ObservedV2 class`，可变字段加 `@Trace`：
```typescript
@ObservedV2
export class TileData {
  readonly id: number;
  @Trace value: number;
  @Trace row: number;
  @Trace col: number;
  @Trace scale: number;
  constructor(id: number, value: number, row: number, col: number, scale: number) { ... }
}
```

2. `rebuildTiles` 从「替换对象」改为「原地更新」：
   - 复用块：直接 `old.row = r; old.col = c; old.value = value; old.scale = ...`（@Trace 触发组件内属性更新，`.animation()` 自动插值 offset/scale/背景色）。
   - 注意：`merged` 判定必须在 `old.value = value` **之前**用旧值计算。
   - 新块：`new TileData(...)` push；被合并吃掉的旧块从数组移除（数组仅在增删时替换）。
   - 非 merged 复用块 `scale` 强制归 1，处理上次弹动被打断的遗留状态。

3. `settleScales` 从「创建新对象」改为「直接改块对象的 scale」（@Trace 触发 + 隐式插值回落），签名从 `ids: number[]` 改为持有块引用。

4. ForEach 键函数保持 `tile.id.toString()` 不变（稳定身份是滑动动画的前提）。

---

### P1-1 俄罗斯方块 — piece 变化时 cellMark 依赖追踪可能失效

**现象**：方块下落时格子颜色可能不更新。

**根因**：`TetrisViewModel.cellMark(r, c)` 访问 `this.board`（`@Trace`）和 `this.piece`（`@Trace`）。当 `piece` 变化时（每 tick 下落一格），build 函数应能检测到依赖。但 `piece` 是 `ActivePiece | null` 类型，每次 `drop()` 中 `this.piece = new ActivePiece(...)` 创建新对象——`@Trace` 应能检测到引用变化。

**风险等级**：低。`piece` 每次 tick 都被重新赋值（新对象），`@Trace` 能检测到引用变化。但 `cellMark` 是方法而非属性，如果 ArkTS V2 的依赖追踪不覆盖方法调用内部的属性访问，则可能失效。

**修复方案**：暂不修改，先验证 P0 修复后是否仍有问题。如果确认 `cellMark` 不刷新，则将 `cellMark` 的逻辑内联到 build 函数中，或改为 `@Trace` 计算属性。

---

### P1-2 扫雷 — revealed/flagged 二维数组的 @Trace 嵌套追踪

**现象**：揭开格子后画面可能不更新。

**根因**：`MinesweeperViewModel` 的 `revealed` 和 `flagged` 是 `boolean[][]`（`@Trace`）。每次操作都整体替换引用（`this.revealed = result.revealed`），`@Trace` 应能检测到。但 `isRevealed(r, c)` / `isFlagged(r, c)` 是方法，返回 `this.revealed[r][c]` / `this.flagged[r][c]`——这是嵌套元素访问。

**风险等级**：低。整体替换引用后，`@Trace` 能检测到顶层引用变化，build 函数应能重渲染。

**修复方案**：暂不修改。

---

### P1-3 华容道 — grid 是 @Trace private，blockKind/blockLabel 通过方法访问

**现象**：移动棋子后画面可能不更新。

**根因**：`KlotskiViewModel.grid` 是 `@Trace private`，`blockKind(r, c)` 和 `blockLabel(r, c)` 通过 `this.grid[r][c]` 读取。每次 `moveBlock()` 中 `this.grid = this.rules.buildGrid(this.blocks)` 整体替换引用。

**风险等级**：低。整体替换引用后 `@Trace` 能检测到。

**修复方案**：暂不修改。

---

### P1-4 记忆翻牌 — cards 是 @Trace private，isFaceUp/isFlipped/isMatched 通过方法访问

**现象**：翻牌后画面可能不更新。

**根因**：`MemoryCardViewModel.cards` 是 `@Trace private`，`isFaceUp(idx)` 等方法通过 `this.cards[idx]` 读取。每次翻牌/匹配都整体替换 `cards` 引用。

**风险等级**：低。整体替换引用后 `@Trace` 能检测到。但 `flippedIdxs` 也是 `@Trace private`，`isAlreadyFlipped()` 方法读取它——这个方法只在 `flipCard()` 内部调用（非 build 函数），不影响渲染。

**修复方案**：暂不修改。

---

### P2-1 所有游戏 — cellValue/isXxx 方法在 build 函数中的依赖追踪

**通用问题**：所有游戏模块都通过 ViewModel 方法（如 `cellValue(r, c)`、`isRevealed(r, c)`、`isSnakeCell(x, y)`）间接读取 `@Trace` 属性。ArkTS V2 的依赖追踪机制是否覆盖方法调用内部的属性访问，文档未明确说明。

**风险等级**：中。如果依赖追踪不覆盖方法调用内部，则所有使用方法间接读取 `@Trace` 属性的游戏都可能存在刷新问题。

**验证方法**：修复 P0-1（贪吃蛇 occupied）后，如果贪吃蛇恢复正常，说明 `@Trace` 的依赖追踪确实覆盖方法调用内部——那么其他游戏也应正常。如果贪吃蛇仍然不刷新，则说明依赖追踪不覆盖方法调用，需要将所有间接读取改为直接读取。

**修复方案**：先修复 P0-1 并验证。如果确认依赖追踪不覆盖方法调用，则需要将所有游戏的 build 函数改为直接读取 `@Trace` 属性（而非通过方法间接读取）。

---

### P2-2 2048 — settleScales 中 tiles 整体替换可能打断 ForEach 复用

**现象**：方块弹动回落（scale 从 0.5/1.15 回到 1）时可能闪烁。

**根因**：`settleScales(ids)` 创建全新的 `TileData[]` 数组（每个元素都是新对象），然后 `this.tiles = updated`。ForEach 通过 `tile.id.toString()` 匹配旧组件，但由于对象引用全部变化，ForEach 可能判定为"全量更新"而非"增量更新"，导致组件销毁重建而非属性更新——`.animation()` 无法对重建的组件做隐式插值。

**修复方案**：改为只更新需要变化的元素，保持其他元素引用不变：
```typescript
private settleScales(ids: number[]): void {
    // 只更新 scale 变化的方块，其他保持原引用
    let changed = false;
    const updated: TileData[] = [];
    for (let i = 0; i < this.tiles.length; i++) {
        const t = this.tiles[i];
        let scale = t.scale;
        for (let k = 0; k < ids.length; k++) {
            if (ids[k] === t.id) { scale = 1; changed = true; break; }
        }
        if (scale !== t.scale) {
            updated.push({ id: t.id, value: t.value, row: t.row, col: t.col, scale: scale });
        } else {
            updated.push(t); // 保持原引用
        }
    }
    if (changed) { this.tiles = updated; }
}
```

---

### P2-3 贪吃蛇 — togglePause 不重启定时器

**现象**：暂停后恢复，蛇可能不动。

**根因**：`togglePause()` 只切换 `status`（PLAYING ↔ PAUSED），不停止/重启定时器。定时器回调 `stepOnce()` 中 `if (this.status !== GameStatus.PLAYING) { return; }` 会跳过暂停态——这是正确的。但 `setInterval` 的间隔是从上次回调算起，暂停期间定时器仍在跑（只是回调被跳过），恢复后下一次 tick 可能立即触发（如果暂停时间恰好是间隔的整数倍），导致蛇突然跳一格。

**风险等级**：低。不影响功能正确性，只是体验上可能感觉蛇"突然跳"。

**修复方案**：暂不修改。如果用户反馈体验问题，可在 `togglePause()` 中停止/重启定时器。

---

## 二、修复优先级

| 优先级 | 问题 | 涉及文件 | 修复方式 |
|--------|------|----------|----------|
| P0 | 贪吃蛇 occupied 非 @Trace | `SnakeViewModel.ets` | 加 `@Trace` |
| P0 | 2048 board 初始值空数组 | `Game2048ViewModel.ets` | 改初始值为 4×4 空棋盘 |
| P0 | 2048 renderGroup 与 animation 冲突 | `Game2048Page.ets` | 删除 `.renderGroup(true)` |
| P0 | 2048 lastSources 非 @Trace | `Game2048ViewModel.ets` | 加 `@Trace` |
| P0 | 2048 TileData 非 @ObservedV2 导致复用方块不更新 | `Game2048Page.ets` | 改为 @ObservedV2 class + 原地更新 |
| P0 | 2048 底色格 Stack 层叠只有第一行可见 | `Game2048Page.ets` | ForEach 用 Column 包裹 |
| P0 | GameResultDialog renderGroup(true) 导致按钮点击无效 | `GameResultDialog.ets` | 删除 `.renderGroup(true)` |
| P0 | GameResultDialog 自定义内容式 Button 点击无效 | `GameResultDialog.ets` | 改为 `Button(text)` 简单形式 |
| P0 | 贪吃蛇开局立即自动移动，1.8秒撞墙 | `SnakeViewModel.ets` / `SnakeModel.ets` | 等玩家按方向键再启动定时器；蛇初始3节 |
| P1 | 2048 settleScales 全量替换 | `Game2048Page.ets` | 只更新变化的元素 |
| P2 | 方法调用依赖追踪验证 | 所有游戏 | 已验证：@Trace 覆盖方法调用内部 |

---

## 三、2026-09-22 模拟器实测结果

### 已验证通过

| 游戏 | 测试项 | 结果 |
|------|--------|------|
| 首页 | 渲染、6张游戏卡片 | ✅ 通过 |
| 2048 | 4×4 网格布局、间距 | ✅ 通过 |
| 2048 | 滑动移动、合并、得分 | ✅ 通过 |
| 贪吃蛇 | 蛇身/食物渲染、界面刷新 | ✅ 通过 |
| 贪吃蛇 | "按方向键开始"提示 | ✅ 通过 |
| 贪吃蛇 | "再来一局"按钮点击 | ✅ 通过（修复后） |
| 贪吃蛇 | 蛇3节初始长度 | ✅ 通过 |
| 俄罗斯方块 | 渲染、方块堆积、控制按钮 | ✅ 通过（初步观察） |

### 新增修复（2026-09-22）

#### P0-4 GameResultDialog renderGroup(true) 导致按钮点击无效

**现象**：贪吃蛇游戏结束后，"再来一局"和"返回"按钮点击完全无响应（uitest uiInput click 命令执行成功但 UI 状态不变）。

**根因**：`GameResultDialog` 的 `build()` 函数中 `.renderGroup(true)` 将组件合成位图缓存，在 ArkUI V2 中位图缓存层拦截了触摸事件，导致 `onClick` 无法触发。

**修复**：删除 `.renderGroup(true)`（两种 cardStyle 都删）。

**涉及文件**：`entry/src/main/ets/components/GameResultDialog.ets`

#### P0-5 GameResultDialog 自定义内容式 Button 点击无效

**现象**：即使移除 `renderGroup(true)` 后，"再来一局"按钮（`Button() { Row() { SymbolGlyph + Text } }`）仍然点击无效，而"返回"按钮（`Button(text)`）点击正常。

**根因**：`Button() { Row() { ... } }` 自定义内容式 Button 在 ArkUI V2 中 `onClick` 事件无法被 `uitest uiInput click` 触发。虽然 `dumpLayout` 显示 Button 的 `clickable: true`，但点击事件没有传递到 `onClick` 回调。

**修复**：将"再来一局"按钮从自定义内容式改为简单文本形式 `Button(this.primaryText)`，与"返回"按钮保持一致。

**涉及文件**：`entry/src/main/ets/components/GameResultDialog.ets`

#### P0-6 贪吃蛇开局立即自动移动，1.8秒撞墙

**现象**：进入贪吃蛇页面后，蛇立即向右自动移动，从中心 (10,10) 出发只需9步（1.8秒）就撞墙死亡，玩家来不及反应。

**根因**：`aboutToAppear()` 调用 `startGame()` → `startTimer()` 立即启动 `setInterval`，蛇自动开始移动。经典贪吃蛇应该是等玩家按方向键后才开始移动。

**修复**：
1. `startGame()` 不再立即调用 `startTimer()`，改为设置 `started = false`
2. 新增 `@Trace started: boolean` 字段，玩家首次按方向键时 `turn()` 方法检测 `!started` → 启动定时器
3. `SnakeGamePage` 在 `!started` 时显示"按方向键开始"提示文本
4. 蛇初始长度从1节改为3节（`SnakeModel.initialSnake()`）

**涉及文件**：
- `entry/src/main/ets/viewmodel/SnakeViewModel.ets`
- `entry/src/main/ets/model/game/SnakeModel.ets`
- `entry/src/main/ets/pages/classic/SnakeGamePage.ets`

---

## 四、回归验证计划

1. **贪吃蛇**：启动游戏 → 显示"按方向键开始" → 按方向键后蛇开始移动 → 画面每 tick 刷新 → 蛇身/食物颜色正确 → 死亡后"再来一局"按钮可点击
2. **2048**：启动游戏 → 棋盘正确显示 2 个初始方块 → 滑动后方块平滑移动 → 合并方块弹动 → 新块弹入
3. **其他游戏**：逐一启动验证基本功能正常
4. **编译验证**：`hvigorw.js assembleHap` 零错误