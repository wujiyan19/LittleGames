# 设置完善与平板验证

本轮完成重开、换题及切换难度的进度保护，加入持久化声音开关，并固定游戏设置底部的“返回游戏”按钮。操作按钮不显示跳转箭头，玩法说明随展开状态切换上下箭头，应用设置入口保留右箭头。

## 安装包与设备

- 设备：WEB-W00，`49X0224C24001554`，2880 × 1920 横屏。
- 包：`entry/build/default/outputs/default/entry-default-signed.hap`。
- SHA-256：`1924c7a826dc53f5717da50629c0e4ad29b095747c057a0640e11c3f69a1b9ca`。
- 最终证据：[verified/summary.json](verified/summary.json)。其他目录保存中间版本的排查记录。

## 交互结果

| 检查 | 结果与证据 |
| --- | --- |
| 重开确认 | 猜数字已输入但未提交时触发确认；取消保留输入，确认清除进度；未操作的新局直接重开。[截图](verified/tablet-restart-confirm.jpeg) |
| 难度确认 | 切换不同难度提示开始新局，系统返回取消后保留难度和输入。[截图](verified/tablet-difficulty-confirm.jpeg) |
| 换题确认 | 数独填入数字后开始新游戏触发确认，取消保留题面与填入内容。[截图](verified/tablet-new-game-confirm.jpeg) |
| 声音开关 | 旋律游戏和应用设置同步；关闭后保留高亮顺序提示，重启应用仍为关闭；检查后恢复原选择。[游戏设置](verified/tablet-melody-sound-off.jpeg)、[视觉提示](verified/tablet-muted-melody-visual-cues.jpeg)、[应用设置](verified/tablet-app-settings-sound-off.jpeg) |
| 固定返回按钮 | 2048、数独、切水果展开玩法说明前后，按钮完整可见且位置相同。[2048](verified/tablet-2048-rules-fixed-footer.jpeg)、[数独](verified/tablet-sudoku-rules-fixed-footer.jpeg)、[切水果](verified/tablet-fruitslice-rules-fixed-footer.jpeg) |
| 暂停与恢复 | 打地鼠设置打开时计时冻结；手动暂停在关闭设置后保持，继续恢复运行。[暂停](verified/tablet-manual-pause.jpeg)、[继续](verified/tablet-resumed-settings.jpeg) |
| 深色模式 | 检查说明文本、动作和底部按钮，结束后恢复原主题。[截图](verified/tablet-dark-fixed-footer.jpeg) |

## 自动检查

- API 24 `assembleHap` 构建通过，已安装到上述平板。
- `test-game-settings.cjs`：9/9，覆盖未得分的 2048 移动、数独填入与擦除、单张翻牌、未提交输入、87 款组合/扩展游戏的初始进度、声音持久化与重置、异步播放静音/停止竞态和静音视觉播放。
- `test-performance.cjs`：160/160；`test-play-time.cjs`：34/34；`test-continuation.cjs`：73/73；`test-collection.cjs`：82/82；`test-expansion.cjs`：336/336。
- 上述脚本共 694 项检查通过，三套语言资源齐全，`git diff --check` 通过。

进度判断仅在打开设置时查询；取消确认不会触发重开，也不会恢复被设置面板暂停的游戏。声音默认开启，兼容旧设置数据；恢复默认设置会重新开启声音并保留战绩。当前有声音的旋律游戏提供就近开关，全部游戏可通过应用设置修改同一偏好。

本轮设备验证覆盖平板横屏；声音调用与异步静音保护由逻辑测试验证。自动存档、无障碍扩展及细化数据管理留待后续迭代。
