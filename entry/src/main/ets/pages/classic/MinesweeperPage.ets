/**
 * 扫雷 —— View 层（纯展示与组装）
 *
 * 只持有 @Local viewModel，读取其 @Trace 状态、转发操作；不 import Model 类型。
 * 规则见 model/game/MinesweeperModel.ets，状态编排见 viewmodel/MinesweeperViewModel.ets。
 */
import { SemanticColors, RadiusTokens, FontTokens, SpacingTokens } from '../../common/DesignTokens';
import { GameHeader } from '../../components/GameHeader';
import { GameDifficulty, GameStatus } from '../../common/GameConstants';
import { SafeAreaInsets } from '../../common/SafeAreaInsets';
import { GameResultDialog } from '../../components/GameResultDialog';
import { ScreenUtils } from '../../common/ScreenUtils';
import { range } from '../../common/Range';
import { MinesweeperViewModel } from '../../viewmodel/MinesweeperViewModel';

const ROWS = 9;
const COLS = 9;

@ComponentV2
export struct MinesweeperPage {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local safeBottom: number = SafeAreaInsets.bottom;
  @Local viewModel: MinesweeperViewModel = new MinesweeperViewModel();
  @Local cellSize: number = 32;
  private idx9: number[] = range(COLS);

  aboutToAppear(): void {
    this.cellSize = ScreenUtils.calcCell(COLS, 520, 20, 24);
    this.viewModel.startGame();
  }

  aboutToDisappear(): void {
    this.viewModel.dispose();
  }

  onPageHide(): void { this.viewModel.onPageHide(); }
  onPageShow(): void { this.viewModel.onPageShow(); }

  /**
   * 雷数提示色。数字 7 用纯白会在亮色底上不可见，已收编为资源，两套主题各有可读配色；
   * 越界值用 error 色，避免深色底「黑字配深底」。
   */
  getNumColor(v: number): ResourceColor {
    if (v < 0 || v > 8) { return $r('app.color.mine_num_invalid'); }
    const colors: ResourceColor[] = [
      $r('app.color.mine_num_0'),
      $r('app.color.mine_num_1'),
      $r('app.color.mine_num_2'),
      $r('app.color.mine_num_3'),
      $r('app.color.mine_num_4'),
      $r('app.color.mine_num_5'),
      $r('app.color.mine_num_6'),
      $r('app.color.mine_num_7'),
      $r('app.color.mine_num_8')
    ];
    return colors[v];
  }

  getCellBg(row: number, col: number): ResourceColor {
    if (this.viewModel.isFlagged(row, col)) { return SemanticColors.accentLight; }
    if (this.viewModel.isRevealed(row, col)) {
      if (this.viewModel.isMine(row, col)) { return SemanticColors.error; }
      return SemanticColors.cellRevealed;
    }
    return SemanticColors.cellHidden;
  }

  getResultSymbol(): Resource {
    if (this.viewModel.gameResult) { return $r('sys.symbol.checkmark_circle'); }
    return $r('sys.symbol.xmark_circle');
  }

  getResultColor(): Resource {
    if (this.viewModel.gameResult) { return SemanticColors.success; }
    return SemanticColors.error;
  }

  getResultText(): string {
    if (this.viewModel.gameResult) { return '扫雷成功!'; }
    return '踩到雷了';
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[SemanticColors.gradientScreen[0], 0], [SemanticColors.gradientScreen[1], 0.5], [SemanticColors.gradientScreen[2], 1]] })

      Column() {
        GameHeader({
          gameTitle: '扫雷',
          showScore: false,
          showPause: false,
          subtitle: '长按插旗 · 点击揭开',
          difficulty: this.viewModel.difficulty,
          onDifficultyChange: (d: GameDifficulty) => { this.viewModel.changeDifficulty(d); },
          onBack: () => { this.pathStack.pop(); },
          onPauseToggle: () => {},
          onRestart: () => { this.viewModel.startGame(); }
        })

        Row() {
          Column() {
            Row({ space: SpacingTokens.xs }) {
              SymbolGlyph($r('sys.symbol.flag_fill'))
                .fontSize(12).fontColor([SemanticColors.warning])
              Text('旗帜').fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textTertiary)
            }
            Text(this.viewModel.flagCount + '/' + this.viewModel.getMineCount()).fontSize(FontTokens.sizeHeadline)
              .fontWeight(FontTokens.weightBold).fontColor(SemanticColors.warning)
          }.layoutWeight(1).padding(8).backgroundColor(SemanticColors.surface)
          .borderRadius(RadiusTokens.base).alignItems(HorizontalAlign.Center).margin({ left: 16 })

          Column() {
            Row({ space: SpacingTokens.xs }) {
              SymbolGlyph($r('sys.symbol.clock'))
                .fontSize(12).fontColor([SemanticColors.accent])
              Text('时间').fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textTertiary)
            }
            Text(this.viewModel.elapsed + 's').fontSize(FontTokens.sizeHeadline)
              .fontWeight(FontTokens.weightBold).fontColor(SemanticColors.accent)
          }.layoutWeight(1).padding(8).backgroundColor(SemanticColors.surface)
          .borderRadius(RadiusTokens.base).alignItems(HorizontalAlign.Center).margin({ left: 8, right: 16 })
        }.margin({ top: 12, bottom: 12 })

        Column() {
          Column() {
            ForEach(this.idx9, (row: number) => {
              Row() {
                ForEach(this.idx9, (col: number) => {
                  Column() {
                    if (this.viewModel.isRevealed(row, col)) {
                      if (this.viewModel.isMine(row, col)) {
                        Text('💣').fontSize(Math.max(14, this.cellSize * 0.5))
                      } else if (this.viewModel.cellValue(row, col) > 0) {
                        Text('' + this.viewModel.cellValue(row, col)).fontSize(Math.max(14, this.cellSize * 0.5)).fontWeight(FontWeight.Bold)
                          .fontColor(this.getNumColor(this.viewModel.cellValue(row, col)))
                      }
                    } else if (this.viewModel.isFlagged(row, col)) {
                      Text('🚩').fontSize(Math.max(14, this.cellSize * 0.5))
                    }
                  }.width(this.cellSize).height(this.cellSize)
                  .backgroundColor(this.getCellBg(row, col))
                  .border({ width: 1, color: SemanticColors.boardBorder }).borderRadius(RadiusTokens.xs)
                  .onClick(() => { if (!this.viewModel.isFlagged(row, col)) { this.viewModel.reveal(row, col); } })
                  .gesture(LongPressGesture().onAction(() => this.viewModel.toggleFlag(row, col)))
                }, (col: number) => col.toString())
              }
            }, (row: number) => row.toString())
          }.padding(2)
          .backgroundColor(SemanticColors.boardBg).border({ width: 2, color: SemanticColors.boardBorder, radius: RadiusTokens.md })
        }.layoutWeight(1).justifyContent(FlexAlign.Center)

        Text('长按插旗 · 点击揭开')
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeBodySmall).fontColor(SemanticColors.textTertiary)
          .padding({ bottom: SpacingTokens.lg, top: SpacingTokens.xs })
      }.width('100%').height('100%').padding({ bottom: this.safeBottom })

      if (this.viewModel.status !== GameStatus.PLAYING) {
        GameResultDialog({
          symbol: this.getResultSymbol(),
          symbolColor: this.getResultColor(),
          title: this.getResultText(),
          detail: this.viewModel.elapsed + ' 秒完成',
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
