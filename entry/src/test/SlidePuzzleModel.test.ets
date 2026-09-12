/**
 * 滑动拼图 Model 层单测
 */
import { describe, it, expect } from '@ohos/hypium';
import { SlidePuzzleRules } from '../main/ets/model/game/SlidePuzzleModel';
import { SeededRandom } from '../main/ets/model/game/RandomSource';

export default function slidePuzzleModelTest() {
  describe('SlidePuzzleRules', () => {
    it('solved_board_layout', 0, () => {
      const rules = new SlidePuzzleRules(3);
      expect(JSON.stringify(rules.solvedBoard())).assertEqual(JSON.stringify([1, 2, 3, 4, 5, 6, 7, 8, 0]));
    });

    it('is_solvable_3x3', 0, () => {
      const rules = new SlidePuzzleRules(3);
      expect(rules.isSolvable([1, 2, 3, 4, 5, 6, 7, 8, 0])).assertTrue();
      // 交换 7/8 → 逆序数为奇，奇数宽度无解
      expect(rules.isSolvable([1, 2, 3, 4, 5, 6, 8, 7, 0])).assertFalse();
    });

    it('is_solvable_4x4_solved_is_solvable', 0, () => {
      const rules = new SlidePuzzleRules(4);
      const solved: number[] = [];
      for (let i = 1; i <= 15; i++) { solved.push(i); }
      solved.push(0);
      expect(rules.isSolvable(solved)).assertTrue();
    });

    it('shuffle_produces_solvable_board', 0, () => {
      const rules = new SlidePuzzleRules(4);
      const b = rules.shuffle(new SeededRandom(9));
      expect(b.length).assertEqual(16);
      expect(rules.isSolvable(b)).assertTrue();
    });

    it('can_move_only_adjacent_to_blank', 0, () => {
      const rules = new SlidePuzzleRules(3);
      const solved = rules.solvedBoard(); // 空格在 (2,2)
      expect(rules.canMove(solved, 2, 1)).assertTrue();
      expect(rules.canMove(solved, 1, 2)).assertTrue();
      expect(rules.canMove(solved, 0, 0)).assertFalse();
      expect(rules.canMove(solved, 2, 2)).assertFalse();
    });

    it('tap_swaps_tile_with_blank', 0, () => {
      const rules = new SlidePuzzleRules(3);
      const solved = rules.solvedBoard();
      const next = rules.tap(solved, 2, 1); // 空格 (2,2) ↔ (2,1) 的 8
      expect(next[8]).assertEqual(8);
      expect(next[7]).assertEqual(0);
      expect(solved[8]).assertEqual(0); // 原数组不变
    });

    it('is_solved_detection', 0, () => {
      const rules = new SlidePuzzleRules(3);
      expect(rules.isSolved(rules.solvedBoard())).assertTrue();
      expect(rules.isSolved([1, 2, 3, 4, 5, 6, 7, 0, 8])).assertFalse();
    });

    it('score_rewards_fewer_steps', 0, () => {
      const rules = new SlidePuzzleRules(3);
      expect(rules.score(0)).assertEqual(1000);
      expect(rules.score(50)).assertEqual(950);
      expect(rules.score(2000)).assertEqual(1); // 下限 1
    });
  });
}
