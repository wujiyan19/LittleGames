# 运动游戏局部素材可读性修复

日期：2026-10-09。依据本轮 `e14b3364…` 真机截图中实际可见的瓶身、主球、道路边线低对比，以及拔河背景人物变形。此次不操作手机、不构建、不修改 HAP；更新素材在重新构建和安装后仍需真机验收。

## 变更范围

| 游戏 | 具体变更 | 生产文件 |
| --- | --- | --- |
| 保龄球 | 瓶身使用已有暖白 `#FFF8E7`，增加独立无填充蓝灰轮廓 `#6386A8`，轮廓宽度从 2 提到 4 个 SVG 单位；保留瓶形、珊瑚颈条和落影 | base/dark `exp_pin.svg` |
| 台球、迷你高尔夫 | 主球使用同一暖白色，增加独立无填充蓝灰圆形轮廓，宽度 2 → 4；保留球形、半径 39、亮斑和落影 | base/dark `exp_cueball.svg` |
| 双人拔河 | 移除专用背景右下被横向 banner 压扁的人物水印，保留背景和点纹；不改前景玩家和绳子 | base/dark `exp_board_tug.svg` |
| 单键漂移 | 原有两条动态原生 Line 的 `stroke` 改为专用颜色资源；浅色 `#6386A8`，深色 `#DAE8FF` | `ExpansionWorldBoard.ets`，base/dark `element/color.json` |

SVG 画布及场内图像尺寸、碰撞、模型、路径算法、漂移线宽 4、玩法控制和布局均未修改。`exp_pin` 的场内消费者只有保龄球；`exp_cueball` 由台球主球与高尔夫主球共用，没有影响其他游戏的彩色球。拔河背景为专用资源。

`scripts/generate-expansion-art.cjs` 同步上述图形变化，并支持传入资源后缀定向输出，避免重新生成全目录及图标、选择器、manifest。此次实际执行：

```text
node scripts/generate-expansion-art.cjs pin cueball board_tug
```

共 10 个生产文件：生成器 1、场景中两条颜色引用 1、颜色 JSON 2、SVG 6。相对本次保存的源文件快照，整个 base/dark media 目录只改变这 6 个 SVG，详见 [文件范围和 HAP 哈希](E:/lianxi/LittleGames/docs/art/sports-readability-2026-10-09/scope-check.json)。`before/` 保存 10 个生产源文件的修改前版本。

## 本地前后预览

以下为实际 SVG 的本地渲染；漂移行使用现有 `roadPoint` 的 time=0 几何与对应颜色值作对照。它们不是新增手机截图，不代表真机通过；SVG 渲染器与设备表现可能不同。背景色来自当前 `board_bg`，球旁的小图按台球 77 px、高尔夫 58 px 节点尺寸示意。

![浅色素材修改前后](E:/lianxi/LittleGames/docs/art/sports-readability-2026-10-09/comparison-base.png)

![深色素材修改前后](E:/lianxi/LittleGames/docs/art/sports-readability-2026-10-09/comparison-dark.png)

## 验证

- `node --check scripts/generate-expansion-art.cjs` 通过。
- 现有 `scripts/test-expansion-art.cjs`：7/7 通过，覆盖已有 SVG 本地引用、素材映射与反馈生命周期；未新增镜像测试。
- 本地预览检查两主题瓶身、主球轮廓清楚；漂移线与场地有明显颜色区别，拔河背景不再有人物变形。
- 签名 HAP SHA256 仍为 `e14b33644f6a0f72964c96e56f0a692c70680db11437152601f9a241e4911757`；未签名仍为 `a8a1b8802a45f6802a955b9e85f30a04cb959d5f125b003e8f6b66b5f43ab7e6`。

待新版真机检查：保龄球瓶身、台球/高尔夫主球在两主题中的识别程度，漂移动态边线及拔河 banner。当前手机继续验收原基线包。
