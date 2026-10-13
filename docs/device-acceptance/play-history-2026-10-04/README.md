# 精选页全部游玩记录

日期：2026-10-04。精选页「最近游玩」保留最近 5 款快捷入口，新增「查看全部」。详情页展示所有已玩游戏，每款游戏只出现一次，按最近一次开局时间降序排列，可直接点开再玩，并显示游戏简介、最近游玩时间和累计时长。

新时间戳通过本地 Preferences 持久化；旧最近列表、已玩标记、累计时长和旧次数记录合并保留。旧版本没有保存日期的记录显示「时间未记录」，沿用原最近顺序排在有日期的记录之后。清空游玩数据也会清除日期，原有偏好设置保留。

历史页直接绑定主页的响应式记录数组，返回时通过 NavDestination.onShown 刷新，避免全局 Builder 按值参数闭包持有旧数组。日期使用系统 Locale 和 Intl.DateTimeFormat；非法日期回退为未知时间。接续导航支持「历史 → 游戏 → 设置 → 关于」。

API 24 `assembleHap` 构建通过。相关自动回归共 282 项通过：完整历史 10/10、时长 34/34、接续 76/76、已有模型与性能检查 162/162；差异空白检查通过。

最终签名包 SHA-256：`dfb6a2863d452bb7ca2c6e48730ac0a2037433730ea53643cd5def6afab41568`。已安装至平板 `49X0224C24001554`，横屏检查与证据见 [final/summary.json](final/summary.json)：

- 36 款已有游戏均可滚动访问，超过首页预览的 5 款；记录没有重复。
- 从较老的「打地鼠」记录进入游戏，返回历史页后该记录移到首位并显示新日期；共 36 款保持不变，精选页首项同步。
- 结束进程并重新启动，记录总数、首项、日期和时长一致。
- 深色模式显示正常，原主题已恢复，最终留在历史页。

最终包截图：[全部记录](final/tablet-history-initial.jpeg)、[列表底部](final/tablet-history-bottom.jpeg)、[重玩后排序](final/tablet-history-replayed-first.jpeg)、[重启恢复](final/tablet-history-relaunched.jpeg)、[深色](final/tablet-history-dark.jpeg)、[恢复原主题](final/tablet-history-restored.jpeg)。目录根部的截图与 summary 属于日期格式调整前的候选包，只保留为过程记录；最终结果以 `final/` 为准。

验收通过正常 UI 打开了游戏，产生正常的最近游玩记录。没有清除设备上的既有游玩数据。
