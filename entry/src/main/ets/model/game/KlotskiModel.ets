/**
 * 华容道 —— Model 层（纯逻辑，零 ArkUI 依赖）
 *
 * 棋子数据 + 布局 + 移动规则 + 胜利判定。grid 由棋子推导，移动/应用返回新棋子数组。
 */
import { GameDifficulty } from '../../common/GameConstants';

export class KlotskiBlock {
  id: string;
  w: number;
  h: number;
  x: number;
  y: number;
  target: boolean;

  constructor(id: string, w: number, h: number, x: number, y: number, target: boolean) {
    this.id = id;
    this.w = w;
    this.h = h;
    this.x = x;
    this.y = y;
    this.target = target;
  }
}

export class KlotskiRules {
  private readonly bw: number;
  private readonly bh: number;

  constructor(bw: number, bh: number) {
    this.bw = bw;
    this.bh = bh;
  }

  /** 各难度初始布局 */
  layout(difficulty: GameDifficulty): KlotskiBlock[] {
    if (difficulty === GameDifficulty.EASY) {
      return [
        new KlotskiBlock('cc', 2, 2, 1, 0, true),
        new KlotskiBlock('g1', 1, 2, 0, 0, false),
        new KlotskiBlock('g2', 1, 2, 3, 0, false),
        new KlotskiBlock('b1', 1, 1, 1, 2, false),
        new KlotskiBlock('b2', 1, 1, 2, 2, false)
      ];
    }
    if (difficulty === GameDifficulty.HARD) {
      return [
        new KlotskiBlock('cc', 2, 2, 1, 0, true),
        new KlotskiBlock('g1', 1, 2, 0, 0, false),
        new KlotskiBlock('g2', 1, 2, 3, 0, false),
        new KlotskiBlock('b1', 1, 1, 1, 2, false),
        new KlotskiBlock('b2', 1, 1, 2, 2, false),
        new KlotskiBlock('b3', 1, 1, 0, 3, false),
        new KlotskiBlock('b4', 1, 1, 3, 3, false),
        new KlotskiBlock('b5', 1, 1, 0, 4, false),
        new KlotskiBlock('b6', 1, 1, 3, 4, false)
      ];
    }
    return [
      new KlotskiBlock('cc', 2, 2, 1, 0, true),
      new KlotskiBlock('g1', 1, 2, 0, 0, false),
      new KlotskiBlock('g2', 1, 2, 3, 0, false),
      new KlotskiBlock('b1', 1, 1, 0, 2, false),
      new KlotskiBlock('b2', 1, 1, 1, 2, false),
      new KlotskiBlock('b3', 1, 1, 2, 2, false),
      new KlotskiBlock('b4', 1, 1, 3, 2, false),
      new KlotskiBlock('b5', 1, 1, 0, 3, false),
      new KlotskiBlock('b6', 1, 1, 3, 3, false)
    ];
  }

  /** 由棋子推导占用网格：格内为棋子 id，空为 null */
  buildGrid(blocks: KlotskiBlock[]): (string | null)[][] {
    const arr: (string | null)[][] = [];
    for (let i = 0; i < this.bh; i++) {
      const row: (string | null)[] = [];
      for (let j = 0; j < this.bw; j++) { row[j] = null; }
      arr[i] = row;
    }
    for (let i = 0; i < blocks.length; i++) {
      const b = blocks[i];
      for (let r = b.y; r < b.y + b.h; r++) {
        for (let c = b.x; c < b.x + b.w; c++) { arr[r][c] = b.id; }
      }
    }
    return arr;
  }

  find(blocks: KlotskiBlock[], id: string): KlotskiBlock | undefined {
    for (let i = 0; i < blocks.length; i++) {
      if (blocks[i].id === id) { return blocks[i]; }
    }
    return undefined;
  }

  canMove(blocks: KlotskiBlock[], grid: (string | null)[][], id: string, dx: number, dy: number): boolean {
    const b = this.find(blocks, id);
    if (!b) { return false; }
    const nx = b.x + dx;
    const ny = b.y + dy;
    if (nx < 0 || nx + b.w > this.bw || ny < 0 || ny + b.h > this.bh) { return false; }
    for (let r = ny; r < ny + b.h; r++) {
      for (let c = nx; c < nx + b.w; c++) {
        const occupied = grid[r][c];
        if (occupied !== null && occupied !== id) { return false; }
      }
    }
    return true;
  }

  /** 移动棋子，返回新棋子数组（调用前先 canMove） */
  apply(blocks: KlotskiBlock[], id: string, dx: number, dy: number): KlotskiBlock[] {
    const next: KlotskiBlock[] = [];
    for (let i = 0; i < blocks.length; i++) {
      const b = blocks[i];
      if (b.id === id) {
        next.push(new KlotskiBlock(b.id, b.w, b.h, b.x + dx, b.y + dy, b.target));
      } else {
        next.push(new KlotskiBlock(b.id, b.w, b.h, b.x, b.y, b.target));
      }
    }
    return next;
  }

  /** 曹操（target）到达底部中央即为胜 */
  isWin(block: KlotskiBlock): boolean {
    return block.target && block.x === 1 && block.y === 3;
  }

  score(steps: number): number {
    return Math.max(1, 1000 - steps);
  }

  /** 棋子类型：1=曹操 2=横将 3=竖将 4=小兵 */
  kind(block: KlotskiBlock): number {
    if (block.target) { return 1; }
    if (block.w === 2 && block.h === 1) { return 2; }
    if (block.w === 1 && block.h === 2) { return 3; }
    return 4;
  }

  label(block: KlotskiBlock): string {
    if (block.target) { return '曹'; }
    if ((block.w === 1 && block.h === 2) || (block.w === 2 && block.h === 1)) { return '将'; }
    return '兵';
  }
}
