/**
 * 打地鼠 —— Model 层（纯逻辑，零 ArkUI 依赖）
 */
import { GameDifficulty } from '../../common/GameConstants';
import { RandomSource } from './RandomSource';

export const HOLE_COUNT = 9;

/** 敲击结果：新洞穴状态 + 分数增量（命中 +10 / 落空 -5） */
export class WhackResult {
  holes: boolean[];
  delta: number;

  constructor(holes: boolean[], delta: number) {
    this.holes = holes;
    this.delta = delta;
  }
}

export class WhackMoleRules {
  getGameTime(difficulty: GameDifficulty): number {
    if (difficulty === GameDifficulty.EASY) { return 40; }
    if (difficulty === GameDifficulty.HARD) { return 20; }
    return 30;
  }

  getSpawnInterval(difficulty: GameDifficulty): number {
    if (difficulty === GameDifficulty.EASY) { return 1000; }
    if (difficulty === GameDifficulty.HARD) { return 600; }
    return 800;
  }

  initialHoles(): boolean[] {
    const arr: boolean[] = [];
    for (let i = 0; i < HOLE_COUNT; i++) { arr.push(false); }
    return arr;
  }

  /** 随机在洞穴里放 1 或 2 只地鼠 */
  spawnHoles(rng: RandomSource): boolean[] {
    const next = this.initialHoles();
    const count = rng.next() < 0.3 ? 2 : 1;
    let placed = 0;
    while (placed < count) {
      const idx = Math.floor(rng.next() * HOLE_COUNT);
      if (!next[idx]) { next[idx] = true; placed++; }
    }
    return next;
  }

  /** 敲击某洞：命中则清除并 +10，落空 -5（分数下限由调用方处理） */
  whack(holes: boolean[], index: number): WhackResult {
    const next = holes.slice();
    if (next[index]) {
      next[index] = false;
      return new WhackResult(next, 10);
    }
    return new WhackResult(next, -5);
  }
}
