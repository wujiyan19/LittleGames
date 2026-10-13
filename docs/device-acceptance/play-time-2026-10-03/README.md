# 游玩时长替代次数

2026-10-03。游戏卡片、精选最近列表和「我的」累计时长统一以小时显示，保留一位小数，例如 `1.2 小时`。底层保存累计毫秒，显示时四舍五入；短于 3 分钟的记录显示 `0.0 小时`。热门推荐改为按累计时长排序，玩家等级按累计 1、5、10 小时提升。

所有 100 款游戏通过 15 个游戏页面接入统一生命周期计时。使用 SDK 的 `systemDateTime.getUptime(TimeType.STARTUP, false)`，避免用户调整日期时间影响时长。仅在前台、对局进行中累计；暂停、退出确认、结果弹窗、后台、贪吃蛇及打砖块等待首次启动、数独生成与生成失败不计入。每 5 秒保存一次计时增量；暂停、退出、切后台和接续立即结算并刷盘。系统在前台直接杀进程时，尚未保存的最后一个检查周期可能丢失。

旧 `playCounts` 只迁移已玩游戏身份，保留最高分、最近顺序和设置，不估算历史时长。新字段为 `playTimesMs` 和 `playedGames`。清空战绩后，持久化空身份列表，后续启动不会重新读回旧次数；目录生成脚本同步更新字段。

API 24 签名构建通过，桌面回归共 676/676 通过：

- `scripts/test-play-time.cjs`：27 项，覆盖小时格式、迁移、清空后重启、异常数据、精确累计、暂停/结果/后台、页面切换、系统时间变化、接续和全部 ViewModel 活跃判定。
- `scripts/test-performance.cjs`：159 项。
- `scripts/test-continuation.cjs`：72 项。
- `scripts/test-collection.cjs`：82 项。
- `scripts/test-expansion.cjs`：336 项。

最终包 SHA-256：`00013ddfd32615369bfe2990fb08753daddbeab19df0107f352e95b25a446008`。已安装至 Mate 60 Pro（`FMR0224521016052`），完成 [summary.json](summary.json) 中 8 项检查：浅/深色各检查分类返回刷新、最近卡片小时格式和个人累计时长；恢复原主题「跟随系统」；结束进程后重启并比较个人页可见数据。原有 37 款已玩游戏与最高分 `3000 挑战分` 保留。

最终截图：[浅色精选](final-light-featured.jpeg)、[深色精选](final-dark-featured.jpeg)、[浅色分类](final-light-category.jpeg)、[深色分类](final-dark-category.jpeg)、[浅色我的](final-light-profile.jpeg)、[深色我的](final-dark-profile.jpeg)、[重启后的我的](final-profile-after-restart.jpeg)、[最终精选页](final-featured.jpeg)。`final-*` 对应最终包；其余截图和操作日志记录初版及定位过程。初次冷启动过早抓取了尚未加载的界面，等待页面加载后复核通过。

真机通过正常进入 2048 产生少量游玩时长，未注入或更改存档。真机显示值仍为 `0.0 小时`；精确毫秒累计、暂停/后台不计时及跨小时四舍五入由受控时钟逻辑回归验证，不能将这些检查描述为真机长时间计时验收。
