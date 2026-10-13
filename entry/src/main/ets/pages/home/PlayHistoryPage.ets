import { i18n } from '@kit.LocalizationKit';
import { FontTokens, RadiusTokens, SemanticColors, SpacingTokens } from '../../common/DesignTokens';
import { HarmonyMotion } from '../../common/HarmonyMotion';
import { resolveFormattedString, resolveString } from '../../common/I18nUtils';
import { formatPlayTime } from '../../common/PlayTime';
import { SafeAreaInsets } from '../../common/SafeAreaInsets';
import { SettingsHeader } from '../../components/SettingsHeader';
import { PlayedGameRecord } from '../../model/GameData';
import { GameRoutes } from '../../router/GameRouteRegistry';

/** 完整的本地游玩记录；父页面在 NavDestination.onShown 中刷新数据。 */
@ComponentV2
export struct PlayHistoryPage {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Param records: PlayedGameRecord[] = [];
  private dateFormatter: Intl.DateTimeFormat = new Intl.DateTimeFormat(i18n.System.getSystemLocaleInstance().toString(), {
    year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit'
  });

  private lastPlayedText(record: PlayedGameRecord): string {
    const context = this.getUIContext().getHostContext();
    let time: string = resolveString($r('app.string.play_history_time_unknown'), context);
    if (record.lastPlayedAt > 0) {
      try {
        time = this.dateFormatter.format(new Date(record.lastPlayedAt));
      } catch (e) {
        // 异常日期保留游戏记录，避免格式化失败影响整个列表。
      }
    }
    return resolveFormattedString($r('app.string.play_history_last_played'), [time], context);
  }

  private totalPlayTimeText(record: PlayedGameRecord): string {
    const context = this.getUIContext().getHostContext();
    return resolveFormattedString($r('app.string.play_history_total_time'),
      [formatPlayTime(record.game.playTimeMs, context)], context);
  }

  private playGame(record: PlayedGameRecord): void {
    const route: string = GameRoutes.routeName(record.game.id);
    if (route.length > 0) { this.pathStack.pushPathByName(route, null); }
  }

  build() {
    Column() {
      SettingsHeader({ title: $r('app.string.play_history_title'), onBack: () => { this.pathStack.pop(); } })
      if (this.records.length > 0) {
        Text($r('app.string.play_history_count', this.records.length))
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeBody)
          .fontColor(SemanticColors.textSecondary)
          .width('100%')
          .constraintSize({ maxWidth: $r('app.float.home_detail_max_width') })
          .padding({ left: SpacingTokens.pageHorizontal, right: SpacingTokens.pageHorizontal,
            bottom: SpacingTokens.base })

        List({ space: SpacingTokens.base }) {
          ForEach(this.records, (record: PlayedGameRecord) => {
            ListItem() {
              this.RecordCard(record)
            }
          }, (record: PlayedGameRecord) => record.game.id + '_' + record.lastPlayedAt.toString() +
            '_' + record.game.playTimeMs.toString())
        }
        .id('play_history_list')
        .width('100%')
        .constraintSize({ maxWidth: $r('app.float.home_detail_max_width') })
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)
        .padding({ left: SpacingTokens.pageHorizontal, right: SpacingTokens.pageHorizontal,
          bottom: SpacingTokens.xxl + SafeAreaInsets.bottom })
      } else {
        Column({ space: SpacingTokens.md }) {
          SymbolGlyph($r('sys.symbol.clock'))
            .fontSize(FontTokens.sizeMega)
            .fontColor([SemanticColors.textTertiary])
          Text($r('app.string.play_history_empty_title'))
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeBodyLarge)
            .fontWeight(FontTokens.weightSemibold)
            .fontColor(SemanticColors.textPrimary)
          Text($r('app.string.play_history_empty_desc'))
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeBody)
            .fontColor(SemanticColors.textSecondary)
            .textAlign(TextAlign.Center)
        }
        .id('play_history_empty')
        .width('100%')
        .constraintSize({ maxWidth: $r('app.float.home_detail_max_width') })
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding(SpacingTokens.xl)
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(SemanticColors.bg)
  }

  @Builder
  RecordCard(record: PlayedGameRecord) {
    Button() {
      Row({ space: SpacingTokens.md }) {
        Column() {
          Image(record.game.icon)
            .width($r('app.float.home_recent_icon_size'))
            .height($r('app.float.home_recent_icon_size'))
            .objectFit(ImageFit.Contain)
        }
        .width($r('app.float.home_recent_icon_container_size'))
        .height($r('app.float.home_recent_icon_container_size'))
        .borderRadius(RadiusTokens.base)
        .backgroundColor(SemanticColors.gameIconBackground)
        .justifyContent(FlexAlign.Center)

        Column({ space: SpacingTokens.xs }) {
          Text(record.game.name)
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeBodyLarge)
            .fontWeight(FontTokens.weightSemibold)
            .fontColor(SemanticColors.textPrimary)
          Text(record.game.description)
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeBody)
            .fontColor(SemanticColors.textSecondary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.lastPlayedText(record))
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeBodySmall)
            .fontColor(SemanticColors.textSecondary)
          Text(this.totalPlayTimeText(record))
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeBodySmall)
            .fontColor(SemanticColors.textTertiary)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(FontTokens.sizeBody)
          .fontColor([SemanticColors.textTertiary])
      }
      .width('100%')
    }
    .id('history_game_' + record.game.id)
    .type(ButtonType.Normal)
    .width('100%')
    .padding(SpacingTokens.base)
    .borderRadius(RadiusTokens.lg)
    .backgroundColor(SemanticColors.surface)
    .renderGroup(true)
    .clickEffect(HarmonyMotion.press(this.getUIContext(), true))
    .accessibilityGroup(true)
    .accessibilityText(resolveString(record.game.name, this.getUIContext().getHostContext()) + '，' +
      this.lastPlayedText(record) + '，' + this.totalPlayTimeText(record))
    .accessibilityDescription($r('app.string.home_recent_action'))
    .onClick(() => { this.playGame(record); })
  }
}
