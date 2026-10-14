import { SemanticColors, FontTokens, SpacingTokens } from '../common/DesignTokens';
import { GameSound, gameSound } from '../common/GameSound';
import { GameDataManager } from '../model/GameData';

@ComponentV2
export struct SettingsVolumeRow {
  @Local sound: GameSound = gameSound;

  aboutToDisappear(): void { GameDataManager.flushNow(); }

  build() {
    Column({ space: SpacingTokens.sm }) {
      Row({ space: SpacingTokens.md }) {
        Text($r('app.string.settings_sound_volume')).fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeBodyLarge).fontWeight(FontTokens.weightMedium)
          .fontColor(SemanticColors.textPrimary).layoutWeight(1)
        Text($r('app.string.settings_sound_volume_value', this.sound.volume))
          .fontFamily(FontTokens.family).fontSize(FontTokens.sizeBody)
          .fontColor(SemanticColors.textSecondary)
      }.width('100%')
      Text($r('app.string.settings_sound_volume_desc')).fontFamily(FontTokens.family)
        .fontSize(FontTokens.sizeBody).fontColor(SemanticColors.textSecondary).width('100%')
      Slider({ value: this.sound.volume, min: GameSound.MIN_VOLUME, max: GameSound.MAX_VOLUME,
        step: GameSound.VOLUME_STEP, style: SliderStyle.OutSet })
        .width('100%').height($r('app.float.home_action_min_height'))
        .selectedColor(SemanticColors.primary).trackColor(SemanticColors.divider)
        .showTips(true, $r('app.string.settings_sound_volume_value', this.sound.volume))
        .accessibilityText($r('app.string.settings_sound_volume')).id('settings-sound-volume')
        .onChange((value: number, mode: SliderChangeMode) => {
          GameDataManager.setSoundVolume(value, mode === SliderChangeMode.End || mode === SliderChangeMode.Click);
        })
    }.width('100%').alignItems(HorizontalAlign.Start).padding(SpacingTokens.base)
  }
}
