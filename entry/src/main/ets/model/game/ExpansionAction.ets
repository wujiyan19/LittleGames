import { ExpansionState, ExpansionPiece } from './ExpansionState';
import { RandomSource } from './RandomSource';
import { ContinuationValidation as V } from '../../common/GameSessionTransfer';

export const ACTION_IDS: string[] = ['platformer', 'grapple', 'flappy', 'fruitslice', 'rollingball', 'shooter', 'tanks', 'fortress', 'survival', 'backpack'];
export class ExpansionAction {
  private random: RandomSource;
  constructor(random: RandomSource) { this.random = random; }
  private pick(n: number): number { return Math.min(n - 1, Math.max(0, Math.floor(this.random.next() * n))); }
  private piece(s: ExpansionState, kind: number, x: number, y: number, r: number = 16): ExpansionPiece {
    const p: ExpansionPiece = new ExpansionPiece(); p.id = s.serial++; p.kind = kind; p.x = x; p.y = y; p.r = r; s.pieces.push(p); return p;
  }
  realtime(id: string): boolean { return ACTION_IDS.includes(id) && id !== 'backpack'; }
  start(s: ExpansionState): void {
    s.cols = 6; s.rows = 6; s.data = [3, 0];
    if (s.id === 'backpack') { s.cols = 4; s.rows = 4; s.board = new Array<number>(16).fill(0); s.tray = [1, 2, 3, 4]; s.selected = 0; s.data = [12, 100]; s.goal = 5; return; }
    const player: ExpansionPiece = this.piece(s, s.id === 'rollingball' ? 32 : 24, 180, 400); player.color = 1;
    if (s.id === 'platformer' || s.id === 'grapple') {
      player.x = 50; player.y = 344; s.goal = s.id === 'platformer' ? 900 + s.level * 240 : 900 + s.level * 180;
      for (let i: number = 0; i < Math.ceil(s.goal / 155) + 1; i++) {
        const ground: ExpansionPiece = this.piece(s, 25, i * 155, 360 - (s.id === 'platformer' ? i % 3 * 10 : 0), 0); ground.w = 85; ground.h = 18;
        if (s.id === 'grapple') { this.piece(s, 28, 130 + i * 155, 120 + i % 2 * 20, 8); }
      }
      this.piece(s, 27, s.goal, 300, 18);
    } else if (s.id === 'flappy') { player.x = 80; player.y = 230; s.goal = 8 + s.level * 4; this.gate(s, 400); }
    else if (s.id === 'fruitslice') { s.pieces = []; s.goal = 20 + s.level * 10; }
    else if (s.id === 'rollingball') {
      player.x = 40; player.y = 410; this.piece(s, 27, 320, 45, 22); s.goal = 1;
      for (let i: number = 0; i < 3; i++) { const wall: ExpansionPiece = this.piece(s, 26, i % 2 === 0 ? 0 : 120, 120 + i * 100, 0); wall.w = 240; wall.h = 16; }
      for (let i: number = 0; i < s.level + 1; i++) { this.piece(s, 31, 290 - i * 70, 330 - i * 100, 12); }
    } else { s.goal = s.id === 'survival' ? 24 + s.level * 8 : 18 + s.level * 6; if (s.id === 'fortress') { s.data = [100, 0]; } }
  }
  activate(s: ExpansionState): void { if (this.realtime(s.id)) { s.phase = 1; } }
  private gate(s: ExpansionState, x: number): void {
    const p: ExpansionPiece = this.piece(s, 29, x, 150 + this.pick(150), 0); p.w = 52; p.h = 160 - s.level * 12;
  }
  private shoot(s: ExpansionState, x: number, y: number, vx: number, vy: number, owner: number = 0): void {
    if (s.pieces.length >= 56) { return; } const bullet: ExpansionPiece = this.piece(s, 34, x, y, owner === 0 ? 5 : 6); bullet.vx = vx; bullet.vy = vy; bullet.owner = owner;
  }
  private attach(s: ExpansionState): void {
    const player: ExpansionPiece = s.pieces[0]; const anchors: ExpansionPiece[] = s.pieces.filter((p: ExpansionPiece) => p.kind === 28 && p.x >= player.x - 20 && p.x - player.x < 220 && Math.hypot(p.x - player.x, p.y - player.y) <= 300);
    if (anchors.length === 0) { return; } const anchor: ExpansionPiece = anchors[0]; s.selected = anchor.id; player.age = Math.hypot(player.x - anchor.x, player.y - anchor.y);
  }
  tap(s: ExpansionState, index: number): void {
    if (s.id === 'backpack') { this.pack(s, index); return; }
    if (s.phase === 0) { return; }
    const p: ExpansionPiece | undefined = s.pieces[0];
    if (s.id === 'platformer' && p) {
      if (index === 0 || index === 1) { p.vx = index === 0 ? -130 : 130; }
      if (index === 2 && p.vy === 0) { p.vy = -330; s.moves++; } if (index === 3) { p.vx = 0; }
    } else if (s.id === 'grapple' && p) {
      if (index === 0) { this.attach(s); } if (index === 1) { s.selected = -1; p.vx = Math.max(160, p.vx); p.vy = Math.min(-260, p.vy); s.moves++; }
    } else if (s.id === 'flappy' && index === 0 && p) { p.vy = -220; s.moves++; }
    else if (s.id === 'fortress' && index === 0 && s.data[1] >= 20) { s.data[1] -= 20; s.next = Math.min(5, s.next + 1); }
  }
  choose(s: ExpansionState, index: number): void { if (s.id === 'backpack' && index < 4) { s.selected = index; } }
  private pack(s: ExpansionState, at: number): void {
    if (at === 100) {
      const attack: number = 6 + s.board.filter((v: number) => v === 1).length * 4;
      const guard: number = s.board.filter((v: number) => v === 2).length * 2;
      const healing: number = s.board.filter((v: number) => v === 3).length * 7;
      const speed: number = 1 + s.board.filter((v: number) => v === 4).length * 0.15;
      const enemyHealth: number = 55 + s.cursor * 35; const rounds: number = Math.ceil(enemyHealth / (attack * speed));
      s.data[1] = Math.min(100, s.data[1] + healing) - rounds * Math.max(1, 9 + s.cursor * 3 - guard);
      s.moves++; if (s.data[1] <= 0) { s.data[1] = 0; s.outcome = 2; } else { s.cursor++; s.score += 200; s.data[0] += 6; if (s.cursor === s.goal) { s.outcome = 1; } } return;
    }
    if (at >= 16 || s.selected < 0 || s.selected > 3) { return; }
    const item: number = s.selected + 1; const widths: number[] = [2, 1, 2, 1]; const heights: number[] = [1, 2, 2, 1]; const cost: number[] = [3, 3, 4, 2];
    const x: number = at % 4; const y: number = Math.floor(at / 4); if (x + widths[s.selected] > 4 || y + heights[s.selected] > 4 || s.data[0] < cost[s.selected]) { return; }
    const cells: number[] = [];
    for (let row: number = 0; row < heights[s.selected]; row++) { for (let col: number = 0; col < widths[s.selected]; col++) { cells.push((y + row) * 4 + x + col); } }
    if (cells.some((i: number) => s.board[i] !== 0)) { return; } cells.forEach((i: number) => { s.board[i] = item; }); s.data[0] -= cost[s.selected]; s.moves++;
  }
  private slice(s: ExpansionState, x: number, y: number): void {
    const fromX: number = s.target.length === 2 ? s.target[0] : x; const fromY: number = s.target.length === 2 ? s.target[1] : y;
    const dx: number = x - fromX; const dy: number = y - fromY; const length: number = dx * dx + dy * dy;
    s.pieces.forEach((p: ExpansionPiece) => {
      const t: number = length === 0 ? 0 : Math.max(0, Math.min(1, ((p.x - fromX) * dx + (p.y - fromY) * dy) / length));
      if (p.alive && Math.hypot(p.x - fromX - t * dx, p.y - fromY - t * dy) < p.r + 5) {
        p.alive = false; if (p.kind === 31) { s.outcome = 2; } else { s.moves++; s.score += 50; if (s.moves >= s.goal) { s.outcome = 1; } }
      }
    }); s.target = [Math.round(x), Math.round(y)];
  }
  aim(s: ExpansionState, x: number, y: number): void {
    if (s.phase === 0) { return; }
    if (s.id === 'fruitslice') { this.slice(s, x, y); return; }
    const p: ExpansionPiece = s.pieces[0];
    if (s.id === 'rollingball') { p.vx = Math.max(-150, Math.min(150, (x - p.x) * 1.6)); p.vy = Math.max(-150, Math.min(150, (y - p.y) * 1.6)); }
    else if (s.id === 'fortress') {
      if (s.cooldown > 0) { return; } const angle: number = Math.atan2(y - p.y, x - p.x); this.shoot(s, p.x, p.y, Math.cos(angle) * 300, Math.sin(angle) * 300); s.cooldown = 0.3;
    } else if (['shooter', 'tanks', 'survival'].includes(s.id)) { p.x = Math.max(18, Math.min(342, x)); p.y = Math.max(s.id === 'shooter' ? 260 : 18, Math.min(442, y)); }
  }
  release(s: ExpansionState): void { if (s.id === 'fruitslice') { s.target = []; } if (s.id === 'platformer' && s.pieces.length > 0) { s.pieces[0].vx = 0; } }
  private platform(s: ExpansionState, dt: number): void {
    const p: ExpansionPiece = s.pieces[0]; const previousY: number = p.y; if (s.id === 'grapple' && p.vx < 80) { p.vx = 80; }
    p.vy += 650 * dt; p.x = Math.max(16, p.x + p.vx * dt); p.y += p.vy * dt;
    if (s.id === 'grapple' && s.selected >= 0) {
      const anchor: ExpansionPiece | undefined = s.pieces.find((q: ExpansionPiece) => q.id === s.selected);
      if (anchor) {
        const dx: number = p.x - anchor.x; const dy: number = p.y - anchor.y; const distance: number = Math.max(1, Math.hypot(dx, dy));
        if (distance > p.age) {
          p.x = anchor.x + dx / distance * p.age; p.y = anchor.y + dy / distance * p.age;
          const radial: number = (p.vx * dx + p.vy * dy) / distance;
          if (radial > 0) { p.vx -= radial * dx / distance; p.vy -= radial * dy / distance; }
        }
      }
    }
    s.pieces.filter((q: ExpansionPiece) => q.kind === 25).forEach((q: ExpansionPiece) => {
      if (p.vy >= 0 && previousY + p.r <= q.y + 2 && p.y + p.r >= q.y && p.x + p.r > q.x && p.x - p.r < q.x + q.w) { p.y = q.y - p.r; p.vy = 0; }
    });
    s.score = Math.max(s.score, Math.floor(p.x)); if (p.x >= s.goal) { s.outcome = 1; s.score += 500; } else if (p.y > 500) { s.outcome = 2; }
  }
  private fly(s: ExpansionState, dt: number): void {
    const p: ExpansionPiece = s.pieces[0]; p.vy += 530 * dt; p.y += p.vy * dt;
    const gates: ExpansionPiece[] = s.pieces.filter((q: ExpansionPiece) => q.kind === 29);
    gates.forEach((g: ExpansionPiece) => {
      g.x -= (90 + s.level * 10) * dt;
      if (Math.abs(p.x - g.x) < g.w / 2 + p.r && (p.y - p.r < g.y - g.h / 2 || p.y + p.r > g.y + g.h / 2)) { s.outcome = 2; }
      if (g.x + g.w / 2 < p.x - p.r && g.age === 0) { g.age = 1; s.cursor++; s.score += 100; }
      if (g.x < -40) { g.alive = false; }
    });
    if (gates[gates.length - 1].x < 200 && s.cursor + gates.filter((g: ExpansionPiece) => g.age === 0).length < s.goal) { this.gate(s, 410); }
    if (p.y < p.r || p.y > 460 - p.r) { s.outcome = 2; } else if (s.cursor >= s.goal) { s.outcome = 1; }
  }
  private fruits(s: ExpansionState, dt: number): void {
    s.cooldown -= dt;
    if (s.cooldown <= 0) {
      const p: ExpansionPiece = this.piece(s, this.pick(7) === 0 ? 31 : 30, 35 + this.pick(290), 440, 20); p.color = 1 + this.pick(6); p.vx = 40 - this.pick(80); p.vy = -340 - this.pick(70); s.cooldown = Math.max(0.35, 0.8 - s.level * 0.15);
    }
    s.pieces.forEach((p: ExpansionPiece) => { p.vy += 500 * dt; p.x += p.vx * dt; p.y += p.vy * dt; if (p.y > 490 || p.x < -40 || p.x > 400) { p.alive = false; if (p.kind === 30) { s.errors++; } } });
    if (s.errors >= 5 || s.time >= 60) { s.outcome = 2; }
  }
  private roll(s: ExpansionState, dt: number): void {
    const p: ExpansionPiece = s.pieces[0]; const oldX: number = p.x; const oldY: number = p.y;
    p.x = Math.max(p.r, Math.min(360 - p.r, p.x + p.vx * dt)); p.y = Math.max(p.r, Math.min(460 - p.r, p.y + p.vy * dt)); p.vx *= Math.pow(0.9, dt); p.vy *= Math.pow(0.9, dt);
    s.pieces.slice(1).forEach((q: ExpansionPiece) => {
      if (q.kind === 26 && p.x + p.r > q.x && p.x - p.r < q.x + q.w && p.y + p.r > q.y && p.y - p.r < q.y + q.h) { p.x = oldX; p.y = oldY; p.vx *= -0.4; p.vy *= -0.4; }
      if (q.kind === 31 && Math.hypot(p.x - q.x, p.y - q.y) < q.r) { s.outcome = 2; }
      if (q.kind === 27 && Math.hypot(p.x - q.x, p.y - q.y) < 18) { s.outcome = 1; s.score = Math.max(100, 1500 - Math.floor(s.time * 10)); }
    });
  }
  private combat(s: ExpansionState, dt: number): void {
    const player: ExpansionPiece = s.pieces[0]; s.cooldown = Math.max(0, s.cooldown - dt); player.age = Math.max(0, player.age - dt);
    if (s.cursor < s.goal && s.time >= s.cursor * (s.id === 'survival' ? 1.05 - s.level * 0.1 : 1.6)) {
      const enemy: ExpansionPiece = this.piece(s, 33, 25 + this.pick(310), 20, 15); enemy.w = s.id === 'survival' ? 2 : 1 + Math.floor(s.level / 2); enemy.color = 2; enemy.age = 1.5; s.cursor++;
    }
    if (s.id !== 'fortress' && player.age <= 0) {
      const enemies: ExpansionPiece[] = s.pieces.filter((q: ExpansionPiece) => q.kind === 33 && q.alive);
      if (s.id === 'shooter') { this.shoot(s, player.x, player.y - 20, 0, -330); }
      else if (enemies.length > 0) {
        enemies.sort((a: ExpansionPiece, b: ExpansionPiece) => Math.hypot(a.x - player.x, a.y - player.y) - Math.hypot(b.x - player.x, b.y - player.y));
        const enemy: ExpansionPiece = enemies[0]; const distance: number = Math.max(1, Math.hypot(enemy.x - player.x, enemy.y - player.y));
        this.shoot(s, player.x, player.y, (enemy.x - player.x) / distance * 290, (enemy.y - player.y) / distance * 290);
      } player.age = s.id === 'shooter' ? 0.28 : 0.48;
    }
    const enemies: ExpansionPiece[] = s.pieces.filter((q: ExpansionPiece) => q.kind === 33 && q.alive);
    enemies.forEach((q: ExpansionPiece) => {
      if (s.id === 'survival' || s.id === 'tanks') { const d: number = Math.max(1, Math.hypot(player.x - q.x, player.y - q.y)); q.x += (player.x - q.x) / d * (s.id === 'tanks' ? 22 : 45) * dt; q.y += (player.y - q.y) / d * (s.id === 'tanks' ? 22 : 45) * dt; }
      else { q.y += (32 + s.level * 7) * dt; }
      q.age = Math.max(0, q.age - dt);
      if (s.id === 'tanks' && q.age <= 0) { const angle: number = Math.atan2(player.y - q.y, player.x - q.x); this.shoot(s, q.x, q.y, Math.cos(angle) * 120, Math.sin(angle) * 120, 1); q.age = 2.5; }
      if (q.y >= 430 || Math.hypot(player.x - q.x, player.y - q.y) < 28) { q.alive = false; s.data[0] -= s.id === 'fortress' ? 15 : 1; s.moves++; }
    });
    s.pieces.filter((q: ExpansionPiece) => q.kind === 34 && q.alive).forEach((b: ExpansionPiece) => {
      b.x += b.vx * dt; b.y += b.vy * dt;
      if (b.owner === 1 && Math.hypot(b.x - player.x, b.y - player.y) < 20) { b.alive = false; s.data[0]--; }
      else if (b.owner === 0) {
        const hit: ExpansionPiece | undefined = enemies.find((q: ExpansionPiece) => q.alive && Math.hypot(b.x - q.x, b.y - q.y) < q.r + b.r);
        if (hit) {
          b.alive = false;
          const splash: ExpansionPiece[] = s.id === 'fortress' ? enemies.filter((q: ExpansionPiece) => q.alive && Math.hypot(q.x - hit.x, q.y - hit.y) < 45) : [hit];
          splash.forEach((q: ExpansionPiece) => { q.w -= s.next; if (q.w <= 0) { q.alive = false; s.moves++; s.score += 100; s.data[1] += 5; } });
        }
      }
      if (b.x < -10 || b.x > 370 || b.y < -10 || b.y > 470) { b.alive = false; }
    });
    if (s.data[0] <= 0) { s.data[0] = 0; s.outcome = 2; } else if (s.cursor === s.goal && s.moves === s.goal) { s.outcome = 1; }
  }
  step(s: ExpansionState, dt: number): void {
    s.time += dt;
    if (s.id === 'platformer' || s.id === 'grapple') { this.platform(s, dt); } else if (s.id === 'flappy') { this.fly(s, dt); }
    else if (s.id === 'fruitslice') { this.fruits(s, dt); } else if (s.id === 'rollingball') { this.roll(s, dt); } else { this.combat(s, dt); }
    s.pieces = s.pieces.filter((p: ExpansionPiece) => p.alive); s.cooldown = Math.max(0, s.cooldown); s.errors = Math.min(5, s.errors);
  }
  valid(s: ExpansionState): boolean {
    if (!ACTION_IDS.includes(s.id) || s.cols !== (s.id === 'backpack' ? 4 : 6) || s.rows !== (s.id === 'backpack' ? 4 : 6) || s.piles.length !== 0 || s.pieces.length > 60 || !V.numbers(s.data, 2, 0, 100000)) { return false; }
    if (s.id === 'backpack') { return s.phase === 0 && s.goal === 5 && V.numbers(s.board, 16, 0, 4) && s.pieces.length === 0 && V.numbers(s.tray, 4, 1, 4) && s.selected >= 0 && s.selected < 4 && s.cursor <= 5 && s.data[1] <= 100 && s.target.length === 0; }
    if (s.board.length !== 0 || s.tray.length !== 0 || s.pieces.some((p: ExpansionPiece) => !p.alive || p.id >= s.serial || p.kind < 24 || p.kind > 34 || p.x < -80 || p.x > 2400 || p.y < -600 || p.y > 510 || p.r < 0 || p.r > 30)) { return false; }
    if (s.id === 'fruitslice') { return s.goal === 20 + s.level * 10 && s.errors <= 5 && (s.target.length === 0 || V.numbers(s.target, 2, 0, 460)) && s.pieces.every((p: ExpansionPiece) => p.kind === 30 || p.kind === 31); }
    if (s.pieces.length === 0 || s.pieces[0].kind !== (s.id === 'rollingball' ? 32 : 24) || s.target.length !== 0) { return false; }
    if (s.id === 'platformer' || s.id === 'grapple') { return s.goal === (s.id === 'platformer' ? 900 + s.level * 240 : 900 + s.level * 180) && s.pieces.filter((p: ExpansionPiece) => p.kind === 27).length === 1; }
    if (s.id === 'flappy') { return s.goal === 8 + s.level * 4 && s.cursor <= s.goal && s.pieces.slice(1).every((p: ExpansionPiece) => p.kind === 29 && p.w === 52 && p.h === 160 - s.level * 12 && p.age <= 1); }
    if (s.id === 'rollingball') { return s.goal === 1 && s.pieces.length === 6 + s.level; }
    return s.goal === (s.id === 'survival' ? 24 + s.level * 8 : 18 + s.level * 6) && s.cursor <= s.goal && s.moves <= s.goal && s.data[0] <= (s.id === 'fortress' ? 100 : 3) && s.pieces.slice(1).every((p: ExpansionPiece) => p.kind === 33 || p.kind === 34);
  }
}
