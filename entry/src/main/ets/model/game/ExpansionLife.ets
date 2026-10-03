import { ExpansionState, ExpansionPiece } from './ExpansionState';
import { RandomSource } from './RandomSource';
import { ContinuationValidation as V } from '../../common/GameSessionTransfer';

export const LIFE_IDS: string[] = ['farm', 'decorate', 'fishing'];
export class ExpansionLife {
  private random: RandomSource;
  constructor(random: RandomSource) { this.random = random; }
  start(s: ExpansionState): void {
    s.cols = s.id === 'decorate' ? 5 : 3; s.rows = s.cols; s.goal = s.id === 'farm' ? 12 : s.id === 'decorate' ? 4 : 5; s.selected = 0;
    if (s.id === 'fishing') { s.data = [0, 0, 50, 0]; s.selected = -1; const fish: ExpansionPiece = new ExpansionPiece(); fish.id = 0; fish.kind = 60; fish.x = 180; fish.y = 240; fish.r = 24; fish.vx = 50; s.pieces.push(fish); }
    else { s.board = new Array<number>(s.cols * s.rows).fill(0); s.data = [s.id === 'farm' ? 12 : 20, 0]; }
  }
  choose(s: ExpansionState, tool: number): void { if (s.id === 'farm' && tool < 3) { s.selected = tool; } if (s.id === 'decorate' && tool < 5) { s.selected = tool; } }
  tap(s: ExpansionState, at: number): void {
    if (s.id === 'fishing') { this.fishingTap(s, at); return; }
    if (s.id === 'farm') {
      if (at === 900) { s.board = s.board.map((v: number) => v === 2 ? 3 : v === 1 ? 0 : v); s.data[1]++; s.moves++; return; }
      if (at >= 9) { return; }
      if (s.selected === 0 && s.board[at] === 0 && s.data[0] >= 2) { s.board[at] = 1; s.data[0] -= 2; }
      else if (s.selected === 1 && s.board[at] === 1) { s.board[at] = 2; }
      else if (s.selected === 2 && s.board[at] === 3) { s.board[at] = 0; s.data[0] += 5; s.cursor++; s.score += 100; if (s.cursor === s.goal) { s.outcome = 1; } }
      else { return; } s.moves++; return;
    }
    if (at >= 25 || s.selected < 0 || s.selected > 4) { return; }
    const x: number = at % 5; const y: number = Math.floor(at / 5); const costs: number[] = [6, 3, 3, 2];
    if (s.selected === 4) {
      const p: ExpansionPiece | undefined = s.pieces.find((piece: ExpansionPiece) => x >= piece.x && x < piece.x + piece.w && y >= piece.y && y < piece.y + piece.h);
      if (!p) { return; } s.data[0] += costs[p.color - 1];
      for (let row: number = p.y; row < p.y + p.h; row++) { for (let col: number = p.x; col < p.x + p.w; col++) { s.board[row * 5 + col] = 0; } }
      s.pieces = s.pieces.filter((piece: ExpansionPiece) => piece.id !== p.id);
    } else {
      const w: number = s.selected === 0 ? 2 : 1; const h: number = s.selected === 2 ? 2 : 1;
      if (x + w > 5 || y + h > 5 || s.data[0] < costs[s.selected]) { return; }
      const cells: number[] = []; for (let row: number = 0; row < h; row++) { for (let col: number = 0; col < w; col++) { cells.push((y + row) * 5 + x + col); } }
      if (cells.some((cell: number) => s.board[cell] > 0)) { return; }
      const p: ExpansionPiece = new ExpansionPiece(); p.id = s.serial++; p.kind = 61; p.color = s.selected + 1; p.x = x; p.y = y; p.w = w; p.h = h; s.pieces.push(p); cells.forEach((cell: number) => { s.board[cell] = p.color; }); s.data[0] -= costs[s.selected];
    }
    s.moves++; const sofa: ExpansionPiece[] = s.pieces.filter((p: ExpansionPiece) => p.color === 1); const plants: number = s.pieces.filter((p: ExpansionPiece) => p.color === 3).length;
    const tableNear: boolean = s.pieces.some((table: ExpansionPiece) => table.color === 2 && sofa.some((p: ExpansionPiece) => Math.abs(table.y - p.y) <= 1 && table.x >= p.x - 1 && table.x <= p.x + p.w));
    s.target = [sofa.length > 0 ? 1 : 0, plants >= 2 ? 1 : 0, s.pieces.some((p: ExpansionPiece) => p.color === 4) ? 1 : 0, tableNear ? 1 : 0];
    s.cursor = s.target.reduce((sum: number, v: number) => sum + v, 0); s.score = s.cursor * 200 + s.data[0] * 25; if (s.cursor === 4) { s.outcome = 1; }
  }
  private fishingTap(s: ExpansionState, at: number): void {
    if (at === 0 && s.data[0] === 0) { s.data[0] = 1; s.cooldown = 1.5 + this.random.next() * 2.5; s.phase = 1; s.selected = -1; s.pieces[0].color = 1 + Math.min(5, Math.max(0, Math.floor(this.random.next() * 6))); }
    else if (at === 0 && s.data[0] === 2) { s.data[0] = 3; s.pieces[0].vx = 50; s.pieces[0].vy = 0; s.selected = -1; }
    else if (at === 1 && s.data[0] === 3) { s.selected = 0; }
    else if (at === 2) { s.selected = -1; }
  }
  activate(s: ExpansionState): void { if (s.id === 'fishing') { this.fishingTap(s, 0); } }
  release(s: ExpansionState): void { if (s.id === 'fishing') { s.selected = -1; } }
  private miss(s: ExpansionState): void { s.errors++; s.data[0] = 0; s.phase = 0; s.selected = -1; if (s.errors >= 3) { s.outcome = 2; } }
  step(s: ExpansionState, dt: number): void {
    s.time += dt; const fish: ExpansionPiece = s.pieces[0]; fish.x = 180 + Math.sin(s.time * 2) * 90;
    if (s.data[0] === 1) { s.cooldown = Math.max(0, s.cooldown - dt); if (s.cooldown === 0) { s.data[0] = 2; s.cooldown = 1.1 - s.level * 0.15; } }
    else if (s.data[0] === 2) { s.cooldown = Math.max(0, s.cooldown - dt); if (s.cooldown === 0) { this.miss(s); } }
    else if (s.data[0] === 3) {
      fish.vx += ((s.selected === 0 ? 25 + s.level * 3 : -17) + Math.sin(s.time * 3) * 8) * dt;
      fish.vy = Math.max(0, fish.vy + (s.selected === 0 ? 22 : -3) * dt); s.data[2] = Math.max(0, Math.min(100, Math.round(fish.vx))); s.data[3] = Math.min(100, Math.round(fish.vy));
      if (fish.vx < 5 || fish.vx > 95) { this.miss(s); }
      else if (fish.vy >= 100) { s.cursor++; s.score += fish.color * 100; s.moves++; s.data[0] = 0; s.phase = 0; s.selected = -1; if (s.cursor === s.goal) { s.outcome = 1; } }
    }
  }
  valid(s: ExpansionState): boolean {
    if (!LIFE_IDS.includes(s.id) || s.cols !== (s.id === 'decorate' ? 5 : 3) || s.rows !== s.cols || s.piles.length !== 0 || s.tray.length !== 0) { return false; }
    if (s.id === 'fishing') { return s.goal === 5 && s.board.length === 0 && s.target.length === 0 && V.numbers(s.data, 4, 0, 100) && s.data[0] <= 3 && s.cursor <= 5 && s.errors <= 3 && s.selected <= 0 && s.pieces.length === 1 && s.pieces[0].kind === 60 && s.pieces[0].x >= 90 && s.pieces[0].x <= 270; }
    if (s.phase !== 0 || !V.numbers(s.data, 2, 0, 10000)) { return false; }
    if (s.id === 'farm') { return s.goal === 12 && V.numbers(s.board, 9, 0, 3) && V.integer(s.selected, 0, 2) && s.cursor <= 12 && s.pieces.length === 0 && s.target.length === 0; }
    if (s.goal !== 4 || !V.numbers(s.board, 25, 0, 4) || s.target.length !== 0 && !V.numbers(s.target, 4, 0, 1) || !V.integer(s.selected, 0, 4) || s.cursor > 4) { return false; }
    const cells: number[] = []; let spending: number = 0;
    for (let i: number = 0; i < s.pieces.length; i++) {
      const p: ExpansionPiece = s.pieces[i]; if (p.kind !== 61 || !V.integer(p.color, 1, 4) || p.w !== (p.color === 1 ? 2 : 1) || p.h !== (p.color === 3 ? 2 : 1) || !V.integer(p.x, 0, 5 - p.w) || !V.integer(p.y, 0, 5 - p.h)) { return false; }
      spending += [6, 3, 3, 2][p.color - 1]; for (let row: number = p.y; row < p.y + p.h; row++) { for (let col: number = p.x; col < p.x + p.w; col++) { const cell: number = row * 5 + col; if (cells.includes(cell) || s.board[cell] !== p.color) { return false; } cells.push(cell); } }
    }
    return s.data[0] + spending === 20 && s.board.every((v: number, i: number) => (v > 0) === cells.includes(i));
  }
}
