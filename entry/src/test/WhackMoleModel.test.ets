/**
 * 打地鼠 Model 层单测
 */
import { describe, it, expect } from '@ohos/hypium';
import { WhackMoleRules } from '../main/ets/model/game/WhackMoleModel';
import { SeededRandom } from '../main/ets/model/game/RandomSource';
import { GameDifficulty } from '../main/ets/common/GameConstants';

export default function whackMoleModelTest() {
  describe('WhackMoleRules', () => {
    const rules = new WhackMoleRules();

    it('initial_holes_all_false', 0, () => {
      const h = rules.initialHoles();
      expect(h.length).assertEqual(9);
      let allFalse = true;
      for (let i = 0; i < h.length; i++) { if (h[i]) { allFalse = false; } }
      expect(allFalse).assertTrue();
    });

    it('spawn_places_one_or_two_moles', 0, () => {
      for (let seed = 1; seed <= 30; seed++) {
        const h = rules.spawnHoles(new SeededRandom(seed));
        let count = 0;
        for (let i = 0; i < h.length; i++) { if (h[i]) { count++; } }
        expect(count >= 1 && count <= 2).assertTrue();
      }
    });

    it('whack_hit_scores_ten_and_clears', 0, () => {
      const holes = rules.initialHoles();
      holes[4] = true;
      const r = rules.whack(holes, 4);
      expect(r.delta).assertEqual(10);
      expect(r.holes[4]).assertFalse();
      expect(holes[4]).assertTrue(); // 原数组不变
    });

    it('whack_miss_penalty', 0, () => {
      const holes = rules.initialHoles();
      const r = rules.whack(holes, 0);
      expect(r.delta).assertEqual(-5);
    });

    it('game_time_by_difficulty', 0, () => {
      expect(rules.getGameTime(GameDifficulty.EASY)).assertEqual(40);
      expect(rules.getGameTime(GameDifficulty.NORMAL)).assertEqual(30);
      expect(rules.getGameTime(GameDifficulty.HARD)).assertEqual(20);
    });

    it('spawn_interval_by_difficulty', 0, () => {
      expect(rules.getSpawnInterval(GameDifficulty.EASY)).assertEqual(1000);
      expect(rules.getSpawnInterval(GameDifficulty.NORMAL)).assertEqual(800);
      expect(rules.getSpawnInterval(GameDifficulty.HARD)).assertEqual(600);
    });
  });
}
