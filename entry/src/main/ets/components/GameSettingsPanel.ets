import { SemanticColors, FontTokens, RadiusTokens, SpacingTokens } from '../common/DesignTokens';
import { GameDifficulty, getDifficultyLabel } from '../common/GameConstants';
import { gameRules } from '../common/GameRules';
import { HarmonyMotion } from '../common/HarmonyMotion';
import { SettingsChoice } from './SettingsChoice';
import { SettingsSwitchRow } from './SettingsSwitchRow';
import { SettingsVolumeRow } from './SettingsVolumeRow';
import { GameSound, gameSound } from '../common/GameSound';
import { GameDataManager } from '../model/GameData';

@ComponentV2
export struct GameSettingsPanel {
  @Param gameId: string = '';
  @Param gameTitle: Resource | string = '';
  @Param difficulty: GameDifficulty = GameDifficulty.NORMAL;
  @Param showDifficulty: boolean = true;
  @Param showPause: boolean = true;
  @Param isPaused: boolean = false;
  @Param enableNewGame: boolean = false;
  @Param hasProgress: boolean = false;
  @Param onDifficultyChange: (diff: GameDifficulty) => void = () => {};
  @Param onPauseToggle: () => void = () => {};
  @Param onRestart: () => void = () => {};
  @Param onNewGame: () => void = () => {};
  @Param onAppSettings: () => void = () => {};
  @Param onClose: () => void = () => {};
  @Local showRules: boolean = false;
  @Local sound: GameSound = gameSound;
  private confirming: boolean = false;

  confirmAction(title: Resource, message: Resource, button: Resource, action: () => void): void {
    if (this.confirming) { return; }
    if (!this.hasProgress) { action(); return; }
    this.confirming = true;
    this.getUIContext().showAlertDialog({
      title: title, message: message, autoCancel: false,
      cancel: () => { this.confirming = false; },
      primaryButton: { value: $r('app.string.settings_cancel'), action: () => { this.confirming = false; } },
      secondaryButton: { value: button, action: () => { this.confirming = false; action(); } }
    });
  }

  chooseDifficulty(diff: GameDifficulty): void {
    if (diff === this.difficulty) { return; }
    this.confirmAction($r('app.string.game_settings_change_difficulty'), $r('app.string.game_settings_difficulty_confirm'),
      $r('app.string.game_settings_change_action'), () => { this.onDifficultyChange(diff); });
  }

  @Builder
  ActionRow(title: Resource, detail: Resource | string, symbol: Resource, action: () => void,
    showArrow: boolean = false, disclosure: boolean = false) {
    Button() {
      Row({ space: SpacingTokens.md }) {
        Column() {
          SymbolGlyph(symbol).fontSize(20).fontColor([SemanticColors.primary])
        }
        .width($r('app.float.home_action_min_height')).height($r('app.float.home_action_min_height'))
        .borderRadius(RadiusTokens.md).backgroundColor(SemanticColors.surfaceHover)
        .justifyContent(FlexAlign.Center)
        Column({ space: SpacingTokens.xs }) {
          Text(title).fontFamily(FontTokens.family).fontSize(FontTokens.sizeBodyLarge)
            .fontWeight(FontTokens.weightMedium).fontColor(SemanticColors.textPrimary)
          if (typeof detail !== 'string' || detail.length > 0) {
            Text(detail).fontFamily(FontTokens.family).fontSize(FontTokens.sizeBody)
              .fontColor(SemanticColors.textSecondary)
          }
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        if (showArrow) {
          SymbolGlyph(disclosure ? (this.showRules ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down')) : $r('sys.symbol.chevron_right'))
            .fontSize(14).fontColor([SemanticColors.textTertiary])
        }
      }.width('100%').padding(SpacingTokens.base)
    }
    .width('100%').type(ButtonType.Normal).padding(0)
    .constraintSize({ minHeight: $r('app.float.home_action_min_height') })
    .backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.lg)
    .clickEffect(HarmonyMotion.press(this.getUIContext())).onClick(action)
  }

  build() {
    Column() {
      Row({ space: SpacingTokens.md }) {
        Text($r('app.string.game_settings_title')).fontFamily(FontTokens.family)
          .fontSize($r('app.float.home_section_title_size')).fontWeight(FontTokens.weightBold)
          .fontColor(SemanticColors.textPrimary).layoutWeight(1)
        Button() { SymbolGlyph($r('sys.symbol.xmark')).fontSize(20).fontColor([SemanticColors.textSecondary]) }
          .type(ButtonType.Circle)
          .width($r('app.float.home_action_min_height')).height($r('app.float.home_action_min_height'))
          .backgroundColor(SemanticColors.surfaceHover)
          .accessibilityText($r('app.string.game_settings_return'))
          .clickEffect(HarmonyMotion.press(this.getUIContext())).onClick(() => { this.onClose(); })
      }.width('100%').padding({ left: SpacingTokens.base, right: SpacingTokens.base,
        top: SpacingTokens.sm, bottom: SpacingTokens.sm })
      Scroll() {
      Column({ space: SpacingTokens.md }) {
        Text(this.gameTitle).fontFamily(FontTokens.family).fontSize(FontTokens.sizeSubtitle)
          .fontWeight(FontTokens.weightSemibold).fontColor(SemanticColors.textSecondary)
          .width('100%').textAlign(TextAlign.Start)
        if (this.showDifficulty) {
          Column({ space: SpacingTokens.md }) {
            Text($r('app.string.game_settings_difficulty')).fontFamily(FontTokens.family)
              .fontSize(FontTokens.sizeBodyLarge).fontWeight(FontTokens.weightMedium)
              .fontColor(SemanticColors.textPrimary)
            Row({ space: SpacingTokens.sm }) {
              SettingsChoice({ label: getDifficultyLabel(GameDifficulty.EASY), selected: this.difficulty === GameDifficulty.EASY,
                onChoose: () => { this.chooseDifficulty(GameDifficulty.EASY); } })
              SettingsChoice({ label: getDifficultyLabel(GameDifficulty.NORMAL), selected: this.difficulty === GameDifficulty.NORMAL,
                onChoose: () => { this.chooseDifficulty(GameDifficulty.NORMAL); } })
              SettingsChoice({ label: getDifficultyLabel(GameDifficulty.HARD), selected: this.difficulty === GameDifficulty.HARD,
                onChoose: () => { this.chooseDifficulty(GameDifficulty.HARD); } })
            }.width('100%')
            Text($r('app.string.game_settings_difficulty_desc')).fontFamily(FontTokens.family)
              .fontSize(FontTokens.sizeBody).fontColor(SemanticColors.textSecondary)
              .width('100%')
          }.alignItems(HorizontalAlign.Start).width('100%').padding(SpacingTokens.base)
            .backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.lg)
        }
        if (this.showPause) {
          this.ActionRow(this.isPaused ? $r('app.string.a11y_header_resume') : $r('app.string.a11y_header_pause'), '',
            this.isPaused ? $r('sys.symbol.play') : $r('sys.symbol.pause'), () => { this.onPauseToggle(); })
        }
        this.ActionRow($r('app.string.header_restart'), '', $r('sys.symbol.arrow_clockwise'), () => {
          this.confirmAction($r('app.string.header_restart'), $r('app.string.game_settings_restart_confirm'),
            $r('app.string.header_restart'), () => { this.onRestart(); });
        })
        if (this.enableNewGame) {
          this.ActionRow($r('app.string.header_new_game'), '', $r('sys.symbol.plus'), () => {
            this.confirmAction($r('app.string.header_new_game'), $r('app.string.game_settings_new_game_confirm'),
              $r('app.string.header_new_game'), () => { this.onNewGame(); });
          })
        }
        Column() {
          SettingsSwitchRow({ title: $r('app.string.settings_sound'), detail: $r('app.string.settings_sound_desc'),
            isOn: this.sound.enabled, onToggle: (value: boolean) => { GameDataManager.setSetting('soundEnabled', value); } })
          Divider().color(SemanticColors.divider)
            .margin({ left: SpacingTokens.base, right: SpacingTokens.base })
          SettingsVolumeRow()
        }.width('100%').backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.lg)
        Column({ space: SpacingTokens.sm }) {
          this.ActionRow($r('app.string.game_settings_rules'), '', $r('sys.symbol.list_bullet'), () => { this.showRules = !this.showRules; },
            true, true)
          if (this.showRules) {
            Text(gameRules(this.gameId)).fontFamily(FontTokens.family).fontSize(FontTokens.sizeBody)
              .lineHeight($r('app.float.collection_rule_line')).fontColor(SemanticColors.textSecondary)
              .width('100%').padding({ left: SpacingTokens.base, right: SpacingTokens.base, bottom: SpacingTokens.base })
          }
        }.width('100%').backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.lg)
        this.ActionRow($r('app.string.game_settings_page'), $r('app.string.game_settings_page_desc'),
          $r('sys.symbol.gearshape'), () => { this.onAppSettings(); }, true)
      }.width('100%').constraintSize({ maxWidth: $r('app.float.collection_board_max') })
        .padding({ left: SpacingTokens.base, right: SpacingTokens.base, top: SpacingTokens.sm, bottom: SpacingTokens.base })
      }.width('100%').layoutWeight(1).scrollBar(BarState.Off).id('game-settings-content')
      Column() {
        Button() {
          Text($r('app.string.game_settings_return')).fontFamily(FontTokens.family).fontSize(FontTokens.sizeBodyLarge)
            .fontWeight(FontTokens.weightMedium).fontColor(SemanticColors.textOnPrimary)
            .width('100%').textAlign(TextAlign.Center)
        }
          .type(ButtonType.Normal)
          .width('100%').constraintSize({ minHeight: $r('app.float.home_action_min_height') })
          .padding({ left: SpacingTokens.base, right: SpacingTokens.base, top: SpacingTokens.md, bottom: SpacingTokens.md })
          .backgroundColor(SemanticColors.primary).fontColor(SemanticColors.textOnPrimary)
          .borderRadius(RadiusTokens.md).clickEffect(HarmonyMotion.press(this.getUIContext()))
          .id('game-settings-return')
          .onClick(() => { this.onClose(); })
      }.width('100%').constraintSize({ maxWidth: $r('app.float.collection_board_max') })
        .padding({ left: SpacingTokens.base, right: SpacingTokens.base, top: SpacingTokens.sm, bottom: SpacingTokens.xl })
    }.width('100%').height('100%').id('game-settings-panel')
      .backgroundColor(SemanticColors.bg).borderRadius(RadiusTokens.xl)
  }
}
