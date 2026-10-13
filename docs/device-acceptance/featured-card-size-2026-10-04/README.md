# 精选页游戏卡片尺寸统一

日期：2026-10-04。修复前平板横屏的游戏栅格宽度均为 680px，但简介自然换行及游玩时长的条件渲染使卡片高度在 258–322px 之间变化。统一共用 `GameCard` 的内容占位：标题一行、简介两行、时长一行；未游玩时隐藏时长并保留空间，文字宽度受栅格内容区约束。

使用原生 `Text.minLines` 保留行高，未固定卡片高度，保留系统字号缩放与自适应列宽。该接口从 API 22 起可用，已核对 [官方 Text 文档](https://github.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-arkui/arkui-ts/ts-basic-components-text.md#minlines22) 与本地 API 24 SDK 声明。

API 24 `assembleHap` 构建成功；现有 `test-play-time.cjs` 34/34 通过，差异空白检查通过。修改已安装到 WEB-W00 平板（HDC `49X0224C24001554`，2880×1920 横屏）。签名包 SHA-256：`82cac37bae2a9ead04afba86ab42dd593612c5e6337a3be13a709460910f1289`。

通过真实 UI 与布局树验证，结果见 [summary.json](summary.json)：

- 浅色、深色的 8 张新玩法卡片与 6 张热门推荐卡片均为 680×322px，包含一行/两行简介及已游玩/未游玩状态。
- 分类页可完整观察的 16 张卡片也均为 680×322px，共用组件布局正常。
- 恢复原主题“跟随系统”，设备留在精选页。

截图：[浅色精选](light-featured-top.jpeg)、[浅色热门推荐](light-featured-bottom.jpeg)、[深色精选](dark-featured-top.jpeg)、[深色热门推荐](dark-featured-bottom.jpeg)、[分类页](light-category.jpeg)、[恢复主题](restored-featured.jpeg)。手机、窄窗口与放大字号未在本轮设备上实测。
