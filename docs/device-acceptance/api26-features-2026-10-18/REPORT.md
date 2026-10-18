# API 26 卡片、光感与成绩分享

2026-10-18，Asia/Shanghai。compile / target 为 `26.0.0`，最低兼容保持 `6.1.1(24)`。本轮实现用户选定的三项功能，未新增测试套件、未跑防御性测试。

## 已实现

- **桌面卡片**：`DailyGame` 为 2×2 今日推荐，复用现有可用游戏目录和每日推荐；`ContinueGame` 为 2×4 续玩卡片，分别显示 2048、数独的本地存档状态。无存档可开始，有存档直接继续；应用前后台切换更新卡片。
- **设置与标题栏光感**：18 个游戏／设置／历史页面使用共享 `PageDestination`，把页头放入真正的 `NavDestination.title` 区域。API 26 使用原生标题栏、圆形按钮和 Sheet 材质；module metadata 启用原生设置控件光感。`deviceInfo.apiAvailable('26.0.0')` 保留 API 24 样式，不给高频棋盘叠加材质。
- **成绩精准分享**：共享结算组件增加“分享成绩”，截图只包含游戏名、结果图标、结算标题及原有成绩详情，排除按钮和棋盘。PNG 存入应用 cacheDir，由系统分享面板分发；存档继续提示不显示分享。结算出现时注册当前窗口的 `knockShare`，退出结算时解除同一回调；API 26 根据 `SharableTarget.getInfo().coordinate` 仅响应成绩区域内的碰一碰。无坐标的普通碰一碰分享当前结算。

卡片路由采用字符串参数契约；卡片状态直接读取响应式存储，避免 Builder 按值参数保留初始状态。自定义标题 Builder 使用捕获所属页面的箭头回调，避免页面上下文丢失。

## 实际验证

| 环境／场景 | 观察结果 | 主要证据 |
| --- | --- | --- |
| API 26 桌面 | 卡片中心识别两种尺寸，均可添加；推荐图标和中文标题正常，点击进入休闲钓鱼，含强制停止后的冷启动 | `daily-card-corrected.*`、`daily-card-cold-launch.*`、`continue-card-preview.*` |
| API 26 续玩 | 从两种无存档状态建立真实对局；后台后卡片更新为“继续存档”；两款冷、热启动均直接恢复，无重复继续提示 | `continue-card-empty.*`、`continue-card-both-saved.*`、`continue-2048-*`、`continue-sudoku-*` |
| 棋盘对比 | 2048 的 4 个可见数字块及位置一致；数独按 UI 树 81 格逐格比较，包含本轮实际填写的数字，冷、热恢复均一致 | `verification.json` |
| API 26 光感 | 猜数字、2048、数独、扩展游戏、设置和游玩历史正常进入及返回；设置 Sheet、音量 100%→33%、浅深色切换可操作 | `light-guess-*`、`light-volume.*`、`app-settings-*`、`history-native-title.*`、`final-snake-dark.*` |
| API 24 兼容 | 最终包安装、冷启动、数独存档提示及设置可用；贪吃蛇按方向键开始、自然撞墙结算，系统分享面板正常打开 | `api24-home.*`、`api24-settings.*`、`api24-final-result.*`、`api24-final-share-panel.*` |
| 成绩图 | 猜数字真实提交 10 次后结算；打开系统分享并执行本地图库保存。实际取回 PNG 检查，包含成绩内容，未包含按钮；最终包另完成深色贪吃蛇自然结算及分享面板验证 | `share-natural-result.*`、`share-system-panel.*`、`shared-result.png`、`final-shared-result-dark.png`、`final-share-panel-dark.*` |
| API 26 短屏 | 1080×1440、480 dpi，即 360×480vp；真实自然结算的成绩内容、分享、再来一局、返回均完整可见。分享面板可打开，关闭后“再来一局”实际重开 | `compact-result.*`、`compact-share-panel.*`、`compact-restart.*` |

数独首次按文字边界比较时受按压动画影响出现 1 像素偏移；复查原始 UI 树后，改为读取棋盘实际 81 个格子及其数字，未忽略数值差异。比较对象不含键盘数字。证据为真实模拟器 UI，未注入或改写游戏存档。

本轮收尾恢复 API 26 普通实例的“跟随系统”主题和原 100% 音量，已关闭本次三个独立模拟器；官方关闭命令后 API 24 留有后台启动进程，核实归属后单独结束。未卸载或清除原有模拟器数据，未停止用户的默认 HDC 服务。

## 构建与包身份

使用图形版 DevEco Studio `26.0.0.851` 配套 SDK `26.0.0.105`，通过 `node scripts/build-hap.cjs` 和 `node scripts/build-hap.cjs release`。两种编译模式均原生编译、打包和签名成功；保留 16 条异常提示／设备能力告警，未为消除告警增加保护层。`git diff --check` 通过，新增 11 个字符串在 base、zh_CN、en_US 中齐全且无重名。

完整 UI 场景使用归档的 `final-debug-unsigned.hap`；API 24 为 `6.1.0.126`，API 26 为 `7.0.0.107`。其后仅清理迁移生成的空行空格、恢复字符串资源原格式，未改变功能，重新通过 Debug／Release 构建；`clean-*` 为这次格式清理后的包，API 26 普通实例另覆盖安装并抽查冷启动卡片。包内 `minAPIVersion=60101024`、`targetAPIVersion=260000026`，包名 `com.littlegames.collection`，版本 `1.0.0`。

- 模拟器验收包 SHA-256：`07886d57306789c7b25c5d645e3915af645aa360b6d07216a7ca9faf4d016aea`。
- 包大小、Debug／Release 签名包散列及设备身份见 [verification.json](verification.json)；原始安装信息见各 `*-installed-bundle.txt`。
- 本机候选包位于 `.local-tools/api26-features/`；构建日志位于 `.local-tools/api26-verification/` 的 `final-*-build.log`、`clean-*-build.log`。未将长期证据放在 `entry/build`。

Release 仅指编译模式，本机签名配置仍是调试 Profile，不能据此认定可上架。

## Git 交付范围

按用户后续指示提交 API 26 升级、三项功能及相关验收记录至 `main`。共享 `build-profile.json5` 的 `signingConfigs` 保持为空，本机签名配置保留在工作区；工具、安装包与缓存继续排除在 Git 之外。此前独立的模型审计修复、棋牌 UI 修改及其测试／报告保留为未提交改动。

完整模拟器证据对应验收时的工作区候选包，含当时已有改动。另将实际暂存快照导出到隔离目录，在不依赖上述独立改动、没有个人签名配置的条件下原生构建成功（34 个任务，23.130 秒）；这是本次提交源码的构建证据，未将其称作重新完成所有模拟器场景。详见 [commit-verification.json](commit-verification.json)。

## 尚未实测的范围

两台支持设备间的碰一碰坐标与实际图片传输尚未验收；本次仅完成接口接入、版本兼容构建和系统分享／图片生成的实际模拟器检查。没有将其描述为跨设备续玩、云存档或联机功能。

未重跑 89 款逐款三次结算，没有新增真机光感、声音、性能或能耗通过结论。现有多人游戏仍保持撤下。手机真机、桌面回归和本轮模拟器证据分别记录，不互相代替。

## 官方依据

- [新版 ArkUI 开启沉浸光感](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/arkts-immersive-light-sense-enable)
- [卡片 postCardAction](https://developer.huawei.com/consumer/en/doc/harmonyos-references-V13/js-apis-postcardaction-V13)
- [碰一碰精准分享指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/knock-share-pc-phones-mutually)（网页未返回完整正文，精确接口以本机官方 API 26 SDK 的 `harmonyShare`、`systemShare`、`UIContext`、`componentUtils` 与 `ImagePacker` 声明交叉确认）
