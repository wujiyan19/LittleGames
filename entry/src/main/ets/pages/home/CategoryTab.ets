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
import { resolveString } from '../../common/I18nUtils';

@ComponentV2
export struct CategoryTab {
  /** 全部游戏（已按拼音排序），「全部」分类使用 */
  @Param allGames: GameInfo[] = [];
  @Param onGameClick: (game: GameInfo) => void = () => {};
  // -1 为全部，其余索引对应 GAME_CATEGORIES。
  @Local currentCategory: number = -1;
  @Local searchText: string = '';

  @Styles
  pressedFeedback() {
    .opacity(0.72)
    .scale({ x: 0.96, y: 0.96 })
  }

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
    if (this.currentCategory === index) { return SemanticColors.textOnPrimary; }
    return SemanticColors.textPrimary;
  }

  getCategoryWeight(index: number): number {
    if (this.currentCategory === index) { return FontTokens.weightMedium; }
    return FontTokens.weightRegular;
  }

  getCategoryBgColor(index: number): Resource {
    if (this.currentCategory === index) { return SemanticColors.primary; }
    return SemanticColors.surface;
  }

  getSearchEmptyLabel(): string {
    const context = this.getUIContext().getHostContext();
    return resolveString($r('app.string.search_no_result_prefix'), context) + this.searchText.trim() +
      resolveString($r('app.string.search_no_result_suffix'), context);
  }

  build() {
    Column() {
      // 搜索栏
      Column() {
        Row({ space: SpacingTokens.sm }) {
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
          .fontSize(18)
          .fontWeight(FontWeight.Regular)
          .fontColor([SemanticColors.textTertiary])
          .margin({ left: SpacingTokens.md })
          TextInput({ text: this.searchText, placeholder: $r('app.string.search_placeholder') })
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
          .onChange((value: string) => { this.searchText = value; })
          if (this.searchText.length > 0) {
            Button() {
              SymbolGlyph($r('sys.symbol.xmark_circle'))
              .fontSize(16)
              .fontColor([SemanticColors.textTertiary])
            }
            .type(ButtonType.Circle)
            .width(32).height(32)
            .backgroundColor(Color.Transparent)
            .stateStyles({ pressed: this.pressedFeedback })
            .onClick(() => { this.searchText = ''; })
          }
        }
        .width('100%')
        .height(44)
        .padding({ right: SpacingTokens.xs })
        .backgroundColor(SemanticColors.surface)
        .borderRadius(RadiusTokens.full)
      }
      .width('100%')
      .padding({
        left: SpacingTokens.pageHorizontal,
        right: SpacingTokens.pageHorizontal,
        top: SpacingTokens.base
      })

      Flex({ wrap: FlexWrap.Wrap }) {
        this.CategoryChip(-1, $r('app.string.cat_all'))
        ForEach(GAME_CATEGORIES, (category: GameCategory, index: number) => {
          this.CategoryChip(index, getCategoryLabel(category))
        }, (category: GameCategory) => category)
      }
      .width('100%')
      .padding({ left: SpacingTokens.pageHorizontal, top: SpacingTokens.base })

      Text($r('app.string.collection_count', this.categoryGames.length))
        .fontSize(FontTokens.sizeBodySmall).fontColor(SemanticColors.textSecondary)
        .width('100%').padding({ left: SpacingTokens.pageHorizontal, top: SpacingTokens.xs })

      Scroll() {
        Column() {
          GridRow({
            gutter: { x: SpacingTokens.base, y: SpacingTokens.base },
            columns: { sm: 4, md: 8, lg: 12 },
            breakpoints: { value: ['320vp', '600vp', '840vp'], reference: BreakpointsReference.WindowSize }
          }) {
            ForEach(this.categoryGames, (game: GameInfo) => {
              GridCol({ span: { sm: 2, md: 2, lg: 3 } }) {
                GameCard({ game: game, onTap: () => { this.onGameClick(game); } })
              }
            }, (game: GameInfo) => game.id + '_' + game.playCount.toString())
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
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .align(Alignment.Top)
    }
    .width('100%').height('100%')
    .backgroundColor(SemanticColors.bg)
  }

  @Builder
  CategoryChip(index: number, title: Resource | string) {
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
      Text((index === -1 ? this.allGames.length : this.allGames.filter((game: GameInfo) => game.category === GAME_CATEGORIES[index]).length).toString())
        .fontSize(FontTokens.sizeCaption).fontColor(this.getCategoryTextColor(index))
    }
    .padding({ left: SpacingTokens.base, right: SpacingTokens.base, top: SpacingTokens.sm, bottom: SpacingTokens.sm })
    .borderRadius(RadiusTokens.full)
    .backgroundColor(this.getCategoryBgColor(index))
    .margin({ right: SpacingTokens.sm, bottom: SpacingTokens.sm })
    .scale({ x: this.currentCategory === index ? 1.05 : 1.0, y: this.currentCategory === index ? 1.05 : 1.0 })
    .animation({ duration: 200, curve: Curve.FastOutSlowIn })
    .stateStyles({ pressed: this.pressedFeedback })
    .onClick(() => {
      this.getUIContext().animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => {
        this.currentCategory = index;
      });
    })
  }
}
