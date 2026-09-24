/**
 * 打地鼠 —— View 层（纯展示与组装）
 *
 * 只持有 @Local viewModel，读取其 @Trace 状态、转发操作；不 import Model 类型。
 * 规则见 model/game/WhackMoleModel.ets，状态编排见 viewmodel/WhackMoleViewModel.ets。
 */
import { SemanticColors, RadiusTokens, FontTokens, ShadowTokens, SpacingTokens } from '../../common/DesignTokens';
import { GameHeader } from '../../components/GameHeader';
import { GameDifficulty, GameStatus } from '../../common/GameConstants';
import { SafeAreaInsets } from '../../common/SafeAreaInsets';
import { GameResultDialog } from '../../components/GameResultDialog';
import { ExitConfirmDialog } from '../../components/ExitConfirmDialog';
import { range } from '../../common/Range';
import { GameLifecycleBus } from '../../common/GameLifecycleBus';
import { Haptics } from '../../common/Haptics';
import { WhackMoleViewModel } from '../../viewmodel/WhackMoleViewModel';

@ComponentV2
export struct WhackMolePage {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local safeBottom: number = SafeAreaInsets.bottom;
  @Local viewModel: WhackMoleViewModel = new WhackMoleViewModel();
  private idx3: number[] = range(3);
  // 无障碍字符串缓存（在 aboutToAppear 中预解析，避免渲染热路径中反复调用 getStringSync）
  @Local a11yHoleFormat: string = '';
  @Local a11yHasMole: string = '';
  @Local a11yEmpty: string = '';

  aboutToAppear(): void {
    const context = this.getUIContext().getHostContext();
    if (context) {
      this.a11yHoleFormat = context.resourceManager.getStringSync($r('app.string.a11y_whack_hole_format'));
      this.a11yHasMole = context.resourceManager.getStringSync($r('app.string.a11y_whack_has_mole'));
      this.a11yEmpty = context.resourceManager.getStringSync($r('app.string.a11y_whack_empty'));
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

  getTimeColor(): ResourceColor {
    if (this.viewModel.timeLeft <= 5) { return SemanticColors.error; }
    return SemanticColors.success;
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
        GameHeader({ gameTitle: $r('app.string.game_whackmole_name'), // 得分/最高分已由下方大字指标卡展示，关闭标题栏的小字重复显示
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
            Text($r('app.string.time_label')).fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textTertiary)
            Text(this.viewModel.timeLeft + 's').fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold)
              .fontColor(this.getTimeColor())
          }.layoutWeight(1).padding(8).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base)
          .alignItems(HorizontalAlign.Center).margin({ left: 8, right: 16 })
        }.margin({ top: 12, bottom: 12 })

        Column() {
          ForEach(this.idx3, (row: number) => {
            Row() {
              ForEach(this.idx3, (col: number) => {
                this.MoleHole(row * 3 + col)
              }, (col: number) => col.toString())
            }
          }, (row: number) => row.toString())
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      }.width('100%').height('100%').padding({ bottom: this.safeBottom })

      if (this.viewModel.status === GameStatus.OVER) {
        GameResultDialog({
          symbol: $r('sys.symbol.star_fill'),
          symbolColor: SemanticColors.warning,
          title: $r('app.string.result_time_up'),
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

  @Builder
  MoleHole(index: number) {
    Column() {
      if (this.viewModel.holes[index]) {
        Text('🐹')
          .fontSize(44)
          .translate({ y: -8 })
      } else {
        Column() {}
          .width('72%').aspectRatio(1.4)
          .borderRadius(RadiusTokens.full)
          .backgroundColor(SemanticColors.surface)
          // 阴影恒为半透明黑：投影在深浅两种底色上都应压暗，不随主题反转
          .shadow(ShadowTokens.float)
          .margin({ bottom: 8 })
      }
    }
    .layoutWeight(1).aspectRatio(0.92)
    .justifyContent(FlexAlign.End)
    // 无障碍:读屏念出洞号与当前是否有地鼠
    .accessibilityText(this.a11yHoleFormat.replace('%1$d', '' + (index + 1)) + (this.viewModel.holes[index] ? this.a11yHasMole : this.a11yEmpty))
    .stateStyles({ pressed: this.pressedFeedback }).onClick(() => { Haptics.tap(); this.viewModel.whack(index); })
  }
}
