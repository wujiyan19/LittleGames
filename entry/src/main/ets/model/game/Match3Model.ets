/**
 * 消消乐（Match3）—— Model 层（纯逻辑，零 ArkUI 依赖）
 *
 * 只负责棋盘规则：生成无三连棋盘、查找连线、消除、重力下落、补位。
 * 随机数通过 RandomSource 接口注入（生产 RealRandom，测试 SeededRandom）。
 */
import { RandomSource } from './RandomSource';

const ROWS = 8;
const COLS = 8;
const GEM_TYPES = 6;

/** 消除结果：新棋盘 + 被消除数量 */
export class RemoveResult {
  board: number[][];
  removedCount: number;

  constructor(board: number[][], removedCount: number) {
    this.board = board;
    this.removedCount = removedCount;
  }
}

/** 交换结果：新棋盘 + 是否形成连线 */
export class SwapResult {
  board: number[][];
  hasMatch: boolean;

  constructor(board: number[][], hasMatch: boolean) {
    this.board = board;
    this.hasMatch = hasMatch;
  }
}

/** 连锁消除单轮结果 */
export class ChainRoundResult {
  board: number[][];
  removedCount: number;
  chainLevel: number;

  constructor(board: number[][], removedCount: number, chainLevel: number) {
    this.board = board;
    this.removedCount = removedCount;
    this.chainLevel = chainLevel;
  }
}

/** 连锁消除完整结果：最终棋盘 + 总得分增量 + 连锁轮数 */
export class ChainResult {
  board: number[][];
  totalGained: number;
  chainRounds: number;

  constructor(board: number[][], totalGained: number, chainRounds: number) {
    this.board = board;
    this.totalGained = totalGained;
    this.chainRounds = chainRounds;
  }
}

export class Match3Rules {
  getRows(): number { return ROWS; }
  getCols(): number { return COLS; }
  getGemTypes(): number { return GEM_TYPES; }

  /** 生成无现成三连且至少有一步合法交换的 8×8 棋盘 */
  generateBoard(rng: RandomSource): number[][] {
    for (let attempt = 0; attempt < 1000; attempt++) {
      const board: number[][] = this.randomBoard(rng);
      if (!this.hasMatches(board) && this.hasLegalSwap(board)) {
        return board;
      }
    }
    // 随机源退化时仍须提供可玩的棋盘。
    return this.fallbackBoard();
  }

  private fallbackBoard(): number[][] {
    const board: number[][] = [];
    for (let r = 0; r < ROWS; r++) {
      const row: number[] = [];
      for (let c = 0; c < COLS; c++) {
        row.push((r + c) % GEM_TYPES);
      }
      board.push(row);
    }
    // 交换 (0,1) 和 (1,1) 后，首行前三格形成三连。
    board[0][2] = 0;
    board[1][1] = 0;
    return board;
  }

  private randomBoard(rng: RandomSource): number[][] {
    const board: number[][] = [];
    for (let r = 0; r < ROWS; r++) {
      const row: number[] = [];
      for (let c = 0; c < COLS; c++) {
        row.push(Math.floor(rng.next() * GEM_TYPES));
      }
      board.push(row);
    }
    return board;
  }

  /** 棋盘是否存在任何 ≥3 同色横竖连线 */
  hasMatches(board: number[][]): boolean {
    // 横向检查
    for (let r = 0; r < ROWS; r++) {
      for (let c = 0; c < COLS - 2; c++) {
        if (board[r][c] >= 0 && board[r][c] === board[r][c + 1] && board[r][c] === board[r][c + 2]) {
          return true;
        }
      }
    }
    // 纵向检查
    for (let c = 0; c < COLS; c++) {
      for (let r = 0; r < ROWS - 2; r++) {
        if (board[r][c] >= 0 && board[r][c] === board[r + 1][c] && board[r][c] === board[r + 2][c]) {
          return true;
        }
      }
    }
    return false;
  }

  /** 稳定棋盘上是否存在能形成三连的相邻交换 */
  hasLegalSwap(board: number[][]): boolean {
    if (this.hasMatches(board)) { return false; }
    const candidate: number[][] = this.clone(board);
    for (let r = 0; r < ROWS; r++) {
      for (let c = 0; c < COLS; c++) {
        if (c + 1 < COLS && candidate[r][c] !== candidate[r][c + 1]) {
          const current: number = candidate[r][c];
          const other: number = candidate[r][c + 1];
          candidate[r][c] = other;
          candidate[r][c + 1] = current;
          const legal: boolean = this.hasMatches(candidate);
          candidate[r][c] = current;
          candidate[r][c + 1] = other;
          if (legal) { return true; }
        }
        if (r + 1 < ROWS && candidate[r][c] !== candidate[r + 1][c]) {
          const current: number = candidate[r][c];
          const other: number = candidate[r + 1][c];
          candidate[r][c] = other;
          candidate[r + 1][c] = current;
          const legal: boolean = this.hasMatches(candidate);
          candidate[r][c] = current;
          candidate[r + 1][c] = other;
          if (legal) { return true; }
        }
      }
    }
    return false;
  }

  /** 查找所有匹配格，返回 boolean[][] 标记 */
  findMatches(board: number[][]): boolean[][] {
    const matched: boolean[][] = [];
    for (let r = 0; r < ROWS; r++) {
      const row: boolean[] = [];
      for (let c = 0; c < COLS; c++) {
        row.push(false);
      }
      matched.push(row);
    }

    // 横向连线
    for (let r = 0; r < ROWS; r++) {
      let c = 0;
      while (c < COLS) {
        if (board[r][c] < 0) { c++; continue; }
        let len = 1;
        while (c + len < COLS && board[r][c + len] === board[r][c] && board[r][c + len] >= 0) {
          len++;
        }
        if (len >= 3) {
          for (let k = 0; k < len; k++) {
            matched[r][c + k] = true;
          }
        }
        c += len;
      }
    }

    // 纵向连线
    for (let c = 0; c < COLS; c++) {
      let r = 0;
      while (r < ROWS) {
        if (board[r][c] < 0) { r++; continue; }
        let len = 1;
        while (r + len < ROWS && board[r + len][c] === board[r][c] && board[r + len][c] >= 0) {
          len++;
        }
        if (len >= 3) {
          for (let k = 0; k < len; k++) {
            matched[r + k][c] = true;
          }
        }
        r += len;
      }
    }

    return matched;
  }

  /** 判断两个格是否相邻（上下左右） */
  isAdjacent(r1: number, c1: number, r2: number, c2: number): boolean {
    const dr = Math.abs(r1 - r2);
    const dc = Math.abs(c1 - c2);
    return (dr === 1 && dc === 0) || (dr === 0 && dc === 1);
  }

  /** 交换两格位置，返回新棋盘 */
  swap(board: number[][], r1: number, c1: number, r2: number, c2: number): number[][] {
    const next = this.clone(board);
    const temp = next[r1][c1];
    next[r1][c1] = next[r2][c2];
    next[r2][c2] = temp;
    return next;
  }

  /** 尝试交换并检查是否形成连线 */
  trySwap(board: number[][], r1: number, c1: number, r2: number, c2: number): SwapResult {
    const swapped = this.swap(board, r1, c1, r2, c2);
    const hasMatch = this.hasMatches(swapped);
    return new SwapResult(swapped, hasMatch);
  }

  /** 消除匹配格（标记为 -1），返回新棋盘和消除数量 */
  removeMatches(board: number[][], matched: boolean[][]): RemoveResult {
    const next = this.clone(board);
    let removedCount = 0;
    for (let r = 0; r < ROWS; r++) {
      for (let c = 0; c < COLS; c++) {
        if (matched[r][c]) {
          next[r][c] = -1;
          removedCount++;
        }
      }
    }
    return new RemoveResult(next, removedCount);
  }

  /** 重力下落 + 顶部随机补位，返回填满的新棋盘 */
  applyGravity(board: number[][], rng: RandomSource): number[][] {
    const next = this.clone(board);
    for (let c = 0; c < COLS; c++) {
      // 将非空宝石向下压实
      let writeRow = ROWS - 1;
      for (let r = ROWS - 1; r >= 0; r--) {
        if (next[r][c] >= 0) {
          if (writeRow !== r) {
            next[writeRow][c] = next[r][c];
            next[r][c] = -1;
          }
          writeRow--;
        }
      }
      // 顶部空缺补随机新宝石
      for (let r = writeRow; r >= 0; r--) {
        next[r][c] = Math.floor(rng.next() * GEM_TYPES);
      }
    }
    return next;
  }

  /**
   * 完整连锁消除流程：从当前棋盘出发，反复查找→消除→补位，直到无连线。
   * 计分规则：第 N 轮消除每个宝石 10×N 分。
   * 返回最终棋盘、总得分增量、连锁轮数。
   */
  resolveChain(board: number[][], rng: RandomSource): ChainResult {
    let currentBoard = board;
    let totalGained = 0;
    let chainRounds = 0;

    while (this.hasMatches(currentBoard)) {
      chainRounds++;
      const matched = this.findMatches(currentBoard);
      const removeRes = this.removeMatches(currentBoard, matched);
      const points = removeRes.removedCount * 10 * chainRounds;
      totalGained += points;
      currentBoard = this.applyGravity(removeRes.board, rng);
    }

    // 连锁结束后的死局重新发牌，分数和剩余步数由调用方保留。
    if (!this.hasLegalSwap(currentBoard)) {
      currentBoard = this.generateBoard(rng);
    }
    return new ChainResult(currentBoard, totalGained, chainRounds);
  }

  private clone(board: number[][]): number[][] {
    const arr: number[][] = [];
    for (let i = 0; i < board.length; i++) {
      arr.push(board[i].slice());
    }
    return arr;
  }
}