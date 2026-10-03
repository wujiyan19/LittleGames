import { ExpansionState, ExpansionPiece } from './ExpansionState';
import { RandomSource } from './RandomSource';
import { ContinuationValidation as V } from '../../common/GameSessionTransfer';

export const SORTING_IDS: string[] = ['buscolor', 'yarn', 'sand', 'untangle'];

export class ExpansionSorting {
  private random: RandomSource;
  constructor(random: RandomSource) { this.random = random; }
  private pick(n: number): number { return Math.min(n - 1, Math.max(0, Math.floor(this.random.next() * n))); }
  private shuffle(values: number[]): void {
    for (let i: number = values.length - 1; i > 0; i--) { const j: number = this.pick(i + 1); const temp: number = values[i]; values[i] = values[j]; values[j] = temp; }
  }
  start(s: ExpansionState): void {
    if (s.id === 'buscolor') { this.startBus(s); } else if (s.id === 'yarn') { this.startYarn(s); }
    else if (s.id === 'sand') { this.startSand(s); } else { this.startKnots(s); }
  }
  private startBus(s: ExpansionState): void {
    s.cols = 3; s.rows = 4; s.goal = 36; s.data = [0, 0, 0];
    for (let i: number = 0; i < 12; i++) {
      const bus: ExpansionPiece = new ExpansionPiece(); bus.id = i; bus.kind = 22; bus.owner = Math.floor(i / 4); bus.color = 1 + this.pick(3 + s.level);
      s.pieces.push(bus); s.target.push(bus.color);
    }
    const cursors: number[] = [0, 0, 0];
    for (let i: number = 0; i < 12; i++) {
      const lanes: number[] = [0, 1, 2].filter((lane: number) => cursors[lane] < 4); const lane: number = lanes[this.pick(lanes.length)];
      cursors[lane]++; s.data.push(lane);
    }
    const launched: number[] = [0, 0, 0];
    for (let batch: number = 0; batch < 12; batch += 3) {
      const colors: number[] = [];
      for (let slot: number = 0; slot < 3; slot++) { const lane: number = s.data[3 + batch + slot]; colors.push(s.pieces[lane * 4 + launched[lane]].color); launched[lane]++; }
      if (s.level === 0) { colors.forEach((color: number) => { s.board.push(color, color, color); }); }
      else { for (let round: number = 0; round < 3; round++) { s.board.push(...colors); } }
    }
  }
  private boardPassengers(s: ExpansionState): void {
    while (s.cursor < s.board.length) {
      const id: number | undefined = s.tray.find((bus: number) => s.pieces[bus].color === s.board[s.cursor]);
      if (id === undefined) { break; } const bus: ExpansionPiece = s.pieces[id]; bus.w++; s.cursor++; s.score += 10;
      if (bus.w === 3) { bus.alive = false; s.tray = s.tray.filter((other: number) => other !== id); s.score += 50; }
    }
    if (s.cursor === s.goal) { s.outcome = 1; }
  }
  private tapBus(s: ExpansionState, lane: number): void {
    if (lane >= 3 || s.data[lane] >= 4 || s.tray.length >= 3) { return; }
    const id: number = lane * 4 + s.data[lane]; s.data[lane]++; s.tray.push(id); s.moves++; this.boardPassengers(s);
  }
  private startYarn(s: ExpansionState): void {
    s.cols = 4 + s.level; s.rows = 8; s.goal = s.cols; s.selected = 0;
    s.board = new Array<number>(s.cols * s.rows).fill(0); s.tray = [0, 0, 0, 0, 0, 0]; s.data = new Array<number>(s.cols).fill(0);
    s.target = new Array<number>(s.cols).fill(0).map((v: number, i: number) => i + 1); this.shuffle(s.target);
    const heights: number[] = new Array<number>(s.cols).fill(0);
    // Build from the last color to the first. Removing each exposed color reverses this construction.
    for (let stage: number = s.target.length - 1; stage >= 0; stage--) {
      for (let unit: number = 0; unit < 8; unit++) {
        const columns: number[] = heights.map((v: number, i: number) => i).filter((i: number) => heights[i] < 8);
        const col: number = columns[this.pick(columns.length)]; s.board[col * 8 + heights[col]] = s.target[stage]; heights[col]++;
      }
    }
  }
  yarnHeight(s: ExpansionState, col: number): number { return s.board.slice(col * 8, col * 8 + 8).filter((v: number) => v > 0).length; }
  private tapYarn(s: ExpansionState, col: number): void {
    if (col >= s.cols || s.selected < 0 || s.selected > 2) { return; }
    const height: number = this.yarnHeight(s, col); if (height === 0) { return; }
    const color: number = s.board[col * 8 + height - 1]; const reel: number = s.selected * 2;
    if (s.tray[reel] !== 0 && s.tray[reel] !== color) { return; }
    let run: number = 0;
    while (height - run > 0 && s.board[col * 8 + height - run - 1] === color && run < 8 - s.tray[reel + 1]) { run++; }
    for (let i: number = 0; i < run; i++) { s.board[col * 8 + height - i - 1] = 0; }
    s.tray[reel] = color; s.tray[reel + 1] += run; s.moves++; s.score += run * 30;
    if (s.tray[reel + 1] === 8) { s.data[color - 1] = 8; s.tray[reel] = 0; s.tray[reel + 1] = 0; s.cursor++; s.score += 100; }
    if (s.cursor === s.goal) { s.outcome = 1; }
  }
  private startSand(s: ExpansionState): void {
    s.cols = 8; s.rows = 6 + s.level * 2; s.goal = s.cols * s.rows; s.selected = 0;
    for (let color: number = 1; color <= 3 + s.level; color++) { for (let i: number = 0; i < 16; i++) { s.board.push(color); } }
    this.shuffle(s.board); s.data = new Array<number>(3 + s.level).fill(0); s.target = new Array<number>(3 + s.level).fill(16);
  }
  private tapSand(s: ExpansionState, at: number): void {
    if (at >= s.board.length || s.board[at] !== s.selected + 1) { return; }
    const color: number = s.board[at]; const queue: number[] = [at]; const capacity: number = 8 - s.data[color - 1] % 8;
    const seen: boolean[] = new Array<boolean>(s.board.length).fill(false); seen[at] = true;
    for (let q: number = 0; q < queue.length && queue.length < capacity; q++) {
      const cell: number = queue[q]; const neighbors: number[] = [];
      if (cell >= s.cols) { neighbors.push(cell - s.cols); } if (cell + s.cols < s.board.length) { neighbors.push(cell + s.cols); }
      if (cell % s.cols > 0) { neighbors.push(cell - 1); } if (cell % s.cols < s.cols - 1) { neighbors.push(cell + 1); }
      for (let n: number = 0; n < neighbors.length && queue.length < capacity; n++) {
        const next: number = neighbors[n]; if (!seen[next] && s.board[next] === color) { seen[next] = true; queue.push(next); }
      }
    }
    queue.forEach((i: number) => { s.board[i] = 0; }); s.data[color - 1] += queue.length; s.cursor += queue.length; s.moves++; s.score += queue.length * 10;
    if (s.data[color - 1] % 8 === 0) { s.score += 50; }
    for (let col: number = 0; col < s.cols; col++) {
      const grains: number[] = [];
      for (let row: number = s.rows - 1; row >= 0; row--) { if (s.board[row * s.cols + col] > 0) { grains.push(s.board[row * s.cols + col]); } s.board[row * s.cols + col] = 0; }
      for (let i: number = 0; i < grains.length; i++) { s.board[(s.rows - 1 - i) * s.cols + col] = grains[i]; }
    }
    if (s.cursor === s.goal) { s.outcome = 1; }
  }
  private knotGraph(s: ExpansionState): void {
    const count: number = 6 + s.level;
    for (let i: number = 1; i < count; i++) { s.board.push(0, i, i, i === count - 1 ? 1 : i + 1); }
  }
  private startKnots(s: ExpansionState): void {
    s.cols = 6 + s.level; s.rows = 1; this.knotGraph(s); s.target = [180, 230];
    for (let i: number = 0; i < s.cols - 1; i++) {
      const angle: number = i * Math.PI * 2 / (s.cols - 1) - Math.PI / 2;
      s.target.push(Math.round(180 + Math.cos(angle) * 130), Math.round(230 + Math.sin(angle) * 170));
    }
    const order: number[] = s.target.map((v: number, i: number) => i).filter((i: number) => i % 2 === 0); this.shuffle(order);
    for (let i: number = 0; i < s.cols; i++) {
      const node: ExpansionPiece = new ExpansionPiece(); node.id = i; node.kind = 23; node.x = s.target[order[i]]; node.y = s.target[order[i] + 1]; s.pieces.push(node);
    }
    if (this.crossings(s) === 0) {
      const first: ExpansionPiece = s.pieces[0]; const next: ExpansionPiece = s.pieces[1]; const x: number = first.x; const y: number = first.y;
      first.x = next.x; first.y = next.y; next.x = x; next.y = y;
    }
    s.data = [this.crossings(s)];
  }
  private orientation(a: ExpansionPiece, b: ExpansionPiece, c: ExpansionPiece): number { return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x); }
  crossingEdges(s: ExpansionState): number[] {
    const result: number[] = [];
    for (let i: number = 0; i < s.board.length; i += 2) {
      for (let j: number = i + 2; j < s.board.length; j += 2) {
        const a: number = s.board[i]; const b: number = s.board[i + 1]; const c: number = s.board[j]; const d: number = s.board[j + 1];
        if (a === c || a === d || b === c || b === d) { continue; }
        const p: ExpansionPiece = s.pieces[a]; const q: ExpansionPiece = s.pieces[b]; const r: ExpansionPiece = s.pieces[c]; const t: ExpansionPiece = s.pieces[d];
        const u: number = this.orientation(p, q, r); const v: number = this.orientation(p, q, t);
        const w: number = this.orientation(r, t, p); const z: number = this.orientation(r, t, q);
        // Include touching/overlapping nonadjacent edges, so a collapsed graph cannot win.
        if (u * v <= 0 && w * z <= 0 && Math.max(p.x, q.x) >= Math.min(r.x, t.x) && Math.max(r.x, t.x) >= Math.min(p.x, q.x) &&
          Math.max(p.y, q.y) >= Math.min(r.y, t.y) && Math.max(r.y, t.y) >= Math.min(p.y, q.y)) { result.push(i, j); }
      }
    } return result;
  }
  crossings(s: ExpansionState): number { return this.crossingEdges(s).length / 2; }
  tap(s: ExpansionState, index: number): void {
    if (s.id === 'buscolor') { this.tapBus(s, index); } else if (s.id === 'yarn') { this.tapYarn(s, index); }
    else if (s.id === 'sand') { this.tapSand(s, index); }
    else if (index < s.pieces.length && s.selected !== index) { s.selected = index; s.moves++; }
  }
  choose(s: ExpansionState, index: number): void {
    if ((s.id === 'yarn' && index < 3) || (s.id === 'sand' && index < s.data.length)) { s.selected = index; }
  }
  aim(s: ExpansionState, x: number, y: number): void {
    if (s.id !== 'untangle' || s.selected < 0) { return; }
    const nextX: number = Math.max(22, Math.min(338, x)); const nextY: number = Math.max(22, Math.min(438, y));
    if (s.pieces.some((p: ExpansionPiece) => p.id !== s.selected && Math.hypot(p.x - nextX, p.y - nextY) < 36)) { return; }
    const node: ExpansionPiece = s.pieces[s.selected]; node.x = nextX; node.y = nextY; s.data[0] = this.crossings(s);
    if (s.data[0] === 0) { s.outcome = 1; s.score = Math.max(100, 1000 - s.moves * 5); s.selected = -1; }
  }
  valid(s: ExpansionState): boolean {
    if (s.phase !== 0 || s.piles.length !== 0) { return false; }
    if (s.id === 'buscolor') {
      if (s.cols !== 3 || s.rows !== 4 || s.goal !== 36 || s.pieces.length !== 12 || !V.numbers(s.board, 36, 1, 3 + s.level) ||
        !V.numbers(s.target, 12, 1, 3 + s.level) || !V.numbers(s.data, 15, 0, 4) || s.data.slice(3).some((v: number) => v > 2) || s.cursor > 36 ||
        s.tray.length > 3 || !V.numbers(s.tray, s.tray.length, 0, 11) || new Set<number>(s.tray).size !== s.tray.length) { return false; }
      let boarded: number = 0;
      for (let i: number = 0; i < 12; i++) {
        const p: ExpansionPiece = s.pieces[i]; const launched: boolean = i % 4 < s.data[Math.floor(i / 4)]; boarded += p.w;
        if (p.id !== i || p.kind !== 22 || p.owner !== Math.floor(i / 4) || p.color !== s.target[i] || !V.integer(p.w, 0, 3) ||
          p.alive !== (p.w < 3) || (!launched && p.w !== 0) || (launched && p.alive) !== s.tray.includes(i)) { return false; }
      }
      return boarded === s.cursor && [1, 2, 3, 4, 5].every((color: number) => s.board.filter((v: number) => v === color).length === s.target.filter((v: number) => v === color).length * 3 &&
        s.board.slice(0, s.cursor).filter((v: number) => v === color).length === s.pieces.filter((p: ExpansionPiece) => p.color === color).reduce((sum: number, p: ExpansionPiece) => sum + p.w, 0));
    }
    if (s.id === 'yarn') {
      if (s.cols !== 4 + s.level || s.rows !== 8 || s.goal !== s.cols || s.pieces.length !== 0 || !V.numbers(s.board, s.cols * 8, 0, s.cols) ||
        !V.numbers(s.target, s.cols, 1, s.cols) || new Set<number>(s.target).size !== s.cols || !V.numbers(s.tray, 6, 0, 7) ||
        !V.numbers(s.data, s.cols, 0, 8) || !V.integer(s.selected, 0, 2) || s.cursor !== s.data.filter((v: number) => v === 8).length) { return false; }
      for (let reel: number = 0; reel < 3; reel++) { if (s.tray[reel * 2] > s.cols || (s.tray[reel * 2] === 0) !== (s.tray[reel * 2 + 1] === 0)) { return false; } }
      for (let col: number = 0; col < s.cols; col++) { const height: number = this.yarnHeight(s, col); if (s.board.slice(col * 8 + height, col * 8 + 8).some((v: number) => v !== 0)) { return false; } }
      return s.data.every((v: number) => v === 0 || v === 8) && s.data.every((v: number, i: number) => v + s.board.filter((color: number) => color === i + 1).length +
        [0, 1, 2].reduce((sum: number, reel: number) => sum + (s.tray[reel * 2] === i + 1 ? s.tray[reel * 2 + 1] : 0), 0) === 8);
    }
    if (s.id === 'sand') {
      return s.cols === 8 && s.rows === 6 + s.level * 2 && s.goal === s.cols * s.rows && s.pieces.length === 0 && s.tray.length === 0 &&
        V.numbers(s.board, s.goal, 0, 3 + s.level) && V.numbers(s.target, 3 + s.level, 16, 16) && V.numbers(s.data, 3 + s.level, 0, 16) &&
        V.integer(s.selected, 0, s.data.length - 1) && s.cursor === s.data.reduce((sum: number, v: number) => sum + v, 0) &&
        s.data.every((v: number, i: number) => v + s.board.filter((color: number) => color === i + 1).length === 16);
    }
    const expected: ExpansionState = new ExpansionState(); expected.level = s.level; this.knotGraph(expected);
    return s.id === 'untangle' && s.cols === 6 + s.level && s.rows === 1 && s.pieces.length === s.cols && s.board.join(',') === expected.board.join(',') &&
      s.tray.length === 0 && V.numbers(s.target, s.cols * 2, 22, 438) && s.selected < s.cols && V.numbers(s.data, 1, 0, 200) &&
      s.pieces.every((p: ExpansionPiece, i: number) => p.id === i && p.kind === 23 && p.alive && p.x >= 22 && p.x <= 338 && p.y >= 22 && p.y <= 438 &&
        !s.pieces.some((q: ExpansionPiece) => p.id !== q.id && Math.hypot(p.x - q.x, p.y - q.y) < 36)) && s.data[0] === this.crossings(s);
  }
}
