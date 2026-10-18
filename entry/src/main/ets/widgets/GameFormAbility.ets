import { Configuration, Want } from '@kit.AbilityKit';
import { formBindingData, FormExtensionAbility, formInfo, formProvider } from '@kit.FormKit';
import { preferences } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { GameDataManager, GAME_DATA_STORE_NAME } from '../model/GameData';
import { GameCards } from './GameCardData';

export default class GameFormAbility extends FormExtensionAbility {
  private readSavedData(): void {
    // FormExtension has its own process/cache; reload the app's flushed data before periodic updates.
    preferences.removePreferencesFromCacheSync(this.context, GAME_DATA_STORE_NAME);
    GameDataManager.init(this.context);
  }

  onAddForm(want: Want): formBindingData.FormBindingData {
    this.readSavedData();
    return GameCards.data(this.context);
  }

  onUpdateForm(formId: string): void {
    this.readSavedData();
    formProvider.updateForm(formId, GameCards.data(this.context)).catch((error: BusinessError) => {
      hilog.warn(0, 'GameCards', 'Scheduled widget update failed: %{public}d', error.code);
    });
  }

  onConfigurationUpdate(configuration: Configuration): void {
    this.readSavedData();
    GameCards.publish(this.context);
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }
}
