/**
 * 分类 Tab — 搜索 + 分类筛选 + 游戏栅格
 *
 * 原先是 Index.ets 内的 @Builder。抽出后它真正做到了自包含：
 * - 数据源（三个分类列表 + 拼音排序的全量）通过 @Param 传入
 * - 筛选条件（分类 / 搜索词）是它自己的 @Local
 * - 展示列表用 @Computed 从两者自动推导，不再需要手动 refreshCategoryGames()，
 *   也不会出现「改了筛选条件却忘了刷新列表」的错位
 * 点击通过 onGameClick 透出，不感知路由。
 */
import { SemanticColors, FontTokens, RadiusTokens, ShadowTokens, SpacingTokens } from '../../common/DesignTokens';
import { GameInfo } from '../../common/GameConstants';
import { GameCard } from '../../components/GameCard';

@ComponentV2
export struct CategoryTab {
  @Param classicGames: GameInfo[] = [];
  @Param puzzleGames: GameInfo[] = [];
  /** 全部游戏（已按拼音排序），「全部」分类使用 */
  @Param allGames: GameInfo[] = [];
  @Param onGameClick: (game: GameInfo) => void = () => {};
  // -1=全部 0=经典休闲 1=益智解谜
  @Local currentCategory: number = -1;
  @Local searchText: string = '';

  /** 当前分类 + 搜索词过滤后的展示列表，随状态自动重算 */
  @Computed
  get categoryGames(): GameInfo[] {
    let source: GameInfo[] = [];
    if (this.currentCategory === -1) {
      source = this.allGames;
    } else if (this.currentCategory === 0) {
      source = this.classicGames;
    } else {
      source = this.puzzleGames;
    }
    const keyword: string = this.searchText.trim().toLowerCase();
    if (keyword.length === 0) {
      return source;
    }
    const result: GameInfo[] = [];
    for (let i = 0; i < source.length; i++) {
      const g: GameInfo = source[i];
      if (g.name.toLowerCase().includes(keyword) || g.description.toLowerCase().includes(keyword)) {
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

  build() {
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
          .onClick(() => { this.searchText = ''; })
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
          GridRow({
            gutter: { x: SpacingTokens.base, y: SpacingTokens.base },
            columns: { sm: 4, md: 8, lg: 12 },
            breakpoints: { value: ['320vp', '600vp', '840vp'], reference: BreakpointsReference.WindowSize }
          }) {
            ForEach(this.categoryGames, (game: GameInfo) => {
              GridCol({ span: { sm: 2, md: 2, lg: 3 } }) {
                GameCard({ game: game, onTap: () => { this.onGameClick(game); } })
              }
            }, (game: GameInfo) => game.id)
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
    .onClick(() => { this.currentCategory = index; })
  }
}
