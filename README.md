<div align="center">

# 🎮 LittleGames · 小游戏合集

**一款基于 HarmonyOS NEXT 的轻量级小游戏合集应用**

宇宙蓝 × 雪域灰 · 轻拟物设计 · 10 款精选小游戏 · 手机 / 平板双端适配

![HarmonyOS](https://img.shields.io/badge/HarmonyOS-NEXT-2D6CE8?style=for-the-badge)
![ArkTS](https://img.shields.io/badge/ArkTS-ArkUI_@ComponentV2-7A5AF8?style=for-the-badge)
![SDK](https://img.shields.io/badge/API-24_(6.1.1)-16205F?style=for-the-badge)
![Device](https://img.shields.io/badge/设备-Phone_∣_Tablet-0B1135?style=for-the-badge)
![Version](https://img.shields.io/badge/version-1.0.0-5C9AFF?style=for-the-badge)

</div>

---

## ✨ 应用简介

**LittleGames（小游戏合集）** 是一款原生 HarmonyOS 休闲游戏应用，收录了 **10 款经典小游戏**，涵盖「经典休闲」与「益智解谜」两大分类。应用采用统一的「宇宙蓝 × 雪域灰」设计语言，配合轻拟物质感与流畅动画，带来清爽一致的游戏体验。所有游戏的最高分与游玩次数自动本地持久化，重启应用后战绩依然保留。

## 🕹️ 游戏列表

### 🎯 经典休闲

| 图标 | 游戏 | 玩法说明 |
| :---: | :--- | :--- |
| 🐍 | **贪吃蛇** | 20×20 棋盘，虚拟方向盘操控，转向输入缓冲防误触，吃食物变长挑战高分 |
| 🧩 | **俄罗斯方块** | 经典 10×20 棋盘，七种方块旋转下落，消行得分，速度随分数递增 |
| 🔲 | **2048** | 4×4 滑动合并数字方块，带滑动动画，冲击 2048 目标 |
| 🐹 | **打地鼠** | 9 洞地鼠快速反应挑战，点击冒出的地鼠得分，考验手速 |
| 💣 | **扫雷** | 经典扫雷规则，翻开格子推理雷区，标记并排除所有地雷 |

### 🧠 益智解谜

| 图标 | 游戏 | 玩法说明 |
| :---: | :--- | :--- |
| 🔢 | **数独** | 标准 9×9 数独，唯一解校验、新题不重复，支持双指缩放与拖拽查看 |
| 🧩 | **滑动拼图** | 移动方块还原完整拼图，步数计时双指标 |
| 💠 | **华容道** | 经典横刀立马布局，移动棋子助曹操从出口逃脱 |
| 🎲 | **猜数字** | 根据 A/B 提示推理 4 位不重复数字密码，越少次数越强 |
| 🃏 | **记忆翻牌** | 翻开卡片寻找相同 Emoji 配对，考验记忆力与反应 |

> 全部游戏均支持 **简单 / 普通 / 困难** 难度体系、最高分记录与游玩次数统计。

## 🌟 核心功能

### 🏠 三大主页 Tab

- **⭐ 精选** — 品牌渐变 Banner + 热门推荐，按历史最高分智能排序精选游戏
- **🗂️ 分类** — 全部 / 经典休闲 / 益智解谜分类筛选，支持**实时搜索**（游戏名称与描述模糊匹配，输入即刷新），全部游戏按中文拼音智能排序
- **👤 我的** — 玩家卡片、游戏总数 / 最高分等数据统计、最高分排行榜

### 🎬 动效闪屏

品牌渐变深空背景 + 光斑拟物装饰，图标、标题、副标题分阶段入场动画，自然过渡进入主页。

### 💾 本地数据持久化

基于 `@kit.ArkData` Preferences 存储：

- 每款游戏的**最高分**自动记录并持久化
- **游玩次数**累计统计
- 应用重启后数据完整保留，写入失败不影响游戏流程

### 📱 响应式多端适配

- `GridRow` 断点栅格布局（320vp / 600vp / 840vp），列数随屏幕宽度自适应
- 媒体查询监听：≥840vp 自动切换平板宽屏版式
- 游戏棋盘按屏幕尺寸动态计算格子大小，安全区自动扩展

### 🎨 统一设计系统

- 自研 **Design Tokens** 体系：色彩 / 间距 / 圆角 / 阴影 / 字体全量令牌化
- 「宇宙蓝（`#2D6CE8`）× 极光紫（`#7A5AF8`）」品牌渐变 + 雪域灰底色
- 语义色资源定义于 `base`（亮色）/ `dark`（深色），**随系统深浅色模式自动适配**
- 通用游戏组件复用：`GameHeader`（对局信息栏）、`ControlPad`（虚拟方向盘）、`GameOverDialog`（结算弹窗）、`GamePanel`、`NumberKeyboard`

## 🛠️ 技术栈

| 项目 | 说明 |
| :--- | :--- |
| 平台 | HarmonyOS NEXT（runtimeOS: HarmonyOS） |
| 语言 | ArkTS（严格模式） |
| UI 框架 | ArkUI 声明式开发范式（`@ComponentV2` / `@Local` 状态管理） |
| 路由 | `router` 页面导航 |
| 数据 | `@kit.ArkData` Preferences 轻量持久化 |
| 国际化 | `@kit.LocalizationKit` intl.Collator 中文拼音排序 |
| 布局 | GridRow 断点栅格 + MediaQuery 媒体查询 |
| SDK | compileSdk / compatibleSdk / targetSdk 均为 `6.1.1(24)` |
| 设备类型 | phone、tablet |

## 📁 项目结构

```
LittleGames
├── AppScope/                        # 应用级配置（bundleName、版本、图标）
└── entry/src/main/
    ├── module.json5                 # 模块配置（Ability、设备类型、页面路由）
    ├── ets/
    │   ├── entryability/            # EntryAbility 应用入口
    │   ├── common/
    │   │   ├── DesignTokens.ets     # 设计令牌（色彩/间距/圆角/阴影/字体）
    │   │   └── GameConstants.ets    # 游戏分类/难度/状态枚举与接口
    │   ├── model/
    │   │   └── GameData.ets         # 游戏数据中心（最高分/次数持久化）
    │   ├── components/              # 通用组件
    │   │   ├── GameHeader.ets       #   对局信息栏
    │   │   ├── ControlPad.ets       #   虚拟方向盘
    │   │   ├── GameOverDialog.ets   #   结算弹窗
    │   │   ├── GamePanel.ets        #   游戏面板
    │   │   └── NumberKeyboard.ets   #   数字键盘
    │   └── pages/
    │       ├── SplashPage.ets       # 动效闪屏页
    │       ├── Index.ets            # 主页（精选/分类/我的）
    │       ├── ProfilePage.ets      # 我的页面
    │       ├── classic/             # 经典休闲：贪吃蛇/俄罗斯方块/2048/打地鼠/扫雷
    │       └── puzzle/              # 益智解谜：数独/滑动拼图/华容道/猜数字/记忆翻牌
    └── resources/
        ├── base/                    # 亮色模式资源（颜色/字符串/图标）
        └── dark/                    # 深色模式资源
```

## 🚀 快速开始

### 环境要求

- **DevEco Studio**（支持 HarmonyOS NEXT 的版本）
- **HarmonyOS SDK** API 24（6.1.1）
- 真机（HarmonyOS NEXT）或本地模拟器 / Previewer

### 构建运行

1. 使用 DevEco Studio 打开项目根目录
2. 等待 IDE 自动同步依赖（`hvigor` 构建体系，无第三方依赖）
3. 连接真机或启动模拟器
4. 点击 **Run ▶**（或 `hvigorw assembleHap`）即可安装运行

> 💡 也可在 IDE 中使用 Previewer 预览各页面 UI。

## 📄 说明

- 本应用为学习练手项目，所有游戏均为原创手写实现，无任何第三方依赖与网络权限
- Bundle Name：`com.littlegames.collection`

<div align="center">

**今天也要加油哦！10 款精选小游戏等你来挑战 ⭐**

</div>
