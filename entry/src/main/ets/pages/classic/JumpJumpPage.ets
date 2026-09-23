/**
 * 跳一跳 —— View 层（展示与动画）
 *
 * 动画口径（遵守 AGENTS.md ArkUI 动画规范）：
 * - 角色跳跃/下落位移用 offset（合成属性，不触发布局）；
 * - 角色蓄力压缩用 scale（不改 height）；
 * - 蓄力条增长用 scale + transformOrigin（不改 width）；
 * - 不使用 renderGroup（含全屏长按手势，开启可能影响事件）。
 * 规则/状态在 Model/ViewModel；本层不 import Model 类型。
 */
import { SemanticColors, RadiusTokens, FontTokens, SpacingTokens } from '../../common/DesignTokens';
import { GameHeader } from '../../components/GameHeader';
import { GameDifficulty, GameStatus } from '../../common/GameConstants';
import { SafeAreaInsets } from '../../common/SafeAreaInsets';
import { GameResultDialog } from '../../components/GameResultDialog';
import { ExitConfirmDialog } from '../../components/ExitConfirmDialog';
import { GameLifecycleBus } from '../../common/GameLifecycleBus';
import { JumpJumpViewModel, PlatformData } from '../../viewmodel/JumpJumpViewModel';

/** 平台高度（vp） */
const PLATFORM_H = 18;
/** 角色尺寸（vp） */
const PLAYER_W = 30;
const PLAYER_H = 40;
/** 蓄力条轨道宽度（vp） */
const CHARGE_BAR_W = 220;
const CHARGE_BAR_H = 10;

@ComponentV2
export struct JumpJumpPage {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local safeBottom: number = SafeAreaInsets.bottom;
  @Local viewModel: JumpJumpViewModel = new JumpJumpViewModel();
  /** 游戏区实测尺寸（vp） */
  @Local areaW: number = 0;
  @Local areaH: number = 0;

  aboutToAppear(): void {
    GameLifecycleBus.attach(this.viewModel);
    this.startGame();
  }

  aboutToDisappear(): void {
    GameLifecycleBus.detach(this.viewModel);
    this.viewModel.dispose();
  }

  startGame(): void {
    this.viewModel.startGame();
  }

  /** 返回请求统一入口：进行中弹确认，其余直接返回 */
  requestExit(): void {
    if (this.viewModel.requestBack()) {
      return;
    }
    this.pathStack.pop();
  }

  private toNumber(v: Length): number {
    const n: number = parseFloat(v as string);
    return isNaN(n) ? 0 : n;
  }

  /** 平台无障碍文案：下一平台单独标识（供测试定位） */
  private platformA11y(index: number): Resource {
    if (index === this.viewModel.currentIndex + 1) {
      return $r('app.string.a11y_jumpjump_next_platform');
    }
    return $r('app.string.a11y_jumpjump_platform');
  }

  /** 地面（平台顶部）在游戏区内的 y 坐标 */
  private groundY(): number {
    if (this.areaH <= 0) { return 300; }
    return this.areaH * 0.35;
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({
          angle: 180,
          colors: [
            [SemanticColors.gradientScreen[0], 0],
            [SemanticColors.gradientScreen[1], 0.5],
            [SemanticColors.gradientScreen[2], 1]
          ]
        })

      Column() {
        GameHeader({
          gameTitle: $r('app.string.game_jumpjump_name'),
          showScore: false,
          difficulty: this.viewModel.difficulty,
          showPause: false,
          onDifficultyChange: (d: GameDifficulty) => { this.viewModel.changeDifficulty(d); },
          onBack: () => { this.requestExit(); },
          onPauseToggle: () => {},
          onRestart: () => { this.startGame(); }
        })

        Row() {
          Column() {
            Text($r('app.string.score_label'))
              .fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textTertiary)
            Text('' + this.viewModel.score)
              .id('jumpjump_score')
              .fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold)
              .fontColor(SemanticColors.accent)
          }
          .layoutWeight(1).padding(8).backgroundColor(SemanticColors.surface)
          .borderRadius(RadiusTokens.base).alignItems(HorizontalAlign.Center).margin({ left: 16 })

          Column() {
            Text($r('app.string.high_score_label'))
              .fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textTertiary)
            Text('' + this.viewModel.highScore)
              .id('jumpjump_high_score')
              .fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold)
              .fontColor(SemanticColors.textPrimary)
          }
          .layoutWeight(1).padding(8).backgroundColor(SemanticColors.surface)
          .borderRadius(RadiusTokens.base).alignItems(HorizontalAlign.Center)
          .margin({ left: 8, right: 16 })
        }.margin({ top: 12, bottom: 12 })

        // 游戏区：全屏长按蓄力
        Stack({ alignContent: Alignment.TopStart }) {
          // 平台层（只渲染屏幕可见范围内的平台）
          ForEach(this.viewModel.platforms, (p: PlatformData, index: number) => {
            if (p.centerX + p.width / 2 >= -20 && p.centerX - p.width / 2 <= this.areaW + 20) {
              Column()
                .width(p.width).height(PLATFORM_H)
                .borderRadius(RadiusTokens.sm)
                .backgroundColor(index === this.viewModel.currentIndex
                  ? SemanticColors.primary : SemanticColors.boardBorder)
                .offset({ x: p.centerX - p.width / 2, y: this.groundY() })
                .id(index === this.viewModel.currentIndex + 1
                  ? 'jumpjump_next_platform' : 'jumpjump_platform_' + p.id)
                .accessibilityText(this.platformA11y(index))
            }
          }, (p: PlatformData) => p.id.toString())

          // 角色（压缩用 scale，位移用 offset）
          Column() {
            Text('🐸').fontSize(24)
          }
          .width(PLAYER_W).height(PLAYER_H)
          .borderRadius(RadiusTokens.md)
          .backgroundColor(SemanticColors.surface)
          .justifyContent(FlexAlign.Center)
          .scale({ x: this.viewModel.playerScaleX, y: this.viewModel.playerScaleY })
          .offset({
            x: this.viewModel.playerX + this.viewModel.playerJumpX - PLAYER_W / 2,
            y: this.groundY() - PLAYER_H + this.viewModel.playerJumpY + this.viewModel.playerDropY
          })
          .id('jumpjump_player')
          .accessibilityText($r('app.string.a11y_jumpjump_player'))

          // 蓄力标记：仅蓄力时出现，作为「角色进入压缩态」的可观测证据
          if (this.viewModel.isCharging) {
            SymbolGlyph($r('sys.symbol.bolt_fill'))
              .fontSize(16)
              .fontColor([SemanticColors.accent])
              .offset({
                x: this.viewModel.playerX - 8,
                y: this.groundY() - PLAYER_H - 26
              })
              .id('jumpjump_charge_mark')
              .accessibilityText($r('app.string.a11y_jumpjump_charging'))
          }
        }
        .width('100%')
        .layoutWeight(1)
        .id('jumpjump_area')
        .onAreaChange((oldValue: Area, newValue: Area) => {
          this.areaW = this.toNumber(newValue.width);
          this.areaH = this.toNumber(newValue.height);
        })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.viewModel.beginCharge();
          } else if (event.type === TouchType.Up) {
            this.viewModel.endCharge();
          } else if (event.type === TouchType.Cancel) {
            this.viewModel.abortCharge();
          }
        })

        // 蓄力条：增长用 scale（不改 width）
        Column() {
          Stack({ alignContent: Alignment.Start }) {
            Column()
              .width(CHARGE_BAR_W).height(CHARGE_BAR_H)
              .borderRadius(CHARGE_BAR_H / 2)
              .backgroundColor(SemanticColors.cellHidden)
            if (this.viewModel.chargeRatio > 0) {
              Column()
                .width(CHARGE_BAR_W).height(CHARGE_BAR_H)
                .borderRadius(CHARGE_BAR_H / 2)
                .backgroundColor(SemanticColors.accent)
                .scale({ x: this.viewModel.chargeRatio, y: 1, centerX: '0%', centerY: '50%' })
                .id('jumpjump_charge_fill')
                .accessibilityText($r('app.string.a11y_jumpjump_charge_bar'))
            }
          }
          .width(CHARGE_BAR_W).height(CHARGE_BAR_H)
        }
        .width('100%').height(44)
        .justifyContent(FlexAlign.Center)

        Text($r('app.string.game_jumpjump_hint'))
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeBodySmall).fontColor(SemanticColors.textTertiary)
          .padding({ bottom: SpacingTokens.lg })
      }
      .width('100%').height('100%').padding({ bottom: this.safeBottom })

      if (this.viewModel.status !== GameStatus.PLAYING) {
        GameResultDialog({
          symbol: $r('sys.symbol.star_fill'),
          symbolColor: SemanticColors.warning,
          title: $r('app.string.result_game_over'),
          detail: $r('app.string.result_detail_score_format', this.viewModel.score),
          detailColor: SemanticColors.accent,
          showDetail: true,
          primaryText: $r('app.string.result_play_again'),
          onPrimary: () => { this.startGame(); },
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