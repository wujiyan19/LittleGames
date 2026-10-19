# DeepSeek 第二轮审查核验

日期：2026-10-18（Asia/Shanghai） <br>
被核验报告：`docs/harmony-audit-2026-10-18.md` <br>
代码基线：HEAD `2937e699035ca822df16c94a4a293a24cbeb4286` + 开始核验时的未提交改动。 <br>
方法：当前源码、目标 API 24 SDK 声明、独立资源扫描、全量原生构建、现有回归、针对性故障注入及现有设备记录重算。

## 结论

**主要技术结论属实，但报告仍有不存在的 API 建议、统计错误和过时的验收进度，不能逐字照用。**

R2/R5 撤回正确，R3 的同步和异步异常处理已修复，当前构建确为调试模式和调试 Profile。报告列出的 8 套 660 项桌面回归已独立复跑通过；另补跑音效与数据恢复两套，合计 **10 套 678/678**。本次没有复现这些审查条目所述的新增阻断级代码问题。

业务源码、签名配置和原审查报告均未修改。本次只新增本核验文档，并在忽略的 `entry/build/audit-verification-20261018/` 保存日志和探针。重新构建更新了本地输出 HAP，未安装到手机。

## 主要结论逐项对照

| 审查项 | 核验结果 | 证据与边界 |
| --- | --- | --- |
| R2 触控坐标不是缺陷 | 属实 | 当前容器保持 360:460，双轴比例均为宽度/360；执行当前源码中的比例与事件表达式，7 组宽度、84 组坐标全部通过。不是原生触摸或布局实测。 |
| R5 恢复首帧不回弹 | 属实 | 实际 `DisplayFrameLoop` 与 `BrickBreakerViewModel` 连接原生 mock，累积余量 0/15/29ms 三种场景恢复首帧的位置和余量均与暂停前严格相同。 |
| R3 Haptics 已修复 | 属实 | `Haptics.ets` 两个反馈方法均有同步 try/catch 与 Promise.catch；现有同步失败、异步拒绝注入测试通过。不能据此证明所有设备振感正常。 |
| 当前仍为调试签名/模式 | 属实 | 当前 Profile 的非敏感字段为 `type=debug`；新构建包内 `buildMode=debug`、`debug=true`。正式分发需要相应发布材料与 release 构建，配置名称不能代替构建模式。 |
| 废弃字符串 Resource 重载已消除 | 本次构建支持 | 全量编译未产生 deprecated 告警；目标 SDK 的数字 ID 重载未废弃，Resource 重载标有 `@deprecated since 20`。不据此承诺所有未来 SDK 下均无废弃项。 |
| 音量更新、持久化、非法输入校验 | 所核对范围成立 | 当前实现与设置/音效回归一致；包含拖动合并落盘、重启恢复、在途播放取得最新音量、并发音量更新串行合并及原生 setVolume 失败。未进行真实音频试听。 |
| 背包 Grid、占格键、双主题槽位资源 | 源码事实成立 | `ExpansionWorldBoard.ets:131-154` 使用 Grid、`index:value` 键与 renderGroup；base/dark 均存在 `exp_pack_slot.svg`。静态核查不替代当前包的实际重绘和读屏验收。 |
| Snake 接续不变量 | 成立 | 相邻蛇身、食物空位、满盘结束哨兵及合法 pendingTurn 均已校验，接续套件 83/83 通过。 |
| 水果警戒线、台球犯规阈值共用常量 | 成立 | `FRUIT_WARNING_Y=50` 与 `BILLIARDS_FOUL_LIMIT=4` 的模型/UI 引用一致。 |
| 1836 个资源引用无悬空、三语种一致 | 成立 | 独立扫描 131 个 .ets，共 1836 处引用，无缺失；每语种 822 条字符串，无重复键和键差异。 |
| 仍未完成每款三次真机验收 | 成立，但进度过时 | 最新 progress.json 为 87/89 款、262/267 次，视觉复核 86/89；详见下文。 |

## 需要纠正的内容

### 1. `tryGetSync` 不是目标 SDK 提供的方法

报告第 94 行建议将读取改为 `tryGetSync`。本工程的 HarmonyOS 6.1.1/API 24 SDK 中，Preferences 声明提供的是：

```typescript
getSync(key: string, defValue: ValueType): ValueType;
```

位置：`C:/Program Files/Huawei/DevEco Studio/sdk/default/openharmony/ets/api/@ohos.data.preferences.d.ts:1114`。该文件及目标 ets API 声明目录内均无 `tryGetSync`。不能直接按这个建议替换，否则会调用未声明的方法。若要隔离各项读取失败，应继续使用真实存在的 API，并明确处理异常。

报告关于外层 catch 能捕获读取异常的判断是对的。本次对 9 个实际读取键逐一注入异常：`init()` 均未向调用方抛错，`store` 均被置空，此后本次运行的写入不再落盘。原先持久化内容没有被删除。因此，准确后果是“可能中断后续恢复，并关闭本次运行的持久化”，不能直接描述为已删除全部历史成绩。“可接受”属于产品取舍，不能由有 catch 单独决定。

### 2. 剩余告警是 9 处，不是 8 处

本次执行 `--no-incremental` 的全量构建成功，实际子进程退出码为 **0**，耗时 **17 s 221 ms**。`CompileArkTS`、`PackageHap`、`SignHap` 均执行。

9 条 `Function may throw exceptions` 均来自 `GameData.ets` 的 getSync，行号为 **215、216、219、223、227、231、236、247、255**。没有废弃 API 告警。这些警告不等于已发生崩溃，相关异常处理结果见上条。

原报告对其“退出码为 1”的 PowerShell 解释没有独立日志足以核定；本次通过 Node 直接捕获 hvigor 进程状态，成功退出码为 0。不能把所有非零退出都笼统归因为 stderr。

### 3. 设备进度应以 progress.json 为准；剩余次数也算错了

汇总 `REPORT.md` 生成于 2026-10-18 10:34:07，记录 86/89、261/267。`progress.json` 更新于当天 **10:40:59**，逐项重算为：

| 项目 | 最新记录 |
| --- | --- |
| 达成三次结算 | 87/89 款 |
| 已记录结算 | 262/267 次 |
| 视觉复核通过 | 86/89 款 |
| 经典纸牌 solitaire | 1/3，仍需 2 次 |
| 蜘蛛纸牌 spider | 0/3，仍需 3 次 |
| 中国象棋 xiangqi | 已 3/3，视觉复核仍待完成 |

所以当前还需 **5 次结算**，并完成经典纸牌、中国象棋、蜘蛛纸牌的相应视觉复核。即使沿用报告的旧快照，267−261 也只差 **6 次**，不是“剩余 3 款各 3 次”。

本次只重算既有记录，并检查所有登记的截图文件存在，未新增真机对局或逐图视觉复核。已记录的 262 次来自 P0/P1/P2/P4/P5 多个包，不能说成 P5 或本次新构建包已完整实测。记录中“每款三次”的标准来自本项目任务，不能直接当成华为商店统一强制规则。截图与桌面测试也不能代替帧率、音频实测。

### 4. media 的 653 个计数混入了 rawfile

独立扫描得到 **467 个 media 资源名**。原脚本 `entry/build/check-res-refs.js` 将 rawfile 文件名也放入 media 集合，其中包括 186 个 WAV，导致报成 653。`.media` 与 rawfile 不能按同一种资源计数。

修正口径后，1836 处 `$r(app.*)` 引用依然全部可解析。字符串字典合计 823 包括 AppScope 资源，entry 三语种各 822 并不矛盾。

### 5. 其余表述需限定

- **Haptics 并非两条路径都记录 error.code**：异步 .catch 记录 code，同步 catch 目前仅记录描述；处理覆盖本身正确。
- **“本轮新增约 1042 行”不是报告声称基线下的未提交差分**：核验开始时跟踪文件差分为 16 个文件、153 行新增/25 行删除；音量相关文件与背包 Grid 已在 HEAD `2937e69` 中。报告应注明使用了哪个差分范围。
- **空字符串回退是有限条件下的风险**：`resolveString` 在缺上下文/解析失败时返回空串，若进入该路径，搜索与无障碍文案可能退化；本次未复现设备生命周期下上下文缺失。当前函数也没有名为 defaultValue 的参数，报告的“回退 defaultValue”需要具体设计，不能直接套用。无障碍文本为空不能笼统称为可接受。
- **本核验不构成上架批准或整机性能保证**：调试签名和内部验收缺口属实，但本次技术核查不能据此得出发布只剩这两项，或其他资质、审核项已通过。

## 本次验证与包身份

| 桌面套件 | 本次结果 |
| --- | --- |
| test-continuation | 83/83 |
| test-performance | 165/165 |
| test-expansion | 331/331 |
| test-window-sizing | 8/8 |
| test-single-player-catalog | 17/17 |
| test-game-settings | 12/12 |
| test-play-history | 10/10 |
| test-play-time | 34/34 |
| test-game-sounds（补跑） | 15/15 |
| test-data-recovery（补跑） | 3/3 |
| 合计 | **678/678** |

针对性探针另计：84 组源码坐标换算、3 组实际 ViewModel/帧源恢复、9 个 Preferences 读取失败注入；全部通过。上述桌面检查使用受控时钟和原生 mock，不代表本次进行了手机验收。

重建前的 HAP 确为 **11,615,806 字节**、SHA-256 `7B32F5CDEB842844FF1E973DF55BF81B9802BB7B661AEA3C1DCD5837121FCB91`，与 DeepSeek 报告一致。因此，原报告关于当时产物身份的记录有实物支持。

本次重建后的 HAP 为 **11,615,809 字节**、SHA-256 `5D70B3FB9B89BA83E032859302D4AB3E79D5000939D67435C6005F738209CBA8`。包内 `compileSdkVersion=6.1.1.125`、`targetAPIVersion=minAPIVersion=60101024`、`buildMode=debug`、`debug=true`。此包未安装到手机，不能替换既有设备记录中的包标识。

证据目录：`entry/build/audit-verification-20261018/`，包含 `native-build.log`、`native-result.json`、`regressions.json`、10 套测试日志、`probes.cjs`、`probe-results.json`、`hap-before.json`、`hap-after.json`。

API 以本机目标 SDK 声明为准；本次也检索了华为官方 Preferences 与发布资料，直接打开文档页面未取得可核对的完整正文，因此没有将页面入口或搜索摘要当成已确认 API 的替代证据。
