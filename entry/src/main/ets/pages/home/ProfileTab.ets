/**
 * 我的 Tab — 用户卡片 + 最近玩过 + 数据统计 + 最高分排行
 * 原先是 Index.ets 内的 @Builder，抽出后成为纯展示组件：
 * 统计数据（总数 / 最高分 / 排行榜）由父组件算好通过 @Param 传入，
 * 不再在 build 过程中调用数据层。
 */
import { SemanticColors, FontTokens, RadiusTokens, ShadowTokens, SpacingTokens, BrandColors, GameBadgeColors } from '../../common/DesignTokens';
import { GameInfo } from '../../common/GameConstants';
import { GameDataManager } from '../../model/GameData';
import { resolveString } from '../../common/I18nUtils';

@ComponentV2
export struct ProfileTab {
  /** 游戏总数（经典 + 益智） */
  @Param totalGames: number = 0;
  /** 全站最高分（无记录时为 '--'） */
  @Param bestScoreText: string = '--';
  /** 按最高分排序的展示列表 */
  @Param rankedGames: GameInfo[] = [];
  @Local hapticsEnabled: boolean = true;
  @Local rankListOpacity: number = 0;
  @Local rankListTranslateY: number = 20;

  aboutToAppear(): void {
    this.hapticsEnabled = GameDataManager.getSetting('hapticsEnabled', true);
    this.getUIContext().animateTo({ duration: 400, delay: 100, curve: Curve.FastOutSlowIn }, () => {
      this.rankListOpacity = 1;
      this.rankListTranslateY = 0;
    });
  }

  getTotalPlayCount(): number {
    let total = 0;
    const allGames = GameDataManager.getAllGames();
    for (let i = 0; i < allGames.length; i++) {
      total += allGames[i].playCount;
    }
    return total;
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
    if (total >= 100) { return SemanticColors.warning; }
    if (total >= 50) { return SemanticColors.accent; }
    if (total >= 10) { return SemanticColors.primary; }
    return SemanticColors.textTertiary;
  }

  getRecentGames(): GameInfo[] {
    return GameDataManager.getMostPlayed(5);
  }

  getRankColor(index: number): Resource {
    if (index === 0) { return $r('app.color.warning'); }
    if (index === 1) { return SemanticColors.textSecondary; }
    if (index === 2) { return $r('app.color.accent'); }
    return SemanticColors.textTertiary;
  }

  getRankBgColor(index: number): Resource {
    if (index === 0) { return $r('app.color.accent_light'); }
    if (index === 1) { return SemanticColors.surfaceHover; }
    if (index === 2) { return $r('app.color.primary_light'); }
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
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .borderRadius(RadiusTokens.full)
                .backgroundColor(SemanticColors.surfaceHover)
                .margin({ left: SpacingTokens.sm })
            }
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

        // 最近玩过
        if (this.getTotalPlayCount() > 0) {
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
          .padding({ left: SpacingTokens.pageHorizontal, top: SpacingTokens.lg, bottom: SpacingTokens.sm })

          Scroll() {
            Row({ space: SpacingTokens.md }) {
              ForEach(this.getRecentGames(), (game: GameInfo) => {
                Column() {
                  Column() {
                    Text(game.icon)
                      .fontSize(22)
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
            .padding({ left: SpacingTokens.pageHorizontal, right: SpacingTokens.pageHorizontal })
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
        }

        // 数据卡片
        Row({ space: SpacingTokens.base }) {
          this.StatsCard($r('sys.symbol.square_grid_2x2'), $r('app.string.profile_stat_total'), '' + this.totalGames)
          this.StatsCard($r('sys.symbol.star_fill'), $r('app.string.profile_stat_collected'), '10')
          this.StatsCard($r('sys.symbol.star_fill'), $r('app.string.profile_stat_best'), this.bestScoreText)
        }
        .width('100%')
        .padding({
          left: SpacingTokens.pageHorizontal,
          right: SpacingTokens.pageHorizontal,
          top: SpacingTokens.base
        })

        // 设置卡片
        Row() {
          Column() {
            Text($r('app.string.settings_haptics'))
              .fontFamily(FontTokens.family)
              .fontSize(FontTokens.sizeBody)
              .fontWeight(FontTokens.weightMedium)
              .fontColor(SemanticColors.textPrimary)
            Text($r('app.string.settings_haptics_desc'))
              .fontFamily(FontTokens.family)
              .fontSize(FontTokens.sizeBodySmall)
              .fontColor(SemanticColors.textTertiary)
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Toggle({ type: ToggleType.Switch, isOn: this.hapticsEnabled })
            .onChange((isOn: boolean) => {
              this.hapticsEnabled = isOn;
              GameDataManager.setSetting('hapticsEnabled', isOn);
            })
            .selectedColor(SemanticColors.primary)
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

        Row() {
          SymbolGlyph($r('sys.symbol.star_fill'))
            .fontSize(18)
            .fontColor([SemanticColors.warning])
          Text($r('app.string.profile_ranking_title'))
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeBodyLarge)
            .fontWeight(FontTokens.weightSemibold)
            .fontColor(SemanticColors.textPrimary)
            .margin({ left: SpacingTokens.sm })
        }
        .width('100%')
        .padding({ left: SpacingTokens.pageHorizontal, top: SpacingTokens.lg, bottom: SpacingTokens.sm })

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
                  Text(game.icon)
                    .fontSize(18)
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
            }, (game: GameInfo) => game.id)
        }
        .width('100%')
        .padding({ left: SpacingTokens.pageHorizontal, right: SpacingTokens.pageHorizontal })
        .backgroundColor(SemanticColors.surface)
        .borderRadius(RadiusTokens.lg)
        .margin({ left: SpacingTokens.pageHorizontal, right: SpacingTokens.pageHorizontal })
        .opacity(this.rankListOpacity)
        .translate({ y: this.rankListTranslateY })
      }
      .width('100%')
      .padding({ bottom: SpacingTokens.xxl })
    }
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor(SemanticColors.bg)
  }

  @Builder
  StatsCard(icon: Resource, title: Resource | string, value: string) {
    Column() {
      SymbolGlyph(icon)
        .fontSize(20)
        .fontColor([SemanticColors.primary])
      Text(value)
        .fontFamily(FontTokens.family)
        .fontSize(FontTokens.sizeHeadline)
        .fontWeight(FontTokens.weightBold)
        .fontColor(SemanticColors.textPrimary)
        .margin({ top: SpacingTokens.xs })
      Text(title)
        .fontFamily(FontTokens.family)
        .fontSize(FontTokens.sizeBodySmall)
        .fontColor(SemanticColors.textTertiary)
        .margin({ top: 2 })
    }
    .layoutWeight(1)
    .padding({ top: SpacingTokens.base, bottom: SpacingTokens.base })
    .borderRadius(RadiusTokens.base)
    .backgroundColor(SemanticColors.surface)
    .shadow(ShadowTokens.card)
    .alignItems(HorizontalAlign.Center)
  }
}
