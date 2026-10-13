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
import { GameSessionParticipant } from './GameSessionTransfer';
import { systemDateTime } from '@kit.BasicServicesKit';
import { GameDataManager } from '../model/GameData';
import { gameSound } from './GameSound';

export interface GameLifecycleObserver extends GameSessionParticipant {
  onAppHidden(): void;
  onAppShown(): void;
  onBackRequested(): boolean;
  isPlayTimeActive(): boolean;
}

export class GameLifecycleBus {
  private static observer: GameLifecycleObserver | null = null;
  private static foreground: boolean = true;
  private static pageVisible: boolean = true;
  private static settingsVisible: boolean = false;
  private static startedAt: number = -1;
  private static playTimeTimer: number = -1;

  static isAppForeground(): boolean { return GameLifecycleBus.foreground; }

  static exportSession(gameId: string): string {
    const observer: GameLifecycleObserver | null = GameLifecycleBus.observer;
    if (observer === null || observer.continuationGameId() !== gameId) {
      throw new Error('Game page is not ready');
    }
    GameLifecycleBus.flushPlayTime();
    return observer.exportContinuation();
  }

  /** 注册活跃对局的观察者（游戏页 aboutToAppear 时调用） */
  static attach(observer: GameLifecycleObserver): void {
    GameLifecycleBus.flushPlayTime();
    GameLifecycleBus.stopPlayTime();
    GameLifecycleBus.observer = observer;
    GameLifecycleBus.pageVisible = true;
    GameLifecycleBus.settingsVisible = false;
    gameSound.selectGame(observer.continuationGameId());
    gameSound.setVisible(GameLifecycleBus.foreground);
    GameDataManager.recordGamePlayed(observer.continuationGameId());
  }

  /** 注销观察者（游戏页 aboutToDisappear 时调用）。校验身份，防误删 */
  static detach(observer: GameLifecycleObserver): void {
    if (GameLifecycleBus.observer === observer) {
      GameLifecycleBus.flushPlayTime();
      GameLifecycleBus.stopPlayTime();
      GameLifecycleBus.observer = null;
      gameSound.selectGame('');
    }
  }

  /** 应用切后台。观察者应在此结算当前分并暂停 */
  static notifyHidden(): void {
    GameLifecycleBus.flushPlayTime();
    GameLifecycleBus.foreground = false;
    gameSound.setVisible(false);
    GameLifecycleBus.stopPlayTime();
    if (GameLifecycleBus.observer !== null) {
      GameLifecycleBus.observer.onAppHidden();
    }
  }

  /** 应用回前台。观察者按需恢复自动暂停的对局 */
  static notifyShown(): void {
    GameLifecycleBus.foreground = true;
    gameSound.setVisible(GameLifecycleBus.pageVisible && !GameLifecycleBus.settingsVisible);
    if (GameLifecycleBus.observer !== null) {
      if (GameLifecycleBus.pageVisible && !GameLifecycleBus.settingsVisible) {
        GameLifecycleBus.observer.onAppShown();
      }
      GameLifecycleBus.updatePlayTime(GameLifecycleBus.observer);
    }
  }

  /** 半模态设置与应用设置页面均暂停对局，关闭后只恢复自动暂停。 */
  static setSettingsVisible(gameId: string, visible: boolean): void {
    const observer: GameLifecycleObserver | null = GameLifecycleBus.observer;
    if (observer === null || observer.continuationGameId() !== gameId ||
      GameLifecycleBus.settingsVisible === visible) { return; }
    GameLifecycleBus.flushPlayTime();
    GameLifecycleBus.settingsVisible = visible;
    GameLifecycleBus.refreshVisibility(observer);
  }

  static setPageVisible(gameId: string, visible: boolean): void {
    const observer: GameLifecycleObserver | null = GameLifecycleBus.observer;
    if (observer === null || observer.continuationGameId() !== gameId ||
      GameLifecycleBus.pageVisible === visible) { return; }
    GameLifecycleBus.flushPlayTime();
    GameLifecycleBus.pageVisible = visible;
    GameLifecycleBus.refreshVisibility(observer);
  }

  private static refreshVisibility(observer: GameLifecycleObserver): void {
    gameSound.setVisible(GameLifecycleBus.foreground && GameLifecycleBus.pageVisible && !GameLifecycleBus.settingsVisible);
    if (GameLifecycleBus.foreground && GameLifecycleBus.pageVisible && !GameLifecycleBus.settingsVisible) {
      observer.onAppShown();
    } else {
      observer.onAppHidden();
    }
    GameLifecycleBus.updatePlayTime(observer);
  }

  /**
   * 系统侧滑返回请求转发。
   * 返回 true = 观察者已消费（不退出页面），false = 放行（正常 pop）。
   */
  static notifyBackRequested(): boolean {
    if (GameLifecycleBus.observer !== null) {
      const consumed: boolean = GameLifecycleBus.observer.onBackRequested();
      GameLifecycleBus.updatePlayTime(GameLifecycleBus.observer);
      return consumed;
    }
    return false;
  }

  /** 游戏页监听对局状态变化，暂停、结算和确认弹窗均结束当前计时区间。 */
  static updatePlayTime(observer: GameLifecycleObserver): void {
    if (GameLifecycleBus.observer !== observer) { return; }
    GameLifecycleBus.checkpointPlayTime();
    if (GameLifecycleBus.foreground && GameLifecycleBus.pageVisible &&
      !GameLifecycleBus.settingsVisible && observer.isPlayTimeActive()) {
      if (GameLifecycleBus.startedAt < 0) { GameLifecycleBus.startedAt = GameLifecycleBus.uptime(); }
      if (GameLifecycleBus.playTimeTimer < 0) {
        GameLifecycleBus.playTimeTimer = setInterval(() => { GameLifecycleBus.checkpointPlayTime(); }, 5000);
      }
    } else {
      GameLifecycleBus.stopPlayTime();
      GameDataManager.flushNow();
    }
  }

  /** 接续替换旧页面时保留真实前后台状态，旧页面不再参与计时。 */
  static suspendSession(): void {
    GameLifecycleBus.flushPlayTime();
    GameLifecycleBus.stopPlayTime();
    if (GameLifecycleBus.observer !== null) { GameLifecycleBus.observer.onAppHidden(); }
    GameLifecycleBus.observer = null;
    gameSound.selectGame('');
  }

  /** 返回主页、切后台、退出和接续时立即结算剩余毫秒并落盘。 */
  static flushPlayTime(): void {
    GameLifecycleBus.checkpointPlayTime();
    GameDataManager.flushNow();
  }

  private static uptime(): number {
    try {
      const value: number = systemDateTime.getUptime(systemDateTime.TimeType.STARTUP, false);
      return Number.isFinite(value) && value >= 0 ? value : -1;
    } catch (e) {
      return -1;
    }
  }

  private static checkpointPlayTime(): void {
    const observer: GameLifecycleObserver | null = GameLifecycleBus.observer;
    if (observer === null) { return; }
    if (GameLifecycleBus.startedAt < 0) {
      if (GameLifecycleBus.foreground && GameLifecycleBus.pageVisible &&
        !GameLifecycleBus.settingsVisible && observer.isPlayTimeActive()) {
        GameLifecycleBus.startedAt = GameLifecycleBus.uptime();
      }
      return;
    }
    const now: number = GameLifecycleBus.uptime();
    if (now >= GameLifecycleBus.startedAt) {
      GameDataManager.addPlayTime(observer.continuationGameId(), now - GameLifecycleBus.startedAt);
    }
    GameLifecycleBus.startedAt = now;
  }

  private static stopPlayTime(): void {
    if (GameLifecycleBus.playTimeTimer >= 0) { clearInterval(GameLifecycleBus.playTimeTimer); }
    GameLifecycleBus.playTimeTimer = -1;
    GameLifecycleBus.startedAt = -1;
  }
}
