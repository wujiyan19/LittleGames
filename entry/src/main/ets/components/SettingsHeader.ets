import { SemanticColors, FontTokens, SpacingTokens } from '../common/DesignTokens';

@ComponentV2
export struct SettingsHeader {
  @Param title: Resource = $r('app.string.settings_title');
  @Param onBack: () => void = () => {};

  build() {
    Row({ space: SpacingTokens.md }) {
      Button() {
        SymbolGlyph($r('sys.symbol.arrow_left'))
          .fontSize(20).fontColor([SemanticColors.textPrimary])
      }
      .type(ButtonType.Circle)
      .width(44).height(44)
      .backgroundColor(SemanticColors.surface)
      .accessibilityText($r('app.string.a11y_header_back'))
      .onClick(() => { this.onBack(); })
      Text(this.title)
        .fontFamily(FontTokens.family).fontSize(FontTokens.sizeTitle)
        .fontWeight(FontTokens.weightBold).fontColor(SemanticColors.textPrimary)
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: SpacingTokens.pageHorizontal, right: SpacingTokens.pageHorizontal,
      top: SpacingTokens.sm, bottom: SpacingTokens.md })
  }
}
