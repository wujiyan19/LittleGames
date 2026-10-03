/**
 * 统一结算弹窗 — 宇宙蓝 × 雪域灰
 *
 * 原先 10 个游戏页各自内联了一段结构完全相同的结算 UI（图标圆底 + 标题 +
 * 副标题 + 主/次按钮 + 遮罩三件套），重复约 120 行 ×10 处。本组件收敛掉这部分，
 * 差异全部通过参数表达。
 *
 * 两种内容间距共用整页遮罩和不透明卡片，棋盘边缘仍可见。
 * cardStyle = true 使用紧凑间距（记忆翻牌 / 猜数字 / 扩展游戏）。
 * 组件常规填充色可能带透明度，不能用作覆盖棋盘的弹窗底色。
 *
 * 次按钮（secondaryText）留空即不渲染——数独、华容道等页面只保留一个主操作。
 */
import { SemanticColors, FontTokens, RadiusTokens, ShadowTokens, SpacingTokens } from '../common/DesignTokens';
import { Haptics } from '../common/Haptics';
import { range } from '../common/Range';

@ComponentV2
export struct GameResultDialog {
  /** 顶部圆形图标（系统 symbol 资源） */
  @Param symbol: Resource = $r('sys.symbol.star_fill');
  /** 图标前景色：成功用 success，失败用 error，普通结算用 warning */
  @Param symbolColor: ResourceColor = SemanticColors.warning;
  /** 主标题 */
  @Param title: Resource | string = '';
  /** 副标题（成绩详情），showDetail 为 true 时渲染 */
  @Param detail: Resource | string = '';
  /** 副标题颜色：成绩类用 accent，提示类用 warning */
  @Param detailColor: ResourceColor = SemanticColors.accent;
  /** 是否显示副标题（Resource 类型无 length 属性，需显式控制） */
  @Param showDetail: boolean = false;
  /** 主按钮文案 */
  @Param primaryText: Resource | string = $r('app.string.result_play_again');
  @Param onPrimary: () => void = () => {};
  /** 次按钮文案，showSecondary 为 true 时渲染 */
  @Param secondaryText: Resource | string = '';
  @Param showSecondary: boolean = false;
  @Param onSecondary: () => void = () => {};
  /** true = 紧凑内容间距；两种形态均有整页遮罩 */
  @Param cardStyle: boolean = false;
  @Param celebrate: boolean = false;
  @Local entrance: number = 0;
  @Local burst: number = 0;
  private entranceTimer: number = -1;

  @Styles
  pressedFeedback() {
    .opacity(0.72)
    .scale({ x: 0.96, y: 0.96 })
  }

  aboutToAppear(): void {
    Haptics.success();
  }
  appear(): void {
    this.entranceTimer = setTimeout(() => {
      this.entranceTimer = -1;
      this.getUIContext().animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => { this.entrance = 1; });
      if (this.celebrate) { this.getUIContext().animateTo({ duration: 1000, curve: Curve.EaseOut }, () => { this.burst = 1; }); }
    }, 16);
  }
  aboutToDisappear(): void { if (this.entranceTimer >= 0) { clearTimeout(this.entranceTimer); this.entranceTimer = -1; } }

  build() {
    Column() {
      Stack() {
        if (this.celebrate) {
          ForEach(range(10), (index: number) => {
            Image($r('app.media.exp_spark')).width($r('app.float.art_win_particle')).height($r('app.float.art_win_particle'))
              .translate({ x: Math.cos(index * Math.PI / 5) * this.burst * 150, y: Math.sin(index * Math.PI / 5) * this.burst * 180 })
              .rotate({ angle: index * 36 + this.burst * 120 }).opacity(1 - this.burst)
              .hitTestBehavior(HitTestMode.None).accessibilityLevel('no');
          }, (index: number) => index.toString());
        }
        this.DialogContent()
      }
        .width('86%').padding(SpacingTokens.lg)
        .borderRadius(RadiusTokens.xl)
        .backgroundColor($r('app.color.surface'))
        .shadow(ShadowTokens.float)
        .renderGroup(true)
        .scale({ x: 0.9 + this.entrance * 0.1, y: 0.9 + this.entrance * 0.1 })
        .translate({ y: (1 - this.entrance) * 18 }).opacity(this.entrance)
    }
      .width('100%').height('100%')
      .backgroundColor(SemanticColors.scrim)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {})
      .onAppear(() => { this.appear(); })
  }

  @Builder
  DialogContent() {
    Column() {
      Column() {
        if (this.celebrate) {
          Image($r('app.media.exp_trophy')).width(64).height(64).objectFit(ImageFit.Contain).accessibilityLevel('no');
        } else {
          SymbolGlyph(this.symbol)
          .fontSize(40)
          .fontWeight(FontWeight.Medium)
          .fontColor([this.symbolColor])
        }
      }
      .width(72).height(72)
      .borderRadius(RadiusTokens.full)
      .backgroundColor(SemanticColors.primaryLight)
      .justifyContent(FlexAlign.Center)

      Text(this.title)
        .fontFamily(FontTokens.family)
        .fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold)
        .fontColor(SemanticColors.textPrimary)
        .margin({
          top: SpacingTokens.md,
          bottom: this.showDetail ? SpacingTokens.xs : SpacingTokens.base
        })

      if (this.showDetail) {
        Text(this.detail)
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeSubtitle).fontColor(this.detailColor)
          .margin({ bottom: this.cardStyle ? SpacingTokens.base : SpacingTokens.lg })
      }

      Row({ space: SpacingTokens.base }) {
        Button(this.primaryText)
          .height(44).padding({ left: SpacingTokens.lg, right: SpacingTokens.lg })
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeBody)
          .fontColor(SemanticColors.textOnPrimary)
          .backgroundColor(SemanticColors.primary).borderRadius(RadiusTokens.full)
          .stateStyles({ pressed: this.pressedFeedback })

          .accessibilityText($r('app.string.a11y_dialog_play_again'))
          .onClick(() => this.onPrimary())

        if (this.showSecondary) {
          Button(this.secondaryText)
            .height(44).padding({ left: SpacingTokens.lg, right: SpacingTokens.lg })
            .fontFamily(FontTokens.family)
            .fontColor(SemanticColors.textPrimary).backgroundColor(SemanticColors.surface)
            .borderRadius(RadiusTokens.full)
            .stateStyles({ pressed: this.pressedFeedback })
            .accessibilityText($r('app.string.a11y_dialog_back'))
            .onClick(() => this.onSecondary())
        }
      }
    }
  }
}
