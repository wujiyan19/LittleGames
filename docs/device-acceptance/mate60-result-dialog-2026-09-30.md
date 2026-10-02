# Mate 60 Pro 结算弹窗背景修复

日期：2026-09-30。设备 Mate 60 Pro / 7.0.0.709 SP6，设备 API 26；应用 1.0.0 / API 24 Debug。

**已复现并修复结算卡片背景透出棋盘的问题。新包已覆盖安装，浅色、深色的胜利、平局、失败及退出确认均完成真机复测。原主题、难度和开关已核对恢复，手机回到精选首页。**

## 原因与修复

`GameResultDialog` 的 `cardStyle = true` 分支使用 `SemanticColors.surface`，实际指向系统组件常规填充色。真机上该背景明显透出棋子，文字与棋盘重叠；该分支还缺少整页遮罩。另一分支已有应用实色背景，因而不同游戏的结算效果不一致。

两种样式现共用整页遮罩和应用 `surface` 实色资源：浅色 `#FFFFFF`，深色 `#182257`，均完全不透明。`cardStyle` 保留紧凑内容间距。遮罩接收点击，防止触发底层棋盘或重开按钮。退出确认卡片也改用相同实色资源。

修改：[结算组件](../../entry/src/main/ets/components/GameResultDialog.ets)、[退出确认组件](../../entry/src/main/ets/components/ExitConfirmDialog.ets)。未修改游戏规则和存档格式。

## 真机复测

| 检查 | 浅色 | 深色 |
| --- | --- | --- |
| 井字棋胜利、平局：卡片不透棋子，文字与按钮可读 | 通过 | 通过 |
| 结算时点击遮住的顶部重开按钮：仍保持结算界面 | 通过 | 通过 |
| 再来一局恢复空棋盘、玩家 1 回合；结算退出返回列表 | 通过 | 通过 |
| 扫雷踩雷失败：显示结算，重开旗数与计时清零 | 通过 | 通过 |
| 退出确认：实色卡片、取消留在游戏、确认返回列表 | 通过 | 通过 |

上述八张结算/确认截图已逐一目视复核。此次针对共享弹窗的两种样式及相关操作复测，没有重新完成全部 33 款游戏玩法验收。

## 对照与证据

- 浅色：[修复前](../screenshots/result-mate60-light-before.jpeg)、[胜利](../screenshots/result-mate60-light-win-after.jpeg)、[平局](../screenshots/result-mate60-light-draw-after.jpeg)、[失败](../screenshots/result-mate60-light-loss-after.jpeg)、[退出确认](../screenshots/result-mate60-light-exit-confirm-after.jpeg)。
- 深色：[修复前](../screenshots/result-mate60-dark-before.jpeg)、[胜利](../screenshots/result-mate60-dark-win-after.jpeg)、[平局](../screenshots/result-mate60-dark-draw-after.jpeg)、[失败](../screenshots/result-mate60-dark-loss-after.jpeg)、[退出确认](../screenshots/result-mate60-dark-exit-confirm-after.jpeg)。
- [检查点](mate60-result-dialog-progress.json)、[操作与截图记录](mate60-result-dialog-actions.jsonl)。每张截图对应 evidence/ 中同名布局记录。
- [设置恢复](../screenshots/result-mate60-settings-restored.jpeg)、[完成后首页](../screenshots/result-mate60-finished-home.jpeg)。

## 构建与包身份

DevEco 内置 SDK 编译成功：[构建日志](../../entry/build/mate60-result-dialog-build.log)。新包安装工具返回 `install bundle successfully`，覆盖安装保留应用数据。

当前包 SHA-256：`A2F49BC992711E20E608C5780E490C8B58376D4E1FB9D2C5221C95DCF8B62A93`。

上一轮修复包 SHA-256：`57DB0B700BBC7933BC61F5B2EA689E27DAC1D5348939BBC70C7A1640BB1A2ECF`。其五类缺陷及 33 款浅/深色入口记录保留在[上一轮报告](mate60-fix-2026-09-30.md)，不作为本次新包全部玩法重新验收的证据。
