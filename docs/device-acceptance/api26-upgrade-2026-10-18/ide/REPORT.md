# DevEco Studio 26 图形版升级续验

日期：2026-10-18（Asia/Shanghai）。用户完成官方下载和安装后，本轮接续首次启动、工程同步、图形构建和 API 变更扫描。

## 结果

DevEco Studio 已从 6.1.1.300 升级为 **26.0.0.851 Release**，安装位置仍为 `C:/Program Files/Huawei/DevEco Studio/`。工程在新版 IDE 中同步成功，并通过“构建 → 编译 Hap(s)/APP(s) → 编译 Hap(s)”生成签名 Debug HAP，日志显示 `BUILD SUCCESSFUL in 26 s 732 ms`。

| 组件 | 本机核实版本 |
| --- | --- |
| IDE build | 261.23567.138.36.2600851 |
| HarmonyOS SDK | 26.0.0.105，API 26 |
| Node | 24.14.1 |
| Hvigor | 6.26.8 |
| JBR | 25.0.2 |

原 IDE 安装位置已被新版替换，不能再将该目录描述为 API 24 SDK。工程最低兼容版本仍为 6.1.1(24)，独立 Command Line Tools、模拟器镜像和实例数据保留。

## 构建入口与本机设置

- `scripts/build-hap.cjs` 默认使用新版 IDE 的 Node、SDK、Hvigor、ohpm 和 JBR，环境变量仅传给子进程；原 `LITTLEGAMES_TOOLCHAIN_ROOT` 仍用于显式指定独立 `command-line-tools` 目录，`JAVA_HOME` 仍可覆盖 JDK。
- 默认入口调整后，`node scripts/build-hap.cjs` 退出码 0，33 个任务执行，`BUILD SUCCESSFUL in 19 s 300 ms`。13 条原有异常提示／设备能力告警仍保留，不将构建通过描述为零告警。
- 复核中，旧命令行工具的 Node 在签名检查文件和 Hvigor 日志处发生写入失败；同版本的新 IDE Node 可打开同一日志，且使用新版 IDE 整套工具的构建成功。未据此推断 JBR 25 不兼容，也未修改文件 ACL 或系统安全设置。失败与成功日志均保存在本机归档目录。
- 通过 IDE 将 `.local-tools` 标记为排除目录，避免索引工具包及模拟器文件；配置保存在本机忽略的 `.idea/modules/LittleGames.iml`。
- README 和本机 AGENTS.md 已更新。没有新增业务代码、防御性分支或测试，没有提交或推送 Git。

## API 变更助手

已运行官方“工具 → API 变更助手”，范围为 **All，6.1.1(24) Release → 26.0.0 Release**。扫描完成，导出 [原始 CSV](20261018194953_apiChange.csv)，共 **5 组行为／定义变更、2003 处 API 匹配位置**。

这些数字表示工具按 API 关联的调用位置，不是 2003 个已确认缺陷。CSV 中“未修复”为工具初始标记，本轮没有批量改为“已修复”。

| 变更组 | 匹配位置 | 本轮核对 |
| --- | ---: | --- |
| ArkUI 接口仅支持 Stage 模型 | 1457 | 工程使用 UIAbility 和 Stage 模型，不涉及 FA 模型迁移 |
| 阴影模糊半径规格 | 3 | 两个确认／结算浮层使用 radius=8；猜数字使用已适配的 button 阴影 radius=-1，无 radius=0 |
| 表单组件最小触摸热区 | 120 | 未检索到 SMALL controlSize 或 Button 型 Toggle；设置项为 Switch 型 Toggle，不能将所有 Button／Toggle 匹配直接认定为受影响 |
| Dialog／Toast／文本选择菜单默认系统材质 | 296 | 属于已知 API 26 视觉行为；既有模拟器验收覆盖部分系统确认框，未额外改写所有 Text 或自绘弹层 |
| 内置文本样式优化 | 127 | 属于已知换行与字体行为；既有模拟器记录包含选定大字号和短屏场景，不代表全部页面及语言已验收 |

本轮未发现阻断构建的新问题；5 组匹配不等于全部界面已通过真机验收。没有将行为扫描与此前 CodeLinter API 兼容性扫描混为同一项。

## 包与证据

两个签名包均为 Debug，大小均为 11,622,122 字节。包内 `compileSdkVersion=26.0.0.105`、`minAPIVersion=60101024`、`targetAPIVersion=260000026`，包名 `com.littlegames.collection`。

| 来源 | SHA-256 |
| --- | --- |
| IDE 图形构建 | ABC9005DD02F12C46E1D896CEAF29757DD372192EE3FA4B132E209447225F1D5 |
| 更新后的命令行入口 | 592FCC9939DAD5F4B64552F48BCEA1416830A181CFA554AE24D5266514978B14 |

- [图形版构建成功截图](hap-build-success.png)
- [API 变更助手与导出成功截图](api-change-assistant.png)
- [版本、包身份及验证摘要](verification.json)
- 本机包与日志：`.local-tools/api26-verification/ide-upgrade-2026-10-18/`，包括 `ide-debug-signed.hap`、`cli-studio-debug-signed.hap`、`ide-build-info.log`、`cli-studio-debug.log` 及失败复核日志。

本轮验证范围是 IDE 升级及其 Debug 构建链路。未重跑 Release、桌面全量回归或设备游玩验收；此前模拟器及阶段 C 的独立结论见[上级验收记录](../REPORT.md)。
