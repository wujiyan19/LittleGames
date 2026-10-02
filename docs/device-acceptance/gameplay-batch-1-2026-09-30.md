# Mate 60 Pro 玩法专项：批次 1

日期：2026-09-30。用户将玩法验收每批从两款增加到五款。本批完成贪吃蛇、打地鼠、打砖块、俄罗斯方块、跳一跳，五款的选定用例均通过，未发现本批用例失败或阻断。本批已停止，手机停留在分类页；下一批为信号反应、2048、消消乐、记忆翻牌、扫雷。

设备：Mate 60 Pro，用户提供系统 7.0.0.709 SP6。连接目标 `FMR0224521016052`。已安装应用报告 1.0.0、Debug、目标 API 24；本地签名包 SHA-256 与入口检查点一致：`5197B4A2F4ECDD0CC1DEF672A80B2254309F06EB9644F0773F05B2F643F3679C`。本批未修改应用代码、重新安装或清除数据。

## 用例与结果

| 游戏 | 实际操作及观察 | 结果 | 关键证据 |
| --- | --- | --- | --- |
| 贪吃蛇 | 点击右方向开始，向上转向后暂停；蛇由横向变为竖向，开始提示消失。两次暂停截图相隔 34.0 秒，蛇与食物格坐标一致。继续后撞上边界，结束结算 0 分；“再来一局”恢复 0 分与待开始提示，正常返回 | 本批用例通过 | [暂停](../screenshots/play-mate60-b1-snake-paused-a.jpeg)、[结束](../screenshots/play-mate60-b1-snake-over.jpeg)、[重开](../screenshots/play-mate60-b1-snake-restart.jpeg) |
| 打地鼠 | 暂停截图相隔 58.7 秒均为 28s。继续后命中得分 0→10→20→30；对已观察空洞点击，得分 30→25。倒计时归零后结算 25 分；重开后空击仍为 0 分，时间恢复 30s，正常返回 | 本批用例通过 | [命中后](../screenshots/play-mate60-b1-whack-score-paused.jpeg)、[空击](../screenshots/play-mate60-b1-whack-empty-minus5.jpeg)、[结束](../screenshots/play-mate60-b1-whack-over.jpeg)、[重开](../screenshots/play-mate60-b1-whack-restart-floor.jpeg) |
| 打砖块 | 左按钮移动挡板并发球；暂停截图相隔 6.1 秒，小球和挡板位置一致。继续后使用右按钮及横向拖动，击砖累计 40 分。三次掉球使生命 3→2→1→0，结束弹窗为得分 40；重开恢复 0 分、3 生命、第 1 关，最高分保留 40，正常返回 | 本批用例通过 | [第一次掉球](../screenshots/play-mate60-b1-brick-first-loss.jpeg)、[第二次掉球](../screenshots/play-mate60-b1-brick-second-loss.jpeg)、[结束](../screenshots/play-mate60-b1-brick-over.jpeg)、[重开](../screenshots/play-mate60-b1-brick-restart.jpeg) |
| 俄罗斯方块 | 暂停截图相隔 65.2 秒，活动方块四格坐标一致。继续与左右操作使方块每次横移一格，旋转改变 L 形朝向。加速下落后出现底部四个锁定格及新活动方块；连续落块堆满后结束，结算 0 分。重开清空堆积，仅保留四格新活动方块，级别 1、得分 0，正常返回 | 本批用例通过 | [左移](../screenshots/play-mate60-b1-tetris-left.jpeg)、[旋转](../screenshots/play-mate60-b1-tetris-rotate.jpeg)、[落块](../screenshots/play-mate60-b1-tetris-drop.jpeg)、[结束](../screenshots/play-mate60-b1-tetris-over.jpeg)、[重开](../screenshots/play-mate60-b1-tetris-restart.jpeg) |
| 跳一跳 | 长按游戏区并松手，成功落到下一台，当前及最高得分均变为 1，后续平台可见。随后短按蓄力不足，落空结束，结算 1 分。重开恢复当前 0 分，最高仍为 1，正常返回 | 本批用例通过 | [落台](../screenshots/play-mate60-b1-jump-landed.jpeg)、[结束](../screenshots/play-mate60-b1-jump-over.jpeg)、[重开](../screenshots/play-mate60-b1-jump-restart.jpeg) |

每款完成后保存[玩法检查点](mate60-gameplay-progress.json)。共 30 张原始截图，均有对应布局证据；操作观察日志为 [mate60-gameplay-actions.jsonl](mate60-gameplay-actions.jsonl)。暂停位置、倒计时、结算文字、落块格数及证据文件完整性均重新核对通过。

已实际查看五款主要操作画面及[五款结算总览](../screenshots/play-mate60-b1-results-overview.jpeg)，结算标题、得分与两个操作按钮可见。结束后查询应用故障记录返回 `no records found`；仅反映本次查询。

## 本批覆盖边界

本批为当前默认难度、中文、浅色、竖屏下的基础操作、部分暂停、结束和重开用例。5/5 指本批选定用例通过，不表示五款游戏全部规则路径或完整设备验收通过。

- 贪吃蛇：吃食物加分、自碰撞仍待检查。
- 俄罗斯方块：消行计分、连消升级、贴墙与顶边旋转仍待检查，本次 0 分结算不能替代计分验证。
- 打砖块：清空砖块、进入下一关和多关连玩仍待检查。
- 跳一跳：连续多次跳跃、平台补充和蓄力中后台恢复仍待检查。
- 全部五款：其它难度、后台恢复、重启后战绩保留、主题与字体、长局稳定性和性能仍待检查；本次 UI 注入不评估真人触控手感或帧率。

测试增加了游玩次数并保留测试数据：打地鼠本次结算 25 分，打砖块与跳一跳的重开画面分别显示最高 40 和 1；重启后的持久化尚未检查。后续先按 [README](README.md) 的玩法批次 2 接续；已测五款的待验收用例继续保留。
