# 生成逻辑修复真机验收（2026-10-02）

设备：华为 ALN-AL00，HDC 目标 FMR0224521016052。通过系统 UI 输入、实际布局树和屏幕图像验证，未读取应用私有模型或注入棋盘。安装时保留应用数据。

最终已安装签名 HAP SHA-256：`3C5C1C4028093D21E8F01DA3ECD3C416EAF85D06165D8D89C95E385F65403468`。

## 真机新发现并修复的问题

迷宫从普通 9×9 切换简单 7×7 后，界面复用旧格子的构建参数。行列数量改变了，但部分 Cell 的索引仍按旧列数计算，机器人不再出现在起点、出口显示在错误格子，边缘也显示成道路。模型连通性测试无法发现这类渲染问题。

CollectionPage 的外层行和内层列 ForEach 标识加入当前列数，尺寸改变时重新建立格子，显示、点击和实际模型索引保持一致。该组件还用于十字熄灯、色块归一、数字寻序、数字绘格等游戏。

[修复前：机器人消失、出口位置错乱](../screenshots/audit-20261002-maze-before-fix.jpeg)；[修复后简单棋盘](../screenshots/audit-20261002-maze-7-board.jpeg)。编译成功，生成逻辑回归 26/26 通过。之前全部 342 项逻辑回归保持记录在 [代码审计报告](../logic-audit-2026-10-02/README.md)。

另发现消消乐和打砖块没有接入三档难度回调，却显示可选择三档的按钮。已隐藏这两个无效入口；消消乐保留固定规则，打砖块继续随关卡增加难度。

## 本次实际通过的用例

已覆盖 **33 款游戏，58 组用例**。每组只宣称下表实际操作过的内容；随机源边界条件、上百关和大批量随机棋盘属于桌面逻辑回归，没有作为真机实测结果计数。

| 游戏/难度 | 实际操作与核对 | 画面证据 |
| --- | --- | --- |
| 迷宫寻路·简单 | 屏幕 7×7 地图全部道路连通；墙格不能穿越；进入死胡同 10 步并原路返回；合法相邻移动到出口，主路线 8 步；结算及同难度重新生成 | [截图](../screenshots/audit-20261002-maze-7-board.jpeg) / [截图](../screenshots/audit-20261002-maze-7-dead-end.jpeg) |
| 迷宫寻路·普通 | 屏幕 9×9 地图全部道路连通；墙格不能穿越；进入死胡同 12 步并原路返回；合法相邻移动到出口，主路线 12 步；结算及同难度重新生成 | [截图](../screenshots/audit-20261002-maze-9-board.jpeg) / [截图](../screenshots/audit-20261002-maze-9-dead-end.jpeg) |
| 迷宫寻路·困难 | 屏幕 11×11 地图全部道路连通；墙格不能穿越；进入死胡同 20 步并原路返回；合法相邻移动到出口，主路线 20 步；结算及同难度重新生成 | [截图](../screenshots/audit-20261002-maze-11-board.jpeg) / [截图](../screenshots/audit-20261002-maze-11-dead-end.jpeg) |
| 井字棋 | 已占格重复落子被拒绝；玩家 1 三连胜；九格填满平局；返回分类列表及退出确认 | [截图](../screenshots/audit-20261002-tictactoe-ready.jpeg) / [截图](../screenshots/audit-20261002-tictactoe-tictactoe-result.jpeg) |
| 五子棋 | 双方交替落子；横向五连结算；重开后纵向五连结算；返回分类列表及退出确认 | [截图](../screenshots/audit-20261002-gomoku-ready.jpeg) / [截图](../screenshots/audit-20261002-gomoku-gomoku-result.jpeg) |
| 落子四连 | 落子自动下沉；纵向四连获胜；满列再次落子被拒绝；返回分类列表及退出确认 | [截图](../screenshots/audit-20261002-fourline-ready.jpeg) / [截图](../screenshots/audit-20261002-fourline-fourline-result.jpeg) |
| 翻转棋 | 非法格点击被拒绝；按提示合法落子与翻子；完整对局终盘及胜负结算（32 手）；返回分类列表及退出确认 | [截图](../screenshots/audit-20261002-reversi-ready.jpeg) / [截图](../screenshots/audit-20261002-reversi-reversi-result.jpeg) |
| 取石子·普通 | 每手取 1～3 枚并交替回合；取完最后一枚结算胜方；返回分类列表及退出确认 | [截图](../screenshots/audit-20261002-nim-普通-ready.jpeg) / [截图](../screenshots/audit-20261002-nim-普通-nim-result.jpeg) |
| 汉诺塔·普通 | 较大盘不能叠在小盘上；全部圆盘移到柱 3；最少步数通关 15；返回分类列表及退出确认 | [截图](../screenshots/audit-20261002-hanoi-普通-ready.jpeg) / [截图](../screenshots/audit-20261002-hanoi-普通-hanoi-result.jpeg) |
| 数字寻序·普通 | 乱序点击不跳过目标；按 1～16 顺序完成；结算得分；返回分类列表及退出确认 | [截图](../screenshots/audit-20261002-schulte-普通-ready.jpeg) / [截图](../screenshots/audit-20261002-schulte-普通-schulte-result.jpeg) |
| 顺序记忆·普通 | 记忆阶段不能作答；按展示顺序回忆全部数字；错误顺序结束并提示失败；返回分类列表及退出确认 | [截图](../screenshots/audit-20261002-memorysequence-普通-ready.jpeg) / [截图](../screenshots/audit-20261002-memorysequence-普通-memorysequence-result.jpeg) |
| 心算十题·普通 | 从界面题目计算并作答十题；首题错误不加分并显示答案；其余九题正确，结算 1800 分；返回分类列表及退出确认 | [截图](../screenshots/audit-20261002-arithmetic-普通-ready.jpeg) / [截图](../screenshots/audit-20261002-arithmetic-普通-arithmetic-result.jpeg) |
| 算式比大小·普通 | 从界面题目计算并作答十题；首题错误不加分并显示答案；其余九题正确，结算 1800 分；返回分类列表及退出确认 | [截图](../screenshots/audit-20261002-compare-普通-ready.jpeg) / [截图](../screenshots/audit-20261002-compare-普通-compare-result.jpeg) |
| 数列推演·普通 | 从界面题目计算并作答十题；首题错误不加分并显示答案；其余九题正确，结算 1800 分；返回分类列表及退出确认 | [截图](../screenshots/audit-20261002-sequence-普通-ready.jpeg) / [截图](../screenshots/audit-20261002-sequence-普通-sequence-result.jpeg) |
| 二进制解码·普通 | 从界面题目计算并作答十题；首题错误不加分并显示答案；其余九题正确，结算 1800 分；返回分类列表及退出确认 | [截图](../screenshots/audit-20261002-binary-普通-ready.jpeg) / [截图](../screenshots/audit-20261002-binary-普通-binary-result.jpeg) |
| 补数求和·普通 | 从界面题目计算并作答十题；首题错误不加分并显示答案；其余九题正确，结算 1800 分；返回分类列表及退出确认 | [截图](../screenshots/audit-20261002-targetsum-普通-ready.jpeg) / [截图](../screenshots/audit-20261002-targetsum-普通-targetsum-result.jpeg) |
| 记忆缺项·普通 | 从界面题目计算并作答十题；首题错误不加分并显示答案；其余九题正确，结算 1800 分；返回分类列表及退出确认 | [截图](../screenshots/audit-20261002-missing-普通-ready.jpeg) / [截图](../screenshots/audit-20261002-missing-普通-missing-result.jpeg) |
| 信号反应 | 信号前抢按判失败；等待信号…变更后点击结算反应时间；返回分类列表及退出确认 | [截图](../screenshots/audit-20261002-reaction-ready.jpeg) / [截图](../screenshots/audit-20261002-reaction-reaction-early.jpeg) |
| 数字绘格·普通 | 空白答案检查提示调整；按行列连续数字填格；合法行列答案完成挑战；返回分类列表及退出确认 | [截图](../screenshots/audit-20261002-nonogram-普通-ready.jpeg) / [截图](../screenshots/audit-20261002-nonogram-普通-nonogram-result.jpeg) |
| 猜数字·普通 | 重复数字被拒绝；未填满提交不消耗次数；删除键撤销末位；根据界面 A/B 提示推理，5 次猜中；再来一局重置尝试记录；返回分类列表及退出确认 | [截图](../screenshots/audit-20261002-guessnumber-普通-ready.jpeg) / [截图](../screenshots/audit-20261002-guessnumber-普通-guessnumber-win.jpeg) |
| 滑动拼图·简单（完整通关） | 非相邻方块点击不移动；切换简单难度，按屏幕数字还原完整 3×3 拼图；通关步数 20；重开重新打乱并清零步数；返回分类列表及退出确认 | [截图](../screenshots/audit-20261002-slidepuzzle-普通-ready.jpeg) / [截图](../screenshots/audit-20261002-slidepuzzle-普通-slidepuzzle-win.jpeg) |
| 记忆翻牌·普通 | 翻开图案；不匹配卡牌延迟盖回；依据实际翻面图案找齐 8 对；完成结算尝试次数；重开全部盖回；返回分类列表及退出确认 | [截图](../screenshots/audit-20261002-memorycard-普通-ready.jpeg) / [截图](../screenshots/audit-20261002-memorycard-普通-memorycard-mismatches.jpeg) |
| 2048 | 四方向滑动操作；同值合并、生成新块和计分；连续 48 次滑动仍在游戏页；顶部重新开始重置棋盘；返回分类列表及退出确认 | [截图](../screenshots/audit-20261002-2048-ready.jpeg) / [截图](../screenshots/audit-20261002-2048-2048-merged.jpeg) |
| 华容道·简单 | 选择棋块并通过方向键移动；按显示布局把曹操移至底部出口；通关 5 步及重开；返回分类列表及退出确认 | [截图](../screenshots/audit-20261002-klotski-简单-ready.jpeg) / [截图](../screenshots/audit-20261002-klotski-简单-klotski-win.jpeg) |
| 华容道·普通 | 选择棋块并通过方向键移动；按显示布局把曹操移至底部出口；通关 9 步及重开；返回分类列表及退出确认 | [截图](../screenshots/audit-20261002-klotski-普通-ready.jpeg) / [截图](../screenshots/audit-20261002-klotski-普通-klotski-win.jpeg) |
| 华容道·困难 | 选择棋块并通过方向键移动；按显示布局把曹操移至底部出口；通关 116 步及重开；返回分类列表及退出确认 | [截图](../screenshots/audit-20261002-klotski-困难-ready.jpeg) / [截图](../screenshots/audit-20261002-klotski-困难-klotski-win.jpeg) |
| 数独·简单 | 实际题面提示数 45，独立求解确认唯一解；切换后重开保持本难度题面；原题数字不能修改；填入和擦除数字；按实际题面求解并填完 81 格；完成结算及生成新题；返回分类列表及退出确认 | [截图](../screenshots/audit-20261002-sudoku-简单-ready.jpeg) / [截图](../screenshots/audit-20261002-sudoku-简单-same-difficulty-restart.jpeg) |
| 数独·普通 | 实际题面提示数 29，独立求解确认唯一解；切换后重开保持本难度题面；原题数字不能修改；填入和擦除数字；按实际题面求解并填完 81 格；完成结算及生成新题；返回分类列表及退出确认 | [截图](../screenshots/audit-20261002-sudoku-普通-ready.jpeg) / [截图](../screenshots/audit-20261002-sudoku-普通-same-difficulty-restart.jpeg) |
| 数独·困难 | 实际题面提示数 25，独立求解确认唯一解；切换后重开保持本难度题面；原题数字不能修改；填入和擦除数字；按实际题面求解并填完 81 格；完成结算及生成新题；返回分类列表及退出确认 | [截图](../screenshots/audit-20261002-sudoku-困难-ready.jpeg) / [截图](../screenshots/audit-20261002-sudoku-困难-same-difficulty-restart.jpeg) |
| 扫雷·简单 | 插旗、取消与旗格不能揭开；首点及周围 3×3 安全揭开，中心为空白；界面雷数标记 8，三档设置正确；踩雷后立即结算并显示踩中的雷；重新开始旗数及时间清零 | [截图](../screenshots/audit-20261002-mines-8-board.jpeg) / [截图](../screenshots/audit-20261002-mines-8-safe-first.jpeg) |
| 扫雷·普通 | 插旗、取消与旗格不能揭开；首点及周围 3×3 安全揭开，中心为空白；界面雷数标记 10，三档设置正确；踩雷后立即结算并显示踩中的雷；重新开始旗数及时间清零 | [截图](../screenshots/audit-20261002-mines-10-board.jpeg) / [截图](../screenshots/audit-20261002-mines-10-safe-first.jpeg) |
| 扫雷·困难 | 插旗、取消与旗格不能揭开；首点及周围 3×3 安全揭开，中心为空白；界面雷数标记 14，三档设置正确；踩雷后立即结算并显示踩中的雷；重新开始旗数及时间清零 | [截图](../screenshots/audit-20261002-mines-14-board.jpeg) / [截图](../screenshots/audit-20261002-mines-14-safe-first.jpeg) |
| 滑动拼图·简单 | 棋盘 3×3，数字与空格恰好各出现一次；独立逆序数校验确认可还原；相邻方块移动及空格交换正确；重新生成 | [截图](../screenshots/audit-20261002-slide-3-board.jpeg) / [截图](../screenshots/audit-20261002-slide-3-move.jpeg) |
| 滑动拼图·普通 | 棋盘 4×4，数字与空格恰好各出现一次；独立逆序数校验确认可还原；相邻方块移动及空格交换正确；重新生成 | [截图](../screenshots/audit-20261002-slide-4-board.jpeg) / [截图](../screenshots/audit-20261002-slide-4-move.jpeg) |
| 滑动拼图·困难 | 棋盘 5×5，数字与空格恰好各出现一次；独立逆序数校验确认可还原；相邻方块移动及空格交换正确；重新生成 | [截图](../screenshots/audit-20261002-slide-5-board.jpeg) / [截图](../screenshots/audit-20261002-slide-5-move.jpeg) |
| 跳子独留·简单 | 选择棋子并越过相邻棋子；被跳棋子移除；最终只留一子，结算 4 步；返回分类列表及退出确认 | [截图](../screenshots/audit-20261002-peg-简单-ready.jpeg) / [截图](../screenshots/audit-20261002-peg-简单-peg-result.jpeg) |
| 跳子独留·普通 | 选择棋子并越过相邻棋子；被跳棋子移除；最终只留一子，结算 5 步；返回分类列表及退出确认 | [截图](../screenshots/audit-20261002-peg-普通-ready.jpeg) / [截图](../screenshots/audit-20261002-peg-普通-peg-result.jpeg) |
| 跳子独留·困难 | 选择棋子并越过相邻棋子；被跳棋子移除；最终只留一子，结算 6 步；返回分类列表及退出确认 | [截图](../screenshots/audit-20261002-peg-困难-ready.jpeg) / [截图](../screenshots/audit-20261002-peg-困难-peg-result.jpeg) |
| 色块归一·简单 | 相同颜色不消耗步数；连通区域扩展及步数变化；限制步数内全部色块归一（7 步）；返回分类列表及退出确认 | [截图](../screenshots/audit-20261002-flood-简单-ready.jpeg) / [截图](../screenshots/audit-20261002-flood-简单-flood-result.jpeg) |
| 色块归一·普通 | 相同颜色不消耗步数；连通区域扩展及步数变化；限制步数内全部色块归一（6 步）；返回分类列表及退出确认 | [截图](../screenshots/audit-20261002-flood-普通-ready.jpeg) / [截图](../screenshots/audit-20261002-flood-普通-flood-result.jpeg) |
| 色块归一·困难 | 相同颜色不消耗步数；连通区域扩展及步数变化；限制步数内全部色块归一（9 步）；返回分类列表及退出确认 | [截图](../screenshots/audit-20261002-flood-困难-ready.jpeg) / [截图](../screenshots/audit-20261002-flood-困难-flood-result.jpeg) |
| 十字熄灯·简单 | 点击格子翻转自身及十字邻格；按实际亮灯画面求解并熄灭全部灯；返回分类列表及退出确认 | [截图](../screenshots/audit-20261002-lights-简单-ready.jpeg) / [截图](../screenshots/audit-20261002-lights-简单-lights-board.jpeg) |
| 十字熄灯·普通 | 点击格子翻转自身及十字邻格；按实际亮灯画面求解并熄灭全部灯；返回分类列表及退出确认 | [截图](../screenshots/audit-20261002-lights-普通-ready.jpeg) / [截图](../screenshots/audit-20261002-lights-普通-lights-board.jpeg) |
| 十字熄灯·困难 | 点击格子翻转自身及十字邻格；按实际亮灯画面求解并熄灭全部灯；返回分类列表及退出确认 | [截图](../screenshots/audit-20261002-lights-困难-ready.jpeg) / [截图](../screenshots/audit-20261002-lights-困难-lights-board.jpeg) |
| 贪吃蛇·简单 | 点击方向按钮后小蛇移动；暂停后画面保持；切后台 2 秒返回保持暂停棋盘；继续游戏后画面推进；重新开始与返回 | [截图](../screenshots/audit-20261002-snake-简单-ready.jpeg) / [截图](../screenshots/audit-20261002-snake-简单-paused.jpeg) |
| 贪吃蛇·普通 | 点击方向按钮后小蛇移动；暂停后画面保持；切后台 2 秒返回保持暂停棋盘；继续游戏后画面推进；重新开始与返回 | [截图](../screenshots/audit-20261002-snake-普通-ready.jpeg) / [截图](../screenshots/audit-20261002-snake-普通-paused.jpeg) |
| 贪吃蛇·困难 | 点击方向按钮后小蛇移动；暂停后画面保持；切后台 2 秒返回保持暂停棋盘；继续游戏后画面推进；重新开始与返回 | [截图](../screenshots/audit-20261002-snake-困难-ready.jpeg) / [截图](../screenshots/audit-20261002-snake-困难-paused.jpeg) |
| 俄罗斯方块·简单 | 点击加速下落按钮，方块落下；暂停后画面保持；切后台 2 秒返回保持暂停棋盘；继续游戏后画面推进；重新开始与返回 | [截图](../screenshots/audit-20261002-tetris-简单-ready.jpeg) / [截图](../screenshots/audit-20261002-tetris-简单-paused.jpeg) |
| 俄罗斯方块·普通 | 点击加速下落按钮，方块落下；暂停后画面保持；切后台 2 秒返回保持暂停棋盘；继续游戏后画面推进；重新开始与返回 | [截图](../screenshots/audit-20261002-tetris-普通-ready.jpeg) / [截图](../screenshots/audit-20261002-tetris-普通-paused.jpeg) |
| 俄罗斯方块·困难 | 点击加速下落按钮，方块落下；暂停后画面保持；切后台 2 秒返回保持暂停棋盘；继续游戏后画面推进；重新开始与返回 | [截图](../screenshots/audit-20261002-tetris-困难-ready.jpeg) / [截图](../screenshots/audit-20261002-tetris-困难-paused.jpeg) |
| 打地鼠·简单 | 观察生成地鼠数量为 1–2，只点击实际出洞位置；击中后加分；暂停冻结倒计时和洞位；倒计时结束结算及重新开始 | [截图](../screenshots/audit-20261002-whackmole-简单-hit.jpeg) / [截图](../screenshots/audit-20261002-whackmole-简单-paused.jpeg) |
| 打地鼠·普通 | 观察生成地鼠数量为 1–2，只点击实际出洞位置；击中后加分；暂停冻结倒计时和洞位；倒计时结束结算及重新开始 | [截图](../screenshots/audit-20261002-whackmole-普通-hit.jpeg) / [截图](../screenshots/audit-20261002-whackmole-普通-paused.jpeg) |
| 打地鼠·困难 | 观察生成地鼠数量为 1–2，只点击实际出洞位置；击中后加分；暂停冻结倒计时和洞位；倒计时结束结算及重新开始 | [截图](../screenshots/audit-20261002-whackmole-困难-hit.jpeg) / [截图](../screenshots/audit-20261002-whackmole-困难-paused.jpeg) |
| 跳一跳·简单 | 真实长按蓄满后落到下一平台；连续 3 次成功跳跃、加分到 3；返回确认 | [截图](../screenshots/audit-20261002-jump-简单-ready.jpeg) / [截图](../screenshots/audit-20261002-jump-简单-three-landings.jpeg) |
| 跳一跳·普通 | 真实长按蓄满后落到下一平台；连续 3 次成功跳跃、加分到 3；返回确认 | [截图](../screenshots/audit-20261002-jump-普通-ready.jpeg) / [截图](../screenshots/audit-20261002-jump-普通-three-landings.jpeg) |
| 跳一跳·困难 | 真实长按蓄满后落到下一平台；连续 3 次成功跳跃、加分到 3；返回确认 | [截图](../screenshots/audit-20261002-jump-困难-ready.jpeg) / [截图](../screenshots/audit-20261002-jump-困难-three-landings.jpeg) |
| 打砖块 | 点击左右按钮移动挡板并发球；暂停后画面保持；切后台 2 秒返回保持暂停棋盘；继续游戏后画面推进；重新开始与返回 | [截图](../screenshots/audit-20261002-brickbreaker-ready.jpeg) / [截图](../screenshots/audit-20261002-brickbreaker-paused.jpeg) |
| 消消乐 | 固定规则游戏的标题只显示返回和重开；无三连交换还原且不扣步数；根据实际宝石画面完成 30 次有效交换，结算 1480 分；剩余步数归零结束；重开恢复得分 0、步数 30；返回分类及退出确认 | [截图](../screenshots/audit-20261002-match3-final-ready.jpeg) / [截图](../screenshots/audit-20261002-match3-final-invalid-swap.jpeg) |

迷宫三档都检查了屏幕中所有道路的连通性，并实际进入死胡同、原路返回、到达出口和重开。正常迷宫的岔路仍保留。

测试后补看了“我的”页面：[3000 挑战分单行显示，与游戏总数/已玩游戏卡片对齐](../screenshots/audit-20261002-profile-stats.jpeg)。手机已返回精选首页。

## 复核材料和范围

- [完整用例与实际棋盘数据](generation-audit-2026-10-02.json)
- 用例中的 packageHash 标明实际测试版本。部分用例在最后的无效难度按钮修复前完成；按钮修复仅影响消消乐和打砖块，这两款在最终安装版本重新验证。
- [按时间记录的操作/截图日志](generation-audit-2026-10-02-actions.jsonl)
- 原始布局证据保存在 evidence/audit-20261002-*.json；截图保存在 ../screenshots/audit-20261002-*.jpeg。
- 自动化脚本：scripts/device-generation-audit.cjs；使用真实界面独立求解，不预设手机随机棋盘。
- 不包含长时间性能、发热耗电、所有随机局和所有机型适配结论。打砖块第 38 关高速接球及 1–100 关布局由独立模型回归验证。
