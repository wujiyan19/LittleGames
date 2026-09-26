/**
 * 打砖块 —— View 层（纯展示与组装）
 *
 * 只持有 @Local viewModel，读取其 @Trace 状态、转发用户操作；
 * 不包含任何游戏规则/计时/持久化，也不 import Model 类型。
 */
import { SemanticColors, RadiusTokens, FontTokens, SpacingTokens, ShadowTokens } from '../../common/DesignTokens';
import { GameHeader } from '../../components/GameHeader';
import { GameResultDialog } from '../../components/GameResultDialog';
import { ExitConfirmDialog } from '../../components/ExitConfirmDialog';
import { GameStatus } from '../../common/GameConstants';
import { SafeAreaInsets } from '../../common/SafeAreaInsets';
import { GameLifecycleBus } from '../../common/GameLifecycleBus';
import { Haptics } from '../../common/Haptics';
import { BrickBreakerViewModel, BrickViewData } from '../../viewmodel/BrickBreakerViewModel';

@ComponentV2
export struct BrickBreakerPage {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local safeBottom: number = SafeAreaInsets.bottom;
  @Local viewModel: BrickBreakerViewModel = new BrickBreakerViewModel();
  private dragStartPaddleX: number = 0;

  aboutToAppear(): void {
    GameLifecycleBus.attach(this.viewModel);
    this.viewModel.startGame();
  }

  aboutToDisappear(): void {
    GameLifecycleBus.detach(this.viewModel);
    this.viewModel.dispose();
  }

  requestExit(): void {
    if (this.viewModel.requestBack()) {
      return;
    }
    this.pathStack.pop();
  }

  /** 砖块颜色：按行号取不同颜色 */
  getBrickColor(row: number): ResourceColor {
    if (row === 0) { return $r('app.color.brick_row_0'); }
    if (row === 1) { return $r('app.color.brick_row_1'); }
    if (row === 2) { return $r('app.color.brick_row_2'); }
    if (row === 3) { return $r('app.color.brick_row_3'); }
    if (row === 4) { return $r('app.color.brick_row_4'); }
    if (row === 5) { return $r('app.color.brick_row_0'); }
    if (row === 6) { return $r('app.color.brick_row_1'); }
    return $r('app.color.brick_row_2');
  }

  @Styles
  pressedFeedback() {
    .opacity(0.72)
    .scale({ x: 0.96, y: 0.96 })
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({
          angle: 180,
          colors: [[SemanticColors.gradientScreen[0], 0], [SemanticColors.gradientScreen[1], 0.5], [SemanticColors.gradientScreen[2], 1]]
        })

      Column() {
        GameHeader({
          gameTitle: $r('app.string.game_brickbreaker_name'),
          showScore: false,
          isPaused: this.viewModel.status === GameStatus.PAUSED,
          onBack: () => { this.requestExit(); },
          onPauseToggle: () => { this.viewModel.togglePause(); },
          onRestart: () => { this.viewModel.startGame(); }
        })

        // 指标卡片：得分 / 最高分 / 生命 / 关卡
        Row() {
          Column() {
            Text($r('app.string.score_label')).fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textTertiary)
            Text('' + this.viewModel.score).fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold).fontColor(SemanticColors.accent)
          }.layoutWeight(1).padding(8).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base)
          .alignItems(HorizontalAlign.Center).margin({ left: 8 })

          Column() {
            Text($r('app.string.high_score_label')).fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textTertiary)
            Text('' + this.viewModel.highScore).fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold).fontColor(SemanticColors.textPrimary)
          }.layoutWeight(1).padding(8).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base)
          .alignItems(HorizontalAlign.Center).margin({ left: 4, right: 4 })

          Column() {
            Text($r('app.string.brickbreaker_lives_label')).fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textTertiary)
            Text('' + this.viewModel.lives).fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold).fontColor(SemanticColors.error)
          }.layoutWeight(1).padding(8).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base)
          .alignItems(HorizontalAlign.Center).margin({ left: 4, right: 4 })

          Column() {
            Text($r('app.string.brickbreaker_level_label')).fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textTertiary)
            Text('' + this.viewModel.level).fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold).fontColor(SemanticColors.success)
          }.layoutWeight(1).padding(8).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base)
          .alignItems(HorizontalAlign.Center).margin({ right: 8 })
        }.margin({ top: 8, bottom: 8 })

        // 游戏区域 - 用Column包裹Stack以支持justifyContent居中
        Column() {
          Stack({ alignContent: Alignment.TopStart }) {
            // 游戏区域背景
            Column()
              .width(this.viewModel.gameWidth())
              .height(this.viewModel.gameHeight())
              .backgroundColor(SemanticColors.boardBg)
              .borderRadius(RadiusTokens.sm)

            // 砖块层
            ForEach(this.viewModel.bricks, (brick: BrickViewData) => {
              Stack() {
                Image($r('app.media.play_brick_gloss'))
                  .width(this.viewModel.brickWidth())
                  .height(this.viewModel.brickHeight())
                  .objectFit(ImageFit.Fill)
              }
                .width(this.viewModel.brickWidth())
                .height(this.viewModel.brickHeight())
                .backgroundColor(this.getBrickColor(brick.row))
                .borderRadius(RadiusTokens.xs)
                .offset({
                  x: this.viewModel.sidePadding() + brick.col * (this.viewModel.brickWidth() + this.viewModel.brickGap()),
                  y: this.viewModel.topPadding() + brick.row * (this.viewModel.brickHeight() + this.viewModel.brickGap())
                })
                .opacity(brick.alive ? 1 : 0)
                .scale({ x: brick.alive ? 1 : 0, y: brick.alive ? 1 : 0 })
                .animation({ duration: 200, curve: Curve.EaseOut, playMode: PlayMode.Normal })
            }, (brick: BrickViewData) => brick.id.toString())

            // 挡板
            Image($r('app.media.play_brick_paddle'))
              .width(this.viewModel.paddleWidth())
              .height(this.viewModel.paddleHeight())
              .objectFit(ImageFit.Fill)
              .offset({
                x: this.viewModel.paddleCenterX - this.viewModel.paddleWidth() / 2,
                y: this.viewModel.paddleY()
              })


            // 小球
            Image($r('app.media.play_brick_ball'))
              .width(this.viewModel.ballRadius() * 2)
              .height(this.viewModel.ballRadius() * 2)
              .objectFit(ImageFit.Contain)
              .offset({
                x: this.viewModel.ballX - this.viewModel.ballRadius(),
                y: this.viewModel.ballY - this.viewModel.ballRadius()
              })

            // 待发提示
            if (!this.viewModel.started && this.viewModel.status === GameStatus.PLAYING) {
              Text($r('app.string.game_brickbreaker_hint'))
                .fontSize(FontTokens.sizeSubtitle).fontColor(SemanticColors.textTertiary)
                .position({ x: this.viewModel.gameWidth() / 2 - 80, y: this.viewModel.gameHeight() / 2 })
            }

            // 通关提示
            if (this.viewModel.levelClearMsg) {
              Column() {
                Text($r('app.string.brickbreaker_level_clear'))
                  .fontSize(FontTokens.sizeTitle).fontWeight(FontTokens.weightBold).fontColor(SemanticColors.success)
              }
              .width(this.viewModel.gameWidth())
              .height(this.viewModel.gameHeight())
              .backgroundColor(SemanticColors.scrim)
              .justifyContent(FlexAlign.Center)
            }
          }
          .width(this.viewModel.gameWidth())
          .height(this.viewModel.gameHeight())
          .gesture(
            PanGesture({ direction: PanDirection.Horizontal })
              .onActionStart((e: GestureEvent) => {
                this.dragStartPaddleX = this.viewModel.paddleCenterX;
              })
              .onActionUpdate((e: GestureEvent) => {
                this.viewModel.dragPaddle(this.dragStartPaddleX + e.offsetX);
              })
              .onActionEnd(() => {
                this.viewModel.launchBall();
              })
          )
          .stateStyles({ pressed: this.pressedFeedback }).onClick(() => {
            this.viewModel.launchBall();
          })
        }.layoutWeight(1).justifyContent(FlexAlign.Center)

        // 左右按钮
        Row({ space: SpacingTokens.xl }) {
          Button() {
            SymbolGlyph($r('sys.symbol.chevron_left'))
              .fontSize(24)
              .fontColor([SemanticColors.textOnPrimary])
          }
          .type(ButtonType.Circle)
          .width(56).height(56)
          .backgroundColor(SemanticColors.primary)

          .accessibilityText($r('app.string.a11y_brickbreaker_left'))
          .stateStyles({ pressed: this.pressedFeedback }).onClick(() => {
            Haptics.tap();
            this.viewModel.movePaddleLeft();
            this.viewModel.launchBall();
          })

          Button() {
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(24)
              .fontColor([SemanticColors.textOnPrimary])
          }
          .type(ButtonType.Circle)
          .width(56).height(56)
          .backgroundColor(SemanticColors.primary)

          .accessibilityText($r('app.string.a11y_brickbreaker_right'))
          .stateStyles({ pressed: this.pressedFeedback }).onClick(() => {
            Haptics.tap();
            this.viewModel.movePaddleRight();
            this.viewModel.launchBall();
          })
        }
        .justifyContent(FlexAlign.Center)
        .margin({ top: SpacingTokens.md, bottom: SpacingTokens.md })
      }.width('100%').height('100%').padding({ bottom: this.safeBottom })

      // 游戏结束结算弹窗
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

      // 退出确认弹窗
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
