# 玩具风格美术：首批四款

范围为拆螺丝、停车场挪车、跳一跳、滚动球闯关。统一采用圆润造型、珊瑚/麦黄/薄荷/雾蓝/淡紫配色、哑光表面和固定镜头。

| 游戏 | 显示方式 | 操作与可读性 |
| --- | --- | --- |
| 拆螺丝 | 原创三维模型离线渲染为透明 PNG | 交叠板材与螺丝共用显示、遮挡和点击坐标；按颜色编号三颗回收，暂存槽随难度变化；拆卸使用旋转、缩放及透明度过渡 |
| 停车场挪车 | 原创三维玩具车离线渲染为透明 PNG | 车头和箭头共同表示出场方向；按原有格子布局和阻挡规则点击；离场使用位移和透明度过渡 |
| 跳一跳 | ArkGraphics 3D / Component3D 实时绘制 GLB | 正交固定镜头；保留蓄力、抛物线、平台判定与下落规则；模型缩放表达蓄力形变 |
| 滚动球闯关 | ArkGraphics 3D / Component3D 实时绘制 GLB | 球体旋转表达滚动；障碍、洞口和终点直接对应原有规则坐标；独立原生触摸层接收输入 |

模型由 `scripts/generate-toy-art.mjs` 中的几何构造生成，未引入外部角色、模型或纹理。GLB 使用共享几何与材质、线性顶点颜色烘焙明暗，不使用实时阴影或动画纹理序列。预览图片放在本目录，不打入安装包。运行时不依赖 Three.js 或浏览器。

相机的原生投影矩阵用于把三维显示范围与 360×460 玩法平面对应起来，包括原生图形后端的 Y 轴符号差异。调整的是三维节点变换；没有改变碰撞、落台、胜负或难度规则。帧更新沿用已有 ViewModel；显示层没有另启定时器，退出页面会销毁原生场景，异步加载晚到时也会释放资源。

拆螺丝在后续迭代中增加了真正的层叠遮挡、同色三颗回收和暂存槽失败规则；上面的“显示层”说明对应首版美术更新。新玩法、难度和存档兼容见 [拆螺丝难度优化](screwout-difficulty.md)。

手机渲染目标设为组件尺寸的 80%，启用模型边缘抗锯齿。浅色和深色棋盘、原生场景均有对应资源；场景优先使用应用内的主题设置，选择“跟随系统”时才读取设备配置。资源原始字节数见 `manifest.json`；这不是安装包压缩后的增量，也不是运行内存或功耗测量。

生成资源：

```powershell
npm install --prefix .local-tools/toy-art three@0.180.0 playwright-core@1.56.1
node scripts/generate-toy-art.mjs
node scripts/test-toy-scenes.cjs
```

离线渲染默认使用本机 Edge，可通过 `TOY_ART_BROWSER` 指向其他 Chromium 浏览器。工具依赖保存在被忽略的 `.local-tools` 中。

构建仍使用 `node scripts/build-hap.cjs` 和 `node scripts/build-hap.cjs release`，目标 API 26、兼容 API 24。新增接口已经核对本机 SDK 与华为官方文档：

- [Component3D](https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-basic-components-component3d)
- [场景加载和控制示例](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/arkgraphics3d-animation)
- [SceneNode / Camera](https://developer.huawei.com/consumer/en/doc/harmonyos-references/js-apis-inner-scene-nodes)
- [场景后处理](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-inner-scene-post-process-settings)

手机证据在 `docs/device-acceptance/toy-art-2026-10-19-phone/`，模拟器证据在 `docs/device-acceptance/toy-art-2026-10-19/`。每次截图与操作记录包含设备及安装包哈希。桌面逻辑检查、模拟器结果、真机结果分别记录；本轮验证不等于全合集验收或长时间功耗、发热验收。
