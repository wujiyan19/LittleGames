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

  @Styles
  pressedFeedback() {
    .opacity(0.72)
    .scale({ x: 0.96, y: 0.96 })
  }

  aboutToAppear(): void {
    Haptics.success();
  }

  build() {
    Column() {
      Column() { this.DialogContent() }
        .width('86%').padding(SpacingTokens.lg)
        .borderRadius(RadiusTokens.xl)
        .backgroundColor($r('app.color.surface'))
        .shadow(ShadowTokens.float)
    }
      .width('100%').height('100%')
      .backgroundColor(SemanticColors.scrim)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {})
  }

  @Builder
  DialogContent() {
    Column() {
      Column() {
        SymbolGlyph(this.symbol)
          .fontSize(40)
          .fontWeight(FontWeight.Medium)
          .fontColor([this.symbolColor])
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
