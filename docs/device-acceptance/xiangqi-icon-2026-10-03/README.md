# 中国象棋图标辨识度调整

2026-10-03，将原先的单枚棋子与抽象线条改为木色棋盘、红「帅」与黑「将」两枚棋子。棋盘保留河界和九宫斜线，棋子文字由矢量笔画绘制，无外部字体依赖。默认与深色资源同步更新；图标生成脚本保存同一构图，重新生成不会恢复旧图。

素材预览见 [浅深色与小尺寸预览](../../art/xiangqi-icon-2026-10-03/preview.png)。两种主题的 SVG 渲染通过，边缘无裁切，42px 与 32px 小尺寸均保留可见内容，记录见 [render-check.json](../../art/xiangqi-icon-2026-10-03/render-check.json)。现有美术与反馈检查 7/7 通过，API 24 签名包构建通过。

最终包 SHA-256：`b9225c031f7e629d350a5ce41ba7368b9be7abf0f2d366c4423731e43d83c1b9`。已安装至 Mate 60 Pro（`FMR0224521016052`），精选页、分类搜索结果和「我的」最近列表在浅色与深色下共 6 组显示检查通过。恢复主题「跟随系统」后保留在精选页，共 7 项检查详见 [summary.json](summary.json)。

真机截图：[浅色精选](light-featured.jpeg)、[浅色分类](light-category.jpeg)、[浅色我的](light-profile.jpeg)、[深色精选](dark-featured.jpeg)、[深色分类](dark-category.jpeg)、[深色我的](dark-profile.jpeg)。
