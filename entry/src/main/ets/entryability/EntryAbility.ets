import { UIAbility, Want, AbilityConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { GameDataManager } from '../model/GameData';
import { SafeAreaInsets } from '../common/SafeAreaInsets';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'LittleGames', '%{public}s', 'onCreate');
    GameDataManager.init(this.context);
  }

  onDestroy(): void {
    hilog.info(0x0000, 'LittleGames', '%{public}s', 'onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(0x0000, 'LittleGames', '%{public}s', 'onWindowStageCreate');
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'LittleGames', 'Failed to load content: %{public}s', err.message);
        return;
      }
      this.initSafeArea(windowStage);
    });
  }

  /**
   * 初始化底部安全区避让高度，并监听其变化（如三键导航 ⇄ 手势导航切换）。
   * 失败时 SafeAreaInsets.bottom 保持 0，退化为「不额外避让」，无副作用。
   */
  private initSafeArea(windowStage: window.WindowStage): void {
    try {
      const win: window.Window = windowStage.getMainWindowSync();
      SafeAreaInsets.updateFromWindow(win);
      win.on('avoidAreaChange', (options: window.AvoidAreaOptions) => {
        if (options.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
          SafeAreaInsets.updateFromWindow(win);
        }
      });
    } catch (e) {
      hilog.error(0x0000, 'LittleGames', 'Failed to init safe area insets');
    }
  }

  onWindowStageDestroy(): void {
    hilog.info(0x0000, 'LittleGames', '%{public}s', 'onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(0x0000, 'LittleGames', '%{public}s', 'onForeground');
  }

  onBackground(): void {
    hilog.info(0x0000, 'LittleGames', '%{public}s', 'onBackground');
    // 落盘走 200ms 防抖，这里强制刷一次，避免防抖窗口内的变更因进程被杀而丢失
    GameDataManager.flushNow();
  }
}
