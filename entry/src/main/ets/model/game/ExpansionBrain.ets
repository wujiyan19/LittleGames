import { ExpansionState, ExpansionPiece } from './ExpansionState';
import { RandomSource } from './RandomSource';
import { ContinuationValidation as V } from '../../common/GameSessionTransfer';

export const BRAIN_IDS: string[] = ['onestroke', 'hiddenobjects', 'linerescue', 'picturepuzzle', 'idiom', 'wordtower', 'beatjump', 'melody'];
export const IDIOMS: string[] = ['一心一意', '画龙点睛', '守株待兔', '亡羊补牢', '掩耳盗铃', '井底之蛙', '刻舟求剑', '对牛弹琴', '水滴石穿', '狐假虎威', '画蛇添足', '胸有成竹', '愚公移山', '精卫填海', '杯弓蛇影', '叶公好龙'];
export const IDIOM_PARTS: string[] = IDIOMS.join('').split('').filter((v: string, i: number, all: string[]) => all.indexOf(v) === i);
export class ExpansionBrain {
  private random: RandomSource;
  constructor(random: RandomSource) { this.random = random; }
  realtime(id: string): boolean { return ['linerescue', 'wordtower', 'beatjump', 'melody'].includes(id); }
  private pick(n: number): number { return Math.min(n - 1, Math.max(0, Math.floor(this.random.next() * n))); }
  private shuffle(values: number[]): void { for (let i: number = values.length - 1; i > 0; i--) { const j: number = this.pick(i + 1); const t: number = values[i]; values[i] = values[j]; values[j] = t; } }
  private piece(s: ExpansionState, kind: number, x: number, y: number, r: number): ExpansionPiece {
    const p: ExpansionPiece = new ExpansionPiece(); p.id = s.serial++; p.kind = kind; p.x = x; p.y = y; p.r = r; s.pieces.push(p); return p;
  }
  start(s: ExpansionState): void {
    if (s.id === 'onestroke') {
      s.cols = 3; s.rows = 3; s.board = [0, 1, 1, 2, 2, 5, 5, 8, 8, 7, 7, 6, 6, 3, 3, 0, 1, 4, 4, 7];
      if (s.level > 0) { s.board.push(3, 4, 4, 5, 5, 3); } if (s.level > 1) { s.board.push(0, 4, 4, 8, 8, 0); }
      s.goal = s.board.length / 2; const used: boolean[] = new Array<boolean>(s.goal).fill(false); const stack: number[] = [1]; const path: number[] = [];
      while (stack.length > 0) { const node: number = stack[stack.length - 1]; const edges: number[] = used.map((v: boolean, i: number) => i).filter((i: number) => !used[i] && (s.board[i * 2] === node || s.board[i * 2 + 1] === node));
        if (edges.length === 0) { path.push(stack.pop() ?? 0); } else { const edge: number = edges[this.pick(edges.length)]; used[edge] = true; stack.push(s.board[edge * 2] === node ? s.board[edge * 2 + 1] : s.board[edge * 2]); }
      } s.target = path.reverse(); return;
    }
    if (s.id === 'hiddenobjects') {
      s.cols = 6; s.rows = 6; s.goal = 6; s.board = new Array<number>(36).fill(0).map(() => 1 + this.pick(9)); const colors: number[] = [1, 2, 3, 4, 5, 6, 7, 8, 9]; this.shuffle(colors); s.target = colors.slice(0, 6);
      s.target.forEach((v: number, i: number) => { s.board[i * 6 + i] = v; }); return;
    }
    if (s.id === 'picturepuzzle') {
      s.cols = 3 + s.level; s.rows = s.cols; s.goal = s.cols * s.cols; s.board = new Array<number>(s.goal).fill(0).map((v: number, i: number) => i); this.shuffle(s.board);
      if (s.board.every((v: number, i: number) => v === i)) { s.board.reverse(); } return;
    }
    if (s.id === 'idiom') { s.cols = 4; s.rows = 1; s.goal = 8; s.data = [0, 0]; s.tray = new Array<number>(IDIOMS.length).fill(0).map((v: number, i: number) => i); this.shuffle(s.tray); this.idiomQuestion(s); return; }
    s.cols = 6; s.rows = 6;
    if (s.id === 'linerescue') {
      s.goal = 10; this.piece(s, 55, 180, 250, 22);
      for (let i: number = 0; i < 4 + s.level; i++) { const bee: ExpansionPiece = this.piece(s, 56, i % 2 === 0 ? 30 : 330, 55 + i * 45, 10); bee.color = 2; } return;
    }
    if (s.id === 'wordtower') {
      s.board = [1, 1, 1, 0, 0, 0]; s.data = [18, 100, 0]; s.goal = 12 + s.level * 4;
      for (let slot: number = 0; slot < 3; slot++) { this.towerPiece(s, slot, 1); } return;
    }
    s.goal = s.id === 'melody' ? 5 : 16 + s.level * 8; s.target = new Array<number>(s.id === 'melody' ? 3 : s.goal).fill(0).map(() => this.pick(s.id === 'melody' ? 4 : 3)); s.data = [0, 0];
    if (s.id === 'beatjump') { const p: ExpansionPiece = this.piece(s, 58, 180, 350, 18); p.owner = 1; s.cooldown = 1.2; }
  }
  private idiomQuestion(s: ExpansionState): void {
    s.data[0] = s.tray[s.moves]; s.data[1] = s.level === 0 ? 3 : this.pick(4); s.target = IDIOMS[s.data[0]].split('').map((v: string) => IDIOM_PARTS.indexOf(v));
    const correct: number = s.target[s.data[1]]; const candidates: number[] = new Array<number>(IDIOM_PARTS.length).fill(0).map((v: number, i: number) => i).filter((v: number) => v !== correct); this.shuffle(candidates); s.board = [correct, ...candidates.slice(0, 3)]; this.shuffle(s.board);
  }
  private towerPiece(s: ExpansionState, slot: number, color: number): void { const p: ExpansionPiece = this.piece(s, 57, 70 + slot % 3 * 110, 290 + Math.floor(slot / 3) * 95, 23); p.owner = slot; p.color = color; }
  activate(s: ExpansionState): void {
    if (!this.realtime(s.id) || (s.id === 'linerescue' && s.target.length < 4)) { return; }
    s.phase = 1; if (s.id === 'melody') { s.cursor = 0; s.data[0] = 0; s.cooldown = 0; s.selected = -1; }
  }
  tap(s: ExpansionState, at: number): void {
    if (s.id === 'onestroke') {
      if (at >= 9) { return; } if (s.selected < 0) { s.selected = at; return; }
      const edge: number = s.board.findIndex((v: number, i: number) => i % 2 === 0 && !s.tray.includes(i / 2) && ((v === s.selected && s.board[i + 1] === at) || (v === at && s.board[i + 1] === s.selected)));
      if (edge >= 0) { s.tray.push(edge / 2); s.selected = at; s.moves++; s.score += 50; if (s.tray.length === s.goal) { s.outcome = 1; } } return;
    }
    if (s.id === 'hiddenobjects') {
      if (at >= 36 || s.tray.includes(s.board[at])) { return; }
      if (s.target.includes(s.board[at])) { s.tray.push(s.board[at]); s.moves++; s.score += 100; if (s.tray.length === s.goal) { s.outcome = 1; } }
      else { s.errors++; if (s.errors >= 3) { s.outcome = 2; } } return;
    }
    if (s.id === 'picturepuzzle') {
      if (at >= s.board.length) { return; } if (s.selected < 0) { s.selected = at; return; } if (at === s.selected) { s.selected = -1; return; }
      const temp: number = s.board[at]; s.board[at] = s.board[s.selected]; s.board[s.selected] = temp; s.selected = -1; s.moves++;
      if (s.board.every((v: number, i: number) => v === i)) { s.outcome = 1; s.score = Math.max(100, 2000 - s.moves * 20); } return;
    }
    if (s.id === 'idiom') {
      if (at >= 4) { return; }
      if (s.board[at] === s.target[s.data[1]]) { s.moves++; s.score += 100; if (s.moves === s.goal) { s.outcome = 1; } else { this.idiomQuestion(s); } }
      else { s.errors++; if (s.errors === 3) { s.outcome = 2; } } return;
    }
    if (s.id === 'linerescue') { if (at === 900 && s.phase === 0) { s.target = []; } return; }
    if (s.id === 'wordtower') { this.towerTap(s, at); return; }
    if (s.id === 'melody') {
      if (at === 900 && s.phase === 0) { this.activate(s); return; } if (s.phase !== 0 || at >= 4 || s.cursor < s.target.length) { return; }
      s.selected = at;
      if (at !== s.target[s.data[0]]) { s.errors++; if (s.errors === 3) { s.outcome = 2; } else { this.activate(s); } return; }
      s.data[0]++; if (s.data[0] === s.target.length) { s.moves++; s.score += s.target.length * 100; if (s.moves === s.goal) { s.outcome = 1; } else { s.target.push(this.pick(4)); this.activate(s); } } return;
    }
    if (s.id === 'beatjump' && s.phase === 1 && at < 3) {
      if (Math.abs(s.cooldown) > 0.18 || at !== s.target[s.cursor]) { s.errors++; }
      else { const p: ExpansionPiece = s.pieces[0]; p.vx = (60 + at * 120 - p.x) / 0.5; p.vy = -260; p.owner = at; s.moves++; s.score += 100 + Math.round((0.18 - Math.abs(s.cooldown)) * 500); }
      s.cursor++; s.cooldown = 0.95 - s.level * 0.1; this.beatEnd(s);
    }
  }
  private beatEnd(s: ExpansionState): void { if (s.errors >= 5) { s.errors = 5; s.outcome = 2; } else if (s.cursor >= s.goal) { s.outcome = 1; } }
  private towerTap(s: ExpansionState, at: number): void {
    if (at >= 6) { return; }
    if (s.board[at] === 0) { if (s.data[0] < 6) { return; } s.board[at] = s.next; s.data[0] -= 6; this.towerPiece(s, at, s.next); return; }
    if (s.board[at] > 4 || s.tray.includes(at)) { return; }
    if (s.tray.length > 0 && s.board[s.tray[0]] !== s.board[at]) { s.tray = []; } s.tray.push(at);
    if (s.tray.length === 3) {
      const keep: number = s.tray[0]; s.board[keep] += 4;
      s.pieces.forEach((p: ExpansionPiece) => { if (p.kind === 57 && s.tray.includes(p.owner)) { if (p.owner === keep) { p.color = s.board[keep]; } else { p.alive = false; s.board[p.owner] = 0; } } });
      s.pieces = s.pieces.filter((p: ExpansionPiece) => p.alive); s.tray = [];
    }
  }
  choose(s: ExpansionState, index: number): void { if (s.id === 'wordtower' && index < 4) { s.next = index + 1; s.tray = []; } }
  aim(s: ExpansionState, x: number, y: number): void {
    if (s.id !== 'linerescue' || s.phase !== 0 || s.target.length >= 48) { return; }
    const last: number = s.target.length - 2;
    if (last >= 0 && Math.hypot(s.target[last] - x, s.target[last + 1] - y) < 10) { return; }
    let length: number = 0; for (let i: number = 2; i < s.target.length; i += 2) { length += Math.hypot(s.target[i] - s.target[i - 2], s.target[i + 1] - s.target[i - 1]); }
    if (last >= 0 && length + Math.hypot(s.target[last] - x, s.target[last + 1] - y) > 650) { return; } s.target.push(Math.round(x), Math.round(y));
  }
  private rescue(s: ExpansionState, dt: number): void {
    const dog: ExpansionPiece = s.pieces[0];
    s.pieces.slice(1).forEach((bee: ExpansionPiece) => {
      const distance: number = Math.max(1, Math.hypot(dog.x - bee.x, dog.y - bee.y)); bee.x += (dog.x - bee.x) / distance * (48 + s.level * 5) * dt; bee.y += (dog.y - bee.y) / distance * (48 + s.level * 5) * dt;
      for (let i: number = 2; i < s.target.length; i += 2) {
        const x: number = s.target[i - 2]; const y: number = s.target[i - 1]; const dx: number = s.target[i] - x; const dy: number = s.target[i + 1] - y;
        const t: number = Math.max(0, Math.min(1, ((bee.x - x) * dx + (bee.y - y) * dy) / Math.max(1, dx * dx + dy * dy)));
        const nx: number = bee.x - x - t * dx; const ny: number = bee.y - y - t * dy; const d: number = Math.max(0.01, Math.hypot(nx, ny));
        if (d < 14) { bee.x += nx / d * (14 - d); bee.y += ny / d * (14 - d); }
      }
      if (Math.hypot(bee.x - dog.x, bee.y - dog.y) < dog.r + bee.r) { s.outcome = 2; }
    }); if (s.time >= s.goal && s.outcome === 0) { s.outcome = 1; s.score = Math.max(100, 1500 - s.target.length * 10); }
  }
  private towers(s: ExpansionState, dt: number): void {
    if (Math.floor(s.time / 2) > s.data[2]) { s.data[0]++; s.data[2] = Math.floor(s.time / 2); }
    if (s.cursor < s.goal && s.time >= s.cursor * 1.4) { const enemy: ExpansionPiece = this.piece(s, 56, 40 + this.pick(280), 15, 14); enemy.w = 6 + s.level * 4; enemy.color = 1 + this.pick(4); s.cursor++; }
    const enemies: ExpansionPiece[] = s.pieces.filter((p: ExpansionPiece) => p.kind === 56 && p.alive);
    s.pieces.filter((p: ExpansionPiece) => p.kind === 57).forEach((tower: ExpansionPiece) => {
      tower.age = Math.max(0, tower.age - dt); const enemy: ExpansionPiece | undefined = enemies.find((p: ExpansionPiece) => p.alive && Math.hypot(p.x - tower.x, p.y - tower.y) < 200);
      if (tower.age === 0 && enemy) { enemy.w -= tower.color > 4 ? 3 : 1; tower.age = 0.6; if (enemy.w <= 0) { enemy.alive = false; s.moves++; s.score += 100; s.data[0] += 4; } }
    });
    enemies.forEach((enemy: ExpansionPiece) => { if (enemy.alive) { enemy.y += (22 + s.level * 4) * dt; if (enemy.y > 440) { enemy.alive = false; s.data[1] -= 20; s.moves++; } } });
    s.pieces = s.pieces.filter((p: ExpansionPiece) => p.alive);
    if (s.data[1] <= 0) { s.data[1] = 0; s.outcome = 2; } else if (s.cursor === s.goal && s.moves === s.goal) { s.outcome = 1; }
  }
  step(s: ExpansionState, dt: number): void {
    s.time += dt;
    if (s.id === 'linerescue') { this.rescue(s, dt); } else if (s.id === 'wordtower') { this.towers(s, dt); }
    else if (s.id === 'melody') {
      s.cooldown = Math.max(0, s.cooldown - dt);
      if (s.cooldown === 0) { if (s.cursor < s.target.length) { s.selected = s.target[s.cursor++]; s.data[1]++; s.cooldown = 0.55; } else { s.phase = 0; s.selected = -1; } }
    } else {
      s.cooldown -= dt; const p: ExpansionPiece = s.pieces[0]; p.vy += 1040 * dt; p.y += p.vy * dt; p.x += p.vx * dt;
      if (p.y >= 350) { p.y = 350; p.vy = 0; p.vx = 0; p.x = 60 + p.owner * 120; }
      if (s.cooldown < -0.18) { s.errors++; s.cursor++; s.cooldown = 0.95 - s.level * 0.1; this.beatEnd(s); }
    }
  }
  valid(s: ExpansionState): boolean {
    if (!BRAIN_IDS.includes(s.id) || s.piles.length !== 0) { return false; }
    if (['onestroke', 'hiddenobjects', 'picturepuzzle', 'linerescue'].includes(s.id) && s.data.length !== 0) { return false; }
    if (s.id === 'onestroke') { const expected: number = 10 + s.level * 3; return s.cols === 3 && s.rows === 3 && s.goal === expected && V.numbers(s.board, expected * 2, 0, 8) && V.numbers(s.target, expected + 1, 0, 8) && s.pieces.length === 0 && s.phase === 0 && s.selected < 9 && V.numbers(s.tray, s.tray.length, 0, expected - 1) && new Set<number>(s.tray).size === s.tray.length; }
    if (s.id === 'hiddenobjects') { return s.cols === 6 && s.rows === 6 && s.goal === 6 && V.numbers(s.board, 36, 1, 9) && V.numbers(s.target, 6, 1, 9) && new Set<number>(s.target).size === 6 && s.tray.every((v: number) => s.target.includes(v)) && new Set<number>(s.tray).size === s.tray.length && s.errors <= 3 && s.phase === 0 && s.pieces.length === 0; }
    if (s.id === 'picturepuzzle') { return s.cols === 3 + s.level && s.rows === s.cols && s.goal === s.cols * s.cols && V.numbers(s.board, s.goal, 0, s.goal - 1) && new Set<number>(s.board).size === s.goal && s.selected < s.goal && s.target.length === 0 && s.tray.length === 0 && s.phase === 0 && s.pieces.length === 0; }
    if (s.id === 'idiom') { return s.cols === 4 && s.rows === 1 && s.goal === 8 && s.moves <= 8 && s.errors <= 3 && V.numbers(s.data, 2, 0, IDIOMS.length - 1) && s.data[1] < 4 && V.numbers(s.board, 4, 0, IDIOM_PARTS.length - 1) && V.numbers(s.target, 4, 0, IDIOM_PARTS.length - 1) && V.numbers(s.tray, IDIOMS.length, 0, IDIOMS.length - 1) && new Set<number>(s.tray).size === IDIOMS.length && s.pieces.length === 0 && s.phase === 0; }
    if (s.cols !== 6 || s.rows !== 6 || s.pieces.some((p: ExpansionPiece) => p.id >= s.serial || !p.alive || p.kind < 55 || p.kind > 58 || p.x < -20 || p.x > 380 || p.y < -20 || p.y > 460)) { return false; }
    if (s.id === 'linerescue') { return s.goal === 10 && s.board.length === 0 && s.tray.length === 0 && s.target.length <= 48 && s.target.length % 2 === 0 && V.numbers(s.target, s.target.length, 0, 460) && s.pieces.length === 5 + s.level && s.pieces[0].kind === 55; }
    if (s.id === 'wordtower') { return s.goal === 12 + s.level * 4 && V.numbers(s.board, 6, 0, 8) && V.numbers(s.data, 3, 0, 10000) && s.data[1] <= 100 && s.cursor <= s.goal && s.moves <= s.goal && s.tray.length <= 2 && V.numbers(s.tray, s.tray.length, 0, 5) && s.target.length === 0 && V.integer(s.next, 1, 4) && s.pieces.filter((p: ExpansionPiece) => p.kind === 57).every((p: ExpansionPiece) => p.color === s.board[p.owner]); }
    if (!V.numbers(s.data, 2, 0, 10000) || s.board.length !== 0 || s.tray.length !== 0) { return false; }
    if (s.id === 'melody') { return s.goal === 5 && s.moves <= 5 && s.errors <= 3 && s.pieces.length === 0 && s.target.length >= 3 && s.target.length <= 7 && V.numbers(s.target, s.target.length, 0, 3) && s.cursor <= s.target.length && s.data[0] <= s.target.length && s.selected < 4; }
    return s.goal === 16 + s.level * 8 && V.numbers(s.target, s.goal, 0, 2) && s.cursor <= s.goal && s.errors <= 5 && s.pieces.length === 1 && s.pieces[0].kind === 58;
  }
}
