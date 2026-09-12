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
}
