/**
 * 猜数字 Model 层单测
 */
import { describe, it, expect } from '@ohos/hypium';
import { GuessFeedback, GuessNumberRules } from '../main/ets/model/game/GuessNumberModel';
import { SeededRandom } from '../main/ets/model/game/RandomSource';
import { GameDifficulty } from '../main/ets/common/GameConstants';

export default function guessNumberModelTest() {
  describe('GuessNumberRules', () => {
    const rules = new GuessNumberRules();

    it('generate_secret_has_length_and_distinct_digits', 0, () => {
      const s = rules.generateSecret(4, new SeededRandom(11));
      expect(s.length).assertEqual(4);
      let distinct = true;
      for (let i = 0; i < s.length; i++) {
        for (let j = i + 1; j < s.length; j++) {
          if (s[i] === s[j]) { distinct = false; }
        }
      }
      expect(distinct).assertTrue();
    });

    it('evaluate_all_A', 0, () => {
      const fb: GuessFeedback = rules.evaluate('1234', '1234');
      expect(fb.a).assertEqual(4);
      expect(fb.b).assertEqual(0);
    });

    it('evaluate_all_B', 0, () => {
      const fb = rules.evaluate('1234', '4321');
      expect(fb.a).assertEqual(0);
      expect(fb.b).assertEqual(4);
    });

    it('evaluate_mixed', 0, () => {
      const fb = rules.evaluate('1234', '1354');
      expect(fb.a).assertEqual(2); // 1、4 位置对
      expect(fb.b).assertEqual(1); // 3 数字对位置错
    });

    it('evaluate_no_match', 0, () => {
      const fb = rules.evaluate('1234', '5678');
      expect(fb.a).assertEqual(0);
      expect(fb.b).assertEqual(0);
    });

    it('difficulty_config_mapping', 0, () => {
      expect(rules.secretLength(GameDifficulty.EASY)).assertEqual(3);
      expect(rules.secretLength(GameDifficulty.NORMAL)).assertEqual(4);
      expect(rules.secretLength(GameDifficulty.HARD)).assertEqual(5);
      expect(rules.maxTries(GameDifficulty.EASY)).assertEqual(8);
      expect(rules.maxTries(GameDifficulty.HARD)).assertEqual(12);
    });

    it('score_rewards_higher_difficulty_and_fewer_tries', 0, () => {
      expect(rules.score(GameDifficulty.HARD, 1) > rules.score(GameDifficulty.NORMAL, 1)).assertTrue();
      expect(rules.score(GameDifficulty.NORMAL, 1) > rules.score(GameDifficulty.NORMAL, 5)).assertTrue();
      expect(rules.score(GameDifficulty.NORMAL, 100) >= 1).assertTrue(); // 下限 1
    });
  });
}
