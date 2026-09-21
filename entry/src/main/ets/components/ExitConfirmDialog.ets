/**
 * 退出对局确认弹窗 — 宇宙蓝 × 雪域灰
 *
 * 对局进行中点「返回」（或系统侧滑）时弹出：确认后退出（分数已由 ViewModel 结算保留），
 * 取消则回到对局。视觉沿用 GameResultDialog 的居中卡片语言。
 */
import { SemanticColors, FontTokens, RadiusTokens, ShadowTokens, SpacingTokens } from '../common/DesignTokens';

@ComponentV2
export struct ExitConfirmDialog {
  /** 确认退出：关闭弹窗并返回首页（分数由 ViewModel 的 dispose/onAppHidden 结算） */
  @Param onConfirm: () => void = () => {};
  /** 继续对局：仅关闭弹窗 */
  @Param onCancel: () => void = () => {};

  build() {
    Column() {
      Column({ space: SpacingTokens.md }) {
        Column() {
          SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
            .fontSize(34)
            .fontWeight(FontWeight.Medium)
            .fontColor([SemanticColors.warning])
        }
        .width(64).height(64)
        .borderRadius(RadiusTokens.full)
        .backgroundColor(SemanticColors.primaryLight)
        .justifyContent(FlexAlign.Center)

        Text($r('app.string.exit_confirm_title'))
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeHeadline)
          .fontWeight(FontTokens.weightBold)
          .fontColor(SemanticColors.textPrimary)

        Text($r('app.string.exit_confirm_desc'))
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeBody)
          .fontColor(SemanticColors.textTertiary)
          .textAlign(TextAlign.Center)

        Row({ space: SpacingTokens.base }) {
          Button() {
            Text($r('app.string.exit_confirm_stay'))
              .fontFamily(FontTokens.family)
              .fontSize(FontTokens.sizeBody)
              .fontColor(SemanticColors.textPrimary)
          }
          .layoutWeight(1).height(44)
          .backgroundColor(SemanticColors.surface)
          .borderRadius(RadiusTokens.full)
          .shadow(ShadowTokens.button)
          .onClick(() => this.onCancel())

          Button() {
            Text($r('app.string.exit_confirm_leave'))
              .fontFamily(FontTokens.family)
              .fontSize(FontTokens.sizeBody)
              .fontColor(SemanticColors.textOnPrimary)
          }
          .layoutWeight(1).height(44)
          .backgroundColor(SemanticColors.primary)
          .borderRadius(RadiusTokens.full)
          .shadow(ShadowTokens.button)
          .onClick(() => this.onConfirm())
        }
        .width('100%')
        .margin({ top: SpacingTokens.sm })
      }
      .width('86%')
      .padding(SpacingTokens.lg)
      .borderRadius(RadiusTokens.xl)
      .backgroundColor(SemanticColors.surfaceTranslucent)
      .backdropBlur(24)
      .shadow(ShadowTokens.float)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%').height('100%')
    .backgroundColor(SemanticColors.scrim)
    .backdropBlur(20)
    .justifyContent(FlexAlign.Center)
  }
}