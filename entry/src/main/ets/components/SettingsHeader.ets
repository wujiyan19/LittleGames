import { SemanticColors, FontTokens, SpacingTokens } from '../common/DesignTokens';
import { HeaderIconButton } from './HeaderIconButton';

@ComponentV2
export struct SettingsHeader {
  @Param title: Resource = $r('app.string.settings_title');
  @Param onBack: () => void = () => {};

  build() {
    Row({ space: SpacingTokens.md }) {
      HeaderIconButton({ label: $r('app.string.a11y_header_back'), onPress: () => { this.onBack(); } })
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
