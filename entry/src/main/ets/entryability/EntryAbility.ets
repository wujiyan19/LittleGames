import { UIAbility, Want, AbilityConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { GameDataManager } from '../model/GameData';
import { SafeAreaInsets } from '../common/SafeAreaInsets';
import { ScreenUtils } from '../common/ScreenUtils';

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
      this.initWindowMetrics(windowStage);
    });
  }

  /**
   * 初始化与窗口相关的度量值（底部安全区避让、窗口宽度），并监听其变化。
   * 失败时保持默认值 0，退化为「不额外避让 / 回退到屏幕宽度」，无副作用。
   */
  private initWindowMetrics(windowStage: window.WindowStage): void {
    try {
      const win: window.Window = windowStage.getMainWindowSync();
      SafeAreaInsets.updateFromWindow(win);
      ScreenUtils.updateFromWindow(win);
      win.on('avoidAreaChange', (options: window.AvoidAreaOptions) => {
        if (options.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
          SafeAreaInsets.updateFromWindow(win);
        }
      });
      // 分屏 / 自由窗口 / 折叠屏展开与旋转都会触发，保持宽度最新
      win.on('windowSizeChange', () => {
        SafeAreaInsets.updateFromWindow(win);
        ScreenUtils.updateFromWindow(win);
      });
    } catch (e) {
      hilog.error(0x0000, 'LittleGames', 'Failed to init window metrics');
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
