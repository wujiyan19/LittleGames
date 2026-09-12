/**
 * 猜数字 —— Model 层（纯逻辑，零 ArkUI 依赖）
 *
 * 密码生成 / A-B 判定 / 难度配置 / 计分都在这里，可脱离 UI 直接单测。
 */
import { GameDifficulty } from '../../common/GameConstants';
import { RandomSource } from './RandomSource';

/** 一次猜测的反馈：a = 数字与位置都对，b = 数字对但位置不对 */
export class GuessFeedback {
  a: number;
  b: number;

  constructor(a: number, b: number) {
    this.a = a;
    this.b = b;
  }
}

export class GuessNumberRules {
  secretLength(difficulty: GameDifficulty): number {
    if (difficulty === GameDifficulty.EASY) { return 3; }
    if (difficulty === GameDifficulty.HARD) { return 5; }
    return 4;
  }

  maxTries(difficulty: GameDifficulty): number {
    if (difficulty === GameDifficulty.EASY) { return 8; }
    if (difficulty === GameDifficulty.HARD) { return 12; }
    return 10;
  }

  score(difficulty: GameDifficulty, tries: number): number {
    let bonus = 0;
    if (difficulty === GameDifficulty.NORMAL) { bonus = 200; }
    if (difficulty === GameDifficulty.HARD) { bonus = 400; }
    return Math.max(1, 1000 + bonus - tries * 30);
  }

  /** 生成指定长度、各位互不重复的数字密码 */
  generateSecret(length: number, rng: RandomSource): string {
    const digits: number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
    let secret = '';
    for (let i = 0; i < length; i++) {
      const idx = Math.floor(rng.next() * digits.length);
      secret += '' + digits.splice(idx, 1)[0];
    }
    return secret;
  }

  /** 计算 A/B。密码各位互不重复，故不会重复计数 */
  evaluate(secret: string, guess: string): GuessFeedback {
    let a = 0;
    let b = 0;
    for (let i = 0; i < secret.length; i++) {
      if (guess[i] === secret[i]) {
        a++;
      } else if (secret.indexOf(guess[i]) >= 0) {
        b++;
      }
    }
    return new GuessFeedback(a, b);
  }
}
