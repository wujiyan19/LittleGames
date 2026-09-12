/**
 * 扫雷 Model 层单测
 */
import { describe, it, expect } from '@ohos/hypium';
import { MinesweeperRules } from '../main/ets/model/game/MinesweeperModel';
import { SeededRandom } from '../main/ets/model/game/RandomSource';

export default function minesweeperModelTest() {
  describe('MinesweeperRules', () => {
    it('first_click_is_safe_within_3x3', 0, () => {
      const rules = new MinesweeperRules(9, 9);
      const board = rules.placeMines(rules.emptyBoard(), 10, 4, 4, new SeededRandom(7));
      let mines = 0;
      let safe = true;
      for (let r = 0; r < 9; r++) {
        for (let c = 0; c < 9; c++) {
          if (board[r][c] === -1) {
            mines++;
            if (Math.abs(r - 4) <= 1 && Math.abs(c - 4) <= 1) { safe = false; }
          }
        }
      }
      expect(mines).assertEqual(10);
      expect(safe).assertTrue();
      expect(board[4][4]).assertEqual(0); // 首点必为 0，可直接展开
    });

    it('count_mines_counts_8_neighbors', 0, () => {
      const rules = new MinesweeperRules(3, 3);
      const board = rules.emptyBoard();
      board[0][0] = -1;
      board[0][1] = -1;
      expect(rules.countMines(board, 1, 1)).assertEqual(2);
      expect(rules.countMines(board, 2, 2)).assertEqual(0);
    });

    it('reveal_mine_hits', 0, () => {
      const rules = new MinesweeperRules(3, 3);
      const board = rules.emptyBoard();
      board[0][0] = -1;
      const res = rules.reveal(board, rules.emptyBool(), rules.emptyBool(), 0, 0);
      expect(res.hitMine).assertTrue();
      expect(res.revealed[0][0]).assertTrue();
      expect(res.revealed[1][1]).assertFalse();
    });

    it('reveal_zero_floods_all_connected', 0, () => {
      const rules = new MinesweeperRules(3, 3);
      const board = rules.emptyBoard(); // 全 0
      const res = rules.reveal(board, rules.emptyBool(), rules.emptyBool(), 1, 1);
      expect(res.hitMine).assertFalse();
      let allRevealed = true;
      for (let r = 0; r < 3; r++) {
        for (let c = 0; c < 3; c++) { if (!res.revealed[r][c]) { allRevealed = false; } }
      }
      expect(allRevealed).assertTrue();
    });

    it('reveal_number_cell_only_opens_itself', 0, () => {
      const rules = new MinesweeperRules(3, 3);
      const board = rules.emptyBoard();
      board[0][0] = -1;
      board[0][1] = 1; // 与雷相邻的数字格
      const res = rules.reveal(board, rules.emptyBool(), rules.emptyBool(), 0, 1);
      expect(res.hitMine).assertFalse();
      expect(res.revealed[0][1]).assertTrue();
      expect(res.revealed[0][2]).assertFalse();
    });

    it('flood_skips_flagged_cell', 0, () => {
      const rules = new MinesweeperRules(3, 3);
      const board = rules.emptyBoard();
      const flagged = rules.emptyBool();
      flagged[1][1] = true;
      const res = rules.reveal(board, rules.emptyBool(), flagged, 0, 0);
      expect(res.revealed[1][1]).assertFalse(); // 旗格不被连锁揭开
      expect(res.revealed[0][0]).assertTrue();
      expect(res.revealed[2][2]).assertTrue();
    });

    it('toggle_flag_flips_and_counts', 0, () => {
      const rules = new MinesweeperRules(3, 3);
      let flagged = rules.emptyBool();
      flagged = rules.toggleFlag(rules.emptyBool(), flagged, 1, 1);
      expect(flagged[1][1]).assertTrue();
      expect(rules.countFlags(flagged)).assertEqual(1);
      flagged = rules.toggleFlag(rules.emptyBool(), flagged, 1, 1);
      expect(flagged[1][1]).assertFalse();
      expect(rules.countFlags(flagged)).assertEqual(0);
    });

    it('all_safe_revealed_win_condition', 0, () => {
      const rules = new MinesweeperRules(3, 3);
      const board = rules.emptyBoard();
      board[0][0] = -1;
      const revealed = rules.emptyBool();
      for (let r = 0; r < 3; r++) {
        for (let c = 0; c < 3; c++) { if (!(r === 0 && c === 0)) { revealed[r][c] = true; } }
      }
      expect(rules.allSafeRevealed(board, revealed)).assertTrue();
      revealed[2][2] = false;
      expect(rules.allSafeRevealed(board, revealed)).assertFalse();
    });
  });
}
