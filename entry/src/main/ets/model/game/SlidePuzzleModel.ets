/**
 * 滑动拼图 —— Model 层（纯逻辑，零 ArkUI 依赖）
 *
 * 棋盘用长度 n*n 的一维数组表示，0 为空格。所有操作返回新数组（不可变）。
 * 可解性判定、随机可解洗牌、移动、完成判定都在这里，可脱离 UI 直接单测。
 */
import { RandomSource } from './RandomSource';

export class SlidePuzzleRules {
  private readonly size: number;

  constructor(size: number) {
    this.size = size;
  }

  sizeN(): number { return this.size; }

  /** 完成态：[1,2,...,n*n-1, 0] */
  solvedBoard(): number[] {
    const arr: number[] = [];
    for (let i = 1; i < this.size * this.size; i++) { arr.push(i); }
    arr.push(0);
    return arr;
  }

  /**
   * 是否可解。奇数宽度看逆序数奇偶；偶数宽度看「逆序数 + 空格从底部数的行号」。
   * 注意偶数棋盘是 % 2 === 1 才有解（曾写反导致 4x4 局面全部无解）。
   */
  isSolvable(arr: number[]): boolean {
    let inv = 0;
    const flat: number[] = [];
    for (let i = 0; i < arr.length; i++) {
      if (arr[i] !== 0) { flat.push(arr[i]); }
    }
    for (let i = 0; i < flat.length; i++) {
      for (let j = i + 1; j < flat.length; j++) {
        if (flat[i] > flat[j]) { inv++; }
      }
    }
    if (this.size % 2 === 0) {
      const blankRowFromBottom = this.size - Math.floor(arr.indexOf(0) / this.size);
      return (inv + blankRowFromBottom) % 2 === 1;
    }
    return inv % 2 === 0;
  }

  /** 一次洗牌，再校正逆序奇偶，保证有限时间内返回可解且未完成的棋盘。 */
  shuffle(rng: RandomSource): number[] {
    const n = this.size;
    const nums: number[] = [];
    for (let i = 1; i < n * n; i++) { nums.push(i); }
    nums.push(0);
    for (let i = nums.length - 1; i > 0; i--) {
      const j = Math.floor(rng.next() * (i + 1));
      const tmp = nums[i];
      nums[i] = nums[j];
      nums[j] = tmp;
    }
    if (!this.isSolvable(nums)) {
      // 只交换两个数字，空格所在行不变，奇偶性恰好翻转。
      const first: number = nums[0] === 0 ? 1 : 0;
      const second: number = nums[first + 1] === 0 ? first + 2 : first + 1;
      const tmp: number = nums[first]; nums[first] = nums[second]; nums[second] = tmp;
    }
    if (this.isSolved(nums)) {
      // 从完成态合法移动一格，避免开局已经完成但没有结算。
      nums[nums.length - 1] = nums[nums.length - 2]; nums[nums.length - 2] = 0;
    }
    return nums.slice();
  }

  zeroIndex(board: number[]): number {
    for (let i = 0; i < board.length; i++) {
      if (board[i] === 0) { return i; }
    }
    return -1;
  }

  /** (r,c) 是否与空格相邻（可移动） */
  canMove(board: number[], r: number, c: number): boolean {
    if (!Number.isInteger(r) || !Number.isInteger(c) || r < 0 || c < 0 || r >= this.size || c >= this.size) { return false; }
    const zi = this.zeroIndex(board);
    if (zi < 0) { return false; }
    const zr = Math.floor(zi / this.size);
    const zc = zi % this.size;
    const dr = Math.abs(r - zr);
    const dc = Math.abs(c - zc);
    return (dr === 1 && dc === 0) || (dr === 0 && dc === 1);
  }

  /** 将 (r,c) 与空格交换，返回新数组（调用前应先 canMove） */
  tap(board: number[], r: number, c: number): number[] {
    const next = board.slice();
    if (!this.canMove(board, r, c)) { return next; }
    const zi = this.zeroIndex(next);
    const tapped = r * this.size + c;
    next[zi] = next[tapped];
    next[tapped] = 0;
    return next;
  }

  /** 是否已完成（最后一位应为 0） */
  isSolved(board: number[]): boolean {
    for (let r = 0; r < this.size; r++) {
      for (let c = 0; c < this.size; c++) {
        const v = board[r * this.size + c];
        if (r === this.size - 1 && c === this.size - 1) {
          if (v !== 0) { return false; }
        } else if (v !== r * this.size + c + 1) {
          return false;
        }
      }
    }
    return true;
  }

  /** 步数越少得分越高 */
  score(steps: number): number {
    return Math.max(1, 1000 - steps);
  }
}
