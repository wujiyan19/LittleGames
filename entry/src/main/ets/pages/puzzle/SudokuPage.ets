/**
 * 数独 —— View 层（展示与组装，含双指缩放）
 *
 * 只持有 @Local viewModel，读取其 @Trace 状态、转发操作；不 import Model 类型。
 * 缩放/偏移是纯 UI 状态，留在本层。
 * 规则见 model/game/SudokuModel.ets，状态编排见 viewmodel/SudokuViewModel.ets。
 */
import { SemanticColors, RadiusTokens, FontTokens, ShadowTokens, SpacingTokens } from '../../common/DesignTokens';
import { GameHeader } from '../../components/GameHeader';
import { GameDifficulty, GameStatus } from '../../common/GameConstants';
import { SafeAreaInsets } from '../../common/SafeAreaInsets';
import { GameResultDialog } from '../../components/GameResultDialog';
import { ScreenUtils } from '../../common/ScreenUtils';
import { range } from '../../common/Range';
import { SudokuViewModel } from '../../viewmodel/SudokuViewModel';

@ComponentV2
export struct SudokuPage {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local safeBottom: number = SafeAreaInsets.bottom;
  @Local viewModel: SudokuViewModel = new SudokuViewModel();
  @Local scaleFactor: number = 1;
  @Local offsetX: number = 0;
  @Local offsetY: number = 0;
  @Local boardPixelSize: number = 302;
  private idx9: number[] = range(9);
  private startScale: number = 1;
  private startOffsetX: number = 0;
  private startOffsetY: number = 0;

  aboutToAppear(): void {
    this.boardPixelSize = ScreenUtils.calcCell(9, 520, 24, 28) * 9 + 8;
    this.viewModel.newGame();
  }

  getCellSize(): number {
    return (this.boardPixelSize - 8) / 9;
  }

  getNumberColor(row: number, col: number): ResourceColor {
    if (this.viewModel.isFixed(row, col)) { return SemanticColors.warning; }
    return SemanticColors.textPrimary;
  }

  getNumberWeight(row: number, col: number): FontWeight {
    if (this.viewModel.isFixed(row, col)) { return FontWeight.Bold; }
    return FontWeight.Regular;
  }

  getCellBg(row: number, col: number): ResourceColor {
    if (this.viewModel.selectedRow === row && this.viewModel.selectedCol === col) { return SemanticColors.accent; }
    if ((Math.floor(row / 3) + Math.floor(col / 3)) % 2 === 0) { return SemanticColors.cellHidden; }
    return SemanticColors.cellRevealed;
  }

  getCellBorderWidth(row: number, col: number): EdgeWidths {
    return {
      top: row % 3 === 0 ? 2 : 0.5,
      left: col % 3 === 0 ? 2 : 0.5,
      right: 0.5,
      bottom: 0.5
    };
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[SemanticColors.gradientScreen[0], 0], [SemanticColors.gradientScreen[1], 0.5], [SemanticColors.gradientScreen[2], 1]] })

      Column() {
        GameHeader({
          gameTitle: '数独',
          showScore: false,
          showPause: false,
          subtitle: '点击格子 · 填入数字',
          difficulty: this.viewModel.difficulty,
          onDifficultyChange: (d: GameDifficulty) => { this.viewModel.changeDifficulty(d); },
          onBack: () => { this.pathStack.pop(); },
          onPauseToggle: () => {},
          onRestart: () => { this.viewModel.restartGame(); },
          onNewGame: () => { this.viewModel.newGame(); },
          enableNewGame: true
        })

        // 外层容器：fill 空间、居中，供缩放容器摆放
        Column() {
          // 棋盘容器：缩放变换作用于此
          Column() {
            ForEach(this.idx9, (row: number) => {
              Row() {
                ForEach(this.idx9, (col: number) => {
                  Column() {
                    if (this.viewModel.cellValue(row, col) > 0) {
                      Text('' + this.viewModel.cellValue(row, col)).fontSize(Math.max(14, this.getCellSize() * 0.5))
                        .fontColor(this.getNumberColor(row, col))
                        .fontWeight(this.getNumberWeight(row, col))
                    }
                  }.width(this.getCellSize()).height(this.getCellSize())
                  .backgroundColor(this.getCellBg(row, col))
                  .border({
                    width: this.getCellBorderWidth(row, col),
                    color: SemanticColors.boardBorder
                  })
                  .justifyContent(FlexAlign.Center)
                  .onClick(() => { this.viewModel.selectCell(row, col); })
                }, (col: number) => col.toString())
              }
            }, (row: number) => row.toString())
          }
          .scale({ x: this.scaleFactor, y: this.scaleFactor })
          .offset({ x: this.offsetX, y: this.offsetY })
          // 81 格随双指缩放/位移，整体缓存为一张位图，减少渲染批次（P2-1）
          .renderGroup(true)
          .gesture(
            GestureGroup(GestureMode.Parallel,
              PinchGesture({ fingers: 2 })
                .onActionStart((event: GestureEvent) => {
                  this.startScale = this.scaleFactor;
                  this.startOffsetX = this.offsetX;
                  this.startOffsetY = this.offsetY;
                })
                .onActionUpdate((event: GestureEvent) => {
                  const newScale = Math.max(1, Math.min(3, this.startScale * event.scale));
                  const cx = event.pinchCenterX;
                  const cy = event.pinchCenterY;
                  const half = this.boardPixelSize / 2;
                  // 以 pinchCenter 为锚点计算偏移：保持触摸中心在视觉上不动
                  this.offsetX = this.startOffsetX + (cx - half) * (this.startScale - newScale);
                  this.offsetY = this.startOffsetY + (cy - half) * (this.startScale - newScale);
                  this.scaleFactor = newScale;
                }),
              TapGesture({ count: 2 })
                .onAction(() => {
                  // 双击重置缩放
                  this.scaleFactor = 1;
                  this.offsetX = 0;
                  this.offsetY = 0;
                })
            )
          )
        }.layoutWeight(1).justifyContent(FlexAlign.Center).clip(true)

        Row({ space: SpacingTokens.sm }) {
          ForEach([1, 2, 3, 4, 5, 6, 7, 8, 9], (n: number) => {
            Button() {
              Text('' + n)
                .fontFamily(FontTokens.family)
                .fontSize(18)
                .fontWeight(FontTokens.weightMedium)
                .fontColor(SemanticColors.textPrimary)
            }
            .layoutWeight(1).height(46)
            .backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base)
            .shadow(ShadowTokens.button)
            .onClick(() => this.viewModel.setNumber(n))
          }, (n: number) => n.toString())
          Button() {
            SymbolGlyph($r('sys.symbol.xmark'))
              .fontSize(18).fontColor([SemanticColors.textOnPrimary])
          }
          .width(46).height(46)
          .backgroundColor(SemanticColors.error).borderRadius(RadiusTokens.base)
          .shadow(ShadowTokens.button)
          .onClick(() => this.viewModel.erase())
        }.width('100%').padding({ left: SpacingTokens.base, right: SpacingTokens.base, bottom: SpacingTokens.lg })
      }.width('100%').height('100%').padding({ bottom: this.safeBottom })

      if (this.viewModel.status === GameStatus.OVER) {
        GameResultDialog({
          symbol: $r('sys.symbol.checkmark_circle'),
          symbolColor: SemanticColors.success,
          title: '恭喜完成!',
          primaryText: '新游戏',
          onPrimary: () => { this.viewModel.newGame(); }
        })
      }
    }.width('100%').height('100%')
  }
}
