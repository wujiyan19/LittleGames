import { ExpansionState } from './ExpansionState';
import { RandomSource } from './RandomSource';
import { ContinuationValidation as V } from '../../common/GameSessionTransfer';

export const CHESS_IDS: string[] = ['xiangqi', 'chess'];
export class BoardMove {
  from: number; to: number;
  constructor(from: number, to: number) { this.from = from; this.to = to; }
}
class ChessCandidate {
  move: BoardMove;
  score: number;
  check: boolean;
  safe: boolean;
  constructor(move: BoardMove, score: number, check: boolean, safe: boolean) {
    this.move = move; this.score = score; this.check = check; this.safe = safe;
  }
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
  needsComputerTurn(s: ExpansionState): boolean { return s.outcome === 0 && s.cursor === 1; }
  private values(s: ExpansionState): number[] {
    return s.id === 'chess' ? [0, 10000, 900, 500, 330, 320, 100] : [0, 10000, 120, 120, 350, 650, 350, 100];
  }
  private candidate(s: ExpansionState, move: BoardMove, side: number): ChessCandidate {
    const values: number[] = this.values(s);
    const savedBoard: number[] = s.board.slice(); const savedData: number[] = s.data.slice();
    const moving: number = this.type(s.board[move.from]);
    const captured: number = s.id === 'chess' && moving === 6 && move.from % 8 !== move.to % 8 && s.board[move.to] === 0 ? 100 : values[this.type(s.board[move.to])];
    // Commit only inside a saved trial: replies need the new castling and en-passant rights.
    this.apply(s, move.from, move.to, true);
    const safe: boolean = !this.attacked(s, move.to, 3 - side);
    const check: boolean = this.checked(s, 3 - side);
    let score: number = captured * 10 + (values[this.type(s.board[move.to])] - values[moving]) * 10;
    if (!safe) { score -= values[this.type(s.board[move.to])] * 8; }
    if (check) { score += 80; }
    score += 5 - Math.abs(move.to % s.cols - (s.cols - 1) / 2);
    s.board = savedBoard; s.data = savedData;
    return new ChessCandidate(move, score, check, safe);
  }
  private ranked(s: ExpansionState, legal: BoardMove[], side: number): ChessCandidate[] {
    const candidates: ChessCandidate[] = legal.map((move: BoardMove) => this.candidate(s, move, side));
    candidates.sort((a: ChessCandidate, b: ChessCandidate) => b.score - a.score);
    return candidates;
  }
  private tacticalCandidates(ranked: ChessCandidate[], main: number, checks: number): ChessCandidate[] {
    const result: ChessCandidate[] = ranked.slice(0, main);
    let added: number = 0;
    for (let i: number = main; i < ranked.length && added < checks; i++) {
      if (ranked[i].check) { result.push(ranked[i]); added++; }
    }
    return result;
  }
  private evaluate(s: ExpansionState): number {
    const values: number[] = this.values(s); let result: number = 0;
    for (let i: number = 0; i < s.board.length; i++) {
      const piece: number = s.board[i]; if (piece === 0) { continue; }
      const side: number = this.side(piece); const type: number = this.type(piece);
      const sign: number = side === 2 ? 1 : -1;
      result += sign * values[type];
      if (type !== 1) {
        result += sign * (s.cols / 2 - Math.abs(i % s.cols - (s.cols - 1) / 2)) * 2;
        if (this.attacked(s, i, 3 - side) && !this.attacked(s, i, side)) { result -= sign * values[type] * 0.2; }
      }
    }
    if (this.checked(s, 2)) { result -= 150; }
    if (this.checked(s, 1)) { result += 30; }
    return result;
  }
  private hardMove(s: ExpansionState, ranked: ChessCandidate[]): BoardMove {
    // At most 12 candidate moves and 14 replies each; never recurse on the UI thread.
    const candidates: ChessCandidate[] = this.tacticalCandidates(ranked, 8, 4);
    const savedBoard: number[] = s.board.slice(); const savedData: number[] = s.data.slice(); const savedCursor: number = s.cursor;
    let best: BoardMove = candidates[0].move; let bestScore: number = -1000000000;
    for (let i: number = 0; i < candidates.length; i++) {
      const candidate: ChessCandidate = candidates[i];
      s.board = savedBoard.slice(); s.data = savedData.slice();
      this.apply(s, candidate.move.from, candidate.move.to, true); s.cursor = 0;
      const replies: BoardMove[] = this.moves(s, 1);
      let worst: number = this.evaluate(s);
      if (replies.length === 0) { worst = this.checked(s, 1) || s.id === 'xiangqi' ? 100000000 : 0; }
      else {
        const replyBoard: number[] = s.board.slice(); const replyData: number[] = s.data.slice();
        const responses: ChessCandidate[] = this.tacticalCandidates(this.ranked(s, replies, 1), 10, 4);
        worst = 1000000000;
        let mateChecks: number = 0;
        for (let j: number = 0; j < responses.length; j++) {
          s.board = replyBoard.slice(); s.data = replyData.slice();
          const reply: BoardMove = responses[j].move;
          this.apply(s, reply.from, reply.to, true); s.cursor = 1;
          let score: number = this.evaluate(s);
          if (responses[j].check && mateChecks < 4) {
            mateChecks++;
            if (this.moves(s, 2).length === 0) { score = -100000000; }
          }
          worst = Math.min(worst, score);
        }
      }
      const score: number = worst + candidate.score * 0.01;
      if (score > bestScore) { bestScore = score; best = candidate.move; }
    }
    s.board = savedBoard; s.data = savedData; s.cursor = savedCursor;
    return best;
  }
  computerTurn(s: ExpansionState): void {
    if (!this.needsComputerTurn(s)) { return; }
    const legal: BoardMove[] = this.moves(s, 2);
    if (legal.length === 0) { this.finish(s); return; }
    const ranked: ChessCandidate[] = this.ranked(s, legal, 2);
    let best: BoardMove = ranked[0].move;
    if (s.level === 0) {
      const safe: ChessCandidate[] = ranked.filter((candidate: ChessCandidate) => candidate.safe);
      const choices: ChessCandidate[] = safe.length > 0 ? safe : ranked;
      best = choices[Math.min(choices.length - 1, Math.floor(this.random.next() * choices.length))].move;
    } else if (s.level === 2) { best = this.hardMove(s, ranked); }
    else {
      let bestScore: number = -1000000000;
      ranked.forEach((candidate: ChessCandidate) => {
        const score: number = candidate.score + this.random.next() * 6;
        if (score > bestScore) { bestScore = score; best = candidate.move; }
      });
    }
    this.move(s, best.from, best.to);
  }
  tap(s: ExpansionState, at: number, automatic: boolean = true): void {
    if (!V.integer(at, 0, s.board.length - 1) || s.outcome !== 0 || s.cursor !== 0) { return; }
    if (this.side(s.board[at]) === 1) { s.selected = s.selected === at ? -1 : at; return; }
    if (s.selected >= 0 && this.legal(s, s.selected, at)) { this.move(s, s.selected, at); if (automatic && this.needsComputerTurn(s)) { this.computerTurn(s); } }
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
