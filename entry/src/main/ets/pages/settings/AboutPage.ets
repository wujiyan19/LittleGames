import { SemanticColors, FontTokens, SpacingTokens, RadiusTokens } from '../../common/DesignTokens';
import { AppInfo } from '../../common/AppInfo';
import { SafeAreaInsets } from '../../common/SafeAreaInsets';
import { SettingsHeader } from '../../components/SettingsHeader';

@ComponentV2
export struct AboutPage {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local version: string = AppInfo.version();

  @Builder
  Statement(title: Resource, content: Resource) {
    Column({ space: SpacingTokens.sm }) {
      Text(title).fontFamily(FontTokens.family).fontSize(FontTokens.sizeBodyLarge)
        .fontWeight(FontTokens.weightSemibold).fontColor(SemanticColors.textPrimary)
      Text(content).fontFamily(FontTokens.family).fontSize(FontTokens.sizeBody)
        .fontColor(SemanticColors.textSecondary).lineHeight(24)
    }.width('100%').alignItems(HorizontalAlign.Start)
    .padding(SpacingTokens.base).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.lg)
  }

  build() {
    Column() {
      SettingsHeader({ title: $r('app.string.settings_about'), onBack: () => { this.pathStack.pop(); } })
      Scroll() {
        Column({ space: SpacingTokens.base }) {
          Column({ space: SpacingTokens.sm }) {
            Image($r('app.media.app_icon')).width(80).height(80).borderRadius(RadiusTokens.lg)
            Text($r('app.string.EntryAbility_label')).fontFamily(FontTokens.family)
              .fontSize(FontTokens.sizeTitle).fontWeight(FontTokens.weightBold).fontColor(SemanticColors.textPrimary)
            Text($r('app.string.settings_about_tagline')).fontFamily(FontTokens.family)
              .fontSize(FontTokens.sizeBody).fontColor(SemanticColors.textTertiary)
            Text(this.version.length > 0 ? this.version : $r('app.string.settings_version_unavailable'))
              .fontFamily(FontTokens.family).fontSize(FontTokens.sizeBodySmall).fontColor(SemanticColors.textTertiary)
          }.width('100%').padding({ top: SpacingTokens.lg, bottom: SpacingTokens.lg })
          this.Statement($r('app.string.settings_statement_title'), $r('app.string.settings_statement_content'))
          this.Statement($r('app.string.settings_privacy_title'), $r('app.string.settings_privacy_content'))
          this.Statement($r('app.string.settings_permission_title'), $r('app.string.settings_permission_content'))
          this.Statement($r('app.string.settings_help_title'), $r('app.string.settings_help_content'))
          this.Statement($r('app.string.continuation_help_title'), $r('app.string.continuation_help_content'))
          this.Statement($r('app.string.immersive_light_title'), $r('app.string.immersive_light_content'))
        }.width('100%')
        .padding({ left: SpacingTokens.pageHorizontal, right: SpacingTokens.pageHorizontal,
          bottom: SpacingTokens.xxl + SafeAreaInsets.bottom })
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor(SemanticColors.bg)
  }
}
