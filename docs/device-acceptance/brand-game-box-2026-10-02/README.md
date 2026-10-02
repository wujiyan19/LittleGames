# 游戏盒子图标真机验收

日期：2026-10-02。设备：ALN-AL00，HDC 目标 `FMR0224521016052`。

用户选定打开的游戏盒子方案后，统一替换桌面图标、系统启动窗口、首页品牌图和关于页图标。保留蓝青色背景与原有应用名称。系统启动窗口仅显示图标，不配置标题、副标题，也不叠加应用内启动页。

## 构建与安装

- 使用 DevEco Studio 内置 SDK 和 hvigor 构建，`assembleHap --mode module -p product=default --no-daemon` 成功。
- 已覆盖安装 `entry-default-signed.hap`，HDC 返回 `AppMod finish install bundle successfully`。
- 安装包 SHA256：`0E91FA06F5E749B1090A1991B11DF0259801B3B8F71B6A6CBBCF5867839C729C`。
- 检查未签名 HAP：包含 1024×1024 桌面图标、256×256 启动图标；启动配置仅含背景色与 `startWindowAppIcon`；无旧 `start_window_brand` 资源。

## 真机结果

| 检查项 | 结果 | 证据 |
| --- | --- | --- |
| 冷启动 | 通过。启动前进程为空，系统窗口显示新盒子图标，无标题和副标题；随后进入首页。 | `cold-start/pid-before.txt`、`cold-start/frame-0.jpeg` 至 `frame-7.jpeg`、`cold-start/final-layout.json` |
| 首页横幅 | 通过。右侧品牌图已使用新盒子图标。 | `home.jpeg` |
| 关于页 | 通过。新盒子图标与应用名称显示正常。 | `about.jpeg`、`about.json` |
| 桌面图标与点击启动 | 通过。桌面图标已更新；点击后回到应用的关于页。 | `desktop.jpeg`、`desktop-launch.json` |
| 我的页面统计回归 | 通过。当前 3000 挑战分保持单行；三个数值区域均为 y=1023–1127，标签均为 y=1140–1186。 | `profile.json` |

冷启动截图用于核对实际外观和切换过程，不作为逐帧性能测量。验收结束后已返回应用首页。

图标原图、生成提示词及资源缩放方法见 `docs/art/brand-game-box/README.md`。
