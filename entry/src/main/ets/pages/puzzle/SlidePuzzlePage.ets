/**
 * 滑动拼图 —— View 层（纯展示与组装）
 *
 * 只持有 @Local viewModel，读取其 @Trace 状态、转发操作；不 import Model 类型。
 * 规则见 model/game/SlidePuzzleModel.ets，状态编排见 viewmodel/SlidePuzzleViewModel.ets。
 */
import { SemanticColors, RadiusTokens, FontTokens, ShadowTokens, SpacingTokens } from '../../common/DesignTokens';
import { GameHeader } from '../../components/GameHeader';
import { GameDifficulty, GameStatus } from '../../common/GameConstants';
import { SafeAreaInsets } from '../../common/SafeAreaInsets';
import { GameResultDialog } from '../../components/GameResultDialog';
import { ExitConfirmDialog } from '../../components/ExitConfirmDialog';
import { GameLifecycleBus } from '../../common/GameLifecycleBus';
import { ScreenUtils } from '../../common/ScreenUtils';
import { range } from '../../common/Range';
import { SlidePuzzleViewModel } from '../../viewmodel/SlidePuzzleViewModel';

@ComponentV2
export struct SlidePuzzlePage {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local safeBottom: number = SafeAreaInsets.bottom;
  @Local viewModel: SlidePuzzleViewModel = new SlidePuzzleViewModel();
  @Local cell: number = 85;
  @Local idxN: number[] = range(3);
  // 无障碍字符串缓存
  @Local a11yTileFormat: string = '';

  aboutToAppear(): void {
    const context = this.getUIContext().getHostContext();
    if (context) {
      this.a11yTileFormat = context.resourceManager.getStringSync($r('app.string.a11y_slide_tile_format'));
    }
    this.refreshLayout();
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

  /** 尺寸随难度变化，重算格子大小与索引表 */
  refreshLayout(): void {
    const n = this.viewModel.getSize();
    this.idxN = range(n);
    this.cell = ScreenUtils.calcCell(n, 520, 40, 40);
  }

  changeDifficulty(d: GameDifficulty): void {
    this.viewModel.changeDifficulty(d);
    this.refreshLayout();
  }

  getCellBg(r: number, c: number): ResourceColor {
    const v = this.viewModel.cellAt(r, c);
    if (v === 0) { return SemanticColors.boardBg; }
    if (v === r * this.viewModel.getSize() + c + 1) { return SemanticColors.success; }
    return SemanticColors.accent;
  }

  getCellOpacity(r: number, c: number): number {
    if (this.viewModel.cellAt(r, c) === 0) { return 0; }
    return 1;
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
        GameHeader({ gameTitle: $r('app.string.game_slidepuzzle_name'),
          showScore: false,
          showPause: false,
          subtitle: $r('app.string.game_slidepuzzle_subtitle'),
          difficulty: this.viewModel.difficulty,
          onDifficultyChange: (d: GameDifficulty) => { this.changeDifficulty(d); },
          onBack: () => { this.requestExit(); },
          onPauseToggle: () => {},
          onRestart: () => { this.viewModel.startGame(); } })

        Row() {
          Column() {
            Text($r('app.string.steps_label')).fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textTertiary)
            Text('' + this.viewModel.steps).fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold).fontColor(SemanticColors.accent)
          }.layoutWeight(1).padding(8).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base)
          .alignItems(HorizontalAlign.Center).margin({ left: 16 })
          Column() {
            Text($r('app.string.best_label')).fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textTertiary)
            Text(this.viewModel.getBestText()).fontSize(FontTokens.sizeHeadline)
              .fontWeight(FontTokens.weightBold).fontColor(SemanticColors.textPrimary)
          }.layoutWeight(1).padding(8).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base)
          .alignItems(HorizontalAlign.Center).margin({ left: 8, right: 16 })
        }.margin({ top: 12, bottom: 12 })

        Column() {
          Column() {
            ForEach(this.idxN, (r: number) => {
              Row() {
                ForEach(this.idxN, (c: number) => {
                  Column() {
                    if (this.viewModel.cellAt(r, c) > 0) {
                      Text('' + this.viewModel.cellAt(r, c)).fontSize(Math.max(22, this.cell * 0.34))
                        .fontWeight(FontWeight.Bold)
                        // 拼图块底色为 accent / success，白字在两套主题下均可读
                        .fontColor($r('app.color.tile_text_high'))
                    }
                  }.width(this.cell).height(this.cell).margin(2)
                  .backgroundColor(this.getCellBg(r, c))
                  .borderRadius(RadiusTokens.base)

                  .opacity(this.getCellOpacity(r, c))
                  .accessibilityText(
                    this.viewModel.cellAt(r, c) > 0
                      ? this.a11yTileFormat.replace('%1$d', '' + this.viewModel.cellAt(r, c))
                      : ''
                  )
                  .stateStyles({ pressed: this.pressedFeedback }).onClick(() => this.viewModel.tapCell(r, c))
                }, (c: number) => c.toString())
              }
            }, (r: number) => r.toString())
          }.backgroundColor(SemanticColors.boardBg).borderRadius(RadiusTokens.base).padding(4)
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      }.width('100%').height('100%').padding({ bottom: this.safeBottom })

      if (this.viewModel.status === GameStatus.OVER) {
        GameResultDialog({
          symbol: $r('sys.symbol.checkmark_circle'),
          symbolColor: SemanticColors.success,
          title: $r('app.string.result_puzzle_complete'),
          detail: $r('app.string.result_detail_steps_format', this.viewModel.steps),
          detailColor: SemanticColors.accent,
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
  }
}
