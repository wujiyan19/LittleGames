import { SemanticColors, FontTokens, SpacingTokens } from '../common/DesignTokens';
import { HarmonyMotion } from '../common/HarmonyMotion';

@ComponentV2
export struct SettingsHeader {
  @Param title: Resource = $r('app.string.settings_title');
  @Param onBack: () => void = () => {};

  build() {
    Row({ space: SpacingTokens.md }) {
      Button() {
        SymbolGlyph($r('sys.symbol.arrow_left'))
          .fontSize($r('app.float.home_header_action_icon_size')).fontColor([SemanticColors.textPrimary])
      }
      .type(ButtonType.Circle)
      .width($r('app.float.home_action_min_height')).height($r('app.float.home_action_min_height'))
      .backgroundColor(SemanticColors.surface)
      .clickEffect(HarmonyMotion.press(this.getUIContext()))
      .accessibilityText($r('app.string.a11y_header_back'))
      .onClick(() => { this.onBack(); })
      Text(this.title)
        .fontFamily(FontTokens.family).fontSize($r('app.float.home_page_title_size'))
        .fontWeight(FontTokens.weightBold).fontColor(SemanticColors.textPrimary)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .constraintSize({ maxWidth: $r('app.float.home_detail_max_width') })
    .padding({ left: SpacingTokens.pageHorizontal, right: SpacingTokens.pageHorizontal,
      top: SpacingTokens.base, bottom: SpacingTokens.md })
  }
}
