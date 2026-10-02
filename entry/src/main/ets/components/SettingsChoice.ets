import { SemanticColors, FontTokens, SpacingTokens, RadiusTokens } from '../common/DesignTokens';

@ComponentV2
export struct SettingsChoice {
  @Param label: Resource | string = '';
  @Param selected: boolean = false;
  @Param onChoose: () => void = () => {};

  build() {
    Button() {
      Row({ space: SpacingTokens.xs }) {
        if (this.selected) {
          SymbolGlyph($r('sys.symbol.checkmark')).fontSize(14).fontColor([SemanticColors.textPrimary])
        }
        Text(this.label).fontFamily(FontTokens.family).fontSize(FontTokens.sizeBody)
          .fontWeight(this.selected ? FontTokens.weightSemibold : FontTokens.weightRegular)
          .fontColor(this.selected ? SemanticColors.textPrimary : SemanticColors.textSecondary)
      }.justifyContent(FlexAlign.Center)
    }
    .layoutWeight(1).constraintSize({ minHeight: 44 })
    .padding({ top: SpacingTokens.sm, bottom: SpacingTokens.sm, left: SpacingTokens.xs, right: SpacingTokens.xs })
    .type(ButtonType.Normal).borderRadius(RadiusTokens.sm)
    .backgroundColor(this.selected ? $r('app.color.primary_light') : SemanticColors.bg)
    .accessibilityDescription(this.selected ? $r('app.string.settings_selected') : $r('app.string.settings_unselected'))
    .onClick(() => { this.onChoose(); })
  }
}
