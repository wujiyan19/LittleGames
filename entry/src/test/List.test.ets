/**
 * 本地单元测试入口（hypium 约定：聚合各 *.test.ets）
 */
import snakeModelTest from './SnakeModel.test';
import tetrisModelTest from './TetrisModel.test';
import minesweeperModelTest from './MinesweeperModel.test';

export default function testsuite() {
  snakeModelTest();
  tetrisModelTest();
  minesweeperModelTest();
}
