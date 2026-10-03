import { ExpansionState, ExpansionPiece } from './ExpansionState';
import { RandomSource } from './RandomSource';

/** Fixed-step native UI games. Coordinates are logical units in a 360 by 460 arena. */
export class ExpansionPhysics {
  private random: RandomSource;
  private stillTime: number = 0;
  constructor(random: RandomSource) { this.random = random; }
  private pick(n: number): number { return Math.min(n - 1, Math.max(0, Math.floor(this.random.next() * n))); }
  start(s: ExpansionState): void {
    this.stillTime = 0;
    if (s.id === 'bubbleshooter') {
      s.cols = 8; s.rows = 15; s.board = new Array<number>(s.cols * s.rows).fill(0); s.goal = 90 - 10 * s.level;
      for (let row: number = 0; row < 4 + s.level; row++) {
        for (let col: number = 0; col < s.cols; col++) { s.board[row * s.cols + col] = 1 + this.pick(3 + s.level); }
      }
      this.nextBubble(s);
    } else { s.next = this.pick(3); s.goal = 9; }
  }
  bubbleX(index: number): number { return 22 + (index % 8) * 42 + (Math.floor(index / 8) % 2) * 21; }
  bubbleY(index: number): number { return 22 + Math.floor(index / 8) * 36; }
  aim(s: ExpansionState, x: number, y: number): void {
    if (!Number.isFinite(x) || !Number.isFinite(y) || x < 0 || x > 360 || y < 0 || y > 460 || s.outcome !== 0 || s.cooldown > 0) { return; }
    if (s.id === 'bubbleshooter') {
      if (s.pieces.length > 0 || y >= 415) { return; }
      const p: ExpansionPiece = new ExpansionPiece(); p.id = s.serial++; p.kind = 3; p.color = s.next;
      p.x = 180; p.y = 435; p.r = 19; const dx: number = x - p.x; const dy: number = Math.min(-30, y - p.y);
      const length: number = Math.sqrt(dx * dx + dy * dy); p.vx = dx / length * 340; p.vy = dy / length * 340;
      s.pieces.push(p); s.moves++; s.phase = 1;
    } else {
      this.stillTime = 0;
      if (s.pieces.length >= 60) { s.outcome = 2; return; }
      const p: ExpansionPiece = new ExpansionPiece(); p.id = s.serial++; p.kind = 4; p.color = s.next;
      p.r = this.fruitRadius(p.color); p.x = Math.max(p.r + 2, Math.min(358 - p.r, x)); p.y = 30;
      s.pieces.push(p); s.next = this.pick(3); s.moves++; s.cooldown = 0.75; s.phase = 1;
    }
  }
  step(s: ExpansionState, dt: number): void {
    if (s.outcome !== 0 || s.phase === 0 || !Number.isFinite(dt) || dt <= 0 || dt > 0.02) { return; }
    s.time += dt; s.cooldown = Math.max(0, s.cooldown - dt);
    if (s.id === 'bubbleshooter') { this.stepBubble(s, dt); } else { this.stepFruit(s, dt); }
  }
  private neighbors(s: ExpansionState, index: number): number[] {
    const row: number = Math.floor(index / 8); const col: number = index % 8;
    const left: number = row % 2 === 0 ? col - 1 : col; const right: number = left + 1;
    const candidates: number[] = [row * 8 + col - 1, row * 8 + col + 1];
    const result: number[] = [];
    if (col > 0) { result.push(candidates[0]); } if (col < 7) { result.push(candidates[1]); }
    for (let dy: number = -1; dy <= 1; dy += 2) {
      if (row + dy < 0 || row + dy >= s.rows) { continue; }
      if (left >= 0 && left < 8) { result.push((row + dy) * 8 + left); }
      if (right >= 0 && right < 8) { result.push((row + dy) * 8 + right); }
    }
    return result;
  }
  private stepBubble(s: ExpansionState, dt: number): void {
    if (s.pieces.length === 0) { return; } const p: ExpansionPiece = s.pieces[0];
    p.x += p.vx * dt; p.y += p.vy * dt;
    if (p.x < 20) { p.x = 40 - p.x; p.vx = Math.abs(p.vx); }
    if (p.x > 340) { p.x = 680 - p.x; p.vx = -Math.abs(p.vx); }
    let hit: number = -1; let nearest: number = 100000;
    for (let i: number = 0; i < s.board.length; i++) {
      if (s.board[i] === 0) { continue; }
      const dx: number = p.x - this.bubbleX(i); const dy: number = p.y - this.bubbleY(i); const dist: number = dx * dx + dy * dy;
      if (dist <= 39 * 39 && dist < nearest) { nearest = dist; hit = i; }
    }
    if (hit < 0 && p.y > 22) { return; }
    const candidates: number[] = hit < 0 ? [0, 1, 2, 3, 4, 5, 6, 7] : this.neighbors(s, hit);
    let cell: number = -1; nearest = 100000;
    for (let k: number = 0; k < candidates.length; k++) {
      const i: number = candidates[k]; if (s.board[i] !== 0 || this.bubbleX(i) > 340) { continue; }
      const dx: number = p.x - this.bubbleX(i); const dy: number = p.y - this.bubbleY(i); const dist: number = dx * dx + dy * dy;
      if (dist < nearest) { nearest = dist; cell = i; }
    }
    if (cell < 0) { s.outcome = 2; s.pieces = []; return; }
    s.board[cell] = p.color; s.pieces = [];
    const same: number[] = [cell]; const seen: boolean[] = new Array<boolean>(s.board.length).fill(false); seen[cell] = true;
    for (let q: number = 0; q < same.length; q++) {
      this.neighbors(s, same[q]).forEach((i: number) => { if (!seen[i] && s.board[i] === p.color) { seen[i] = true; same.push(i); } });
    }
    if (same.length >= 3) {
      same.forEach((i: number) => { s.board[i] = 0; }); s.score += same.length * 20;
      const anchored: boolean[] = new Array<boolean>(s.board.length).fill(false); const queue: number[] = [];
      for (let i: number = 0; i < 8; i++) { if (s.board[i] > 0) { anchored[i] = true; queue.push(i); } }
      for (let q: number = 0; q < queue.length; q++) {
        this.neighbors(s, queue[q]).forEach((i: number) => { if (!anchored[i] && s.board[i] > 0) { anchored[i] = true; queue.push(i); } });
      }
      for (let i: number = 0; i < s.board.length; i++) { if (s.board[i] > 0 && !anchored[i]) { s.board[i] = 0; s.score += 30; } }
    }
    if (s.board.every((v: number) => v === 0)) { s.outcome = 1; }
    else if (s.moves >= s.goal || s.board.some((v: number, i: number) => v > 0 && this.bubbleY(i) + 19 >= 410)) { s.outcome = 2; }
    this.nextBubble(s); s.phase = 0;
  }
  private nextBubble(s: ExpansionState): void {
    const colors: number[] = [];
    s.board.forEach((v: number) => { if (v > 0 && !colors.includes(v)) { colors.push(v); } });
    s.next = colors.length > 0 ? colors[this.pick(colors.length)] : 1;
  }
  fruitRadius(tier: number): number { return 12 + tier * 4; }
  private stepFruit(s: ExpansionState, dt: number): void {
    s.pieces.forEach((p: ExpansionPiece) => {
      p.vy += 480 * dt; p.x += p.vx * dt; p.y += p.vy * dt; p.vx *= 0.997;
      if (p.x < p.r) { p.x = p.r; p.vx = Math.abs(p.vx) * 0.25; }
      if (p.x > 360 - p.r) { p.x = 360 - p.r; p.vx = -Math.abs(p.vx) * 0.25; }
      if (p.y > 460 - p.r) { p.y = 460 - p.r; p.vy = p.vy > 20 ? -p.vy * 0.15 : 0; p.vx *= 0.95; }
    });
    // Relax contacts several times. Stable entity IDs keep size changes outside animations.
    let merged: boolean = false;
    for (let pass: number = 0; pass < 4; pass++) {
      for (let a: number = 0; a < s.pieces.length; a++) {
        const p: ExpansionPiece = s.pieces[a]; if (!p.alive) { continue; }
        for (let b: number = a + 1; b < s.pieces.length; b++) {
          const q: ExpansionPiece = s.pieces[b]; if (!q.alive) { continue; }
          let dx: number = q.x - p.x; let dy: number = q.y - p.y; let d: number = Math.sqrt(dx * dx + dy * dy);
          if (d > p.r + q.r) { continue; }
          if (!merged && p.color === q.color && p.color < 9) {
            p.alive = false; q.alive = false; const fruit: ExpansionPiece = new ExpansionPiece(); fruit.id = s.serial++;
            fruit.kind = 4; fruit.color = p.color + 1; fruit.r = this.fruitRadius(fruit.color); fruit.x = Math.max(fruit.r, Math.min(360 - fruit.r, (p.x + q.x) / 2));
            fruit.y = Math.min(460 - fruit.r, (p.y + q.y) / 2); fruit.vx = (p.vx + q.vx) / 2; fruit.vy = Math.min(0, (p.vy + q.vy) / 2);
            s.pieces.push(fruit); s.score += Math.pow(2, fruit.color) * 10; merged = true;
            if (fruit.color >= s.goal) { s.outcome = 1; } break;
          }
          if (d < 0.001) { dx = 0.01; dy = -1; d = Math.sqrt(dx * dx + dy * dy); }
          const nx: number = dx / d; const ny: number = dy / d; const overlap: number = p.r + q.r - d;
          p.x -= nx * overlap * 0.5; p.y -= ny * overlap * 0.5; q.x += nx * overlap * 0.5; q.y += ny * overlap * 0.5;
          const velocity: number = (q.vx - p.vx) * nx + (q.vy - p.vy) * ny;
          if (velocity < 0) { p.vx += velocity * nx * 0.55; p.vy += velocity * ny * 0.55; q.vx -= velocity * nx * 0.55; q.vy -= velocity * ny * 0.55; }
        }
      }
    }
    s.pieces = s.pieces.filter((p: ExpansionPiece) => p.alive);
    s.pieces.forEach((p: ExpansionPiece) => {
      p.x = Math.max(p.r, Math.min(360 - p.r, p.x)); p.y = Math.min(460 - p.r, p.y);
      p.age = p.y - p.r < 50 && Math.abs(p.vy) < 35 && s.time > 2 ? p.age + dt : 0;
      if (p.age >= 2) { s.outcome = 2; }
    });
    const resting: boolean = s.cooldown === 0 && s.pieces.every((p: ExpansionPiece) => Math.abs(p.vx) < 5 && Math.abs(p.vy) < 20 && p.y - p.r >= 50);
    this.stillTime = resting ? this.stillTime + dt : 0;
    if (this.stillTime >= 1.2) { s.phase = 0; }
  }
}
