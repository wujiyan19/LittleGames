/**
 * 随机源抽象（各游戏 Model 共用）
 *
 * 生产用 RealRandom；测试注入 SeededRandom 以获得确定性、可回放的序列。
 */

export interface RandomSource {
  next(): number;
}

export class RealRandom implements RandomSource {
  next(): number {
    return Math.random();
  }
}

export class SeededRandom implements RandomSource {
  private seed: number;

  constructor(seed: number) {
    this.seed = seed;
  }

  next(): number {
    // 线性同余，够测试用；不追求统计质量
    this.seed = (this.seed * 1103515245 + 12345) % 2147483648;
    return this.seed / 2147483648;
  }
}
