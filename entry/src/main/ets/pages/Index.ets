/**
 * 主页壳 — HarmonyOS 系统色与三栏导航
 *
 * 本文件原本 855 行、承担 6 类职责（路由表 / 闪屏 / Tab 容器 / 精选 / 分类 / 我的），
 * 已按职责拆分为：
 * - router/GameRoutes.ets    — Navigation 的 navDestination 路由映射
 * - pages/home/FeaturedTab.ets — 精选 Tab（横幅 + 最近游玩 + 热门推荐）
 * - pages/home/CategoryTab.ets — 分类 Tab（搜索 + 筛选 + 空态）
 * - pages/home/ProfileTab.ets  — 我的 Tab（数据 + 排行榜）
 * - components/GameCard.ets    — 精选/分类共用的游戏卡片
 *
 * 壳只保留：Navigation + Tabs 骨架、数据装配（loadData）与导航回调。
 * 顺带清理：isTablet 是死状态（mediaquery 监听后从未在 UI 使用，见报告 P2-7）。
 */
import { intl } from '@kit.LocalizationKit';
import { HdsTabs, HdsTabsFloatingStyle } from '@kit.UIDesignKit';
import { AppContinuation, AppContinuationState, ContinuationNavigationState } from '../common/AppContinuation';
import { GameSessionTransfer } from '../common/GameSessionTransfer';
import { ImmersiveLight } from '../common/ImmersiveLight';
import { GameLifecycleBus } from '../common/GameLifecycleBus';
import { GameDataManager, PlayedGameRecord } from '../model/GameData';
import { GameInfo } from '../common/GameConstants';
import { SemanticColors, SpacingTokens, FontTokens } from '../common/DesignTokens';
import { resolveString } from '../common/I18nUtils';
import { GamePageMap, GameRoutes } from '../router/GameRoutes';
import { FeaturedTab } from './home/FeaturedTab';
import { PlayHistoryPage } from './home/PlayHistoryPage';
import { CategoryTab } from './home/CategoryTab';
import { ProfileTab } from './home/ProfileTab';
import { HarmonyMotion } from '../common/HarmonyMotion';
import { DailyFeaturedViewModel } from '../viewmodel/DailyFeaturedViewModel';
import { WidgetLaunch, widgetLaunch } from '../widgets/WidgetLaunch';

/** 拼音排序器：构造是重操作，模块级单例，避免每次排序都新建（P2-6） */
const PINYIN_COLLATOR: intl.Collator = new intl.Collator('zh-CN', { usage: 'sort', collation: 'pinyin' });

@Entry
@ComponentV2
struct Index {
  pathStack: NavPathStack = new NavPathStack();
  @Local currentTab: number = 0;
  @Local featuredGames: GameInfo[] = [];
  @Local dailyFeatured: DailyFeaturedViewModel = new DailyFeaturedViewModel();
  private dailyRefreshTimer: number = -1;
  @Local newGames: GameInfo[] = [];
  @Local rankedGames: GameInfo[] = [];
  @Local totalGames: number = 0;
  @Local bestScoreText: string = '--';
  @Local recentGames: GameInfo[] = [];
  @Local playHistory: PlayedGameRecord[] = [];
  @Local playedGameCount: number = 0;
  @Local totalPlayTimeMs: number = 0;
  /** 0 加载中，1 已就绪，2 无数据，3 加载异常 */
  @Local dataStatus: number = 0;
  // 全部游戏按拼音排序；清空数据后替换列表，分类页同步刷新。
  @Local allGamesPinyin: GameInfo[] = [];
  /** 冷启动时 aboutToAppear 已完整加载，跳过紧随其后的首次 onPageShow */
  private firstShow: boolean = true;
  private floatingTabStyle: HdsTabsFloatingStyle = ImmersiveLight.floatingTabs();
  @Local navigationGeneration: number = 0;
  @Local cardLaunch: WidgetLaunch = widgetLaunch;

  @Monitor('cardLaunch.revision')
  openWidgetGame(): void {
    const gameId: string = this.cardLaunch.takeGameId();
    if (gameId.length === 0) { return; }
    GameLifecycleBus.suspendSession();
    GameDataManager.flushNow();
    this.pathStack = new NavPathStack();
    this.pathStack.pushPathByName(GameRoutes.routeName(gameId), null, false);
    this.navigationGeneration++;
  }

  aboutToAppear(): void {
    this.loadAll();
    this.openWidgetGame();
    GameSessionTransfer.setFailureHandler(() => {
      AppContinuation.setRestoring(false);
      AppContinuation.reportFailure();
    });
    GameSessionTransfer.setRestoredHandler(() => {
      AppContinuation.setRestoring(false);
      this.showContinuationFeedback(true);
    });
    AppContinuation.setFailureHandler(() => { this.showContinuationFeedback(false); });
    AppContinuation.connect((): ContinuationNavigationState => {
      return { tab: this.currentTab, paths: this.pathStack.getAllPathName() };
    }, (state: AppContinuationState) => { this.restoreContinuation(state); });
  }

  aboutToDisappear(): void {
    if (this.dailyRefreshTimer >= 0) { clearTimeout(this.dailyRefreshTimer); this.dailyRefreshTimer = -1; }
    AppContinuation.disconnect();
  }

  private showContinuationFeedback(success: boolean): void {
    const message: string = resolveString(success ? $r('app.string.continuation_restored') :
      $r('app.string.continuation_restore_failed'), this.getUIContext().getHostContext());
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (e) {
      // A disappearing window must not turn an otherwise valid continuation into a failure.
    }
  }

  private restoreContinuation(state: AppContinuationState): void {
    AppContinuation.setRestoring(true);
    GameLifecycleBus.suspendSession();
    GameDataManager.flushNow();
    this.currentTab = state.tab;
    GameSessionTransfer.prepare(state.gameId, state.gamePayload);
    this.pathStack = new NavPathStack();
    for (let i = 0; i < state.paths.length; i++) {
      this.pathStack.pushPathByName(state.paths[i], null, false);
    }
    // A new key recreates Navigation even when the warm target is displaying the same game.
    this.navigationGeneration++;
    this.refreshScores();
    if (state.gameId.length === 0) {
      AppContinuation.setRestoring(false);
      this.showContinuationFeedback(true);
    }
  }

  onPageShow(): void {
    if (this.firstShow) {
      this.firstShow = false;
      return;
    }
    // 返回主页时刷新最近顺序、每日推荐、排行与概要。
    this.refreshScores();
  }

  /** 完整加载：分类、拼音排序、排行榜与概要（冷启动一次） */
  loadAll(): void {
    this.dataStatus = 0;
    try {
      this.newGames = GameDataManager.getAllGames().filter((game: GameInfo) =>
        ['fruitslice', 'backpack', 'billiards', 'guandan', 'xiangqi', 'linerescue', 'melody', 'farm'].includes(game.id));
      this.allGamesPinyin = this.sortByPinyin(GameDataManager.getAllGames());
      this.totalGames = this.allGamesPinyin.length;
      this.refreshScores();
      this.dataStatus = this.totalGames > 0 ? 1 : 2;
    } catch (e) {
      this.dataStatus = 3;
    }
  }

  /**
   * 刷新最近游玩、最高分与累计游玩时长影响的部分。
   * 精选随日期与手动批次变化；排行榜沿用最高分口径。
   */
  refreshScores(): void {
    GameLifecycleBus.flushPlayTime();
    this.dailyFeatured.update(GameDataManager.getAllGames());
    this.featuredGames = this.dailyFeatured.recommendations;
    this.scheduleDailyRefresh();
    this.rankedGames = GameDataManager.getTopGames(6);
    this.playHistory = GameDataManager.getPlayHistory();
    this.recentGames = this.playHistory.slice(0, 5).map((record: PlayedGameRecord) => record.game);
    this.playedGameCount = GameDataManager.getPlayedGameCount();
    this.totalPlayTimeMs = GameDataManager.getTotalPlayTimeMs();
    // GameInfo 是普通接口，替换数组并以时长作为卡片 key，确保返回后展示新时长。
    this.newGames = this.newGames.slice();
    this.allGamesPinyin = this.allGamesPinyin.slice();
    const top: GameInfo[] = GameDataManager.getTopGames(1);
    if (top.length > 0 && top[0].highScore > 0) {
      const context = this.getUIContext().getHostContext();
      const label = resolveString(top[0].scoreLabel, context);
      this.bestScoreText = top[0].highScore.toString() + ' ' + label;
    } else {
      this.bestScoreText = '--';
    }
  }

  // 中文按拼音排序（系统 Locale 习惯排序）
  sortByPinyin(list: GameInfo[]): GameInfo[] {
    const copy = list.slice();
    const context = this.getUIContext().getHostContext();
    copy.sort((a: GameInfo, b: GameInfo) => {
      const nameA = resolveString(a.name, context);
      const nameB = resolveString(b.name, context);
      return PINYIN_COLLATOR.compare(nameA, nameB);
    });
    return copy;
  }

  /**
   * 跳转到指定游戏。路由名通过 GameRoutes.routeName 查询；
   * 未登记的 ID 直接忽略——原实现的 else 兜底是 MemoryCardPage，
   * ID 写错会静默跳进错误的页面，比白屏更难排查。
   */
  navigateToGame(game: GameInfo): void {
    const name: string = GameRoutes.routeName(game.id);
    if (name.length === 0) {
      return;
    }
    this.pathStack.pushPathByName(name, null);
  }

  /**
   * 路由入口。
   * 注意：不能写成 .navDestination(GamePageMap)——navDestination 只会给回调传
   * 一个 name 参数，多出来的参数拿不到值，游戏页的 pathStack 会变成空，
   * 点「返回」调 pop() 即崩溃。必须由本组件这层薄包装把 this.pathStack 带进去。
   */
  @Builder
  PageMap(name: string) {
    if (name === 'PlayHistoryPage') {
      // 直接绑定本组件的响应式记录，避免全局 Builder 按值参数保留旧数组。
      PlayHistoryPage({ pathStack: this.pathStack, records: this.playHistory,
        onPageShown: () => { this.refreshScores(); } })
    } else {
      GamePageMap(name, this.pathStack, () => { this.loadAll(); })
    }
  }

  private scheduleDailyRefresh(): void {
    if (this.dailyRefreshTimer >= 0) { clearTimeout(this.dailyRefreshTimer); }
    const now: Date = new Date();
    const midnight: Date = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
    this.dailyRefreshTimer = setTimeout(() => {
      this.dailyRefreshTimer = -1;
      this.refreshScores();
    }, Math.max(1000, midnight.getTime() - now.getTime()));
  }

  build() {
    Stack() {
      ForEach([this.navigationGeneration], (generation: number) => {
      Navigation(this.pathStack) {
        Column() {
          if (this.dataStatus === 0) {
            this.LoadingView()
          } else if (this.dataStatus === 2) {
            this.EmptyView()
          } else if (this.dataStatus === 3) {
            this.ErrorView()
          } else {
          HdsTabs({ barPosition: BarPosition.End, index: this.currentTab }) {
            TabContent() {
              FeaturedTab({
                games: this.featuredGames,
                encouragement: this.dailyFeatured.inspiration,
                onRefreshClick: () => {
                  this.dailyFeatured.refresh(GameDataManager.getAllGames());
                  this.featuredGames = this.dailyFeatured.recommendations;
                },
                newGames: this.newGames,
                recentGames: this.recentGames,
                onSettingsClick: () => { this.pathStack.pushPathByName('SettingsPage', null); },
                onHistoryClick: () => { this.pathStack.pushPathByName('PlayHistoryPage', null); },
                onGameClick: (game: GameInfo) => { this.navigateToGame(game); }
              })
            }
            .tabBar(this.TabBuilder(0, $r('app.string.tab_featured')))
            TabContent() {
              CategoryTab({
                allGames: this.allGamesPinyin,
                onSettingsClick: () => { this.pathStack.pushPathByName('SettingsPage', null); },
                onGameClick: (game: GameInfo) => { this.navigateToGame(game); }
              })
            }
            .tabBar(this.TabBuilder(1, $r('app.string.tab_category')))
            TabContent() {
              ProfileTab({
                totalGames: this.totalGames,
                bestScoreText: this.bestScoreText,
                rankedGames: this.rankedGames,
                recentGames: this.recentGames,
                playedGameCount: this.playedGameCount,
                totalPlayTimeMs: this.totalPlayTimeMs,
                onSettingsClick: () => { this.pathStack.pushPathByName('SettingsPage', null); }
              })
            }
            .tabBar(this.TabBuilder(2, $r('app.string.tab_profile')))
          }
          .barHeight($r('app.float.home_tab_height'))
          .barMode(BarMode.Fixed)
          .barOverlap(true)
          .barFloatingStyle(this.floatingTabStyle)
          .onChange((index: number) => {
            this.currentTab = index;
            this.refreshScores();
          })
          .layoutWeight(1)
          }
        }
        .width('100%').height('100%')
        .backgroundColor(SemanticColors.bg)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      }
      .mode(NavigationMode.Stack)
      .hideTitleBar(true)
      .navDestination(this.PageMap)
      .onNavBarStateChange((isVisible: boolean) => {
        if (isVisible) { this.refreshScores(); }
      })
      }, (generation: number) => generation.toString())

    }
  }

  @Builder
  LoadingView() {
    Column({ space: SpacingTokens.base }) {
      Row() {
        Column() {}.width('65%').height(24).borderRadius(8).backgroundColor(SemanticColors.surfaceHover)
      }
      .width('100%').padding(SpacingTokens.base)
      .borderRadius(16).backgroundColor(SemanticColors.surface)

      Row({ space: SpacingTokens.base }) {
        this.SkeletonCard()
        this.SkeletonCard()
      }
      .width('100%')
    }
    .width('100%').layoutWeight(1)
    .padding(SpacingTokens.base)
    .backgroundColor(SemanticColors.bg)
  }

  @Builder
  SkeletonCard() {
    Column({ space: SpacingTokens.md }) {
      Column() {}.width(52).height(52).borderRadius(16).backgroundColor(SemanticColors.primaryLight)
      Column() {}.width('70%').height(16).borderRadius(8).backgroundColor(SemanticColors.surfaceHover)
      Column() {}.width('100%').height(12).borderRadius(8).backgroundColor(SemanticColors.surfaceHover)
    }
    .layoutWeight(1).padding(SpacingTokens.base)
    .borderRadius(24).backgroundColor(SemanticColors.surface)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  EmptyView() {
    this.StatusView($r('app.string.home_empty_title'), $r('app.string.home_empty_desc'))
  }

  @Builder
  ErrorView() {
    this.StatusView($r('app.string.home_error_title'), $r('app.string.home_error_desc'))
  }

  @Builder
  StatusView(title: Resource, detail: Resource) {
    Column({ space: SpacingTokens.md }) {
      Image($r('app.media.brand_start_icon'))
        .width($r('app.float.brand_status_icon_size'))
        .height($r('app.float.brand_status_icon_size'))
        .objectFit(ImageFit.Contain)
        .borderRadius($r('app.float.brand_status_icon_radius')).clip(true)
      Text(title)
        .fontFamily(FontTokens.family).fontSize(FontTokens.sizeTitle)
        .fontWeight(FontWeight.Bold).fontColor(SemanticColors.textPrimary)
      Text(detail)
        .fontFamily(FontTokens.family).fontSize(FontTokens.sizeBody)
        .fontColor(SemanticColors.textSecondary)
      Button($r('app.string.home_retry'))
        .fontFamily(FontTokens.family).fontSize(FontTokens.sizeBody)
        .fontColor(SemanticColors.textOnPrimary)
        .backgroundColor(SemanticColors.primary)
        .borderRadius(24)
        .margin({ top: SpacingTokens.md })
        .clickEffect(HarmonyMotion.press(this.getUIContext()))
        .onClick(() => { this.loadAll(); })
    }
    .width('100%').layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(SemanticColors.bg)
  }

  getTabSymbol(index: number): Resource {
    if (index === 0) { return $r('sys.symbol.star_fill'); }
    if (index === 1) { return $r('sys.symbol.square_grid_2x2'); }
    return $r('sys.symbol.person_fill');
  }

  getTabColor(index: number): Resource {
    if (this.currentTab === index) { return SemanticColors.primary; }
    return SemanticColors.textTertiary;
  }

  getTabWeight(index: number): number {
    if (this.currentTab === index) { return FontTokens.weightMedium; }
    return FontTokens.weightRegular;
  }

  @Builder
  TabBuilder(index: number, title: Resource | string) {
    Column() {
      SymbolGlyph(this.getTabSymbol(index))
        .fontSize($r('app.float.motion_tab_symbol_size'))
        .fontWeight(FontWeight.Regular)
        .fontColor([this.getTabColor(index)])
        .scale({
          x: HarmonyMotion.tabScale(this.getUIContext(), this.currentTab === index),
          y: HarmonyMotion.tabScale(this.getUIContext(), this.currentTab === index)
        })
        .translate({ y: HarmonyMotion.tabOffset(this.getUIContext(), this.currentTab === index) })
        .animation(HarmonyMotion.selection(this.getUIContext()))
      Text(title)
        .fontFamily(FontTokens.family)
        .fontSize(FontTokens.sizeCaption)
        .fontWeight(this.getTabWeight(index))
        .fontColor(this.getTabColor(index))
        .margin({ top: 4 })
    }
    .width('100%').height('100%')
    .justifyContent(FlexAlign.Center)
    .clickEffect(HarmonyMotion.press(this.getUIContext()))
  }
}
