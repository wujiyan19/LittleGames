# 新老游戏图标统一：真机验收

2026-10-03，手机 `FMR0224521016052`，系统 `ALN-AL00 7.0.0.109(SP6C00E105R5P3)`，应用 `com.littlegames.collection`，API 24 Debug 包。

**全部 100 款游戏已统一图标。最终包的 16 款代表游戏，浅色、深色各 16 次目录显示检查通过；首页、分类页、最近游戏和排行榜已复核。200 个图标资源渲染及 248 项相关回归通过，签名包已安装到手机。**

当前实拍：[32 个手机图标对照](final/catalog-icon-contact.png)。上两行浅色，下两行深色；每个图标从实际截图按 UI 布局中的底板坐标裁取，未替换图形。裁取记录见 [catalog-icon-crops.json](final/catalog-icon-crops.json)。

## 改动

原 13 款 PNG、Collection 20 款棋盘场景、Expansion 67 款带底框图标统一成透明矢量小模型。共用画布、材质、轮廓、光影、投影和留白，各玩法保留独立构图；深浅资源共 200 个。原 PNG 保留在[历史归档](../../art/legacy-icons/README.md)，不再进入应用包。

真机首次查看时，系统高饱和激活蓝色会弱化蓝色主体。最终使用图标专属底板：浅色 `#DDEBFA`、深色 `#24395A`，首页、分类、最近游戏和排行榜一致。32 次最终目录检查均从实际布局核对底板颜色与对应主题一致；蓝色积木、球和棋具的轮廓更清楚。

完整样式、100 款预览及生成维护方法见[统一图标交付](../../art/unified-icons.md)。

## 最终包

- 签名 HAP SHA-256：`f1c508642f0371387315f8c6b5fe224ab7936d1b3f91fc067f516c649c18adf2`。
- 大小 7,090,444 字节，DevEco 内置 SDK / API 24 构建成功，见 [build.log](final/build.log)。
- 包身份和安装信息见 [metadata.json](final/metadata.json)、[installed-final.json](final/installed-final.json)。
- 本轮结果与原始记录：[summary.json](final/summary.json)、[actions.jsonl](final/actions.jsonl)。

本目录根层记录初次统一图标包 `fa479fd9b7edb68f485b587203c16eaed836212867643b074810b22210992d6e` 的 32 次显示检查，使用旧系统蓝色底板。[初次拼图](catalog-icon-contact.png)保留当时画面。`final/` 为专用主题底板修复包的独立复测，不将两个包的检查次数合并为单包 64 次验收。

## 代表游戏与页面

| 原 13 款 | Collection | Expansion |
| --- | --- | --- |
| 贪吃蛇、俄罗斯方块、2048、打地鼠、记忆翻牌 | 井字棋、五子棋、心算十题、顺序记忆、信号反应 | 方块拼填、倒水排序、切水果、国际象棋、掼蛋、家居装饰 |

每款均通过分类搜索展示实际图标，再分别截图深浅主题。目录中“全部 100”仍显示正确；正常进入贪吃蛇、井字棋、切水果及掼蛋形成混合最近记录，用于并排比较旧、新游戏图标。验证产生的正常进入次数与最近记录保留。

| 页面 | 浅色最终画面 | 深色最终画面 |
| --- | --- | --- |
| 精选首页 | [浅色](final/light-featured.jpeg) | [深色](final/dark-featured.jpeg) |
| 分类页 | [浅色](final/light-category.jpeg) | [深色](final/dark-category.jpeg) |
| 最近游戏及排行榜 | [浅色](final/light-profile.jpeg) | [深色](final/dark-profile.jpeg) |

设备检查脚本：[device-game-icons.cjs](../../../scripts/device-game-icons.cjs)。仅使用实际 UI 输入、布局及屏幕截图，没有注入应用状态。

## 回归与收尾

200/200 SVG 渲染、透明边缘无裁切和 42px 可见主体检查通过，[素材渲染记录](../../art/game-icon-render-check.json)。美术检查 7/7、Collection 回归 82/82、性能及设置回归 159/159，共 248 项通过，见[美术](../../art/icon-checks-2026-10-03/test-expansion-art.log)、[Collection](../../art/icon-checks-2026-10-03/test-collection.log)、[性能及设置](../../art/icon-checks-2026-10-03/test-performance.log)。

设置恢复核对记录见[原设置](final/original-settings.json)、[恢复后布局](final/settings-restore.json)及 [summary.json](final/summary.json)。主题为“跟随系统”，记住难度关闭，震动反馈与退出确认开启；应用回到[精选首页](final/finished-home.jpeg)，手机保留最终包。

本轮验收关注图标。桌面覆盖全部 100 款双主题资源，手机覆盖 16 款代表目录图标及三个页面；不据此宣称最终包全部 100 款玩法、所有设备/窗口或长局性能已验收。
