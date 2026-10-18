import { PageDestination } from '../../components/PageDestination';
import { resolveString } from '../../common/I18nUtils';
import { GameSessionTransfer } from '../../common/GameSessionTransfer';
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
import { ExitConfirmDialog } from '../../components/ExitConfirmDialog';
import { GameLifecycleBus } from '../../common/GameLifecycleBus';
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
  // 无障碍字符串缓存（在 aboutToAppear 中预解析，避免渲染热路径中反复调用 getStringSync）
  @Local a11yRowColFormat: string = '';
  @Local a11yFlagged: string = '';
  @Local a11yHidden: string = '';
  @Local a11yIsMine: string = '';
  @Local a11yAroundFormat: string = '';
  @Local a11yBlank: string = '';

  @Monitor('viewModel.status', 'viewModel.confirmExit')
  playTimeStateChanged(): void { GameLifecycleBus.updatePlayTime(this.viewModel); }

  aboutToAppear(): void {
    const context = this.getUIContext().getHostContext();
    if (context) {
      this.a11yRowColFormat = resolveString($r('app.string.a11y_mine_row_col_format'), context);
      this.a11yFlagged = resolveString($r('app.string.a11y_mine_flagged'), context);
      this.a11yHidden = resolveString($r('app.string.a11y_mine_hidden'), context);
      this.a11yIsMine = resolveString($r('app.string.a11y_mine_is_mine'), context);
      this.a11yAroundFormat = resolveString($r('app.string.a11y_mine_around_format'), context);
      this.a11yBlank = resolveString($r('app.string.a11y_mine_blank'), context);
    }
    this.cellSize = ScreenUtils.calcCell(COLS, 520, 20, 24);
    GameLifecycleBus.attach(this.viewModel);
    if (!GameSessionTransfer.restore(this.viewModel)) { this.viewModel.startGame(); }
    this.playTimeStateChanged();
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
    if (this.viewModel.isFlagged(row, col)) { return $r('app.color.play_selection_background'); }
    if (this.viewModel.isRevealed(row, col)) {
      if (this.viewModel.isMine(row, col)) { return $r('app.color.play_mine_revealed_background'); }
      return $r('app.color.play_cell_background');
    }
    return $r('app.color.play_board_background');
  }

  getResultSymbol(): Resource {
    if (this.viewModel.gameResult) { return $r('sys.symbol.checkmark_circle'); }
    return $r('sys.symbol.xmark_circle');
  }

  getResultColor(): Resource {
    if (this.viewModel.gameResult) { return SemanticColors.success; }
    return SemanticColors.error;
  }

  getResultText(): Resource {
    if (this.viewModel.gameResult) { return $r('app.string.result_minesweeper_win'); }
    return $r('app.string.result_minesweeper_lose');
  }

  /** 无障碍描述：行/列 + 当前状态（未揭开/插旗/数字/地雷） */
  cellA11y(row: number, col: number): string {
    const pos = this.a11yRowColFormat.replace('%1$d', '' + (row + 1)).replace('%2$d', '' + (col + 1));
    if (!this.viewModel.isRevealed(row, col)) {
      return this.viewModel.isFlagged(row, col) ? pos + this.a11yFlagged : pos + this.a11yHidden;
    }
    if (this.viewModel.isMine(row, col)) { return pos + this.a11yIsMine; }
    const v = this.viewModel.cellValue(row, col);
    return v > 0 ? pos + this.a11yAroundFormat.replace('%1$d', '' + v) : pos + this.a11yBlank;
  }

  @Styles
  pressedFeedback() {
    .opacity(0.72)
    .scale({ x: 0.96, y: 0.96 })
  }

  @Builder
  PageHeader() {
    GameHeader({ gameId: 'minesweeper', pathStack: this.pathStack, hasProgress: (): boolean => this.viewModel.hasProgress(),
          gameTitle: $r('app.string.game_minesweeper_name'),
          showScore: false,
          showPause: false,
          subtitle: $r('app.string.game_minesweeper_subtitle'),
          difficulty: this.viewModel.difficulty,
          onDifficultyChange: (d: GameDifficulty) => { this.viewModel.changeDifficulty(d); },
          onBack: () => { this.requestExit(); },
          onPauseToggle: () => {},
          onRestart: () => { this.viewModel.startGame(); }
        })
  }

  @Builder
  PageContent() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[SemanticColors.gradientScreen[0], 0], [SemanticColors.gradientScreen[1], 0.5], [SemanticColors.gradientScreen[2], 1]] })

      Column() {


        Row() {
          Column() {
            Row({ space: SpacingTokens.xs }) {
              SymbolGlyph($r('sys.symbol.flag_fill'))
                .fontSize(12).fontColor([SemanticColors.warning])
              Text($r('app.string.flags_label')).fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textTertiary)
            }
            Text(this.viewModel.flagCount + '/' + this.viewModel.getMineCount()).fontSize(FontTokens.sizeHeadline)
              .fontWeight(FontTokens.weightBold).fontColor(SemanticColors.warning)
          }.layoutWeight(1).padding(8).backgroundColor(SemanticColors.surface)
          .borderRadius(RadiusTokens.lg).alignItems(HorizontalAlign.Center).margin({ left: 16 })

          Column() {
            Row({ space: SpacingTokens.xs }) {
              SymbolGlyph($r('sys.symbol.clock'))
                .fontSize(12).fontColor([SemanticColors.accent])
              Text($r('app.string.time_label')).fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textTertiary)
            }
            Text(this.viewModel.elapsed + 's').fontSize(FontTokens.sizeHeadline)
              .fontWeight(FontTokens.weightBold).fontColor(SemanticColors.accent)
          }.layoutWeight(1).padding(8).backgroundColor(SemanticColors.surface)
          .borderRadius(RadiusTokens.lg).alignItems(HorizontalAlign.Center).margin({ left: 8, right: 16 })
        }.margin({ top: 12, bottom: 12 })

        Column() {
          Column() {
            ForEach(this.idx9, (row: number) => {
              Row() {
                ForEach(this.idx9, (col: number) => {
                  Stack() {
                    if (!this.viewModel.isRevealed(row, col)) {
                      Image($r('app.media.play_2048_surface'))
                        .width(this.cellSize).height(this.cellSize).objectFit(ImageFit.Fill)
                        .draggable(false).hitTestBehavior(HitTestMode.None)
                    }
                    if (this.viewModel.isRevealed(row, col)) {
                      if (this.viewModel.isMine(row, col)) {
                        Image($r('app.media.play_mine'))
                          .width(this.cellSize * 0.72).height(this.cellSize * 0.72).objectFit(ImageFit.Contain)
                          .draggable(false).hitTestBehavior(HitTestMode.None)
                      } else if (this.viewModel.cellValue(row, col) > 0) {
                        Text('' + this.viewModel.cellValue(row, col)).fontSize(Math.max(14, this.cellSize * 0.5)).fontWeight(FontWeight.Bold)
                          .fontColor(this.getNumColor(this.viewModel.cellValue(row, col)))
                          .draggable(false).hitTestBehavior(HitTestMode.None)
                      }
                    } else if (this.viewModel.isFlagged(row, col)) {
                      Image($r('app.media.play_flag'))
                        .width(this.cellSize * 0.72).height(this.cellSize * 0.72).objectFit(ImageFit.Contain)
                        .draggable(false).hitTestBehavior(HitTestMode.None)
                    }
                  }.width(this.cellSize).height(this.cellSize)
                  .backgroundColor(this.getCellBg(row, col))
                  .border({ width: 1, color: $r('app.color.play_piece_border') }).borderRadius(RadiusTokens.xs)
                  .accessibilityText(this.cellA11y(row, col))
                  .stateStyles({ pressed: this.pressedFeedback }).onClick(() => { if (!this.viewModel.isFlagged(row, col)) { this.viewModel.reveal(row, col); } })
                  .gesture(LongPressGesture().onAction(() => this.viewModel.toggleFlag(row, col)))
                }, (col: number) => col.toString())
              }
            }, (row: number) => row.toString())
          }.padding(2)
          .backgroundColor($r('app.color.play_board_background')).borderRadius(RadiusTokens.md)
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
          .onAreaChange((oldValue: Area, newValue: Area) => {
            const width: number = parseFloat(newValue.width as string);
            const height: number = parseFloat(newValue.height as string);
            if (Number.isFinite(width) && Number.isFinite(height) && width > 0 && height > 0) {
              this.cellSize = ScreenUtils.calcCellForArea(width, height, COLS, ROWS, 520, 20, 4);
            }
          })

        Text($r('app.string.game_minesweeper_subtitle'))
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeBodySmall).fontColor(SemanticColors.textTertiary)
          .padding({ bottom: SpacingTokens.lg, top: SpacingTokens.xs })
      }.width('100%').height('100%').padding({ bottom: this.safeBottom })

      if (this.viewModel.status !== GameStatus.PLAYING) {
        GameResultDialog({ shareGameId: 'minesweeper',
          celebrate: this.viewModel.gameResult,
          symbol: this.getResultSymbol(),
          symbolColor: this.getResultColor(),
          title: this.getResultText(),
          detail: $r('app.string.result_detail_time_format', this.viewModel.elapsed),
          detailColor: SemanticColors.accent,
          showDetail: true,
          primaryText: $r('app.string.result_play_again'),
          onPrimary: () => { this.viewModel.startGame(); },
          secondaryText: $r('app.string.action_back'),
          showSecondary: true,
          onSecondary: () => { this.pathStack.pop(); }
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

  build() {
    PageDestination({ gameId: 'minesweeper', header: () => { this.PageHeader(); }, content: () => { this.PageContent(); } })
  }
}
