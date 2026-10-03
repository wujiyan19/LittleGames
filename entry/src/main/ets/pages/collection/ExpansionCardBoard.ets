import { ExpansionViewModel } from '../../viewmodel/ExpansionViewModel';
import { ExpansionPiece, ExpansionPile } from '../../model/game/ExpansionState';
import { POKER_IDS } from '../../model/game/ExpansionPoker';
import { CHESS_IDS } from '../../model/game/ExpansionChess';
import { SemanticColors, FontTokens, SpacingTokens, RadiusTokens } from '../../common/DesignTokens';
import { range } from '../../common/Range';
import { ExpansionArt } from '../../common/ExpansionArt';
import { GameArtTile } from '../../components/GameArtTile';

@ComponentV2
export struct ExpansionCardBoard {
  @Param gameId: string = '';
  @Param vm: ExpansionViewModel = new ExpansionViewModel();
  @Local arenaWidth: number = 320;
  color(player: number): Resource { return [$r('app.color.expansion_color_1'), $r('app.color.expansion_color_2'), $r('app.color.expansion_color_3'), $r('app.color.expansion_color_4')][player % 4]; }
  cardText(card: number): string {
    if (this.gameId === 'mahjong') {
      const type: number = Math.floor(card / 4); return type < 27 ? (type % 9 + 1).toString() + ['萬', '筒', '索'][Math.floor(type / 9)] : ['東', '南', '西', '北', '中', '發', '白'][type - 27];
    }
    if (this.gameId === 'spider' && this.vm.state.pieces[card].w === 0) { return '▧'; }
    const base: number = POKER_IDS.includes(this.gameId) ? card % 54 : card;
    if (base >= 52 && POKER_IDS.includes(this.gameId)) { return base === 52 ? '☆' : '★'; }
    return (this.gameId === 'spider' ? '♠' : ['♠', '♥', '♦', '♣'][Math.floor(base / 13)]) + ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'][base % 13];
  }
  cardColor(card: number): Resource {
    if (this.gameId === 'mahjong') { return Math.floor(card / 4) < 9 ? SemanticColors.error : Math.floor(card / 4) < 27 ? SemanticColors.primary : SemanticColors.textPrimary; }
    const suit: number = Math.floor((POKER_IDS.includes(this.gameId) ? card % 54 : card) / 13); return suit === 1 || suit === 2 ? SemanticColors.error : SemanticColors.textPrimary;
  }
  chessText(piece: number): string {
    if (piece === 0) { return ''; } const side: number = piece > 10 ? 2 : 1; const type: number = piece % 10;
    return this.gameId === 'chess' ? ['', '♚', '♛', '♜', '♝', '♞', '♟'][type] : (side === 1 ? ['', '帥', '仕', '相', '馬', '車', '炮', '兵'] : ['', '將', '士', '象', '馬', '車', '砲', '卒'])[type];
  }
  tableauHeight(): number { return Math.max(230, ...this.vm.state.piles.slice(0, this.gameId === 'spider' ? 10 : 8).map((pile: ExpansionPile) => pile.cards.length * 24 + 40)); }
  ludoPoint(token: ExpansionPiece): number[] {
    if (token.x < 0) { const side: number = token.owner; return [side === 0 || side === 3 ? 30 + token.id % 2 * 38 : 254 + token.id % 2 * 38, side < 2 ? 25 + Math.floor(token.id % 4 / 2) * 38 : 365 + Math.floor(token.id % 4 / 2) * 38]; }
    if (token.x >= 52) { const angle: number = token.owner * Math.PI / 2 - Math.PI / 2; const distance: number = (57 - token.x) * 17; return [165 + Math.cos(angle) * distance + token.id % 2 * 8, 215 + Math.sin(angle) * distance + Math.floor(token.id % 4 / 2) * 8]; }
    const angle: number = ((token.x + token.owner * 13) % 52) * Math.PI * 2 / 52 - Math.PI / 2; return [165 + Math.cos(angle) * 140, 215 + Math.sin(angle) * 175];
  }
  measure(area: Area): void { const width: number = Number(area.width); if (Number.isFinite(width) && width > 0) { this.arenaWidth = width; } }
  build() {
    Column({ space: SpacingTokens.base }) {
      if (CHESS_IDS.includes(this.gameId)) { this.Chess() }
      if (POKER_IDS.includes(this.gameId)) { this.Poker() }
      if (this.gameId === 'mahjong') { this.Mahjong() }
      if (this.gameId === 'ludo') { this.Ludo() }
      if (this.gameId === 'spider' || this.gameId === 'freecell') { this.Solitaire() }
    }.width('100%').padding(SpacingTokens.sm).backgroundImage(ExpansionArt.board(this.gameId)).backgroundImageSize({ width: '100%', height: '100%' }).borderRadius(RadiusTokens.base)
  }
  @Builder
  Card(card: number) {
    Column() {
      GameArtTile({ image: this.gameId === 'mahjong' ? $r('app.media.exp_mahjong') : this.gameId === 'spider' && this.vm.state.pieces[card].w === 0 ? $r('app.media.exp_card_back') : $r('app.media.exp_card_front'),
        label: this.gameId === 'spider' && this.vm.state.pieces[card].w === 0 ? '' : this.cardText(card), description: this.cardText(card), textColor: this.cardColor(card),
        selected: this.vm.state.selected === card || this.vm.state.tray.includes(card), onTap: () => { this.vm.tap(card); } })
    }.width(48).height(62)
  }
  @Builder
  Hand(cards: number[]) {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
      ForEach(cards, (card: number) => { Column() { this.Card(card) }.margin(SpacingTokens.xs) }, (card: number) => card.toString())
    }.width('100%')
  }
  @Builder
  Poker() {
    Column({ space: SpacingTokens.base }) {
      Row({ space: SpacingTokens.sm }) {
        ForEach(range(this.gameId === 'guandan' ? 3 : 2), (opponent: number) => {
          Text($r('app.string.expansion_hand_count', opponent + 2, this.vm.state.piles[opponent + 1].cards.length)).fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textSecondary).layoutWeight(1)
        }, (opponent: number) => opponent.toString())
      }.width('100%')
      Text(this.gameId === 'doudizhu' ? $r('app.string.expansion_landlord') : $r('app.string.expansion_guandan_team')).fontColor(SemanticColors.textSecondary)
      Text($r('app.string.expansion_last_play')).fontColor(SemanticColors.textSecondary)
      this.Hand(this.vm.state.piles[4].cards)
      this.Hand(this.vm.state.piles[0].cards)
      Row({ space: SpacingTokens.sm }) {
        Button($r('app.string.expansion_hint')).layoutWeight(1).onClick(() => { this.vm.tap(902); })
        Button($r('app.string.expansion_pass')).layoutWeight(1).enabled(this.vm.state.data[2] !== 0).onClick(() => { this.vm.tap(901); })
        Button($r('app.string.expansion_play_cards')).layoutWeight(1).onClick(() => { this.vm.tap(900); })
      }.width('100%')
    }.width('100%')
  }
  @Builder
  Chess() {
    Column({ space: SpacingTokens.sm }) {
      Text($r('app.string.expansion_board_opponent')).fontColor(SemanticColors.textSecondary)
      Column({ space: 1 }) {
        ForEach(range(this.vm.state.rows), (row: number) => {
          Row({ space: 1 }) {
            ForEach(range(this.vm.state.cols), (col: number) => {
              Column() {
                GameArtTile({ image: this.vm.state.board[row * this.vm.state.cols + col] === 0 ? $r('app.media.exp_empty') : this.gameId === 'chess' ? ExpansionArt.chess(this.vm.state.board[row * this.vm.state.cols + col]) : $r('app.media.exp_chip'),
                  label: this.gameId === 'xiangqi' ? this.chessText(this.vm.state.board[row * this.vm.state.cols + col]) : '',
                  textColor: this.vm.state.board[row * this.vm.state.cols + col] > 10 ? SemanticColors.textPrimary : SemanticColors.error,
                  selected: this.vm.state.selected === row * this.vm.state.cols + col,
                  description: $r('app.string.expansion_cell', row + 1, col + 1, this.chessText(this.vm.state.board[row * this.vm.state.cols + col])),
                  onTap: () => { this.vm.tap(row * this.vm.state.cols + col); } })
              }.layoutWeight(1).height('100%').padding(0)
                .backgroundColor(this.vm.legalTargets.includes(row * this.vm.state.cols + col) ? SemanticColors.primaryLight : (row + col) % 2 === 0 ? SemanticColors.surface : SemanticColors.boardBg)
                .border({ width: this.vm.state.selected === row * this.vm.state.cols + col ? 2 : 0, color: SemanticColors.primary })
                .accessibilityText($r('app.string.expansion_cell', row + 1, col + 1, this.chessText(this.vm.state.board[row * this.vm.state.cols + col])))
            }, (col: number) => col.toString())
          }.width('100%').layoutWeight(1)
        }, (row: number) => row.toString())
      }.width('100%').aspectRatio(this.vm.state.cols / this.vm.state.rows).padding(SpacingTokens.xs).backgroundColor(SemanticColors.border).borderRadius(RadiusTokens.sm)
      if (this.gameId === 'chess') {
        Text($r('app.string.expansion_promotion')).fontColor(SemanticColors.textSecondary)
        Row({ space: SpacingTokens.sm }) {
          ForEach(range(4), (choice: number) => {
            Column() { GameArtTile({ image: ExpansionArt.chess(choice + 2), description: ['♛', '♜', '♝', '♞'][choice], selected: this.vm.state.data[9] === choice + 2,
              onTap: () => { this.vm.choose(choice); } }) }.layoutWeight(1).height(52)
          }, (choice: number) => choice.toString())
        }.width('100%')
      }
    }.width('100%')
  }
  @Builder
  Mahjong() {
    Column({ space: SpacingTokens.base }) {
      Text($r('app.string.expansion_wall', 136 - this.vm.state.cursor)).fontColor(SemanticColors.textSecondary)
      Row({ space: SpacingTokens.sm }) {
        ForEach(range(3), (seat: number) => { Text($r('app.string.expansion_hand_count', seat + 2, this.vm.state.piles[seat + 1].cards.length)).fontColor(SemanticColors.textSecondary).fontSize(FontTokens.sizeCaption) }, (seat: number) => seat.toString())
      }.width('100%')
      if (this.vm.state.piles[8].cards.length > 0) { Text($r('app.string.expansion_discard', this.cardText(this.vm.state.piles[8].cards[this.vm.state.piles[8].cards.length - 1]))).fontColor(SemanticColors.textPrimary) }
      this.Hand(this.vm.state.piles[0].cards)
      if (this.vm.state.piles[4].cards.length > 0) { this.Hand(this.vm.state.piles[4].cards) }
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
        Button($r('app.string.expansion_mahjong_win')).margin(SpacingTokens.xs).enabled(this.vm.mahjongCan(900)).onClick(() => { this.vm.tap(900); })
        if (this.vm.state.data[0] === 1) {
          Button($r('app.string.expansion_pong')).margin(SpacingTokens.xs).enabled(this.vm.mahjongCan(901)).onClick(() => { this.vm.tap(901); })
          ForEach(range(3), (choice: number) => {
            Button($r('app.string.expansion_chi', choice + 1)).margin(SpacingTokens.xs).enabled(this.vm.mahjongCan(902 + choice)).onClick(() => { this.vm.tap(902 + choice); })
          }, (choice: number) => choice.toString())
          Button($r('app.string.expansion_kong')).margin(SpacingTokens.xs).enabled(this.vm.mahjongCan(905)).onClick(() => { this.vm.tap(905); })
          Button($r('app.string.expansion_pass')).margin(SpacingTokens.xs).onClick(() => { this.vm.tap(907); })
        } else { Button($r('app.string.expansion_closed_kong')).margin(SpacingTokens.xs).onClick(() => { this.vm.tap(906); }) }
      }.width('100%')
    }.width('100%')
  }
  @Builder
  Ludo() {
    Column({ space: SpacingTokens.base }) {
      Text($r('app.string.expansion_die', this.vm.state.data[0])).fontColor(SemanticColors.textPrimary)
      Stack({ alignContent: Alignment.TopStart }) {
        ForEach(range(52), (step: number) => {
          Text('·').width(8).height(8).fontColor(SemanticColors.border)
            .translate({ x: (180 + Math.cos(step * Math.PI * 2 / 52 - Math.PI / 2) * 140) * this.arenaWidth / 360,
              y: (230 + Math.sin(step * Math.PI * 2 / 52 - Math.PI / 2) * 175) * this.arenaWidth / 360 })
        }, (step: number) => step.toString())
        ForEach(this.vm.state.pieces, (token: ExpansionPiece) => {
          Column() { GameArtTile({ image: $r('app.media.exp_plane'), label: (token.id % 4 + 1).toString(),
            description: $r('app.string.art_ludo_token', token.owner + 1, token.id % 4 + 1), onTap: () => { this.vm.tap(token.id); } }) }
            .width(30 * this.arenaWidth / 360).height(30 * this.arenaWidth / 360).backgroundColor(this.color(token.owner)).borderRadius(RadiusTokens.sm)
            .translate({ x: this.ludoPoint(token)[0] * this.arenaWidth / 360, y: this.ludoPoint(token)[1] * this.arenaWidth / 360 })
        }, (token: ExpansionPiece) => token.id.toString())
      }.width('100%').aspectRatio(360 / 460).backgroundColor(SemanticColors.boardBg).backgroundImage(ExpansionArt.board(this.gameId)).backgroundImageSize({ width: '100%', height: '100%' }).borderRadius(RadiusTokens.base)
        .onAreaChange((oldArea: Area, area: Area) => { this.measure(area); })
      Button($r('app.string.expansion_roll')).enabled(this.vm.state.data[0] === 0).onClick(() => { this.vm.tap(900); })
    }.width('100%')
  }
  @Builder
  Solitaire() {
    Column({ space: SpacingTokens.base }) {
      if (this.gameId === 'spider') { Button($r('app.string.expansion_stock', this.vm.state.piles[10].cards.length)).onClick(() => { this.vm.tap(900); }) }
      else {
        Row({ space: SpacingTokens.xs }) {
          ForEach(range(8), (slot: number) => {
            Button(this.vm.state.piles[8 + slot].cards.length > 0 ? this.cardText(this.vm.state.piles[8 + slot].cards[this.vm.state.piles[8 + slot].cards.length - 1]) : slot < 4 ? '○' : ['♠', '♥', '♦', '♣'][slot - 4], { type: ButtonType.Normal })
              .layoutWeight(1).height(48).padding(0).fontColor(SemanticColors.textPrimary).backgroundColor(SemanticColors.surface)
              .onClick(() => { if (this.vm.state.selected >= 0) { this.vm.tap(208 + slot); } else if (slot < 4 && this.vm.state.piles[8 + slot].cards.length > 0) { this.vm.tap(this.vm.state.piles[8 + slot].cards[0]); } })
          }, (slot: number) => slot.toString())
        }.width('100%')
        Button($r('app.string.expansion_foundation')).onClick(() => { this.vm.tap(900); })
      }
      Scroll() {
        Row({ space: SpacingTokens.xs }) {
          ForEach(range(this.gameId === 'spider' ? 10 : 8), (col: number) => {
            Stack({ alignContent: Alignment.TopStart }) {
              Button('○', { type: ButtonType.Normal }).width(48).height(62).backgroundColor(SemanticColors.primaryLight).onClick(() => { this.vm.tap(200 + col); })
              ForEach(this.vm.state.piles[col].cards, (card: number, pos: number) => { Column() { this.Card(card) }.translate({ y: pos * 24 }) }, (card: number) => card.toString())
            }.width(48).height(this.tableauHeight())
          }, (col: number) => col.toString())
        }
      }.width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
    }.width('100%')
  }
}
