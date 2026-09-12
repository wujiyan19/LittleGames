/**
 * 2048 —— Model 层（纯逻辑，零 ArkUI 依赖）
 *
 * 只负责棋盘规则：生成新块、滑动合并、判负。滑动/合并返回新棋盘（不可变），
 * 动画与方块身份(id/缩放)属于表现层，留在 View。
 */
import { RandomSource } from './RandomSource';

export enum SwipeDir { LEFT, RIGHT, UP, DOWN }

/** 生成新块的结果；无空格时 row=-1、棋盘不变 */
export class SpawnResult {
  board: number[][];
  row: number;
  col: number;
  value: number;

  constructor(board: number[][], row: number, col: number, value: number) {
    this.board = board;
    this.row = row;
    this.col = col;
    this.value = value;
  }
}

/** 滑动结果：新棋盘 + 是否变化 + 本次合并得分 */
export class SwipeResult {
  board: number[][];
  changed: boolean;
  gained: number;

  constructor(board: number[][], changed: boolean, gained: number) {
    this.board = board;
    this.changed = changed;
    this.gained = gained;
  }
}

class MergeLineResult {
  values: number[];
  gained: number;

  constructor(values: number[], gained: number) {
    this.values = values;
    this.gained = gained;
  }
}

export class Game2048Rules {
  private readonly size: number;

  constructor(size: number) {
    this.size = size;
  }

  emptyBoard(): number[][] {
    const arr: number[][] = [];
    for (let i = 0; i < this.size; i++) {
      const row: number[] = [];
      for (let j = 0; j < this.size; j++) { row[j] = 0; }
      arr[i] = row;
    }
    return arr;
  }

  private clone(board: number[][]): number[][] {
    const arr: number[][] = [];
    for (let i = 0; i < board.length; i++) { arr.push(board[i].slice()); }
    return arr;
  }

  /** 在空格中随机放一个 2 或 4（fourChance 为出 4 的概率） */
  spawn(board: number[][], fourChance: number, rng: RandomSource): SpawnResult {
    const empty: number[] = [];
    for (let r = 0; r < this.size; r++) {
      for (let c = 0; c < this.size; c++) {
        if (board[r][c] === 0) { empty.push(r * this.size + c); }
      }
    }
    if (empty.length === 0) { return new SpawnResult(board, -1, -1, 0); }
    const flat = empty[Math.floor(rng.next() * empty.length)];
    const row = Math.floor(flat / this.size);
    const col = flat % this.size;
    const value = rng.next() < (1 - fourChance) ? 2 : 4;
    const next = this.clone(board);
    next[row][col] = value;
    return new SpawnResult(next, row, col, value);
  }

  /** 单行左对齐合并（纯函数） */
  private mergeLine(line: number[]): MergeLineResult {
    const filtered: number[] = [];
    for (let i = 0; i < line.length; i++) {
      if (line[i] > 0) { filtered.push(line[i]); }
    }
    const values: number[] = [];
    let gained = 0;
    let k = 0;
    while (k < filtered.length) {
      if (k + 1 < filtered.length && filtered[k] === filtered[k + 1]) {
        values.push(filtered[k] * 2);
        gained += filtered[k] * 2;
        k += 2;
      } else {
        values.push(filtered[k]);
        k += 1;
      }
    }
    while (values.length < this.size) { values.push(0); }
    return new MergeLineResult(values, gained);
  }

  swipe(board: number[][], dir: SwipeDir): SwipeResult {
    const next = this.emptyBoard();
    let gained = 0;
    for (let i = 0; i < this.size; i++) {
      const line: number[] = [];
      for (let j = 0; j < this.size; j++) {
        if (dir === SwipeDir.LEFT) { line.push(board[i][j]); }
        else if (dir === SwipeDir.RIGHT) { line.push(board[i][this.size - 1 - j]); }
        else if (dir === SwipeDir.UP) { line.push(board[j][i]); }
        else { line.push(board[this.size - 1 - j][i]); }
      }
      const merged = this.mergeLine(line);
      gained += merged.gained;
      for (let j = 0; j < this.size; j++) {
        if (dir === SwipeDir.LEFT) { next[i][j] = merged.values[j]; }
        else if (dir === SwipeDir.RIGHT) { next[i][this.size - 1 - j] = merged.values[j]; }
        else if (dir === SwipeDir.UP) { next[j][i] = merged.values[j]; }
        else { next[this.size - 1 - j][i] = merged.values[j]; }
      }
    }
    let changed = false;
    for (let r = 0; r < this.size && !changed; r++) {
      for (let c = 0; c < this.size; c++) {
        if (board[r][c] !== next[r][c]) { changed = true; break; }
      }
    }
    return new SwipeResult(next, changed, gained);
  }

  isGameOver(board: number[][]): boolean {
    for (let r = 0; r < this.size; r++) {
      for (let c = 0; c < this.size; c++) {
        if (board[r][c] === 0) { return false; }
        if (c + 1 < this.size && board[r][c] === board[r][c + 1]) { return false; }
        if (r + 1 < this.size && board[r][c] === board[r + 1][c]) { return false; }
      }
    }
    return true;
  }
}
