import { SemanticColors, FontTokens, RadiusTokens, SpacingTokens } from '../common/DesignTokens';

@ComponentV2
export struct ProfileStatsCard {
  @Param icon: Resource = $r('sys.symbol.star_fill');
  @Param title: Resource | string = '';
  @Param value: string = '';

  build() {
    Column() {
      SymbolGlyph(this.icon).fontSize(20).fontColor([SemanticColors.primary])
      Text(this.value).fontFamily(FontTokens.family).fontSize(FontTokens.sizeHeadline)
        .fontWeight(FontTokens.weightBold).fontColor(SemanticColors.textPrimary)
        // 长分数与单位保持单行；统一数值区域高度，避免挤低本卡片的标题。
        .width('100%').height(FontTokens.sizeHeadline + SpacingTokens.sm)
        .minFontSize(FontTokens.sizeBody).maxFontSize(FontTokens.sizeHeadline)
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
        .margin({ top: SpacingTokens.xs })
      Text(this.title).fontFamily(FontTokens.family).fontSize(FontTokens.sizeBodySmall)
        .fontColor(SemanticColors.textTertiary).margin({ top: SpacingTokens.xs })
    }
    .layoutWeight(1).padding({
      top: SpacingTokens.base, bottom: SpacingTokens.base,
      left: SpacingTokens.xs, right: SpacingTokens.xs
    })
    .borderRadius(RadiusTokens.base).backgroundColor(SemanticColors.surface)
    .alignItems(HorizontalAlign.Center)
  }
}
