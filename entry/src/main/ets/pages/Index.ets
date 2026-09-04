/**
 * 主页壳 — 宇宙蓝 × 雪域灰
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
import { SemanticColors, SpacingTokens, FontTokens, BrandColors } from '../common/DesignTokens';
import { GamePageMap } from '../router/GameRoutes';
import { SplashLayer } from './home/SplashLayer';
import { FeaturedTab } from './home/FeaturedTab';
import { CategoryTab } from './home/CategoryTab';
import { ProfileTab } from './home/ProfileTab';

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
  // 全部游戏按拼音排序（非 UI 状态，传给分类页的「全部」）
  private allGamesPinyin: GameInfo[] = [];

  aboutToAppear(): void {
    this.loadData();
  }

  onPageShow(): void {
    this.loadData();
  }

  loadData(): void {
    this.featuredGames = GameDataManager.getTopGames(6);
    this.classicGames = GameDataManager.getGamesByCategory(GameCategory.CLASSIC);
    this.puzzleGames = GameDataManager.getGamesByCategory(GameCategory.PUZZLE);
    this.allGamesPinyin = this.sortByPinyin(GameDataManager.getAllGames());
    this.rankedGames = GameDataManager.getTopGames(6);
    this.totalGames = this.classicGames.length + this.puzzleGames.length;
    const top: GameInfo[] = GameDataManager.getTopGames(1);
    this.bestScoreText = (top.length > 0 && top[0].highScore > 0) ? top[0].highScore.toString() : '--';
  }

  // 中文按拼音排序（系统 Locale 习惯排序）
  sortByPinyin(list: GameInfo[]): GameInfo[] {
    const collator = new intl.Collator('zh-CN', { usage: 'sort', collation: 'pinyin' });
    const copy = list.slice();
    copy.sort((a: GameInfo, b: GameInfo) => collator.compare(a.name, b.name));
    return copy;
  }

  navigateToGame(game: GameInfo): void {
    let name = '';
    if (game.id === 'snake') { name = 'SnakeGamePage'; }
    else if (game.id === 'tetris') { name = 'TetrisGamePage'; }
    else if (game.id === '2048') { name = 'Game2048Page'; }
    else if (game.id === 'whackmole') { name = 'WhackMolePage'; }
    else if (game.id === 'minesweeper') { name = 'MinesweeperPage'; }
    else if (game.id === 'sudoku') { name = 'SudokuPage'; }
    else if (game.id === 'slidepuzzle') { name = 'SlidePuzzlePage'; }
    else if (game.id === 'klotski') { name = 'KlotskiPage'; }
    else if (game.id === 'guessnumber') { name = 'GuessNumberPage'; }
    else { name = 'MemoryCardPage'; }
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
          Tabs({ barPosition: BarPosition.End, index: this.currentTab }) {
            TabContent() {
              FeaturedTab({
                games: this.featuredGames,
                onGameClick: (game: GameInfo) => { this.navigateToGame(game); }
              })
            }
            .tabBar(this.TabBuilder(0, '精选'))
            TabContent() {
              CategoryTab({
                classicGames: this.classicGames,
                puzzleGames: this.puzzleGames,
                allGames: this.allGamesPinyin,
                onGameClick: (game: GameInfo) => { this.navigateToGame(game); }
              })
            }
            .tabBar(this.TabBuilder(1, '分类'))
            TabContent() {
              ProfileTab({
                totalGames: this.totalGames,
                bestScoreText: this.bestScoreText,
                rankedGames: this.rankedGames
              })
            }
            .tabBar(this.TabBuilder(2, '我的'))
          }
          .barHeight(56)
          .barMode(BarMode.Fixed)
          .barBackgroundColor(SemanticColors.surfaceTranslucent)
          .barBackgroundBlurStyle(BlurStyle.Thin)
          .onChange((index: number) => { this.currentTab = index; })
          .layoutWeight(1)
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

  /**
   * 顶部品牌栏。背景为品牌渐变（gradientBrand，不随主题变化），
   * 因此其上的白色文字与半透明白图标是固定配色，非疏漏。
   */
  @Builder
  TopBar() {
    Row() {
      Column() {
        Text('LittleGames')
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeTitle)
          .fontWeight(FontTokens.weightSemibold)
          .fontColor('#FFFFFF')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      SymbolGlyph($r('sys.symbol.gamecontroller'))
        .fontSize(30)
        .fontWeight(FontWeight.Medium)
        .fontColor(['rgba(255, 255, 255, 0.95)', 'rgba(255, 255, 255, 0.55)'])
    }
    .width('100%')
    .padding({
      left: SpacingTokens.pageHorizontal,
      right: SpacingTokens.pageHorizontal,
      top: SpacingTokens.base,
      bottom: SpacingTokens.base
    })
    .linearGradient({
      angle: 120,
      colors: [
        [BrandColors.cosmicBlue, 0],
        [BrandColors.auroraPurple, 1]
      ]
    })
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
  TabBuilder(index: number, title: string) {
    Column() {
      SymbolGlyph(this.getTabSymbol(index))
        .fontSize(22)
        .fontWeight(FontWeight.Regular)
        .fontColor([this.getTabColor(index)])
      Text(title)
        .fontFamily(FontTokens.family)
        .fontSize(FontTokens.sizeCaption)
        .fontWeight(this.getTabWeight(index))
        .fontColor(this.getTabColor(index))
        .margin({ top: 2 })
    }
    .width('100%').height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
