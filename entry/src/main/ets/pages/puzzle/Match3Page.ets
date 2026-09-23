/**
 * 消消乐（Match3）—— View 层（展示与交互）
 *
 * 只持有 @Local viewModel，读取其 @Trace 状态、转发操作；不 import Model 类型。
 * 规则见 model/game/Match3Model.ets，状态编排见 viewmodel/Match3ViewModel.ets。
 */
import { SemanticColors, RadiusTokens, FontTokens, ShadowTokens, SpacingTokens } from '../../common/DesignTokens';
import { GameHeader } from '../../components/GameHeader';
import { GameStatus } from '../../common/GameConstants';
import { SafeAreaInsets } from '../../common/SafeAreaInsets';
import { GameResultDialog } from '../../components/GameResultDialog';
import { ExitConfirmDialog } from '../../components/ExitConfirmDialog';
import { ScreenUtils } from '../../common/ScreenUtils';
import { range } from '../../common/Range';
import { GameLifecycleBus } from '../../common/GameLifecycleBus';
import { Match3ViewModel } from '../../viewmodel/Match3ViewModel';

const ROWS = 8;
const COLS = 8;
const GAP = 3;

@ComponentV2
export struct Match3Page {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local safeBottom: number = SafeAreaInsets.bottom;
  @Local viewModel: Match3ViewModel = new Match3ViewModel();
  @Local cell: number = 36;
  @Local boardSize: number = 320;
  private rowIdx: number[] = range(ROWS);
  private colIdx: number[] = range(COLS);
  @Local a11yGemFormat: string = '';

  aboutToAppear(): void {
    this.initBoardSize();
    const context = this.getUIContext().getHostContext();
    if (context) {
      this.a11yGemFormat = context.resourceManager.getStringSync($r('app.string.a11y_match3_gem_format'));
    }
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

  initBoardSize(): void {
    this.cell = ScreenUtils.calcCell(COLS, 360, 24, 28);
    this.boardSize = this.cell * COLS + (COLS - 1) * GAP + 8;
  }

  private step(): number { return this.cell + GAP; }
  private innerSize(): number { return this.cell * COLS + (COLS - 1) * GAP; }

  /** 宝石背景色：6 种宝石对应 shape_1 ~ shape_6 */
  getGemBg(type: number): ResourceColor {
    switch (type) {
      case 0: return $r('app.color.shape_1');
      case 1: return $r('app.color.shape_2');
      case 2: return $r('app.color.shape_3');
      case 3: return $r('app.color.shape_4');
      case 4: return $r('app.color.shape_5');
      case 5: return $r('app.color.shape_6');
      default: return SemanticColors.cellHidden;
    }
  }

  /** 宝石内 SymbolGlyph：6 种不同形状辅助区分 */
  getGemSymbol(type: number): Resource {
    switch (type) {
      case 0: return $r('sys.symbol.circle_fill');
      case 1: return $r('sys.symbol.square_fill');
      case 2: return $r('sys.symbol.star_fill');
      case 3: return $r('sys.symbol.heart_fill');
      case 4: return $r('sys.symbol.circle_fill');
      case 5: return $r('sys.symbol.square_fill');
      default: return $r('sys.symbol.circle_fill');
    }
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[SemanticColors.gradientScreen[0], 0], [SemanticColors.gradientScreen[1], 0.5], [SemanticColors.gradientScreen[2], 1]] })

      Column() {
        GameHeader({
          gameTitle: $r('app.string.game_match3_name'),
          showScore: false,
          showPause: false,
          onBack: () => { this.requestExit(); },
          onPauseToggle: () => {},
          onRestart: () => { this.viewModel.startGame(); }
        })

        // 指标区：得分 / 最高分 / 剩余步数
        Row() {
          Column() {
            Text($r('app.string.score_label')).fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textTertiary)
            Text('' + this.viewModel.score).fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold).fontColor(SemanticColors.accent)
          }.layoutWeight(1).padding(8).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base)
          .alignItems(HorizontalAlign.Center).margin({ left: 16 })

          Column() {
            Text($r('app.string.high_score_label')).fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textTertiary)
            Text('' + this.viewModel.highScore).fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold).fontColor(SemanticColors.textPrimary)
          }.layoutWeight(1).padding(8).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base)
          .alignItems(HorizontalAlign.Center).margin({ left: 4, right: 4 })

          Column() {
            Text($r('app.string.game_match3_moves_label')).fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textTertiary)
            Text('' + this.viewModel.movesLeft).fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold).fontColor(SemanticColors.warning)
          }.layoutWeight(1).padding(8).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base)
          .alignItems(HorizontalAlign.Center).margin({ right: 16 })
        }.margin({ top: 12, bottom: 12 })

        // 棋盘
        Column() {
          ForEach(this.rowIdx, (r: number) => {
            Row() {
              ForEach(this.colIdx, (c: number) => {
                Stack() {
                  // 宝石底色
                  Column()
                    .width(this.cell).height(this.cell)
                    .borderRadius(RadiusTokens.md)
                    .backgroundColor(this.getGemBg(this.viewModel.gemType(r, c)))

                  // 宝石内形状标识
                  SymbolGlyph(this.getGemSymbol(this.viewModel.gemType(r, c)))
                    .fontSize(Math.max(10, this.cell * 0.35))
                    .fontColor([SemanticColors.textOnPrimary])

                  // 选中高亮：边框 + 缩放
                  if (this.viewModel.isSelected(r, c)) {
                    Column()
                      .width(this.cell).height(this.cell)
                      .borderRadius(RadiusTokens.md)
                      .border({ width: 3, color: SemanticColors.textOnPrimary, radius: RadiusTokens.md })
                      .scale({ x: 1.1, y: 1.1 })
                      .animation({ duration: 150, curve: Curve.EaseOut, playMode: PlayMode.Normal })
                  }
                }
                .width(this.cell).height(this.cell)
                .margin({ left: c > 0 ? GAP : 0, top: r > 0 ? GAP : 0 })
                .accessibilityText(
                  this.a11yGemFormat
                    .replace('%1$d', '' + (r + 1))
                    .replace('%2$d', '' + (c + 1))
                    .replace('%3$d', '' + (this.viewModel.gemType(r, c) + 1))
                )
                .onClick(() => { this.viewModel.onGemClick(r, c); })
              }, (c: number) => c.toString())
            }
          }, (r: number) => r.toString())
        }
        .width(this.innerSize())
        .padding(4)
        .backgroundColor(SemanticColors.boardBg)
        .border({ width: 2, color: SemanticColors.boardBorder, radius: RadiusTokens.base })
        .layoutWeight(1).justifyContent(FlexAlign.Center)

        Text($r('app.string.game_match3_hint'))
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeBodySmall).fontColor(SemanticColors.textTertiary)
          .padding({ bottom: SpacingTokens.lg })
      }.width('100%').height('100%').padding({ bottom: this.safeBottom })

      // 步数用尽结算弹窗
      if (this.viewModel.status === GameStatus.OVER) {
        GameResultDialog({
          symbol: $r('sys.symbol.star_fill'),
          symbolColor: SemanticColors.warning,
          title: $r('app.string.result_game_over'),
          detail: $r('app.string.result_detail_score_format', this.viewModel.score),
          detailColor: SemanticColors.accent,
          showDetail: true,
          primaryText: $r('app.string.result_play_again'),
          onPrimary: () => { this.viewModel.startGame(); },
          secondaryText: $r('app.string.action_back'),
          showSecondary: true,
          onSecondary: () => { this.pathStack.pop(); }
        })
      }

      // 对局中返回确认弹窗
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
}