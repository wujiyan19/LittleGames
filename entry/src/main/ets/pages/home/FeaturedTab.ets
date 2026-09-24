/**
 * 精选 Tab — 横幅 + 热门推荐栅格
 * 原先是 Index.ets 内的 @Builder，抽出后横幅与卡片栅格自持，
 * 只通过 games 接收数据、onGameClick 透出点击，不感知路由与数据层。
 */
import { SemanticColors, FontTokens, RadiusTokens, SpacingTokens } from '../../common/DesignTokens';
import { GameInfo } from '../../common/GameConstants';
import { GameCard } from '../../components/GameCard';

@ComponentV2
export struct FeaturedTab {
  /** 已按热度排好的展示列表 */
  @Param games: GameInfo[] = [];
  @Param onGameClick: (game: GameInfo) => void = () => {};

  build() {
    Scroll() {
      Column() {
        this.Banner()

        Row() {
          Text($r('app.string.home_hot_title'))
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeBodyLarge)
            .fontWeight(FontTokens.weightSemibold)
            .fontColor(SemanticColors.textPrimary)
          Text($r('app.string.home_featured_subtitle'))
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeBodySmall)
            .fontColor(SemanticColors.textTertiary)
            .margin({ left: SpacingTokens.sm })
        }
        .width('100%')
        .padding({ left: SpacingTokens.pageHorizontal, top: SpacingTokens.lg, bottom: SpacingTokens.sm })

        GridRow({
          gutter: { x: SpacingTokens.base, y: SpacingTokens.base },
          columns: { sm: 4, md: 8, lg: 12 },
          breakpoints: { value: ['320vp', '600vp', '840vp'], reference: BreakpointsReference.WindowSize }
        }) {
          ForEach(this.games, (game: GameInfo) => {
            GridCol({ span: { sm: 2, md: 2, lg: 3 } }) {
              GameCard({ game: game, onTap: () => { this.onGameClick(game); } })
            }
          }, (game: GameInfo) => game.id)
        }
        .width('100%')
        .padding({
          left: SpacingTokens.pageHorizontal,
          right: SpacingTokens.pageHorizontal,
          bottom: SpacingTokens.xxl
        })
      }
      .width('100%')
    }
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor(SemanticColors.bg)
  }

  /** 横幅使用系统卡片、文字和强调色。 */
  @Builder
  Banner() {
    Stack() {
      Row() {
        Column() {
          Text($r('app.string.home_banner_title'))
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeTitle)
            .fontColor(SemanticColors.textPrimary)
            .fontWeight(FontWeight.Bold)
          Text($r('app.string.home_banner_subtitle'))
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeBody)
            .fontColor(SemanticColors.textSecondary)
            .fontWeight(FontWeight.Medium)
            .margin({ top: SpacingTokens.xs })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        SymbolGlyph($r('sys.symbol.gamecontroller'))
          .fontSize(56)
          .fontWeight(FontWeight.Medium)
          .fontColor([SemanticColors.primary])
      }
      .width('100%')
      .padding({ left: SpacingTokens.lg, right: SpacingTokens.lg, top: SpacingTokens.lg, bottom: SpacingTokens.lg })
      .borderRadius(RadiusTokens.xl)
      .backgroundColor(SemanticColors.surface)

    }
    .width('100%')
    .padding({
      left: SpacingTokens.pageHorizontal,
      right: SpacingTokens.pageHorizontal,
      top: SpacingTokens.base
    })
  }
}
