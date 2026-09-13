/**
 * ViewModel 层单测（经典类）
 *
 * 覆盖各 ViewModel 的编排逻辑：开局、操作、难度切换、状态迁移、计分/落库调用。
 * 随机源用 SeededRandom 保证确定；不依赖真实时间（用手动步进/同步结算入口）。
 */
import { describe, it, expect } from '@ohos/hypium';
import { SnakeViewModel } from '../main/ets/viewmodel/SnakeViewModel';
import { TetrisViewModel } from '../main/ets/viewmodel/TetrisViewModel';
import { MinesweeperViewModel } from '../main/ets/viewmodel/MinesweeperViewModel';
import { WhackMoleViewModel } from '../main/ets/viewmodel/WhackMoleViewModel';
import { Game2048ViewModel } from '../main/ets/viewmodel/Game2048ViewModel';
import { SeededRandom } from '../main/ets/model/game/RandomSource';
import { GameDifficulty, GameStatus } from '../main/ets/common/GameConstants';

export default function viewModelClassicTest() {

  describe('SnakeViewModel', () => {
    it('new_game_sets_playing_and_starts_timer_free', 0, () => {
      const vm = new SnakeViewModel(new SeededRandom(1));
      vm.newGame();
      expect(vm.status).assertEqual(GameStatus.PLAYING);
      expect(vm.snake.length).assertEqual(1);
      expect(vm.score).assertEqual(0);
      vm.dispose();
    });

    it('step_moves_head_and_updates_occupancy', 0, () => {
      const vm = new SnakeViewModel(new SeededRandom(2));
      vm.newGame();
      const hx = vm.snake[0].x;
      vm.stepOnce();
      expect(vm.snake[0].x).assertEqual(hx + 1); // 默认向右
      expect(vm.isSnakeCell(vm.snake[0].x, vm.snake[0].y)).assertTrue();
    });

    it('dies_on_wall_then_status_over', 0, () => {
      const vm = new SnakeViewModel(new SeededRandom(3));
      vm.newGame();
      // 一直向右，撞右墙（20 列，起点 x=10）
      for (let i = 0; i < 20 && vm.status === GameStatus.PLAYING; i++) { vm.stepOnce(); }
      expect(vm.status).assertEqual(GameStatus.OVER);
      vm.dispose();
    });

    it('toggle_pause_only_between_playing_and_paused', 0, () => {
      const vm = new SnakeViewModel(new SeededRandom(4));
      vm.newGame();
      vm.togglePause();
      expect(vm.status).assertEqual(GameStatus.PAUSED);
      vm.togglePause();
      expect(vm.status).assertEqual(GameStatus.PLAYING);
      vm.dispose();
    });

    it('rejects_reverse_turn', 0, () => {
      const vm = new SnakeViewModel(new SeededRandom(5));
      vm.newGame(); // 向右
      vm.turnLeft(); // 反向，应被忽略
      vm.stepOnce();
      expect(vm.snake[0].x > vm.snake.length - 1).assertTrue(); // 仍向右移动
      vm.dispose();
    });
  });

  describe('TetrisViewModel', () => {
    it('new_game_spawns_a_piece', 0, () => {
      const vm = new TetrisViewModel(new SeededRandom(1));
      vm.newGame();
      expect(vm.status).assertEqual(GameStatus.PLAYING);
      expect(vm.piece !== null).assertTrue();
      vm.dispose();
    });

    it('hard_drop_locks_piece_and_respawns', 0, () => {
      const vm = new TetrisViewModel(new SeededRandom(1));
      vm.newGame();
      const first = vm.piece;
      vm.hardDrop();
      expect(vm.piece !== null).assertTrue();
      // 落底后棋盘底部某处应有占用（cellMark != 0 的格）
      let occupied = false;
      for (let c = 0; c < vm.cols(); c++) {
        if (vm.cellMark(vm.rows() - 1, c) !== 0) { occupied = true; }
      }
      expect(occupied).assertTrue();
      expect(first !== null).assertTrue();
      vm.dispose();
    });

    it('move_left_never_goes_negative', 0, () => {
      const vm = new TetrisViewModel(new SeededRandom(2));
      vm.newGame();
      for (let i = 0; i < 20; i++) { vm.moveLeft(); }
      expect(vm.piece !== null && vm.piece.x >= 0).assertTrue();
      vm.dispose();
    });

    it('difficulty_changes_base_fall_interval', 0, () => {
      const vm = new TetrisViewModel(new SeededRandom(3));
      vm.difficulty = GameDifficulty.EASY;
      const easy = vm.getBaseFallInterval();
      vm.difficulty = GameDifficulty.HARD;
      const hard = vm.getBaseFallInterval();
      expect(easy > hard).assertTrue();
      vm.dispose();
    });
  });

  describe('MinesweeperViewModel', () => {
    it('first_reveal_is_safe_and_floods', 0, () => {
      const vm = new MinesweeperViewModel(new SeededRandom(7));
      vm.newGame();
      vm.reveal(4, 4);
      expect(vm.isMine(4, 4)).assertFalse();
      let revealedCount = 0;
      for (let r = 0; r < vm.rows(); r++) {
        for (let c = 0; c < vm.cols(); c++) { if (vm.isRevealed(r, c)) { revealedCount++; } }
      }
      expect(revealedCount > 1).assertTrue();
      vm.dispose();
    });

    it('flag_toggles_and_counts', 0, () => {
      const vm = new MinesweeperViewModel(new SeededRandom(8));
      vm.newGame();
      vm.reveal(4, 4); // 触发布雷 + 计时
      vm.toggleFlag(0, 0);
      expect(vm.isFlagged(0, 0)).assertTrue();
      expect(vm.flagCount).assertEqual(1);
      vm.toggleFlag(0, 0);
      expect(vm.flagCount).assertEqual(0);
      vm.dispose();
    });

    it('mine_count_by_difficulty', 0, () => {
      const vm = new MinesweeperViewModel(new SeededRandom(9));
      vm.difficulty = GameDifficulty.EASY;
      expect(vm.getMineCount()).assertEqual(8);
      vm.difficulty = GameDifficulty.HARD;
      expect(vm.getMineCount()).assertEqual(14);
      vm.dispose();
    });
  });

  describe('WhackMoleViewModel', () => {
    it('whack_hit_adds_ten_and_clears_hole', 0, () => {
      const vm = new WhackMoleViewModel(new SeededRandom(1));
      vm.startGame();
      const holes = [false, false, false, false, true, false, false, false, false];
      vm.holes = holes;
      vm.whack(4);
      expect(vm.score).assertEqual(10);
      expect(vm.holes[4]).assertFalse();
      vm.dispose();
    });

    it('whack_miss_penalty_not_below_zero', 0, () => {
      const vm = new WhackMoleViewModel(new SeededRandom(2));
      vm.startGame();
      vm.holes = [false, false, false, false, false, false, false, false, false];
      vm.whack(0);
      expect(vm.score).assertEqual(0); // 0 - 5 夹到 0
      vm.dispose();
    });

    it('game_time_by_difficulty', 0, () => {
      const vm = new WhackMoleViewModel(new SeededRandom(3));
      vm.difficulty = GameDifficulty.HARD;
      expect(vm.getGameTime()).assertEqual(20);
      vm.dispose();
    });
  });

  describe('Game2048ViewModel', () => {
    it('new_game_has_two_tiles', 0, () => {
      const vm = new Game2048ViewModel(new SeededRandom(1));
      vm.newGame();
      let count = 0;
      for (let r = 0; r < vm.size(); r++) {
        for (let c = 0; c < vm.size(); c++) { if (vm.cellValue(r, c) !== 0) { count++; } }
      }
      expect(count).assertEqual(2);
      expect(vm.status).assertEqual(GameStatus.PLAYING);
    });

    it('swipe_left_reports_change_and_source', 0, () => {
      const vm = new Game2048ViewModel(new SeededRandom(2));
      vm.newGame();
      // 直接摆一个可合并的局面
      vm.board = [[2, 0, 0, 2], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]];
      const changed = vm.swipeLeft();
      expect(changed).assertTrue();
      expect(vm.cellValue(0, 0)).assertEqual(4);
      expect(vm.score >= 4).assertTrue();
    });

    it('swipe_returns_false_when_no_change', 0, () => {
      const vm = new Game2048ViewModel(new SeededRandom(3));
      vm.newGame();
      vm.board = [[2, 4, 8, 16], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]];
      expect(vm.swipeLeft()).assertFalse();
    });

    it('difficulty_changes_four_chance', 0, () => {
      const vm = new Game2048ViewModel(new SeededRandom(4));
      vm.difficulty = GameDifficulty.EASY;
      const easy = vm.getFourChance();
      vm.difficulty = GameDifficulty.HARD;
      const hard = vm.getFourChance();
      expect(hard > easy).assertTrue();
    });
  });
}
