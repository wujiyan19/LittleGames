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
import { ExitConfirmDialog } from '../../components/ExitConfirmDialog';
import { GameLifecycleBus } from '../../common/GameLifecycleBus';
import { ScreenUtils } from '../../common/ScreenUtils';
import { KlotskiPieceView, KlotskiViewModel } from '../../viewmodel/KlotskiViewModel';

const BW = 4;
const BH = 5;

@ComponentV2
export struct KlotskiPage {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local safeBottom: number = SafeAreaInsets.bottom;
  @Local viewModel: KlotskiViewModel = new KlotskiViewModel();
  @Local cell: number = 65;
  @Local centerLabel: string = '';
  // 无障碍字符串缓存
  @Local a11yBlockFormat: string = '';

  aboutToAppear(): void {
    this.cell = ScreenUtils.calcCell(BW, 560, 28, 48);
    const context = this.getUIContext().getHostContext();
    if (context) {
      this.a11yBlockFormat = context.resourceManager.getStringSync($r('app.string.a11y_klotski_block_format'));
    }
    GameLifecycleBus.attach(this.viewModel);
    this.viewModel.startGame();
    const ctx = this.getUIContext().getHostContext();
    if (ctx) {
      this.centerLabel = ctx.resourceManager.getStringSync($r('app.string.klotski_move'));
    }
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

  private step(): number { return this.cell + 4; }

  getPieceImage(kind: number): Resource {
    if (kind === 1) { return $r('app.media.play_klotski_target'); }
    if (kind === 2) { return $r('app.media.play_klotski_horizontal'); }
    if (kind === 3) { return $r('app.media.play_klotski_vertical'); }
    return $r('app.media.play_klotski_soldier');
  }

  @Styles
  pressedFeedback() {
    .opacity(0.72)
    .scale({ x: 0.96, y: 0.96 })
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
          onBack: () => { this.requestExit(); },
          onPauseToggle: () => {},
          onRestart: () => { this.viewModel.startGame(); }
        })

        Column() {
          Stack({ alignContent: Alignment.TopStart }) {
            Image($r('app.media.play_klotski_board'))
              .width(this.step() * BW + 8).height(this.step() * BH + 8)
              .objectFit(ImageFit.Fill)

            ForEach(this.viewModel.piecesForView(), (piece: KlotskiPieceView) => {
              Stack() {
                Image(this.getPieceImage(piece.kind))
                  .width(piece.w * this.step() - 4)
                  .height(piece.h * this.step() - 4)
                  .objectFit(ImageFit.Fill)
                Text(piece.label)
                  .fontSize(Math.max(18, this.cell * 0.3))
                  .fontWeight(FontWeight.Bold)
                  .fontColor(piece.kind === 4 ? $r('app.color.klotski_wood_text') : $r('app.color.tile_text_high'))
              }
              .width(piece.w * this.step() - 4).height(piece.h * this.step() - 4)
              .border({ width: piece.selected ? 3 : 0, color: SemanticColors.warning })
              .borderRadius(RadiusTokens.base)
              .offset({ x: 6 + piece.x * this.step(), y: 6 + piece.y * this.step() })
              .accessibilityText(this.a11yBlockFormat.replace('%1$s', piece.label))
              .stateStyles({ pressed: this.pressedFeedback })
              .onClick(() => this.viewModel.selectBlockAt(piece.y, piece.x))
            }, (piece: KlotskiPieceView) => piece.id)
          }
          .width(this.step() * BW + 8).height(this.step() * BH + 8)
          Text($r('app.string.klotski_exit'))
            .fontSize(FontTokens.sizeCaption)
            .fontColor(SemanticColors.textSecondary)
            .margin({ top: SpacingTokens.sm })
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
      .onAreaChange((oldValue: Area, newValue: Area) => {
        const width: number = parseFloat(newValue.width as string);
        if (!isNaN(width) && width > 0) { this.cell = ScreenUtils.calcCellForWidth(width, BW, 560, 28); }
      })
  }
}
