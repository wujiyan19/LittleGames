import { UIAbility, Want, AbilityConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { GameDataManager } from '../model/GameData';

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
    windowStage.loadContent('pages/SplashPage', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'LittleGames', 'Failed to load content: %{public}s', err.message);
      }
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(0x0000, 'LittleGames', '%{public}s', 'onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(0x0000, 'LittleGames', '%{public}s', 'onForeground');
  }

  onBackground(): void {
    hilog.info(0x0000, 'LittleGames', '%{public}s', 'onBackground');
  }
}
