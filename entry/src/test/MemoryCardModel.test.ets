/**
 * 记忆翻牌 Model 层单测
 */
import { describe, it, expect } from '@ohos/hypium';
import { Card, MemoryCardRules } from '../main/ets/model/game/MemoryCardModel';
import { SeededRandom } from '../main/ets/model/game/RandomSource';
import { GameDifficulty } from '../main/ets/common/GameConstants';

export default function memoryCardModelTest() {
  describe('MemoryCardRules', () => {
    const rules = new MemoryCardRules();

    it('pair_and_row_counts_by_difficulty', 0, () => {
      expect(rules.pairCount(GameDifficulty.EASY)).assertEqual(6);
      expect(rules.pairCount(GameDifficulty.NORMAL)).assertEqual(8);
      expect(rules.pairCount(GameDifficulty.HARD)).assertEqual(12);
      expect(rules.rowCount(GameDifficulty.EASY)).assertEqual(3);
      expect(rules.rowCount(GameDifficulty.HARD)).assertEqual(6);
    });

    it('deal_creates_two_of_each_emoji', 0, () => {
      const cards = rules.deal(8, new SeededRandom(5));
      expect(cards.length).assertEqual(16);
      const counts: Record<string, number> = {};
      for (let i = 0; i < cards.length; i++) {
        const e = cards[i].emoji;
        counts[e] = (counts[e] === undefined ? 0 : counts[e]) + 1;
      }
      const keys = Object.keys(counts);
      expect(keys.length).assertEqual(8); // 8 种表情
      let allTwice = true;
      for (let i = 0; i < keys.length; i++) {
        if (counts[keys[i]] !== 2) { allTwice = false; }
      }
      expect(allTwice).assertTrue();
    });

    it('is_match_by_emoji', 0, () => {
      const cards = rules.deal(8, new SeededRandom(6));
      const a = 0;
      let sameIdx = -1;
      for (let i = 1; i < cards.length; i++) {
        if (cards[i].emoji === cards[a].emoji) { sameIdx = i; break; }
      }
      expect(sameIdx >= 0).assertTrue();
      expect(rules.isMatch(cards, a, sameIdx)).assertTrue();
      let diffIdx = -1;
      for (let i = 1; i < cards.length; i++) {
        if (cards[i].emoji !== cards[a].emoji) { diffIdx = i; break; }
      }
      expect(rules.isMatch(cards, a, diffIdx)).assertFalse();
    });

    it('score_rewards_fewer_attempts', 0, () => {
      expect(rules.score(0)).assertEqual(1000);
      expect(rules.score(20)).assertEqual(980);
      expect(rules.score(2000)).assertEqual(1);
    });
  });
}
