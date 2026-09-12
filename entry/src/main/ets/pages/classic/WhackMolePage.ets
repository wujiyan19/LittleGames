/**
 * 打地鼠 —— View 层（纯展示与组装）
 *
 * 只持有 @Local viewModel，读取其 @Trace 状态、转发操作；不 import Model 类型。
 * 规则见 model/game/WhackMoleModel.ets，状态编排见 viewmodel/WhackMoleViewModel.ets。
 */
import { SemanticColors, RadiusTokens, FontTokens, SpacingTokens } from '../../common/DesignTokens';
import { GameHeader } from '../../components/GameHeader';
import { GameDifficulty, GameStatus } from '../../common/GameConstants';
import { SafeAreaInsets } from '../../common/SafeAreaInsets';
import { GameResultDialog } from '../../components/GameResultDialog';
import { range } from '../../common/Range';
import { WhackMoleViewModel } from '../../viewmodel/WhackMoleViewModel';

@ComponentV2
export struct WhackMolePage {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local safeBottom: number = SafeAreaInsets.bottom;
  @Local viewModel: WhackMoleViewModel = new WhackMoleViewModel();
  private idx3: number[] = range(3);

  aboutToAppear(): void { this.viewModel.startGame(); }
  aboutToDisappear(): void { this.viewModel.dispose(); }

  onPageHide(): void { this.viewModel.onPageHide(); }
  onPageShow(): void { this.viewModel.onPageShow(); }

  getTimeColor(): ResourceColor {
    if (this.viewModel.timeLeft <= 5) { return SemanticColors.error; }
    return SemanticColors.success;
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[SemanticColors.gradientScreen[0], 0], [SemanticColors.gradientScreen[1], 0.5], [SemanticColors.gradientScreen[2], 1]] })

      Column() {
        GameHeader({ gameTitle: '打地鼠', // 得分/最高分已由下方大字指标卡展示，关闭标题栏的小字重复显示
          showScore: false,
          isPaused: this.viewModel.status === GameStatus.PAUSED,
          difficulty: this.viewModel.difficulty,
          onDifficultyChange: (d: GameDifficulty) => { this.viewModel.changeDifficulty(d); },
          onBack: () => { this.pathStack.pop(); },
          onPauseToggle: () => { this.viewModel.togglePause(); },
          onRestart: () => { this.viewModel.startGame(); } })

        Row() {
          Column() {
            Text('得分').fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textTertiary)
            Text('' + this.viewModel.score).fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold).fontColor(SemanticColors.accent)
          }.layoutWeight(1).padding(8).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base)
          .alignItems(HorizontalAlign.Center).margin({ left: 16 })

          Column() {
            Text('时间').fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textTertiary)
            Text(this.viewModel.timeLeft + 's').fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold)
              .fontColor(this.getTimeColor())
          }.layoutWeight(1).padding(8).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base)
          .alignItems(HorizontalAlign.Center).margin({ left: 8, right: 16 })
        }.margin({ top: 12, bottom: 12 })

        Column() {
          ForEach(this.idx3, (row: number) => {
            Row() {
              ForEach(this.idx3, (col: number) => {
                this.MoleHole(row * 3 + col)
              }, (col: number) => col.toString())
            }
          }, (row: number) => row.toString())
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      }.width('100%').height('100%').padding({ bottom: this.safeBottom })

      if (this.viewModel.status === GameStatus.OVER) {
        GameResultDialog({
          symbol: $r('sys.symbol.star_fill'),
          symbolColor: SemanticColors.warning,
          title: '时间到！',
          detail: '得分 ' + this.viewModel.score,
          detailColor: SemanticColors.accent,
          primaryText: '再来一局',
          onPrimary: () => { this.viewModel.startGame(); },
          secondaryText: '返回',
          onSecondary: () => { this.pathStack.pop(); }
        })
      }
    }.width('100%').height('100%')
  }

  @Builder
  MoleHole(index: number) {
    Column() {
      if (this.viewModel.holes[index]) {
        Text('🐹')
          .fontSize(44)
          .translate({ y: -8 })
      } else {
        Column() {}
          .width('72%').aspectRatio(1.4)
          .borderRadius(RadiusTokens.full)
          .backgroundColor(SemanticColors.surface)
          // 阴影恒为半透明黑：投影在深浅两种底色上都应压暗，不随主题反转
          .shadow({ radius: 10, color: 'rgba(0,0,0,0.25)', offsetY: 4 })
          .margin({ bottom: 8 })
      }
    }
    .layoutWeight(1).aspectRatio(0.92)
    .justifyContent(FlexAlign.End)
    .onClick(() => this.viewModel.whack(index))
  }
}
