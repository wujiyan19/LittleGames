# 鸿蒙应用接续与沉浸光感

状态更新（2026-10-02）：仓库共享配置不含个人签名材料，测试电脑已配置本机调试签名并完成 33 款、58 组选定玩法[真机验收](device-acceptance/generation-audit-2026-10-02.md)。下文未签名产物为早期记录；72 项接续桌面回归已重新通过，真实系统跨设备接续与真机沉浸材质效果仍待专项验证。

本次按华为开发者官方资料接入两项能力，保持工程 HarmonyOS 6.1.1 / API 24，不升级 SDK。

## 官方学习资料与版本选择

- [常见接续最佳实践](https://developer.huawei.com/consumer/cn/doc/best-practices/bpta-application-continue-progess)：Ability 配置 `continuable`；源端在 `onContinue` 保存 Want 参数；目标端在 `onCreate` / `onNewWant` 根据 `LaunchReason.CONTINUATION` 恢复业务数据。
- [UIAbility](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-app-ability-uiability)、[UIAbilityContext](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/js-apis-inner-application-uiabilitycontext)：生命周期和 `setMissionContinueState`。
- [应用接续数据迁移](https://developer.huawei.com/consumer/cn/doc/best-practices/bpta-continue-data)：本项目游戏数据足够小，采用 Want 传输，未引入分布式数据对象或额外数据同步权限。
- [华为官方 2026 年 4 月开发者月刊](https://developer.huawei.com/consumer/cn/monthly/202604)：确认 HarmonyOS 6.1 / API 23 起提供 HDS 悬浮页签与沉浸光感能力。
- [多设备移动支付界面](https://developer.huawei.com/consumer/cn/doc/doccenter-multi-device/bpta-multi-mobile-payment)：官方使用 `HdsTabs` 和悬浮页签样式的多设备示例。
- [UI Design Kit API 目录](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/ui-design-arkts)：HDS 材质 API；入参、枚举和起始版本同时逐项核对了 DevEco 内置 API 24 SDK 的 `@kit.UIDesignKit`、`hdsMaterial` 和 `hdsBaseComponent` 声明。
- [新版 ArkUI 开启沉浸光感](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/arkts-immersive-light-sense-enable)：该路线要求 target SDK 不低于 26，本工程采用 API 23 已支持的 HDS 路线。

部分华为文档网页未能返回正文；本地官方 SDK 提供的声明、API 注释及可读取的官方指南用于交叉核对。实现没有使用 API 26 的 `uiMaterial` 或全局沉浸材质配置。

## 实际行为

主页底部三栏导航使用 `HdsTabs` 悬浮页签。通过 `hdsMaterial.getSystemMaterialTypes()` 查询支持情况，有沉浸材质时选择 `IMMERSIVE`，其他情况使用 `ADAPTIVE`；材质等级由系统决定。开启 `thermoCtrl` 让系统在温控条件下调整效果。颜色跟随系统与应用明暗主题，游戏中的高频棋盘和运动区域没有添加材质渲染。

接续入口由鸿蒙系统提供。两端需使用支持该能力的手机或平板、登录同一华为账号、安装支持接续的应用版本，并开启系统接续功能。关于页面提供操作说明。

| 游戏 | 接续保留内容 | 到达后的行为 |
| --- | --- | --- |
| 贪吃蛇 | 蛇身、食物、方向及待执行转向、分数、难度 | 已启动的对局暂停，点击继续恢复 |
| 俄罗斯方块 | 棋盘、当前方块、旋转、位置、等级、分数 | 暂停，点击继续恢复 |
| 2048 | 棋盘、分数、难度 | 直接继续；渲染方块重新组装 |
| 打地鼠 | 地鼠、剩余秒数、当前不足一秒的余额、分数 | 暂停，传输时间不扣除 |
| 扫雷 | 雷盘、揭开与标记状态、首点状态、用时、结果 | 接着计时，传输时间不计入 |
| 数独 | 题面、固定格、填写状态、选中格、难度 | 直接继续；生成题面期间源端拒绝接续 |
| 滑动拼图 | 棋盘、步数、难度 | 恢复对应棋盘尺寸，继续移动 |
| 华容道 | 棋子布局、选中棋子、步数、难度 | 重建占用网格，继续移动 |
| 猜数字 | 答案、未提交输入、历史记录、尝试次数 | 直接继续 |
| 记忆翻牌 | 牌面、已配对状态、翻开牌、尝试次数 | 未完成的翻牌结算延时重新启动 |
| 跳一跳 | 平台、得分、运动进度、落点与落台结果 | 恢复在途运动，坐标适配目标窗口；持续按压的蓄力取消 |
| 打砖块 | 球位置和速度、挡板、砖块、生命、关卡 | 已发射的球暂停；过关提示完成后进入下一关 |
| 消消乐 | 棋盘、剩余步数、分数、选中格 | 直接继续 |

主页当前页签、游戏路由、设置及关于页面也随接续恢复。热启动目标使用新的导航实例与组件标识，即使目标已经打开同一游戏，也会从收到的进度创建新的页面。恢复不会额外记一次开局，目标设备已有更高纪录会保留。

## 数据与生命周期

- 应用封套和各游戏状态均采用版本 1，显式接口描述传输字段。字段类型、棋盘尺寸、坐标范围与部分关键规则关系验证通过后才替换游戏状态。
- 应用封套限制为 20,000 个 UTF-16 代码单元，即使按最坏 UTF-8 编码估算，也为 Want 参数的 100 KB 上限留出余量。桌面检查验证全部游戏及最高难度的正常载荷低于该上限。
- 只传序列化游戏数据，不传定时器、帧循环、任务池任务、窗口或导航对象；目标端重新构造需要观察的实例。
- `SUPPORT_CONTINUE_PAGE_STACK_KEY` 设置为 `false`，由应用显式恢复 Navigation 和 ComponentV2 的状态，避免系统自动页面恢复与业务恢复重复执行。
- 使用系统默认的接续成功后退出源端行为。源端导出快照不会自行暂停、结算或修改游戏；系统接续失败时原局仍可游玩。
- 页面未就绪、恢复进行中、数独仍在出题、载荷过大时返回 `REJECT`。不兼容或损坏的接收数据有错误提示，不假装恢复成功。
- 接续仅携带当前页面和当前对局，不构成全部历史记录或偏好设置的持续跨设备同步。

## 已完成验证

2026-09-26：DevEco 官方工具 `assembleHap` 构建成功；72/72 项接续及沉浸材质逻辑检查通过，既有 159/159 项检查通过。桌面测试使用受控的系统服务与时钟，覆盖 13 款游戏的三个难度、编辑后的进度、延时与运动、冷/热启动 Ability 回调、错误载荷、源端不被快照导出修改、目标更高纪录、跨窗口尺寸适配和 HDS 降级。

运行方式：

```powershell
& 'C:/Program Files/Huawei/DevEco Studio/tools/node/node.exe' scripts/test-continuation.cjs
& 'C:/Program Files/Huawei/DevEco Studio/tools/node/node.exe' scripts/test-performance.cjs
```

构建产物：`entry/build/default/outputs/default/entry-default-unsigned.hap`。工程未配置签名，因此产物未签名。随后已完成 API 24 手机与 Mate X7 展开态的[模拟器验收](emulator-acceptance-2026-09-26.md)：26 条游戏入口/返回流程通过，明暗悬浮页签及底部触控通过；模拟器返回的材质支持列表为空，实际走自适应降级。系统跨设备接续与真机沉浸材质效果仍待验证。

## 真机验收步骤

1. 在两台符合条件的设备上，通过 DevEco 正常签名安装本次版本；核对同账号与系统接续开关。
2. 源端切到分类或我的页，使用对端系统接续入口，检查页签恢复且没有启动闪屏遮挡。设置和关于页分别检查返回路径。
3. 两端分别冷启动和提前打开应用；目标提前打开同一游戏时，检查旧局被替换为源端进度，而非保留目标旧局。反复执行接续并检查返回首页。
4. 按上表逐款验证中途对局和已结束对局，比较棋盘、分数、难度、步数与剩余时间；检查恢复不会增加开局次数。
5. 特别在贪吃蛇按键之后、俄罗斯方块下落中、打地鼠不足一秒时、翻牌结算前、跳跃半空中、打砖块过关提示期间接续。检查手动恢复按钮及传输时间处理。
6. 使用宽窄不同的窗口、平板和手机验证拼图/翻牌行数、跳跃平台与运动、方块渲染、分屏和旋转。
7. 数独出题时触发接续，应被拒绝；题面就绪后应成功。关闭目标设备、断开连接或取消接续后，源端原局仍可继续。
8. 在目标有更高纪录时接续，检查记录没有倒退。检查损坏/不兼容数据出现失败提示。
9. 深色与浅色主题下检查悬浮页签材质、文字可读性、触控反馈、底部安全区，以及滚动到底时最后一张卡片仍可点击；对照系统材质策略检查支持设备和降级设备的表现。
10. 在温控或系统降效条件下确认界面仍可操作，并用 DevEco Profiler 检查主页滚动与游戏帧率。桌面逻辑检查不能代替这一项。
