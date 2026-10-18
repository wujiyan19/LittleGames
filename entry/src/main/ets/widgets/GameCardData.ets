import { Context } from '@kit.AbilityKit';
import { formBindingData, formProvider } from '@kit.FormKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { GameDataManager } from '../model/GameData';
import { DailyFeaturedViewModel } from '../viewmodel/DailyFeaturedViewModel';
import { GameInfo } from '../common/GameConstants';
import { resolveString } from '../common/I18nUtils';

export class GameCardData {
  gameId: string = '';
  gameName: string = '';
  description: string = '';
  gameIcon: Resource | string = $r('app.media.game_2048');
  saved2048: boolean = false;
  savedSudoku: boolean = false;
}

/** Both the app and FormExtension use the same catalog, recommendations and saved-game keys. */
export class GameCards {
  static data(context: Context): formBindingData.FormBindingData {
    const daily: DailyFeaturedViewModel = new DailyFeaturedViewModel();
    daily.update(GameDataManager.getAllGames());
    const game: GameInfo = daily.recommendations[0];
    const data: GameCardData = new GameCardData();
    data.gameId = game.id;
    data.gameName = resolveString(game.name, context);
    data.description = resolveString(game.description, context);
    data.gameIcon = game.icon;
    data.saved2048 = GameDataManager.getSavedGame('2048').length > 0;
    data.savedSudoku = GameDataManager.getSavedGame('sudoku').length > 0;
    return formBindingData.createFormBindingData(data);
  }

  static async publish(context: Context): Promise<void> {
    try {
      const forms = await formProvider.getPublishedRunningFormInfos();
      const data: formBindingData.FormBindingData = GameCards.data(context);
      for (let i = 0; i < forms.length; i++) {
        if (forms[i].abilityName === 'GameFormAbility') {
          await formProvider.updateForm(forms[i].formId, data);
        }
      }
    } catch (error) {
      hilog.warn(0, 'GameCards', 'Widget update failed: %{public}d', (error as BusinessError).code);
    }
  }
}
