import { ExpansionViewModel } from '../../viewmodel/ExpansionViewModel';
import { ExpansionPiece, ExpansionPile } from '../../model/game/ExpansionState';
import { CHARACTER_PARTS, CHARACTER_RECIPES } from '../../model/game/ExpansionTable';
import { SemanticColors, FontTokens, SpacingTokens, RadiusTokens } from '../../common/DesignTokens';
import { range } from '../../common/Range';
import { ExpansionArt } from '../../common/ExpansionArt';

@ComponentV2
export struct ExpansionExtras {
  @Param gameId: string = '';
  @Param vm: ExpansionViewModel = new ExpansionViewModel();
  cardText(card: number): string {
    if (this.vm.state.pieces[card].w === 0) { return '▧'; }
    const rank: number = card % 13; return ['♠', '♥', '♦', '♣'][Math.floor(card / 13)] + ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'][rank];
  }
  cardColor(card: number): Resource { const suit: number = Math.floor(card / 13); return suit === 1 || suit === 2 ? SemanticColors.error : SemanticColors.textPrimary; }
  top(pile: number): number { const cards: number[] = this.vm.state.piles[pile].cards; return cards.length > 0 ? cards[cards.length - 1] : -1; }
  tableauHeight(): number { return Math.max(200, ...this.vm.state.piles.slice(2, 9).map((p: ExpansionPile) => p.cards.length * 24 + 36)); }
  food(index: number): Resource { return index === 0 ? $r('app.string.expansion_food_0') : index === 1 ? $r('app.string.expansion_food_1') : $r('app.string.expansion_food_2'); }
  build() {
    Column({ space: SpacingTokens.base }) {
      if (this.gameId === 'solitaire') { this.Solitaire() }
      if (this.gameId === 'characters') { this.Characters() }
      if (this.gameId === 'restaurant') { this.Restaurant() }
      if (this.gameId === 'roomdefense') {
        Text($r('app.string.expansion_coins', this.vm.state.data[0], this.vm.state.data[1])).fontColor(SemanticColors.textPrimary)
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
          ForEach(range(6), (slot: number) => {
            Button($r('app.string.expansion_tower', slot + 1)).width('47%').margin(SpacingTokens.xs)
              .onClick(() => { this.vm.tap(slot); })
          }, (slot: number) => slot.toString())
        }.width('100%')
        Button($r('app.string.expansion_repair')).onClick(() => { this.vm.tap(6); })
      }
      if (this.gameId === 'rhythm') {
        Row({ space: SpacingTokens.xs }) {
          ForEach(range(4), (lane: number) => {
            Button($r('app.string.expansion_key', lane + 1)).layoutWeight(1).height($r('app.float.expansion_control_height'))
              .onClick(() => { this.vm.tap(lane); })
          }, (lane: number) => lane.toString())
        }.width('100%')
      }
    }.width('100%').padding(SpacingTokens.sm).backgroundImage(ExpansionArt.board(this.gameId)).backgroundImageSize({ width: '100%', height: '100%' }).borderRadius(RadiusTokens.base)
  }
  @Builder
  Card(card: number) {
    Button(this.cardText(card), { type: ButtonType.Normal }).width('100%').height(36).padding(0)
      .backgroundImage(this.vm.state.pieces[card].w === 0 ? $r('app.media.exp_card_back') : $r('app.media.exp_card_front')).backgroundImageSize(ImageSize.Cover)
      .fontSize(FontTokens.sizeBody).fontColor(this.cardColor(card)).backgroundColor(SemanticColors.surface)
      .borderRadius(RadiusTokens.xs).border({ width: this.vm.state.selected === card ? 2 : 1, color: this.vm.state.selected === card ? SemanticColors.primary : SemanticColors.border })
      .onClick(() => { this.vm.tap(card); })
  }
  @Builder
  Solitaire() {
    Column({ space: SpacingTokens.base }) {
      Row({ space: SpacingTokens.sm }) {
        Button($r('app.string.expansion_stock', this.vm.state.piles[0].cards.length)).layoutWeight(1).onClick(() => { this.vm.tap(100); })
        Column() { if (this.top(1) >= 0) { this.Card(this.top(1)) } else { Text('○').fontColor(SemanticColors.textSecondary) } }.layoutWeight(1)
        Button($r('app.string.expansion_foundation')).layoutWeight(1).onClick(() => { this.vm.tap(101); })
      }.width('100%')
      Row({ space: SpacingTokens.sm }) {
        ForEach(range(4), (suit: number) => {
          Button(this.top(9 + suit) >= 0 ? this.cardText(this.top(9 + suit)) : ['♠', '♥', '♦', '♣'][suit], { type: ButtonType.Normal })
            .layoutWeight(1).height(44).fontColor(suit === 1 || suit === 2 ? SemanticColors.error : SemanticColors.textPrimary)
            .backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.sm).onClick(() => { this.vm.tap(109 + suit); })
        }, (suit: number) => suit.toString())
      }.width('100%')
      Row({ space: SpacingTokens.xs }) {
        ForEach(range(7), (col: number) => {
          Stack({ alignContent: Alignment.TopStart }) {
            Button('K', { type: ButtonType.Normal }).width('100%').height(36).padding(0).backgroundColor(SemanticColors.primaryLight)
              .fontColor(SemanticColors.textSecondary).borderRadius(RadiusTokens.xs).onClick(() => { this.vm.tap(102 + col); })
            ForEach(this.vm.state.piles[2 + col].cards, (card: number, pos: number) => {
              Column() { this.Card(card) }.width('100%').translate({ y: pos * 24 })
            }, (card: number) => card.toString())
          }.layoutWeight(1).height(this.tableauHeight())
        }, (col: number) => col.toString())
      }.width('100%')
    }.width('100%')
  }
  @Builder
  Characters() {
    Column({ space: SpacingTokens.base }) {
      Text($r('app.string.expansion_character', CHARACTER_RECIPES[this.vm.state.cursor].result)).fontSize(FontTokens.sizeTitle).fontColor(SemanticColors.textPrimary)
      Text(this.vm.state.tray.map((part: number) => CHARACTER_PARTS[part]).join(' + ')).height(48).fontSize(FontTokens.sizeTitle).fontColor(SemanticColors.primary)
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
        ForEach(this.vm.state.board, (part: number, option: number) => {
          Button(CHARACTER_PARTS[part]).width('29%').height(64).margin(SpacingTokens.xs).fontSize(FontTokens.sizeTitle)
            .onClick(() => { this.vm.tap(option); })
        }, (part: number) => part.toString())
      }.width('100%')
      Row({ space: SpacingTokens.sm }) {
        Button($r('app.string.expansion_clear')).layoutWeight(1).onClick(() => { this.vm.tap(100); })
        Button($r('app.string.expansion_check')).layoutWeight(1).onClick(() => { this.vm.action(); })
      }.width('100%')
    }.width('100%')
  }
  @Builder
  Restaurant() {
    Column({ space: SpacingTokens.base }) {
      Text($r('app.string.expansion_money', this.vm.state.data[0])).fontColor(SemanticColors.textPrimary)
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
        ForEach(this.vm.state.pieces.filter((p: ExpansionPiece) => p.kind === 19), (p: ExpansionPiece) => {
          Button({ type: ButtonType.Normal }) {
            Column({ space: SpacingTokens.sm }) {
              Image(ExpansionArt.person(p.id % 6)).width(52).height(52).objectFit(ImageFit.Contain).accessibilityLevel('no')
              Image(ExpansionArt.food(p.color)).width(32).height(32).objectFit(ImageFit.Contain).accessibilityLevel('no')
              Text(this.food(p.color)).fontColor(SemanticColors.textPrimary)
              Text($r('app.string.expansion_customer', p.id, Math.ceil(p.age))).fontSize(FontTokens.sizeCaption).fontColor(p.age < 8 ? SemanticColors.warning : SemanticColors.textSecondary)
            }.padding(SpacingTokens.sm)
          }.width('47%').margin(SpacingTokens.xs).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base)
            .onClick(() => { this.vm.tap(100 + p.id); })
        }, (p: ExpansionPiece) => p.id.toString())
      }.width('100%')
      Row({ space: SpacingTokens.sm }) {
        ForEach(range(3), (food: number) => {
          Button({ type: ButtonType.Normal }) {
            Column({ space: SpacingTokens.sm }) {
              Image(ExpansionArt.food(food)).width(48).height(48).objectFit(ImageFit.Contain).accessibilityLevel('no')
              Text(this.food(food)).fontColor(SemanticColors.textPrimary)
              Text($r('app.string.expansion_food_stock', this.vm.state.board[food])).fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textSecondary)
              if (this.vm.state.pieces.some((p: ExpansionPiece) => p.kind === 20 && p.color === food)) { Text($r('app.string.expansion_cooking')).fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.primary) }
            }.padding(SpacingTokens.sm)
          }.layoutWeight(1).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base).onClick(() => { this.vm.tap(food); })
        }, (food: number) => food.toString())
      }.width('100%')
    }.width('100%')
  }
}
