/**
 * 精选 Tab — 横幅 + 热门推荐栅格
 * 原先是 Index.ets 内的 @Builder，抽出后横幅与卡片栅格自持，
 * 只通过 games 接收数据、onGameClick 透出点击，不感知路由与数据层。
 */
import { SemanticColors, FontTokens, RadiusTokens, ShadowTokens, SpacingTokens, BrandColors } from '../../common/DesignTokens';
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

  /** 横幅：背景为品牌渐变（gradientHero），故其上文字恒为白色，不随主题变化 */
  @Builder
  Banner() {
    Stack() {
      Row() {
        Column() {
          Text($r('app.string.home_banner_title'))
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeTitle)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Bold)
          Text($r('app.string.home_banner_subtitle'))
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeBody)
            .fontColor('rgba(255, 255, 255, 0.78)')
            .fontWeight(FontWeight.Medium)
            .margin({ top: SpacingTokens.xs })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        SymbolGlyph($r('sys.symbol.gamecontroller'))
          .fontSize(56)
          .fontWeight(FontWeight.Medium)
          .fontColor(['rgba(255, 255, 255, 0.95)', 'rgba(255, 255, 255, 0.45)'])
      }
      .width('100%')
      .padding({ left: SpacingTokens.lg, right: SpacingTokens.lg, top: SpacingTokens.lg, bottom: SpacingTokens.lg })
      .borderRadius(RadiusTokens.xl)
      .linearGradient({
        angle: 135,
        colors: [
          [BrandColors.cosmicBlue, 0],
          [BrandColors.auroraPurple, 1]
        ]
      })
      .shadow(ShadowTokens.float)
      .margin({
        left: SpacingTokens.pageHorizontal,
        right: SpacingTokens.pageHorizontal,
        top: SpacingTokens.base
      })

      Circle({ width: 180, height: 180 })
        .fill('rgba(93, 134, 255, 0.30)')
        .blur(50)
        .position({ x: -40, y: -30 })

      Circle({ width: 140, height: 140 })
        .fill('rgba(122, 90, 248, 0.25)')
        .blur(40)
        .position({ x: '75%', y: '60%' })
    }
    .width('100%')
    .margin({
      left: SpacingTokens.pageHorizontal,
      right: SpacingTokens.pageHorizontal,
      top: SpacingTokens.base
    })
  }
}
