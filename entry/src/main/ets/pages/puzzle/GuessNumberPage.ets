/**
 * 猜数字 —— View 层（纯展示与组装）
 *
 * 只持有 @Local viewModel，读取其 @Trace 状态、转发操作；不 import Model 类型。
 * 规则见 model/game/GuessNumberModel.ets，状态编排见 viewmodel/GuessNumberViewModel.ets。
 */
import { SemanticColors, RadiusTokens, FontTokens, ShadowTokens, SpacingTokens } from '../../common/DesignTokens';
import { GameHeader } from '../../components/GameHeader';
import { GameDifficulty, GameStatus } from '../../common/GameConstants';
import { SafeAreaInsets } from '../../common/SafeAreaInsets';
import { GameResultDialog } from '../../components/GameResultDialog';
import { ExitConfirmDialog } from '../../components/ExitConfirmDialog';
import { GameLifecycleBus } from '../../common/GameLifecycleBus';

import { GuessNumberViewModel, GuessRecord } from '../../viewmodel/GuessNumberViewModel';

@ComponentV2
export struct GuessNumberPage {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local safeBottom: number = SafeAreaInsets.bottom;
  @Local viewModel: GuessNumberViewModel = new GuessNumberViewModel();

  aboutToAppear(): void {
    GameLifecycleBus.attach(this.viewModel);
    this.viewModel.startGame();
  }

  aboutToDisappear(): void {
    GameLifecycleBus.detach(this.viewModel);
    this.viewModel.dispose();
  }

  /** 返回请求统一入口：进行中弹确认，其余直接返回 */
  requestExit(): void {
    if (this.viewModel.requestBack()) {
      return;
    }
    this.pathStack.pop();
  }

  getResultColor(a: number): ResourceColor {
    if (a === this.viewModel.getSecretLength()) { return SemanticColors.success; }
    return SemanticColors.warning;
  }

  getInputColor(): ResourceColor {
    if (this.viewModel.isInputComplete()) { return SemanticColors.success; }
    return SemanticColors.textPrimary;
  }

  getKeyFontSize(key: string): number {
    if (key === 'submit') { return FontTokens.sizeBody; }
    return 24;
  }

  getKeyFontColor(key: string): ResourceColor {
    if (key === 'submit') {
      if (this.viewModel.isInputComplete()) { return SemanticColors.textOnPrimary; }
      return SemanticColors.textTertiary;
    }
    return SemanticColors.textPrimary;
  }

  getKeyBgColor(key: string): ResourceColor {
    if (key === 'submit') {
      if (this.viewModel.isInputComplete()) { return SemanticColors.primary; }
      return SemanticColors.surfaceHover;
    }
    if (key === '⌫') { return SemanticColors.error; }
    return SemanticColors.surface;
  }

  getKeyShadow(key: string): ShadowOptions | undefined {
    if (key === 'submit' && this.viewModel.isInputComplete()) {
      return ShadowTokens.button;
    }
    return undefined;
  }

  getKeyA11yText(key: string): string {
    if (key === '⌫') {
      const context = this.getUIContext().getHostContext();
      if (context) {
        return context.resourceManager.getStringSync($r('app.string.a11y_keypad_delete'));
      }
      return 'Delete';
    }
    if (key === 'submit') {
      const context = this.getUIContext().getHostContext();
      if (context) {
        return context.resourceManager.getStringSync($r('app.string.a11y_keypad_submit'));
      }
      return 'Submit';
    }
    return key;
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[SemanticColors.gradientScreen[0], 0], [SemanticColors.gradientScreen[1], 0.5], [SemanticColors.gradientScreen[2], 1]] })

      Column() {
        GameHeader({ gameTitle: $r('app.string.game_guessnumber_name'),
          // subtitle 仅在 showScore 为 false 时显示，不关掉的话「尝试 N / M」永远被吃掉
          showScore: false,
          subtitle: $r('app.string.game_guessnumber_subtitle_format', this.viewModel.tries, this.viewModel.getMaxTries()),
          difficulty: this.viewModel.difficulty,
          onDifficultyChange: (d: GameDifficulty) => { this.viewModel.changeDifficulty(d); },
          onBack: () => { this.requestExit(); },
          onPauseToggle: () => {},
          onRestart: () => { this.viewModel.startGame(); } })

        Column() {
          Text($r('app.string.guess_hint_length_format', this.viewModel.getSecretLength()))
            .fontFamily(FontTokens.family).fontSize(FontTokens.sizeBodySmall)
            .fontColor(SemanticColors.textTertiary).margin({ top: SpacingTokens.sm })
          Text($r('app.string.guess_hint_submit_format', this.viewModel.getSecretLength()))
            .fontFamily(FontTokens.family).fontSize(FontTokens.sizeBodySmall)
            .fontColor(SemanticColors.textTertiary)
          Text($r('app.string.guess_tries_format', this.viewModel.tries, this.viewModel.getMaxTries()))
            .fontFamily(FontTokens.family).fontSize(FontTokens.sizeBodySmall)
            .fontColor(SemanticColors.warning).margin({ top: SpacingTokens.xs })
        }.alignItems(HorizontalAlign.Center).margin({ bottom: SpacingTokens.md })

        Column() {
          Row({ space: SpacingTokens.xs }) {
            SymbolGlyph($r('sys.symbol.list_bullet'))
              .fontSize(12).fontColor([SemanticColors.accent])
            Text($r('app.string.guess_records_title'))
              .fontFamily(FontTokens.family).fontSize(FontTokens.sizeBodySmall)
              .fontColor(SemanticColors.textTertiary).margin({ bottom: 0 })
          }.width('100%').margin({ left: SpacingTokens.base, right: SpacingTokens.base, bottom: 4 })

          List() {
            ForEach(this.viewModel.records.slice(0, 6), (rec: GuessRecord, index: number) => {
              ListItem() {
                Row() {
                  Text('#' + (this.viewModel.records.length - index))
                    .fontFamily(FontTokens.family).fontSize(FontTokens.sizeBodySmall)
                    .fontColor(SemanticColors.textTertiary).width(28)
                  Text(rec.guess).fontWeight(FontWeight.Bold)
                    .fontColor(SemanticColors.textPrimary).margin({ left: SpacingTokens.sm }).fontSize(FontTokens.sizeSubtitle)
                  Text(rec.a + 'A' + rec.b + 'B').fontWeight(FontWeight.Bold)
                    .fontColor(this.getResultColor(rec.a))
                    .margin({ left: SpacingTokens.md }).fontSize(FontTokens.sizeBodyLarge)
                  Blank()
                }.width('100%').padding({ left: SpacingTokens.sm, right: SpacingTokens.sm })
              }.height(40)
            }, (rec: GuessRecord) => rec.seq.toString())
          }.height(Math.min(this.viewModel.records.length * 40, 240))
          .backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base)
          .margin({ left: SpacingTokens.base, right: SpacingTokens.base })
        }.layoutWeight(1)

        Column() {
          Text(this.viewModel.input + '_'.repeat(this.viewModel.getSecretLength() - this.viewModel.input.length))
            .fontFamily(FontTokens.family)
            .fontSize(32).fontWeight(FontWeight.Bold)
            .fontColor(this.getInputColor())
            .margin({ bottom: SpacingTokens.base })

          this.KeyRow(['1', '2', '3'])
          this.KeyRow(['4', '5', '6'])
          this.KeyRow(['7', '8', '9'])
          this.KeyRow(['⌫', '0', 'submit'])
        }.padding({ bottom: SpacingTokens.lg })
      }.width('100%').height('100%').padding({ bottom: this.safeBottom })

      if (this.viewModel.isWin) {
        GameResultDialog({
          symbol: $r('sys.symbol.checkmark_circle'),
          symbolColor: SemanticColors.success,
          title: $r('app.string.result_guess_win'),
          detail: $r('app.string.result_detail_guess_win_format', this.viewModel.secret, this.viewModel.tries),
          detailColor: SemanticColors.warning,
          showDetail: true,
          primaryText: $r('app.string.result_play_again'),
          onPrimary: () => { this.viewModel.startGame(); },
          cardStyle: true
        })
      } else if (this.viewModel.status === GameStatus.OVER) {
        GameResultDialog({
          symbol: $r('sys.symbol.xmark_circle'),
          symbolColor: SemanticColors.error,
          title: $r('app.string.result_guess_fail_format', this.viewModel.getMaxTries()),
          detail: $r('app.string.result_detail_guess_fail_format', this.viewModel.secret),
          detailColor: SemanticColors.error,
          showDetail: true,
          primaryText: $r('app.string.result_play_again'),
          onPrimary: () => { this.viewModel.startGame(); },
          cardStyle: true
        })
      }

      if (this.viewModel.confirmExit) {
        ExitConfirmDialog({
          onConfirm: () => {
            this.viewModel.dismissExitConfirm();
            this.pathStack.pop();
          },
          onCancel: () => { this.viewModel.dismissExitConfirm(); }
        })
      }
    }.width('100%').height('100%')
  }

  @Builder
  KeyRow(keys: string[]) {
    Row({ space: SpacingTokens.sm }) {
      ForEach(keys, (key: string) => {
        Button() {
          if (key === '⌫') {
            SymbolGlyph($r('sys.symbol.delete_left'))
              .fontSize(20).fontColor([SemanticColors.textOnPrimary])
          } else if (key === 'submit') {
            Text($r('app.string.guess_confirm'))
              .fontFamily(FontTokens.family)
              .fontSize(this.getKeyFontSize(key))
              .fontColor(this.getKeyFontColor(key))
          } else {
            Text(key)
              .fontFamily(FontTokens.family)
              .fontSize(this.getKeyFontSize(key))
              .fontColor(this.getKeyFontColor(key))
          }
        }
        .layoutWeight(1).height(52)
        .backgroundColor(this.getKeyBgColor(key))
        .borderRadius(RadiusTokens.base)
        .shadow(this.getKeyShadow(key))
        .accessibilityText(this.getKeyA11yText(key))
        .onClick(() => {
          if (key === '⌫') { this.viewModel.deleteDigit(); }
          else if (key === 'submit') { this.viewModel.submit(); }
          else { this.viewModel.pushDigit(key); }
        })
      }, (key: string) => key)
    }
    .width('100%')
    .margin({ bottom: SpacingTokens.sm })
  }
}
