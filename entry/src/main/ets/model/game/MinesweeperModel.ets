/**
 * 扫雷 —— Model 层（纯逻辑，零 ArkUI 依赖）
 *
 * 棋盘/揭开/插旗都用不可变风格：每次操作返回新状态，调用方整体替换。
 * 首点安全（推迟布雷）与连锁展开都在这里，可脱离 UI 直接单测。
 * 棋盘约定：-1 = 雷，0..8 = 周围雷数。
 */
import { RandomSource } from './RandomSource';

/** 揭开结果：新 revealed + 是否踩雷 */
export class RevealResult {
  revealed: boolean[][];
  hitMine: boolean;

  constructor(revealed: boolean[][], hitMine: boolean) {
    this.revealed = revealed;
    this.hitMine = hitMine;
  }
}

export class MinesweeperRules {
  private readonly rows: number;
  private readonly cols: number;

  constructor(rows: number, cols: number) {
    this.rows = rows;
    this.cols = cols;
  }

  emptyBoard(): number[][] {
    const arr: number[][] = [];
    for (let i = 0; i < this.rows; i++) {
      const row: number[] = [];
      for (let j = 0; j < this.cols; j++) { row[j] = 0; }
      arr[i] = row;
    }
    return arr;
  }

  emptyBool(): boolean[][] {
    const arr: boolean[][] = [];
    for (let i = 0; i < this.rows; i++) {
      const row: boolean[] = [];
      for (let j = 0; j < this.cols; j++) { row[j] = false; }
      arr[i] = row;
    }
    return arr;
  }

  private copyNum(src: number[][]): number[][] {
    const arr: number[][] = [];
    for (let i = 0; i < src.length; i++) { arr.push(src[i].slice()); }
    return arr;
  }

  private copyBool(src: boolean[][]): boolean[][] {
    const arr: boolean[][] = [];
    for (let i = 0; i < src.length; i++) {
      const row: boolean[] = [];
      for (let j = 0; j < src[i].length; j++) { row[j] = src[i][j]; }
      arr.push(row);
    }
    return arr;
  }

  /** 周围 8 格雷数 */
  countMines(board: number[][], r: number, c: number): number {
    let cnt = 0;
    for (let dr = -1; dr <= 1; dr++) {
      for (let dc = -1; dc <= 1; dc++) {
        const nr = r + dr;
        const nc = c + dc;
        if (nr >= 0 && nr < this.rows && nc >= 0 && nc < this.cols && board[nr][nc] === -1) {
          cnt++;
        }
      }
    }
    return cnt;
  }

  /**
   * 布雷并计算数字，返回新棋盘。
   * 排除首点格及其 3×3 邻域：首点必为 0，可直接展开一片（首点安全）。
   */
  placeMines(board: number[][], mineCount: number, safeR: number, safeC: number, rng: RandomSource): number[][] {
    const next = this.copyNum(board);
    let placed = 0;
    while (placed < mineCount) {
      const r = Math.floor(rng.next() * this.rows);
      const c = Math.floor(rng.next() * this.cols);
      if (Math.abs(r - safeR) <= 1 && Math.abs(c - safeC) <= 1) { continue; }
      if (next[r][c] !== -1) { next[r][c] = -1; placed++; }
    }
    for (let r = 0; r < this.rows; r++) {
      for (let c = 0; c < this.cols; c++) {
        if (next[r][c] !== -1) { next[r][c] = this.countMines(next, r, c); }
      }
    }
    return next;
  }

  /**
   * 揭开 (r,c)：
   * - 踩雷 → hitMine=true（只揭开该格）
   * - 数字格 → 只揭开该格
   * - 空格(0) → 连锁展开（BFS，跳过插旗格，不展开到旗上）
   * 用索引指针代替 Array.shift()，避免 O(n²)。
   */
  reveal(board: number[][], revealed: boolean[][], flagged: boolean[][], r: number, c: number): RevealResult {
    const next = this.copyBool(revealed);
    next[r][c] = true;
    if (board[r][c] === -1) { return new RevealResult(next, true); }
    if (board[r][c] === 0) {
      const queue: number[] = [r * this.cols + c];
      let head = 0;
      while (head < queue.length) {
        const idx = queue[head];
        head++;
        const cr = Math.floor(idx / this.cols);
        const cc = idx % this.cols;
        for (let dr = -1; dr <= 1; dr++) {
          for (let dc = -1; dc <= 1; dc++) {
            const nr = cr + dr;
            const nc = cc + dc;
            if (nr >= 0 && nr < this.rows && nc >= 0 && nc < this.cols &&
                !next[nr][nc] && !flagged[nr][nc]) {
              next[nr][nc] = true;
              if (board[nr][nc] === 0) { queue.push(nr * this.cols + nc); }
            }
          }
        }
      }
    }
    return new RevealResult(next, false);
  }

  /** 翻转旗帜，返回新 flagged */
  toggleFlag(revealed: boolean[][], flagged: boolean[][], r: number, c: number): boolean[][] {
    const next = this.copyBool(flagged);
    next[r][c] = !next[r][c];
    return next;
  }

  countFlags(flagged: boolean[][]): number {
    let cnt = 0;
    for (let i = 0; i < flagged.length; i++) {
      for (let j = 0; j < flagged[i].length; j++) {
        if (flagged[i][j]) { cnt++; }
      }
    }
    return cnt;
  }

  /** 经典规则：揭开全部安全格即获胜 */
  allSafeRevealed(board: number[][], revealed: boolean[][]): boolean {
    for (let r = 0; r < this.rows; r++) {
      for (let c = 0; c < this.cols; c++) {
        if (board[r][c] !== -1 && !revealed[r][c]) { return false; }
      }
    }
    return true;
  }
}
