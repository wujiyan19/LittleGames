import { ExpansionState, ExpansionPiece } from './ExpansionState';
import { RandomSource } from './RandomSource';
import { ContinuationValidation as V } from '../../common/GameSessionTransfer';

export const MATCHING_IDS: string[] = ['linktiles', 'mahjongsolitaire', 'groupclear', 'slotpair'];

class LinkVisit {
  cell: number;
  direction: number;
  turns: number;
  previous: number;
  constructor(cell: number, direction: number, turns: number, previous: number) {
    this.cell = cell; this.direction = direction; this.turns = turns; this.previous = previous;
  }
}

export class ExpansionMatching {
  private random: RandomSource;
  constructor(random: RandomSource) { this.random = random; }
  private pick(n: number): number { return Math.min(n - 1, Math.max(0, Math.floor(this.random.next() * n))); }
  private shuffle(values: number[]): void {
    for (let i: number = values.length - 1; i > 0; i--) { const j: number = this.pick(i + 1); const temp: number = values[i]; values[i] = values[j]; values[j] = temp; }
  }
  start(s: ExpansionState): void {
    if (s.id === 'mahjongsolitaire') { this.makeMahjong(s); return; }
    s.cols = 6; s.rows = s.id === 'linktiles' ? 4 + s.level * 2 : s.id === 'groupclear' ? 8 : 6;
    s.board = new Array<number>(s.cols * s.rows).fill(0);
    if (s.id === 'linktiles') {
      for (let i: number = 0; i < s.board.length; i += 2) { const color: number = 1 + this.pick(3 + s.level); s.board[i] = color; s.board[i + 1] = color; }
      this.shuffle(s.board); this.ensureLink(s); s.goal = s.board.length;
    } else if (s.id === 'groupclear') {
      s.board = s.board.map(() => 1 + this.pick(3 + s.level)); s.goal = 300 + s.level * 150;
      // Always offer an opening move, even with an adversarial random source.
      s.board[1] = s.board[0];
    } else {
      s.goal = 40 + s.level * 20;
      for (let i: number = 0; i < s.goal; i += 2) { const color: number = 1 + this.pick(3 + s.level); s.target.push(color, color); }
      s.next = s.target[0];
    }
  }
  private neighbors(s: ExpansionState, at: number): number[] {
    const result: number[] = [];
    if (at >= s.cols) { result.push(at - s.cols); } if (at + s.cols < s.board.length) { result.push(at + s.cols); }
    if (at % s.cols > 0) { result.push(at - 1); } if (at % s.cols < s.cols - 1) { result.push(at + 1); } return result;
  }
  group(s: ExpansionState, at: number): number[] {
    if (at < 0 || at >= s.board.length || s.board[at] === 0) { return []; }
    const queue: number[] = [at]; const seen: boolean[] = new Array<boolean>(s.board.length).fill(false); seen[at] = true;
    for (let q: number = 0; q < queue.length; q++) {
      this.neighbors(s, queue[q]).forEach((i: number) => { if (!seen[i] && s.board[i] === s.board[at]) { seen[i] = true; queue.push(i); } });
    } return queue;
  }
  settle(s: ExpansionState, slide: boolean): void {
    let destination: number = 0;
    for (let col: number = 0; col < s.cols; col++) {
      const values: number[] = [];
      for (let row: number = s.rows - 1; row >= 0; row--) { if (s.board[row * s.cols + col] > 0) { values.push(s.board[row * s.cols + col]); } }
      const targetCol: number = slide ? destination : col;
      for (let row: number = 0; row < s.rows; row++) { s.board[row * s.cols + col] = 0; }
      for (let i: number = 0; i < values.length; i++) { s.board[(s.rows - 1 - i) * s.cols + targetCol] = values[i]; }
      if (values.length > 0) { destination++; }
    }
  }
  /** Search an empty one-cell border as well as the board; at most two direction changes. */
  linkPath(s: ExpansionState, from: number, to: number): number[] {
    if (from === to || from < 0 || to < 0 || from >= s.board.length || to >= s.board.length || s.board[from] === 0 || s.board[to] === 0) { return []; }
    const width: number = s.cols + 2; const height: number = s.rows + 2;
    const start: number = (Math.floor(from / s.cols) + 1) * width + from % s.cols + 1;
    const end: number = (Math.floor(to / s.cols) + 1) * width + to % s.cols + 1;
    const occupied: boolean[] = new Array<boolean>(width * height).fill(false);
    s.board.forEach((v: number, i: number) => { if (v > 0) { occupied[(Math.floor(i / s.cols) + 1) * width + i % s.cols + 1] = true; } });
    const visited: number[] = new Array<number>(width * height * 4).fill(3); const queue: LinkVisit[] = [];
    for (let d: number = 0; d < 4; d++) { queue.push(new LinkVisit(start, d, 0, -1)); visited[start * 4 + d] = 0; }
    const dx: number[] = [0, 1, 0, -1]; const dy: number[] = [-1, 0, 1, 0];
    for (let q: number = 0; q < queue.length; q++) {
      const node: LinkVisit = queue[q];
      if (node.cell === end) {
        const result: number[] = []; let at: number = q;
        while (at >= 0) { result.push(queue[at].cell); at = queue[at].previous; } return result.reverse();
      }
      for (let d: number = 0; d < 4; d++) {
        const turns: number = node.turns + (d === node.direction ? 0 : 1); if (turns > 2) { continue; }
        const x: number = node.cell % width + dx[d]; const y: number = Math.floor(node.cell / width) + dy[d];
        if (x < 0 || x >= width || y < 0 || y >= height) { continue; }
        const cell: number = y * width + x;
        if ((occupied[cell] && cell !== end) || visited[cell * 4 + d] <= turns) { continue; }
        visited[cell * 4 + d] = turns; queue.push(new LinkVisit(cell, d, turns, q));
      }
    } return [];
  }
  linkPair(s: ExpansionState, sameColor: boolean = true): number[] {
    for (let a: number = 0; a < s.board.length; a++) { if (s.board[a] === 0) { continue; }
      for (let b: number = a + 1; b < s.board.length; b++) {
        if (s.board[b] > 0 && (!sameColor || s.board[a] === s.board[b]) && this.linkPath(s, a, b).length > 0) { return [a, b]; }
      }
    } return [];
  }
  private ensureLink(s: ExpansionState): void {
    if (this.linkPair(s).length > 0) { return; } const pair: number[] = this.linkPair(s, false); if (pair.length < 2) { return; }
    const other: number = s.board.findIndex((v: number, i: number) => i !== pair[0] && v === s.board[pair[0]]);
    if (other >= 0) { const temp: number = s.board[pair[1]]; s.board[pair[1]] = s.board[other]; s.board[other] = temp; }
  }
  private tapLink(s: ExpansionState, index: number): void {
    if (index >= s.board.length || s.board[index] === 0) { return; }
    if (s.selected === index) { s.selected = -1; return; }
    if (s.selected >= 0 && s.board[s.selected] === s.board[index]) {
      const path: number[] = this.linkPath(s, s.selected, index);
      if (path.length > 0) {
        s.data = path; s.board[s.selected] = 0; s.board[index] = 0; s.selected = -1; s.tray = []; s.moves++; s.score += 100;
        if (s.board.every((v: number) => v === 0)) { s.outcome = 1; } return;
      }
    } s.selected = index; s.data = []; s.tray = [];
  }
  tileFree(s: ExpansionState, id: number): boolean {
    const tile: ExpansionPiece | undefined = s.pieces.find((p: ExpansionPiece) => p.id === id); if (!tile || !tile.alive) { return false; }
    const covered: boolean = s.pieces.some((p: ExpansionPiece) => p.alive && p.owner > tile.owner && p.x === tile.x && p.y === tile.y);
    const left: boolean = s.pieces.some((p: ExpansionPiece) => p.alive && p.owner === tile.owner && p.y === tile.y && p.x === tile.x - 1);
    const right: boolean = s.pieces.some((p: ExpansionPiece) => p.alive && p.owner === tile.owner && p.y === tile.y && p.x === tile.x + 1);
    return !covered && (!left || !right);
  }
  private makeMahjong(s: ExpansionState): void {
    s.cols = 6; s.rows = 4;
    for (let layer: number = 0; layer <= s.level; layer++) {
      for (let row: number = layer === 0 ? 0 : 1; row < (layer === 0 ? 4 : 3); row++) {
        for (let col: number = layer === 0 ? 0 : layer === 1 ? 1 : 2; col < (layer === 0 ? 6 : layer === 1 ? 5 : 4); col++) {
          const tile: ExpansionPiece = new ExpansionPiece(); tile.id = s.pieces.length; tile.kind = 21; tile.owner = layer; tile.x = col; tile.y = row; s.pieces.push(tile);
        }
      }
    }
    const pairs: number[] = []; for (let i: number = 0; i < s.pieces.length / 2; i++) { pairs.push(1 + this.pick(3 + s.level)); }
    s.pieces.forEach((p: ExpansionPiece, i: number) => { p.color = pairs[Math.floor(i / 2)]; }); s.goal = s.pieces.length; this.arrangeMahjong(s);
  }
  private removalOrder(s: ExpansionState, order: number[], budget: number[]): boolean {
    if (s.pieces.every((p: ExpansionPiece) => !p.alive)) { return true; }
    if (budget[0]-- <= 0) { return false; }
    const free: ExpansionPiece[] = s.pieces.filter((p: ExpansionPiece) => this.tileFree(s, p.id));
    // Prefer a pair in the same row and layer; this preserves even row lengths on a new board.
    for (let preference: number = 0; preference < 2; preference++) {
      for (let i: number = 0; i < free.length; i++) { for (let j: number = i + 1; j < free.length; j++) {
        const a: ExpansionPiece = free[i]; const b: ExpansionPiece = free[j];
        const sameRow: boolean = a.owner === b.owner && a.y === b.y;
        if ((preference === 0) !== sameRow) { continue; }
        a.alive = false; b.alive = false; order.push(a.id, b.id);
        const solved: boolean = this.removalOrder(s, order, budget); a.alive = true; b.alive = true;
        if (solved) { return true; } order.pop(); order.pop();
      } }
    } return false;
  }
  private arrangeMahjong(s: ExpansionState): boolean {
    const remaining: ExpansionPiece[] = s.pieces.filter((p: ExpansionPiece) => p.alive); const colors: number[] = [];
    for (let color: number = 1; color <= 6; color++) {
      const count: number = remaining.filter((p: ExpansionPiece) => p.color === color).length;
      for (let i: number = 0; i < count / 2; i++) { colors.push(color); }
    }
    const order: number[] = [];
    if (!this.removalOrder(s, order, [10000])) { return false; }
    this.shuffle(colors);
    for (let pair: number = 0; pair < colors.length; pair++) { s.pieces[order[pair * 2]].color = colors[pair]; s.pieces[order[pair * 2 + 1]].color = colors[pair]; }
    s.target = order; s.selected = -1; s.data = []; return true;
  }
  private tapMahjong(s: ExpansionState, index: number): void {
    if (!this.tileFree(s, index)) { return; }
    if (s.selected === index) { s.selected = -1; return; }
    const first: ExpansionPiece | undefined = s.pieces.find((p: ExpansionPiece) => p.id === s.selected);
    const second: ExpansionPiece | undefined = s.pieces.find((p: ExpansionPiece) => p.id === index);
    if (first && second && this.tileFree(s, first.id) && first.color === second.color) {
      first.alive = false; second.alive = false; s.selected = -1; s.tray = []; s.moves++; s.score += 100;
      if (s.pieces.every((p: ExpansionPiece) => !p.alive)) { s.outcome = 1; }
    } else { s.selected = index; }
  }
  private tapGroup(s: ExpansionState, index: number): void {
    const group: number[] = this.group(s, index); if (group.length < 2) { return; }
    group.forEach((i: number) => { s.board[i] = 0; }); s.moves++; s.score += group.length * group.length * 10; this.settle(s, true);
    if (s.board.every((v: number) => v === 0)) { s.score += 500; s.outcome = 1; return; }
    if (!s.board.some((v: number, i: number) => v > 0 && this.neighbors(s, i).some((j: number) => s.board[j] === v))) { s.outcome = s.score >= s.goal ? 1 : 2; }
  }
  private tapSlot(s: ExpansionState, col: number): void {
    if (col >= s.cols || s.cursor >= s.target.length || s.board[col] !== 0) { return; }
    let row: number = s.rows - 1; while (row > 0 && s.board[row * s.cols + col] > 0) { row--; }
    s.board[row * s.cols + col] = s.target[s.cursor]; s.cursor++; s.moves++;
    // Cascades terminate because each pass removes at least two occupied cells.
    for (let pass: number = 0; pass < s.board.length / 2; pass++) {
      const at: number = s.board.findIndex((v: number, i: number) => v > 0 && this.neighbors(s, i).some((j: number) => s.board[j] === v));
      if (at < 0) { break; } const group: number[] = this.group(s, at); group.forEach((i: number) => { s.board[i] = 0; }); s.score += group.length * group.length * 20; this.settle(s, false);
    }
    s.next = s.cursor < s.target.length ? s.target[s.cursor] : 0;
    if (s.cursor >= s.target.length) { s.outcome = s.board.every((v: number) => v === 0) ? 1 : 2; }
    else if (s.board.slice(0, s.cols).every((v: number) => v > 0)) { s.outcome = 2; }
  }
  tap(s: ExpansionState, index: number): void {
    if (s.id === 'linktiles') { this.tapLink(s, index); } else if (s.id === 'mahjongsolitaire') { this.tapMahjong(s, index);
    } else if (s.id === 'groupclear') { this.tapGroup(s, index); } else { this.tapSlot(s, index); }
  }
  action(s: ExpansionState): void {
    if (s.id === 'linktiles') {
      const values: number[] = s.board.filter((v: number) => v > 0); this.shuffle(values); let cursor: number = 0;
      s.board = s.board.map((v: number) => v === 0 ? 0 : values[cursor++]); this.ensureLink(s); s.selected = -1; s.data = []; s.tray = this.linkPair(s); s.moves++;
    } else if (s.id === 'mahjongsolitaire' && this.arrangeMahjong(s)) { s.tray = s.target.slice(0, 2); s.moves++; }
  }
  valid(s: ExpansionState): boolean {
    if (s.piles.length !== 0 || s.phase !== 0) { return false; }
    if (s.id === 'mahjongsolitaire') {
      const expected: ExpansionState = new ExpansionState(); expected.id = s.id; expected.level = s.level; this.makeMahjong(expected);
      if (s.cols !== 6 || s.rows !== 4 || s.board.length !== 0 || s.pieces.length !== expected.pieces.length || s.goal !== s.pieces.length ||
        s.selected >= s.pieces.length || s.target.length > s.pieces.length || s.target.length % 2 !== 0 || !V.numbers(s.target, s.target.length, 0, s.pieces.length - 1) ||
        s.data.length !== 0 || s.tray.length > 2 || !V.numbers(s.tray, s.tray.length, 0, s.pieces.length - 1)) { return false; }
      for (let i: number = 0; i < s.pieces.length; i++) {
        const p: ExpansionPiece = s.pieces[i]; const e: ExpansionPiece = expected.pieces[i];
        if (p.id !== e.id || p.kind !== 21 || p.x !== e.x || p.y !== e.y || p.owner !== e.owner || !V.integer(p.color, 1, 3 + s.level)) { return false; }
      }
      return new Set<number>(s.target).size === s.target.length && [1, 2, 3, 4, 5].every((color: number) => s.pieces.filter((p: ExpansionPiece) => p.alive && p.color === color).length % 2 === 0);
    }
    if (s.cols !== 6 || s.pieces.length !== 0 || !V.numbers(s.board, s.cols * s.rows, 0, 3 + s.level)) { return false; }
    if (s.id === 'linktiles') { return s.rows === 4 + s.level * 2 && s.goal === s.board.length && s.selected < s.board.length && s.target.length === 0 &&
      s.tray.length <= 2 && V.numbers(s.tray, s.tray.length, 0, s.board.length - 1) && V.numbers(s.data, s.data.length, 0, (s.cols + 2) * (s.rows + 2) - 1) &&
      [1, 2, 3, 4, 5].every((color: number) => s.board.filter((v: number) => v === color).length % 2 === 0); }
    if (s.id === 'groupclear') { return s.rows === 8 && s.goal === 300 + s.level * 150 && s.target.length === 0 && s.tray.length === 0 && s.data.length === 0; }
    return s.id === 'slotpair' && s.rows === 6 && s.goal === 40 + s.level * 20 && V.numbers(s.target, s.goal, 1, 3 + s.level) && s.cursor <= s.goal &&
      s.next === (s.cursor < s.goal ? s.target[s.cursor] : 0) && s.tray.length === 0 && s.data.length === 0;
  }
}
