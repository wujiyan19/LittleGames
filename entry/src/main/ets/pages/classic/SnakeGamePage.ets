/**
 * 贪吃蛇 —— View 层（纯展示与组装）
 *
 * 只持有 @Local viewModel，读取其 @Trace 状态、转发用户操作；
 * 不包含任何游戏规则/计时/持久化，也不 import Model 类型。
 * 规则见 model/game/SnakeModel.ets，状态编排见 viewmodel/SnakeViewModel.ets。
 */
import { SemanticColors, RadiusTokens, FontTokens, SpacingTokens } from '../../common/DesignTokens';
import { GameHeader } from '../../components/GameHeader';
import { ControlPad } from '../../components/ControlPad';
import { GameResultDialog } from '../../components/GameResultDialog';
import { GameDifficulty, GameStatus } from '../../common/GameConstants';
import { SafeAreaInsets } from '../../common/SafeAreaInsets';
import { ScreenUtils } from '../../common/ScreenUtils';
import { range } from '../../common/Range';
import { GameLifecycleBus } from '../../common/GameLifecycleBus';
import { ExitConfirmDialog } from '../../components/ExitConfirmDialog';
import { SnakeViewModel } from '../../viewmodel/SnakeViewModel';

const COLS = 20;
const ROWS = 20;

@ComponentV2
export struct SnakeGamePage {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local safeBottom: number = SafeAreaInsets.bottom;
  @Local viewModel: SnakeViewModel = new SnakeViewModel();
  @Local cell: number = 16;
  private idx20: number[] = range(COLS);

  aboutToAppear(): void {
    this.cell = ScreenUtils.calcCell(COLS, 560, 24, 8);
    // 挂到生命周期总线：切后台暂停/恢复、系统侧滑返回拦截都经总线转发
    // （页面 onPageHide/onPageShow 仅对 @Entry 生效，本页是 @ComponentV2，不可依赖）
    GameLifecycleBus.attach(this.viewModel);
    this.viewModel.startGame();
  }

  aboutToDisappear(): void {
    GameLifecycleBus.detach(this.viewModel);
    this.viewModel.dispose();
  }

  /** 返回请求统一入口：进行中弹确认（被 requestBack 拦截），其余直接返回 */
  requestExit(): void {
    if (this.viewModel.requestBack()) {
      return;
    }
    this.pathStack.pop();
  }

  getCellColor(col: number, row: number): ResourceColor {
    if (this.viewModel.isFood(col, row)) { return SemanticColors.error; }
    if (this.viewModel.isSnakeCell(col, row)) { return SemanticColors.success; }
    if ((row + col) % 2 === 0) { return SemanticColors.cellHidden; }
    return SemanticColors.cellRevealed;
  }

  getCellRadius(col: number, row: number): number {
    if (this.viewModel.isFood(col, row)) { return RadiusTokens.md; }
    return 3;
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[SemanticColors.gradientScreen[0], 0], [SemanticColors.gradientScreen[1], 0.5], [SemanticColors.gradientScreen[2], 1]] })

      Column() {
        GameHeader({ gameTitle: $r('app.string.game_snake_name'), // 得分/最高分已由下方大字指标卡展示，关闭标题栏的小字重复显示
          showScore: false,
          isPaused: this.viewModel.status === GameStatus.PAUSED,
          difficulty: this.viewModel.difficulty,
          onDifficultyChange: (d: GameDifficulty) => { this.viewModel.changeDifficulty(d); },
          onBack: () => { this.requestExit(); },
          onPauseToggle: () => { this.viewModel.togglePause(); },
          onRestart: () => { this.viewModel.startGame(); } })

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
          .alignItems(HorizontalAlign.Center).margin({ left: 8, right: 16 })
        }.margin({ top: 12, bottom: 12 })

        Column() {
          Column() {
            ForEach(this.idx20, (row: number) => {
              Row() {
                ForEach(this.idx20, (col: number) => {
                  Column() {}.width(this.cell).height(this.cell)
                    .backgroundColor(this.getCellColor(col, row))
                    .borderRadius(this.getCellRadius(col, row))
                }, (col: number) => col.toString())
              }
            }, (row: number) => row.toString())
          }.width(this.cell * COLS).height(this.cell * ROWS)
          .border({ width: 2, color: SemanticColors.boardBorder, radius: RadiusTokens.sm })
          .backgroundColor(SemanticColors.boardBg)

          if (!this.viewModel.started) {
            Text('按方向键开始')
              .fontSize(FontTokens.sizeSubtitle).fontColor(SemanticColors.textTertiary)
              .margin({ top: 12 })
          }
        }.layoutWeight(1).justifyContent(FlexAlign.Center)

        ControlPad({
          onUp: () => this.viewModel.turnUp(),
          onDown: () => this.viewModel.turnDown(),
          onLeft: () => this.viewModel.turnLeft(),
          onRight: () => this.viewModel.turnRight(),
          onCenter: () => {},
          showCenter: true, centerLabel: '✨'
        })
      }.width('100%').height('100%').padding({ bottom: this.safeBottom })

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
