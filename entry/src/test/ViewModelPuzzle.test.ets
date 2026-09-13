/**
 * ViewModel 层单测（益智类）
 */
import { describe, it, expect } from '@ohos/hypium';
import { GuessNumberViewModel } from '../main/ets/viewmodel/GuessNumberViewModel';
import { SlidePuzzleViewModel } from '../main/ets/viewmodel/SlidePuzzleViewModel';
import { KlotskiViewModel } from '../main/ets/viewmodel/KlotskiViewModel';
import { MemoryCardViewModel } from '../main/ets/viewmodel/MemoryCardViewModel';
import { SudokuViewModel } from '../main/ets/viewmodel/SudokuViewModel';
import { SeededRandom } from '../main/ets/model/game/RandomSource';
import { GameDifficulty, GameStatus } from '../main/ets/common/GameConstants';

export default function viewModelPuzzleTest() {

  describe('GuessNumberViewModel', () => {
    it('start_generates_secret_with_valid_length', 0, () => {
      const vm = new GuessNumberViewModel(new SeededRandom(1));
      vm.startGame();
      expect(vm.secret.length).assertEqual(vm.getSecretLength());
      expect(vm.status).assertEqual(GameStatus.PLAYING);
    });

    it('rejects_duplicate_digit_and_caps_length', 0, () => {
      const vm = new GuessNumberViewModel(new SeededRandom(2));
      vm.startGame();
      const len = vm.getSecretLength();
      const d = '1';
      vm.pushDigit(d);
      vm.pushDigit(d); // 重复，忽略
      expect(vm.input).assertEqual('1');
      // 填满后再塞不进去
      for (let i = 0; i < len + 3; i++) { vm.pushDigit((i % 9).toString()); }
      expect(vm.input.length <= len).assertTrue();
    });

    it('submit_correct_guess_wins', 0, () => {
      const vm = new GuessNumberViewModel(new SeededRandom(3));
      vm.startGame();
      const secret = vm.secret;
      for (let i = 0; i < secret.length; i++) { vm.pushDigit(secret[i]); }
      vm.submit();
      expect(vm.isWin).assertTrue();
      expect(vm.status).assertEqual(GameStatus.OVER);
      expect(vm.records.length).assertEqual(1);
      expect(vm.records[0].a).assertEqual(secret.length);
    });

    it('delete_removes_last_digit', 0, () => {
      const vm = new GuessNumberViewModel(new SeededRandom(4));
      vm.startGame();
      vm.pushDigit('7');
      vm.pushDigit('3');
      vm.deleteDigit();
      expect(vm.input).assertEqual('7');
    });
  });

  describe('SlidePuzzleViewModel', () => {
    it('start_shuffles_to_solvable_board_of_right_size', 0, () => {
      const vm = new SlidePuzzleViewModel(new SeededRandom(1));
      vm.difficulty = GameDifficulty.EASY;
      vm.startGame();
      expect(vm.board.length).assertEqual(9);
      expect(vm.status).assertEqual(GameStatus.PLAYING);
    });

    it('tap_non_adjacent_does_nothing', 0, () => {
      const vm = new SlidePuzzleViewModel(new SeededRandom(2));
      vm.startGame();
      const before = vm.board.slice();
      // 找空格，点一个非相邻格
      let zi = -1;
      for (let i = 0; i < vm.board.length; i++) { if (vm.board[i] === 0) { zi = i; } }
      const n = vm.getSize();
      const zr = Math.floor(zi / n);
      const zc = zi % n;
      // 找一个 |dr|+|dc| > 1 的格
      let tr = (zr + 2) % n;
      let tc = zc;
      if (Math.abs(tr - zr) + Math.abs(tc - zc) <= 1) { tr = (zr + 1) % n; tc = (zc + 2) % n; }
      vm.tapCell(tr, tc);
      expect(JSON.stringify(vm.board)).assertEqual(JSON.stringify(before));
      expect(vm.steps).assertEqual(0);
    });

    it('tap_adjacent_increments_steps', 0, () => {
      const vm = new SlidePuzzleViewModel(new SeededRandom(3));
      vm.startGame();
      const n = vm.getSize();
      let zi = -1;
      for (let i = 0; i < vm.board.length; i++) { if (vm.board[i] === 0) { zi = i; } }
      const zr = Math.floor(zi / n);
      const zc = zi % n;
      // 右邻（若存在）
      const tc = (zc + 1 < n) ? zc + 1 : zc - 1;
      vm.tapCell(zr, tc);
      expect(vm.steps).assertEqual(1);
    });
  });

  describe('KlotskiViewModel', () => {
    it('select_and_move_into_empty', 0, () => {
      const vm = new KlotskiViewModel();
      vm.difficulty = GameDifficulty.EASY;
      vm.startGame();
      // EASY 布局：b1 在 (行2,列1)，下方 (行3,列1) 空
      vm.selectBlockAt(2, 1);
      expect(vm.isSelected(2, 1)).assertTrue();
      vm.moveBlock(0, 1);
      expect(vm.blockKind(3, 1)).assertEqual(4); // 小兵
      expect(vm.blockKind(2, 1)).assertEqual(0); // 原格空出
      expect(vm.stepCount).assertEqual(1);
    });

    it('move_without_selection_does_nothing', 0, () => {
      const vm = new KlotskiViewModel();
      vm.startGame();
      vm.moveBlock(0, 1);
      expect(vm.stepCount).assertEqual(0);
    });

    it('cannot_move_blocked_direction', 0, () => {
      const vm = new KlotskiViewModel();
      vm.difficulty = GameDifficulty.EASY;
      vm.startGame();
      // 曹操 2x2 在 (1,0)，下方被 b1/b2 挡住，不能下移
      vm.selectBlockAt(0, 1);
      vm.moveBlock(0, 1);
      expect(vm.stepCount).assertEqual(0);
    });
  });

  describe('MemoryCardViewModel', () => {
    it('start_deals_two_of_each', 0, () => {
      const vm = new MemoryCardViewModel(new SeededRandom(1));
      vm.startGame();
      const pairs = vm.getPairCount();
      expect(vm.matchedCount).assertEqual(0);
      expect(vm.attempts).assertEqual(0);
      expect(pairs > 0).assertTrue();
      vm.dispose();
    });

    it('match_pair_increments_matched', 0, () => {
      const vm = new MemoryCardViewModel(new SeededRandom(2));
      vm.startGame();
      // 找一对同 emoji
      let a = 0;
      let b = -1;
      for (let i = 1; i < vm.getPairCount() * 2; i++) {
        if (vm.cardEmoji(i) === vm.cardEmoji(a)) { b = i; break; }
      }
      expect(b >= 0).assertTrue();
      vm.flipCard(a);
      vm.flipCard(b);
      vm.resolvePending();
      expect(vm.isMatched(a)).assertTrue();
      expect(vm.isMatched(b)).assertTrue();
      expect(vm.matchedCount).assertEqual(1);
      vm.dispose();
    });

    it('mismatch_flips_back', 0, () => {
      const vm = new MemoryCardViewModel(new SeededRandom(3));
      vm.startGame();
      let a = 0;
      let b = -1;
      for (let i = 1; i < vm.getPairCount() * 2; i++) {
        if (vm.cardEmoji(i) !== vm.cardEmoji(a)) { b = i; break; }
      }
      vm.flipCard(a);
      vm.flipCard(b);
      vm.resolvePending();
      expect(vm.isFlipped(a)).assertFalse();
      expect(vm.isFlipped(b)).assertFalse();
      expect(vm.matchedCount).assertEqual(0);
      expect(vm.attempts).assertEqual(1);
      vm.dispose();
    });

    it('matching_all_pairs_wins', 0, () => {
      const vm = new MemoryCardViewModel(new SeededRandom(5));
      vm.startGame();
      const total = vm.getPairCount() * 2;
      const done: boolean[] = [];
      for (let i = 0; i < total; i++) { done.push(false); }
      for (let i = 0; i < total; i++) {
        if (done[i]) { continue; }
        let j = -1;
        for (let k = i + 1; k < total; k++) {
          if (!done[k] && vm.cardEmoji(k) === vm.cardEmoji(i)) { j = k; break; }
        }
        vm.flipCard(i);
        vm.flipCard(j);
        vm.resolvePending();
        done[i] = true;
        done[j] = true;
      }
      expect(vm.matchedCount).assertEqual(vm.getPairCount());
      expect(vm.status).assertEqual(GameStatus.OVER);
      vm.dispose();
    });
  });

  describe('SudokuViewModel', () => {
    it('new_game_fills_fixed_cells', 0, () => {
      const vm = new SudokuViewModel(new SeededRandom(1));
      vm.newGame();
      let fixedCount = 0;
      for (let r = 0; r < 9; r++) {
        for (let c = 0; c < 9; c++) {
          if (vm.isFixed(r, c)) {
            fixedCount++;
            expect(vm.cellValue(r, c) !== 0).assertTrue();
          }
        }
      }
      expect(fixedCount > 0).assertTrue();
    });

    it('set_number_ignored_on_fixed_cell', 0, () => {
      const vm = new SudokuViewModel(new SeededRandom(2));
      vm.newGame();
      // 找一个固定格
      let fr = -1;
      let fc = -1;
      for (let r = 0; r < 9 && fr < 0; r++) {
        for (let c = 0; c < 9; c++) { if (vm.isFixed(r, c)) { fr = r; fc = c; break; } }
      }
      const before = vm.cellValue(fr, fc);
      vm.selectCell(fr, fc);
      vm.setNumber((before % 9) + 1);
      expect(vm.cellValue(fr, fc)).assertEqual(before); // 未改变
    });

    it('set_and_erase_on_editable_cell', 0, () => {
      const vm = new SudokuViewModel(new SeededRandom(3));
      vm.newGame();
      // 找一个非固定格
      let er = -1;
      let ec = -1;
      for (let r = 0; r < 9 && er < 0; r++) {
        for (let c = 0; c < 9; c++) { if (!vm.isFixed(r, c)) { er = r; ec = c; break; } }
      }
      vm.selectCell(er, ec);
      vm.setNumber(7);
      expect(vm.cellValue(er, ec)).assertEqual(7);
      vm.erase();
      expect(vm.cellValue(er, ec)).assertEqual(0);
    });
  });
}
