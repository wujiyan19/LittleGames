/**
 * 我的页面 — 宇宙蓝 × 雪域灰
 */
import { GameDataManager } from '../model/GameData';
import { GameInfo } from '../common/GameConstants';
import {
  SemanticColors,
  SpacingTokens,
  FontTokens,
  RadiusTokens,
  ShadowTokens,
  BrandColors
} from '../common/DesignTokens';

@ComponentV2
export struct ProfilePage {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local allGames: GameInfo[] = [];

  aboutToAppear(): void {
    this.allGames = GameDataManager.getAllGames();
  }

  build() {
    Column() {
      // 顶部
      Row() {
        Button() {
          SymbolGlyph($r('sys.symbol.arrow_left'))
            .fontSize(20)
            .fontColor([SemanticColors.textPrimary])
        }
        .type(ButtonType.Circle)
        .width(40).height(40)
        .backgroundColor(SemanticColors.surface)
        .shadow(ShadowTokens.button)
        .onClick(() => this.pathStack.pop())

        Text('我的')
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeSubtitle)
          .fontWeight(FontTokens.weightSemibold)
          .fontColor(SemanticColors.textPrimary)
          .layoutWeight(1)
          .margin({ left: SpacingTokens.md })
      }
      .width('100%')
      .padding({
        left: SpacingTokens.pageHorizontal,
        right: SpacingTokens.pageHorizontal,
        top: SpacingTokens.sm,
        bottom: SpacingTokens.sm
      })
      .backgroundColor(SemanticColors.surface)
      .shadow(ShadowTokens.card)

      Scroll() {
        Column() {
          // 用户卡片
          Row() {
            Column() {
              SymbolGlyph($r('sys.symbol.person_fill'))
                .fontSize(36)
                .fontWeight(FontWeight.Medium)
                // 头像底色为品牌渐变（cosmicBlue→auroraPurple），白图标恒可读
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

          // 最高分排行
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

          Column() {
            ForEach([...this.allGames].sort((a: GameInfo, b: GameInfo) => b.highScore - a.highScore),
              (game: GameInfo, index: number) => {
                Row() {
                  Text('' + (index + 1))
                    .fontFamily(FontTokens.family)
                    .fontSize(FontTokens.sizeBody)
                    .fontWeight(FontTokens.weightBold)
                    .fontColor(index < 3 ? SemanticColors.warning : SemanticColors.textTertiary)
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
                  Text(game.highScore > 0 ? '' + game.highScore : '--')
                    .fontFamily(FontTokens.family)
                    .fontSize(FontTokens.sizeBody)
                    .fontWeight(FontTokens.weightBold)
                    .fontColor(game.highScore > 0 ? SemanticColors.primary : SemanticColors.textDisabled)
                }
                .width('100%')
                .height(48)
                .padding({ left: SpacingTokens.base, right: SpacingTokens.base })
              }, (game: GameInfo) => game.id)
          }
          .width('100%')
          .backgroundColor(SemanticColors.surface)
          .borderRadius(RadiusTokens.lg)
          .shadow(ShadowTokens.card)
          .margin({ left: SpacingTokens.pageHorizontal, right: SpacingTokens.pageHorizontal })

          // 关于
          Row() {
            SymbolGlyph($r('sys.symbol.info_circle'))
              .fontSize(18)
              .fontColor([SemanticColors.primary])
            Text('关于')
              .fontFamily(FontTokens.family)
              .fontSize(FontTokens.sizeBodyLarge)
              .fontWeight(FontTokens.weightSemibold)
              .fontColor(SemanticColors.textPrimary)
              .margin({ left: SpacingTokens.sm })
          }
          .width('100%')
          .padding({ left: SpacingTokens.pageHorizontal, top: SpacingTokens.lg, bottom: SpacingTokens.sm })

          Column() {
            this.InfoRow('应用名称', '小游戏合集')
            this.InfoRow('版本', '1.0.0')
            this.InfoRow('游戏数量', '10 款')
            this.InfoRow('分类', '经典休闲 / 益智解谜')
          }
          .width('100%')
          .backgroundColor(SemanticColors.surface)
          .borderRadius(RadiusTokens.lg)
          .shadow(ShadowTokens.card)
          .margin({ left: SpacingTokens.pageHorizontal, right: SpacingTokens.pageHorizontal, bottom: SpacingTokens.xxl })
        }
        .width('100%')
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%').height('100%')
    .backgroundColor(SemanticColors.bg)
  }

  @Builder
  InfoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontFamily(FontTokens.family)
        .fontSize(FontTokens.sizeBody)
        .fontColor(SemanticColors.textSecondary)
        .layoutWeight(1)
      Text(value)
        .fontFamily(FontTokens.family)
        .fontSize(FontTokens.sizeBody)
        .fontColor(SemanticColors.textPrimary)
    }
    .width('100%')
    .height(44)
    .padding({ left: SpacingTokens.base, right: SpacingTokens.base })
    .border({ width: { bottom: 0.5 }, color: SemanticColors.divider })
  }
}
