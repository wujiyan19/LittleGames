/**
 * 分类 Tab — 搜索 + 分类筛选 + 游戏栅格
 *
 * 原先是 Index.ets 内的 @Builder。抽出后它真正做到了自包含：
 * - 拼音排序的全量游戏通过 @Param 传入，六类筛选共用同一数据源
 * - 筛选条件（分类 / 搜索词）是它自己的 @Local
 * - 展示列表用 @Computed 从两者自动推导，不再需要手动 refreshCategoryGames()，
 *   也不会出现「改了筛选条件却忘了刷新列表」的错位
 * 点击通过 onGameClick 透出，不感知路由。
 */
import { SemanticColors, FontTokens, RadiusTokens, SpacingTokens } from '../../common/DesignTokens';
import { GameInfo, GameCategory, GAME_CATEGORIES, getCategoryLabel } from '../../common/GameConstants';
import { GameCard } from '../../components/GameCard';
import { HomeHeader } from '../../components/HomeHeader';
import { resolveString } from '../../common/I18nUtils';
import { HarmonyMotion } from '../../common/HarmonyMotion';

@ComponentV2
export struct CategoryTab {
  /** 全部游戏（已按拼音排序），「全部」分类使用 */
  @Param allGames: GameInfo[] = [];
  @Param onGameClick: (game: GameInfo) => void = () => {};
  @Param onSettingsClick: () => void = () => {};
  // -1 为全部，其余索引对应 GAME_CATEGORIES。
  @Local currentCategory: number = -1;
  @Local searchText: string = '';
  private categoryScroller: ListScroller = new ListScroller();
  private gameScroller: Scroller = new Scroller();

  /** 当前分类 + 搜索词过滤后的展示列表，随状态自动重算 */
  @Computed
  get categoryGames(): GameInfo[] {
    let source: GameInfo[] = [];
    if (this.currentCategory === -1) {
      source = this.allGames;
    } else {
      source = this.allGames.filter((game: GameInfo) => game.category === GAME_CATEGORIES[this.currentCategory]);
    }
    const keyword: string = this.searchText.trim().toLowerCase();
    if (keyword.length === 0) {
      return source;
    }
    const context = this.getUIContext().getHostContext();
    const result: GameInfo[] = [];
    for (let i = 0; i < source.length; i++) {
      const g: GameInfo = source[i];
      const nameStr = resolveString(g.name, context).toLowerCase();
      const descStr = resolveString(g.description, context).toLowerCase();
      if (nameStr.includes(keyword) || descStr.includes(keyword)) {
        result.push(g);
      }
    }
    return result;
  }

  getCategorySymbol(index: number): Resource {
    if (index === -1) { return $r('sys.symbol.star_fill'); }
    if (index === 0) { return $r('sys.symbol.gamecontroller'); }
    return $r('sys.symbol.square_grid_2x2');
  }

  getCategoryTextColor(index: number): Resource {
    if (this.currentCategory === index) { return SemanticColors.primary; }
    return SemanticColors.textSecondary;
  }

  getCategoryWeight(index: number): number {
    if (this.currentCategory === index) { return FontTokens.weightMedium; }
    return FontTokens.weightRegular;
  }

  getCategoryBgColor(index: number): Resource {
    if (this.currentCategory === index) { return SemanticColors.selectionSurface; }
    return SemanticColors.surface;
  }

  getSearchEmptyLabel(): string {
    const context = this.getUIContext().getHostContext();
    return resolveString($r('app.string.search_no_result_prefix'), context) + this.searchText.trim() +
      resolveString($r('app.string.search_no_result_suffix'), context);
  }

  changeSearch(value: string): void {
    if (this.searchText === value) { return; }
    this.searchText = value;
    this.gameScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false });
  }

  selectCategory(index: number): void {
    this.categoryScroller.scrollToIndex(index + 1, true, ScrollAlign.AUTO);
    if (this.currentCategory === index) { return; }
    this.currentCategory = index;
    this.gameScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false });
  }

  build() {
    Column() {
      HomeHeader({ title: $r('app.string.tab_category'), onSettingsClick: this.onSettingsClick })
      // 搜索栏
      Column() {
        Row({ space: SpacingTokens.sm }) {
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
          .fontSize($r('app.float.home_search_icon_size'))
          .fontWeight(FontWeight.Regular)
          .fontColor([SemanticColors.textTertiary])
          .margin({ left: SpacingTokens.md })
          TextInput({ text: this.searchText, placeholder: $r('app.string.search_placeholder') })
          .id('home_category_search')
          .layoutWeight(1)
          .height($r('app.float.home_search_height'))
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeBody)
          .fontColor(SemanticColors.textPrimary)
          .placeholderColor(SemanticColors.textTertiary)
          .placeholderFont({ size: FontTokens.sizeBody })
          .backgroundColor(Color.Transparent)
          .caretColor(SemanticColors.primary)
          .enterKeyType(EnterKeyType.Search)
          .onChange((value: string) => { this.changeSearch(value); })
          if (this.searchText.length > 0) {
            Button() {
              SymbolGlyph($r('sys.symbol.xmark_circle'))
              .fontSize(16)
              .fontColor([SemanticColors.textTertiary])
            }
            .type(ButtonType.Circle)
            .id('home_search_clear')
            .width($r('app.float.home_action_min_height'))
            .height($r('app.float.home_action_min_height'))
            .backgroundColor(Color.Transparent)
            .clickEffect(HarmonyMotion.press(this.getUIContext()))
            .accessibilityText($r('app.string.search_clear'))
            .onClick(() => { this.changeSearch(''); })
          }
        }
        .width('100%')
        .height($r('app.float.home_search_height'))
        .padding({ right: SpacingTokens.xs })
        .backgroundColor(SemanticColors.surface)
        .borderRadius(RadiusTokens.full)
      }
      .width('100%')
      .padding({
        left: SpacingTokens.pageHorizontal,
        right: SpacingTokens.pageHorizontal,
        top: SpacingTokens.sm
      })

      List({ space: SpacingTokens.sm, scroller: this.categoryScroller }) {
        ListItem() { this.CategoryChip(-1, $r('app.string.cat_all')) }
        ForEach(GAME_CATEGORIES, (category: GameCategory, index: number) => {
          ListItem() { this.CategoryChip(index, getCategoryLabel(category)) }
        }, (category: GameCategory) => category)
      }
      .width('100%')
      .id('home_category_filters')
      .height($r('app.float.home_filter_bar_height'))
      .listDirection(Axis.Horizontal)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .padding({ left: SpacingTokens.pageHorizontal, right: SpacingTokens.pageHorizontal,
        top: SpacingTokens.xs, bottom: SpacingTokens.xs })
      .margin({ top: SpacingTokens.md })

      Text($r('app.string.collection_count', this.categoryGames.length))
        .fontSize(FontTokens.sizeBodySmall).fontColor(SemanticColors.textSecondary)
        .width('100%').padding({ left: SpacingTokens.pageHorizontal, top: SpacingTokens.sm })

      Scroll(this.gameScroller) {
        Column() {
          GridRow({
            gutter: { x: $r('app.float.home_grid_gap_horizontal'), y: $r('app.float.home_grid_gap_vertical') },
            columns: { sm: 4, md: 8, lg: 12 },
            breakpoints: { value: ['320vp', '600vp', '840vp'], reference: BreakpointsReference.WindowSize }
          }) {
            ForEach(this.categoryGames, (game: GameInfo) => {
              GridCol({ span: { sm: 2, md: 2, lg: 3 } }) {
                GameCard({ game: game, onTap: () => { this.onGameClick(game); } })
              }
            }, (game: GameInfo) => game.id + '_' + game.playTimeMs.toString())
          }
          .width('100%')
          .padding({
            left: SpacingTokens.pageHorizontal,
            right: SpacingTokens.pageHorizontal,
            top: SpacingTokens.base
          })

          if (this.searchText.trim().length > 0 && this.categoryGames.length === 0) {
            Column({ space: SpacingTokens.sm }) {
              SymbolGlyph($r('sys.symbol.magnifyingglass'))
                .fontSize(44)
                .fontWeight(FontWeight.Regular)
                .fontColor([SemanticColors.textDisabled])
              Text(this.getSearchEmptyLabel())
                .fontFamily(FontTokens.family)
                .fontSize(FontTokens.sizeBodyLarge)
                .fontWeight(FontTokens.weightMedium)
                .fontColor(SemanticColors.textTertiary)
              Text($r('app.string.search_try_other'))
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
        .padding({ bottom: $r('app.float.home_tab_content_inset') })
      }
      .layoutWeight(1)
      .id('home_category_games')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .align(Alignment.Top)
    }
    .width('100%').height('100%')
    .backgroundColor(SemanticColors.bg)
  }

  @Builder
  CategoryChip(index: number, title: Resource | string) {
    Button() {
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
        .maxLines(1)
      Text((index === -1 ? this.allGames.length : this.allGames.filter((game: GameInfo) => game.category === GAME_CATEGORIES[index]).length).toString())
        .fontSize(FontTokens.sizeCaption).fontColor(this.getCategoryTextColor(index))
      }
    }
    .id(index === -1 ? 'category_filter_all' : 'category_filter_' + index.toString())
    .type(ButtonType.Normal)
    .constraintSize({ minHeight: $r('app.float.home_action_min_height') })
    .padding({ left: SpacingTokens.base, right: SpacingTokens.base, top: SpacingTokens.sm, bottom: SpacingTokens.sm })
    .borderRadius(RadiusTokens.full)
    .backgroundColor(this.getCategoryBgColor(index))
    .animation(HarmonyMotion.selection(this.getUIContext()))
    .clickEffect(HarmonyMotion.press(this.getUIContext()))
    .accessibilityDescription(this.currentCategory === index ? $r('app.string.settings_selected') : $r('app.string.settings_unselected'))
    .onClick(() => {
      // 仅筛选控件参与动效；两个滚动区域分别保持自己的位置。
      this.selectCategory(index);
    })
  }
}
