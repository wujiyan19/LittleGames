# 鸿蒙应用接续与沉浸光感：模拟器验收

2026-09-26。**模拟器可覆盖的 UI 和运行检查通过；系统跨设备接续、真机沉浸材质效果仍待验证。**

## 环境与最终产物

- DevEco Studio 6.1.1，HarmonyOS 6.1.1 / API 24。
- LittleGamesPhone：Pura 90 Pro 配置，1256 × 2760；Mate X7 展开态：2210 × 2416。
- 最新工作区使用官方工具重新构建成功，未覆盖已有改动；两台模拟器均成功安装未签名调试 HAP。
- 最终包：`entry/build/default/outputs/default/entry-default-unsigned.hap`，3,168,507 字节。
- SHA-256：`0E5CACBE6B58EC58D0AB57D2C694C53ACE780221FAE5F928DD9F583AFA356431`。

## 实际通过的检查

| 检查 | 结果与证据 |
| --- | --- |
| 原生悬浮页签 | 精选、分类、我的均可切换；手机与展开态显示正常，游戏页不覆盖主页页签。[手机浅色](screenshots/accept-phone-home.jpeg)、[手机深色](screenshots/accept-phone-profile-dark-final.jpeg)、[展开态深色](screenshots/accept-fold-home-final-dark.jpeg) |
| 滚动到底与触控 | 分类末尾卡片完整露出，位于页签上方；两端点击末尾“消消乐”均能打开游戏。[手机列表](screenshots/accept-phone-category-bottom-dark.jpeg)、[展开态列表](screenshots/accept-fold-category-bottom-final-dark.jpeg)、[手机打开](screenshots/accept-phone-last-card-open.jpeg)、[展开态打开](screenshots/accept-fold-last-card-open.jpeg) |
| 个人页底部 | 展开态滚动到底后，第六条排行完整显示且避开悬浮页签。[截图](screenshots/accept-fold-profile-bottom-dark.jpeg) |
| 13 款游戏入口与返回 | 手机浅色与展开态深色各执行 13 条流程，共 26 条全部通过：搜索游戏、打开、检查标题、确认无主页页签覆盖、系统返回、必要时确认退出、回到分类页。逐款截图见下表。 |
| 主要棋盘视觉抽查 | 实际查看俄罗斯方块、2048、滑动拼图、数独、记忆翻牌的截图；本次抽查没有发现页头、棋盘与底部控制区重叠。 |
| 后台恢复抽查 | 手机 2048 实际滑动后切到桌面，再启动现有应用，三枚数字方块与得分保持。[恢复截图](screenshots/accept-phone-2048-resume.jpeg)。此项是同设备后台恢复，不是跨设备接续。 |
| 搜索空结果修复 | 实测发现资源对象拼接产生 `[object Object]`；改为解析资源字符串后拼接。重新构建、安装后显示“未找到「zzaccept」相关游戏”。[修复前](screenshots/accept-phone-search-empty-before.jpeg)、[修复后](screenshots/accept-phone-search-empty-fixed.jpeg) |
| 运行稳定性 | 两台设备查询 `hidumper -e --list com.littlegames.collection` 均返回 `no records found`；本次流程没有观察到崩溃或白屏。 |

逐款检查覆盖入口和返回，并不等同于全部难度通关、完整结算或跨端恢复验收。26 条流程执行后只修改了搜索空结果文字与一次启动材质诊断日志；最终包重新安装后，针对修改点及页签、底部触控进行了复测。

| 游戏 | 手机浅色 | 展开态深色 |
| --- | --- | --- |
| 2048 | [截图](screenshots/accept-phone-2048.jpeg) | [截图](screenshots/accept-fold-dark-2048.jpeg) |
| 猜数字 | [截图](screenshots/accept-phone-guess.jpeg) | [截图](screenshots/accept-fold-dark-guess.jpeg) |
| 打地鼠 | [截图](screenshots/accept-phone-whack.jpeg) | [截图](screenshots/accept-fold-dark-whack.jpeg) |
| 打砖块 | [截图](screenshots/accept-phone-brick.jpeg) | [截图](screenshots/accept-fold-dark-brick.jpeg) |
| 俄罗斯方块 | [截图](screenshots/accept-phone-tetris.jpeg) | [截图](screenshots/accept-fold-dark-tetris.jpeg) |
| 华容道 | [截图](screenshots/accept-phone-klotski.jpeg) | [截图](screenshots/accept-fold-dark-klotski.jpeg) |
| 滑动拼图 | [截图](screenshots/accept-phone-slide.jpeg) | [截图](screenshots/accept-fold-dark-slide.jpeg) |
| 记忆翻牌 | [截图](screenshots/accept-phone-memory.jpeg) | [截图](screenshots/accept-fold-dark-memory.jpeg) |
| 扫雷 | [截图](screenshots/accept-phone-mines.jpeg) | [截图](screenshots/accept-fold-dark-mines.jpeg) |
| 数独 | [截图](screenshots/accept-phone-sudoku.jpeg) | [截图](screenshots/accept-fold-dark-sudoku.jpeg) |
| 贪吃蛇 | [截图](screenshots/accept-phone-snake.jpeg) | [截图](screenshots/accept-fold-dark-snake.jpeg) |
| 跳一跳 | [截图](screenshots/accept-phone-jump.jpeg) | [截图](screenshots/accept-fold-dark-jump.jpeg) |
| 消消乐 | [截图](screenshots/accept-phone-match3.jpeg) | [截图](screenshots/accept-fold-dark-match3.jpeg) |

## 两项能力的验收边界

**沉浸光感**：两台设备的启动日志均为 `Floating tab material: 100; supported: []`。根据当前官方 SDK，100 为 `ADAPTIVE`，101 为 `IMMERSIVE`。模拟器未返回沉浸材质支持列表，应用正确进入自适应降级路径。截图可证明原生悬浮页签、明暗显示和内容避让正常，不能证明真机的光感折射、动态模糊或温控降效效果通过。

**应用接续**：安装包的系统查询确认 `EntryAbility.continuable = true`，实际启动未观察到设置接续状态失败日志。本轮没有建立同一华为账号的可信跨设备环境，没有通过系统入口触发 `onContinue` 或冷/热接续启动。因此，源端导出、系统传输、对端进度与导航恢复的完整链路仍待真机验收。本轮没有用普通启动或同设备后台恢复冒充接续成功。

此前及本轮重跑的桌面受控测试为 72/72 项接续/材质逻辑检查、159/159 项既有检查；它们覆盖 13 款游戏快照与冷/热 Ability 回调，但不能替代以上设备验证。真机步骤和官方学习链接见[实现说明](harmonyos-continuation-immersive-light.md)。本轮未覆盖运行中折叠/分屏切换、性能与功耗、温控、英文 UI 或屏幕阅读器。

## 复用检查工具

`scripts/emulator-acceptance.cjs` 支持读取布局、截图和基本设备输入；`scripts/emulator-game-smoke.cjs` 根据实时布局查找搜索框、游戏卡片及退出按钮，不向生产应用添加测试入口。

```powershell
# 启动模拟器后先用 hdc list targets 确认端口；端口每次可能变化。
# 先进入分类页，再执行逐款游戏检查。
& 'C:/Program Files/Huawei/DevEco Studio/tools/node/node.exe' scripts/emulator-game-smoke.cjs 127.0.0.1:5557 phone
& 'C:/Program Files/Huawei/DevEco Studio/tools/node/node.exe' scripts/emulator-game-smoke.cjs 127.0.0.1:5555 fold-dark
```

临时布局、逐款结果和构建日志保存在 `entry/build/emulator-acceptance/`；可审阅截图保存在 `docs/screenshots/accept-*.jpeg`。模拟器验收增加了本地游玩次数，未清除设备已有记录。验收后已将两台设备的主题偏好恢复为原来的“跟随系统”，应用停留在最新包的精选首页。
