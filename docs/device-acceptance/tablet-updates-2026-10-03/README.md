# 最近游玩、象棋图标与时长的平板横屏检查

2026-10-03，在 WEB-W00 平板（HDC `49X0224C24001554`）上安装并检查当前改动。横屏实际应用宽度 2880px，屏幕 2880×1920px。检查使用真实界面输入、截图及 ArkUI 布局树，没有注入存档。

## 结论与修复

| 更新 | 横屏检查结果 |
| --- | --- |
| 精选最近游玩 | 五张卡片完整可见，图标、名称和一位小数的小时数未裁切；最新中国象棋位于首项，点击进入并退出后正常返回精选页。 |
| 中国象棋图标 | 精选和分类中浅、深色图标均完整显示；`Contain` 缩放保持棋盘及红帅、黑将的比例。 |
| 游玩时长 | 单款卡片和个人累计时长显示 `0.0 小时`，小时文字完整。存储和计时逻辑本轮未改变。 |
| 我的统计卡片 | 原来的两行在横屏中占用过多高度。改为 `GridRow/GridCol`：容器宽度达到 840vp 时四列，较窄时两列；卡片填满各自栅格。 |

对比：[调整前的横屏统计](initial-profile.jpeg)、[四列横屏统计](final-light-profile.jpeg)、[窄悬浮窗两列统计](final-narrow-profile.jpeg)。通过 [GridRow 官方文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-container-gridrow) 和本机 API 24 SDK 确认使用 `BreakpointsReference.ComponentSize`，响应实际容器宽度。

## 验证

最终签名包 SHA-256：`92bd5536573a51a17c04300fcc8b48c7bc5367ad183d7dd4877d2b0f4e6df9b1`。API 24 构建成功，已安装到上述平板。性能及设置回归 159/159、窗口计算回归 8/8 通过；`git diff --check` 通过。

[summary.json](summary.json) 记录 11 项设备检查：浅、深色各覆盖分类时长与图标、五个最近入口、入口点击返回、四张统计卡同排；恢复原主题「跟随系统」；窄悬浮窗两列统计；恢复原横屏全屏。

浮窗实际矩形 `[2026,243][2823,1659]`，约 797×1416px。两个统计标题处于第一排、另外两个处于第二排，布局树可见边界与原始边界一致。浮窗截图只保留应用矩形，系统桌面截图位于被忽略的构建目录。一次截图传输失败后重新抓取成功，不作为应用布局缺陷记录。

最终截图：[浅色精选](final-light-featured.jpeg)、[深色精选](final-dark-featured.jpeg)、[浅色分类](final-light-category.jpeg)、[深色分类](final-dark-category.jpeg)、[浅色我的](final-light-profile.jpeg)、[深色我的](final-dark-profile.jpeg)、[窄窗精选](final-narrow-featured.jpeg)、[恢复全屏](final-featured-restored-full.jpeg)。`initial-*` 对应修复前包 `00013ddfd32615369bfe2990fb08753daddbeab19df0107f352e95b25a446008`；`final-*` 对应最终包。

本轮针对上述三项更新，覆盖中文、当前系统字号、浅深色、横屏全屏及一个窄悬浮窗。没有执行最大字体、英文、任意分屏比例或全部游戏玩法验收。正常打开中国象棋新增了该游戏的已玩身份及少量真实时长，原主题和全屏状态已恢复，结束时停留在精选页。
