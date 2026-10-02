import { RandomSource, RealRandom } from './RandomSource';

/** Original implementations of traditional boards and generated exercises. No external levels/assets. */
export const COLLECTION_IDS: string[] = ['tictactoe', 'gomoku', 'reversi', 'fourline', 'nim',
  'lights', 'flood', 'maze', 'hanoi', 'peg', 'nonogram', 'arithmetic', 'compare', 'sequence',
  'binary', 'targetsum', 'schulte', 'memorysequence', 'missing', 'reaction'];

export class CollectionState {
  id: string = '';
  level: number = 1;
  cols: number = 3;
  board: number[] = [];
  target: number[] = [];
  choices: number[] = [];
  selected: number = -1;
  player: number = 1;
  moves: number = 0;
  round: number = 0;
  score: number = 0;
  answer: number = 0;
  cursor: number = 0;
  phase: number = 0;
  outcome: number = 0;
  prompt: string = '';
  signalAt: number = 0;
}

export class CollectionModel {
  state: CollectionState = new CollectionState();
  private rng: RandomSource;

  constructor(rng: RandomSource = new RealRandom()) { this.rng = rng; }
  private random(n: number): number { return Math.floor(this.rng.next() * n); }
  private shuffle(values: number[]): number[] {
    for (let i = values.length - 1; i > 0; i--) {
      const j: number = this.random(i + 1);
      const tmp: number = values[i]; values[i] = values[j]; values[j] = tmp;
    }
    return values;
  }
  start(id: string, level: number): void {
    this.state = new CollectionState();
    const s: CollectionState = this.state;
    s.id = id; s.level = level;
    if (id === 'tictactoe' || id === 'gomoku' || id === 'fourline' || id === 'reversi') {
      s.cols = id === 'gomoku' ? 9 : id === 'fourline' ? 7 : id === 'reversi' ? 6 : 3;
      s.board = new Array<number>(s.cols * (id === 'fourline' ? 6 : s.cols)).fill(0);
      if (id === 'reversi') { s.board[14] = 1; s.board[21] = 1; s.board[15] = 2; s.board[20] = 2; }
    } else if (id === 'nim') {
      s.board = [12 + level * 5]; s.choices = [1, 2, 3];
    } else if (id === 'lights') {
      s.cols = 3 + level; s.board = new Array<number>(s.cols * s.cols).fill(0);
      for (let i = 0; i < 6 + level * 3; i++) { this.toggle(this.random(s.board.length)); }
      if (s.board.every((v: number) => v === 0)) { this.toggle(0); }
    } else if (id === 'flood') {
      s.cols = 5 + level; s.board = new Array<number>(s.cols * s.cols).fill(0).map(() => this.random(4));
      s.choices = [0, 1, 2, 3];
      if (s.board.every((v: number) => v === s.board[0])) {
        s.board[s.board.length - 1] = (s.board[0] + 1) % 4;
      }
      // Compute an actual winning path; never impose an unverified random-board limit.
      const original: number[] = s.board.slice(); let solution: number = 0;
      while (!s.board.every((v: number) => v === s.board[0])) {
        let best: number[] = s.board; let bestSize: number = -1;
        for (let color = 0; color < 4; color++) {
          if (color === s.board[0]) { continue; }
          const trial: number[] = s.board.slice(); this.fill(trial, color);
          const size: number = this.regionSize(trial);
          if (size > bestSize) { best = trial; bestSize = size; }
        }
        s.board = best; solution++;
      }
      s.board = original; s.answer = solution + 4 - level;
    } else if (id === 'maze') {
      s.cols = 7 + level * 2; this.makeMaze();
    } else if (id === 'hanoi') {
      s.board = new Array<number>(3 + level).fill(0); s.choices = [0, 1, 2];
    } else if (id === 'peg') {
      s.cols = 5; s.board = new Array<number>(25).fill(-1);
      // Reverse legal jumps from a single peg guarantees at least one solution.
      for (let r = 0; r < 5; r++) {
        for (let c = 0; c < 5; c++) { if (r === 2 || c === 2) { s.board[r * 5 + c] = 0; } }
      }
      s.board[12] = 1;
      this.expandPeg(4 + level, new Set<string>());
    } else if (id === 'nonogram') {
      s.cols = 4 + level; s.board = new Array<number>(s.cols * s.cols).fill(0);
      s.target = s.board.map(() => this.random(2)); s.target[0] = 1;
    } else if (id === 'schulte') {
      s.cols = 3 + level; s.board = this.shuffle(new Array<number>(s.cols * s.cols).fill(0).map((v: number, i: number) => i + 1));
      s.answer = 1;
    } else if (id === 'memorysequence') {
      s.cols = 3; s.board = [1, 2, 3, 4, 5, 6, 7, 8, 9];
      s.target = new Array<number>(4 + level * 2).fill(0).map(() => this.random(9) + 1);
    } else if (id === 'reaction') {
      s.cols = 1; s.board = [0];
    } else { this.question(); }
  }

  isDuel(): boolean { return ['tictactoe', 'gomoku', 'fourline', 'reversi', 'nim'].includes(this.state.id); }
  isQuiz(): boolean { return ['arithmetic', 'compare', 'sequence', 'binary', 'targetsum', 'missing'].includes(this.state.id); }
  private finish(win: boolean): void {
    const s: CollectionState = this.state;
    s.outcome = win ? 1 : 2;
    if (win && !this.isQuiz()) { s.score = Math.max(10, 1000 + s.level * 200 - s.moves * 5); }
  }
  neighbor(index: number, direction: number): number {
    const s: CollectionState = this.state;
    if (index < 0) { return -1; }
    const r: number = Math.floor(index / s.cols); const c: number = index % s.cols;
    const nr: number = r + [-1, 0, 1, 0][direction]; const nc: number = c + [0, 1, 0, -1][direction];
    return nr < 0 || nc < 0 || nc >= s.cols || nr >= s.board.length / s.cols ? -1 : nr * s.cols + nc;
  }
  private toggle(index: number): void {
    const s: CollectionState = this.state; s.board[index] = 1 - s.board[index];
    for (let d = 0; d < 4; d++) { const n: number = this.neighbor(index, d); if (n >= 0) { s.board[n] = 1 - s.board[n]; } }
  }
  private fill(board: number[], value: number): void {
    const old: number = board[0]; if (old === value) { return; }
    const queue: number[] = [0]; board[0] = value;
    for (let i = 0; i < queue.length; i++) {
      for (let d = 0; d < 4; d++) {
        const n: number = this.neighbor(queue[i], d);
        if (n >= 0 && board[n] === old) { board[n] = value; queue.push(n); }
      }
    }
  }
  private regionSize(board: number[]): number {
    const queue: number[] = [0]; const seen: boolean[] = new Array<boolean>(board.length).fill(false); seen[0] = true;
    for (let i = 0; i < queue.length; i++) {
      for (let d = 0; d < 4; d++) {
        const n: number = this.neighbor(queue[i], d);
        if (n >= 0 && !seen[n] && board[n] === board[0]) { seen[n] = true; queue.push(n); }
      }
    }
    return queue.length;
  }
  private makeMaze(): void {
    const s: CollectionState = this.state; s.board = new Array<number>(s.cols * s.cols).fill(1);
    const stack: number[] = [s.cols + 1]; s.board[stack[0]] = 0;
    while (stack.length > 0) {
      const at: number = stack[stack.length - 1]; const dirs: number[] = this.shuffle([0, 1, 2, 3]);
      let carved: boolean = false;
      for (let j = 0; j < dirs.length; j++) {
        const mid: number = this.neighbor(at, dirs[j]); const end: number = this.neighbor(mid, dirs[j]);
        if (end > s.cols && end < s.board.length - s.cols && end % s.cols > 0 && end % s.cols < s.cols - 1 && s.board[end] === 1) {
          s.board[mid] = 0; s.board[end] = 0; stack.push(end); carved = true; break;
        }
      }
      if (!carved) { stack.pop(); }
    }
    s.cursor = s.cols + 1; s.answer = s.board.length - s.cols - 2;
  }
  /** 回溯逆向跳跃，完整生成指定步数；遇到提前封死的分支会换另一条生成路线。 */
  private expandPeg(remaining: number, failed: Set<string>): boolean {
    if (remaining === 0) { return true; }
    const s: CollectionState = this.state; const key: string = s.board.join(',');
    if (failed.has(key)) { return false; }
    const options: number[][] = [];
    for (let i = 0; i < s.board.length; i++) {
      for (let d = 0; d < 4; d++) {
        const mid: number = this.neighbor(i, d); const end: number = this.neighbor(mid, d);
        if (s.board[i] === 1 && mid >= 0 && end >= 0 && s.board[mid] === 0 && s.board[end] === 0) {
          options.push([i, mid, end]);
        }
      }
    }
    const order: number[] = this.shuffle(options.map((option: number[], index: number) => index));
    for (let i = 0; i < order.length; i++) {
      const pick: number[] = options[order[i]];
      s.board[pick[0]] = 0; s.board[pick[1]] = 1; s.board[pick[2]] = 1;
      if (this.expandPeg(remaining - 1, failed)) { return true; }
      s.board[pick[0]] = 1; s.board[pick[1]] = 0; s.board[pick[2]] = 0;
    }
    failed.add(key); return false;
  }
  private lineWin(at: number, player: number): boolean {
    const s: CollectionState = this.state; const needed: number = s.id === 'gomoku' ? 5 : s.id === 'fourline' ? 4 : 3;
    const dr: number[] = [0, 1, 1, 1]; const dc: number[] = [1, 0, 1, -1];
    for (let d = 0; d < 4; d++) {
      let count: number = 1;
      for (let sign = -1; sign <= 1; sign += 2) {
        let r: number = Math.floor(at / s.cols) + dr[d] * sign; let c: number = at % s.cols + dc[d] * sign;
        while (r >= 0 && c >= 0 && c < s.cols && r < s.board.length / s.cols && s.board[r * s.cols + c] === player) {
          count++; r += dr[d] * sign; c += dc[d] * sign;
        }
      }
      if (count >= needed) { return true; }
    }
    return false;
  }
  flips(at: number, player: number): number[] {
    const s: CollectionState = this.state; const result: number[] = [];
    if (s.board[at] !== 0) { return result; }
    for (let dr = -1; dr <= 1; dr++) {
      for (let dc = -1; dc <= 1; dc++) {
        if (dr === 0 && dc === 0) { continue; }
        let r: number = Math.floor(at / s.cols) + dr; let c: number = at % s.cols + dc;
        const line: number[] = [];
        while (r >= 0 && c >= 0 && r < s.cols && c < s.cols && s.board[r * s.cols + c] === 3 - player) {
          line.push(r * s.cols + c); r += dr; c += dc;
        }
        if (r >= 0 && c >= 0 && r < s.cols && c < s.cols && s.board[r * s.cols + c] === player) { result.push(...line); }
      }
    }
    return result;
  }
  private canFlip(player: number): boolean {
    for (let i = 0; i < this.state.board.length; i++) { if (this.flips(i, player).length > 0) { return true; } }
    return false;
  }

  tap(index: number, now: number = Date.now()): void {
    const s: CollectionState = this.state;
    if (s.outcome !== 0 || !Number.isInteger(index) || index < 0 || index >= s.board.length) { return; }
    if (s.id === 'reaction') { this.react(now); return; }
    if (s.id === 'tictactoe' || s.id === 'gomoku' || s.id === 'fourline') {
      let at: number = index;
      if (s.id === 'fourline') {
        at = -1;
        for (let r = 5; r >= 0; r--) { if (s.board[r * s.cols + index % s.cols] === 0) { at = r * s.cols + index % s.cols; break; } }
      }
      if (at < 0 || s.board[at] !== 0) { return; }
      s.board[at] = s.player; s.moves++;
      if (this.lineWin(at, s.player)) { s.outcome = s.player; }
      else if (!s.board.includes(0)) { s.outcome = 3; }
      else { s.player = 3 - s.player; }
    } else if (s.id === 'reversi') {
      const captured: number[] = this.flips(index, s.player); if (captured.length === 0) { return; }
      s.board[index] = s.player; captured.forEach((at: number) => { s.board[at] = s.player; }); s.moves++;
      s.player = 3 - s.player;
      if (!this.canFlip(s.player)) { s.player = 3 - s.player; }
      if (!this.canFlip(s.player)) {
        const a: number = s.board.filter((v: number) => v === 1).length;
        const b: number = s.board.filter((v: number) => v === 2).length;
        s.outcome = a === b ? 3 : a > b ? 1 : 2;
      }
    } else if (s.id === 'lights') {
      this.toggle(index); s.moves++; if (s.board.every((v: number) => v === 0)) { this.finish(true); }
    } else if (s.id === 'maze') {
      if (s.board[index] !== 0) { return; }
      if (![0, 1, 2, 3].some((d: number) => this.neighbor(s.cursor, d) === index)) { return; }
      s.cursor = index; s.moves++; if (index === s.answer) { this.finish(true); }
    } else if (s.id === 'peg') { this.peg(index); }
    else if (s.id === 'nonogram') { s.board[index] = 1 - s.board[index]; s.moves++; }
    else if (s.id === 'schulte') {
      s.moves++; if (s.board[index] === s.answer) { s.answer++; }
      if (s.answer > s.board.length) { this.finish(true); }
    } else if (s.id === 'memorysequence' && s.phase === 1) {
      s.moves++; if (s.board[index] !== s.target[s.cursor]) { this.finish(false); }
      else { s.cursor++; if (s.cursor === s.target.length) { this.finish(true); } }
    }
  }
  private peg(index: number): void {
    const s: CollectionState = this.state;
    if (s.board[index] === 1) { s.selected = index; return; }
    if (s.selected < 0 || s.board[index] !== 0) { return; }
    for (let d = 0; d < 4; d++) {
      const mid: number = this.neighbor(s.selected, d);
      if (this.neighbor(mid, d) === index && mid >= 0 && s.board[mid] === 1) {
        s.board[s.selected] = 0; s.board[mid] = 0; s.board[index] = 1; s.selected = -1; s.moves++;
        if (s.board.filter((v: number) => v === 1).length === 1) { this.finish(true); return; }
        for (let i = 0; i < s.board.length; i++) {
          for (let dir = 0; dir < 4; dir++) {
            const m: number = this.neighbor(i, dir); const e: number = this.neighbor(m, dir);
            if (s.board[i] === 1 && m >= 0 && e >= 0 && s.board[m] === 1 && s.board[e] === 0) { return; }
          }
        }
        this.finish(false); return;
      }
    }
  }
  choose(index: number): void {
    const s: CollectionState = this.state;
    if (s.outcome !== 0 || index < 0 || index >= s.choices.length || !Number.isInteger(index)) { return; }
    const value: number = s.choices[index];
    if (s.id === 'nim') {
      if (value > s.board[0]) { return; }
      s.board[0] -= value; s.moves++;
      if (s.board[0] === 0) { s.outcome = s.player; } else { s.player = 3 - s.player; }
    } else if (s.id === 'hanoi') {
      const top: number = s.board.indexOf(value);
      if (s.selected < 0) { if (top >= 0) { s.selected = value; } return; }
      const disc: number = s.board.indexOf(s.selected);
      if (s.selected === value) { s.selected = -1; return; }
      if (top < 0 || disc < top) { s.board[disc] = value; s.moves++; s.selected = -1; }
      if (s.board.every((v: number) => v === 2)) { this.finish(true); }
    } else if (s.id === 'flood') {
      const old: number = s.board[0]; if (old === value) { return; }
      this.fill(s.board, value);
      s.moves++;
      if (s.board.every((v: number) => v === value)) { this.finish(true); }
      else if (s.moves >= s.answer) { this.finish(false); }
    } else if (this.isQuiz()) {
      if (s.id === 'missing' && s.phase === 0) { return; }
      s.moves++; if (value === s.answer) { s.score += 100 * (s.level + 1); }
      s.round++; if (s.round >= 10) { s.outcome = 1; } else { this.question(); }
    }
  }
  action(): void {
    const s: CollectionState = this.state; if (s.outcome !== 0) { return; }
    if (s.id === 'memorysequence' || s.id === 'missing') { s.phase = 1; }
    if (s.id === 'nonogram') {
      s.moves++;
      for (let axis = 0; axis < 2; axis++) {
        for (let i = 0; i < s.cols; i++) {
          if (this.clue(s.board, i, axis === 1) !== this.clue(s.target, i, axis === 1)) { return; }
        }
      }
      this.finish(true);
    }
  }
  clue(values: number[], line: number, column: boolean): string {
    const groups: number[] = []; let count: number = 0;
    for (let i = 0; i <= this.state.cols; i++) {
      const value: number = i === this.state.cols ? 0 : values[column ? i * this.state.cols + line : line * this.state.cols + i];
      if (value === 1) { count++; } else if (count > 0) { groups.push(count); count = 0; }
    }
    return groups.length > 0 ? groups.join(' ') : '0';
  }
  private question(): void {
    const s: CollectionState = this.state; const a: number = this.random(10 + s.level * 15) + 1;
    const b: number = this.random(9) + 1; s.phase = 0; s.board = []; s.target = [];
    if (s.id === 'arithmetic') {
      const op: number = this.random(3);
      s.answer = op === 0 ? a + b : op === 1 ? a - b : a * b;
      s.prompt = a + [' + ', ' − ', ' × '][op] + b + ' = ?';
    } else if (s.id === 'compare') {
      const c: number = this.random(20) + 1; const d: number = this.random(20) + 1;
      s.answer = a + b < c + d ? -1 : a + b === c + d ? 0 : 1;
      s.prompt = '(' + a + ' + ' + b + ')  ?  (' + c + ' + ' + d + ')'; s.choices = [-1, 0, 1]; return;
    } else if (s.id === 'sequence') {
      const step: number = b; s.target = [a, a + step, a + step * 2, a + step * 3];
      if (s.level === 2 && this.random(2) === 0) { s.target = [b, b * 2, b * 4, b * 8]; s.answer = b * 16; }
      else { s.answer = a + step * 4; }
      s.prompt = s.target.join(' · ') + ' · ?';
    } else if (s.id === 'binary') { s.answer = this.random(16 * (s.level + 1)); s.prompt = s.answer.toString(2) + '₂ = ?₁₀'; }
    else if (s.id === 'targetsum') {
      s.target = [a, b, this.random(15) + 1]; s.answer = s.target[2];
      s.prompt = a + ' + ' + b + ' + ? = ' + (a + b + s.answer);
    } else if (s.id === 'missing') {
      s.target = this.shuffle(new Array<number>(20).fill(0).map((v: number, i: number) => i + 1)).slice(0, 4 + s.level);
      s.answer = s.target[this.random(s.target.length)]; s.board = s.target.filter((v: number) => v !== s.answer);
      s.choices = this.shuffle(s.target.slice()); return;
    }
    s.choices = [s.answer];
    const offsets: number[] = [];
    for (let offset = -9; offset <= 9; offset++) { if (offset !== 0) { offsets.push(offset); } }
    this.shuffle(offsets);
    for (let i = 0; i < 3; i++) { s.choices.push(s.answer + offsets[i]); }
    this.shuffle(s.choices);
  }
  private react(now: number): void {
    const s: CollectionState = this.state;
    if (s.phase === 0) { s.phase = 1; s.signalAt = now + 1500 + this.random(2500); }
    else if (s.phase === 1) { s.outcome = 2; }
    else {
      const elapsed: number = Math.max(0, now - s.signalAt);
      s.answer = elapsed; s.score = Math.max(0, 2000 - elapsed); s.outcome = 1;
    }
  }
  tick(now: number): void {
    const s: CollectionState = this.state;
    if (s.id === 'reaction' && s.outcome === 0 && s.phase === 1 && now >= s.signalAt) {
      s.phase = 2; s.signalAt = now;
    }
  }
}
