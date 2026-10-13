/**
 * 我的 Tab — 用户卡片 + 最近玩过 + 数据统计 + 最高分排行
 * 原先是 Index.ets 内的 @Builder，抽出后成为纯展示组件：
 * 统计数据（总数 / 最高分 / 排行榜）由父组件算好通过 @Param 传入，
 * 不再在 build 过程中调用数据层。
 */
import { SemanticColors, FontTokens, RadiusTokens, SpacingTokens } from '../../common/DesignTokens';
import { GameInfo } from '../../common/GameConstants';
import { resolveString } from '../../common/I18nUtils';
import { ProfileStatsCard } from '../../components/ProfileStatsCard';
import { HomeHeader } from '../../components/HomeHeader';
import { HarmonyMotion } from '../../common/HarmonyMotion';
import { formatPlayTime } from '../../common/PlayTime';

@ComponentV2
export struct ProfileTab {
  /** 游戏总数（经典 + 益智） */
  @Param totalGames: number = 0;
  /** 全站最高分（无记录时为 '--'） */
  @Param bestScoreText: string = '--';
  /** 按最高分排序的展示列表 */
  @Param rankedGames: GameInfo[] = [];
  @Param recentGames: GameInfo[] = [];
  @Param playedGameCount: number = 0;
  @Param totalPlayTimeMs: number = 0;
  @Param onSettingsClick: () => void = () => {};

  getTotalPlayTimeText(): string {
    return formatPlayTime(this.totalPlayTimeMs, this.getUIContext().getHostContext());
  }

  getLevelLabel(): Resource {
    const hours: number = this.totalPlayTimeMs / 3600000;
    if (hours >= 10) { return $r('app.string.profile_level_master'); }
    if (hours >= 5) { return $r('app.string.profile_level_expert'); }
    if (hours >= 1) { return $r('app.string.profile_level_player'); }
    return $r('app.string.profile_level_newbie');
  }

  getLevelColor(): Resource {
    if (this.totalPlayTimeMs >= 3600000) { return SemanticColors.primary; }
    return SemanticColors.textTertiary;
  }

  getRecentGames(): GameInfo[] {
    return this.recentGames;
  }

  getRankColor(index: number): Resource {
    if (index === 0) { return SemanticColors.primary; }
    if (index === 1) { return SemanticColors.textSecondary; }
    if (index === 2) { return SemanticColors.textSecondary; }
    return SemanticColors.textTertiary;
  }

  getRankBgColor(index: number): Resource {
    if (index === 0) { return SemanticColors.surfaceHover; }
    if (index === 1) { return SemanticColors.surfaceHover; }
    if (index === 2) { return SemanticColors.surfaceHover; }
    return SemanticColors.bg;
  }

  getHighScoreText(game: GameInfo): string {
    if (game.highScore > 0) {
      const context = this.getUIContext().getHostContext();
      const label = resolveString(game.scoreLabel, context);
      return '' + game.highScore + ' ' + label;
    }
    return '--';
  }

  getHighScoreColor(game: GameInfo): Resource {
    if (game.highScore > 0) { return SemanticColors.primary; }
    return SemanticColors.textDisabled;
  }

  build() {
    Column() {
      HomeHeader({ title: $r('app.string.tab_profile'), onSettingsClick: () => { this.onSettingsClick(); } })
      Scroll() {
        Column() {
          // 用户卡片
          Row() {
            Column() {
              SymbolGlyph($r('sys.symbol.person_fill'))
                .fontSize(36)
                .fontWeight(FontWeight.Medium)
                .fontColor([SemanticColors.textOnPrimary])
            }
            .width(64).height(64)
            .borderRadius(RadiusTokens.full)
            .backgroundColor(SemanticColors.primary)
            .justifyContent(FlexAlign.Center)

            Column() {
              Text($r('app.string.profile_player_name'))
                .fontFamily(FontTokens.family)
                .fontSize(FontTokens.sizeBodyLarge)
                .fontWeight(FontTokens.weightSemibold)
                .fontColor(SemanticColors.textPrimary)
              Row() {
                Text($r('app.string.profile_player_desc'))
                  .fontFamily(FontTokens.family)
                  .fontSize(FontTokens.sizeBody)
                  .fontColor(SemanticColors.textSecondary)
                Text(this.getLevelLabel())
                  .fontFamily(FontTokens.family)
                  .fontSize(FontTokens.sizeCaption)
                  .fontWeight(FontTokens.weightBold)
                  .fontColor(this.getLevelColor())
                  .padding({ left: SpacingTokens.sm, right: SpacingTokens.sm, top: SpacingTokens.xs, bottom: SpacingTokens.xs })
                  .borderRadius(RadiusTokens.full)
                  .backgroundColor(SemanticColors.surfaceHover)
                  .margin({ left: SpacingTokens.sm })
              }
              .margin({ top: SpacingTokens.xs })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            .margin({ left: SpacingTokens.base })
          }
          .width('100%')
          .padding(SpacingTokens.base)
          .borderRadius(RadiusTokens.lg)
          .backgroundColor(SemanticColors.surface)
          .margin({ top: SpacingTokens.pageTop })

          // 最近玩过
          if (this.getRecentGames().length > 0) {
            Row() {
              SymbolGlyph($r('sys.symbol.clock'))
                .fontSize(16)
                .fontColor([SemanticColors.primary])
              Text($r('app.string.profile_recent_title'))
                .fontFamily(FontTokens.family)
                .fontSize($r('app.float.home_section_title_size'))
                .fontWeight(FontTokens.weightSemibold)
                .fontColor(SemanticColors.textPrimary)
                .margin({ left: SpacingTokens.sm })
            }
            .width('100%')
            .padding({ top: SpacingTokens.xl, bottom: SpacingTokens.md })

            Scroll() {
              Row({ space: SpacingTokens.md }) {
                ForEach(this.getRecentGames(), (game: GameInfo) => {
                  Column() {
                    Column() {
                      Image(game.icon)
                        .width(38).height(38)
                        .objectFit(ImageFit.Contain)
                    }
                    .width(44).height(44)
                    .borderRadius(RadiusTokens.md)
                    .backgroundColor(SemanticColors.gameIconBackground)
                    .justifyContent(FlexAlign.Center)

                    Text(game.name)
                      .fontFamily(FontTokens.family)
                      .fontSize(FontTokens.sizeBody)
                      .fontColor(SemanticColors.textSecondary)
                      .margin({ top: SpacingTokens.xs })
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .width(64)
                  .alignItems(HorizontalAlign.Center)
                }, (game: GameInfo) => game.id)
              }
            }
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
            .width('100%')
          }

          // 数据卡片
          GridRow({ gutter: { x: $r('app.float.home_grid_gap_horizontal'), y: $r('app.float.home_grid_gap_vertical') },
            columns: { xs: 2, sm: 2, md: 2, lg: 4 },
            breakpoints: { value: ['320vp', '600vp', '840vp'], reference: BreakpointsReference.ComponentSize } }) {
            GridCol() {
              ProfileStatsCard({ icon: $r('sys.symbol.square_grid_2x2'), title: $r('app.string.profile_stat_total'), value: '' + this.totalGames })
            }
            GridCol() {
              ProfileStatsCard({ icon: $r('sys.symbol.star_fill'), title: $r('app.string.profile_stat_collected'), value: '' + this.playedGameCount })
            }
            GridCol() {
              ProfileStatsCard({ icon: $r('sys.symbol.clock'), title: $r('app.string.profile_stat_play_time'), value: this.getTotalPlayTimeText() })
            }
            GridCol() {
              ProfileStatsCard({ icon: $r('sys.symbol.star_fill'), title: $r('app.string.profile_stat_best'), value: this.bestScoreText })
            }
          }
          .width('100%')
          .padding({ top: SpacingTokens.xl })

          // 设置卡片
          Button() {
            Row({ space: SpacingTokens.md }) {
              SymbolGlyph($r('sys.symbol.gearshape'))
                .fontSize(22).fontColor([SemanticColors.primary])
              Column() {
                Text($r('app.string.settings_title'))
                  .fontFamily(FontTokens.family)
                  .fontSize(FontTokens.sizeBody)
                  .fontWeight(FontTokens.weightMedium)
                  .fontColor(SemanticColors.textPrimary)
                Text($r('app.string.settings_entry_desc'))
                  .fontFamily(FontTokens.family)
                  .fontSize(FontTokens.sizeBody)
                  .fontColor(SemanticColors.textSecondary)
                  .margin({ top: SpacingTokens.xs })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              SymbolGlyph($r('sys.symbol.chevron_right'))
                .fontSize(14).fontColor([SemanticColors.textTertiary])
            }
            .width('100%')
          }
          .type(ButtonType.Normal)
          .width('100%')
          .padding(SpacingTokens.base)
          .borderRadius(RadiusTokens.lg)
          .backgroundColor(SemanticColors.surface)
          .margin({ top: SpacingTokens.xl })
          .constraintSize({ minHeight: $r('app.float.home_action_min_height') })
          .clickEffect(HarmonyMotion.press(this.getUIContext(), true))
          .onClick(() => { this.onSettingsClick(); })

          Row() {
            SymbolGlyph($r('sys.symbol.star_fill'))
              .fontSize(18)
              .fontColor([SemanticColors.primary])
            Text($r('app.string.profile_ranking_title'))
              .fontFamily(FontTokens.family)
              .fontSize($r('app.float.home_section_title_size'))
              .fontWeight(FontTokens.weightSemibold)
              .fontColor(SemanticColors.textPrimary)
              .margin({ left: SpacingTokens.sm })
          }
          .width('100%')
          .padding({ top: SpacingTokens.xl, bottom: SpacingTokens.md })

          Column() {
            ForEach(this.rankedGames,
              (game: GameInfo, index: number) => {
                Row() {
                  Column() {
                    Text('' + (index + 1))
                      .fontFamily(FontTokens.family)
                      .fontSize(FontTokens.sizeBodySmall)
                      .fontWeight(FontTokens.weightBold)
                      .fontColor(this.getRankColor(index))
                  }
                  .width(28).height(28)
                  .borderRadius(RadiusTokens.full)
                  .backgroundColor(this.getRankBgColor(index))
                  .justifyContent(FlexAlign.Center)

                  Column() {
                    Image(game.icon)
                      .width(32).height(32)
                      .objectFit(ImageFit.Contain)
                  }
                  .width(36).height(36)
                  .borderRadius(RadiusTokens.md)
                  .backgroundColor(SemanticColors.gameIconBackground)
                  .justifyContent(FlexAlign.Center)
                  .margin({ left: SpacingTokens.sm })

                  Text(game.name)
                    .fontFamily(FontTokens.family)
                    .fontSize(FontTokens.sizeBody)
                    .fontColor(SemanticColors.textPrimary)
                    .layoutWeight(1)
                    .margin({ left: SpacingTokens.sm })
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(this.getHighScoreText(game))
                    .fontFamily(FontTokens.family)
                    .fontSize(FontTokens.sizeBody)
                    .fontWeight(FontTokens.weightBold)
                    .fontColor(this.getHighScoreColor(game))
                    .layoutWeight(1)
                    .textAlign(TextAlign.End)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .width('100%')
                .padding({ left: SpacingTokens.base, right: SpacingTokens.base,
                  top: SpacingTokens.sm, bottom: SpacingTokens.sm })
                .constraintSize({ minHeight: $r('app.float.home_settings_row_min_height') })
                if (index < this.rankedGames.length - 1) {
                  Row() {
                    Row().height($r('app.float.home_group_divider_height'))
                      .layoutWeight(1).backgroundColor(SemanticColors.divider)
                  }.width('100%').padding({ left: SpacingTokens.base, right: SpacingTokens.base })
                }
              }, (game: GameInfo, index: number) => game.id + '_' + game.highScore.toString() + '_' + index.toString())
          }
          .width('100%')
          .backgroundColor(SemanticColors.surface)
          .borderRadius(RadiusTokens.lg)
          .renderGroup(true)
          .transition(HarmonyMotion.content(this.getUIContext()))
        }
        .width('100%')
        .padding({ left: SpacingTokens.pageHorizontal, right: SpacingTokens.pageHorizontal, bottom: $r('app.float.home_tab_content_inset') })
      }
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(SemanticColors.bg)
  }

}
