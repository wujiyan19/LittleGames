import { ExpansionState, ExpansionPiece } from './ExpansionState';
import { RandomSource } from './RandomSource';

export class ExpansionAdventure {
  private random: RandomSource;
  constructor(random: RandomSource) { this.random = random; }
  private pick(n: number): number { return Math.min(n - 1, Math.max(0, Math.floor(this.random.next() * n))); }
  start(s: ExpansionState): void {
    if (s.id === 'sokoban') { this.makeWarehouse(s);
    } else if (s.id === 'pipes') { this.makePipes(s);
    } else if (s.id === 'differences') {
      s.cols = 5; s.rows = 5; s.board = new Array<number>(25).fill(0).map(() => 1 + this.pick(6));
      const candidates: number[] = new Array<number>(25).fill(0).map((v: number, i: number) => i);
      for (let i: number = 0; i < 3 + s.level; i++) { const at: number = this.pick(candidates.length); s.target.push(candidates[at]); candidates.splice(at, 1); }
      s.goal = s.target.length;
    } else if (s.id === 'runner') {
      s.goal = 600 + 300 * s.level; s.cursor = 1;
      const runner: ExpansionPiece = new ExpansionPiece(); runner.id = s.serial++; runner.kind = 6; runner.x = 180; runner.y = 388; runner.r = 20; s.pieces.push(runner);
    } else {
      s.goal = s.id === 'blackhole' ? 35 + 10 * s.level : 20 + 5 * s.level;
      const player: ExpansionPiece = new ExpansionPiece(); player.id = s.serial++; player.kind = s.id === 'blackhole' ? 8 : 10;
      player.x = 180; player.y = 230; player.r = s.id === 'blackhole' ? 19 : 14; player.color = 1; s.pieces.push(player);
      if (s.id === 'blackhole') {
        for (let i: number = 0; i < s.goal; i++) {
          const item: ExpansionPiece = new ExpansionPiece(); item.id = s.serial++; item.kind = 9; item.r = 8 + Math.floor(i / 8) * 4;
          item.x = 20 + this.pick(320); item.y = 30 + this.pick(400); item.color = 1 + i % 6; s.pieces.push(item);
        }
      } else { for (let i: number = 0; i < 14; i++) { this.spawnFish(s); } }
    }
  }
  private neighbor(s: ExpansionState, at: number, direction: number): number {
    const offsets: number[] = [-s.cols, 1, s.cols, -1]; const to: number = at + offsets[direction];
    if (to < 0 || to >= s.board.length || Math.abs(to % s.cols - at % s.cols) > 1) { return -1; } return to;
  }
  private box(s: ExpansionState, cell: number): ExpansionPiece | undefined { return s.pieces.find((p: ExpansionPiece) => p.y * s.cols + p.x === cell); }
  private makeWarehouse(s: ExpansionState): void {
    s.cols = 7; s.rows = 7; s.board = new Array<number>(49).fill(0);
    for (let i: number = 0; i < 49; i++) { if (i % 7 === 0 || i % 7 === 6 || i < 7 || i >= 42) { s.board[i] = 1; } }
    const goals: number[] = s.level === 0 ? [16, 31] : s.level === 1 ? [16, 18, 31] : [16, 18, 31, 37];
    goals.forEach((at: number, i: number) => {
      s.board[at] = 2; const box: ExpansionPiece = new ExpansionPiece(); box.id = i; box.kind = 5; box.x = at % 7; box.y = Math.floor(at / 7); s.pieces.push(box);
    }); s.cursor = 24;
    const reverse: number[] = [];
    for (let i: number = 0; i < 140; i++) {
      const d: number = this.pick(4); const to: number = this.neighbor(s, s.cursor, d);
      if (to < 0 || s.board[to] === 1 || this.box(s, to)) { continue; }
      const behind: number = this.neighbor(s, s.cursor, (d + 2) % 4); const box: ExpansionPiece | undefined = this.box(s, behind);
      if (box) { box.x = s.cursor % 7; box.y = Math.floor(s.cursor / 7); }
      s.cursor = to; reverse.push((d + 2) % 4);
    }
    s.target = reverse.reverse();
    if (this.warehouseSolved(s)) {
      // Safe fallback for adversarial random sources: pull one box away from its goal.
      let pulled: boolean = false;
      for (let i: number = 0; i < s.pieces.length && !pulled; i++) {
        const b: ExpansionPiece = s.pieces[i]; const at: number = b.y * 7 + b.x;
        for (let d: number = 0; d < 4 && !pulled; d++) {
          const to: number = this.neighbor(s, at, d); const hero: number = this.neighbor(s, to, d);
          if (to < 0 || hero < 0 || s.board[to] === 1 || s.board[hero] === 1 || this.box(s, to) || this.box(s, hero)) { continue; }
          b.x = to % 7; b.y = Math.floor(to / 7); s.cursor = hero; s.target = [(d + 2) % 4]; pulled = true;
        }
      }
    }
    s.goal = goals.length;
  }
  warehouseSolved(s: ExpansionState): boolean { return s.pieces.every((p: ExpansionPiece) => s.board[p.y * s.cols + p.x] === 2); }
  move(s: ExpansionState, d: number): void {
    const to: number = this.neighbor(s, s.cursor, d); if (to < 0 || s.board[to] === 1) { return; }
    const b: ExpansionPiece | undefined = this.box(s, to);
    if (b) {
      const next: number = this.neighbor(s, to, d); if (next < 0 || s.board[next] === 1 || this.box(s, next)) { return; }
      b.x = next % s.cols; b.y = Math.floor(next / s.cols);
    }
    s.cursor = to; s.moves++; s.score = s.pieces.filter((p: ExpansionPiece) => s.board[p.y * s.cols + p.x] === 2).length * 100;
    if (this.warehouseSolved(s)) { s.outcome = 1; s.score += Math.max(100, 1000 - s.moves * 3); }
  }
  private makePipes(s: ExpansionState): void {
    s.cols = 4 + s.level; s.rows = s.cols; const n: number = s.cols * s.rows;
    s.target = new Array<number>(n).fill(0); const order: number[] = [];
    const vertical: boolean = this.pick(2) === 1;
    for (let row: number = 0; row < s.rows; row++) { for (let col: number = 0; col < s.cols; col++) {
      const x: number = row % 2 === 0 ? col : s.cols - 1 - col; order.push(vertical ? x * s.cols + row : row * s.cols + x);
    } }
    for (let i: number = 0; i < order.length - 1; i++) {
      const a: number = order[i]; const b: number = order[i + 1]; const d: number = b === a + 1 ? 1 : b === a - 1 ? 3 : b > a ? 2 : 0;
      s.target[a] |= 1 << d; s.target[b] |= 1 << ((d + 2) % 4);
    }
    s.cursor = order[order.length - 1]; s.goal = n; s.board = s.target.map((value: number) => {
      let rotated: number = value; const turns: number = 1 + this.pick(3); for (let i: number = 0; i < turns; i++) { rotated = this.rotate(rotated); } return rotated;
    }); this.flow(s);
  }
  rotate(mask: number): number { return ((mask << 1) & 15) | (mask >> 3); }
  flow(s: ExpansionState): void {
    const reached: number[] = [0]; const seen: boolean[] = new Array<boolean>(s.board.length).fill(false); seen[0] = true;
    let closed: boolean = true;
    for (let q: number = 0; q < reached.length; q++) {
      const at: number = reached[q];
      for (let d: number = 0; d < 4; d++) {
        if ((s.board[at] & (1 << d)) === 0) { continue; }
        const next: number = this.neighbor(s, at, d);
        if (next < 0 || (s.board[next] & (1 << ((d + 2) % 4))) === 0) { closed = false; continue; }
        if (!seen[next]) { seen[next] = true; reached.push(next); }
      }
    }
    s.tray = reached; s.score = reached.length * 20;
    if (reached.length === s.board.length && closed && reached.includes(s.cursor)) { s.outcome = 1; }
  }
  tap(s: ExpansionState, index: number): void {
    if (s.id === 'sokoban') { if (index < 4) { this.move(s, index); }
    } else if (s.id === 'pipes') {
      if (index >= s.board.length) { return; } s.board[index] = this.rotate(s.board[index]); s.moves++; this.flow(s);
    } else if (s.id === 'differences') {
      if (index >= s.board.length || s.tray.includes(index)) { return; }
      if (s.target.includes(index)) { s.tray.push(index); s.score += 100; s.moves++; if (s.tray.length === s.target.length) { s.outcome = 1; } }
      else { s.errors++; if (s.errors === 3) { s.outcome = 2; } }
    } else if (s.id === 'runner') {
      if (index === 0 || index === 1) { s.cursor = Math.max(0, Math.min(2, s.cursor + (index === 0 ? -1 : 1))); }
    }
  }
  aim(s: ExpansionState, x: number, y: number): void {
    if (s.id !== 'blackhole' && s.id !== 'fisheat') { return; }
    const p: ExpansionPiece = s.pieces[0]; p.w = x; p.h = y; s.phase = 1;
  }
  activate(s: ExpansionState): void { if (s.id === 'runner') { s.phase = 1; } }
  private spawnFish(s: ExpansionState): void {
    const fish: ExpansionPiece = new ExpansionPiece(); fish.id = s.serial++; fish.kind = 11; fish.r = 6 + this.pick(10 + s.level * 6);
    fish.color = 1 + this.pick(6); fish.x = this.pick(2) === 0 ? -fish.r : 360 + fish.r; fish.y = 25 + this.pick(410);
    fish.vx = (fish.x < 0 ? 1 : -1) * (25 + this.pick(45) + s.level * 10); s.pieces.push(fish);
  }
  step(s: ExpansionState, dt: number): void {
    s.time += dt; s.cooldown = Math.max(0, s.cooldown - dt);
    if (s.id === 'runner') { this.runStep(s, dt); return; }
    const p: ExpansionPiece = s.pieces[0];
    const dx: number = p.w - p.x; const dy: number = p.h - p.y; const d: number = Math.sqrt(dx * dx + dy * dy);
    if (d > 1) { const step: number = Math.min(d, (s.id === 'blackhole' ? 145 : 180) * dt); p.x += dx / d * step; p.y += dy / d * step; }
    p.x = Math.max(p.r, Math.min(360 - p.r, p.x)); p.y = Math.max(p.r, Math.min(460 - p.r, p.y));
    for (let i: number = 1; i < s.pieces.length; i++) {
      const item: ExpansionPiece = s.pieces[i]; item.x += item.vx * dt;
      const ax: number = item.x - p.x; const ay: number = item.y - p.y; const distance: number = Math.sqrt(ax * ax + ay * ay);
      if (s.id === 'blackhole') {
        if (item.r < p.r * 0.9 && distance < p.r - item.r * 0.3) { item.alive = false; s.moves++; s.score += Math.round(item.r * 10); p.r = Math.min(70, p.r + 1.3); }
      } else {
        if (item.x < -50 || item.x > 410) { item.alive = false; }
        else if (distance < p.r + item.r * 0.7) {
          if (item.r >= p.r + 2) { s.outcome = 2; }
          else { item.alive = false; s.moves++; s.score += Math.round(item.r * 10); p.r = Math.min(50, p.r + 0.7); }
        }
      }
    }
    s.pieces = s.pieces.filter((item: ExpansionPiece) => item.alive);
    if (s.id === 'fisheat') { while (s.pieces.length < 15) { this.spawnFish(s); } }
    if (s.moves >= s.goal) { s.outcome = 1; }
    if (s.id === 'blackhole' && s.time >= 120 - 20 * s.level) { s.outcome = 2; }
  }
  private runStep(s: ExpansionState, dt: number): void {
    const p: ExpansionPiece = s.pieces[0]; p.x = 60 + s.cursor * 120; s.score = Math.floor(s.time * 25) + s.moves * 50;
    if (s.cooldown <= 0) {
      const obstacle: ExpansionPiece = new ExpansionPiece(); obstacle.id = s.serial++; obstacle.kind = 7; obstacle.x = 60 + this.pick(3) * 120;
      obstacle.y = -30; obstacle.r = 24; obstacle.color = this.pick(3) === 0 ? 1 : 2; s.pieces.push(obstacle); s.cooldown = Math.max(0.65, 1.2 - s.time / 120 - s.level * 0.1);
    }
    for (let i: number = 1; i < s.pieces.length; i++) {
      const obstacle: ExpansionPiece = s.pieces[i]; obstacle.y += (150 + s.level * 25 + Math.min(120, s.time * 2)) * dt;
      if (Math.abs(obstacle.x - p.x) < 30 && Math.abs(obstacle.y - p.y) < 35) {
        if (obstacle.color === 1) { s.score += 50; s.moves++; obstacle.alive = false; } else { s.outcome = 2; }
      }
      if (obstacle.y > 500) { obstacle.alive = false; }
    }
    s.pieces = s.pieces.filter((item: ExpansionPiece) => item.alive);
    if (s.outcome === 0 && s.score >= s.goal) { s.outcome = 1; }
  }
}
