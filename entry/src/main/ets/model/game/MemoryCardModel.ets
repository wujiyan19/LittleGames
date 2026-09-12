/**
 * 记忆翻牌 —— Model 层（纯逻辑，零 ArkUI 依赖）
 *
 * 发牌（洗牌 + 配对）、配对判定、计分。卡牌状态由调用方持有。
 */
import { GameDifficulty } from '../../common/GameConstants';
import { RandomSource } from './RandomSource';

export const ALL_EMOJIS: string[] = ['🎮', '🎯', '🎲', '🎸', '🎨', '🚀', '🌈', '⭐', '🍎', '🌺', '🐶', '🐱'];

export class Card {
  id: number;
  emoji: string;
  flipped: boolean;
  matched: boolean;

  constructor(id: number, emoji: string, flipped: boolean, matched: boolean) {
    this.id = id;
    this.emoji = emoji;
    this.flipped = flipped;
    this.matched = matched;
  }
}

export class MemoryCardRules {
  pairCount(difficulty: GameDifficulty): number {
    if (difficulty === GameDifficulty.EASY) { return 6; }
    if (difficulty === GameDifficulty.HARD) { return 12; }
    return 8;
  }

  rowCount(difficulty: GameDifficulty): number {
    return Math.floor(this.pairCount(difficulty) / 2);
  }

  /** 发牌：从表情池选 pairCount 个，各两张，再整体打乱 */
  deal(pairCount: number, rng: RandomSource): Card[] {
    // 洗表情池
    const pool = ALL_EMOJIS.slice();
    for (let i = pool.length - 1; i > 0; i--) {
      const j = Math.floor(rng.next() * (i + 1));
      const tmp = pool[i];
      pool[i] = pool[j];
      pool[j] = tmp;
    }
    const selected = pool.slice(0, pairCount);
    const cards: Card[] = [];
    for (let i = 0; i < selected.length; i++) {
      cards.push(new Card(i * 2, selected[i], false, false));
      cards.push(new Card(i * 2 + 1, selected[i], false, false));
    }
    // 洗牌
    for (let i = cards.length - 1; i > 0; i--) {
      const j = Math.floor(rng.next() * (i + 1));
      const tmp = cards[i];
      cards[i] = cards[j];
      cards[j] = tmp;
    }
    return cards;
  }

  isMatch(cards: Card[], a: number, b: number): boolean {
    return cards[a].emoji === cards[b].emoji;
  }

  /** 尝试次数越少得分越高 */
  score(attempts: number): number {
    return Math.max(1, 1000 - attempts);
  }
}
