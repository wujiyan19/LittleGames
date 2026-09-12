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
import { GuessNumberViewModel, GuessRecord } from '../../viewmodel/GuessNumberViewModel';

@ComponentV2
export struct GuessNumberPage {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local safeBottom: number = SafeAreaInsets.bottom;
  @Local viewModel: GuessNumberViewModel = new GuessNumberViewModel();

  aboutToAppear(): void { this.viewModel.startGame(); }

  getResultColor(a: number): ResourceColor {
    if (a === this.viewModel.getSecretLength()) { return SemanticColors.success; }
    return SemanticColors.warning;
  }

  getInputColor(): ResourceColor {
    if (this.viewModel.isInputComplete()) { return SemanticColors.success; }
    return SemanticColors.textPrimary;
  }

  getKeyFontSize(key: string): number {
    if (key === '确定') { return FontTokens.sizeBody; }
    return 24;
  }

  getKeyFontColor(key: string): ResourceColor {
    if (key === '确定') {
      if (this.viewModel.isInputComplete()) { return SemanticColors.textOnPrimary; }
      return SemanticColors.textTertiary;
    }
    return SemanticColors.textPrimary;
  }

  getKeyBgColor(key: string): ResourceColor {
    if (key === '确定') {
      if (this.viewModel.isInputComplete()) { return SemanticColors.primary; }
      return SemanticColors.surfaceHover;
    }
    if (key === '⌫') { return SemanticColors.error; }
    return SemanticColors.surface;
  }

  getKeyShadow(key: string): ShadowOptions | undefined {
    if (key === '确定' && this.viewModel.isInputComplete()) {
      return ShadowTokens.button;
    }
    return undefined;
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[SemanticColors.gradientScreen[0], 0], [SemanticColors.gradientScreen[1], 0.5], [SemanticColors.gradientScreen[2], 1]] })

      Column() {
        GameHeader({ gameTitle: '猜数字',
          // subtitle 仅在 showScore 为 false 时显示，不关掉的话「尝试 N / M」永远被吃掉
          showScore: false,
          subtitle: '尝试 ' + this.viewModel.tries + ' / ' + this.viewModel.getMaxTries(),
          difficulty: this.viewModel.difficulty,
          onDifficultyChange: (d: GameDifficulty) => { this.viewModel.changeDifficulty(d); },
          onBack: () => { this.pathStack.pop(); },
          onPauseToggle: () => {},
          onRestart: () => { this.viewModel.startGame(); } })

        Column() {
          Text('猜一个由' + this.viewModel.getSecretLength() + '个不重复数字组成的密码')
            .fontFamily(FontTokens.family).fontSize(FontTokens.sizeBodySmall)
            .fontColor(SemanticColors.textTertiary).margin({ top: SpacingTokens.sm })
          Text('输入' + this.viewModel.getSecretLength() + '位数字后提交')
            .fontFamily(FontTokens.family).fontSize(FontTokens.sizeBodySmall)
            .fontColor(SemanticColors.textTertiary)
          Text('已尝试: ' + this.viewModel.tries + '/' + this.viewModel.getMaxTries())
            .fontFamily(FontTokens.family).fontSize(FontTokens.sizeBodySmall)
            .fontColor(SemanticColors.warning).margin({ top: SpacingTokens.xs })
        }.alignItems(HorizontalAlign.Center).margin({ bottom: SpacingTokens.md })

        Column() {
          Row({ space: SpacingTokens.xs }) {
            SymbolGlyph($r('sys.symbol.list_bullet'))
              .fontSize(12).fontColor([SemanticColors.accent])
            Text('猜测记录')
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
          this.KeyRow(['⌫', '0', '确定'])
        }.padding({ bottom: SpacingTokens.lg })
      }.width('100%').height('100%').padding({ bottom: this.safeBottom })

      if (this.viewModel.isWin) {
        GameResultDialog({
          symbol: $r('sys.symbol.checkmark_circle'),
          symbolColor: SemanticColors.success,
          title: '恭喜猜中!',
          detail: '密码: ' + this.viewModel.secret + '  ·  ' + this.viewModel.tries + ' 次',
          detailColor: SemanticColors.warning,
          primaryText: '再来一局',
          onPrimary: () => { this.viewModel.startGame(); },
          cardStyle: true
        })
      } else if (this.viewModel.status === GameStatus.OVER) {
        GameResultDialog({
          symbol: $r('sys.symbol.xmark_circle'),
          symbolColor: SemanticColors.error,
          title: this.viewModel.getMaxTries() + '次用完了',
          detail: '密码: ' + this.viewModel.secret,
          detailColor: SemanticColors.error,
          primaryText: '再来一局',
          onPrimary: () => { this.viewModel.startGame(); },
          cardStyle: true
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
        .onClick(() => {
          if (key === '⌫') { this.viewModel.deleteDigit(); }
          else if (key === '确定') { this.viewModel.submit(); }
          else { this.viewModel.pushDigit(key); }
        })
      }, (key: string) => key)
    }
    .width('100%')
    .margin({ bottom: SpacingTokens.sm })
  }
}
