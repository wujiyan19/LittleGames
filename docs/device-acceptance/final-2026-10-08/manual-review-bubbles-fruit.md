# 泡泡龙与落果合成：动态截图目视复核

2026-10-09，本轮设备 `FMR0224521016052`；安装包 SHA256 `e14b33644f6a0f72964c96e56f0a692c70680db11437152601f9a241e4911757`。仅查看原始真实截图，未操作手机、修改脚本或读取应用模型。

1. **泡泡龙：`passed-visual-inspection`。** 对应 `attemptId=mv0zyxhl-0e419b-8` 的 `rendered-motion`。Trial 2 的 [fast-0](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/world-bubbleshooter-mv0zyxhl-0e419b-8-motion-trial-2-fast-0.jpeg) 中，金色星形球独立位于场地下半部；[fast-1](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/world-bubbleshooter-mv0zyxhl-0e419b-8-motion-trial-2-fast-1.jpeg) 中已移到阵列底部左侧，后两帧保持挂靠位置。真实画面显示球的位置变化。Trial 1 的四帧也已查看，其消除/+60 画面不单独作为运动通过依据。
2. **落果合成：`passed-visual-inspection`。** 对应 `attemptId=mv0zyxhl-0e419b-9` 的 `rendered-motion`。Trial 1 的 [fast-0](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/world-fruitmerge-mv0zyxhl-0e419b-9-motion-trial-1-fast-0.jpeg) 中，双樱桃在警戒线附近；[fast-1](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/world-fruitmerge-mv0zyxhl-0e419b-9-motion-trial-1-fast-1.jpeg) 已下降到容器中下部；[fast-2](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/world-fruitmerge-mv0zyxhl-0e419b-9-motion-trial-1-fast-2.jpeg) 和 [fast-3](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/world-fruitmerge-mv0zyxhl-0e419b-9-motion-trial-1-fast-3.jpeg) 显示其下降到底部。

这是两项**可见位置变化**的人工复核通过，原生同 hash 节点仍未建立；不扩展为帧率、完整动效、合成规则或胜负目标通过。仅检验上述序列，未为了这些结论重复检查其他 trial。逐文件观察和截图哈希见 [独立 JSON 记录](E:/lianxi/LittleGames/docs/device-acceptance/final-2026-10-08/manual-review-bubbles-fruit.json)；现有 `manual-review.json` 与 `worlds.json` 均未修改。
