/**
 * 统一游戏头部组件 — 宇宙蓝 × 雪域灰
 * 使用系统 Symbol 图标，交互热区 ≥ 44vp
 */
import { SemanticColors, FontTokens, SpacingTokens } from '../common/DesignTokens';
import { GameDifficulty } from '../common/GameConstants';
import { HarmonyMotion } from '../common/HarmonyMotion';
import { GameLifecycleBus } from '../common/GameLifecycleBus';
import { GameSettingsPanel } from './GameSettingsPanel';

@ComponentV2
export struct GameHeader {
  @Param gameId: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Param gameTitle: Resource | string = '';
  @Param subtitle: Resource | string = '';
  @Param isPaused: boolean = false;
  @Param showScore: boolean = true;
  @Param scoreValue: number = 0;
  @Param highScoreValue: number = 0;
  @Param difficulty: GameDifficulty = GameDifficulty.NORMAL;
  @Param onDifficultyChange: (diff: GameDifficulty) => void = () => {};
  @Param onBack: () => void = () => {};
  @Param onPauseToggle: () => void = () => {};
  @Param onRestart: () => void = () => {};
  @Param onNewGame: () => void = () => {};
  // 无暂停玩法的游戏（如数独/拼图）在设置内隐藏暂停项。
  @Param showPause: boolean = true;
  @Param showDifficulty: boolean = true;
  // 设置内同时提供「重新开始当前题目」和「新游戏」。
  @Param enableNewGame: boolean = false;
  @Param hasProgress: () => boolean = (): boolean => true;
  @Local showSettings: boolean = false;
  @Local pausedBeforeSettings: boolean = false;
  @Local protectProgress: boolean = false;
  private pendingAction: () => void = () => {};

  openSettings(): void {
    this.protectProgress = this.hasProgress();
    this.pausedBeforeSettings = this.isPaused;
    this.pendingAction = () => {};
    GameLifecycleBus.setSettingsVisible(this.gameId, true);
    this.showSettings = true;
  }

  closeSettings(action: () => void): void {
    if (!this.showSettings) { return; }
    this.pendingAction = action;
    this.showSettings = false;
  }

  settingsDismissed(): void {
    this.showSettings = false;
    // 应用设置接着显示时保持暂停，避免在两层设置之间短暂恢复游戏。
    const action: () => void = this.pendingAction;
    this.pendingAction = () => {};
    action();
    GameLifecycleBus.setSettingsVisible(this.gameId, false);
  }

  aboutToDisappear(): void {
    GameLifecycleBus.setSettingsVisible(this.gameId, false);
  }

  build() {
    Row({ space: SpacingTokens.md }) {
      // 返回（统一的 44vp 热区）
      Button() {
        SymbolGlyph($r('sys.symbol.arrow_left'))
          .fontSize(20)
          .fontColor([SemanticColors.textPrimary])
      }
      .type(ButtonType.Circle)
      .width($r('app.float.home_action_min_height')).height($r('app.float.home_action_min_height'))
      .backgroundColor(SemanticColors.surface)
      .clickEffect(HarmonyMotion.press(this.getUIContext()))

      .accessibilityText($r('app.string.a11y_header_back'))
      .onClick(() => {
        this.onBack();
      })

      Column() {
        Text(this.gameTitle)
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeSubtitle)
          .fontWeight(FontTokens.weightBold)
          .fontColor(SemanticColors.textPrimary)
        if (this.showScore) {
          Text($r('app.string.header_score_format', this.scoreValue, this.highScoreValue))
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeCaption)
            .fontColor(SemanticColors.textTertiary)
            .margin({ top: 2 })
        } else if (typeof this.subtitle !== 'string' || this.subtitle.length > 0) {
          Text(this.subtitle)
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeCaption)
            .fontColor(SemanticColors.textTertiary)
            .margin({ top: 2 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Button() {
        SymbolGlyph($r('sys.symbol.gearshape'))
          .fontSize(20).fontColor([SemanticColors.textPrimary])
      }
      .type(ButtonType.Circle)
      .width($r('app.float.home_action_min_height')).height($r('app.float.home_action_min_height'))
      .backgroundColor(SemanticColors.surface)
      .clickEffect(HarmonyMotion.press(this.getUIContext()))
      .accessibilityText($r('app.string.game_settings_title'))
      .id('game-settings-button')
      .onClick(() => { this.openSettings(); })
      .bindSheet($$this.showSettings, this.settingsPanel, {
        height: SheetSize.LARGE,
        showClose: false,
        dragBar: false,
        backgroundColor: SemanticColors.bg,
        onDisappear: () => { this.settingsDismissed(); }
      })
    }
    .width('100%')
    .padding({
      left: SpacingTokens.base,
      right: SpacingTokens.base,
      top: SpacingTokens.sm,
      bottom: SpacingTokens.sm
    })
    .backgroundColor(SemanticColors.surface)
  }

  @Builder
  settingsPanel() {
    GameSettingsPanel({
      gameId: this.gameId, gameTitle: this.gameTitle,
      difficulty: this.difficulty, showDifficulty: this.showDifficulty,
      showPause: this.showPause, isPaused: this.pausedBeforeSettings,
      enableNewGame: this.enableNewGame,
      hasProgress: this.protectProgress,
      onDifficultyChange: (diff: GameDifficulty) => {
        if (diff === this.difficulty) { return; }
        this.closeSettings(() => {
          GameLifecycleBus.setSettingsVisible(this.gameId, false);
          this.onDifficultyChange(diff);
        });
      },
      onPauseToggle: () => { this.closeSettings(() => {
        GameLifecycleBus.setSettingsVisible(this.gameId, false);
        this.onPauseToggle();
      }); },
      onRestart: () => { this.closeSettings(() => {
        GameLifecycleBus.setSettingsVisible(this.gameId, false);
        this.onRestart();
      }); },
      onNewGame: () => { this.closeSettings(() => {
        GameLifecycleBus.setSettingsVisible(this.gameId, false);
        this.onNewGame();
      }); },
      onAppSettings: () => { this.closeSettings(() => {
        GameLifecycleBus.setPageVisible(this.gameId, false);
        this.pathStack.pushPathByName('SettingsPage', null);
      }); },
      onClose: () => { this.closeSettings(() => {}); }
    })
  }
}
