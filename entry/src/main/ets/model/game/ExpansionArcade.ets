import { ExpansionState, ExpansionPiece } from './ExpansionState';
import { RandomSource } from './RandomSource';

export class ExpansionArcade {
  private random: RandomSource;
  constructor(random: RandomSource) { this.random = random; }
  private pick(n: number): number { return Math.min(n - 1, Math.max(0, Math.floor(this.random.next() * n))); }
  start(s: ExpansionState): void {
    if (s.id === 'roomdefense') {
      s.data = [60, 100]; s.goal = 12 + s.level * 6;
      const base: ExpansionPiece = new ExpansionPiece(); base.id = s.serial++; base.kind = 13; base.x = 180; base.y = 418; base.r = 24; base.color = 4; s.pieces.push(base);
    } else if (s.id === 'basketball') {
      s.data = [0]; s.goal = 5 + s.level; s.next = 16;
      const hoop: ExpansionPiece = new ExpansionPiece(); hoop.id = s.serial++; hoop.kind = 16; hoop.x = 260; hoop.y = 145; hoop.r = 24; hoop.color = 3; s.pieces.push(hoop);
    } else if (s.id === 'rhythm') {
      s.goal = 32 + s.level * 8; s.target = new Array<number>(s.goal).fill(0).map(() => this.pick(4));
    } else { s.goal = 10 + s.level * 5; s.data = [20]; s.board = [0, 0, 0]; this.customer(s); }
  }
  activate(s: ExpansionState): void { s.phase = 1; }
  tap(s: ExpansionState, index: number): void {
    if (s.id === 'roomdefense') {
      if (index > 6) { return; }
      if (index === 6) { if (s.data[0] >= 25 && s.data[1] < 100) { s.data[0] -= 25; s.data[1] = Math.min(100, s.data[1] + 40); } return; }
      const existing: ExpansionPiece | undefined = s.pieces.find((p: ExpansionPiece) => p.kind === 14 && p.owner === index);
      const cost: number = existing ? 20 * existing.color : 30;
      if (s.data[0] < cost || (existing && existing.color >= 3)) { return; } s.data[0] -= cost;
      if (existing) { existing.color++; } else {
        const tower: ExpansionPiece = new ExpansionPiece(); tower.id = s.serial++; tower.kind = 14; tower.owner = index; tower.r = 19;
        tower.x = 70 + (index % 2) * 220; tower.y = 125 + Math.floor(index / 2) * 95; tower.color = 1; s.pieces.push(tower);
      }
    } else if (s.id === 'rhythm') {
      if (s.phase === 0 || index > 3) { return; }
      let chosen: ExpansionPiece | undefined = undefined;
      for (let i: number = 0; i < s.pieces.length; i++) {
        const p: ExpansionPiece = s.pieces[i];
        if (p.owner === index && Math.abs(p.y - 400) <= 38 && (!chosen || p.y > chosen.y)) { chosen = p; }
      }
      if (chosen) { chosen.alive = false; s.score += Math.abs(chosen.y - 400) < 12 ? 150 : 100; s.moves++; }
      else { s.errors++; if (s.errors >= 5) { s.outcome = 2; } }
    } else if (s.id === 'restaurant') {
      if (index < 3 && s.data[0] >= 2 && !s.pieces.some((p: ExpansionPiece) => p.kind === 20 && p.color === index)) {
        const dish: ExpansionPiece = new ExpansionPiece(); dish.id = s.serial++; dish.kind = 20; dish.color = index; dish.age = 2.2; s.pieces.push(dish); s.data[0] -= 2;
      } else if (index >= 100) {
        const customer: ExpansionPiece | undefined = s.pieces.find((p: ExpansionPiece) => p.kind === 19 && p.id === index - 100);
        if (customer && s.board[customer.color] > 0) {
          s.board[customer.color]--; customer.alive = false; s.data[0] += 10; s.score += 100; s.moves++;
          if (s.moves >= s.goal) { s.outcome = 1; }
        }
      }
    }
  }
  aim(s: ExpansionState, x: number, y: number): void {
    if (s.id !== 'basketball' || s.pieces.some((p: ExpansionPiece) => p.kind === 17) || s.moves >= s.next || y >= 390) { return; }
    const ball: ExpansionPiece = new ExpansionPiece(); ball.id = s.serial++; ball.kind = 17; ball.x = 60; ball.y = 410; ball.r = 12; ball.color = 3;
    ball.vx = (x - 60) / 1.6; ball.vy = (y - 410 - 190 * 1.6 * 1.6) / 1.6; s.pieces.push(ball); s.moves++; s.phase = 1;
  }
  private customer(s: ExpansionState): void {
    if (s.pieces.filter((p: ExpansionPiece) => p.kind === 19 && p.alive).length >= 4) { return; }
    const customer: ExpansionPiece = new ExpansionPiece(); customer.id = s.serial++; customer.kind = 19; customer.color = this.pick(3); customer.age = 30 - s.level * 5;
    s.pieces.push(customer); s.cursor++;
  }
  step(s: ExpansionState, dt: number): void {
    const before: number = s.time; s.time += dt; s.cooldown = Math.max(0, s.cooldown - dt);
    if (s.id === 'roomdefense') { this.defense(s, dt, before);
    } else if (s.id === 'basketball') { this.basket(s, dt);
    } else if (s.id === 'rhythm') { this.notes(s, dt);
    } else { this.kitchen(s, dt); }
  }
  private defense(s: ExpansionState, dt: number, before: number): void {
    if (Math.floor(s.time) > Math.floor(before)) { s.data[0] += 5; }
    if (s.cooldown <= 0 && s.cursor < s.goal) {
      const enemy: ExpansionPiece = new ExpansionPiece(); enemy.id = s.serial++; enemy.kind = 15; enemy.r = 14; enemy.x = 30 + this.pick(300); enemy.y = -20;
      enemy.w = 10 + s.level * 5 + Math.floor(s.cursor / 4) * 3; enemy.color = 2; s.pieces.push(enemy); s.cursor++; s.cooldown = 2.3 - s.level * 0.25;
    }
    s.pieces.forEach((p: ExpansionPiece) => {
      p.age = Math.max(0, p.age - dt);
      if (p.kind === 15) {
        const dx: number = 180 - p.x; const dy: number = 418 - p.y; const d: number = Math.sqrt(dx * dx + dy * dy);
        if (d > 35) { p.x += dx / d * (25 + s.level * 8) * dt; p.y += dy / d * (25 + s.level * 8) * dt; }
        else if (p.age <= 0) { s.data[1] -= 8 + s.level * 2; p.age = 1; }
      } else if (p.kind === 14 && p.age <= 0) {
        const targets: ExpansionPiece[] = s.pieces.filter((e: ExpansionPiece) => e.kind === 15 && e.alive && Math.hypot(e.x - p.x, e.y - p.y) <= 150);
        if (targets.length > 0) {
          const e: ExpansionPiece = targets[0]; e.w -= 3 + p.color * 3; p.age = 0.7;
          if (e.w <= 0) { e.alive = false; s.moves++; s.score += 100; s.data[0] += 8; }
        }
      }
    });
    s.pieces = s.pieces.filter((p: ExpansionPiece) => p.alive);
    if (s.data[1] <= 0) { s.data[1] = 0; s.outcome = 2; }
    else if (s.cursor >= s.goal && !s.pieces.some((p: ExpansionPiece) => p.kind === 15)) { s.outcome = 1; }
  }
  private basket(s: ExpansionState, dt: number): void {
    const hoop: ExpansionPiece = s.pieces[0]; hoop.x = 260 + Math.sin(s.time * 0.9) * s.level * 24;
    s.pieces.forEach((p: ExpansionPiece) => {
      if (p.kind !== 17) { return; } const oldY: number = p.y; p.vy += 380 * dt; p.x += p.vx * dt; p.y += p.vy * dt;
      if (p.vy > 0 && oldY <= hoop.y && p.y >= hoop.y && Math.abs(p.x - hoop.x) <= 22) { p.alive = false; s.data[0]++; s.score += 100; }
      else if (p.y > 470 || p.x < -20 || p.x > 380) { p.alive = false; }
    }); s.pieces = s.pieces.filter((p: ExpansionPiece) => p.alive);
    if (s.data[0] >= s.goal) { s.outcome = 1; }
    else if (s.moves >= s.next && s.pieces.length === 1) { s.outcome = 2; }
  }
  private notes(s: ExpansionState, dt: number): void {
    if (s.cooldown <= 0 && s.cursor < s.target.length) {
      const note: ExpansionPiece = new ExpansionPiece(); note.id = s.serial++; note.kind = 18; note.owner = s.target[s.cursor]; note.color = note.owner + 1;
      note.x = 45 + note.owner * 90; note.y = -20; note.r = 20; s.pieces.push(note); s.cursor++; s.cooldown = 0.68 - s.level * 0.08;
    }
    s.pieces.forEach((p: ExpansionPiece) => { p.y += (150 + s.level * 30) * dt; if (p.alive && p.y > 442) { p.alive = false; s.errors++; } });
    s.pieces = s.pieces.filter((p: ExpansionPiece) => p.alive);
    if (s.errors >= 5) { s.outcome = 2; }
    else if (s.cursor >= s.target.length && s.pieces.length === 0) { s.outcome = 1; }
  }
  private kitchen(s: ExpansionState, dt: number): void {
    if (s.cooldown <= 0) { this.customer(s); s.cooldown = 6 - s.level; }
    s.pieces.forEach((p: ExpansionPiece) => {
      p.age -= dt;
      if (p.age <= 0 && p.alive) {
        p.alive = false; if (p.kind === 20) { s.board[p.color]++; } else { s.errors++; }
      }
    }); s.pieces = s.pieces.filter((p: ExpansionPiece) => p.alive);
    if (s.errors >= 5 || s.time >= 120) { s.outcome = 2; }
  }
}
