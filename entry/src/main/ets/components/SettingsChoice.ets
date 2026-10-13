import { SemanticColors, FontTokens, SpacingTokens, RadiusTokens } from '../common/DesignTokens';
import { HarmonyMotion } from '../common/HarmonyMotion';

@ComponentV2
export struct SettingsChoice {
  @Param label: Resource | string = '';
  @Param selected: boolean = false;
  @Param onChoose: () => void = () => {};

  build() {
    Button() {
      Row({ space: SpacingTokens.xs }) {
        if (this.selected) {
          SymbolGlyph($r('sys.symbol.checkmark')).fontSize(FontTokens.sizeBody).fontColor([SemanticColors.primary])
        }
        Text(this.label).fontFamily(FontTokens.family).fontSize(FontTokens.sizeBody)
          .fontWeight(this.selected ? FontTokens.weightSemibold : FontTokens.weightRegular)
          .fontColor(this.selected ? SemanticColors.textPrimary : SemanticColors.textSecondary)
      }.justifyContent(FlexAlign.Center)
    }
    .layoutWeight(1).constraintSize({ minHeight: $r('app.float.home_action_min_height') })
    .padding({ top: SpacingTokens.sm, bottom: SpacingTokens.sm, left: SpacingTokens.xs, right: SpacingTokens.xs })
    .type(ButtonType.Normal).borderRadius(RadiusTokens.md)
    .backgroundColor(this.selected ? SemanticColors.selectionSurface : SemanticColors.bg)
    .clickEffect(HarmonyMotion.press(this.getUIContext()))
    .accessibilityDescription(this.selected ? $r('app.string.settings_selected') : $r('app.string.settings_unselected'))
    .onClick(() => { this.onChoose(); })
  }
}
