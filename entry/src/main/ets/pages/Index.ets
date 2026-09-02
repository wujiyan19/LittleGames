/**
 * 主页 — 宇宙蓝 × 雪域灰
 * 使用 GridRow 断点布局 + 媒体查询适配不同屏幕
 */
import { mediaquery } from '@kit.ArkUI';
import { intl } from '@kit.LocalizationKit';
import { GameDataManager } from '../model/GameData';
import { GameInfo, GameCategory } from '../common/GameConstants';
import {
  SemanticColors,
  SpacingTokens,
  FontTokens,
  RadiusTokens,
  ShadowTokens,
  BrandColors
} from '../common/DesignTokens';
import { SnakeGamePage } from './classic/SnakeGamePage';
import { TetrisGamePage } from './classic/TetrisGamePage';
import { Game2048Page } from './classic/Game2048Page';
import { WhackMolePage } from './classic/WhackMolePage';
import { MinesweeperPage } from './classic/MinesweeperPage';
import { SudokuPage } from './puzzle/SudokuPage';
import { SlidePuzzlePage } from './puzzle/SlidePuzzlePage';
import { KlotskiPage } from './puzzle/KlotskiPage';
import { GuessNumberPage } from './puzzle/GuessNumberPage';
import { MemoryCardPage } from './puzzle/MemoryCardPage';
import { ProfilePage } from './ProfilePage';

@Entry
@ComponentV2
struct Index {
  pathStack: NavPathStack = new NavPathStack();
  // 启动闪屏（原 SplashPage 折叠为首页内覆盖层）
  @Local showSplash: boolean = true;
  @Local iconAnimOpacity: number = 0;
  @Local iconAnimScale: number = 0.6;
  @Local iconAnimTranslateY: number = 20;
  @Local titleAnimOpacity: number = 0;
  @Local subtitleAnimOpacity: number = 0;
  @Local currentTab: number = 0;
  // -1=全部 0=经典休闲 1=益智解谜
  @Local currentCategory: number = -1;
  @Local searchText: string = '';
  // 当前分类 + 搜索词过滤后的展示列表（状态驱动，保证输入即刷新）
  @Local categoryGames: GameInfo[] = [];
  @Local featuredGames: GameInfo[] = [];
  @Local classicGames: GameInfo[] = [];
  @Local puzzleGames: GameInfo[] = [];
  @Local rankedGames: GameInfo[] = [];
  @Local isTablet: boolean = false;
  // 全部游戏按拼音排序（非 UI 状态）
  private allGamesPinyin: GameInfo[] = [];
  private mq: mediaquery.MediaQueryListener | null = null;

  private mqCallback = (result: mediaquery.MediaQueryResult): void => {
    this.isTablet = result.matches;
  };

  aboutToAppear(): void {
    this.loadData();
    this.startSplash();
    // 媒体查询：≥840vp 视为宽屏（平板），调整版式密度
    this.mq = this.getUIContext().getMediaQuery().matchMediaSync('(width >= 840vp)');
    this.mq.on('change', this.mqCallback);
  }

  aboutToDisappear(): void {
    if (this.mq) {
      this.mq.off('change', this.mqCallback);
      this.mq = null;
    }
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
    this.refreshCategoryGames();
  }

  // 中文按拼音排序（系统 Locale 习惯排序）
  sortByPinyin(list: GameInfo[]): GameInfo[] {
    const collator = new intl.Collator('zh-CN', { usage: 'sort', collation: 'pinyin' });
    const copy = list.slice();
    copy.sort((a: GameInfo, b: GameInfo) => collator.compare(a.name, b.name));
    return copy;
  }

  // 按当前分类与搜索词重新计算展示列表
  refreshCategoryGames(): void {
    let source: GameInfo[] = [];
    if (this.currentCategory === -1) { source = this.allGamesPinyin; }
    else if (this.currentCategory === 0) { source = this.classicGames; }
    else { source = this.puzzleGames; }
    const keyword = this.searchText.trim().toLowerCase();
    if (keyword.length === 0) {
      this.categoryGames = source;
      return;
    }
    const result: GameInfo[] = [];
    for (let i = 0; i < source.length; i++) {
      const g = source[i];
      if (g.name.toLowerCase().includes(keyword) || g.description.toLowerCase().includes(keyword)) {
        result.push(g);
      }
    }
    this.categoryGames = result;
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

  startSplash(): void {
    this.getUIContext().animateTo({
      duration: 600,
      curve: Curve.FastOutSlowIn
    }, () => {
      this.iconAnimOpacity = 1;
      this.iconAnimScale = 1;
      this.iconAnimTranslateY = 0;
    });
    setTimeout(() => {
      this.getUIContext().animateTo({
        duration: 400,
        curve: Curve.EaseOut
      }, () => {
        this.titleAnimOpacity = 1;
      });
      setTimeout(() => {
        this.getUIContext().animateTo({
          duration: 300,
          curve: Curve.EaseOut
        }, () => {
          this.subtitleAnimOpacity = 1;
        });
        setTimeout(() => {
          this.showSplash = false;
        }, 800);
      }, 300);
    }, 600);
  }

  @Builder
  PageMap(name: string) {
    if (name === 'SnakeGamePage') {
      NavDestination() {
        SnakeGamePage({ pathStack: this.pathStack })
      }
      .hideTitleBar(true)
    } else if (name === 'TetrisGamePage') {
      NavDestination() {
        TetrisGamePage({ pathStack: this.pathStack })
      }
      .hideTitleBar(true)
    } else if (name === 'Game2048Page') {
      NavDestination() {
        Game2048Page({ pathStack: this.pathStack })
      }
      .hideTitleBar(true)
    } else if (name === 'WhackMolePage') {
      NavDestination() {
        WhackMolePage({ pathStack: this.pathStack })
      }
      .hideTitleBar(true)
    } else if (name === 'MinesweeperPage') {
      NavDestination() {
        MinesweeperPage({ pathStack: this.pathStack })
      }
      .hideTitleBar(true)
    } else if (name === 'SudokuPage') {
      NavDestination() {
        SudokuPage({ pathStack: this.pathStack })
      }
      .hideTitleBar(true)
    } else if (name === 'SlidePuzzlePage') {
      NavDestination() {
        SlidePuzzlePage({ pathStack: this.pathStack })
      }
      .hideTitleBar(true)
    } else if (name === 'KlotskiPage') {
      NavDestination() {
        KlotskiPage({ pathStack: this.pathStack })
      }
      .hideTitleBar(true)
    } else if (name === 'GuessNumberPage') {
      NavDestination() {
        GuessNumberPage({ pathStack: this.pathStack })
      }
      .hideTitleBar(true)
    } else if (name === 'MemoryCardPage') {
      NavDestination() {
        MemoryCardPage({ pathStack: this.pathStack })
      }
      .hideTitleBar(true)
    } else if (name === 'ProfilePage') {
      NavDestination() {
        ProfilePage({ pathStack: this.pathStack })
      }
      .hideTitleBar(true)
    }
  }

  /**
   * 启动闪屏层。
   * 注意：这里的深空渐变、光晕与白色文字均为**品牌固定配色**（deepSpace 系），
   * 不随系统深浅色模式变化——闪屏是品牌展示页，两套主题下都应呈现同一张「宇宙蓝星空」。
   * 因此本方法内的 #16205F / #2A2B7E / rgba(...) / #FFFFFF 是刻意为之，请勿替换为语义色。
   */
  @Builder
  SplashLayer() {
    Stack() {
      Column()
        .width('100%').height('100%')
        .linearGradient({
          angle: 160,
          colors: [
            [BrandColors.deepSpace, 0],
            ['#16205F', 0.5],
            ['#2A2B7E', 1]
          ]
        })

      Circle({ width: 260, height: 260 })
        .fill('rgba(93, 134, 255, 0.25)')
        .blur(60)
        .position({ x: -80, y: -40 })
      Circle({ width: 220, height: 220 })
        .fill('rgba(122, 90, 248, 0.22)')
        .blur(60)
        .position({ x: '72%', y: '68%' })

      Column() {
        Column() {
          SymbolGlyph($r('sys.symbol.gamecontroller'))
            .fontSize(72)
            .fontWeight(FontWeight.Medium)
            .fontColor([BrandColors.cosmicBlueBright, BrandColors.auroraPurpleBright])
        }
        .width(152).height(152)
        .borderRadius(RadiusTokens.full)
        .backgroundColor('rgba(255, 255, 255, 0.10)')
        .border({ width: 1, color: 'rgba(255, 255, 255, 0.22)', radius: RadiusTokens.full })
        .backdropBlur(20)
        .shadow(ShadowTokens.float)
        .opacity(this.iconAnimOpacity)
        .scale({ x: this.iconAnimScale, y: this.iconAnimScale })
        .translate({ y: this.iconAnimTranslateY })

        Text('小游戏合集')
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeDisplay)
          .fontWeight(FontTokens.weightBold)
          .fontColor('#FFFFFF')
          .opacity(this.titleAnimOpacity)
          .margin({ top: 28 })

        Text('宇宙蓝 × 雪域灰 · 轻拟物设计')
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeBody)
          .fontColor('rgba(255, 255, 255, 0.72)')
          .opacity(this.subtitleAnimOpacity)
          .margin({ top: SpacingTokens.sm })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%').height('100%')
  }

  build() {
    Stack() {
      Navigation(this.pathStack) {
        Column() {
          this.TopBar()
      Tabs({ barPosition: BarPosition.End, index: this.currentTab }) {
        TabContent() { this.FeaturedTab() }
          .tabBar(this.TabBuilder(0, '精选'))
        TabContent() { this.CategoryTab() }
          .tabBar(this.TabBuilder(1, '分类'))
        TabContent() { this.ProfileTab() }
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
        this.SplashLayer()
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

  getCategorySymbol(index: number): Resource {
    if (index === -1) { return $r('sys.symbol.star_fill'); }
    if (index === 0) { return $r('sys.symbol.gamecontroller'); }
    return $r('sys.symbol.square_grid_2x2');
  }

  getCategoryTextColor(index: number): Resource {
    if (this.currentCategory === index) { return SemanticColors.textOnPrimary; }
    return SemanticColors.primary;
  }

  getCategoryWeight(index: number): number {
    if (this.currentCategory === index) { return FontTokens.weightMedium; }
    return FontTokens.weightRegular;
  }

  getCategoryBgColor(index: number): Resource {
    if (this.currentCategory === index) { return SemanticColors.primary; }
    return SemanticColors.primaryLight;
  }

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

  @Builder
  FeaturedTab() {
    Scroll() {
      Column() {
        this.Banner()
        Row() {
          Text('热门推荐')
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeBodyLarge)
            .fontWeight(FontTokens.weightSemibold)
            .fontColor(SemanticColors.textPrimary)
          Text('为你精选')
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeBodySmall)
            .fontColor(SemanticColors.textTertiary)
            .margin({ left: SpacingTokens.sm })
        }
        .width('100%')
        .padding({ left: SpacingTokens.pageHorizontal, top: SpacingTokens.lg, bottom: SpacingTokens.sm })

        GridRow({
          gutter: { x: SpacingTokens.base, y: SpacingTokens.base },
          columns: { sm: 4, md: 8, lg: 12 },
          breakpoints: { value: ['320vp', '600vp', '840vp'], reference: BreakpointsReference.WindowSize }
        }) {
          ForEach(this.featuredGames, (game: GameInfo) => {
            GridCol({ span: { sm: 2, md: 2, lg: 3 } }) {
              this.GameCard(game)
            }
          }, (game: GameInfo) => game.id)
        }
        .width('100%')
        .padding({
          left: SpacingTokens.pageHorizontal,
          right: SpacingTokens.pageHorizontal,
          bottom: SpacingTokens.xxl
        })
      }
      .width('100%')
    }
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  /** 横幅：背景为品牌渐变（gradientHero），故其上文字恒为白色，不随主题变化 */
  Banner() {
    Row() {
      Column() {
        Text('今天也要加油哦！')
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeSubtitle)
          .fontColor('#FFFFFF')
          .fontWeight(FontTokens.weightBold)
        Text('10 款精选小游戏等你来挑战')
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeBody)
          .fontColor('rgba(255, 255, 255, 0.78)')
          .margin({ top: SpacingTokens.xs })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      SymbolGlyph($r('sys.symbol.star_fill'))
        .fontSize(44)
        .fontWeight(FontWeight.Medium)
        .fontColor(['rgba(255, 255, 255, 0.95)', 'rgba(255, 255, 255, 0.45)'])
    }
    .width('100%')
    .padding({ left: SpacingTokens.lg, right: SpacingTokens.lg, top: SpacingTokens.base, bottom: SpacingTokens.base })
    .borderRadius(RadiusTokens.xl)
    .linearGradient({
      angle: 135,
      colors: [
        [BrandColors.cosmicBlue, 0],
        [BrandColors.auroraPurple, 1]
      ]
    })
    .shadow(ShadowTokens.float)
    .margin({
      left: SpacingTokens.pageHorizontal,
      right: SpacingTokens.pageHorizontal,
      top: SpacingTokens.base
    })
  }

  @Builder
  GameCard(game: GameInfo) {
    Column() {
      // 图标徽章
      Column() {
        Text(game.icon)
          .fontSize(30)
      }
      .width(54).height(54)
      .borderRadius(RadiusTokens.base)
      .backgroundColor(SemanticColors.primaryLight)
      .justifyContent(FlexAlign.Center)

      Text(game.name)
        .fontFamily(FontTokens.family)
        .fontSize(FontTokens.sizeBodyLarge)
        .fontWeight(FontTokens.weightMedium)
        .fontColor(SemanticColors.textPrimary)
        .margin({ top: SpacingTokens.sm })

      Text(game.description)
        .fontFamily(FontTokens.family)
        .fontSize(FontTokens.sizeBodySmall)
        .fontColor(SemanticColors.textTertiary)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: SpacingTokens.xs })
    }
    .width('100%')
    .padding(SpacingTokens.base)
    .borderRadius(RadiusTokens.lg)
    .backgroundColor(SemanticColors.surface)
    .shadow(ShadowTokens.card)
    .alignItems(HorizontalAlign.Start)
    .onClick(() => { this.navigateToGame(game); })
  }

  clearSearch(): void {
    this.searchText = '';
    this.refreshCategoryGames();
  }

  @Builder
  CategoryTab() {
    Column() {
      // 搜索栏
      Row({ space: SpacingTokens.sm }) {
        SymbolGlyph($r('sys.symbol.magnifyingglass'))
          .fontSize(18)
          .fontWeight(FontWeight.Regular)
          .fontColor([SemanticColors.textTertiary])
          .margin({ left: SpacingTokens.md })
        TextInput({ text: this.searchText, placeholder: '搜索游戏名称或描述' })
          .layoutWeight(1)
          .height(40)
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeBody)
          .fontColor(SemanticColors.textPrimary)
          .placeholderColor(SemanticColors.textTertiary)
          .placeholderFont({ size: FontTokens.sizeBody })
          .backgroundColor(Color.Transparent)
          .caretColor(SemanticColors.primary)
          .enterKeyType(EnterKeyType.Search)
          .onChange((value: string) => {
            this.searchText = value;
            this.refreshCategoryGames();
          })
        if (this.searchText.length > 0) {
          Button() {
            SymbolGlyph($r('sys.symbol.xmark_circle'))
              .fontSize(16)
              .fontColor([SemanticColors.textTertiary])
          }
          .type(ButtonType.Circle)
          .width(32).height(32)
          .backgroundColor(Color.Transparent)
          .onClick(() => this.clearSearch())
        }
      }
      .width('100%')
      .height(44)
      .padding({ right: SpacingTokens.xs })
      .margin({
        left: SpacingTokens.pageHorizontal,
        right: SpacingTokens.pageHorizontal,
        top: SpacingTokens.base
      })
      .backgroundColor(SemanticColors.surface)
      .borderRadius(RadiusTokens.full)
      .shadow(ShadowTokens.card)

      Row() {
        this.CategoryChip(-1, '全部')
        this.CategoryChip(0, '经典休闲')
        this.CategoryChip(1, '益智解谜')
      }
      .width('100%')
      .padding({ left: SpacingTokens.pageHorizontal, top: SpacingTokens.base })
      .justifyContent(FlexAlign.Start)

      Scroll() {
        Column() {
          this.CategoryGames(this.categoryGames)
          if (this.searchText.trim().length > 0 && this.categoryGames.length === 0) {
            Column({ space: SpacingTokens.sm }) {
              SymbolGlyph($r('sys.symbol.magnifyingglass'))
                .fontSize(44)
                .fontWeight(FontWeight.Regular)
                .fontColor([SemanticColors.textDisabled])
              Text('未找到「' + this.searchText.trim() + '」相关游戏')
                .fontFamily(FontTokens.family)
                .fontSize(FontTokens.sizeBodyLarge)
                .fontWeight(FontTokens.weightMedium)
                .fontColor(SemanticColors.textTertiary)
              Text('换个关键词试试，或看看其他分类')
                .fontFamily(FontTokens.family)
                .fontSize(FontTokens.sizeBodySmall)
                .fontColor(SemanticColors.textDisabled)
            }
            .width('100%')
            .padding({
              top: SpacingTokens.xxl,
              left: SpacingTokens.pageHorizontal,
              right: SpacingTokens.pageHorizontal
            })
            .alignItems(HorizontalAlign.Center)
          }
        }
        .width('100%')
        .padding({ bottom: SpacingTokens.xxl })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .align(Alignment.Top)
    }
    .width('100%').height('100%')
    .backgroundColor(SemanticColors.bg)
  }

  @Builder
  CategoryChip(index: number, title: string) {
    Row({ space: SpacingTokens.xs }) {
      SymbolGlyph(this.getCategorySymbol(index))
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor([this.getCategoryTextColor(index)])
      Text(title)
        .fontFamily(FontTokens.family)
        .fontSize(FontTokens.sizeBody)
        .fontWeight(this.getCategoryWeight(index))
        .fontColor(this.getCategoryTextColor(index))
    }
    .padding({ left: SpacingTokens.base, right: SpacingTokens.base, top: SpacingTokens.sm, bottom: SpacingTokens.sm })
    .borderRadius(RadiusTokens.full)
    .backgroundColor(this.getCategoryBgColor(index))
    .margin({ right: SpacingTokens.md })
    .onClick(() => {
      this.currentCategory = index;
      this.refreshCategoryGames();
    })
  }

  @Builder
  CategoryGames(games: GameInfo[]) {
    GridRow({
      gutter: { x: SpacingTokens.base, y: SpacingTokens.base },
      columns: { sm: 4, md: 8, lg: 12 },
      breakpoints: { value: ['320vp', '600vp', '840vp'], reference: BreakpointsReference.WindowSize }
    }) {
      ForEach(games, (game: GameInfo) => {
        GridCol({ span: { sm: 2, md: 2, lg: 3 } }) {
          this.GameCard(game)
        }
      }, (game: GameInfo) => game.id)
    }
    .width('100%')
    .padding({
      left: SpacingTokens.pageHorizontal,
      right: SpacingTokens.pageHorizontal,
      top: SpacingTokens.base
    })
  }

  @Builder
  ProfileTab() {
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
          this.StatsCard('游戏总数', '' + (this.classicGames.length + this.puzzleGames.length))
          this.StatsCard('已收录', '10')
          this.StatsCard('最高分', this.bestScore())
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

  allGames(): GameInfo[] {
    return GameDataManager.getAllGames();
  }

  bestScore(): string {
    const top: GameInfo[] = GameDataManager.getTopGames(1);
    if (top.length > 0 && top[0].highScore > 0) {
      return top[0].highScore.toString();
    }
    return '--';
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
