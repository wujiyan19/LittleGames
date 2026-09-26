/**
 * 主页壳 — HarmonyOS 系统色与三栏导航
 *
 * 本文件原本 855 行、承担 6 类职责（路由表 / 闪屏 / Tab 容器 / 精选 / 分类 / 我的），
 * 已按职责拆分为：
 * - router/GameRoutes.ets    — Navigation 的 navDestination 路由映射
 * - pages/home/SplashLayer.ets — 启动闪屏（自带动画状态与播放时序）
 * - pages/home/FeaturedTab.ets — 精选 Tab（横幅 + 热门推荐）
 * - pages/home/CategoryTab.ets — 分类 Tab（搜索 + 筛选 + 空态）
 * - pages/home/ProfileTab.ets  — 我的 Tab（数据 + 排行榜）
 * - components/GameCard.ets    — 精选/分类共用的游戏卡片
 *
 * 壳只保留：Navigation + Tabs 骨架、数据装配（loadData）与导航回调。
 * 顺带清理：isTablet 是死状态（mediaquery 监听后从未在 UI 使用，见报告 P2-7）。
 */
import { intl } from '@kit.LocalizationKit';
import { GameDataManager } from '../model/GameData';
import { GameInfo, GameCategory } from '../common/GameConstants';
import { SemanticColors, SpacingTokens, FontTokens } from '../common/DesignTokens';
import { resolveString } from '../common/I18nUtils';
import { GamePageMap, GameRoutes } from '../router/GameRoutes';
import { SplashLayer } from './home/SplashLayer';
import { FeaturedTab } from './home/FeaturedTab';
import { CategoryTab } from './home/CategoryTab';
import { ProfileTab } from './home/ProfileTab';

/** 拼音排序器：构造是重操作，模块级单例，避免每次排序都新建（P2-6） */
const PINYIN_COLLATOR: intl.Collator = new intl.Collator('zh-CN', { usage: 'sort', collation: 'pinyin' });

@Entry
@ComponentV2
struct Index {
  pathStack: NavPathStack = new NavPathStack();
  @Local showSplash: boolean = true;
  @Local currentTab: number = 0;
  @Local featuredGames: GameInfo[] = [];
  @Local classicGames: GameInfo[] = [];
  @Local puzzleGames: GameInfo[] = [];
  @Local rankedGames: GameInfo[] = [];
  @Local totalGames: number = 0;
  @Local bestScoreText: string = '--';
  /** 0 加载中，1 已就绪，2 无数据，3 加载异常 */
  @Local dataStatus: number = 0;
  // 全部游戏按拼音排序（非 UI 状态，传给分类页的「全部」）
  private allGamesPinyin: GameInfo[] = [];
  /** 冷启动时 aboutToAppear 已完整加载，跳过紧随其后的首次 onPageShow */
  private firstShow: boolean = true;

  @Styles
  pressedFeedback() {
    .opacity(0.72)
  }

  aboutToAppear(): void {
    this.loadAll();
  }

  onPageShow(): void {
    if (this.firstShow) {
      this.firstShow = false;
      return;
    }
    // 从游戏页返回时最高分/游玩次数可能变化，只刷新受其影响的两块 + 概要
    this.refreshScores();
  }

  /** 完整加载：分类、拼音排序、排行榜与概要（冷启动一次） */
  loadAll(): void {
    this.dataStatus = 0;
    try {
      this.classicGames = GameDataManager.getGamesByCategory(GameCategory.CLASSIC);
      this.puzzleGames = GameDataManager.getGamesByCategory(GameCategory.PUZZLE);
      this.allGamesPinyin = this.sortByPinyin(GameDataManager.getAllGames());
      this.totalGames = this.classicGames.length + this.puzzleGames.length;
      this.refreshScores();
      this.dataStatus = this.totalGames > 0 ? 1 : 2;
    } catch (e) {
      this.dataStatus = 3;
    }
  }

  /**
   * 刷新受最高分/游玩次数影响的部分。
   * 精选 = 最常玩（热门），排行 = 最高分——两者口径不同，各有意义（P2-8）。
   */
  refreshScores(): void {
    this.featuredGames = GameDataManager.getMostPlayed(6);
    this.rankedGames = GameDataManager.getTopGames(6);
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
   * 跳转到指定游戏。路由名查 GameRoutes.PATHS 表；
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
    GamePageMap(name, this.pathStack)
  }

  build() {
    Stack() {
      Navigation(this.pathStack) {
        Column() {
          this.TopBar()
          if (this.dataStatus === 0) {
            this.LoadingView()
          } else if (this.dataStatus === 2) {
            this.EmptyView()
          } else if (this.dataStatus === 3) {
            this.ErrorView()
          } else {
          Tabs({ barPosition: BarPosition.End, index: this.currentTab }) {
            TabContent() {
              FeaturedTab({
                games: this.featuredGames,
                onGameClick: (game: GameInfo) => { this.navigateToGame(game); }
              })
            }
            .tabBar(this.TabBuilder(0, $r('app.string.tab_featured')))
            TabContent() {
              CategoryTab({
                classicGames: this.classicGames,
                puzzleGames: this.puzzleGames,
                allGames: this.allGamesPinyin,
                onGameClick: (game: GameInfo) => { this.navigateToGame(game); }
              })
            }
            .tabBar(this.TabBuilder(1, $r('app.string.tab_category')))
            TabContent() {
              ProfileTab({
                totalGames: this.totalGames,
                bestScoreText: this.bestScoreText,
                rankedGames: this.rankedGames
              })
            }
            .tabBar(this.TabBuilder(2, $r('app.string.tab_profile')))
          }
          .barHeight(56)
          .barMode(BarMode.Fixed)
          .barBackgroundColor(SemanticColors.surfaceTranslucent)
          .barBackgroundBlurStyle(BlurStyle.Thin)
          .onChange((index: number) => { this.currentTab = index; })
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

      if (this.showSplash) {
        SplashLayer({ onFinish: () => { this.showSplash = false; } })
      }
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
      SymbolGlyph($r('sys.symbol.gamecontroller'))
        .fontSize(48).fontColor([SemanticColors.primary])
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
        .stateStyles({ pressed: this.pressedFeedback })
        .onClick(() => { this.loadAll(); })
    }
    .width('100%').layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(SemanticColors.bg)
  }

  /** 顶部品牌栏使用系统文字、卡片与强调色。 */
  @Builder
  TopBar() {
    Row() {
      Column() {
        Text($r('app.string.app_name'))
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeTitle)
          .fontWeight(FontTokens.weightSemibold)
          .fontColor(SemanticColors.textPrimary)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      SymbolGlyph($r('sys.symbol.gamecontroller'))
        .fontSize(30)
        .fontWeight(FontWeight.Medium)
        .fontColor([SemanticColors.primary])
    }
    .width('100%')
    .padding({
      left: SpacingTokens.pageHorizontal,
      right: SpacingTokens.pageHorizontal,
      top: SpacingTokens.base,
      bottom: SpacingTokens.base
    })
    .backgroundColor(SemanticColors.surface)
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
        .fontSize(this.currentTab === index ? 24 : 22)
        .fontWeight(FontWeight.Regular)
        .fontColor([this.getTabColor(index)])
      Text(title)
        .fontFamily(FontTokens.family)
        .fontSize(FontTokens.sizeCaption)
        .fontWeight(this.getTabWeight(index))
        .fontColor(this.getTabColor(index))
        .margin({ top: 4 })
    }
    .width('100%').height('100%')
    .justifyContent(FlexAlign.Center)
    .stateStyles({ pressed: this.pressedFeedback })
  }
}
