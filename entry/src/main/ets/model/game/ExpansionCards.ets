import { ExpansionState, ExpansionPiece, ExpansionPile } from './ExpansionState';
import { RandomSource } from './RandomSource';
import { ContinuationValidation as V } from '../../common/GameSessionTransfer';

export const CARD_IDS: string[] = ['mahjong', 'ludo', 'spider', 'freecell'];
export class ExpansionCards {
  private random: RandomSource;
  constructor(random: RandomSource) { this.random = random; }
  private pick(n: number): number { return Math.min(n - 1, Math.max(0, Math.floor(this.random.next() * n))); }
  private deck(n: number): number[] {
    const deck: number[] = new Array<number>(n).fill(0).map((v: number, i: number) => i);
    for (let i: number = n - 1; i > 0; i--) { const j: number = this.pick(i + 1); const temp: number = deck[i]; deck[i] = deck[j]; deck[j] = temp; } return deck;
  }
  private piles(s: ExpansionState, n: number): void { for (let i: number = 0; i < n; i++) { s.piles.push(new ExpansionPile()); } }
  private cardPieces(s: ExpansionState, n: number, face: number): void {
    for (let i: number = 0; i < n; i++) { const p: ExpansionPiece = new ExpansionPiece(); p.id = i; p.kind = 51; p.w = face; s.pieces.push(p); } s.serial = n + 1;
  }
  start(s: ExpansionState): void {
    s.cols = 6; s.rows = 6;
    if (s.id === 'ludo') {
      s.goal = 4; s.data = [0, 0];
      for (let i: number = 0; i < 16; i++) { const p: ExpansionPiece = new ExpansionPiece(); p.id = i; p.kind = 52; p.owner = Math.floor(i / 4); p.color = p.owner + 1; p.x = -1; s.pieces.push(p); } s.serial = 17; return;
    }
    if (s.id === 'mahjong') {
      this.piles(s, 9); s.board = this.deck(136); s.data = [0, 0, 0, 0, 0, 0, 0, 0]; s.goal = 136;
      for (let i: number = 0; i < 52; i++) { s.piles[i % 4].cards.push(s.board[i]); } s.cursor = 52; this.draw(s, 0); return;
    }
    const spider: boolean = s.id === 'spider'; s.goal = spider ? 104 : 52; this.cardPieces(s, s.goal, spider ? 0 : 1); this.piles(s, spider ? 12 : 16);
    const deck: number[] = this.deck(s.goal);
    if (spider) {
      for (let i: number = 0; i < 54; i++) { s.piles[i % 10].cards.push(deck[i]); }
      for (let i: number = 0; i < 10; i++) { const cards: number[] = s.piles[i].cards; s.pieces[cards[cards.length - 1]].w = 1; }
      s.piles[10].cards = deck.slice(54); s.data = [0];
    } else { deck.forEach((card: number, i: number) => { s.piles[i % 8].cards.push(card); }); s.data = [0]; }
  }
  private pileOf(s: ExpansionState, card: number): number { return s.piles.findIndex((pile: ExpansionPile) => pile.cards.includes(card)); }
  private rank(card: number): number { return card % 13; }
  private red(card: number): boolean { return Math.floor(card / 13) === 1 || Math.floor(card / 13) === 2; }
  private tail(s: ExpansionState, pile: number, from: number): boolean {
    const cards: number[] = s.piles[pile].cards; if (from < 0 || from >= cards.length) { return false; }
    for (let i: number = from; i < cards.length; i++) { if (s.pieces[cards[i]].w !== 1 || (i > from && (this.rank(cards[i - 1]) !== this.rank(cards[i]) + 1 || (s.id === 'freecell' && this.red(cards[i - 1]) === this.red(cards[i]))))) { return false; } } return true;
  }
  private reveal(s: ExpansionState, pile: number): void { const cards: number[] = s.piles[pile].cards; if (cards.length > 0) { s.pieces[cards[cards.length - 1]].w = 1; } }
  private spiderRuns(s: ExpansionState): void {
    for (let pile: number = 0; pile < 10; pile++) {
      const cards: number[] = s.piles[pile].cards; const start: number = cards.length - 13;
      if (start >= 0 && this.rank(cards[start]) === 12 && this.tail(s, pile, start)) { s.piles[11].cards.push(...cards.splice(start, 13)); s.data[0]++; s.score += 500; this.reveal(s, pile); }
    }
    if (s.data[0] === 8) { s.outcome = 1; }
  }
  private tableMove(s: ExpansionState, destination: number): void {
    const fromPile: number = this.pileOf(s, s.selected); if (fromPile < 0 || fromPile === destination || destination >= s.piles.length) { return; }
    const source: number[] = s.piles[fromPile].cards; const from: number = source.indexOf(s.selected); const moving: number[] = source.slice(from);
    if (s.id === 'spider') {
      if (fromPile >= 10 || destination >= 10 || !this.tail(s, fromPile, from)) { return; }
      const target: number[] = s.piles[destination].cards; if (target.length > 0 && this.rank(target[target.length - 1]) !== this.rank(s.selected) + 1) { return; }
    } else {
      if (fromPile >= 12 || !this.tail(s, fromPile, from)) { return; }
      const target: number[] = s.piles[destination].cards;
      if (destination >= 12) { if (moving.length !== 1 || Math.floor(s.selected / 13) !== destination - 12 || this.rank(s.selected) !== target.length) { return; } }
      else if (destination >= 8) { if (moving.length !== 1 || target.length !== 0) { return; } }
      else {
        if (target.length > 0 && (this.red(target[target.length - 1]) === this.red(s.selected) || this.rank(target[target.length - 1]) !== this.rank(s.selected) + 1)) { return; }
        const free: number = s.piles.slice(8, 12).filter((pile: ExpansionPile) => pile.cards.length === 0).length;
        const columns: number = s.piles.slice(0, 8).filter((pile: ExpansionPile, i: number) => pile.cards.length === 0 && i !== destination).length;
        if (moving.length > (free + 1) * Math.pow(2, columns)) { return; }
      }
    }
    source.splice(from); s.piles[destination].cards.push(...moving); this.reveal(s, fromPile); s.selected = -1; s.moves++;
    if (s.id === 'spider') { this.spiderRuns(s); } else { s.score = s.piles.slice(12).reduce((sum: number, pile: ExpansionPile) => sum + pile.cards.length * 50, 0); if (s.piles.slice(12).every((pile: ExpansionPile) => pile.cards.length === 13)) { s.outcome = 1; } }
  }
  private cardsTap(s: ExpansionState, at: number): void {
    if (at === 900) {
      if (s.id === 'freecell') { if (s.selected >= 0) { this.tableMove(s, 12 + Math.floor(s.selected / 13)); } return; }
      if (s.piles[10].cards.length === 0 || s.piles.slice(0, 10).some((pile: ExpansionPile) => pile.cards.length === 0)) { return; }
      for (let col: number = 0; col < 10; col++) { const card: number = s.piles[10].cards.shift() ?? 0; s.pieces[card].w = 1; s.piles[col].cards.push(card); } s.moves++; s.selected = -1; this.spiderRuns(s); return;
    }
    if (at >= 200 && at < 200 + (s.id === 'spider' ? 10 : 16)) { this.tableMove(s, at - 200); return; }
    if (at >= s.pieces.length || s.pieces[at].w === 0) { return; } const pile: number = this.pileOf(s, at); if (pile < 0 || pile >= (s.id === 'spider' ? 10 : 12)) { return; }
    if (s.selected >= 0 && s.selected !== at && this.pileOf(s, s.selected) !== pile) { this.tableMove(s, pile); }
    else if (this.tail(s, pile, s.piles[pile].cards.indexOf(at))) { s.selected = s.selected === at ? -1 : at; }
  }
  private ludoLegal(s: ExpansionState, player: number): ExpansionPiece[] { return s.pieces.filter((p: ExpansionPiece) => p.owner === player && p.x < 57 && (p.x >= 0 || s.data[0] === 6)); }
  private ludoMove(s: ExpansionState, token: ExpansionPiece): void {
    const die: number = s.data[0]; if (die === 0 || !this.ludoLegal(s, s.next - 1).some((p: ExpansionPiece) => p.id === token.id)) { return; }
    let destination: number = token.x < 0 ? 0 : token.x + die; if (destination > 57) { destination = 114 - destination; }
    if (destination < 50 && destination % 4 === 0 && destination > 0) { destination = Math.min(51, destination + 4); }
    token.x = destination;
    if (destination < 52) { const shared: number = (destination + token.owner * 13) % 52; s.pieces.forEach((p: ExpansionPiece) => { if (p.owner !== token.owner && p.x >= 0 && p.x < 52 && (p.x + p.owner * 13) % 52 === shared) { p.x = -1; } }); }
    s.moves++; s.score = s.pieces.filter((p: ExpansionPiece) => p.owner === 0).reduce((sum: number, p: ExpansionPiece) => sum + Math.max(0, p.x) * 10, 0);
    if (s.pieces.filter((p: ExpansionPiece) => p.owner === token.owner).every((p: ExpansionPiece) => p.x === 57)) { s.outcome = token.owner === 0 ? 1 : 2; }
    s.data[0] = 0; if (die !== 6) { s.next = s.next % 4 + 1; }
  }
  private ludoBots(s: ExpansionState): void {
    for (let guard: number = 0; guard < 100 && s.next !== 1 && s.outcome === 0; guard++) {
      s.data[0] = 1 + this.pick(6); const legal: ExpansionPiece[] = this.ludoLegal(s, s.next - 1);
      if (legal.length === 0) { s.data[0] = 0; s.next = s.next % 4 + 1; } else { legal.sort((a: ExpansionPiece, b: ExpansionPiece) => b.x - a.x); this.ludoMove(s, legal[0]); }
    }
  }
  private ludoTap(s: ExpansionState, at: number): void {
    if (s.next !== 1) { return; }
    if (at === 900 && s.data[0] === 0) { s.data[0] = 1 + this.pick(6); if (this.ludoLegal(s, 0).length === 0) { s.data[0] = 0; s.next = 2; this.ludoBots(s); } return; }
    const token: ExpansionPiece | undefined = s.pieces.find((p: ExpansionPiece) => p.id === at && p.owner === 0);
    if (token) { this.ludoMove(s, token); this.ludoBots(s); }
  }
  private sortTiles(cards: number[]): void { cards.sort((a: number, b: number) => Math.floor(a / 4) - Math.floor(b / 4) || a - b); }
  private draw(s: ExpansionState, player: number): boolean {
    if (s.cursor >= 136) { s.outcome = 1; s.data[3] = 1; s.score = 0; return false; }
    s.piles[player].cards.push(s.board[s.cursor++]); this.sortTiles(s.piles[player].cards); return true;
  }
  private melds(counts: number[], remaining: number): boolean {
    const first: number = counts.findIndex((v: number) => v > 0); if (first < 0) { return remaining === 0; } if (remaining <= 0) { return false; }
    if (counts[first] >= 3) { counts[first] -= 3; const won: boolean = this.melds(counts, remaining - 1); counts[first] += 3; if (won) { return true; } }
    if (first < 27 && first % 9 <= 6 && counts[first + 1] > 0 && counts[first + 2] > 0) {
      counts[first]--; counts[first + 1]--; counts[first + 2]--; const won: boolean = this.melds(counts, remaining - 1); counts[first]++; counts[first + 1]++; counts[first + 2]++; if (won) { return true; }
    } return false;
  }
  mahjongWin(cards: number[], declared: number = 0): boolean {
    if (cards.length !== 14 - declared * 3) { return false; } const counts: number[] = new Array<number>(34).fill(0); cards.forEach((card: number) => { counts[Math.floor(card / 4)]++; });
    if (declared === 0 && counts.every((v: number) => v % 2 === 0)) { return true; }
    for (let pair: number = 0; pair < 34; pair++) { if (counts[pair] >= 2) { counts[pair] -= 2; const won: boolean = this.melds(counts, 4 - declared); counts[pair] += 2; if (won) { return true; } } } return false;
  }
  mahjongCan(s: ExpansionState, command: number): boolean {
    const hand: number[] = s.piles[0].cards; const reaction: boolean = s.data[0] === 1; const card: number = s.data[2] - 1; const type: number = Math.floor(card / 4);
    if (command === 900) { return this.mahjongWin(reaction ? [...hand, card] : hand, s.data[4]); }
    if (!reaction || card < 0 || s.data[4] >= 4) { return false; }
    if (command === 901 || command === 905) { return hand.filter((v: number) => Math.floor(v / 4) === type).length >= (command === 901 ? 2 : 3); }
    const start: number = type - (command - 902); if (command < 902 || command > 904 || s.data[1] !== 3 || type >= 27 || start < 0 || Math.floor(start / 9) !== Math.floor(type / 9) || start % 9 > 6) { return false; }
    return [start, start + 1, start + 2].filter((v: number) => v !== type).every((v: number) => hand.some((tile: number) => Math.floor(tile / 4) === v));
  }
  private mahjongAdvance(s: ExpansionState): void {
    for (let guard: number = 0; guard < 4 && s.outcome === 0; guard++) {
      const player: number = s.next % 4; s.next = player;
      if (!this.draw(s, player)) { return; }
      if (player === 0) { s.data[0] = 0; return; }
      const hand: number[] = s.piles[player].cards; if (this.mahjongWin(hand, s.data[4 + player])) { s.outcome = 2; return; }
      const discard: number = hand.slice().sort((a: number, b: number) => hand.filter((v: number) => Math.floor(v / 4) === Math.floor(a / 4)).length - hand.filter((v: number) => Math.floor(v / 4) === Math.floor(b / 4)).length || b - a)[0];
      hand.splice(hand.indexOf(discard), 1); s.piles[8].cards.push(discard); s.data[1] = player; s.data[2] = discard + 1; s.next = (player + 1) % 4; s.data[0] = 1;
      if ([900, 901, 902, 903, 904, 905].some((command: number) => this.mahjongCan(s, command))) { return; } s.data[0] = 0;
    }
  }
  private mahjongTap(s: ExpansionState, at: number): void {
    if (at === 900 && this.mahjongCan(s, at)) { if (s.data[0] === 1) { s.piles[0].cards.push(s.piles[8].cards.pop() ?? 0); } s.data[0] = 0; s.outcome = 1; s.score = 1500; return; }
    if (s.data[0] === 1) {
      if (at === 907) { s.data[0] = 0; this.mahjongAdvance(s); return; }
      if (!this.mahjongCan(s, at)) { return; }
      const card: number = s.piles[8].cards.pop() ?? 0; const type: number = Math.floor(card / 4); const types: number[] = at === 901 ? [type, type] : at === 905 ? [type, type, type] : [type - (at - 902), type - (at - 902) + 1, type - (at - 902) + 2].filter((v: number) => v !== type);
      const hand: number[] = s.piles[0].cards; const meld: number[] = [card]; types.forEach((v: number) => { const i: number = hand.findIndex((tile: number) => Math.floor(tile / 4) === v); meld.push(hand.splice(i, 1)[0]); });
      s.piles[4].cards.push(...meld); s.data[4]++; s.data[0] = 0; s.next = 0; s.moves++; if (at === 905) { this.draw(s, 0); } return;
    }
    if (at === 906 && s.selected >= 0 && s.data[4] < 4) {
      const type: number = Math.floor(s.selected / 4); const tiles: number[] = s.piles[0].cards.filter((v: number) => Math.floor(v / 4) === type);
      if (tiles.length !== 4) { return; } s.piles[0].cards = s.piles[0].cards.filter((v: number) => !tiles.includes(v)); s.piles[4].cards.push(...tiles); s.data[4]++; s.selected = -1; this.draw(s, 0); s.moves++; return;
    }
    if (!s.piles[0].cards.includes(at)) { return; }
    if (s.selected !== at) { s.selected = at; return; }
    s.piles[0].cards.splice(s.piles[0].cards.indexOf(at), 1); s.piles[8].cards.push(at); s.selected = -1; s.moves++;
    for (let player: number = 1; player < 4; player++) { if (this.mahjongWin([...s.piles[player].cards, at], s.data[4 + player])) { s.outcome = 2; return; } }
    s.next = 1; this.mahjongAdvance(s);
  }
  tap(s: ExpansionState, at: number): void { if (s.id === 'ludo') { this.ludoTap(s, at); } else if (s.id === 'mahjong') { this.mahjongTap(s, at); } else { this.cardsTap(s, at); } }
  valid(s: ExpansionState): boolean {
    if (!CARD_IDS.includes(s.id) || s.cols !== 6 || s.rows !== 6 || s.phase !== 0 || s.tray.length !== 0 || s.target.length !== 0) { return false; }
    if (s.id === 'ludo') { return s.goal === 4 && s.piles.length === 0 && s.board.length === 0 && V.numbers(s.data, 2, 0, 6) && V.integer(s.next, 1, 4) && s.pieces.length === 16 && s.pieces.every((p: ExpansionPiece, i: number) => p.id === i && p.kind === 52 && p.owner === Math.floor(i / 4) && V.integer(p.x, -1, 57)); }
    if (s.id === 'mahjong') {
      if (s.goal !== 136 || s.pieces.length !== 0 || s.piles.length !== 9 || !V.numbers(s.board, 136, 0, 135) || new Set<number>(s.board).size !== 136 ||
        !V.numbers(s.data, 8, 0, 136) || s.data[0] > 1 || s.data[1] > 3 || s.data[3] > 1 || s.data.slice(4).some((v: number) => v > 4) || s.cursor < 52 || s.cursor > 136 || s.next > 3) { return false; }
      const all: number[] = [];
      for (let i: number = 0; i < 9; i++) { if (!s.piles[i] || !V.numbers(s.piles[i].cards, s.piles[i].cards.length, 0, 135)) { return false; } all.push(...s.piles[i].cards); }
      return all.length === s.cursor && new Set<number>(all).size === all.length && all.every((v: number) => s.board.slice(0, s.cursor).includes(v));
    }
    const spider: boolean = s.id === 'spider'; const count: number = spider ? 104 : 52;
    if (s.goal !== count || s.pieces.length !== count || s.piles.length !== (spider ? 12 : 16) || s.board.length !== 0 || !V.numbers(s.data, 1, 0, 8) || s.selected >= count ||
      s.pieces.some((p: ExpansionPiece, i: number) => p.id !== i || p.kind !== 51 || !V.integer(p.w, 0, 1))) { return false; }
    const all: number[] = [];
    for (let i: number = 0; i < s.piles.length; i++) { if (!s.piles[i] || !V.numbers(s.piles[i].cards, s.piles[i].cards.length, 0, count - 1)) { return false; } all.push(...s.piles[i].cards); }
    if (all.length !== count || new Set<number>(all).size !== count) { return false; }
    if (spider) { return s.piles[11].cards.length === s.data[0] * 13; }
    return s.piles.slice(8, 12).every((pile: ExpansionPile) => pile.cards.length <= 1) && s.piles.slice(12).every((pile: ExpansionPile, suit: number) => pile.cards.every((card: number, rank: number) => Math.floor(card / 13) === suit && card % 13 === rank));
  }
}
