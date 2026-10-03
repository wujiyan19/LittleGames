import { ExpansionState, ExpansionPiece, ExpansionPile } from './ExpansionState';
import { RandomSource } from './RandomSource';

export class CharacterRecipe {
  result: string = '';
  parts: number[] = [];
  constructor(result: string, parts: number[]) { this.result = result; this.parts = parts; }
}
export const CHARACTER_PARTS: string[] = ['日', '月', '木', '人', '口', '女', '子', '田', '力', '火', '山', '水'];
export const CHARACTER_RECIPES: CharacterRecipe[] = [
  new CharacterRecipe('明', [0, 1]), new CharacterRecipe('林', [2, 2]), new CharacterRecipe('休', [3, 2]),
  new CharacterRecipe('好', [5, 6]), new CharacterRecipe('男', [7, 8]), new CharacterRecipe('炎', [9, 9]),
  new CharacterRecipe('森', [2, 2, 2]), new CharacterRecipe('品', [4, 4, 4])
];

export class ExpansionTable {
  private random: RandomSource;
  constructor(random: RandomSource) { this.random = random; }
  private pick(n: number): number { return Math.min(n - 1, Math.max(0, Math.floor(this.random.next() * n))); }
  start(s: ExpansionState): void {
    if (s.id === 'characters') { s.goal = 8; this.word(s); return; }
    const deck: number[] = new Array<number>(52).fill(0).map((v: number, i: number) => i);
    for (let i: number = 51; i > 0; i--) { const j: number = this.pick(i + 1); const temp: number = deck[i]; deck[i] = deck[j]; deck[j] = temp; }
    for (let i: number = 0; i < 13; i++) { s.piles.push(new ExpansionPile()); }
    for (let i: number = 0; i < 52; i++) { const card: ExpansionPiece = new ExpansionPiece(); card.id = i; card.kind = 12; card.color = Math.floor(i / 13); s.pieces.push(card); }
    for (let col: number = 0; col < 7; col++) {
      for (let j: number = 0; j <= col; j++) {
        const card: number = deck.pop() ?? 0; s.piles[col + 2].cards.push(card); s.pieces[card].w = j === col ? 1 : 0;
      }
    }
    s.piles[0].cards = deck; s.goal = 52;
  }
  private word(s: ExpansionState): void {
    s.cursor = (s.moves + s.level * 2) % CHARACTER_RECIPES.length;
    s.target = CHARACTER_RECIPES[s.cursor].parts.slice(); s.board = [];
    s.target.forEach((part: number) => { if (!s.board.includes(part)) { s.board.push(part); } });
    const candidates: number[] = new Array<number>(CHARACTER_PARTS.length).fill(0).map((v: number, i: number) => i).filter((i: number) => !s.board.includes(i));
    while (s.board.length < 6) { const at: number = this.pick(candidates.length); s.board.push(candidates[at]); candidates.splice(at, 1); }
    for (let i: number = s.board.length - 1; i > 0; i--) { const at: number = this.pick(i + 1); const temp: number = s.board[i]; s.board[i] = s.board[at]; s.board[at] = temp; }
    s.tray = [];
  }
  checkWord(s: ExpansionState): void {
    if (s.id !== 'characters' || s.tray.length === 0) { return; }
    const selected: number[] = s.tray.slice().sort((a: number, b: number) => a - b); const answer: number[] = s.target.slice().sort((a: number, b: number) => a - b);
    if (selected.join(',') === answer.join(',')) {
      s.moves++; s.score += 100; if (s.moves >= s.goal) { s.outcome = 1; } else { this.word(s); }
    } else { s.errors++; s.tray = []; if (s.errors >= 3) { s.outcome = 2; } }
  }
  rank(card: number): number { return card % 13 + 1; }
  red(card: number): boolean { const suit: number = Math.floor(card / 13); return suit === 1 || suit === 2; }
  private owner(s: ExpansionState, card: number): number { return s.piles.findIndex((pile: ExpansionPile) => pile.cards.includes(card)); }
  private movable(s: ExpansionState, card: number): boolean {
    const from: number = this.owner(s, card); if (from < 1 || from > 8 || s.pieces[card].w !== 1) { return false; }
    const cards: number[] = s.piles[from].cards; const pos: number = cards.indexOf(card);
    if (from === 1) { return pos === cards.length - 1; }
    for (let i: number = pos + 1; i < cards.length; i++) {
      if (s.pieces[cards[i]].w !== 1 || this.rank(cards[i]) !== this.rank(cards[i - 1]) - 1 || this.red(cards[i]) === this.red(cards[i - 1])) { return false; }
    } return true;
  }
  private transfer(s: ExpansionState, to: number): boolean {
    const selected: number = s.selected; if (selected < 0 || !this.movable(s, selected)) { return false; }
    const from: number = this.owner(s, selected); if (from === to || to < 2 || to > 12) { return false; }
    const source: number[] = s.piles[from].cards; const pos: number = source.indexOf(selected); const destination: number[] = s.piles[to].cards;
    if (to >= 9) {
      if (pos !== source.length - 1 || Math.floor(selected / 13) !== to - 9 || this.rank(selected) !== destination.length + 1) { return false; }
    } else if (destination.length === 0 ? this.rank(selected) !== 13 :
      this.rank(selected) !== this.rank(destination[destination.length - 1]) - 1 || this.red(selected) === this.red(destination[destination.length - 1])) { return false; }
    const moved: number[] = source.splice(pos); destination.push(...moved); s.moves++;
    if (to >= 9) { s.score += 10; }
    if (source.length > 0 && from >= 2) {
      const top: number = source[source.length - 1]; if (s.pieces[top].w === 0) { s.pieces[top].w = 1; s.score += 5; }
    }
    s.selected = -1;
    if (s.piles.slice(9).every((pile: ExpansionPile) => pile.cards.length === 13)) { s.outcome = 1; } return true;
  }
  tap(s: ExpansionState, index: number): void {
    if (s.id === 'characters') {
      if (index === 100) { s.tray = []; } else if (index < s.board.length && s.tray.length < 3) { s.tray.push(s.board[index]); }
      return;
    }
    if (index === 100) {
      if (s.piles[0].cards.length === 0) {
        s.piles[0].cards = s.piles[1].cards.reverse(); s.piles[1].cards = []; s.piles[0].cards.forEach((card: number) => { s.pieces[card].w = 0; });
      } else {
        const card: number = s.piles[0].cards.pop() ?? 0; s.piles[1].cards.push(card); s.pieces[card].w = 1;
      } s.moves++; s.selected = -1; return;
    }
    if (index === 101) { if (s.selected >= 0) { this.transfer(s, 9 + Math.floor(s.selected / 13)); } return; }
    if (index >= 102 && index <= 112) { this.transfer(s, index - 100); return; }
    if (index >= 52) { return; }
    if (s.selected === index) { s.selected = -1; return; }
    if (s.selected >= 0 && this.transfer(s, this.owner(s, index))) { return; }
    if (this.movable(s, index)) { s.selected = index; }
  }
}
