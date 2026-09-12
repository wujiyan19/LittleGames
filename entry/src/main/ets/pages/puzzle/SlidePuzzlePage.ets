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

  aboutToAppear(): void {
    this.refreshLayout();
    this.viewModel.startGame();
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

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[SemanticColors.gradientScreen[0], 0], [SemanticColors.gradientScreen[1], 0.5], [SemanticColors.gradientScreen[2], 1]] })

      Column() {
        GameHeader({ gameTitle: '滑动拼图',
          showScore: false,
          showPause: false,
          subtitle: '移动方块还原顺序',
          difficulty: this.viewModel.difficulty,
          onDifficultyChange: (d: GameDifficulty) => { this.changeDifficulty(d); },
          onBack: () => { this.pathStack.pop(); },
          onPauseToggle: () => {},
          onRestart: () => { this.viewModel.startGame(); } })

        Row() {
          Column() {
            Text('步数').fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textTertiary)
            Text('' + this.viewModel.steps).fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold).fontColor(SemanticColors.accent)
          }.layoutWeight(1).padding(8).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base)
          .alignItems(HorizontalAlign.Center).margin({ left: 16 })
          Column() {
            Text('最佳').fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textTertiary)
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
                        .fontColor('#FFFFFF')
                    }
                  }.width(this.cell).height(this.cell).margin(2)
                  .backgroundColor(this.getCellBg(r, c))
                  .borderRadius(RadiusTokens.base)
                  .shadow(ShadowTokens.button)
                  .opacity(this.getCellOpacity(r, c))
                  .onClick(() => this.viewModel.tapCell(r, c))
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
          title: '拼图完成!',
          detail: '步数: ' + this.viewModel.steps,
          detailColor: SemanticColors.accent,
          primaryText: '再来一局',
          onPrimary: () => { this.viewModel.startGame(); }
        })
      }
    }.width('100%').height('100%')
  }
}
