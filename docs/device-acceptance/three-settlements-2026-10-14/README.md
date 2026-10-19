# Mate 60 Pro 每款三次结算验收

> 历史验收范围为 89 款，当前产品已精简为 76 款。本目录的进度跨多个旧安装包，不能作为当前源码或当前 HAP 的完整验收。仓库保留本说明、历史报告、`progress.json` 与 `visual-reviews.json`；原始截图、布局、操作日志、识别中间文件及旧 HAP 保留在本地并由 `.gitignore` 排除。报告与进度时间不同时，以 `progress.json` 为准。

本目录记录 2026-10-14 对当前上架 89 款游戏的真机操作。入口、结算和重开来自手机实际界面，使用 HDC / UITest 正常触控；没有向应用注入分数、关卡、时钟或终局状态。成功和失败结算均计数，重开验证成功后才将该局写入 `progress.json`。

`progress.json` 是实时进度的依据。只有 `completedGames` 为 89、`settlements` 至少为 267，且图标和界面截图全部复核，才能声明本任务完成。运行器策略存在不代表已验证通过；`attempts` 中的失败可能是脚本定位问题、系统遮挡或产品问题，需要结合对应截图判断。

```powershell
node scripts/device-three-settlements.cjs status
node scripts/device-three-settlements.cjs run
# 仅补测指定游戏；已完成三次的游戏会跳过
node scripts/device-three-settlements.cjs run snake sudoku
```

默认设备为 `FMR0224521016052`。可通过 `LITTLEGAMES_ART_TARGET` 指定另一台设备，通过 `LITTLEGAMES_THREE_OUTPUT` 指定另一证据目录。启动时要求手机已解锁，应用已启动。本机 Codex 沙盒无法发现真实 USB HDC 连接，因此本次执行在沙盒外进行。

包基线为运行时签名 HAP 的 SHA-256；更换包须使用另一证据目录。包已用 API 24 原生构建，并通过 `hdc install -r` 覆盖安装，未卸载或清空手机数据。测试会通过正常游玩更新游戏统计和存档。

每款留存搜索结果图标、开局、三次结算、重开截图及同名 UI 树。`actions.jsonl` 记录截图和触控操作；`vision/` 是本地截图识别中间文件。图像策略将手机截图与公开的随包素材或题面参考图比较，再生成真实触控动作。FreeCell 搜索仅接收界面上的明牌，并输出正常移牌步骤。

`visual-review/` 是复核联系表，`visual-reviews.json` 记录已人工视觉复核的范围。联系表生成脚本不会自动标记视觉通过。截图只证明采样时的显示状态，不代表已经测量帧率或验证音频。

已观察到手机系统通知短暂遮挡游戏页头，导致一次打地鼠重开检查未完成；该次没有算作完整通过，已安排补测。旧的模拟器和桌面回归报告不计入本次真机结算数量。
