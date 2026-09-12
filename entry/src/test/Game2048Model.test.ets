/**
 * 2048 Model 层单测
 */
import { describe, it, expect } from '@ohos/hypium';
import { Game2048Rules, SwipeDir } from '../main/ets/model/game/Game2048Model';
import { SeededRandom } from '../main/ets/model/game/RandomSource';

function board4(rows: number[][]): number[][] {
  return rows;
}

export default function game2048ModelTest() {
  describe('Game2048Rules', () => {
    const rules = new Game2048Rules(4);
    const emptyRow: number[] = [0, 0, 0, 0];

    it('swipe_left_merges_pairs', 0, () => {
      const b = board4([[2, 2, 2, 2], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]);
      const r = rules.swipe(b, SwipeDir.LEFT);
      expect(r.changed).assertTrue();
      expect(r.board[0][0]).assertEqual(4);
      expect(r.board[0][1]).assertEqual(4);
      expect(r.board[0][2]).assertEqual(0);
      expect(r.gained).assertEqual(8);
    });

    it('swipe_left_no_chain_merge', 0, () => {
      const b = board4([[4, 2, 2, 4], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]);
      const r = rules.swipe(b, SwipeDir.LEFT);
      expect(r.board[0][0]).assertEqual(4);
      expect(r.board[0][1]).assertEqual(4);
      expect(r.board[0][2]).assertEqual(4);
      expect(r.board[0][3]).assertEqual(0);
      expect(r.gained).assertEqual(4);
    });

    it('swipe_right_compacts_to_right', 0, () => {
      const b = board4([[2, 0, 0, 2], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]);
      const r = rules.swipe(b, SwipeDir.RIGHT);
      expect(r.board[0][3]).assertEqual(4);
      expect(r.board[0][0]).assertEqual(0);
      expect(r.gained).assertEqual(4);
    });

    it('swipe_up_merges_column', 0, () => {
      const b = board4([[2, 0, 0, 0], [2, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]);
      const r = rules.swipe(b, SwipeDir.UP);
      expect(r.board[0][0]).assertEqual(4);
      expect(r.board[1][0]).assertEqual(0);
    });

    it('swipe_reports_unchanged_when_nothing_moves', 0, () => {
      const b = board4([[2, 4, 8, 16], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]);
      const r = rules.swipe(b, SwipeDir.LEFT);
      expect(r.changed).assertFalse();
    });

    it('spawn_places_tile_in_empty_cell', 0, () => {
      const b = rules.emptyBoard();
      const r = rules.spawn(b, 0.1, new SeededRandom(3));
      expect(r.row >= 0 && r.row < 4).assertTrue();
      expect(r.col >= 0 && r.col < 4).assertTrue();
      const v = r.board[r.row][r.col];
      expect(v === 2 || v === 4).assertTrue();
      expect(b[r.row][r.col]).assertEqual(0); // 原棋盘不被修改
    });

    it('spawn_returns_negative_when_full', 0, () => {
      const b = board4([[2, 4, 2, 4], [4, 2, 4, 2], [2, 4, 2, 4], [4, 2, 4, 2]]);
      const r = rules.spawn(b, 0.1, new SeededRandom(3));
      expect(r.row).assertEqual(-1);
    });

    it('is_game_over_detects_full_no_merge', 0, () => {
      const stuck = board4([[2, 4, 2, 4], [4, 2, 4, 2], [2, 4, 2, 4], [4, 2, 4, 2]]);
      expect(rules.isGameOver(stuck)).assertTrue();
      const mergable = board4([[2, 2, 2, 4], [4, 2, 4, 2], [2, 4, 2, 4], [4, 2, 4, 2]]);
      expect(rules.isGameOver(mergable)).assertFalse();
      const withEmpty = board4([[2, 4, 2, 4], [4, 2, 4, 2], [2, 4, 2, 4], [4, 2, 4, 0]]);
      expect(rules.isGameOver(withEmpty)).assertFalse();
    });
  });
}
