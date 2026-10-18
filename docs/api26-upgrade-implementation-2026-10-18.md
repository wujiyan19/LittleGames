# HarmonyOS API 26 升级实施记录

日期：2026-10-18（Asia/Shanghai）。本记录对应迁移验收时的工作区，包括升级前已有的未提交修改。后续功能与 Git 交付范围见[功能验收记录](device-acceptance/api26-features-2026-10-18/REPORT.md)。

## 当前结果

**工程已切换为 compile/target=`26.0.0`、compatible=`6.1.1(24)`。最终阶段 C 的 Debug / Release 原生构建成功，26 套桌面回归 1340/1340 通过，API 兼容性专项扫描无发现。同一最终 Debug 包已安装于 API 24、26 和 API 26 短屏模拟器；覆盖存档与关键界面完成实测。**

模拟器验收发现并修复了猜数字在 360×480vp 短屏下历史与输入重叠的问题。具体包身份、场景、截图及边界见[模拟器验收记录](device-acceptance/api26-upgrade-2026-10-18/REPORT.md)。本次没有真机音效听感、振动、性能或全 89 款三次结算的通过结论。后续图形版 DevEco Studio 已升级为 26.0.0.851，IDE 同步、签名 HAP 和命令行 Debug 构建通过，API 变更助手已完成扫描；见[IDE 续验记录](device-acceptance/api26-upgrade-2026-10-18/ide/REPORT.md)。

## 已安装工具

用户从华为官方下载中心下载了 `commandline-tools-windows-x64-26.0.0.851.zip`，文件大小 2,722,224,870 字节，下载来源记录为华为 `contentcenter-vali-drcn.dbankcdn.cn`。本轮计算的 SHA-256：

```text
AC8D0563F47F95CA78799EA4AA494FA260BC3F7C8F2A569AC629AF1794B5D71C
```

7-Zip 完整性测试退出码为 0。该散列是本机计算值，未声称与官网公布散列独立比对。

工具解压安装于：

```text
E:/lianxi/LittleGames/.local-tools/harmonyos-26.0.0.851/command-line-tools
```

| 组件 | 实际版本 |
| --- | --- |
| Command Line Tools | 26.0.0.851 Release |
| HarmonyOS SDK | 26.0.0.105 Release，API 26 |
| Hvigor / OHOS plugin | 6.26.8 |
| Node | 24.14.1 |
| ohpm | 26.0.0.630 |
| CodeLinter | 6.0.240 |
| HDC | 3.2.0f |
| Java | 复用原 DevEco Studio 的 JBR 21.0.8 |

命令行迁移阶段保留了旧图形版 DevEco Studio 6.1.1.300。随后用户完成图形版安装，原安装位置现已为 DevEco Studio 26.0.0.851，内置 SDK 为 26.0.0.105、JBR 为 25.0.2；旧安装目录不再代表 API 24 SDK。独立命令行工具和模拟器实例仍保留。

## 工程与代码变更

- `build-profile.json5`：编译与目标升级至 `26.0.0`，最低版本保持 `6.1.1(24)`；配置 `strictMode.apiCompatibilityCheck="error"`。保留本机已有签名配置。
- `oh-package.json5`、`hvigor/hvigor-config.json5`：modelVersion 升级为 `26.0.0`。未升级应用运行时依赖、未新增权限。
- `DesignTokens.ets`：card / button 阴影半径从 0 改为 -1，保留新旧目标版本下的无阴影语义；浮层阴影不变。
- `ControlPad.ets`：中央小圆点由 `Circle.fill` 改为同尺寸的基础圆角背景。新版 SDK 在 CircleAttribute 上新增的 fill 重载标为 API 26，严格最低版本检查会拒绝原写法；本机声明位于 `sdk/default/openharmony/ets/component/circle.d.ts:144`。采用基础组件绘制，避免引入高版本分支或关闭检查。
- `GuessNumberPage.ets`、base `float.json`：短屏实测发现历史区被固定键盘挤压，与输入重叠。增加有最小内容高度的原生 Scroll，历史 List 按可用高度布局并保留记录高度上限；标题固定，短屏可滚动查看历史和操作完整键盘。普通高度继续保留原布局关系，未缩小按键触区。
- `scripts/build-hap.cjs`：默认使用新版 DevEco Studio 的 API 26 Node / SDK / Hvigor / JBR，支持 debug / release；可通过 `LITTLEGAMES_TOOLCHAIN_ROOT` 指定独立命令行工具，通过 `JAVA_HOME` 指定 JDK。环境设置只传给构建子进程。默认路径调整后的 Debug 签名构建已通过。
- `.gitignore`：排除本地工具目录。`code-linter.json5` 同时排除该目录并开启 API 兼容性错误检查，避免扫描 SDK 自带代码。
- `scripts/run-regressions.cjs`：增加 `LITTLEGAMES_REGRESSION_OUTPUT` 输出位置选项，保留原默认路径及已有套件。
- `device-art-review.cjs`：增加可选 `LITTLEGAMES_ART_HDC` / `LITTLEGAMES_ART_HAP`，将证据绑定本次实际安装包。`test-classic-logic-audit.cjs` 的猜数字用例保留最早记录的业务断言，去掉解析固定高度源码的断言；滚动与裁切改由本次七条记录的真实 UI 验证，不将桌面模型测试当作布局证明。
- `README.md`、本机 `AGENTS.md`：更新当前 SDK 与构建入口；AGENTS.md 沿用本机忽略策略。

没有改动存档键、存储格式、应用包名、版本号或产品目录。当前仍按 89 款可用单人游戏验证；内部保留模型不等于开放多人入口。

## 验证与产物

以下检查均由本轮实际运行，不继承旧报告的通过结论。

| 检查 | 本次结果 |
| --- | --- |
| 阶段 A：compile=26 / target=24 / compatible=24，Debug 全量构建 | 退出码 0，CompileArkTS / PackageHap / SignHap 成功 |
| 阶段 B：compile=26 / target=26 / compatible=24，Debug 全量构建 | 退出码 0，CompileArkTS / PackageHap / SignHap 成功 |
| 阶段 B 的 Release 全量构建 | 退出码 0，编译、打包、签名成功 |
| CodeLinter API 兼容性专项 | 入口 `entry/src/main/ets`，退出码 0，JSON 结果 `[]` |
| 桌面回归 | API 26 工具包中的 Node / TypeScript；26 套，1340/1340，通过 |
| 变更检查 | 两个 Node 脚本语法检查、相关文件 git diff --check 通过 |

CodeLinter 在命令行迁移阶段只运行 API 兼容性专项，不代表全部风格、安全或性能规则零问题。当时尚未运行图形 API Change Assistant；后续已完成的 GUI 行为扫描单列于 [IDE 续验记录](device-acceptance/api26-upgrade-2026-10-18/ide/REPORT.md)，两项结论不混用。

以下为阶段 A / B 的归档产物，最终候选为后文阶段 C。

| 签名 HAP | 字节数 | 包内 compileSdkVersion | minAPIVersion | targetAPIVersion | debug |
| --- | ---: | --- | ---: | ---: | --- |
| stage-a-signed.hap | 11,606,793 | 26.0.0.105 | 60101024 | 60101024 | true |
| stage-b-signed.hap | 11,606,793 | 26.0.0.105 | 60101024 | 260000026 | true |
| stage-b-release-signed.hap | 8,947,967 | 26.0.0.105 | 60101024 | 260000026 | false |

对应 SHA-256：

```text
stage-a: fa7029dbc08b3953ac053ff02145894ec3a4d39eeea80ddfe7e6010521bda27b
stage-b: e64d3bb808e4b6641c0ecb8ac310057279bcdca087dac54824d3f76164a3eb11
stage-b-release: b265f138f0f540cf62a0145569d6b89928b89a84f6aefaf2ae31a311b5f886ea
```

签名 Profile 的当前 type 实际为 debug。Release 表示编译模式，本轮 Release 包仍使用已有本机调试签名，不是商店发布签名或上架许可。当前默认输出目录最后生成的是阶段 C Release；设备调试候选为单独保存的 `stage-c-signed.hap`。模拟器实际安装的是同阶段的 unsigned Debug 包。

三次成功构建各保留 13 条 ArkTS 告警：9 条是原有 Preferences.getSync 异常提示；另 4 条是新版 SDK 对两处音频服务的 audio / media 系统能力提示。无 API 版本不兼容错误，未因迁移盲目增加能力探测或修改音频行为；实际声音、能力支持仍需设备验证。

## 证据位置与环境问题

长期证据、三个阶段的 signed / unsigned HAP、包内元数据和逐套回归日志保存于：

```text
E:/lianxi/LittleGames/.local-tools/api26-verification/
```

构建子进程使用 `.local-tools/hvigor-user-home` 缓存。首次启动受 Windows 沙箱目录链接限制影响，已仅对两处官方 Hvigor 缓存目录创建 Junction；没有关闭安全保护、改写官方工具或扩大工程权限。

迁移初期误将备份和日志放在 `entry/build/api26-upgrade-20261018/`，该目录被新 Hvigor 的迁移清理删除。源码与安装工具未丢失；目前的 A/B/Release 构建和 API 26 回归证据已重新生成到上述独立目录。先前 API 24 阴影修改后的构建与 1340 项回归确曾通过，但原临时日志和旧 HAP 备份不再作为现存交付证据。

## 模拟器验收与最终候选

用户已明确同意 HarmonyOS SDK License Agreement 与 HarmonyOS Software License and Service Agreement。官方镜像下载成功，已核实镜像 `sdk-pkg.json`：API 26、platformVersion `26.0.0`、`7.0.0.107 Release`，并实际启动取得系统 API Level 26。

在工作区建立 `LittleGamesApi24Upgrade`、`LittleGamesApi26Upgrade` 和 `LittleGamesApi26Compact`，保留原实例。API 24 基线为阶段 A（API 26 编译、target=24），经阶段 B 覆盖后再覆盖最终 C；未卸载或清数据。2048 / 数独逐格可见值、主题、历史与最高分均有保留证据。阶段 A 不是迁移前原始 API 24 编译产物，不将此项扩大为原始发布包全路径升级证明。

模拟器在沙箱内无法访问 Windows Hypervisor，沙箱外启动成功；HDC 默认 8710 端口绑定失败，使用独立 18710 端口后连通。没有修改 Windows 虚拟化、安全或防火墙设置。验收辅助脚本 `device-art-review.cjs` 增加可选 HDC / HAP 环境变量，默认行为不变，使证据绑定实际安装的独立 unsigned HAP，避免误用默认输出目录中的 Release 包散列。

| 最终阶段 C 签名产物 | 字节数 | SHA-256 |
| --- | ---: | --- |
| `stage-c-signed.hap`，Debug | 11,622,115 | `0f455fe004135da4dc2ddcb2f4b895a7b4cb8af548da6819fa91971df9aa9230` |
| `stage-c-release-signed.hap`，Release | 8,955,531 | `0d2449bce9f147be643e521678461a8b62ba34d31365fffb32e5095ba3ec3348` |

两包包内 compileSdkVersion=`26.0.0.105`、minAPIVersion=`60101024`、targetAPIVersion=`260000026`。模拟器实际使用的 `stage-c-unsigned.hap` SHA-256 为 `7fa619fc3768e05bcf0459117958971d55ae079dd989ba80b26e2033883114d4`。最终构建、回归与扫描文件分别为 `stage-c*-build.*`、`regressions-final/verification.json`、`api-compatibility-final.json`，均在 `.local-tools/api26-verification/`。

CodeLinter 官方 bat 包装器包含固定 `exit /b 1`；最终扫描直接调用工具内 Node 与 `codelinter/index.js`，避免把包装器退出码误判为检查失败。该专项结果仍不等同于图形 API Change Assistant。

许可文件随已安装工具提供：`emulator/agreement/HarmonyOS_SDK_Agreement.txt` 与 `HarmonyOS_Software_Service_Agreement.txt`。

## 构建命令

```powershell
cd E:/lianxi/LittleGames
node scripts/build-hap.cjs
node scripts/build-hap.cjs release
```

SDK 配置与兼容性原则参见[官方升级指导](https://developer.huawei.com/consumer/cn/doc/doccenter-release-notes/upgrade-adaptation)与[工程配置说明](https://developer.huawei.com/consumer/cn/doc/doccenter-deveco-studio/ide-hmos-hvigor-build-profile-app)；阴影行为参见[官方行为变更](https://developer.huawei.com/consumer/cn/doc/doccenter-release-notes/changelogs-for-all-apps-7001)。
