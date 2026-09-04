/**
 * 我的 Tab — 用户卡片 + 数据统计 + 最高分排行
 * 原先是 Index.ets 内的 @Builder，抽出后成为纯展示组件：
 * 统计数据（总数 / 最高分 / 排行榜）由父组件算好通过 @Param 传入，
 * 不再在 build 过程中调用数据层。
 */
import { SemanticColors, FontTokens, RadiusTokens, ShadowTokens, SpacingTokens, BrandColors } from '../../common/DesignTokens';
import { GameInfo } from '../../common/GameConstants';

@ComponentV2
export struct ProfileTab {
  /** 游戏总数（经典 + 益智） */
  @Param totalGames: number = 0;
  /** 全站最高分（无记录时为 '--'） */
  @Param bestScoreText: string = '--';
  /** 按最高分排序的展示列表 */
  @Param rankedGames: GameInfo[] = [];

  getRankColor(index: number): Resource {
    if (index < 3) { return SemanticColors.warning; }
    return SemanticColors.textTertiary;
  }

  getHighScoreText(game: GameInfo): string {
    if (game.highScore > 0) { return '' + game.highScore; }
    return '--';
  }

  getHighScoreColor(game: GameInfo): Resource {
    if (game.highScore > 0) { return SemanticColors.primary; }
    return SemanticColors.textDisabled;
  }

  build() {
    Scroll() {
      Column() {
        // 用户卡片
        Row() {
          Column() {
            SymbolGlyph($r('sys.symbol.person_fill'))
              .fontSize(36)
              .fontWeight(FontWeight.Medium)
              // 头像底色是品牌渐变（cosmicBlue→auroraPurple），白图标恒可读
              .fontColor(['#FFFFFF'])
          }
          .width(64).height(64)
          .borderRadius(RadiusTokens.full)
          .linearGradient({
            angle: 135,
            colors: [[BrandColors.cosmicBlue, 0], [BrandColors.auroraPurple, 1]]
          })
          .justifyContent(FlexAlign.Center)

          Column() {
            Text('游戏玩家')
              .fontFamily(FontTokens.family)
              .fontSize(FontTokens.sizeBodyLarge)
              .fontWeight(FontTokens.weightSemibold)
              .fontColor(SemanticColors.textPrimary)
            Text('享受游戏的乐趣！')
              .fontFamily(FontTokens.family)
              .fontSize(FontTokens.sizeBodySmall)
              .fontColor(SemanticColors.textTertiary)
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .margin({ left: SpacingTokens.base })
        }
        .width('100%')
        .padding(SpacingTokens.base)
        .borderRadius(RadiusTokens.lg)
        .backgroundColor(SemanticColors.surface)
        .shadow(ShadowTokens.card)
        .margin({
          left: SpacingTokens.pageHorizontal,
          right: SpacingTokens.pageHorizontal,
          top: SpacingTokens.base
        })

        // 数据卡片
        Row({ space: SpacingTokens.base }) {
          this.StatsCard('游戏总数', '' + this.totalGames)
          this.StatsCard('已收录', '10')
          this.StatsCard('最高分', this.bestScoreText)
        }
        .width('100%')
        .padding({
          left: SpacingTokens.pageHorizontal,
          right: SpacingTokens.pageHorizontal,
          top: SpacingTokens.base
        })

        Row() {
          SymbolGlyph($r('sys.symbol.star_fill'))
            .fontSize(18)
            .fontColor([SemanticColors.warning])
          Text('最高分排行')
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeBodyLarge)
            .fontWeight(FontTokens.weightSemibold)
            .fontColor(SemanticColors.textPrimary)
            .margin({ left: SpacingTokens.sm })
        }
        .width('100%')
        .padding({ left: SpacingTokens.pageHorizontal, top: SpacingTokens.lg, bottom: SpacingTokens.sm })

        List() {
          ForEach(this.rankedGames,
            (game: GameInfo, index: number) => {
              ListItem() {
                Row() {
                  Text('' + (index + 1))
                    .fontFamily(FontTokens.family)
                    .fontSize(FontTokens.sizeBody)
                    .fontWeight(FontTokens.weightBold)
                    .fontColor(this.getRankColor(index))
                    .width(28)
                  Text(game.icon)
                    .fontSize(20)
                    .margin({ left: SpacingTokens.sm })
                  Text(game.name)
                    .fontFamily(FontTokens.family)
                    .fontSize(FontTokens.sizeBody)
                    .fontColor(SemanticColors.textPrimary)
                    .layoutWeight(1)
                    .margin({ left: SpacingTokens.sm })
                  Text(this.getHighScoreText(game))
                    .fontFamily(FontTokens.family)
                    .fontSize(FontTokens.sizeBody)
                    .fontWeight(FontTokens.weightBold)
                    .fontColor(this.getHighScoreColor(game))
                }
                .width('100%')
                .padding({ left: SpacingTokens.base, right: SpacingTokens.base })
              }
              .height(52)
            }, (game: GameInfo) => game.id)
        }
        .width('100%')
        .padding({ left: SpacingTokens.pageHorizontal, right: SpacingTokens.pageHorizontal })
        .backgroundColor(SemanticColors.surface)
        .borderRadius(RadiusTokens.lg)
        .margin({ left: SpacingTokens.pageHorizontal, right: SpacingTokens.pageHorizontal })
        .height(312)
      }
      .width('100%')
      .padding({ bottom: SpacingTokens.xxl })
    }
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor(SemanticColors.bg)
  }

  @Builder
  StatsCard(title: string, value: string) {
    Column() {
      Text(value)
        .fontFamily(FontTokens.family)
        .fontSize(FontTokens.sizeTitle)
        .fontWeight(FontTokens.weightBold)
        .fontColor(SemanticColors.textPrimary)
      Text(title)
        .fontFamily(FontTokens.family)
        .fontSize(FontTokens.sizeBodySmall)
        .fontColor(SemanticColors.textTertiary)
        .margin({ top: SpacingTokens.xs })
    }
    .layoutWeight(1)
    .padding({ top: SpacingTokens.base, bottom: SpacingTokens.base })
    .borderRadius(RadiusTokens.base)
    .backgroundColor(SemanticColors.surface)
    .shadow(ShadowTokens.card)
  }
}
