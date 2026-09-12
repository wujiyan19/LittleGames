/**
 * 俄罗斯方块 —— View 层（纯展示与组装）
 *
 * 只持有 @Local viewModel，读取其 @Trace 状态、转发操作；不 import Model 类型。
 * 规则见 model/game/TetrisModel.ets，状态编排见 viewmodel/TetrisViewModel.ets。
 */
import { SemanticColors, RadiusTokens, FontTokens, ShadowTokens, SpacingTokens } from '../../common/DesignTokens';
import { GameHeader } from '../../components/GameHeader';
import { GameDifficulty, GameStatus } from '../../common/GameConstants';
import { SafeAreaInsets } from '../../common/SafeAreaInsets';
import { GameResultDialog } from '../../components/GameResultDialog';
import { ScreenUtils } from '../../common/ScreenUtils';
import { range } from '../../common/Range';
import { TetrisViewModel } from '../../viewmodel/TetrisViewModel';

const COLS = 10;
const ROWS = 20;

/**
 * 方块配色。UI 常量收编为资源；深色模式在 dark/element/color.json 提供提亮版本。
 * 与 Model 的 SHAPES 索引一一对应（SHAPES[idx] ↔ SHAPE_COLORS[idx]）。
 */
const SHAPE_COLORS: ResourceColor[] = [
  $r('app.color.shape_1'),
  $r('app.color.shape_2'),
  $r('app.color.shape_3'),
  $r('app.color.shape_4'),
  $r('app.color.shape_5'),
  $r('app.color.shape_6'),
  $r('app.color.shape_7')
];

@ComponentV2
export struct TetrisGamePage {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local safeBottom: number = SafeAreaInsets.bottom;
  @Local viewModel: TetrisViewModel = new TetrisViewModel();
  @Local cell: number = 18;
  private rowIdx: number[] = range(ROWS);
  private colIdx: number[] = range(COLS);

  aboutToAppear(): void {
    this.cell = ScreenUtils.calcCell(COLS, 560, 16, 8);
    this.viewModel.startGame();
  }

  aboutToDisappear(): void {
    this.viewModel.dispose();
  }

  onPageHide(): void {
    this.viewModel.onPageHide();
  }

  onPageShow(): void {
    this.viewModel.onPageShow();
  }

  getCellColor(r: number, c: number): ResourceColor {
    const mark = this.viewModel.cellMark(r, c);
    if (mark !== 0) { return SHAPE_COLORS[mark - 1]; }
    return SemanticColors.cellRevealed;
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[SemanticColors.gradientScreen[0], 0], [SemanticColors.gradientScreen[1], 0.5], [SemanticColors.gradientScreen[2], 1]] })

      Column() {
        GameHeader({ gameTitle: '俄罗斯方块', // 得分/最高分已由下方大字指标卡展示，关闭标题栏的小字重复显示
          showScore: false,
          isPaused: this.viewModel.status === GameStatus.PAUSED,
          difficulty: this.viewModel.difficulty,
          onDifficultyChange: (d: GameDifficulty) => { this.viewModel.changeDifficulty(d); },
          onBack: () => { this.pathStack.pop(); },
          onPauseToggle: () => { this.viewModel.togglePause(); },
          onRestart: () => { this.viewModel.startGame(); } })

        Row() {
          Column() {
            Text('级别').fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textTertiary)
            Text('' + this.viewModel.level).fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold).fontColor(SemanticColors.warning)
          }.layoutWeight(1).padding(8).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base)
          .alignItems(HorizontalAlign.Center).margin({ left: 16 })

          Column() {
            Text('得分').fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textTertiary)
            Text('' + this.viewModel.score).fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold).fontColor(SemanticColors.accent)
          }.layoutWeight(1).padding(8).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base)
          .alignItems(HorizontalAlign.Center).margin({ left: 8, right: 16 })
        }.margin({ top: 12, bottom: 12 })

        Row() {
          Column() {
            ForEach(this.rowIdx, (row: number) => {
              Row() {
                ForEach(this.colIdx, (col: number) => {
                  Column() {}.width(this.cell).height(this.cell)
                    .backgroundColor(this.getCellColor(row, col))
                    .border({ width: 0.5, color: SemanticColors.divider })
                }, (col: number) => col.toString())
              }
            }, (row: number) => row.toString())
          }.width(this.cell * COLS).height(this.cell * ROWS)
          .border({ width: 2, color: SemanticColors.boardBorder, radius: RadiusTokens.sm })
          .backgroundColor(SemanticColors.boardBg)
        }.layoutWeight(1).justifyContent(FlexAlign.Center)

        Column({ space: SpacingTokens.sm }) {
          Row({ space: SpacingTokens.sm }) {
            Button() {
              SymbolGlyph($r('sys.symbol.arrow_left'))
                .fontSize(18).fontColor([SemanticColors.textPrimary])
            }
            .layoutWeight(1).height(48).backgroundColor(SemanticColors.surface)
            .borderRadius(RadiusTokens.base).shadow(ShadowTokens.button).onClick(() => this.viewModel.moveLeft())
            Button() {
              SymbolGlyph($r('sys.symbol.arrow_clockwise'))
                .fontSize(18).fontColor([SemanticColors.textPrimary])
            }
            .layoutWeight(1).height(48).backgroundColor(SemanticColors.surface)
            .borderRadius(RadiusTokens.base).shadow(ShadowTokens.button).onClick(() => this.viewModel.rotateBlock())
            Button() {
              SymbolGlyph($r('sys.symbol.arrow_right'))
                .fontSize(18).fontColor([SemanticColors.textPrimary])
            }
            .layoutWeight(1).height(48).backgroundColor(SemanticColors.surface)
            .borderRadius(RadiusTokens.base).shadow(ShadowTokens.button).onClick(() => this.viewModel.moveRight())
          }
          .width('100%').padding({ left: SpacingTokens.base, right: SpacingTokens.base })
          Button() {
            Row({ space: SpacingTokens.xs }) {
              SymbolGlyph($r('sys.symbol.arrow_down'))
                .fontSize(16).fontColor([SemanticColors.textOnPrimary])
              Text('加速下落')
                .fontFamily(FontTokens.family)
                .fontSize(FontTokens.sizeBody).fontColor(SemanticColors.textOnPrimary)
            }
          }
          .width('80%').height(48).backgroundColor(SemanticColors.primary)
          .borderRadius(RadiusTokens.full).shadow(ShadowTokens.button).onClick(() => this.viewModel.hardDrop())
        }.padding({ bottom: SpacingTokens.lg })
      }.width('100%').height('100%').padding({ bottom: this.safeBottom })

      if (this.viewModel.status === GameStatus.OVER) {
        GameResultDialog({
          symbol: $r('sys.symbol.star_fill'),
          symbolColor: SemanticColors.warning,
          title: '游戏结束',
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
}
