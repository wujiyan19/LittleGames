/**
 * 俄罗斯方块 —— Model 层（纯逻辑，零 ArkUI 依赖）
 *
 * 棋盘用不可变风格：lock/clearRows 返回新棋盘，调用方（ViewModel）整体替换，
 * 既符合 V2「深层更新走 copy-on-write」的约定，也让规则可脱离 UI 直接单测。
 */
import { RandomSource } from './RandomSource';

// 每种方块的完整旋转状态
export const SHAPES: number[][][][] = [
  // I
  [[[1, 1, 1, 1]], [[1], [1], [1], [1]]],
  // O
  [[[1, 1], [1, 1]]],
  // T
  [[[0, 1, 0], [1, 1, 1]], [[1, 0], [1, 1], [1, 0]], [[1, 1, 1], [0, 1, 0]], [[0, 1], [1, 1], [0, 1]]],
  // S
  [[[0, 1, 1], [1, 1, 0]], [[1, 0], [1, 1], [0, 1]]],
  // Z
  [[[1, 1, 0], [0, 1, 1]], [[0, 1], [1, 1], [1, 0]]],
  // L
  [[[1, 0, 0], [1, 1, 1]], [[1, 1], [1, 0], [1, 0]], [[1, 1, 1], [0, 0, 1]], [[0, 1], [0, 1], [1, 1]]],
  // J
  [[[0, 0, 1], [1, 1, 1]], [[1, 0], [1, 0], [1, 1]], [[1, 1, 1], [1, 0, 0]], [[1, 1], [0, 1], [0, 1]]]
];

/** 当前下落方块（纯数据，无颜色——颜色由形状索引在 View 查表） */
export class ActivePiece {
  idx: number;
  rot: number;
  x: number;
  y: number;

  constructor(idx: number, rot: number, x: number, y: number) {
    this.idx = idx;
    this.rot = rot;
    this.x = x;
    this.y = y;
  }
}

/** 消行结果：新棋盘 + 消除行数 */
export class ClearResult {
  board: number[][];
  lines: number;

  constructor(board: number[][], lines: number) {
    this.board = board;
    this.lines = lines;
  }
}

/**
 * 俄罗斯方块规则。无状态：棋盘与当前方块由调用方传入。
 * 棋盘约定：0 = 空格，n = 第 (n-1) 号形状占据。
 */
export class TetrisRules {
  private readonly cols: number;
  private readonly rows: number;

  constructor(cols: number, rows: number) {
    this.cols = cols;
    this.rows = rows;
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

  rotationCount(idx: number): number {
    return SHAPES[idx].length;
  }

  /** 随机生成下落方块，水平居中、置于顶部 */
  spawn(rng: RandomSource): ActivePiece {
    const idx = Math.floor(rng.next() * SHAPES.length);
    const width = SHAPES[idx][0][0].length;
    const x = Math.floor((this.cols - width) / 2);
    return new ActivePiece(idx, 0, x, 0);
  }

  canPlace(board: number[][], piece: ActivePiece, dx: number, dy: number): boolean {
    const shape = SHAPES[piece.idx][piece.rot];
    for (let r = 0; r < shape.length; r++) {
      for (let c = 0; c < shape[r].length; c++) {
        if (shape[r][c]) {
          const nx = piece.x + c + dx;
          const ny = piece.y + r + dy;
          if (nx < 0 || nx >= this.cols || ny >= this.rows) { return false; }
          if (ny >= 0 && board[ny][nx] !== 0) { return false; }
        }
      }
    }
    return true;
  }

  /** 旋转一格（带回踢）。无法旋转时返回原 piece（不可变，不修改入参） */
  rotated(board: number[][], piece: ActivePiece): ActivePiece {
    const count = SHAPES[piece.idx].length;
    if (count <= 1) { return piece; }
    const nextRot = (piece.rot + 1) % count;
    const offsets = [0, -1, 1, -2, 2];
    for (let k = 0; k < offsets.length; k++) {
      const kicked = new ActivePiece(piece.idx, nextRot, piece.x + offsets[k], piece.y);
      if (this.canPlace(board, kicked, 0, 0)) { return kicked; }
    }
    return piece;
  }

  /** 硬降的最终 y（不修改入参） */
  hardDropY(board: number[][], piece: ActivePiece): number {
    const probe = new ActivePiece(piece.idx, piece.rot, piece.x, piece.y);
    while (this.canPlace(board, probe, 0, 1)) { probe.y++; }
    return probe.y;
  }

  /** 锁定到棋盘，返回新棋盘 */
  lock(board: number[][], piece: ActivePiece): number[][] {
    const next: number[][] = [];
    for (let i = 0; i < this.rows; i++) { next.push(board[i].slice()); }
    const shape = SHAPES[piece.idx][piece.rot];
    const mark = piece.idx + 1;
    for (let r = 0; r < shape.length; r++) {
      for (let c = 0; c < shape[r].length; c++) {
        if (shape[r][c] && piece.y + r >= 0) {
          next[piece.y + r][piece.x + c] = mark;
        }
      }
    }
    return next;
  }

  /** 消行，返回新棋盘与消除行数 */
  clearRows(board: number[][]): ClearResult {
    let lines = 0;
    const kept: number[][] = [];
    for (let i = 0; i < board.length; i++) {
      let full = true;
      for (let j = 0; j < board[i].length; j++) {
        if (board[i][j] === 0) { full = false; break; }
      }
      if (full) {
        lines++;
      } else {
        kept.push(board[i]);
      }
    }
    while (kept.length < this.rows) {
      const row: number[] = [];
      for (let j = 0; j < this.cols; j++) { row[j] = 0; }
      kept.splice(0, 0, row);
    }
    return new ClearResult(kept, lines);
  }

  scoreForLines(lines: number, level: number): number {
    const scores = [0, 100, 300, 500, 800];
    return scores[Math.min(lines, 4)] * level;
  }

  /** 某格最终显示标记：0=空；(idx+1)=已落定或当前方块占据。供 View 映射颜色 */
  cellMark(board: number[][], piece: ActivePiece | null, r: number, c: number): number {
    if (board[r][c] !== 0) { return board[r][c]; }
    if (piece) {
      const shape = SHAPES[piece.idx][piece.rot];
      const cr = r - piece.y;
      const cc = c - piece.x;
      if (cr >= 0 && cr < shape.length && cc >= 0 && cc < shape[0].length && shape[cr][cc]) {
        return piece.idx + 1;
      }
    }
    return 0;
  }
}
