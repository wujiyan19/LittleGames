import { ExpansionState } from './ExpansionState';
import { RandomSource } from './RandomSource';
import { ContinuationValidation as V } from '../../common/GameSessionTransfer';

export const CHESS_IDS: string[] = ['xiangqi', 'chess'];
export class BoardMove {
  from: number; to: number;
  constructor(from: number, to: number) { this.from = from; this.to = to; }
}
export class ExpansionChess {
  private random: RandomSource;
  constructor(random: RandomSource) { this.random = random; }
  side(piece: number): number { return piece === 0 ? 0 : piece > 10 ? 2 : 1; }
  type(piece: number): number { return piece % 10; }
  start(s: ExpansionState): void {
    s.cols = s.id === 'xiangqi' ? 9 : 8; s.rows = s.id === 'xiangqi' ? 10 : 8; s.goal = 1;
    s.board = new Array<number>(s.cols * s.rows).fill(0); s.data = new Array<number>(10).fill(0); s.data[9] = 2;
    const ranks: number[] = s.id === 'xiangqi' ? [5, 4, 3, 2, 1, 2, 3, 4, 5] : [3, 5, 4, 2, 1, 4, 5, 3];
    for (let x: number = 0; x < s.cols; x++) { s.board[x] = 10 + ranks[x]; s.board[(s.rows - 1) * s.cols + x] = ranks[x]; }
    if (s.id === 'xiangqi') {
      [1, 7].forEach((x: number) => { s.board[2 * 9 + x] = 16; s.board[7 * 9 + x] = 6; });
      [0, 2, 4, 6, 8].forEach((x: number) => { s.board[3 * 9 + x] = 17; s.board[6 * 9 + x] = 7; });
    } else { for (let x: number = 0; x < 8; x++) { s.board[8 + x] = 16; s.board[48 + x] = 6; } }
    s.target = [this.hash(s)];
  }
  private between(s: ExpansionState, from: number, to: number): number {
    const x1: number = from % s.cols; const y1: number = Math.floor(from / s.cols); const x2: number = to % s.cols; const y2: number = Math.floor(to / s.cols);
    const dx: number = Math.sign(x2 - x1); const dy: number = Math.sign(y2 - y1); const distance: number = Math.max(Math.abs(x2 - x1), Math.abs(y2 - y1)); let count: number = 0;
    for (let i: number = 1; i < distance; i++) { if (s.board[(y1 + dy * i) * s.cols + x1 + dx * i] > 0) { count++; } } return count;
  }
  private palace(side: number, x: number, y: number): boolean { return x >= 3 && x <= 5 && (side === 1 ? y >= 7 && y <= 9 : y >= 0 && y <= 2); }
  private raw(s: ExpansionState, from: number, to: number, attack: boolean): boolean {
    if (from === to || from < 0 || to < 0 || from >= s.board.length || to >= s.board.length || s.board[from] === 0) { return false; }
    const piece: number = s.board[from]; const side: number = this.side(piece); const type: number = this.type(piece);
    const x: number = from % s.cols; const y: number = Math.floor(from / s.cols); const tx: number = to % s.cols; const ty: number = Math.floor(to / s.cols);
    const dx: number = tx - x; const dy: number = ty - y; const ax: number = Math.abs(dx); const ay: number = Math.abs(dy);
    if (!attack && this.side(s.board[to]) === side) { return false; }
    if (s.id === 'xiangqi') {
      if (type === 1) { return (ax + ay === 1 && this.palace(side, tx, ty)) || (dx === 0 && this.type(s.board[to]) === 1 && this.side(s.board[to]) !== side && this.between(s, from, to) === 0); }
      if (type === 2) { return ax === 1 && ay === 1 && this.palace(side, tx, ty); }
      if (type === 3) { return ax === 2 && ay === 2 && (side === 1 ? ty >= 5 : ty <= 4) && s.board[(y + dy / 2) * 9 + x + dx / 2] === 0; }
      if (type === 4) { return (ax === 2 && ay === 1 && s.board[y * 9 + x + Math.sign(dx)] === 0) || (ax === 1 && ay === 2 && s.board[(y + Math.sign(dy)) * 9 + x] === 0); }
      if (type === 5) { return (dx === 0 || dy === 0) && this.between(s, from, to) === 0; }
      if (type === 6) { return (dx === 0 || dy === 0) && this.between(s, from, to) === (s.board[to] === 0 ? 0 : 1); }
      return (dx === 0 && dy === (side === 1 ? -1 : 1)) || (ay === 0 && ax === 1 && (side === 1 ? y <= 4 : y >= 5));
    }
    if (type === 1) {
      if (Math.max(ax, ay) === 1) { return true; }
      if (attack || ay !== 0 || ax !== 2 || from !== (side === 1 ? 60 : 4)) { return false; }
      const base: number = side === 1 ? 0 : 3; const rook: number = (side === 1 ? 56 : 0) + (dx > 0 ? 7 : 0);
      if (s.data[base] !== 0 || s.data[base + (dx > 0 ? 2 : 1)] !== 0 || s.board[rook] !== (side === 1 ? 3 : 13) || this.between(s, from, rook) !== 0) { return false; }
      return !this.attacked(s, from, 3 - side) && !this.attacked(s, from + Math.sign(dx), 3 - side) && !this.attacked(s, to, 3 - side);
    }
    if (type === 2) { return (dx === 0 || dy === 0 || ax === ay) && this.between(s, from, to) === 0; }
    if (type === 3) { return (dx === 0 || dy === 0) && this.between(s, from, to) === 0; }
    if (type === 4) { return ax === ay && this.between(s, from, to) === 0; }
    if (type === 5) { return ax * ay === 2; }
    const direction: number = side === 1 ? -1 : 1;
    if (attack) { return ax === 1 && dy === direction; }
    if (dx === 0 && dy === direction && s.board[to] === 0) { return true; }
    if (dx === 0 && dy === direction * 2 && y === (side === 1 ? 6 : 1) && s.board[to] === 0 && s.board[from + direction * 8] === 0) { return true; }
    return ax === 1 && dy === direction && (this.side(s.board[to]) === 3 - side || (s.data[6] === to + 1 && s.board[to - direction * 8] === (side === 1 ? 16 : 6)));
  }
  attacked(s: ExpansionState, cell: number, by: number): boolean { return s.board.some((p: number, i: number) => this.side(p) === by && this.raw(s, i, cell, true)); }
  checked(s: ExpansionState, side: number): boolean { const king: number = s.board.findIndex((p: number) => p === (side === 1 ? 1 : 11)); return king < 0 || this.attacked(s, king, 3 - side); }
  private apply(s: ExpansionState, from: number, to: number, commit: boolean): void {
    const piece: number = s.board[from]; const capture: number = s.board[to]; const side: number = this.side(piece); const type: number = this.type(piece);
    if (s.id === 'chess') {
      if (type === 6 && to % 8 !== from % 8 && capture === 0) { s.board[to + (side === 1 ? 8 : -8)] = 0; }
      if (type === 1 && Math.abs(to - from) === 2) { const rook: number = Math.floor(from / 8) * 8 + (to > from ? 7 : 0); s.board[to + (to > from ? -1 : 1)] = s.board[rook]; s.board[rook] = 0; }
      if (commit) {
        if (type === 1) { s.data[side === 1 ? 0 : 3] = 1; }
        [56, 63, 0, 7].forEach((cell: number, i: number) => { if (from === cell || to === cell) { s.data[[1, 2, 4, 5][i]] = 1; } });
        s.data[6] = type === 6 && Math.abs(to - from) === 16 ? (from + to) / 2 + 1 : 0;
        s.data[7] = type === 6 || capture !== 0 ? 0 : s.data[7] + 1;
      }
    }
    s.board[from] = 0; s.board[to] = piece;
    if (s.id === 'chess' && type === 6 && (to < 8 || to >= 56)) { s.board[to] = (side === 1 ? 0 : 10) + (side === 1 ? s.data[9] : 2); }
  }
  legal(s: ExpansionState, from: number, to: number): boolean {
    if (!this.raw(s, from, to, false) || this.type(s.board[to]) === 1) { return false; }
    const side: number = this.side(s.board[from]); const saved: number[] = s.board.slice(); this.apply(s, from, to, false); const okay: boolean = !this.checked(s, side); s.board = saved; return okay;
  }
  moves(s: ExpansionState, side: number): BoardMove[] {
    const result: BoardMove[] = [];
    for (let from: number = 0; from < s.board.length; from++) { if (this.side(s.board[from]) !== side) { continue; }
      for (let to: number = 0; to < s.board.length; to++) { if (this.legal(s, from, to)) { result.push(new BoardMove(from, to)); } }
    } return result;
  }
  private hash(s: ExpansionState): number {
    let hash: number = s.cursor + 1; s.board.forEach((p: number) => { hash = (hash * 31 + p) % 1000003; });
    s.data.slice(0, 7).forEach((v: number) => { hash = (hash * 31 + v) % 1000003; }); return hash;
  }
  private finish(s: ExpansionState): void {
    const side: number = s.cursor + 1;
    if (this.moves(s, side).length === 0) {
      if (s.id === 'chess' && !this.checked(s, side)) { s.data[8] = 1; s.outcome = 1; } else { s.outcome = side === 2 ? 1 : 2; s.score = s.outcome === 1 ? Math.max(100, 2000 - s.moves * 5) : 0; } return;
    }
    const hash: number = this.hash(s); s.target.push(hash); if (s.target.length > 120) { s.target.shift(); }
    const material: number[] = s.board.filter((p: number) => p !== 0 && this.type(p) !== 1);
    const insufficient: boolean = s.id === 'chess' && (material.length === 0 || (material.length === 1 && [4, 5].includes(this.type(material[0]))));
    if (s.target.filter((v: number) => v === hash).length >= 3 || (s.id === 'chess' && (s.data[7] >= 100 || insufficient))) { s.data[8] = 1; s.outcome = 1; }
  }
  private move(s: ExpansionState, from: number, to: number): void { this.apply(s, from, to, true); s.selected = -1; s.moves++; s.cursor = 1 - s.cursor; this.finish(s); }
  private bot(s: ExpansionState): void {
    const legal: BoardMove[] = this.moves(s, 2); if (legal.length === 0) { return; }
    let best: BoardMove = legal[0]; let bestScore: number = -100000;
    const values: number[] = s.id === 'chess' ? [0, 10000, 900, 500, 330, 320, 100] : [0, 10000, 120, 120, 350, 650, 350, 100];
    legal.forEach((move: BoardMove) => {
      let value: number = values[this.type(s.board[move.to])] * 10 + this.random.next() * 6;
      const saved: number[] = s.board.slice(); const moving: number = this.type(s.board[move.from]); this.apply(s, move.from, move.to, false);
      if (this.attacked(s, move.to, 1)) { value -= values[moving] * (s.level === 0 ? 3 : 8); }
      if (this.checked(s, 1)) { value += 80; }
      value += 5 - Math.abs(move.to % s.cols - (s.cols - 1) / 2); s.board = saved;
      if (value > bestScore) { bestScore = value; best = move; }
    }); this.move(s, best.from, best.to);
  }
  tap(s: ExpansionState, at: number): void {
    if (at >= s.board.length || s.cursor !== 0) { return; }
    if (this.side(s.board[at]) === 1) { s.selected = s.selected === at ? -1 : at; return; }
    if (s.selected >= 0 && this.legal(s, s.selected, at)) { this.move(s, s.selected, at); if (s.outcome === 0) { this.bot(s); } }
  }
  choose(s: ExpansionState, index: number): void { if (s.id === 'chess' && index < 4) { s.data[9] = [2, 3, 4, 5][index]; } }
  valid(s: ExpansionState): boolean {
    if (!CHESS_IDS.includes(s.id) || s.cols !== (s.id === 'xiangqi' ? 9 : 8) || s.rows !== (s.id === 'xiangqi' ? 10 : 8) || s.goal !== 1 || s.phase !== 0 || s.piles.length !== 0 || s.pieces.length !== 0 || s.tray.length !== 0 ||
      !V.numbers(s.board, s.cols * s.rows, 0, 17) || s.board.some((p: number) => p !== 0 && (p % 10 < 1 || p % 10 > (s.id === 'xiangqi' ? 7 : 6))) ||
      s.board.filter((p: number) => p === 1).length !== 1 || s.board.filter((p: number) => p === 11).length !== 1 || s.cursor > 1 || s.selected >= s.board.length ||
      !V.numbers(s.data, 10, 0, 100000) || s.data.slice(0, 6).some((v: number) => v > 1) || s.data[6] > 64 || s.data[8] > 1 || !V.integer(s.data[9], 2, 5) ||
      s.target.length > 120 || !V.numbers(s.target, s.target.length, 0, 1000002)) { return false; }
    return !this.checked(s, 3 - (s.cursor + 1));
  }
}
