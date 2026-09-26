/**
 * 本地单元测试入口（hypium 约定：聚合各 *.test.ets）
 */
import snakeModelTest from './SnakeModel.test';
import tetrisModelTest from './TetrisModel.test';
import minesweeperModelTest from './MinesweeperModel.test';
import game2048ModelTest from './Game2048Model.test';
import guessNumberModelTest from './GuessNumberModel.test';
import slidePuzzleModelTest from './SlidePuzzleModel.test';
import klotskiModelTest from './KlotskiModel.test';
import whackMoleModelTest from './WhackMoleModel.test';
import memoryCardModelTest from './MemoryCardModel.test';
import sudokuModelTest from './SudokuModel.test';
import viewModelClassicTest from './ViewModelClassic.test';
import viewModelPuzzleTest from './ViewModelPuzzle.test';
import gameDataManagerTest from './GameDataManager.test';
import jumpJumpModelTest from './JumpJumpModel.test';
import match3ModelTest from './Match3Model.test';

export default function testsuite() {
  snakeModelTest();
  tetrisModelTest();
  minesweeperModelTest();
  game2048ModelTest();
  guessNumberModelTest();
  slidePuzzleModelTest();
  klotskiModelTest();
  whackMoleModelTest();
  memoryCardModelTest();
  sudokuModelTest();
  viewModelClassicTest();
  viewModelPuzzleTest();
  gameDataManagerTest();
  jumpJumpModelTest();
  match3ModelTest();
}
