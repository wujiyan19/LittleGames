/**
 * 统一游戏头部组件 — 宇宙蓝 × 雪域灰
 * 使用系统 Symbol 图标，交互热区 ≥ 40vp
 */
import { DarkColors, FontTokens, RadiusTokens, ShadowTokens, SpacingTokens } from '../common/DesignTokens';
import { GameDifficulty } from '../common/GameConstants';

@ComponentV2
export struct GameHeader {
  @Param gameTitle: string = '';
  @Param subtitle: string = '';
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
  // 无暂停玩法的游戏（如数独/拼图）隐藏暂停键，避免无效按钮
  @Param showPause: boolean = true;
  // 开启后刷新按钮变为「重新开始 / 新游戏」菜单
  @Param enableNewGame: boolean = false;
  @Local showRefreshMenu: boolean = false;

  build() {
    Row({ space: SpacingTokens.md }) {
      // 返回（40×40 热区）
      Button() {
        SymbolGlyph($r('sys.symbol.arrow_left'))
          .fontSize(20)
          .fontColor([DarkColors.textPrimary])
      }
      .type(ButtonType.Circle)
      .width(40).height(40)
      .backgroundColor(DarkColors.surface)
      .shadow(ShadowTokens.button)
      .onClick(() => {
        this.onBack();
      })

      Column() {
        Text(this.gameTitle)
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeSubtitle)
          .fontWeight(FontTokens.weightBold)
          .fontColor(DarkColors.textPrimary)
        if (this.showScore) {
          Text('得分 ' + this.scoreValue + ' · 最高 ' + this.highScoreValue)
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeCaption)
            .fontColor(DarkColors.textTertiary)
            .margin({ top: 2 })
        } else if (this.subtitle.length > 0) {
          Text(this.subtitle)
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeCaption)
            .fontColor(DarkColors.textTertiary)
            .margin({ top: 2 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Row({ space: SpacingTokens.sm }) {
        // 难度选择
        Button() {
          SymbolGlyph($r('sys.symbol.gearshape'))
            .fontSize(18)
            .fontColor([DarkColors.textPrimary])
        }
        .type(ButtonType.Circle)
        .width(40).height(40)
        .backgroundColor(DarkColors.surface)
        .shadow(ShadowTokens.button)
        .bindMenu(this.difficultyMenu)

        // 暂停 / 继续
        if (this.showPause) {
          Button() {
            SymbolGlyph(this.isPaused ? $r('sys.symbol.play') : $r('sys.symbol.pause'))
              .fontSize(18)
              .fontColor([DarkColors.textPrimary])
          }
          .type(ButtonType.Circle)
          .width(40).height(40)
          .backgroundColor(DarkColors.surface)
          .shadow(ShadowTokens.button)
          .onClick(() => { this.onPauseToggle(); })
        }

        // 刷新：重新开始 / 新游戏
        Button() {
          SymbolGlyph($r('sys.symbol.arrow_clockwise'))
            .fontSize(18)
            .fontColor([DarkColors.textPrimary])
        }
        .type(ButtonType.Circle)
        .width(40).height(40)
        .backgroundColor(DarkColors.surface)
        .shadow(ShadowTokens.button)
        .onClick(() => {
          if (this.enableNewGame) {
            this.showRefreshMenu = true;
          } else {
            this.onRestart();
          }
        })
        .bindMenu(this.showRefreshMenu, this.refreshMenu, {
          onDisappear: () => { this.showRefreshMenu = false; }
        })
      }
    }
    .width('100%')
    .padding({
      left: SpacingTokens.base,
      right: SpacingTokens.base,
      top: SpacingTokens.sm,
      bottom: SpacingTokens.sm
    })
    .backgroundColor(DarkColors.surfaceTranslucent)
    .backdropBlur(20)
  }

  @Builder
  difficultyMenu() {
    Menu() {
      MenuItem() {
        Text('简单')
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeBody)
          .fontColor(DarkColors.textPrimary)
      }
      .selected(this.difficulty === GameDifficulty.EASY)
      .onClick(() => { this.onDifficultyChange(GameDifficulty.EASY); })
      MenuItem() {
        Text('普通')
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeBody)
          .fontColor(DarkColors.textPrimary)
      }
      .selected(this.difficulty === GameDifficulty.NORMAL)
      .onClick(() => { this.onDifficultyChange(GameDifficulty.NORMAL); })
      MenuItem() {
        Text('困难')
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeBody)
          .fontColor(DarkColors.textPrimary)
      }
      .selected(this.difficulty === GameDifficulty.HARD)
      .onClick(() => { this.onDifficultyChange(GameDifficulty.HARD); })
    }
    .backgroundColor(DarkColors.surface)
    .radius(RadiusTokens.base)
  }

  @Builder
  refreshMenu() {
    Menu() {
      MenuItem() {
        Text('重新开始')
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeBody)
          .fontColor(DarkColors.textPrimary)
      }
      .onClick(() => { this.onRestart(); })
      MenuItem() {
        Text('新游戏')
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeBody)
          .fontColor(DarkColors.textPrimary)
      }
      .onClick(() => { this.onNewGame(); })
    }
    .backgroundColor(DarkColors.surface)
    .radius(RadiusTokens.base)
  }
}
