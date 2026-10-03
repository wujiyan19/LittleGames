import { ExpansionState, ExpansionPiece, BLOCK_SHAPES, BlockShape } from './ExpansionState';
import { RandomSource } from './RandomSource';

/** Six different puzzle rules share state transport, never their move rules. */
export class ExpansionPuzzle {
  private random: RandomSource;
  constructor(random: RandomSource) { this.random = random; }
  private pick(count: number): number { return Math.min(count - 1, Math.max(0, Math.floor(this.random.next() * count))); }

  start(s: ExpansionState): void {
    if (s.id === 'blockfit') {
      s.cols = 6 + s.level; s.rows = s.cols; s.board = new Array<number>(s.cols * s.rows).fill(0);
      s.goal = 800 + s.level * 400; this.refill(s);
    } else if (s.id === 'tilestack') { this.makeStack(s);
    } else if (s.id === 'watersort') { this.makeWater(s);
    } else if (s.id === 'arrowclear') { this.makeArrows(s);
    } else if (s.id === 'screwout') { this.makeScrews(s);
    } else if (s.id === 'parkingjam') { this.makeParking(s); }
  }
  tap(s: ExpansionState, index: number): void {
    if (s.id === 'blockfit') { this.place(s, index);
    } else if (s.id === 'tilestack') { this.popTile(s, index);
    } else if (s.id === 'watersort') { this.pour(s, index);
    } else if (s.id === 'arrowclear') { this.clearArrow(s, index);
    } else if (s.id === 'screwout') { this.unscrew(s, index);
    } else if (s.id === 'parkingjam') { this.drive(s, index); }
  }
  private refill(s: ExpansionState): void {
    s.tray = [this.pick(7 + s.level), this.pick(7 + s.level), this.pick(7 + s.level)]; s.selected = 0;
  }
  fits(s: ExpansionState, shapeId: number, index: number): boolean {
    if (shapeId < 0 || shapeId >= BLOCK_SHAPES.length || index < 0 || index >= s.board.length) { return false; }
    const shape: BlockShape = BLOCK_SHAPES[shapeId]; const x: number = index % s.cols; const y: number = Math.floor(index / s.cols);
    if (x + shape.cols > s.cols || y + shape.rows > s.rows) { return false; }
    return shape.cells.every((cell: number) => s.board[(y + Math.floor(cell / shape.cols)) * s.cols + x + cell % shape.cols] === 0);
  }
  private place(s: ExpansionState, index: number): void {
    if (s.selected < 0 || !this.fits(s, s.tray[s.selected], index)) { return; }
    const shape: BlockShape = BLOCK_SHAPES[s.tray[s.selected]]; const x: number = index % s.cols; const y: number = Math.floor(index / s.cols);
    shape.cells.forEach((cell: number) => { s.board[(y + Math.floor(cell / shape.cols)) * s.cols + x + cell % shape.cols] = s.selected + 1; });
    s.tray[s.selected] = -1; s.moves++; s.score += shape.cells.length * 10;
    const cleared: boolean[] = new Array<boolean>(s.board.length).fill(false); let lines: number = 0;
    for (let i: number = 0; i < s.cols; i++) {
      let rowFull: boolean = true; let colFull: boolean = true;
      for (let j: number = 0; j < s.cols; j++) { rowFull = rowFull && s.board[i * s.cols + j] > 0; colFull = colFull && s.board[j * s.cols + i] > 0; }
      if (rowFull) { lines++; for (let j: number = 0; j < s.cols; j++) { cleared[i * s.cols + j] = true; } }
      if (colFull) { lines++; for (let j: number = 0; j < s.cols; j++) { cleared[j * s.cols + i] = true; } }
    }
    cleared.forEach((value: boolean, i: number) => { if (value) { s.board[i] = 0; } }); s.score += lines * lines * 100;
    if (s.score >= s.goal) { s.outcome = 1; return; }
    if (s.tray.every((value: number) => value < 0)) { this.refill(s); }
    s.selected = s.tray.findIndex((value: number) => value >= 0);
    let possible: boolean = false;
    for (let i: number = 0; i < s.board.length && !possible; i++) { possible = s.tray.some((shapeId: number) => this.fits(s, shapeId, i)); }
    if (!possible) { s.outcome = 2; }
  }
  private makeStack(s: ExpansionState): void {
    s.cols = 5; s.rows = 4 + s.level; const count: number = s.cols * s.rows;
    const depth: number = 3; s.board = new Array<number>(count * depth).fill(0);
    const heights: number[] = new Array<number>(count).fill(0); const order: number[] = [];
    // Every three insertions share a symbol. Reverse insertion is a guaranteed solution.
    for (let group: number = 0; group < count; group++) {
      const color: number = 1 + this.pick(4 + s.level);
      for (let k: number = 0; k < 3; k++) {
        const free: number[] = [];
        for (let c: number = 0; c < count; c++) { if (heights[c] < depth) { free.push(c); } }
        const col: number = free[this.pick(free.length)]; s.board[heights[col] * count + col] = color; heights[col]++; order.push(col);
      }
    }
    s.target = order.reverse(); s.goal = count * 3;
  }
  top(s: ExpansionState, index: number): number {
    const count: number = s.cols * s.rows;
    if (index < 0 || index >= count) { return -1; }
    for (let layer: number = 2; layer >= 0; layer--) { if (s.board[layer * count + index] > 0) { return layer * count + index; } }
    return -1;
  }
  private popTile(s: ExpansionState, index: number): void {
    const at: number = this.top(s, index); if (at < 0) { return; }
    const color: number = s.board[at]; s.board[at] = 0; s.tray.push(color); s.moves++;
    if (s.tray.filter((v: number) => v === color).length === 3) { s.tray = s.tray.filter((v: number) => v !== color); s.score += 100; }
    if (s.board.every((v: number) => v === 0)) { s.outcome = s.tray.length === 0 ? 1 : 2; }
    else if (s.tray.length >= 7) { s.outcome = 2; }
  }
  height(s: ExpansionState, tube: number): number {
    let n: number = 0; while (n < 4 && s.board[tube * 4 + n] > 0) { n++; } return n;
  }
  waterSolved(s: ExpansionState): boolean {
    for (let i: number = 0; i < s.cols; i++) {
      const n: number = this.height(s, i); if (n !== 0 && (n !== 4 || !s.board.slice(i * 4, i * 4 + 4).every((v: number) => v === s.board[i * 4]))) { return false; }
    }
    return true;
  }
  private makeWater(s: ExpansionState): void {
    const colors: number = 3 + s.level; s.cols = colors + 2; s.rows = 4;
    s.board = new Array<number>(s.cols * 4).fill(0);
    for (let c: number = 0; c < colors; c++) { for (let j: number = 0; j < 4; j++) { s.board[c * 4 + j] = c + 1; } }
    const reverse: number[] = [];
    // Reverse legal single-layer pours from a solved board. Each inverse pour remains legal.
    for (let step: number = 0; step < 80 + 30 * s.level; step++) {
      const pairs: number[] = [];
      for (let from: number = 0; from < s.cols; from++) {
        const n: number = this.height(s, from); if (n === 0 || (n > 1 && s.board[from * 4 + n - 1] !== s.board[from * 4 + n - 2])) { continue; }
        for (let to: number = 0; to < s.cols; to++) { if (to !== from && this.height(s, to) < 4) { pairs.push(from * s.cols + to); } }
      }
      if (pairs.length === 0) { break; }
      const pair: number = pairs[this.pick(pairs.length)]; const from: number = Math.floor(pair / s.cols); const to: number = pair % s.cols;
      const n: number = this.height(s, from); const m: number = this.height(s, to);
      s.board[to * 4 + m] = s.board[from * 4 + n - 1]; s.board[from * 4 + n - 1] = 0; reverse.push(to, from);
    }
    if (this.waterSolved(s)) {
      // A deterministic, solvable fallback also handles a constant random source.
      s.board = new Array<number>(s.cols * 4).fill(0);
      for (let c: number = 0; c < colors; c++) { for (let j: number = 0; j < 4; j++) { s.board[c * 4 + j] = c + 1; } }
      s.board[colors * 4] = 1; s.board[3] = 2; s.board[7] = 0; s.target = [0, 1, colors, 0];
    } else {
      for (let i: number = reverse.length - 2; i >= 0; i -= 2) { s.target.push(reverse[i], reverse[i + 1]); }
    }
  }
  private pour(s: ExpansionState, tube: number): void {
    if (tube >= s.cols) { return; }
    if (s.selected < 0) { if (this.height(s, tube) > 0) { s.selected = tube; } return; }
    if (s.selected === tube) { s.selected = -1; return; }
    const from: number = s.selected; const n: number = this.height(s, from); const m: number = this.height(s, tube);
    if (n === 0) { s.selected = m > 0 ? tube : -1; return; }
    if (m >= 4 || (m > 0 && s.board[tube * 4 + m - 1] !== s.board[from * 4 + n - 1])) { s.selected = tube; return; }
    s.board[tube * 4 + m] = s.board[from * 4 + n - 1]; s.board[from * 4 + n - 1] = 0; s.selected = -1; s.moves++;
    s.score = s.board.filter((v: number) => v > 0).length * 10;
    if (this.waterSolved(s)) { s.outcome = 1; s.score += Math.max(100, 1000 - s.moves * 5); }
  }
  private rayClear(board: number[], cols: number, rows: number, index: number, direction: number): boolean {
    const dx: number[] = [0, 1, 0, -1]; const dy: number[] = [-1, 0, 1, 0];
    let x: number = index % cols + dx[direction]; let y: number = Math.floor(index / cols) + dy[direction];
    while (x >= 0 && x < cols && y >= 0 && y < rows) { if (board[y * cols + x] > 0) { return false; } x += dx[direction]; y += dy[direction]; } return true;
  }
  private makeArrows(s: ExpansionState): void {
    s.cols = 5 + s.level; s.rows = s.cols; const n: number = s.cols * s.rows;
    const remaining: number[] = new Array<number>(n).fill(1); s.board = new Array<number>(n).fill(0);
    for (let step: number = 0; step < n; step++) {
      const candidates: number[] = [];
      for (let i: number = 0; i < n; i++) { if (remaining[i] > 0) { for (let d: number = 0; d < 4; d++) { if (this.rayClear(remaining, s.cols, s.rows, i, d)) { candidates.push(i * 4 + d); } } } }
      const move: number = candidates[this.pick(candidates.length)]; const i: number = Math.floor(move / 4);
      s.board[i] = move % 4 + 1; remaining[i] = 0; s.target.push(i);
    }
  }
  private clearArrow(s: ExpansionState, index: number): void {
    if (index >= s.board.length || s.board[index] === 0) { return; }
    if (!this.rayClear(s.board, s.cols, s.rows, index, s.board[index] - 1)) { s.errors++; if (s.errors === 3) { s.outcome = 2; } return; }
    s.board[index] = 0; s.moves++; s.score += 50; if (s.board.every((v: number) => v === 0)) { s.outcome = 1; }
  }
  private makeScrews(s: ExpansionState): void {
    s.cols = 3; s.rows = 3; const plates: number = 3 + s.level;
    for (let p: number = 0; p < plates; p++) {
      const plate: ExpansionPiece = new ExpansionPiece(); plate.id = p; plate.kind = 0; plate.x = 22 + p * 22;
      plate.y = 48 + p * 52; plate.w = 220; plate.h = 96; plate.color = p + 1; s.pieces.push(plate);
      for (let j: number = 0; j < 3; j++) {
        const screw: ExpansionPiece = new ExpansionPiece(); screw.id = plates + p * 3 + j; screw.kind = 1;
        screw.owner = p; screw.x = plate.x + 26 + j * 78; screw.y = plate.y + 30; screw.r = 16; screw.color = p + 1; s.pieces.push(screw);
      }
    }
    s.target = s.pieces.filter((p: ExpansionPiece) => p.kind === 1).sort((a: ExpansionPiece, b: ExpansionPiece) => b.owner - a.owner).map((p: ExpansionPiece) => p.id);
  }
  screwFree(s: ExpansionState, screw: ExpansionPiece): boolean {
    return screw.alive && screw.kind === 1 && !s.pieces.some((p: ExpansionPiece) => p.kind === 0 && p.alive && p.id > screw.owner &&
      screw.x >= p.x && screw.x <= p.x + p.w && screw.y >= p.y && screw.y <= p.y + p.h);
  }
  private unscrew(s: ExpansionState, id: number): void {
    const screw: ExpansionPiece | undefined = s.pieces.find((p: ExpansionPiece) => p.id === id);
    if (!screw || !this.screwFree(s, screw) || s.tray.length >= 3) { return; }
    screw.alive = false; s.tray.push(screw.id); s.moves++; s.score += 30;
    if (!s.pieces.some((p: ExpansionPiece) => p.kind === 1 && p.alive && p.owner === screw.owner)) {
      const plate: ExpansionPiece | undefined = s.pieces.find((p: ExpansionPiece) => p.kind === 0 && p.id === screw.owner);
      if (plate) { plate.alive = false; }
      s.tray = s.tray.filter((parked: number) => s.pieces.find((p: ExpansionPiece) => p.id === parked)?.owner !== screw.owner); s.score += 100;
    }
    if (!s.pieces.some((p: ExpansionPiece) => p.kind === 0 && p.alive)) { s.outcome = 1; }
  }
  private carClear(s: ExpansionState, car: ExpansionPiece): boolean {
    const grid: number[] = new Array<number>(s.cols * s.rows).fill(0);
    s.pieces.forEach((other: ExpansionPiece) => { if (other.alive && other.id !== car.id) {
      for (let y: number = other.y; y < other.y + other.h; y++) { for (let x: number = other.x; x < other.x + other.w; x++) { grid[y * s.cols + x] = 1; } }
    } });
    const index: number = car.color === 0 ? car.y * s.cols + car.x : car.color === 1 ? car.y * s.cols + car.x + car.w - 1 :
      car.color === 2 ? (car.y + car.h - 1) * s.cols + car.x : car.y * s.cols + car.x;
    return this.rayClear(grid, s.cols, s.rows, index, car.color);
  }
  private makeParking(s: ExpansionState): void {
    s.cols = 6 + s.level; s.rows = s.cols;
    for (let attempt: number = 0; attempt < 250 && s.pieces.length < 9 + 4 * s.level; attempt++) {
      const car: ExpansionPiece = new ExpansionPiece(); car.id = s.pieces.length; car.kind = 2; car.color = this.pick(4);
      car.w = car.color % 2 === 1 ? 2 + this.pick(2) : 1; car.h = car.color % 2 === 0 ? 2 + this.pick(2) : 1;
      car.x = this.pick(s.cols - car.w + 1); car.y = this.pick(s.rows - car.h + 1);
      const overlap: boolean = s.pieces.some((p: ExpansionPiece) => car.x < p.x + p.w && car.x + car.w > p.x && car.y < p.y + p.h && car.y + car.h > p.y);
      if (!overlap && this.carClear(s, car)) { s.pieces.push(car); }
    }
    s.target = s.pieces.map((p: ExpansionPiece) => p.id).reverse();
  }
  private drive(s: ExpansionState, id: number): void {
    const car: ExpansionPiece | undefined = s.pieces.find((p: ExpansionPiece) => p.id === id);
    if (!car || !car.alive) { return; }
    if (!this.carClear(s, car)) { s.errors++; return; }
    car.alive = false; s.moves++; s.score += 100; if (s.pieces.every((p: ExpansionPiece) => !p.alive)) { s.outcome = 1; }
  }
}
