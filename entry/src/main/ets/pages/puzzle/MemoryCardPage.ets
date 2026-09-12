/**
 * 记忆翻牌 —— View 层（纯展示与组装）
 *
 * 只持有 @Local viewModel，读取其 @Trace 状态、转发操作；不 import Model 类型。
 * 规则见 model/game/MemoryCardModel.ets，状态编排见 viewmodel/MemoryCardViewModel.ets。
 */
import { SemanticColors, RadiusTokens, FontTokens, ShadowTokens, SpacingTokens } from '../../common/DesignTokens';
import { GameHeader } from '../../components/GameHeader';
import { GameDifficulty, GameStatus } from '../../common/GameConstants';
import { SafeAreaInsets } from '../../common/SafeAreaInsets';
import { GameResultDialog } from '../../components/GameResultDialog';
import { ScreenUtils } from '../../common/ScreenUtils';
import { range } from '../../common/Range';
import { MemoryCardViewModel } from '../../viewmodel/MemoryCardViewModel';

// 棋盘列数固定为 4；行数随难度变化
const COLS = 4;

@ComponentV2
export struct MemoryCardPage {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local safeBottom: number = SafeAreaInsets.bottom;
  @Local viewModel: MemoryCardViewModel = new MemoryCardViewModel();
  @Local cardW: number = 78;
  @Local rowIdx: number[] = range(4);
  private colIdx: number[] = range(COLS);

  aboutToAppear(): void {
    this.refreshLayout();
    this.viewModel.startGame();
  }

  aboutToDisappear(): void { this.viewModel.dispose(); }

  /** 卡牌尺寸与行数随难度变化 */
  refreshLayout(): void {
    this.rowIdx = range(this.viewModel.getRowCount());
    this.cardW = ScreenUtils.calcCell(COLS, 520, 48, 56);
    if (this.viewModel.getRowCount() >= 6) { this.cardW = Math.floor(this.cardW * 0.8); }
  }

  changeDifficulty(d: GameDifficulty): void {
    this.viewModel.changeDifficulty(d);
    this.refreshLayout();
  }

  getCardBg(idx: number): ResourceColor {
    if (this.viewModel.isMatched(idx)) { return SemanticColors.success; }
    if (this.viewModel.isFlipped(idx)) { return SemanticColors.accent; }
    return SemanticColors.surface;
  }

  getCardOpacity(idx: number): number {
    if (this.viewModel.isMatched(idx)) { return 0.72; }
    return 1;
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[SemanticColors.gradientScreen[0], 0], [SemanticColors.gradientScreen[1], 0.5], [SemanticColors.gradientScreen[2], 1]] })

      Column() {
        GameHeader({
          gameTitle: '记忆翻牌',
          showScore: false,
          subtitle: '已配对 ' + this.viewModel.matchedCount + ' / ' + this.viewModel.getPairCount(),
          difficulty: this.viewModel.difficulty,
          onDifficultyChange: (d: GameDifficulty) => { this.changeDifficulty(d); },
          onBack: () => { this.pathStack.pop(); },
          onPauseToggle: () => {},
          onRestart: () => { this.viewModel.startGame(); }
        })

        Row() {
          Column() {
            Text('尝试').fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textTertiary)
            Text('' + this.viewModel.attempts).fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold).fontColor(SemanticColors.accent)
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
          ForEach(this.rowIdx, (r: number) => {
            Row() {
              ForEach(this.colIdx, (c: number) => {
                Column() {
                  if (this.viewModel.isFaceUp(r * COLS + c)) {
                    Text(this.viewModel.cardEmoji(r * COLS + c)).fontSize(Math.max(24, this.cardW * 0.45))
                  } else {
                    SymbolGlyph($r('sys.symbol.star'))
                      .fontSize(Math.max(16, this.cardW * 0.3))
                      .fontColor([SemanticColors.textTertiary])
                  }
                }.width(this.cardW).height(this.cardW * 1.15).margin(3)
                .backgroundColor(this.getCardBg(r * COLS + c))
                .borderRadius(RadiusTokens.base)
                .shadow(ShadowTokens.button)
                .opacity(this.getCardOpacity(r * COLS + c))
                .onClick(() => this.viewModel.flipCard(r * COLS + c))
              }, (c: number) => c.toString())
            }
          }, (r: number) => r.toString())
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      }.width('100%').height('100%').padding({ bottom: this.safeBottom })

      if (this.viewModel.status === GameStatus.OVER) {
        GameResultDialog({
          symbol: $r('sys.symbol.star_fill'),
          symbolColor: SemanticColors.warning,
          title: '全部找到!',
          detail: '尝试: ' + this.viewModel.attempts + '  ·  最佳: ' + this.viewModel.bestScore,
          detailColor: SemanticColors.warning,
          primaryText: '再来一局',
          onPrimary: () => { this.viewModel.startGame(); },
          cardStyle: true
        })
      }
    }.width('100%').height('100%')
  }
}
