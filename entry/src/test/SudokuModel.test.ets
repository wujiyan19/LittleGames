/**
 * 数独 Model 层单测（位掩码求解器 / 生成 / 校验）
 */
import { describe, it, expect } from '@ohos/hypium';
import { SudokuRules } from '../main/ets/model/game/SudokuModel';
import { SeededRandom } from '../main/ets/model/game/RandomSource';
import { GameDifficulty } from '../main/ets/common/GameConstants';

export default function sudokuModelTest() {
  describe('SudokuRules', () => {
    const rules = new SudokuRules();

    it('generated_solution_is_full_and_valid', 0, () => {
      const g = rules.generateSolution(new SeededRandom(1));
      let filled = true;
      for (let i = 0; i < 81; i++) { if (g[i] === 0) { filled = false; } }
      expect(filled).assertTrue();
      expect(rules.isComplete(g)).assertTrue();
    });

    it('count_solutions_of_full_grid_is_one', 0, () => {
      const g = rules.generateSolution(new SeededRandom(2));
      expect(rules.countSolutions(g)).assertEqual(1);
    });

    it('count_solutions_of_empty_grid_is_multiple', 0, () => {
      // 求解器找到 >1 即提前退出，故返回 2
      expect(rules.countSolutions(rules.emptyGrid())).assertEqual(2);
    });

    it('fallback_puzzle_has_unique_solution', 0, () => {
      expect(rules.countSolutions(rules.fallbackPuzzle(GameDifficulty.EASY))).assertEqual(1);
      expect(rules.countSolutions(rules.fallbackPuzzle(GameDifficulty.NORMAL))).assertEqual(1);
      expect(rules.countSolutions(rules.fallbackPuzzle(GameDifficulty.HARD))).assertEqual(1);
    });

    it('generated_puzzle_has_unique_solution', 0, () => {
      const result = rules.generatePuzzle(GameDifficulty.EASY, '', new SeededRandom(3));
      expect(rules.countSolutions(result.puzzle)).assertEqual(1);
      expect(result.key.length).assertEqual(81);
    });

    it('is_complete_detects_incomplete_and_conflict', 0, () => {
      expect(rules.isComplete(rules.emptyGrid())).assertFalse();
      const conflict = rules.emptyGrid();
      conflict[0] = 5;
      conflict[1] = 5; // 同一行重复
      expect(rules.isComplete(conflict)).assertFalse();
    });
  });
}
