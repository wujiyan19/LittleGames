/**
 * 我的 Tab — 用户卡片 + 最近玩过 + 数据统计 + 最高分排行
 * 原先是 Index.ets 内的 @Builder，抽出后成为纯展示组件：
 * 统计数据（总数 / 最高分 / 排行榜）由父组件算好通过 @Param 传入，
 * 不再在 build 过程中调用数据层。
 */
import { SemanticColors, FontTokens, RadiusTokens, SpacingTokens, GameBadgeColors } from '../../common/DesignTokens';
import { GameInfo } from '../../common/GameConstants';
import { resolveString } from '../../common/I18nUtils';
import { ProfileStatsCard } from '../../components/ProfileStatsCard';

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
  @Param totalPlayCount: number = 0;
  @Param onSettingsClick: () => void = () => {};
  @Local rankListOpacity: number = 0;
  @Local rankListTranslateY: number = 20;

  aboutToAppear(): void {
    this.getUIContext().animateTo({ duration: 400, delay: 100, curve: Curve.FastOutSlowIn }, () => {
      this.rankListOpacity = 1;
      this.rankListTranslateY = 0;
    });
  }

  getTotalPlayCount(): number {
    return this.totalPlayCount;
  }

  getLevelLabel(): Resource {
    const total = this.getTotalPlayCount();
    if (total >= 100) { return $r('app.string.profile_level_master'); }
    if (total >= 50) { return $r('app.string.profile_level_expert'); }
    if (total >= 10) { return $r('app.string.profile_level_player'); }
    return $r('app.string.profile_level_newbie');
  }

  getLevelColor(): Resource {
    const total = this.getTotalPlayCount();
    if (total >= 10) { return SemanticColors.primary; }
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
                .fontSize(FontTokens.sizeBodySmall)
                .fontColor(SemanticColors.textTertiary)
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
        .margin({ top: SpacingTokens.base })

        // 最近玩过
        if (this.getRecentGames().length > 0) {
          Row() {
            SymbolGlyph($r('sys.symbol.clock'))
              .fontSize(16)
              .fontColor([SemanticColors.primary])
            Text($r('app.string.profile_recent_title'))
              .fontFamily(FontTokens.family)
              .fontSize(FontTokens.sizeBodyLarge)
              .fontWeight(FontTokens.weightSemibold)
              .fontColor(SemanticColors.textPrimary)
              .margin({ left: SpacingTokens.sm })
          }
          .width('100%')
          .padding({ top: SpacingTokens.lg, bottom: SpacingTokens.sm })

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
                  .borderRadius(RadiusTokens.base)
                  .linearGradient({
                    angle: 135,
                    colors: GameBadgeColors.getGradient(game.id)
                  })
                  .justifyContent(FlexAlign.Center)

                  Text(game.name)
                    .fontFamily(FontTokens.family)
                    .fontSize(FontTokens.sizeCaption)
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
        Row({ space: SpacingTokens.base }) {
          ProfileStatsCard({ icon: $r('sys.symbol.square_grid_2x2'), title: $r('app.string.profile_stat_total'), value: '' + this.totalGames })
          ProfileStatsCard({ icon: $r('sys.symbol.star_fill'), title: $r('app.string.profile_stat_collected'), value: '' + this.playedGameCount })
          ProfileStatsCard({ icon: $r('sys.symbol.star_fill'), title: $r('app.string.profile_stat_best'), value: this.bestScoreText })
        }
        .width('100%')
        .padding({ top: SpacingTokens.base })

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
                .fontSize(FontTokens.sizeBodySmall)
                .fontColor(SemanticColors.textTertiary)
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
        .margin({ top: SpacingTokens.base })
        .onClick(() => { this.onSettingsClick(); })

        Row() {
          SymbolGlyph($r('sys.symbol.star_fill'))
            .fontSize(18)
            .fontColor([SemanticColors.primary])
          Text($r('app.string.profile_ranking_title'))
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeBodyLarge)
            .fontWeight(FontTokens.weightSemibold)
            .fontColor(SemanticColors.textPrimary)
            .margin({ left: SpacingTokens.sm })
        }
        .width('100%')
        .padding({ top: SpacingTokens.lg, bottom: SpacingTokens.sm })

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
                .borderRadius(RadiusTokens.sm)
                .linearGradient({
                  angle: 135,
                  colors: GameBadgeColors.getGradient(game.id)
                })
                .justifyContent(FlexAlign.Center)
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
              .height(52)
            }, (game: GameInfo, index: number) => game.id + '_' + game.highScore.toString() + '_' + index.toString())
        }
        .width('100%')
        .padding({ left: SpacingTokens.base, right: SpacingTokens.base })
        .backgroundColor(SemanticColors.surface)
        .borderRadius(RadiusTokens.lg)
        .opacity(this.rankListOpacity)
        .translate({ y: this.rankListTranslateY })
      }
      .width('100%')
      .padding({ left: SpacingTokens.pageHorizontal, right: SpacingTokens.pageHorizontal, bottom: $r('app.float.home_tab_content_inset') })
    }
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor(SemanticColors.bg)
  }

}
