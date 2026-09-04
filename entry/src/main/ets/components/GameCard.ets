/**
 * 游戏卡片 — 精选页与分类页共用
 * 原先是 Index.ets 内的 @Builder，抽出后两个 Tab 各自持有，不再共享单文件
 */
import { SemanticColors, FontTokens, RadiusTokens, ShadowTokens, SpacingTokens } from '../common/DesignTokens';
import { GameInfo, GameCategory } from '../common/GameConstants';

const EMPTY_GAME: GameInfo = {
  id: '',
  name: '',
  category: GameCategory.PUZZLE,
  icon: '',
  description: '',
  highScore: 0,
  playCount: 0,
  scoreLabel: '分'
};

@ComponentV2
export struct GameCard {
  @Param game: GameInfo = EMPTY_GAME;
  /** 点击跳转，由父组件持有导航逻辑（各 Tab 不感知 NavPathStack）。命名为 onTap 以避开基类 onClick 属性 */
  @Param onTap: () => void = () => {};

  build() {
    Column() {
      // 图标徽章
      Column() {
        Text(this.game.icon)
          .fontSize(30)
      }
      .width(54).height(54)
      .borderRadius(RadiusTokens.base)
      .backgroundColor(SemanticColors.primaryLight)
      .justifyContent(FlexAlign.Center)

      Text(this.game.name)
        .fontFamily(FontTokens.family)
        .fontSize(FontTokens.sizeBodyLarge)
        .fontWeight(FontTokens.weightMedium)
        .fontColor(SemanticColors.textPrimary)
        .margin({ top: SpacingTokens.sm })

      Text(this.game.description)
        .fontFamily(FontTokens.family)
        .fontSize(FontTokens.sizeBodySmall)
        .fontColor(SemanticColors.textTertiary)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: SpacingTokens.xs })
    }
    .width('100%')
    .padding(SpacingTokens.base)
    .borderRadius(RadiusTokens.lg)
    .backgroundColor(SemanticColors.surface)
    .shadow(ShadowTokens.card)
    .alignItems(HorizontalAlign.Start)
    .onClick(() => { this.onTap(); })
  }
}
