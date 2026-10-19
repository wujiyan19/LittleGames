# 华为账号登录可行性评估

评估日期：2026-10-14。结论：LittleGames 可以接入 HarmonyOS 原生 Account Kit，现有 API 24 工程和手机/平板目标设备满足已核实接口的条件。推荐先提供可选的华为账号登录与头像昵称授权，继续允许游客离线游玩。云存档与跨设备战绩同步需要另建数据服务，不能由登录能力自动获得。

本轮仅评估与保存报告，没有修改应用代码、权限、签名、AGC 配置或现有隐私声明，也没有发起真实账号登录。

## 当前工程条件

| 项目 | 本轮检查结果 | 判断 |
| --- | --- | --- |
| 编译与目标系统 | `build-profile.json5` 的 compile/compatible/target 均为 HarmonyOS 6.1.1 / API 24 | 无需为下列账号接口升级 SDK |
| SDK 能力 | 本机 HMS SDK 包含 `@kit.AccountKit`、`authentication`、`LoginWithHuaweiIDButton` | 可以直接使用系统 Kit；基础接入无需引入 Android HMS SDK 或额外 OHPM 账号库 |
| 应用包名 | `com.littlegames.collection` | AGC 应用、证书与 Profile 应对应此应用 |
| 身份配置 | `entry/src/main/module.json5` 中未发现 `client_id`；没有现成 Account Kit 调用 | 需核对实际 AGC Client ID 与 APP ID，再决定配置方式 |
| 页面入口 | `ProfileTab` 已有用户卡片，当前名称和头像为本地占位 | 适合放置可选登录入口与授权后的资料 |
| 数据归属 | `GameDataManager` 使用单一 `little_games_data` Preferences，最高分、时长、历史和两个存档均按设备保存 | 当前没有账号分区；不能直接将设备旧战绩宣称为当前登录账号的云战绩 |
| 服务端 | 仓库没有用户服务或云数据服务；根 package.json 只有设备测试依赖 | 云端账号会话、备份、排行榜需要新增服务或选用托管后端 |
| 现有权限与声明 | 模块仅申请 VIBRATE；隐私草稿写明无需登录、不读取账号资料、不上传游戏数据 | 加入账号资料后需更新实际信息处理说明；访问头像网络资源/业务服务端时按所用网络 API 配置权限 |

仓库的旧发布准备记录记载当时尚未创建对应 AGC 应用。本轮未访问 AGC 管理中心，该历史记录不能证明今天仍未创建。

## 能实现的功能与接入规模

| 目标 | 可行性与主要工作 | 规模判断 |
| --- | --- | --- |
| 在“我的”页提供登录入口、显示账号资料 | Account Kit 登录请求与独立的 profile 授权；加载、取消、失败、失效、退出状态；资料缓存 | 中等客户端改动；头像昵称授权本身不强制自建服务端 |
| 按账号隔离本机战绩 | 在身份确定后切换账号数据分区，明确游客记录导入与退出后的显示规则 | 中等数据层改动；需要迁移与账号切换回归 |
| 云备份最高分与存档 | 身份校验、应用会话、数据库、上传下载、断网重试、冲突与删除规则 | 中到大；当前没有相应基础设施 |
| 公共排行榜或跨设备累计时长 | 云端业务校验、用户归属、幂等提交、数据口径与合并机制 | 大于单纯登录；本地分数不能直接作为可信云端排名依据 |

上述规模是基于现有源码的工程判断，不是已验证的工期。AGC 配置、证书状态与真实后端方案尚未确认，不给出承诺完成日期。

## 已核实的官方接入路线

### 登录与资料授权分别处理

[华为账号登录 API 指南](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/account-unionid-login-api) 给出：

- 从 `@kit.AccountKit` 导入 `authentication`。
- `HuaweiIDProvider.createLoginWithHuaweiIDRequest()` 创建登录请求，使用页面的有效 Context 构造 `AuthenticationController`，通过 `executeRequest` 执行。
- 处理 `state` 一致性、用户取消、网络错误、未登录及重复请求。
- 云端用户体系采用授权码交给服务端兑换凭证、获取身份并建立应用自己的会话。

[头像昵称指南](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/account-get-avatar-nickname) 明确提供独立授权：`createAuthorizationWithHuaweiIDRequest()` 与 `scopes = ['profile']`。用户允许后客户端可读取 `avatarUri` 和 `nickName`。`serviceauthcode` 用于需要服务端处理的情形，指南将头像昵称的服务端开发列为可选。

因此，仅完善“我的”页本地资料可以先做客户端授权。若要建立云端账号与数据归属，应完成服务端身份验证和应用会话；客户端缓存的 OpenID/UnionID 不能直接作为业务服务端的鉴权凭证。Client Secret 保留在服务端，不写入应用资源或 Preferences。

头像昵称不应假定总是完整可用：用户可拒绝授权；未设置昵称可能返回匿名手机号/邮箱；头像更新会使旧链接失效。需要默认头像、合理显示和缓存失效处理。[官方资料说明](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/account-get-avatar-nickname)

### 登录按钮与 V2 页面

优先评估官方 [LoginWithHuaweiIDButton](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/account-unionid-login-button)，其样式支持系统深浅色切换。也可以使用符合华为品牌规范的自定义按钮调用上述登录 API。

本工程页面采用 `@ComponentV2`。本机官方按钮声明使用 V1 `@Component`，正式接入应验证组件组合边界；若需要，采用 V2 页面中的规范自定义按钮调用官方 Account Kit API，不在同一组件混用 V1/V2 装饰器。该组合本轮未编译或实机试验。

### AGC 与签名前提

官方登录与头像昵称指南都要求正确配置签名、公钥指纹与 Client ID，并说明这些基础场景无需额外申请账号数据能力权限。这不等于跳过 AGC 配置、用户授权或应用自身网络权限。

[官方 Client ID 问题说明](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/account-faq-22) 指出：

- 获取 **应用** 的 Client ID 与 APP ID。
- 两者不同时，在 entry 模块 `module.json5` 配置正确的 `client_id`；相同时可以不配置。
- 无效 Profile 或身份配置错误会导致调用失败。

当前工程已有签名构建成功的证据，但签名成功不能证明其公钥指纹已经在 AGC 登记并可使用账号服务。需分别核对调试与发布证书及对应 Profile。没有必要因历史教程而一律改成手动签名，应按实际证书与设备错误核实。

## 建议的实现边界

第一阶段提供“游客 / 正在登录 / 已登录 / 登录失效或失败”状态和独立的资料授权状态。登录放在“我的”，用户取消或无网络时仍可离线游玩；不在应用启动时强制拉起登录页。

建议以独立 `AccountService` 封装原生认证，以 `@ObservedV2` 的账号 ViewModel 提供页面状态，ProfileTab 接收资料与事件。GameDataManager 暂保留设备数据口径，在页面明确显示“本机战绩”；如果要按账号隔离，先决定游客数据是否由用户选择导入，再做分区迁移，避免切换账号后错误显示或覆盖另一人的记录。

必须区分应用退出登录、撤销资料授权与退出设备上的华为账号。应用内退出只清理自己的登录会话/资料状态，不主动退出系统华为账号。返回前台或恢复页面后核对身份有效性；SDK 已提供 `HuaweiIDProvider.getHuaweiIDState`，可用于所持身份状态检查。退出、重试或账号切换时令旧异步结果失效。

第二阶段再确定云存档业务契约：身份验证与账号绑定、存档版本、最高分合并、时长提交去重、冲突选择和删除策略。现有系统接续传输的是页面与本局状态，仍不能当成云端账号数据同步。

## 正式接入前的必要输入与验收

必要输入为：实际 AGC 应用与 Client ID/APP ID、可用签名/Profile 及已配置的公钥指纹、选择“仅本机资料”还是“账号隔离/云同步”。有业务服务端时再确定服务地址与凭证交换配置；评估或客户端编码不需要在聊天里提供 Client Secret。

验收包括已登录/未登录系统账号、同意/拒绝资料授权、取消、断网、连续点击、登录期间离页、应用重启、身份失效、账号切换和退出。数据分区或云存档版本还要验证游客迁移与冲突。登录授权弹层、系统账号状态和指纹匹配需要真实设备及有效 AGC 配置验证。

本轮核对的本机 SDK 文件：

- `sdk/default/hms/ets/kits/@kit.AccountKit.d.ts`。
- `sdk/default/hms/ets/api/@hms.core.authentication.d.ts`：登录接口、授权接口、状态查询、取消授权；登录接口与 Kit 的原生能力早于 API 24，`avatarUri`/`nickName` 当前声明的应用版本亦由目标 SDK 支持。
- `sdk/default/hms/ets/api/@hms.core.account.LoginComponent.d.ets`：官方按钮和面板。

本轮尚未完成：AGC 在线状态核验、身份令牌验证细节联调、真实登录、V2 页面与官方按钮组合验证、后台服务部署与云数据设计。ID Token 验证参考页本轮仅取得站点外壳，不能声称其完整字段与密码学验证步骤已核实。
