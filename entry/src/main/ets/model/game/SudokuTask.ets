import { GameDifficulty } from '../../common/GameDifficulty';
import { SudokuRules } from './SudokuModel';
import { SeededRandom } from './RandomSource';

/** 只交换原始值和数组；不传 ViewModel、装饰器对象或 UI 到任务线程。 */
@Concurrent
export function generateSudokuPuzzle(difficulty: GameDifficulty, previousKey: string, seed: number): number[] {
  const rules: SudokuRules = new SudokuRules();
  return rules.generatePuzzle(difficulty, previousKey, new SeededRandom(seed)).puzzle;
}
