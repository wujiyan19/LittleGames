# UI 优化方案 — 2026-09-21

## 概述

对 LittleGames 应用进行全面 UI 优化，覆盖 5 个维度：游戏卡片视觉、首页横幅、交互动画、个人页内容、细节打磨。

---

## U1: 游戏卡片视觉升级（高优先级）

**现状问题：**
- 图标徽章为纯色 `primaryLight` 背景 + emoji 文字，10 个游戏中有两个 🧩 重复（tetris 和 slidepuzzle）
- 卡片无点击反馈动画，触感单调
- 卡片信息密度低，只有名称和描述

**优化方案：**

### U1.1 每个游戏独有渐变色徽章
为每个游戏定义独立的双色渐变，替代统一的 `primaryLight` 背景：

| 游戏 | 渐变起始 | 渐变结束 |
|---|---|---|
| snake | #2DD482 | #00B560 |
| tetris | #8675F8 | #5C3FD4 |
| 2048 | #FFAA33 | #FF6B6B |
| whackmole | #FF6B9D | #FF3D7F |
| minesweeper | #3399FF | #1A66CC |
| sudoku | #00D4B4 | #00A88A |
| slidepuzzle | #FF6B6B | #CC3333 |
| klotski | #5C9AFF | #2D6CE8 |
| guessnumber | #F5A623 | #D48806 |
| memorycard | #9A83FF | #7A5AF8 |

在 `DesignTokens.ets` 中新增 `GameBadgeColors` 类，在 `color.json` 中新增对应资源。

### U1.2 卡片点击 scale 动画
- 添加 `@Local isPressed: boolean` 状态
- 点击时 `scale: 0.95`，松开恢复 `1.0`
- 使用 `animateTo` 实现弹性回弹

### U1.3 卡片底部微信息
- 在描述文字下方增加一行：游玩次数 + 最高分（小字、灰色）
- 仅在 `playCount > 0` 时显示，避免新用户看到空数据

**涉及文件：**
- `common/DesignTokens.ets` — 新增 GameBadgeColors
- `resources/base/element/color.json` — 新增 badge 渐变色
- `resources/dark/element/color.json` — 深色变体
- `components/GameCard.ets` — 渐变徽章 + 点击动画 + 微信息

---

## U2: 首页横幅增强（高优先级）

**现状问题：**
- 横幅只有左侧文字 + 右侧星星图标，视觉单薄
- 缺少装饰性元素，与品牌"宇宙蓝"主题不呼应

**优化方案：**

### U2.1 横幅装饰光晕
- 在横幅背景上叠加两个模糊圆形光晕（参考 SplashLayer 的做法）
- 左下角蓝色光晕 + 右上角紫色光晕，增加深度感

### U2.2 横幅图标替换
- 将 `sys.symbol.star_fill` 替换为 `sys.symbol.gamecontroller`（与品牌一致）
- 增大图标尺寸至 56，增加视觉重量

### U2.3 横幅文字层级优化
- 标题字号从 `sizeSubtitle(18)` 提升到 `sizeTitle(20)`
- 副标题增加 `fontWeight: Medium`，提升可读性

**涉及文件：**
- `pages/home/FeaturedTab.ets` — Banner Builder

---

## U3: 交互反馈与动画（中优先级）

**现状问题：**
- 卡片点击无 scale 反馈（U1.2 已覆盖）
- 分类 Chip 切换无动画过渡
- Tab 切换无过渡效果

**优化方案：**

### U3.1 分类 Chip 切换动画
- Chip 选中/未选中状态切换时，背景色和文字色用 `animateTo` 过渡
- 添加 `@Local chipAnimScale` 状态，选中时轻微放大 `1.05`

### U3.2 排行榜列表项动画
- 列表项进入时依次淡入（`opacity: 0 → 1` + `translateY: 10 → 0`）
- 使用 `animateTo` + `delay` 实现错落入场

**涉及文件：**
- `pages/home/CategoryTab.ets` — CategoryChip
- `pages/home/ProfileTab.ets` — 排行榜列表

---

## U4: 我的 Tab 内容丰富化（中优先级）

**现状问题：**
- 用户卡片信息少（头像 + 名字 + 描述）
- 统计卡片只有 3 个数字，缺少视觉层次
- 排行榜列表项缺少分隔线和图标背景
- 没有"最近玩过"功能

**优化方案：**

### U4.1 用户卡片增强
- 在用户名下方增加"游戏达人"等级标签（根据游玩总次数计算等级）
- 等级规则：0次=新手、10次=玩家、50次=达人、100次=大师

### U4.2 统计卡片视觉优化
- 每个统计卡片增加顶部小图标（总数→网格图标、收藏→星图标、最高→奖杯图标）
- 数值字号增大到 `sizeHeadline(24)`，增强视觉冲击

### U4.3 排行榜列表项优化
- 排名数字增加圆形背景（前3名金/银/铜色，其余灰色）
- 游戏图标增加小圆形渐变背景（复用 U1.1 的 GameBadgeColors）
- 列表项之间增加细分隔线

### U4.4 最近玩过区域
- 在用户卡片和统计卡片之间，增加"最近玩过"横向滚动列表
- 显示最近 5 次游玩的游戏（按 playCount 降序取前 5）
- 每项为小圆形图标 + 游戏名，点击可跳转

**涉及文件：**
- `pages/home/ProfileTab.ets` — 全面增强
- `common/DesignTokens.ets` — 可能新增等级标签色

---

## U5: 整体配色与细节打磨（低优先级）

**现状问题：**
- 顶部品牌栏高度偏小，视觉存在感弱
- Tab 栏图标和文字间距偏紧
- 搜索栏阴影偏重

**优化方案：**

### U5.1 顶部品牌栏优化
- 增加品牌栏高度：`padding.top/bottom` 从 `base(16)` 提升到 `lg(20)`
- 标题字号从 `sizeTitle(20)` 提升到 `sizeSubtitle(18)` → 保持 20 但增加 `letterSpacing`

### U5.2 Tab 栏细节
- 图标和文字间距从 `2` 提升到 `4`
- 选中态图标尺寸从 `22` 提升到 `24`，增强选中反馈

### U5.3 搜索栏阴影减轻
- 搜索栏 `ShadowTokens.card` 替换为更轻的阴影 `radius: 8, offsetY: 2`

### U5.4 卡片圆角统一
- GameCard 圆角从 `lg(16)` 提升到 `xl(20)`，与横幅/弹窗保持一致

**涉及文件：**
- `pages/Index.ets` — TopBar + TabBuilder
- `pages/home/CategoryTab.ets` — 搜索栏
- `components/GameCard.ets` — 圆角

---

## 实施顺序

| 优先级 | 编号 | 标题 | 预计改动量 |
|---|---|---|---|
| 高 | U1 | 游戏卡片视觉升级 | 中（新增色资源 + GameCard 重写） |
| 高 | U2 | 首页横幅增强 | 小（仅 FeaturedTab Banner） |
| 中 | U3 | 交互反馈与动画 | 小（Chip + 列表动画） |
| 中 | U4 | 我的 Tab 内容丰富化 | 中（ProfileTab 较大改动） |
| 低 | U5 | 整体配色与细节打磨 | 小（多处微调） |

每项完成后独立构建验证，确保不引入编译错误。