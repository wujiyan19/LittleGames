# 100 款游戏图标风格统一

2026-10-03。此前图标来自三套制作方式：原 13 款透明立体 PNG、Collection 20 款棋盘矢量场景、Expansion 67 款带独立底框的矢量图标。放在同一目录时，细节密度、比例和底框不一致。

全部 100 款现使用统一矢量系统，生成 `base`、`dark` 两套，共 200 个 SVG。

## 统一规范

- 120×120 透明画布，居中小模型、保留安全留白，投影位于同一基线。
- 同一套蓝、珊瑚、金、薄荷、紫色材质，统一轮廓粗细与左上高光。
- 去掉 Expansion 图标额外的独立底框；棋盘、卡片、车辆等保留各自的玩法形状。
- 原 13 款重新绘制蛇、地鼠、青蛙、数字块等主体，替换细节较多的 PNG。
- Collection 20 款保留棋盘、天平、汉诺塔等辨识线索，同时改用统一材质和尺寸。
- 深色版本调整纸张、木板、轮廓及投影；主体颜色保留辨识度。
- 首页、分类页、最近游戏和排行榜的图标底色统一使用 `SemanticColors.gameIconBackground`；专用资源提供浅蓝、深蓝灰版本，避免系统高饱和激活色弱化蓝色主体。

数字、问号、汉字提示以几何路径绘制；SVG 无字体、外部图片、滤镜及下载依赖。游戏目录 ID、资源名和玩法规则保持原样。

## 预览与验证

[浅色 100 款全览](game-icons-light.png) · [深色 100 款全览](game-icons-dark.png)

两张全览均已视觉复核，右下角显示各图标的 42px 缩小版本。这些是素材预览，实际手机画面与覆盖范围见[真机报告](../device-acceptance/unified-icons-2026-10-03/README.md)。

- 200/200 SVG 栅格化通过；透明边缘无裁切、42px 下均有有效可见主体，见 [render-check](game-icon-render-check.json)。
- 验证所有 100 款的深浅资源引用、统一画布、无重复 PNG、可解析的本地渐变，以及 100 种独立主体构图。
- 美术检查 7/7、Collection 回归 82/82、性能及设置回归 159/159，共 248 项通过，见 [美术](icon-checks-2026-10-03/test-expansion-art.log)、[Collection](icon-checks-2026-10-03/test-collection.log)、[性能及设置](icon-checks-2026-10-03/test-performance.log)。
- DevEco / API 24 构建通过并安装签名包到已连接手机，见[包身份及构建记录](../device-acceptance/unified-icons-2026-10-03/final/metadata.json)。

## 维护

[generate-game-icons.cjs](../../scripts/generate-game-icons.cjs) 是全部图标的唯一生成来源；[清单](game-icon-manifest.json)记录游戏和资源对应关系。该脚本重用已有 `exp_*` 对局图形、统一材质，并为旧游戏及需要区分的玩法绘制专用构图。

更新图标运行 `node scripts/generate-game-icons.cjs`；生成全览运行 `node scripts/preview-game-icons.cjs`，后者需提供 `sharp`。Collection / Expansion 对局美术生成器完成后同样调用统一入口，并同步清单中的图标尺寸，避免再次分成不同风格。

原 13 款 PNG 已移到 [legacy-icons/](legacy-icons/README.md) 保留历史版本。现有 Collection / Expansion 素材交付中的旧图标拼图保留原阶段画面；当前入口外观以本页全览和本轮真机截图为准。
