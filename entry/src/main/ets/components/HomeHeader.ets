import { SemanticColors, FontTokens, SpacingTokens } from '../common/DesignTokens';
import { HarmonyMotion } from '../common/HarmonyMotion';

/** 三个主页面共用的标题与设置入口。 */
@ComponentV2
export struct HomeHeader {
  @Param title: Resource | string = '';
  @Param onSettingsClick: () => void = () => {};

  build() {
    Row({ space: SpacingTokens.md }) {
      Text(this.title)
        .fontFamily(FontTokens.family)
        .fontSize($r('app.float.home_page_title_size'))
        .fontWeight(FontTokens.weightBold)
        .fontColor(SemanticColors.textPrimary)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Button() {
        SymbolGlyph($r('sys.symbol.gearshape'))
          .fontSize($r('app.float.home_header_action_icon_size'))
          .fontColor([SemanticColors.textPrimary])
      }
      .type(ButtonType.Circle)
      .width($r('app.float.home_action_min_height'))
      .height($r('app.float.home_action_min_height'))
      .backgroundColor(SemanticColors.surface)
      .id('home_settings_button')
      .clickEffect(HarmonyMotion.press(this.getUIContext()))
      .accessibilityText($r('app.string.settings_title'))
      .onClick(() => { this.onSettingsClick(); })
    }
    .width('100%')
    .padding({ left: SpacingTokens.pageHorizontal, right: SpacingTokens.pageHorizontal,
      top: SpacingTokens.base, bottom: SpacingTokens.md })
    .backgroundColor(SemanticColors.bg)
  }
}
