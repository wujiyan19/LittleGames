import { ExpansionState, ExpansionPiece } from './ExpansionState';
import { RandomSource } from './RandomSource';
import { ContinuationValidation as V } from '../../common/GameSessionTransfer';

export const SPORTS_IDS: string[] = ['billiards', 'penalty', 'pingpong', 'bowling', 'golf', 'drift', 'hillclimb', 'airhockey', 'tug', 'dots'];
export class ExpansionSports {
  private random: RandomSource;
  constructor(random: RandomSource) { this.random = random; }
  realtime(id: string): boolean { return SPORTS_IDS.includes(id) && id !== 'tug' && id !== 'dots'; }
  private piece(s: ExpansionState, kind: number, x: number, y: number, r: number = 14): ExpansionPiece {
    const p: ExpansionPiece = new ExpansionPiece(); p.id = s.serial++; p.kind = kind; p.x = x; p.y = y; p.r = r; s.pieces.push(p); return p;
  }
  terrain(x: number): number { return 320 + Math.sin(x / 85) * 35 + Math.sin(x / 210) * 25; }
  start(s: ExpansionState): void {
    s.cols = 6; s.rows = 6; s.data = [0, 0];
    if (s.id === 'tug') { s.data = [50, 0]; s.goal = 100; return; }
    if (s.id === 'dots') { s.cols = 3 + s.level; s.rows = s.cols; s.board = new Array<number>(2 * s.cols * (s.cols + 1)).fill(0); s.data = new Array<number>(s.cols * s.cols).fill(0); s.goal = s.cols * s.cols; return; }
    const ball: ExpansionPiece = this.piece(s, ['drift', 'hillclimb'].includes(s.id) ? 36 : 32, 180, 390); ball.color = 1;
    if (s.id === 'billiards') {
      ball.x = 100; ball.y = 340; ball.r = 12; s.goal = 5;
      for (let i: number = 0; i < 5; i++) { const other: ExpansionPiece = this.piece(s, 32, 150 + i % 3 * 27, 120 + Math.floor(i / 3) * 27, 12); other.color = 2 + i; }
      [25, 335].forEach((x: number) => { [25, 230, 435].forEach((y: number) => { this.piece(s, 42, x, y, 19); }); });
    } else if (s.id === 'penalty') { const keeper: ExpansionPiece = this.piece(s, 44, 180, 95, 26); keeper.vx = 70 + s.level * 25; s.goal = 5; }
    else if (s.id === 'pingpong' || s.id === 'airhockey') {
      ball.y = 230; ball.r = s.id === 'airhockey' ? 12 : 8; ball.vx = 80; ball.vy = 170;
      const human: ExpansionPiece = this.piece(s, 39, 180, 420, s.id === 'airhockey' ? 24 : 0); human.w = 84; human.h = 12;
      const bot: ExpansionPiece = this.piece(s, 39, 180, 40, s.id === 'airhockey' ? 24 : 0); bot.w = 84; bot.h = 12; bot.owner = 1; s.goal = s.id === 'airhockey' ? 5 : 7;
    } else if (s.id === 'bowling') {
      for (let row: number = 0; row < 4; row++) { for (let col: number = 0; col <= row; col++) { this.piece(s, 37, 180 + (col - row / 2) * 27, 130 - row * 24, 13); } } s.goal = 8 + s.level;
    } else if (s.id === 'golf') {
      ball.x = 45; ball.y = 410; ball.r = 9; this.piece(s, 43, 310, 55, 14); s.goal = 20;
      const a: ExpansionPiece = this.piece(s, 26, 80, 150, 0); a.w = 220; a.h = 14;
      const b: ExpansionPiece = this.piece(s, 26, 0, 285, 0); b.w = 200; b.h = 14;
    } else if (s.id === 'drift') { ball.vx = 85; s.goal = 30 + s.level * 10; s.data.push(180); }
    else { ball.x = 35; ball.y = this.terrain(35) - 16; s.data = [100, 0]; s.goal = 1200 + s.level * 300; }
  }
  activate(s: ExpansionState): void { if (this.realtime(s.id) && !['billiards', 'golf', 'bowling'].includes(s.id)) { s.phase = 1; } }
  private boxEdges(s: ExpansionState, box: number): number[] {
    const n: number = s.cols; const row: number = Math.floor(box / n); const col: number = box % n; const vertical: number = n * (n + 1);
    return [row * n + col, (row + 1) * n + col, vertical + row * (n + 1) + col, vertical + row * (n + 1) + col + 1];
  }
  tap(s: ExpansionState, at: number): void {
    if (s.id === 'tug' && at < 2) { s.data[0] = Math.max(0, Math.min(100, s.data[0] + (at === 0 ? 1 : -1) * (3 + s.level))); s.moves++; if (s.data[0] === 0 || s.data[0] === 100) { s.cursor = s.data[0] === 100 ? 0 : 1; s.outcome = 1; s.score = Math.max(100, 2000 - s.moves * 10); } return; }
    if (s.id === 'dots') {
      if (at >= s.board.length || s.board[at] !== 0) { return; } s.board[at] = s.cursor + 1; s.moves++; let gained: boolean = false;
      for (let box: number = 0; box < s.data.length; box++) { if (s.data[box] === 0 && this.boxEdges(s, box).every((edge: number) => s.board[edge] !== 0)) { s.data[box] = s.cursor + 1; gained = true; } }
      s.score = s.data.filter((v: number) => v === 1).length * 100;
      if (s.data.every((v: number) => v > 0)) { s.outcome = 1; } else if (!gained) { s.cursor = 1 - s.cursor; } return;
    }
    if (s.phase === 0) { return; } const p: ExpansionPiece = s.pieces[0];
    if (s.id === 'drift' && at === 0) { p.vx *= -1; s.moves++; }
    if (s.id === 'hillclimb' && at < 3) { s.selected = at === 2 ? -1 : at; }
  }
  release(s: ExpansionState): void { if (s.id === 'hillclimb') { s.selected = -1; } }
  aim(s: ExpansionState, x: number, y: number): void {
    if (['tug', 'dots', 'drift', 'hillclimb'].includes(s.id)) { return; }
    if (s.id === 'pingpong' || s.id === 'airhockey') {
      if (s.phase === 0) { return; } const p: ExpansionPiece = s.pieces[1]; const nx: number = Math.max(s.id === 'pingpong' ? 42 : 25, Math.min(s.id === 'pingpong' ? 318 : 335, x));
      const ny: number = s.id === 'pingpong' ? 420 : Math.max(245, Math.min(430, y)); p.vx = Math.max(-450, Math.min(450, (nx - p.x) * 8)); p.vy = Math.max(-450, Math.min(450, (ny - p.y) * 8)); p.x = nx; p.y = ny; return;
    }
    const ball: ExpansionPiece = s.pieces[0];
    if (s.id === 'penalty') { if (ball.vy !== 0 || s.data[0] >= 8) { return; } ball.vx = (Math.max(35, Math.min(325, x)) - ball.x) / 1.1; ball.vy = -300; s.data[0]++; s.moves++; s.phase = 1; return; }
    if (s.phase !== 0) { return; }
    const dx: number = x - ball.x; const dy: number = y - ball.y; const distance: number = Math.hypot(dx, dy); if (distance < 10) { return; }
    const speed: number = s.id === 'bowling' ? 300 : Math.min(350, Math.max(60, distance * 1.8));
    ball.vx = dx / distance * speed; ball.vy = dy / distance * speed; s.phase = 1; s.moves++; ball.age = 0;
    if (s.id === 'bowling') { s.data[0]++; }
  }
  private walls(p: ExpansionPiece, restitution: number): void {
    if (p.x < p.r + 10) { p.x = p.r + 10; p.vx = Math.abs(p.vx) * restitution; }
    if (p.x > 350 - p.r) { p.x = 350 - p.r; p.vx = -Math.abs(p.vx) * restitution; }
    if (p.y < p.r + 10) { p.y = p.r + 10; p.vy = Math.abs(p.vy) * restitution; }
    if (p.y > 450 - p.r) { p.y = 450 - p.r; p.vy = -Math.abs(p.vy) * restitution; }
  }
  private billiards(s: ExpansionState, dt: number): void {
    const balls: ExpansionPiece[] = s.pieces.filter((p: ExpansionPiece) => p.kind === 32 && p.alive);
    balls.forEach((p: ExpansionPiece) => {
      p.x += p.vx * dt; p.y += p.vy * dt;
      if (s.pieces.some((hole: ExpansionPiece) => hole.kind === 42 && Math.hypot(p.x - hole.x, p.y - hole.y) < hole.r)) {
        if (p.id === s.pieces[0].id) { p.x = 100; p.y = 340; p.vx = 0; p.vy = 0; s.errors++; } else { p.alive = false; s.cursor++; s.score += 200; } return;
      }
      this.walls(p, 0.88); p.vx *= Math.exp(-1.2 * dt); p.vy *= Math.exp(-1.2 * dt);
    });
    for (let i: number = 0; i < balls.length; i++) { for (let j: number = i + 1; j < balls.length; j++) {
      const a: ExpansionPiece = balls[i]; const b: ExpansionPiece = balls[j]; if (!a.alive || !b.alive) { continue; }
      const dx: number = b.x - a.x; const dy: number = b.y - a.y; const d: number = Math.max(0.01, Math.hypot(dx, dy));
      if (d < 24) {
        const nx: number = dx / d; const ny: number = dy / d; const overlap: number = (24 - d) / 2; a.x -= nx * overlap; a.y -= ny * overlap; b.x += nx * overlap; b.y += ny * overlap;
        const speed: number = (a.vx - b.vx) * nx + (a.vy - b.vy) * ny;
        if (speed > 0) { a.vx -= speed * nx; a.vy -= speed * ny; b.vx += speed * nx; b.vy += speed * ny; }
      }
    } }
    if (s.cursor === 5) { s.outcome = 1; } else if (s.errors >= 4) { s.outcome = 2; }
    if (balls.every((p: ExpansionPiece) => !p.alive || Math.hypot(p.vx, p.vy) < 2)) { balls.forEach((p: ExpansionPiece) => { p.vx = 0; p.vy = 0; }); s.phase = 0; }
  }
  private penalty(s: ExpansionState, dt: number): void {
    const ball: ExpansionPiece = s.pieces[0]; const keeper: ExpansionPiece = s.pieces[1]; keeper.x += keeper.vx * dt;
    if (keeper.x < 55 || keeper.x > 305) { keeper.vx *= -1; keeper.x = Math.max(55, Math.min(305, keeper.x)); }
    if (ball.vy === 0) { return; } ball.x += ball.vx * dt; ball.y += ball.vy * dt;
    if (ball.y <= 95) {
      if (ball.x >= 30 && ball.x <= 330 && Math.abs(ball.x - keeper.x) > keeper.r + ball.r) { s.data[1]++; s.score += 200; }
      ball.x = 180; ball.y = 390; ball.vx = 0; ball.vy = 0;
      if (s.data[1] >= s.goal) { s.outcome = 1; } else if (s.data[0] >= 8) { s.outcome = 2; }
    }
  }
  private point(s: ExpansionState, human: boolean): void {
    s.data[human ? 0 : 1]++; const ball: ExpansionPiece = s.pieces[0]; ball.x = 180; ball.y = 230; ball.vx = 70; ball.vy = human ? 160 : -160;
    s.score = s.data[0] * 200; if (s.data[0] >= s.goal || s.data[1] >= s.goal) { s.outcome = s.data[0] >= s.goal ? 1 : 2; }
  }
  private racket(s: ExpansionState, dt: number): void {
    const ball: ExpansionPiece = s.pieces[0]; const bot: ExpansionPiece = s.pieces[2]; const oldX: number = bot.x; const oldY: number = bot.y;
    bot.x += Math.max(-(130 + s.level * 35) * dt, Math.min((130 + s.level * 35) * dt, ball.x - bot.x));
    if (s.id === 'airhockey') { bot.y += Math.max(-90 * dt, Math.min(90 * dt, Math.max(25, Math.min(205, ball.y - 30)) - bot.y)); }
    bot.vx = (bot.x - oldX) / dt; bot.vy = (bot.y - oldY) / dt;
    ball.x += ball.vx * dt; ball.y += ball.vy * dt;
    if (ball.x < ball.r + 10 || ball.x > 350 - ball.r) { ball.x = Math.max(ball.r + 10, Math.min(350 - ball.r, ball.x)); ball.vx *= -1; }
    if (s.id === 'pingpong') {
      s.pieces.slice(1).forEach((p: ExpansionPiece) => {
        if (Math.abs(ball.x - p.x) <= p.w / 2 + ball.r && Math.abs(ball.y - p.y) <= ball.r + p.h / 2 && (p.owner === 1 ? ball.vy < 0 : ball.vy > 0)) {
          ball.vy = (p.owner === 1 ? 1 : -1) * Math.min(330, Math.abs(ball.vy) + 12); ball.vx = (ball.x - p.x) * 5; ball.y = p.y + (p.owner === 1 ? 1 : -1) * (ball.r + p.h / 2 + 1);
        }
      });
      if (ball.y < 0) { this.point(s, true); } else if (ball.y > 460) { this.point(s, false); }
    } else {
      s.pieces.slice(1).forEach((p: ExpansionPiece) => {
        const dx: number = ball.x - p.x; const dy: number = ball.y - p.y; const d: number = Math.max(1, Math.hypot(dx, dy));
        if (d < p.r + ball.r) { ball.x = p.x + dx / d * (p.r + ball.r); ball.y = p.y + dy / d * (p.r + ball.r); ball.vx = Math.max(-450, Math.min(450, dx / d * 240 + p.vx * 0.5)); ball.vy = Math.max(-450, Math.min(450, dy / d * 240 + p.vy * 0.5)); }
      });
      if (ball.y < 10 || ball.y > 450) { if (ball.x > 125 && ball.x < 235) { this.point(s, ball.y < 10); } else { ball.y = Math.max(10, Math.min(450, ball.y)); ball.vy *= -1; } }
    }
  }
  private bowling(s: ExpansionState, dt: number): void {
    const ball: ExpansionPiece = s.pieces[0]; ball.age += dt; ball.x += ball.vx * dt; ball.y += ball.vy * dt;
    const pins: ExpansionPiece[] = s.pieces.filter((p: ExpansionPiece) => p.kind === 37 && p.alive);
    const hit: ExpansionPiece | undefined = pins.find((p: ExpansionPiece) => Math.hypot(p.x - ball.x, p.y - ball.y) < p.r + ball.r);
    if (hit) { pins.filter((p: ExpansionPiece) => Math.hypot(p.x - hit.x, p.y - hit.y) <= 31).forEach((p: ExpansionPiece) => { p.alive = false; s.cursor++; s.score += 100; }); }
    if (ball.y < -20 || ball.x < -20 || ball.x > 380 || ball.y > 480 || ball.age > 4) {
      ball.x = 180; ball.y = 390; ball.vx = 0; ball.vy = 0; ball.age = 0; s.phase = 0;
      if (s.cursor === 10 || s.data[0] >= 3) { s.outcome = s.cursor >= s.goal ? 1 : 2; }
    }
  }
  private golf(s: ExpansionState, dt: number): void {
    const ball: ExpansionPiece = s.pieces[0]; const oldX: number = ball.x; const oldY: number = ball.y; ball.x += ball.vx * dt; ball.y += ball.vy * dt;
    this.walls(ball, 0.7); ball.vx *= Math.exp(-0.8 * dt); ball.vy *= Math.exp(-0.8 * dt);
    s.pieces.filter((p: ExpansionPiece) => p.kind === 26).forEach((p: ExpansionPiece) => {
      if (ball.x + ball.r > p.x && ball.x - ball.r < p.x + p.w && ball.y + ball.r > p.y && ball.y - ball.r < p.y + p.h) {
        if (oldY + ball.r <= p.y || oldY - ball.r >= p.y + p.h) { ball.vy *= -0.65; } else { ball.vx *= -0.65; } ball.x = oldX; ball.y = oldY;
      }
    });
    const hole: ExpansionPiece = s.pieces[1]; if (Math.hypot(ball.x - hole.x, ball.y - hole.y) < 12 && Math.hypot(ball.vx, ball.vy) < 150) { s.outcome = 1; s.score = Math.max(100, 2100 - s.moves * 100); }
    if (Math.hypot(ball.vx, ball.vy) < 3) { ball.vx = 0; ball.vy = 0; s.phase = 0; if (s.moves >= 20 && s.outcome === 0) { s.outcome = 2; } }
  }
  private race(s: ExpansionState, dt: number): void {
    const car: ExpansionPiece = s.pieces[0];
    if (s.id === 'drift') {
      const center: number = 180 + Math.sin(s.time * 0.65) * 90; s.data[2] = Math.round(center); car.x += car.vx * dt;
      if (Math.abs(car.x - center) > 65) { s.outcome = 2; } else if (s.time >= s.goal) { s.outcome = 1; } s.score = Math.floor(s.time * 50);
    } else {
      const previousGround: number = this.terrain(car.x) - 16;
      const slope: number = (this.terrain(car.x + 2) - this.terrain(car.x - 2)) / 4;
      car.vx = Math.max(0, Math.min(145, car.vx + (s.selected === 0 ? 85 : s.selected === 1 ? -180 : -15) * dt + slope * 50 * dt)); car.x += car.vx * dt;
      const ground: number = this.terrain(car.x) - 16;
      if (car.y >= previousGround - 1 && ground <= car.y + 3) { car.y = ground; car.vy = Math.min(0, slope * car.vx); }
      else { car.vy += 500 * dt; car.y += car.vy * dt; if (car.y >= ground) { if (car.vy > 330) { s.outcome = 2; } car.y = ground; car.vy = 0; } }
      s.data[0] = Math.max(0, 100 - Math.floor(s.time * 1.1)); s.score = Math.floor(car.x);
      if (car.x >= s.goal) { s.outcome = 1; s.score += 500; } else if (s.data[0] === 0) { s.outcome = 2; }
    }
  }
  step(s: ExpansionState, dt: number): void {
    s.time += dt;
    if (s.id === 'billiards') { this.billiards(s, dt); } else if (s.id === 'penalty') { this.penalty(s, dt); }
    else if (s.id === 'pingpong' || s.id === 'airhockey') { this.racket(s, dt); } else if (s.id === 'bowling') { this.bowling(s, dt); }
    else if (s.id === 'golf') { this.golf(s, dt); } else { this.race(s, dt); }
    s.pieces = s.pieces.filter((p: ExpansionPiece) => p.alive);
  }
  valid(s: ExpansionState): boolean {
    if (!SPORTS_IDS.includes(s.id) || s.piles.length !== 0 || s.target.length !== 0 || s.tray.length !== 0) { return false; }
    if (s.id === 'dots') { return s.cols === 3 + s.level && s.rows === s.cols && s.goal === s.cols * s.cols && s.phase === 0 && s.pieces.length === 0 && s.cursor <= 1 && V.numbers(s.board, 2 * s.cols * (s.cols + 1), 0, 2) && V.numbers(s.data, s.goal, 0, 2); }
    if (s.cols !== 6 || s.rows !== 6 || s.board.length !== 0 || !V.numbers(s.data, s.id === 'drift' ? 3 : 2, 0, 10000)) { return false; }
    if (s.id === 'tug') { return s.phase === 0 && s.goal === 100 && s.data[0] <= 100 && s.pieces.length === 0 && s.cursor <= 1; }
    if (s.pieces.length === 0 || s.pieces.some((p: ExpansionPiece) => !p.alive || p.id >= s.serial || p.kind < 26 || p.kind > 44 || p.x < -40 || p.x > 1900 || p.y < -40 || p.y > 490 || p.r < 0 || p.r > 30)) { return false; }
    if (s.id === 'billiards') { return s.goal === 5 && s.pieces.length === 12 - s.cursor && s.cursor <= 5 && s.errors <= 4 && s.pieces[0].kind === 32 && s.pieces.filter((p: ExpansionPiece) => p.kind === 42).length === 6; }
    if (s.id === 'penalty') { return s.goal === 5 && s.pieces.length === 2 && s.data[0] <= 8 && s.data[1] <= s.data[0] && s.pieces[1].kind === 44; }
    if (s.id === 'pingpong' || s.id === 'airhockey') { return s.pieces.length === 3 && s.pieces[0].kind === 32 && s.pieces.slice(1).every((p: ExpansionPiece) => p.kind === 39) && s.goal === (s.id === 'pingpong' ? 7 : 5) && s.data[0] <= s.goal && s.data[1] <= s.goal; }
    if (s.id === 'bowling') { return s.goal === 8 + s.level && s.pieces.length === 11 - s.cursor && s.cursor <= 10 && s.data[0] <= 3 && s.pieces[0].kind === 32; }
    if (s.id === 'golf') { return s.goal === 20 && s.pieces.length === 4 && s.moves <= 20 && s.pieces[1].kind === 43; }
    return s.pieces.length === 1 && s.pieces[0].kind === 36 && s.goal === (s.id === 'drift' ? 30 + s.level * 10 : 1200 + s.level * 300) && (s.id !== 'hillclimb' || s.data[0] <= 100);
  }
}
