/**
 * 华容道 —— View 层（纯展示与组装）
 *
 * 只持有 @Local viewModel，读取其 @Trace 状态、转发操作；不 import Model 类型。
 * 规则见 model/game/KlotskiModel.ets，状态编排见 viewmodel/KlotskiViewModel.ets。
 */
import { SemanticColors, RadiusTokens, FontTokens, SpacingTokens } from '../../common/DesignTokens';
import { ControlPad } from '../../components/ControlPad';
import { GameHeader } from '../../components/GameHeader';
import { GameDifficulty, GameStatus } from '../../common/GameConstants';
import { SafeAreaInsets } from '../../common/SafeAreaInsets';
import { GameResultDialog } from '../../components/GameResultDialog';
import { ScreenUtils } from '../../common/ScreenUtils';
import { range } from '../../common/Range';
import { KlotskiViewModel } from '../../viewmodel/KlotskiViewModel';

const BW = 4;
const BH = 5;

@ComponentV2
export struct KlotskiPage {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local safeBottom: number = SafeAreaInsets.bottom;
  @Local viewModel: KlotskiViewModel = new KlotskiViewModel();
  @Local cell: number = 65;
  @Local centerLabel: string = '';
  private rowArray: number[] = range(BH);
  private colArray: number[] = range(BW);

  aboutToAppear(): void {
    this.cell = ScreenUtils.calcCell(BW, 560, 28, 48);
    this.viewModel.startGame();
    this.centerLabel = getStringSync($r('app.string.klotski_move'));
  }

  /** 棋子配色（种类由 ViewModel 给出，颜色资源在 View）；文字恒为白 */
  getCellBg(row: number, col: number): ResourceColor {
    const kind = this.viewModel.blockKind(row, col);
    if (kind === 0) { return SemanticColors.boardBg; }
    if (kind === 1) { return $r('app.color.klotski_target'); }
    if (kind === 2) { return $r('app.color.klotski_horizontal'); }
    if (kind === 3) { return $r('app.color.klotski_vertical'); }
    return $r('app.color.klotski_normal');
  }

  getBorderWidth(row: number, col: number): number {
    if (this.viewModel.isSelected(row, col)) { return 2; }
    return 0;
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[SemanticColors.gradientScreen[0], 0], [SemanticColors.gradientScreen[1], 0.5], [SemanticColors.gradientScreen[2], 1]] })

      Column() {
        GameHeader({
          gameTitle: $r('app.string.game_klotski_name'),
          showScore: false,
          showPause: false,
          subtitle: $r('app.string.game_klotski_subtitle_format', this.viewModel.stepCount),
          difficulty: this.viewModel.difficulty,
          onDifficultyChange: (d: GameDifficulty) => { this.viewModel.changeDifficulty(d); },
          onBack: () => { this.pathStack.pop(); },
          onPauseToggle: () => {},
          onRestart: () => { this.viewModel.startGame(); }
        })

        Column() {
          Column() {
            ForEach(this.rowArray, (row: number) => {
              Row() {
                ForEach(this.colArray, (col: number) => {
                  Column() {
                    if (this.viewModel.blockKind(row, col) > 0) {
                      Text(this.viewModel.blockLabel(row, col))
                        .fontSize(Math.max(16, this.cell * 0.28)).fontWeight(FontWeight.Bold)
                        // 棋子底色为彩色，白字在两套主题下均可读
                        .fontColor('#FFFFFF')
                    } else if (row === 4 && col === 1) {
                      Text($r('app.string.klotski_exit')).fontSize(Math.max(10, this.cell * 0.16)).fontColor(SemanticColors.textTertiary)
                    }
                  }.width(this.cell).height(this.cell).margin(2)
                  .backgroundColor(this.getCellBg(row, col))
                  .borderRadius(RadiusTokens.base)
                  .border({
                    width: this.getBorderWidth(row, col),
                    color: SemanticColors.borderStrong
                  })
                  .onClick(() => this.viewModel.selectBlockAt(row, col))
                }, (col: number) => col.toString())
              }
            }, (row: number) => row.toString())
          }.width(this.cell * BW + 30).height(this.cell * BH + 34)
          .backgroundColor(SemanticColors.boardBg)
          .border({ width: 3, color: SemanticColors.boardBorder, radius: RadiusTokens.base }).padding(4)
        }.layoutWeight(1).justifyContent(FlexAlign.Center)

        ControlPad({
          onUp: () => this.viewModel.moveBlock(0, -1),
          onDown: () => this.viewModel.moveBlock(0, 1),
          onLeft: () => this.viewModel.moveBlock(-1, 0),
          onRight: () => this.viewModel.moveBlock(1, 0),
          onCenter: () => {},
          centerLabel: this.centerLabel
        })
      }.width('100%').height('100%').padding({ bottom: this.safeBottom })

      if (this.viewModel.status === GameStatus.OVER) {
        GameResultDialog({
          symbol: $r('sys.symbol.checkmark_circle'),
          symbolColor: SemanticColors.success,
          title: $r('app.string.result_klotski_success'),
          detail: $r('app.string.result_detail_steps_complete_format', this.viewModel.stepCount),
          detailColor: SemanticColors.warning,
          showDetail: true,
          primaryText: $r('app.string.result_play_again'),
          onPrimary: () => { this.viewModel.startGame(); }
        })
      }
    }.width('100%').height('100%')
  }
}
