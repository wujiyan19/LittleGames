import { ExpansionState, ExpansionPile } from './ExpansionState';
import { RandomSource } from './RandomSource';
import { ContinuationValidation as V } from '../../common/GameSessionTransfer';

export const POKER_IDS: string[] = ['doudizhu', 'guandan'];
export class PokerPattern {
  kind: number = 0; strength: number = 0; size: number = 0; bomb: number = 0;
  constructor(kind: number = 0, strength: number = 0, size: number = 0, bomb: number = 0) { this.kind = kind; this.strength = strength; this.size = size; this.bomb = bomb; }
}
export class ExpansionPoker {
  private random: RandomSource;
  constructor(random: RandomSource) { this.random = random; }
  rank(card: number): number { const base: number = card % 54; return base >= 52 ? base - 36 : base % 13 === 0 ? 14 : base % 13 + 1; }
  strength(rank: number): number { return rank === 2 ? 15 : rank; }
  private shuffle(cards: number[]): void {
    for (let i: number = cards.length - 1; i > 0; i--) { const j: number = Math.min(i, Math.max(0, Math.floor(this.random.next() * (i + 1)))); const temp: number = cards[i]; cards[i] = cards[j]; cards[j] = temp; }
  }
  start(s: ExpansionState): void {
    s.cols = 6; s.rows = 6; s.goal = s.id === 'guandan' ? 108 : 54; s.board = new Array<number>(s.goal).fill(0).map((v: number, i: number) => i); this.shuffle(s.board);
    s.piles = new Array<ExpansionPile>(); for (let i: number = 0; i < 6; i++) { s.piles.push(new ExpansionPile()); }
    const players: number = s.id === 'guandan' ? 4 : 3;
    s.board.forEach((card: number, i: number) => { s.piles[i < (s.id === 'guandan' ? 108 : 51) ? i % players : 0].cards.push(card); });
    for (let i: number = 0; i < players; i++) { this.sort(s.piles[i].cards); } s.data = [0, 0, 0, 0, 0, 0];
  }
  private sort(cards: number[]): void { cards.sort((a: number, b: number) => this.strength(this.rank(a)) - this.strength(this.rank(b)) || a - b); }
  private run(ranks: number[], count: number, length: number, guandan: boolean): number {
    const groups: number[] = [];
    for (let rank: number = guandan ? 2 : 3; rank <= 14; rank++) { if (ranks.filter((v: number) => v === rank).length === count) { groups.push(rank); } }
    if (groups.length !== length || groups.some((v: number, i: number) => i > 0 && v !== groups[i - 1] + 1)) {
      if (guandan && ranks.length === length * count && [14, ...new Array<number>(length - 1).fill(0).map((v: number, i: number) => i + 2)].every((v: number) => ranks.filter((r: number) => r === v).length === count)) { return length; } return 0;
    } return groups[groups.length - 1];
  }
  private classify(ranks: number[], suits: number[], guandan: boolean): PokerPattern {
    const n: number = ranks.length; if (n === 0) { return new PokerPattern(); }
    const counts: number[] = new Array<number>(18).fill(0); ranks.forEach((r: number) => { counts[r]++; });
    const unique: number[] = counts.map((v: number, i: number) => i).filter((i: number) => counts[i] > 0);
    if ((!guandan && n === 2 && ranks.includes(16) && ranks.includes(17)) || (guandan && n === 4 && counts[16] === 2 && counts[17] === 2)) { return new PokerPattern(14, 18, n, 1000); }
    if (unique.length === 1) {
      const rank: number = this.strength(unique[0]);
      if (n <= 3) { return new PokerPattern(n, rank, n); }
      if ((guandan && n >= 4) || (!guandan && n === 4)) { return new PokerPattern(13, rank, n, guandan ? n * 10 : 40); }
    }
    if (n === 4 && !guandan && unique.some((r: number) => counts[r] === 3)) { return new PokerPattern(4, this.strength(unique.find((r: number) => counts[r] === 3) ?? 0), n); }
    if (n === 5 && unique.length === 2 && unique.some((r: number) => counts[r] === 3) && unique.some((r: number) => counts[r] === 2)) { return new PokerPattern(5, this.strength(unique.find((r: number) => counts[r] === 3) ?? 0), n); }
    if ((!guandan && n >= 5) || (guandan && n === 5)) {
      const high: number = this.run(ranks, 1, n, guandan);
      if (high > 0) { return guandan && suits.every((suit: number) => suit === suits[0] && suit < 4) ? new PokerPattern(15, high, n, 55) : new PokerPattern(6, high, n); }
    }
    if (n % 2 === 0 && ((!guandan && n >= 6) || (guandan && n === 6))) { const high: number = this.run(ranks, 2, n / 2, guandan); if (high > 0) { return new PokerPattern(7, high, n); } }
    if (n % 3 === 0 && ((!guandan && n >= 6) || (guandan && n === 6))) { const high: number = this.run(ranks, 3, n / 3, guandan); if (high > 0) { return new PokerPattern(8, high, n); } }
    if (!guandan) {
      for (let triples: number = 2; triples <= 5; triples++) {
        if (n !== triples * 4 && n !== triples * 5) { continue; }
        for (let start: number = 3; start + triples - 1 <= 14; start++) {
          const remaining: number[] = counts.slice(); let okay: boolean = true;
          for (let r: number = start; r < start + triples; r++) { if (remaining[r] < 3) { okay = false; break; } remaining[r] -= 3; }
          if (okay && remaining.slice(start, start + triples).every((v: number) => v === 0) && (n === triples * 4 || remaining.every((v: number) => v === 0 || v === 2))) { return new PokerPattern(n === triples * 4 ? 9 : 10, start + triples - 1, n); }
        }
      }
      const four: number = counts.findIndex((v: number) => v === 4);
      if (four >= 0 && n === 6) { return new PokerPattern(11, this.strength(four), n); }
      if (four >= 0 && n === 8 && unique.filter((r: number) => r !== four).length === 2 && unique.filter((r: number) => r !== four).every((r: number) => counts[r] === 2)) { return new PokerPattern(12, this.strength(four), n); }
    } return new PokerPattern();
  }
  beats(play: PokerPattern, last: PokerPattern): boolean {
    if (play.kind === 0) { return false; } if (last.kind === 0) { return true; }
    if (play.bomb !== last.bomb) { return play.bomb > last.bomb; }
    if (play.bomb > 0) { return play.strength > last.strength; }
    return play.kind === last.kind && play.size === last.size && play.strength > last.strength;
  }
  last(s: ExpansionState): PokerPattern { return new PokerPattern(s.data[2], s.data[3], s.data[4], s.data[5]); }
  pattern(cards: number[], guandan: boolean, last: PokerPattern = new PokerPattern()): PokerPattern {
    const ranks: number[] = cards.map((card: number) => this.rank(card)); const suits: number[] = cards.map((card: number) => Math.floor(card % 54 / 13));
    const wilds: number[] = guandan ? cards.map((card: number, i: number) => i).filter((i: number) => cards[i] % 54 === 14) : [];
    const natural: PokerPattern = this.classify(ranks, suits, guandan); let best: PokerPattern = this.beats(natural, last) ? natural : new PokerPattern();
    if (wilds.length === 0 || cards.length === 1) { return best; }
    for (let a: number = 2; a <= 14; a++) { for (let b: number = wilds.length > 1 ? 2 : 14; b <= 14; b++) {
      ranks[wilds[0]] = a; if (wilds.length > 1) { ranks[wilds[1]] = b; }
      const nonwild: number = cards.findIndex((card: number) => card % 54 !== 14); const suit: number = nonwild >= 0 ? suits[nonwild] : 1;
      wilds.forEach((i: number) => { suits[i] = suit; }); const pattern: PokerPattern = this.classify(ranks, suits, guandan);
      if (this.beats(pattern, last) && (best.kind === 0 || pattern.bomb < best.bomb || (pattern.bomb === best.bomb && pattern.strength < best.strength))) { best = pattern; }
    } } return best;
  }
  private groups(hand: number[]): number[][] {
    const groups: number[][] = [];
    for (let i: number = 0; i < 18; i++) { groups.push([]); }
    for (let i: number = 0; i < hand.length; i++) { groups[this.rank(hand[i])].push(hand[i]); }
    return groups;
  }
  private fill(groups: number[][], ranks: number[], counts: number[], wild: number[]): number[] {
    const cards: number[] = []; let missing: number = 0;
    for (let i: number = 0; i < ranks.length; i++) {
      const group: number[] = groups[ranks[i]];
      const count: number = Math.min(group.length, counts[i]);
      cards.push(...group.slice(0, count)); missing += counts[i] - count;
    }
    if (missing > wild.length) { return []; }
    cards.push(...wild.slice(0, missing)); return cards;
  }
  private wings(choices: number[][], hand: number[], core: number[], singles: number, pairs: number): void {
    const coreRanks: number[] = core.map((card: number) => this.rank(card));
    const remaining: number[] = hand.filter((card: number) => !coreRanks.includes(this.rank(card)));
    if (singles > 0 && remaining.length >= singles) {
      choices.push([...core, ...remaining.slice(0, singles)]);
      choices.push([...core, ...remaining.slice(remaining.length - singles)]);
    }
    if (pairs === 0) { return; }
    const groups: number[][] = this.groups(remaining);
    const pairRanks: number[] = [];
    for (let rank: number = 2; rank <= 17; rank++) { if (groups[rank].length >= 2) { pairRanks.push(rank); } }
    if (pairRanks.length < pairs) { return; }
    const low: number[] = core.slice(); const high: number[] = core.slice();
    for (let i: number = 0; i < pairs; i++) {
      low.push(...groups[pairRanks[i]].slice(0, 2));
      high.push(...groups[pairRanks[pairRanks.length - 1 - i]].slice(0, 2));
    }
    choices.push(low); choices.push(high);
  }
  private runs(choices: number[][], hand: number[], groups: number[][], guandan: boolean, wild: number[]): void {
    for (let count: number = 1; count <= 3; count++) {
      const minimum: number = count === 1 ? 5 : count === 2 ? 3 : 2;
      const maximum: number = guandan ? minimum : count === 1 ? 12 : Math.floor(hand.length / count);
      for (let length: number = minimum; length <= maximum; length++) {
        for (let start: number = guandan ? 2 : 3; start + length - 1 <= 14; start++) {
          const ranks: number[] = [];
          for (let i: number = 0; i < length; i++) { ranks.push(start + i); }
          const run: number[] = this.fill(groups, ranks, new Array<number>(length).fill(count), wild);
          if (run.length === 0) { continue; }
          choices.push(run);
          if (!guandan && count === 3 && length <= 5) { this.wings(choices, hand, run, length, length); }
        }
      }
      if (guandan) {
        const ranks: number[] = [14];
        for (let i: number = 1; i < minimum; i++) { ranks.push(i + 1); }
        const lowAce: number[] = this.fill(groups, ranks, new Array<number>(minimum).fill(count), wild);
        if (lowAce.length > 0) { choices.push(lowAce); }
      }
    }
  }
  private fragmentation(hand: number[], choice: number[]): number {
    const before: number[][] = this.groups(hand); const after: number[][] = this.groups(hand.filter((card: number) => !choice.includes(card)));
    let cost: number = 0;
    for (let rank: number = 2; rank <= 17; rank++) {
      if (before[rank].length >= 4 && after[rank].length > 0 && after[rank].length < 4) { cost += 90; }
      else if (before[rank].length >= 2 && after[rank].length === 1) { cost += 18; }
    }
    return cost;
  }
  private enemyNearFinish(s: ExpansionState, player: number, cards: number): boolean {
    const players: number = s.id === 'guandan' ? 4 : 3;
    for (let seat: number = 0; seat < players; seat++) {
      const enemy: boolean = s.id === 'guandan' ? seat % 2 !== player % 2 : (seat === 0) !== (player === 0);
      // Hand sizes are public information. Never inspect an opponent's card ranks.
      if (enemy && s.piles[seat].cards.length > 0 && s.piles[seat].cards.length <= cards) { return true; }
    }
    return false;
  }
  candidate(s: ExpansionState, player: number): number[] {
    if (!V.integer(player, 0, s.id === 'guandan' ? 3 : 2) || !POKER_IDS.includes(s.id)) { return []; }
    const hand: number[] = s.piles[player].cards; const last: PokerPattern = this.last(s); const choices: number[][] = [];
    hand.forEach((card: number) => { choices.push([card]); });
    for (let rank: number = 2; rank <= 17; rank++) {
      const same: number[] = hand.filter((card: number) => this.rank(card) === rank);
      for (let n: number = 2; n <= same.length; n++) { choices.push(same.slice(0, n)); }
      if (same.length >= 3) {
        for (let other: number = 2; other <= 17; other++) { if (rank === other) { continue; } const pair: number[] = hand.filter((card: number) => this.rank(card) === other); if (pair.length >= 2) { choices.push([...same.slice(0, 3), ...pair.slice(0, 2)]); } if (s.id === 'doudizhu' && pair.length > 0) { choices.push([...same.slice(0, 3), pair[0]]); } }
      }
    }
    if (s.id === 'doudizhu') { const jokers: number[] = hand.filter((card: number) => this.rank(card) >= 16); if (jokers.length === 2) { choices.push(jokers); } }
    else { const jokers: number[] = hand.filter((card: number) => this.rank(card) >= 16); if (jokers.length === 4) { choices.push(jokers); } }
    const wild: number[] = hand.filter((card: number) => card % 54 === 14);
    const groups: number[][] = this.groups(hand);
    choices.push(hand.slice());
    this.runs(choices, hand, groups, s.id === 'guandan', []);
    if (s.id === 'doudizhu') {
      for (let rank: number = 2; rank <= 17; rank++) {
        if (groups[rank].length === 4) { this.wings(choices, hand, groups[rank].slice(0, 4), 2, 2); }
      }
    } else {
      const natural: number[][] = this.groups(hand.filter((card: number) => !wild.includes(card)));
      if (wild.length > 0) {
        this.runs(choices, hand, natural, true, wild);
        for (let rank: number = 2; rank <= 14; rank++) {
          for (let other: number = 2; other <= 17; other++) {
            if (rank === other) { continue; }
            const fullHouse: number[] = this.fill(natural, [rank, other], [3, 2], wild);
            if (fullHouse.length === 5) { choices.push(fullHouse); }
          }
          for (let used: number = 1; used <= wild.length; used++) {
            for (let count: number = 1; count <= natural[rank].length; count++) {
              choices.push([...natural[rank].slice(0, count), ...wild.slice(0, used)]);
            }
          }
        }
      }
      // A natural straight flush can require different physical cards from a rank-only run.
      for (let suit: number = 0; suit < 4; suit++) {
        const suited: number[] = hand.filter((card: number) => card % 54 < 52 &&
          Math.floor(card % 54 / 13) === suit && !wild.includes(card));
        const suitedGroups: number[][] = this.groups(suited);
        for (let start: number = 2; start <= 10; start++) {
          const run: number[] = this.fill(suitedGroups, [start, start + 1, start + 2, start + 3, start + 4], [1, 1, 1, 1, 1], wild);
          if (run.length === 5) { choices.push(run); }
        }
        const lowAce: number[] = this.fill(suitedGroups, [14, 2, 3, 4, 5], [1, 1, 1, 1, 1], wild);
        if (lowAce.length === 5) { choices.push(lowAce); }
      }
    }
    let best: number[] = []; let value: number = 1000000000;
    choices.forEach((choice: number[]) => {
      const pattern: PokerPattern = this.pattern(choice, s.id === 'guandan', last); if (pattern.kind === 0) { return; }
      let score: number = pattern.bomb * 100 + pattern.strength;
      if (s.level > 0) { score -= last.kind === 0 ? choice.length * 30 : 0; }
      if (s.level === 2) {
        score += this.fragmentation(hand, choice);
        if (last.kind === 0) { score -= choice.length * 20; }
        else if (pattern.bomb === 0 && this.enemyNearFinish(s, player, last.size)) { score -= pattern.strength * 3; }
      }
      if (choice.length === hand.length) { score = -1000000; }
      if (score < value) { best = choice; value = score; }
    }); return best;
  }
  private finished(s: ExpansionState, player: number): void {
    if (s.piles[player].cards.length > 0) { return; }
    if (s.id === 'doudizhu') { s.outcome = player === 0 ? 1 : 2; s.score = s.outcome === 1 ? 1500 : 0; return; }
    if (!s.target.includes(player)) { s.target.push(player); }
    if (s.target.length === 3) {
      const remaining: number = [0, 1, 2, 3].find((seat: number) => !s.target.includes(seat)) ?? 0; s.target.push(remaining);
      s.outcome = s.target[0] % 2 === 0 ? 1 : 2; const partner: number = (s.target[0] + 2) % 4; s.score = s.outcome === 1 ? (4 - s.target.indexOf(partner)) * 600 : 0;
    }
  }
  private next(s: ExpansionState): void {
    const players: number = s.id === 'guandan' ? 4 : 3;
    do { s.cursor = (s.cursor + 1) % players; } while (s.piles[s.cursor].cards.length === 0 && s.outcome === 0);
    if (s.cursor === s.data[0] || (s.piles[s.data[0]].cards.length === 0 && s.data[1] >= players - s.target.length - 1)) {
      if (s.piles[s.data[0]].cards.length === 0 && s.id === 'guandan') { const partner: number = (s.data[0] + 2) % 4; if (s.piles[partner].cards.length > 0) { s.cursor = partner; } }
      s.data[1] = 0; s.data[2] = 0; s.data[3] = 0; s.data[4] = 0; s.data[5] = 0;
    }
  }
  private play(s: ExpansionState, cards: number[]): boolean {
    const hand: number[] = s.piles[s.cursor].cards;
    if (cards.length === 0 || new Set<number>(cards).size !== cards.length || cards.some((card: number) => !hand.includes(card))) { return false; }
    const pattern: PokerPattern = this.pattern(cards, s.id === 'guandan', this.last(s)); if (pattern.kind === 0) { return false; }
    s.piles[5].cards.push(...s.piles[4].cards); s.piles[4].cards = cards.slice(); s.piles[s.cursor].cards = hand.filter((card: number) => !cards.includes(card));
    s.data = [s.cursor, 0, pattern.kind, pattern.strength, pattern.size, pattern.bomb]; s.moves++; s.tray = []; this.finished(s, s.cursor); if (s.outcome === 0) { this.next(s); } return true;
  }
  private pass(s: ExpansionState): boolean { if (s.data[2] === 0) { return false; } s.data[1]++; this.next(s); return true; }
  needsComputerTurn(s: ExpansionState): boolean {
    return POKER_IDS.includes(s.id) && s.outcome === 0 &&
      (s.cursor !== 0 || s.piles[0].cards.length === 0);
  }
  computerTurn(s: ExpansionState): void {
    if (!this.needsComputerTurn(s)) { return; }
    const partnerLeads: boolean = s.data[2] !== 0 &&
      (s.id === 'guandan' ? s.data[0] % 2 === s.cursor % 2 : s.data[0] > 0 && s.cursor > 0);
    const candidate: number[] = this.candidate(s, s.cursor);
    // Finishing one's own hand helps the team; otherwise preserve a partner's winning play.
    if (s.level > 0 && partnerLeads && candidate.length !== s.piles[s.cursor].cards.length) {
      this.pass(s);
    } else if (candidate.length > 0) { this.play(s, candidate); }
    else { this.pass(s); }
  }
  private bots(s: ExpansionState): void {
    for (let guard: number = 0; guard < 500 && this.needsComputerTurn(s); guard++) {
      this.computerTurn(s);
    }
  }
  tap(s: ExpansionState, at: number, automatic: boolean = true): void {
    if (!V.integer(at, 0, 1000) || s.outcome !== 0 || s.cursor !== 0 || s.piles[0].cards.length === 0) { return; }
    if (at === 902) { s.tray = this.candidate(s, 0); return; }
    if (at === 900) { if (this.play(s, s.tray) && automatic) { this.bots(s); } return; }
    if (at === 901) { if (this.pass(s)) { s.tray = []; if (automatic) { this.bots(s); } } return; }
    if (s.piles[0].cards.includes(at)) { s.tray = s.tray.includes(at) ? s.tray.filter((card: number) => card !== at) : [...s.tray, at]; }
  }
  valid(s: ExpansionState): boolean {
    if (!POKER_IDS.includes(s.id) || s.cols !== 6 || s.rows !== 6 || s.goal !== (s.id === 'guandan' ? 108 : 54) || s.phase !== 0 || s.pieces.length !== 0 ||
      !V.numbers(s.board, s.goal, 0, s.goal - 1) || new Set<number>(s.board).size !== s.goal || s.piles.length !== 6 || s.cursor >= (s.id === 'guandan' ? 4 : 3) ||
      !V.numbers(s.data, 6, 0, 1000) || s.data[0] >= (s.id === 'guandan' ? 4 : 3) || s.data[1] > 3 || s.data[2] > 15 || s.data[3] > 18 || s.data[4] > 27 ||
      !V.numbers(s.target, s.target.length, 0, 3) || s.target.length > 4 || new Set<number>(s.target).size !== s.target.length || new Set<number>(s.tray).size !== s.tray.length) { return false; }
    const all: number[] = [];
    for (let i: number = 0; i < 6; i++) { if (!s.piles[i] || !Array.isArray(s.piles[i].cards) || !V.numbers(s.piles[i].cards, s.piles[i].cards.length, 0, s.goal - 1)) { return false; } all.push(...s.piles[i].cards); }
    return all.length === s.goal && new Set<number>(all).size === s.goal && s.tray.every((card: number) => s.piles[0].cards.includes(card)) && (s.id !== 'doudizhu' || s.piles[3].cards.length === 0);
  }
}
