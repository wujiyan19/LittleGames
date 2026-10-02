# 玩趣盒：游戏盒子品牌图

用户于 2026-10-02 选定“游戏盒子”方案。原图由内置 image_gen 生成，保存为 `game-box-source.png`。主体为打开的白色盒子，包含蓝青色方块和圆形棋子，沿用蓝色背景。

使用 `scripts/generate-brand-assets.py` 仅按平台资源尺寸缩放原图：桌面及关于页使用 1024×1024 的 `app_icon.png`；系统启动窗口、首页横幅及空态使用 256×256 的 `brand_start_icon.png`。启动窗口通过原生 `startWindowAppIcon` 配置适配尺寸，不含标题和副标题，不叠加应用内启动页。

## 原始生成提示词

Use case: logo-brand. Generate a single polished mobile app icon concept for a Chinese offline minigame collection named 玩趣盒 (Play Box). The actual asset contains NO TEXT. Primary request: differentiate its identity from conventional game controller app icons by using a playful open toy box, with one geometric cube and one round checker rising from the opening. The box itself is the dominant, unmistakable silhouette, with a chunky rounded U-shaped front and subtly open lid. No gamepad silhouette, no plus-shaped directional pad, no group of four circular controller buttons. Style: exceptionally simple, premium flat vector-like app icon, strong negative space, just a few bold shapes, legible at 32px, no thin lines, no tiny game details. Keep the app's existing electric blue and cyan identity: electric-blue square full-bleed background with a very subtle blue/cyan corner gradient; a large warm-white symbol, modest cyan inset on the box. All four canvas corners filled, no exterior padding or device frame. Center the complete symbol with ample in-icon safety area, filling roughly 62 percent of the square. This is brand concept A, the most recommended route because box matches the name and varied pieces imply multiple games. No typography, letters, numerals, watermark, trademark, ribbons, photorealistic material, floating particles, heavy 3D, or drop-shadow.
