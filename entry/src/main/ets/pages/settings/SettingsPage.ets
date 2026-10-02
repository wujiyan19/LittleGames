import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { SemanticColors, FontTokens, SpacingTokens, RadiusTokens } from '../../common/DesignTokens';
import { GameDifficulty, getDifficultyLabel } from '../../common/GameConstants';
import { GameDataManager } from '../../model/GameData';
import { AppTheme } from '../../common/AppTheme';
import { AppInfo } from '../../common/AppInfo';
import { Haptics } from '../../common/Haptics';
import { SafeAreaInsets } from '../../common/SafeAreaInsets';
import { SettingsHeader } from '../../components/SettingsHeader';
import { SettingsChoice } from '../../components/SettingsChoice';
import { SettingsSwitchRow } from '../../components/SettingsSwitchRow';

@ComponentV2
export struct SettingsPage {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Param onDataChanged: () => void = () => {};
  @Local themeMode: string = GameDataManager.getThemeMode();
  @Local difficulty: GameDifficulty = GameDataManager.getDefaultDifficulty();
  @Local hapticsEnabled: boolean = GameDataManager.getSetting('hapticsEnabled', true);
  @Local rememberDifficulty: boolean = GameDataManager.getSetting('rememberDifficulty', false);
  @Local confirmExitEnabled: boolean = GameDataManager.getSetting('confirmExitEnabled', true);
  @Local version: string = AppInfo.version();

  applyTheme(mode: string): boolean {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (AppTheme.apply(context, mode)) { return true; }
    this.showMessage($r('app.string.settings_theme_failed'));
    return false;
  }

  showMessage(message: Resource): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (e) {
      hilog.error(0x0000, 'LittleGames', 'Failed to show settings feedback');
    }
  }

  changeTheme(mode: string): void {
    if (this.themeMode === mode || !this.applyTheme(mode)) { return; }
    GameDataManager.setTextSetting('themeMode', mode);
    this.themeMode = mode;
  }

  changeDifficulty(value: GameDifficulty): void {
    this.difficulty = value;
    GameDataManager.setTextSetting('defaultDifficulty', value);
  }

  confirmReset(): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.settings_reset'),
      message: $r('app.string.settings_reset_confirm'),
      autoCancel: false,
      primaryButton: { value: $r('app.string.settings_cancel'), action: () => {} },
      secondaryButton: { value: $r('app.string.settings_restore'), action: () => {
        if (!this.applyTheme('system')) { return; }
        GameDataManager.resetSettings();
        this.themeMode = GameDataManager.getThemeMode();
        this.difficulty = GameDataManager.getDefaultDifficulty();
        this.hapticsEnabled = GameDataManager.getSetting('hapticsEnabled', true);
        this.rememberDifficulty = GameDataManager.getSetting('rememberDifficulty', false);
        this.confirmExitEnabled = GameDataManager.getSetting('confirmExitEnabled', true);
        this.showMessage($r('app.string.settings_reset_done'));
      } }
    });
  }

  confirmClear(): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.settings_clear'),
      message: $r('app.string.settings_clear_confirm'),
      autoCancel: false,
      primaryButton: { value: $r('app.string.settings_cancel'), action: () => {} },
      secondaryButton: { value: $r('app.string.settings_clear_action'), fontColor: SemanticColors.error, action: () => {
        GameDataManager.clearPlayData();
        this.onDataChanged();
        this.showMessage($r('app.string.settings_clear_done'));
      } }
    });
  }

  @Builder
  SectionTitle(title: Resource) {
    Text(title)
      .fontFamily(FontTokens.family).fontSize(FontTokens.sizeBodySmall)
      .fontWeight(FontTokens.weightMedium).fontColor(SemanticColors.textTertiary)
      .width('100%').textAlign(TextAlign.Start)
      .padding({ left: SpacingTokens.base, top: SpacingTokens.lg, bottom: SpacingTokens.sm })
  }

  @Builder
  Description(title: Resource, detail: Resource) {
    Column({ space: SpacingTokens.xs }) {
      Text(title).fontFamily(FontTokens.family).fontSize(FontTokens.sizeBodyLarge)
        .fontWeight(FontTokens.weightMedium).fontColor(SemanticColors.textPrimary)
      Text(detail).fontFamily(FontTokens.family).fontSize(FontTokens.sizeBodySmall)
        .fontColor(SemanticColors.textTertiary)
    }.alignItems(HorizontalAlign.Start).layoutWeight(1)
  }

  @Builder
  LinkRow(title: Resource, detail: Resource | string, action: () => void, destructive: boolean = false) {
    Button() {
      Row({ space: SpacingTokens.md }) {
        Column({ space: SpacingTokens.xs }) {
          Text(title).fontFamily(FontTokens.family).fontSize(FontTokens.sizeBodyLarge)
            .fontColor(destructive ? SemanticColors.error : SemanticColors.textPrimary)
          Text(detail).fontFamily(FontTokens.family).fontSize(FontTokens.sizeBodySmall)
            .fontColor(SemanticColors.textTertiary)
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([SemanticColors.textTertiary])
      }.width('100%')
    }.type(ButtonType.Normal).width('100%')
    .padding(SpacingTokens.base).backgroundColor(SemanticColors.surface)
    .borderRadius(RadiusTokens.lg).onClick(action)
  }

  build() {
    Column() {
      SettingsHeader({ onBack: () => { this.pathStack.pop(); } })
      Scroll() {
        Column() {
          Text($r('app.string.settings_intro')).fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeBody).fontColor(SemanticColors.textTertiary)
            .width('100%').textAlign(TextAlign.Start).padding({ left: SpacingTokens.base })

          this.SectionTitle($r('app.string.settings_appearance'))
          Column({ space: SpacingTokens.md }) {
            Row() { this.Description($r('app.string.settings_theme'), $r('app.string.settings_theme_desc')) }
            Row({ space: SpacingTokens.sm }) {
              SettingsChoice({ label: $r('app.string.settings_theme_system'), selected: this.themeMode === 'system', onChoose: () => { this.changeTheme('system'); } })
              SettingsChoice({ label: $r('app.string.settings_theme_light'), selected: this.themeMode === 'light', onChoose: () => { this.changeTheme('light'); } })
              SettingsChoice({ label: $r('app.string.settings_theme_dark'), selected: this.themeMode === 'dark', onChoose: () => { this.changeTheme('dark'); } })
            }.width('100%')
          }.width('100%').padding(SpacingTokens.base).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.lg)

          this.SectionTitle($r('app.string.settings_gameplay'))
          Column() {
            Column({ space: SpacingTokens.md }) {
              Row() { this.Description($r('app.string.settings_difficulty'), $r('app.string.settings_difficulty_desc')) }
              Row({ space: SpacingTokens.sm }) {
                SettingsChoice({ label: getDifficultyLabel(GameDifficulty.EASY), selected: this.difficulty === GameDifficulty.EASY, onChoose: () => { this.changeDifficulty(GameDifficulty.EASY); } })
                SettingsChoice({ label: getDifficultyLabel(GameDifficulty.NORMAL), selected: this.difficulty === GameDifficulty.NORMAL, onChoose: () => { this.changeDifficulty(GameDifficulty.NORMAL); } })
                SettingsChoice({ label: getDifficultyLabel(GameDifficulty.HARD), selected: this.difficulty === GameDifficulty.HARD, onChoose: () => { this.changeDifficulty(GameDifficulty.HARD); } })
              }.width('100%')
            }.width('100%').padding(SpacingTokens.base)
            SettingsSwitchRow({ title: $r('app.string.settings_remember_difficulty'), detail: $r('app.string.settings_remember_difficulty_desc'), isOn: this.rememberDifficulty, onToggle: (value: boolean) => {
              this.rememberDifficulty = value;
              GameDataManager.setSetting('rememberDifficulty', value);
            } })
            SettingsSwitchRow({ title: $r('app.string.settings_haptics'), detail: $r('app.string.settings_haptics_desc'), isOn: this.hapticsEnabled, onToggle: (value: boolean) => {
              this.hapticsEnabled = value;
              GameDataManager.setSetting('hapticsEnabled', value);
              if (value) { Haptics.success(); }
            } })
            SettingsSwitchRow({ title: $r('app.string.settings_confirm_exit'), detail: $r('app.string.settings_confirm_exit_desc'), isOn: this.confirmExitEnabled, onToggle: (value: boolean) => {
              this.confirmExitEnabled = value;
              GameDataManager.setSetting('confirmExitEnabled', value);
            } })
          }.width('100%').backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.lg)

          this.SectionTitle($r('app.string.settings_data'))
          Column() {
            this.LinkRow($r('app.string.settings_reset'), $r('app.string.settings_reset_desc'), () => { this.confirmReset(); })
            this.LinkRow($r('app.string.settings_clear'), $r('app.string.settings_clear_desc'), () => { this.confirmClear(); }, true)
          }.width('100%').backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.lg)

          this.SectionTitle($r('app.string.settings_about_section'))
          this.LinkRow($r('app.string.settings_about'), $r('app.string.settings_about_desc'), () => {
            this.pathStack.pushPathByName('AboutPage', null);
          })
          Row({ space: SpacingTokens.md }) {
            Text($r('app.string.settings_version')).fontFamily(FontTokens.family)
              .fontSize(FontTokens.sizeBody).fontColor(SemanticColors.textTertiary).layoutWeight(1)
            Text(this.version.length > 0 ? this.version : $r('app.string.settings_version_unavailable'))
              .fontFamily(FontTokens.family).fontSize(FontTokens.sizeBodySmall).fontColor(SemanticColors.textTertiary)
          }.width('100%').padding(SpacingTokens.base)
        }.width('100%')
        .padding({ left: SpacingTokens.pageHorizontal, right: SpacingTokens.pageHorizontal,
          bottom: SpacingTokens.xxl + SafeAreaInsets.bottom })
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
    }.width('100%').height('100%').backgroundColor(SemanticColors.bg)
  }
}
