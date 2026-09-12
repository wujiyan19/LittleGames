/**
 * 数独 —— Model 层（纯逻辑，零 ArkUI 依赖）
 *
 * 位掩码回溯求解器 + 题面生成（唯一解校验）+ 完成校验。
 * 一维 81 格棋盘（0 为空）。生成用注入的 RandomSource，便于确定性单测。
 */
import { GameDifficulty } from '../../common/GameConstants';
import { RandomSource, SeededRandom } from './RandomSource';

/** 生成的题面 + 指纹（供「不连续重复」去重） */
export class PuzzleResult {
  puzzle: number[];
  key: string;

  constructor(puzzle: number[], key: string) {
    this.puzzle = puzzle;
    this.key = key;
  }
}

export class SudokuRules {
  // 位掩码求解器状态（实例级草稿区）
  private rowMask: Int32Array = new Int32Array(9);
  private colMask: Int32Array = new Int32Array(9);
  private boxMask: Int32Array = new Int32Array(9);
  private bitToVal: Int8Array = new Int8Array(512);
  private popCount: Int8Array = new Int8Array(512);
  private boxOf: Int8Array = new Int8Array(81);
  private solutionCount: number = 0;

  constructor() {
    for (let i = 0; i < 81; i++) {
      this.boxOf[i] = Math.floor(i / 27) * 3 + Math.floor((i % 9) / 3);
    }
    for (let m = 1; m < 512; m++) {
      this.popCount[m] = this.popCount[m >> 1] + (m & 1);
    }
    for (let v = 1; v <= 9; v++) {
      this.bitToVal[1 << (v - 1)] = v;
    }
  }

  emptyGrid(): number[] {
    const arr: number[] = [];
    for (let i = 0; i < 81; i++) { arr[i] = 0; }
    return arr;
  }

  copyGrid(src: number[]): number[] {
    const dst: number[] = [];
    for (let i = 0; i < 81; i++) { dst[i] = src[i]; }
    return dst;
  }

  targetClues(difficulty: GameDifficulty): number {
    if (difficulty === GameDifficulty.EASY) { return 45; }
    if (difficulty === GameDifficulty.HARD) { return 23; }
    return 29;
  }

  private shuffled9(rng: RandomSource): number[] {
    const arr = [1, 2, 3, 4, 5, 6, 7, 8, 9];
    for (let i = 8; i > 0; i--) {
      const j = Math.floor(rng.next() * (i + 1));
      const t = arr[i];
      arr[i] = arr[j];
      arr[j] = t;
    }
    return arr;
  }

  // 依据当前棋盘重建行/列/宫占用掩码
  private buildMasks(grid: number[]): void {
    for (let i = 0; i < 9; i++) {
      this.rowMask[i] = 0;
      this.colMask[i] = 0;
      this.boxMask[i] = 0;
    }
    for (let i = 0; i < 81; i++) {
      const v = grid[i];
      if (v === 0) { continue; }
      const bit = 1 << (v - 1);
      const b = this.boxOf[i];
      this.rowMask[Math.floor(i / 9)] = this.rowMask[Math.floor(i / 9)] | bit;
      this.colMask[i % 9] = this.colMask[i % 9] | bit;
      this.boxMask[b] = this.boxMask[b] | bit;
    }
  }

  private candidateMask(idx: number): number {
    return (~(this.rowMask[Math.floor(idx / 9)] | this.colMask[idx % 9] | this.boxMask[this.boxOf[idx]])) & 0x1FF;
  }

  // 回溯填满一个完整解（MRV 选格）
  private fillSolutionBit(grid: number[], rng: RandomSource): boolean {
    let idx = -1;
    let bestMask = 0;
    let bestLen = 10;
    for (let i = 0; i < 81; i++) {
      if (grid[i] !== 0) { continue; }
      const mask = this.candidateMask(i);
      if (mask === 0) { return false; }
      const len = this.popCount[mask];
      if (len < bestLen) {
        bestLen = len;
        idx = i;
        bestMask = mask;
        if (len === 1) { break; }
      }
    }
    if (idx === -1) { return true; }
    const r = Math.floor(idx / 9);
    const c = idx % 9;
    const b = this.boxOf[idx];
    const order = this.shuffled9(rng);
    for (let k = 0; k < order.length; k++) {
      const v = order[k];
      const bit = 1 << (v - 1);
      if ((bestMask & bit) === 0) { continue; }
      grid[idx] = v;
      this.rowMask[r] = this.rowMask[r] | bit;
      this.colMask[c] = this.colMask[c] | bit;
      this.boxMask[b] = this.boxMask[b] | bit;
      if (this.fillSolutionBit(grid, rng)) { return true; }
      grid[idx] = 0;
      this.rowMask[r] = this.rowMask[r] ^ bit;
      this.colMask[c] = this.colMask[c] ^ bit;
      this.boxMask[b] = this.boxMask[b] ^ bit;
    }
    return false;
  }

  generateSolution(rng: RandomSource): number[] {
    const grid = this.emptyGrid();
    this.buildMasks(grid);
    this.fillSolutionBit(grid, rng);
    return grid;
  }

  // 数解的个数，找到 2 个就提前退出（唯一解校验只需知道是否 > 1）
  private solveCountBit(grid: number[]): void {
    if (this.solutionCount > 1) { return; }
    let bestIdx = -1;
    let bestMask = 0;
    let bestLen = 10;
    for (let i = 0; i < 81; i++) {
      if (grid[i] !== 0) { continue; }
      const mask = this.candidateMask(i);
      if (mask === 0) { return; }
      const len = this.popCount[mask];
      if (len < bestLen) {
        bestLen = len;
        bestIdx = i;
        bestMask = mask;
        if (len === 1) { break; }
      }
    }
    if (bestIdx === -1) {
      this.solutionCount++;
      return;
    }
    const r = Math.floor(bestIdx / 9);
    const c = bestIdx % 9;
    const b = this.boxOf[bestIdx];
    let m = bestMask;
    while (m !== 0) {
      const bit = m & (-m);
      m = m ^ bit;
      const v = this.bitToVal[bit];
      grid[bestIdx] = v;
      this.rowMask[r] = this.rowMask[r] | bit;
      this.colMask[c] = this.colMask[c] | bit;
      this.boxMask[b] = this.boxMask[b] | bit;
      this.solveCountBit(grid);
      grid[bestIdx] = 0;
      this.rowMask[r] = this.rowMask[r] ^ bit;
      this.colMask[c] = this.colMask[c] ^ bit;
      this.boxMask[b] = this.boxMask[b] ^ bit;
      if (this.solutionCount > 1) { return; }
    }
  }

  countSolutions(grid: number[]): number {
    this.solutionCount = 0;
    const work = this.copyGrid(grid);
    this.buildMasks(work);
    this.solveCountBit(work);
    return this.solutionCount;
  }

  private boardKey(grid: number[]): string {
    let key = '';
    for (let i = 0; i < 81; i++) { key += grid[i].toString(); }
    return key;
  }

  /**
   * 生成题面：先造完整解，再随机逐格抹除并保证唯一解，直到剩余提示数达标。
   * 返回的指纹取自真正返回的题面（此前记的是最后一次候选，导致去重失效）。
   */
  generatePuzzle(difficulty: GameDifficulty, previousKey: string, rng: RandomSource): PuzzleResult {
    const targetClues = this.targetClues(difficulty);
    for (let attempt = 0; attempt < 30; attempt++) {
      const solution = this.generateSolution(rng);
      const candidate = this.copyGrid(solution);
      const cells: number[] = [];
      for (let i = 0; i < 81; i++) { cells.push(i); }
      for (let i = 80; i > 0; i--) {
        const j = Math.floor(rng.next() * (i + 1));
        const t = cells[i];
        cells[i] = cells[j];
        cells[j] = t;
      }
      let clues = 81;
      for (let k = 0; k < cells.length && clues > targetClues; k++) {
        const idx = cells[k];
        const saved = candidate[idx];
        candidate[idx] = 0;
        if (this.countSolutions(candidate) !== 1) {
          candidate[idx] = saved;
        } else {
          clues--;
        }
      }
      const key = this.boardKey(candidate);
      if (key !== previousKey) {
        return new PuzzleResult(candidate, key);
      }
    }
    const fb = this.fallbackPuzzle(difficulty);
    return new PuzzleResult(fb, this.boardKey(fb));
  }

  /**
   * 兜底题面：用固定种子确定性地从某个解抹格（并保持唯一解），保证一定可解且唯一。
   * 原实现硬编码的困难题面解不唯一（单测已抓出），硬编码再漂亮也不如由求解器兜底可靠。
   */
  fallbackPuzzle(difficulty: GameDifficulty): number[] {
    const rng: RandomSource = new SeededRandom(20240912);
    const solution = this.generateSolution(rng);
    const candidate = this.copyGrid(solution);
    const cells: number[] = [];
    for (let i = 0; i < 81; i++) { cells.push(i); }
    for (let i = 80; i > 0; i--) {
      const j = Math.floor(rng.next() * (i + 1));
      const t = cells[i];
      cells[i] = cells[j];
      cells[j] = t;
    }
    const targetClues = this.targetClues(difficulty);
    let clues = 81;
    for (let k = 0; k < cells.length && clues > targetClues; k++) {
      const idx = cells[k];
      const saved = candidate[idx];
      candidate[idx] = 0;
      if (this.countSolutions(candidate) !== 1) {
        candidate[idx] = saved;
      } else {
        clues--;
      }
    }
    return candidate;
  }

  private isValidAt(grid: number[], r: number, c: number, v: number): boolean {
    for (let i = 0; i < 9; i++) {
      if (i !== c && grid[r * 9 + i] === v) { return false; }
      if (i !== r && grid[i * 9 + c] === v) { return false; }
    }
    const br = Math.floor(r / 3) * 3;
    const bc = Math.floor(c / 3) * 3;
    for (let i = br; i < br + 3; i++) {
      for (let j = bc; j < bc + 3; j++) {
        if ((i !== r || j !== c) && grid[i * 9 + j] === v) { return false; }
      }
    }
    return true;
  }

  /** 全部填满且无冲突即完成 */
  isComplete(grid: number[]): boolean {
    for (let r = 0; r < 9; r++) {
      for (let c = 0; c < 9; c++) {
        const v = grid[r * 9 + c];
        if (v === 0 || !this.isValidAt(grid, r, c, v)) { return false; }
      }
    }
    return true;
  }
}
