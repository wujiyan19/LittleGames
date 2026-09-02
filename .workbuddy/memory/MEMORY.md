# LittleGames 项目长期约定

HarmonyOS / ArkTS 小游戏合集，单一 `entry` 模块，10 款游戏。API 24 (HarmonyOS 6.1.1)，`@ComponentV2` + `Navigation` + `Tabs`，零第三方依赖。

## 必须遵守的约定（改动前先看）

- **颜色只用 `SemanticColors`**（`common/DesignTokens.ets`）。`LightColors` / `DarkColors` 已于 2026-09-02 合并删除——两者 40 字段完全重复，明暗实际由 `base/` 与 `dark/` 资源目录决定。固定深色场景（闪屏/品牌）用 `BrandColors`
- **新增任何颜色必须同时加到 `base/element/color.json` 和 `dark/element/color.json`**，保持两套一一对应（当前各 73 项）。新增后建议用脚本校验对称性
- **游戏调色板已收编为资源**：2048（`tile_*`）、俄罗斯方块（`shape_*`）、华容道（`klotski_*`）、扫雷数字（`mine_num_*`）。不要再写颜色字面量
- **底部安全区用 `SafeAreaInsets.bottom`**，不要用 `expandSafeArea` —— 应用未开全屏，页面本就在安全区内，`expandSafeArea` 会让内容反向顶到手势条下
- **深层状态更新走不可变更新（copy-on-write）**：`@Local` 只做一层代理，`arr[i][j] = v` 和数组内对象字段赋值**不会**触发刷新。棋盘统一用一维数组 + 整体赋值
- **持久化用 `GameDataManager.markDirty()`**（内部 200ms 防抖），不要直接调私有的 `persist()`；退出前调 `flushNow()`

## 构建

```bash
cd E:/lianxi/LittleGames
export DEVECO_SDK_HOME="C:/Program Files/Huawei/DevEco Studio/sdk"
export PATH="/c/Program Files/Huawei/DevEco Studio/tools/node:/c/Program Files/Huawei/DevEco Studio/tools/ohpm/bin:/c/Program Files/Huawei/DevEco Studio/jbr/bin:$PATH"
export JAVA_HOME="C:/Program Files/Huawei/DevEco Studio/jbr"
node "C:/Program Files/Huawei/DevEco Studio/tools/hvigor/bin/hvigorw.js" assembleHap --mode module -p product=default --no-daemon
```

- 工程根目录**没有** `hvigorw`，入口是 DevEco 的 `tools/hvigor/bin/hvigorw.js`（不是 `tools/hvigor/`）
- Git Bash 下 node 路径参数必须写 `C:/` 前缀，写 `/c/` 会被路径转换破坏成 `E:\c\...`
- 产物在 `entry/build/default/outputs/default/`；产物未签名是正常的（工程未配 signingConfigs）
- 已知的固有告警：`initCellSize()` 里 `getDefaultDisplaySync()` 抛异常（6 处），非新增问题

## 参考文档

- `AGENTS.md` —— ArkTS 严格模式语法约束（强制性，编译期生效）
- `docs/project-review.html` —— 完整代码审查报告（30 条建议 P0/P1/P2 + 路线图）。10 条 P0 已全部修复
