/**
 * 游戏生命周期总线 —— 模块级单例（ArkTS 禁用 globalThis，用显式模块单例）
 *
 * 为什么需要它：onPageShow()/onPageHide() 仅对 @Entry 组件生效（SDK common.d.ts 明确注释
 * "It works only for the custom components decorated by @Entry"），而本项目游戏页全部是
 * @ComponentV2（作为 NavDestination 内容），写在页面里的这两个钩子永远不会被调用。
 * 因此「切后台暂停 / 回前台恢复 / 系统侧滑返回拦截」改走显式总线：
 * - UIAbility.onBackground / onForeground → notifyHidden / notifyShown
 * - NavDestination.onBackPressed → notifyBackRequested
 * - 游戏页 aboutToAppear / aboutToDisappear → attach / detach
 *
 * 同时只挂载一个观察者（Navigation 栈中至多一个游戏页活跃，后注册者覆盖前注册者）。
 * detach 时校验身份，避免旧页面销毁时误删新页面的注册。
 */

/**
 * 游戏对局生命周期观察者。各 ViewModel 实现此接口，语义：
 * - onAppHidden：应用切后台（进程可能被杀，需先结算再暂停）或对局页被隐藏
 * - onAppShown：应用回前台，若此前为自动暂停则恢复
 * - onBackRequested：系统侧滑返回。返回 true 表示已拦截（如弹出退出确认），false 表示放行
 */
export interface GameLifecycleObserver {
  onAppHidden(): void;
  onAppShown(): void;
  onBackRequested(): boolean;
}

export class GameLifecycleBus {
  private static observer: GameLifecycleObserver | null = null;

  /** 注册活跃对局的观察者（游戏页 aboutToAppear 时调用） */
  static attach(observer: GameLifecycleObserver): void {
    GameLifecycleBus.observer = observer;
  }

  /** 注销观察者（游戏页 aboutToDisappear 时调用）。校验身份，防误删 */
  static detach(observer: GameLifecycleObserver): void {
    if (GameLifecycleBus.observer === observer) {
      GameLifecycleBus.observer = null;
    }
  }

  /** 应用切后台。观察者应在此结算当前分并暂停 */
  static notifyHidden(): void {
    if (GameLifecycleBus.observer !== null) {
      GameLifecycleBus.observer.onAppHidden();
    }
  }

  /** 应用回前台。观察者按需恢复自动暂停的对局 */
  static notifyShown(): void {
    if (GameLifecycleBus.observer !== null) {
      GameLifecycleBus.observer.onAppShown();
    }
  }

  /**
   * 系统侧滑返回请求转发。
   * 返回 true = 观察者已消费（不退出页面），false = 放行（正常 pop）。
   */
  static notifyBackRequested(): boolean {
    if (GameLifecycleBus.observer !== null) {
      return GameLifecycleBus.observer.onBackRequested();
    }
    return false;
  }
}