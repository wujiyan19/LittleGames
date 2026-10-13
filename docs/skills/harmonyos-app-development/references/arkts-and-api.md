# ArkTS 与 HarmonyOS API 约束

以下严格规则来自 LittleGames 的 `AGENTS.md`，作为此 skill 的 `.ets` 默认编写约定。目标项目规则及目标编译器更优先；不要把 ArkTS 的限制扩展到 Node.js、Java 等服务端代码或现有 `.cjs/.mjs` 工具。

## 类型、导入与声明

- 所有 import 位于文件开头，普通 `import`/`export`；不用 `require`、import 赋值、`export =`、UMD、导入断言、通配模块名或 ambient module。
- 显式命名 class/interface/enum/类型别名；不用 `any`、`unknown`、匿名对象类型作声明、类字面量、`as const`、类型上下文的 `typeof`、索引访问类型 `T[K]`。
- 不用条件类型、`infer`、交叉类型、映射类型。以命名类型、继承和接口组织数据，不依赖 TS 结构类型互换。
- 工具类型仅按项目与编译器允许的 `Partial`、`Required`、`Readonly`、`Record` 使用；优先明确 DTO。`Record<K, V>` 取值需处理 `V | undefined`。
- 不合并类、接口、枚举声明。枚举显式初始化值同类型、编译期可确定，不用运行时表达式。
- 类字段在类体声明并初始化，构造函数中只赋值；不用参数属性、确定赋值断言 `!` 或 `#private`。可空字段显式写 `T | null/undefined` 与初始值。
- 类可用于命名类型、正常实例化及已声明静态成员；不把类/构造器当作函数值传递或赋给变量。不用构造签名或构造函数类型；确需工厂时使用返回实例的命名接口方法或 lambda。
- 不用对象调用签名、接口构造签名、泛型 `this` 类型。接口避免参数签名相同而返回类型不同的方法，也避免多重继承重复签名。
- 对象字面量必须对应明确的 class/interface。不要把无类型字面量塞给 Object/object，或用于带方法、带参构造器、readonly 字段的类。数组中对象元素也需明确可推断类型。
- 普通函数/方法明确标注返回类型。仅根据返回值推断泛型参数不允许，调用时显式传类型；返回另一无返回类型函数的结果也不能依赖传递推断。

## 表达式与运行时

- 使用 `let`/`const`，不用 `var`、`with`。
- 不用解构声明/赋值/参数、对象展开、`for..in`、函数表达式或嵌套函数声明。逐字段赋值；数组用普通循环或适用数组方法；回调用箭头函数。
- 数组展开仅用于数组字面量与 rest 参数调用。逗号运算符仅用于 `for` 的允许位置。
- `this` 只用于实例方法；静态方法用类名访问静态字段。共享状态通过模块导出/导入，不用 `globalThis`、原型赋值、动态字段或命名空间当值。
- 不用 `Function.call/apply/bind`、函数附加属性、生成器、`new.target`、JSX、`Symbol()`（允许的 `Symbol.iterator` 除外）。
- 不用 `in` / `is`；需要类型分支时按明确类型转换和适用的 `instanceof`，外部数据直接校验字段。
- 字段用 `obj.field`，不用 `obj['field']` 动态访问。数组、定型数组及项目允许的 Record 索引按其类型处理。
- 一元 `+/-/~` 只用于数字，字符串转数用明确转换并检查有效性。
- `typeof` 只在表达式中用于值校验；`catch (e)` 不标 `any`/`unknown`。确需 SDK 错误类型时在作用域内显式转换。
- 静态代码块最多一个。可序列化状态中不存函数、UIContext、计时器或原生句柄。

## 可复用的类型写法

```typescript
export interface ItemDto {
  id: string;
  title: string;
  updatedAtMs: number;
}

export class ItemState {
  items: ItemDto[] = [];
  loading: boolean = false;
  errorCode: string = '';
}

export interface ItemRepository {
  load(): Promise<ItemDto[]>;
}
```

这是类型边界示意，不是必须新增的文件结构，也不是网络 JSON 校验器。页面使用 V2 时，实际需要观测的状态另按 `@ObservedV2` / `@Trace` 声明。

## API、资源与工程

- 当前 LittleGames 配置为 HarmonyOS 6.1.1 / API 24，手机和平板。新工程读取自身 compile/compatible/target SDK，不自动升级或要求 API 24。
- 默认优先 HarmonyOS 官方 Kit、UI 组件、动画与示例。对任何不确定的 API/语法，搜索华为开发者官方文档，再核对本地目标 SDK `.d.ts`：名称、导入、重载、返回值、起始 API、系统能力与设备支持。不能将网页最新版直接套到较低 API。
- UI 操作用实例 UIContext：`this.getUIContext().animateTo(...)`、`getRouter()`、`px2vp(...)` 等；对 Navigation 工程继续使用现有 NavPathStack，不混加一套 Router 页面栈。
- ArkUI V2 组件内使用 `@Local` / `@Param`，ViewModel 使用 `@ObservedV2` / `@Trace`；事件声明先沿用目标项目，再核对 SDK 支持的 `@Event`。不在同一组件混写 V1/V2 状态装饰器。
- 调用系统能力前检查所需 import 与权限，在模块 `module.json5` 中配置能力实际需要的权限及资源化理由。不能根据旧 README 判定当前权限。
- LittleGames 当前 LAN 使用 `@kit.NetworkKit` 的 `connection` / `socket`，模块已声明 INTERNET、GET_NETWORK_INFO、VIBRATE；新业务按真实用途配置，不为纯离线应用预加网络权限。
- 依赖存在且版本兼容后才写入正确模块的 `oh-package.json5`。当前 entry 运行时依赖为空，优先沿用官方能力；测试用 `@ohos/hypium` 不等同于运行依赖。
- 界面字符串放资源，新增值覆盖所有现有语言目录（LittleGames 是 base、zh_CN、en_US），变量用资源格式化；颜色/尺寸资源与语义令牌集中定义，新颜色与素材默认维护 base/dark 同名资源。
- API 24 的 HDS 接口须核对 `@kit.UIDesignKit` 与 hds 声明；不要直接采用要求更高 target SDK 的新材质路线。查不到定义时不用猜造 API，以已核实的原生能力完成当前功能。
