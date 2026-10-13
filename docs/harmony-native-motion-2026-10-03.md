# 鸿蒙原生动效调研与实现

2026-10-03，LittleGames，DevEco Studio 内置 HarmonyOS 6.1.1 / API 24。

## 官方资料与设计判断

华为的[设计与开发 HarmonyOS 应用指南](https://developer.huawei.com/consumer/cn/app/planning)将物理动力学和引力作为动效设计的基础，并强调轻拟物质感、交互一致性和多设备体验。[动画曲线概述](https://developer.huawei.com/consumer/en/doc/harmonyos-guides-V5/arkts-curve-overview-V5)建议优先采用物理曲线，使运动更自然。

当前[HarmonyOS 设计入口](https://developer.huawei.com/consumer/cn/design)还强调材质的光学行为、空间属性和交互响应。工程已使用系统语义色、HarmonyOS Sans、系统 Symbol、原生 Navigation、滚动回弹和 API 24 HDS 悬浮导航材质。这次将改动重点放在按压、选中和浮层的运动节奏。

以下数值是针对本项目选择的调校值，不是华为规定的标准参数。手机实测与证据见[原生动效真机验证](device-acceptance/harmony-motion-2026-10-03/README.md)。

## 已落地的改动

| 交互 | 原来 | 现在 |
| --- | --- | --- |
| 首页与分类游戏卡片 | 手工监听触摸，以固定缓动曲线缩至 95% | 原生 `clickEffect`，轻微缩至 98%，由系统处理按下、释放、取消与弹簧反馈 |
| 游戏头部、方向键、设置选择和返回、首页重试 | 瞬时透明度/缩放状态或缺少缩放反馈 | 共用原生按钮按压效果，缩至 96% |
| 底部导航图标 | 选中时修改字号 | 字号固定；通过缩放与 1.5vp 轻抬升表达选中，使用弹簧接续运动 |
| 分类筛选 | 全局 `animateTo` 包围列表筛选状态 | 直接更新分类；弹簧仅绑定筛选项，选中放大至 103%，避免栅格布局参与动画 |
| 结算、退出确认 | 结算延迟手工入场，退出确认直接出现 | 声明式组件转场；卡片以 94% 缩放和 16vp 位移进入，关闭更快，遮罩独立淡入淡出 |
| 浮层操作 | 立即关闭时，双击的第二次触摸可能落到新棋盘 | 接受一次操作后禁用按钮；先以 140ms 退场，保留触摸遮罩至 320ms 再回调，避免新局误操作 |
| 平板浮层 | 卡片宽度仅随屏幕比例扩大 | 最大宽度 420vp，保持浮层的信息聚焦 |
| 我的排行榜 | 手工延迟 100ms，再用 400ms 显示 | 内容默认可读，通过 180ms 的淡入与 8vp 位移转场出现 |
| 胜利庆祝 | 1000ms 粒子散开 | 保留单次庆祝，缩短为 680ms |

## 实现与 API 核对

- `entry/src/main/ets/common/HarmonyMotion.ets` 集中管理按压、选中、浮层和内容转场；参数位于 `entry/src/main/resources/base/element/float.json`。
- 按压使用 `ClickEffectLevel.LIGHT`；选中使用 `curves.springMotion(0.28, 0.88)`，浮层进入使用 `curves.springMotion(0.38, 0.88)`。弹簧时长由物理参数决定，因此没有混用固定 `duration` 限制弹簧。
- 透明度单独使用传统曲线；遮罩为 180ms，卡片退出为 140ms。以 `TransitionEffect.asymmetric` 分别表达进入与退出节奏。
- 真机发现的双击穿透在公共结算与退出组件中一起修复。关闭状态只改变变换与透明度，延迟回调期间保留全屏点击遮罩；组件销毁时清理定时器。
- 复杂卡片和浮层使用 `renderGroup(true)`。新动效只改变 `scale`、`translate`、`opacity` 或选中色；没有逐帧修改尺寸、边距、内边距。
- 数字资源通过 UIContext 对应的资源管理器读取；使用资源 ID 的 `getNumber` 重载，避免已废弃的 Resource 参数重载。上下文/资源不可用时有默认值。
- 使用 `@kit.ArkUI` 的 `curves` 与 `UIContext`，维持工程的 `@ComponentV2`、`@Local` 状态范式。上述 UI 动效不需要新增权限或第三方依赖。
- 新增资源全部为与主题无关的运动参数。颜色继续引用现有系统与应用双主题资源；无新增界面文案，分类选中描述复用已有三种语言的字符串。

官方[曲线接口](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-curve)和[组件转场接口](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-transition-animation-component)的网页抓取出现超时。接口签名、导入与支持版本另据本机官方 SDK 的 `@ohos.curves.d.ts`、`component/common.d.ts`、`component/enums.d.ts`、`@ohos.resourceManager.d.ts` 核对：弹簧运动 API 9 起，点击反馈与组合转场 API 10 起；本工程 API 24 编译通过。SDK 说明中的点击反馈本身使用物理弹簧。

## 验证

- API 24 `assembleHap` 成功，生成 `entry/build/default/outputs/default/entry-default-signed.hap`。
- `scripts/test-performance.cjs`：159/159 通过，覆盖已有性能、设置及相关模型回归。
- `scripts/test-expansion-art.cjs`：7/7 通过，覆盖资源引用、主题素材、反馈在暂停/后台/退出/流转时的行为。
- 新资源成功编译，已检查编译产物中的资源 ID 与生成资源表一致。
- `git diff --check` 通过。

签名包已安装到连接的 ALN-AL00 手机。浅色/深色的快速切 Tab、分类稳定宽度、按压取消、胜利/平局/失败结算、双击重开与取消退出、暂停恢复均由实际触摸输入验证，详见[当轮报告及包身份](device-acceptance/harmony-motion-2026-10-03/README.md)。截图采样用于状态与视觉复核，不能证明每一帧的流畅度；本轮没有进行平板、横屏或长局帧率测试。
