/**
 * 主页 — 宇宙蓝 × 雪域灰
 * 使用 GridRow 断点布局 + 媒体查询适配不同屏幕
 */
import { mediaquery } from '@kit.ArkUI';
import { intl } from '@kit.LocalizationKit';
import { GameDataManager } from '../model/GameData';
import { GameInfo, GameCategory } from '../common/GameConstants';
import {
  LightColors,
  DarkColors,
  SpacingTokens,
  FontTokens,
  RadiusTokens,
  ShadowTokens,
  BrandColors
} from '../common/DesignTokens';

@Entry
@ComponentV2
struct Index {
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
    let route = '';
    if (game.id === 'snake') { route = 'pages/classic/SnakeGamePage'; }
    else if (game.id === 'tetris') { route = 'pages/classic/TetrisGamePage'; }
    else if (game.id === '2048') { route = 'pages/classic/Game2048Page'; }
    else if (game.id === 'whackmole') { route = 'pages/classic/WhackMolePage'; }
    else if (game.id === 'minesweeper') { route = 'pages/classic/MinesweeperPage'; }
    else if (game.id === 'sudoku') { route = 'pages/puzzle/SudokuPage'; }
    else if (game.id === 'slidepuzzle') { route = 'pages/puzzle/SlidePuzzlePage'; }
    else if (game.id === 'klotski') { route = 'pages/puzzle/KlotskiPage'; }
    else if (game.id === 'guessnumber') { route = 'pages/puzzle/GuessNumberPage'; }
    else { route = 'pages/puzzle/MemoryCardPage'; }
    this.getUIContext().getRouter().pushUrl({ url: route });
  }

  build() {
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
      .barBackgroundColor(DarkColors.surfaceTranslucent)
      .barBackgroundBlurStyle(BlurStyle.Thin)
      .onChange((index: number) => { this.currentTab = index; })
      .layoutWeight(1)
    }
    .width('100%').height('100%')
    .backgroundColor(LightColors.bg)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

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
    if (this.currentTab === index) { return LightColors.primary; }
    return LightColors.textTertiary;
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
    if (this.currentCategory === index) { return LightColors.textOnPrimary; }
    return LightColors.primary;
  }

  getCategoryWeight(index: number): number {
    if (this.currentCategory === index) { return FontTokens.weightMedium; }
    return FontTokens.weightRegular;
  }

  getCategoryBgColor(index: number): Resource {
    if (this.currentCategory === index) { return LightColors.primary; }
    return DarkColors.primaryLight;
  }

  getRankColor(index: number): Resource {
    if (index < 3) { return DarkColors.warning; }
    return LightColors.textTertiary;
  }

  getHighScoreText(game: GameInfo): string {
    if (game.highScore > 0) { return '' + game.highScore; }
    return '--';
  }

  getHighScoreColor(game: GameInfo): Resource {
    if (game.highScore > 0) { return LightColors.primary; }
    return LightColors.textDisabled;
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
            .fontColor(LightColors.textPrimary)
          Text('为你精选')
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeBodySmall)
            .fontColor(LightColors.textTertiary)
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
      .backgroundColor(DarkColors.primaryLight)
      .justifyContent(FlexAlign.Center)

      Text(game.name)
        .fontFamily(FontTokens.family)
        .fontSize(FontTokens.sizeBodyLarge)
        .fontWeight(FontTokens.weightMedium)
        .fontColor(LightColors.textPrimary)
        .margin({ top: SpacingTokens.sm })

      Text(game.description)
        .fontFamily(FontTokens.family)
        .fontSize(FontTokens.sizeBodySmall)
        .fontColor(LightColors.textTertiary)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: SpacingTokens.xs })
    }
    .width('100%')
    .padding(SpacingTokens.base)
    .borderRadius(RadiusTokens.lg)
    .backgroundColor(LightColors.surface)
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
          .fontColor([LightColors.textTertiary])
          .margin({ left: SpacingTokens.md })
        TextInput({ text: this.searchText, placeholder: '搜索游戏名称或描述' })
          .layoutWeight(1)
          .height(40)
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeBody)
          .fontColor(LightColors.textPrimary)
          .placeholderColor(LightColors.textTertiary)
          .placeholderFont({ size: FontTokens.sizeBody })
          .backgroundColor(Color.Transparent)
          .caretColor(LightColors.primary)
          .enterKeyType(EnterKeyType.Search)
          .onChange((value: string) => {
            this.searchText = value;
            this.refreshCategoryGames();
          })
        if (this.searchText.length > 0) {
          Button() {
            SymbolGlyph($r('sys.symbol.xmark_circle'))
              .fontSize(16)
              .fontColor([LightColors.textTertiary])
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
      .backgroundColor(LightColors.surface)
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
                .fontColor([LightColors.textDisabled])
              Text('未找到「' + this.searchText.trim() + '」相关游戏')
                .fontFamily(FontTokens.family)
                .fontSize(FontTokens.sizeBodyLarge)
                .fontWeight(FontTokens.weightMedium)
                .fontColor(LightColors.textTertiary)
              Text('换个关键词试试，或看看其他分类')
                .fontFamily(FontTokens.family)
                .fontSize(FontTokens.sizeBodySmall)
                .fontColor(LightColors.textDisabled)
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
    .backgroundColor(LightColors.bg)
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
              .fontColor(LightColors.textPrimary)
            Text('享受游戏的乐趣！')
              .fontFamily(FontTokens.family)
              .fontSize(FontTokens.sizeBodySmall)
              .fontColor(LightColors.textTertiary)
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .margin({ left: SpacingTokens.base })
        }
        .width('100%')
        .padding(SpacingTokens.base)
        .borderRadius(RadiusTokens.lg)
        .backgroundColor(LightColors.surface)
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
            .fontColor([DarkColors.warning])
          Text('最高分排行')
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeBodyLarge)
            .fontWeight(FontTokens.weightSemibold)
            .fontColor(LightColors.textPrimary)
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
                    .fontColor(LightColors.textPrimary)
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
        .backgroundColor(LightColors.surface)
        .borderRadius(RadiusTokens.lg)
        .margin({ left: SpacingTokens.pageHorizontal, right: SpacingTokens.pageHorizontal })
        .height(312)
      }
      .width('100%')
      .padding({ bottom: SpacingTokens.xxl })
    }
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor(LightColors.bg)
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
        .fontColor(LightColors.textPrimary)
      Text(title)
        .fontFamily(FontTokens.family)
        .fontSize(FontTokens.sizeBodySmall)
        .fontColor(LightColors.textTertiary)
        .margin({ top: SpacingTokens.xs })
    }
    .layoutWeight(1)
    .padding({ top: SpacingTokens.base, bottom: SpacingTokens.base })
    .borderRadius(RadiusTokens.base)
    .backgroundColor(LightColors.surface)
    .shadow(ShadowTokens.card)
  }
}
