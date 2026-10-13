/**
 * 精选 Tab — 横幅 + 最近游玩入口 + 新游与热门推荐栅格
 * 原先是 Index.ets 内的 @Builder，抽出后横幅与卡片栅格自持，
 * 通过参数接收各组游戏、onGameClick 透出点击，不感知路由与数据层。
 */
import { SemanticColors, FontTokens, RadiusTokens, SpacingTokens } from '../../common/DesignTokens';
import { GameInfo } from '../../common/GameConstants';
import { GameCard } from '../../components/GameCard';
import { HomeHeader } from '../../components/HomeHeader';
import { HarmonyMotion } from '../../common/HarmonyMotion';
import { resolveString } from '../../common/I18nUtils';
import { playTimeHours } from '../../common/PlayTime';

@ComponentV2
export struct FeaturedTab {
  /** 已按热度排好的展示列表 */
  @Param games: GameInfo[] = [];
  @Param newGames: GameInfo[] = [];
  /** 按最近游玩顺序排列，与主页和「我的」共用持久化记录。 */
  @Param recentGames: GameInfo[] = [];
  @Param onGameClick: (game: GameInfo) => void = () => {};
  @Param onHistoryClick: () => void = () => {};
  @Param onSettingsClick: () => void = () => {};
  @Param encouragement: Resource = $r('app.string.home_banner_subtitle');
  @Param onRefreshClick: () => void = () => {};

  build() {
    Column() {
      HomeHeader({ title: $r('app.string.tab_featured'), onSettingsClick: this.onSettingsClick })
      Scroll() {
        Column() {
          this.Banner()

          this.RecentGames()

          Row() {
            Text($r('app.string.home_daily_recommendation'))
              .fontFamily(FontTokens.family)
              .fontSize($r('app.float.home_section_title_size'))
              .fontWeight(FontTokens.weightSemibold)
              .fontColor(SemanticColors.textPrimary)
            Text($r('app.string.home_daily_subtitle'))
              .fontFamily(FontTokens.family)
              .fontSize(FontTokens.sizeBodySmall)
              .fontColor(SemanticColors.textTertiary)
              .margin({ left: SpacingTokens.sm })
              .layoutWeight(1)
            Button($r('app.string.home_daily_refresh'))
              .id('featured-refresh-button')
              .type(ButtonType.Normal)
              .constraintSize({ minHeight: $r('app.float.home_action_min_height') })
              .padding({ left: SpacingTokens.sm, right: SpacingTokens.sm })
              .fontSize(FontTokens.sizeBody).fontColor(SemanticColors.primary)
              .backgroundColor(Color.Transparent).borderRadius(RadiusTokens.base)
              .clickEffect(HarmonyMotion.press(this.getUIContext()))
              .accessibilityText($r('app.string.home_daily_refresh_a11y'))
              .onClick(() => { this.onRefreshClick(); })
          }
          .width('100%')
          .padding({ left: SpacingTokens.pageHorizontal, right: SpacingTokens.pageHorizontal, top: $r('app.float.home_section_gap'), bottom: SpacingTokens.md })

          GridRow({
            gutter: { x: $r('app.float.home_grid_gap_horizontal'), y: $r('app.float.home_grid_gap_vertical') },
            columns: { sm: 4, md: 8, lg: 12 },
            breakpoints: { value: ['320vp', '600vp', '840vp'], reference: BreakpointsReference.WindowSize }
          }) {
            ForEach(this.games, (game: GameInfo) => {
              GridCol({ span: { sm: 2, md: 2, lg: 3 } }) {
                GameCard({ game: game, onTap: () => { this.onGameClick(game); } }).id('daily-game-' + game.id)
              }
            }, (game: GameInfo) => game.id + '_' + game.playTimeMs.toString())
          }
          .width('100%')
          .padding({
            left: SpacingTokens.pageHorizontal,
            right: SpacingTokens.pageHorizontal
          })
          this.NewGames()
        }
        .width('100%')
      }
      .width('100%').layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .align(Alignment.Top)
    }
    .width('100%').height('100%')
    .backgroundColor(SemanticColors.bg)
  }

  @Builder
  NewGames() {
    Column() {
      Text($r('app.string.collection_new'))
        .fontFamily(FontTokens.family).fontSize($r('app.float.home_section_title_size'))
        .fontWeight(FontTokens.weightSemibold).fontColor(SemanticColors.textPrimary).width('100%')
        .margin({ bottom: SpacingTokens.md })
      GridRow({ gutter: { x: $r('app.float.home_grid_gap_horizontal'), y: $r('app.float.home_grid_gap_vertical') },
        columns: { sm: 4, md: 8, lg: 12 },
        breakpoints: { value: ['320vp', '600vp', '840vp'], reference: BreakpointsReference.WindowSize } }) {
        ForEach(this.newGames, (game: GameInfo) => {
          GridCol({ span: { sm: 2, md: 2, lg: 3 } }) {
            GameCard({ game: game, onTap: () => { this.onGameClick(game); } })
          }
        }, (game: GameInfo) => game.id + '_' + game.playTimeMs.toString())
      }.width('100%')
    }.width('100%').padding({ left: SpacingTokens.pageHorizontal, right: SpacingTokens.pageHorizontal,
      top: $r('app.float.home_section_gap'), bottom: $r('app.float.home_tab_content_inset') })
  }

  @Builder
  RecentGames() {
    Column() {
      Row({ space: SpacingTokens.sm }) {
        SymbolGlyph($r('sys.symbol.clock'))
          .fontSize(FontTokens.sizeBodyLarge)
          .fontColor([SemanticColors.primary])
        Text($r('app.string.home_recent_title'))
          .fontFamily(FontTokens.family)
          .fontSize($r('app.float.home_section_title_size'))
          .fontWeight(FontTokens.weightSemibold)
          .fontColor(SemanticColors.textPrimary)
          .layoutWeight(1)
        Button() {
          Row({ space: SpacingTokens.xs }) {
            Text($r('app.string.home_recent_view_all'))
              .fontFamily(FontTokens.family)
              .fontSize(FontTokens.sizeBody)
              .fontColor(SemanticColors.primary)
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(FontTokens.sizeBodySmall)
              .fontColor([SemanticColors.primary])
          }
        }
        .id('featured_history_button')
        .type(ButtonType.Normal)
        .constraintSize({ minHeight: $r('app.float.play_history_action_min_height') })
        .padding({ left: SpacingTokens.sm, right: SpacingTokens.sm })
        .borderRadius(RadiusTokens.base)
        .backgroundColor(Color.Transparent)
        .clickEffect(HarmonyMotion.press(this.getUIContext()))
        .accessibilityText($r('app.string.play_history_title'))
        .onClick(() => { this.onHistoryClick(); })
      }
      .width('100%')
      .padding({ left: SpacingTokens.pageHorizontal, right: SpacingTokens.pageHorizontal,
        top: $r('app.float.home_section_gap'), bottom: SpacingTokens.sm })

      // 最近首项变化时重建横向滚动容器，让刚玩的游戏回到可见位置。
      // 普通切换 Tab 时保留滚动位置。
      if (this.recentGames.length > 0) {
        ForEach([this.recentGames[0].id], (latestId: string) => {
          Scroll() {
            Row({ space: SpacingTokens.md }) {
              ForEach(this.recentGames, (game: GameInfo) => {
                this.RecentGame(game)
              }, (game: GameInfo) => game.id + '_' + game.playTimeMs.toString())
            }
            .padding({ left: SpacingTokens.pageHorizontal, right: SpacingTokens.pageHorizontal })
          }
          .id('featured_recent_scroll')
          .width('100%')
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }, (latestId: string) => latestId)
      } else {
        Text($r('app.string.play_history_empty_desc'))
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeBody)
          .fontColor(SemanticColors.textTertiary)
          .width('100%')
          .padding({ left: SpacingTokens.pageHorizontal, right: SpacingTokens.pageHorizontal,
            bottom: SpacingTokens.sm })
      }
    }
    .width('100%')
  }

  @Builder
  RecentGame(game: GameInfo) {
    Button() {
      Column({ space: SpacingTokens.sm }) {
        Column() {
          Image(game.icon)
            .width($r('app.float.home_recent_icon_size'))
            .height($r('app.float.home_recent_icon_size'))
            .objectFit(ImageFit.Contain)
        }
        .width($r('app.float.home_recent_icon_container_size'))
        .height($r('app.float.home_recent_icon_container_size'))
        .borderRadius(RadiusTokens.base)
        .backgroundColor(SemanticColors.gameIconBackground)
        .justifyContent(FlexAlign.Center)

        Text(game.name)
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeBody)
          .fontWeight(FontTokens.weightMedium)
          .fontColor(SemanticColors.textPrimary)
          .width('100%')
          .textAlign(TextAlign.Center)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text($r('app.string.play_time_hours', playTimeHours(game.playTimeMs)))
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeCaption)
          .fontColor(SemanticColors.textTertiary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
    }
    .id('recent_game_' + game.id)
    .type(ButtonType.Normal)
    .width($r('app.float.home_recent_card_width'))
    .constraintSize({ minHeight: $r('app.float.home_recent_card_min_height') })
    .padding(SpacingTokens.md)
    .borderRadius(RadiusTokens.lg)
    .backgroundColor(SemanticColors.surface)
    .renderGroup(true)
    .clickEffect(HarmonyMotion.press(this.getUIContext(), true))
    .accessibilityGroup(true)
    .accessibilityText(resolveString(game.name, this.getUIContext().getHostContext()))
    .accessibilityDescription($r('app.string.home_recent_action'))
    .onClick(() => { this.onGameClick(game); })
  }

  /** 横幅使用系统卡片、文字和强调色。 */
  @Builder
  Banner() {
    Stack() {
      Row() {
        Column() {
          Text($r('app.string.home_daily_greeting'))
            .fontFamily(FontTokens.family)
            .fontSize($r('app.float.home_section_title_size'))
            .fontColor(SemanticColors.textPrimary)
            .fontWeight(FontWeight.Medium)
          Text(this.encouragement)
            .id('featured-daily-inspiration')
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeBody)
            .fontColor(SemanticColors.textSecondary)
            .fontWeight(FontWeight.Regular)
            .margin({ top: SpacingTokens.xs })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Image($r('app.media.brand_start_icon'))
          .width($r('app.float.brand_banner_icon_size'))
          .height($r('app.float.brand_banner_icon_size'))
          .objectFit(ImageFit.Contain)
          .borderRadius(RadiusTokens.md)
      }
      .width('100%')
      .padding({ left: SpacingTokens.lg, right: SpacingTokens.lg, top: SpacingTokens.base, bottom: SpacingTokens.base })
      .borderRadius(RadiusTokens.xl)
      .backgroundColor(SemanticColors.surface)

    }
    .width('100%')
    .padding({
      left: SpacingTokens.pageHorizontal,
      right: SpacingTokens.pageHorizontal,
      top: SpacingTokens.sm
    })
  }
}
