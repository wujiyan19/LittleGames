/**
 * 俄罗斯方块 Model 层单测
 *
 * 直接用 ActivePiece 构造局面，绕开随机生成，断言确定。
 */
import { describe, it, expect } from '@ohos/hypium';
import { ActivePiece, TetrisRules } from '../main/ets/model/game/TetrisModel';

export default function tetrisModelTest() {
  describe('TetrisRules', () => {
    const rules = new TetrisRules(10, 20);

    it('empty_board_is_all_zero', 0, () => {
      const b = rules.emptyBoard();
      expect(b.length).assertEqual(20);
      let allZero = true;
      for (let r = 0; r < b.length; r++) {
        for (let c = 0; c < b[r].length; c++) {
          if (b[r][c] !== 0) { allZero = false; }
        }
      }
      expect(allZero).assertTrue();
    });

    it('can_place_rejects_out_of_bounds', 0, () => {
      const b = rules.emptyBoard();
      // I 横放宽 4，位于 x=0 → 左移越界
      const piece = new ActivePiece(0, 0, 0, 0);
      expect(rules.canPlace(b, piece, -1, 0)).assertFalse();
      // 放到最右会越界
      const right = new ActivePiece(0, 0, 7, 0);
      expect(rules.canPlace(b, right, 0, 0)).assertFalse();
      expect(rules.canPlace(b, new ActivePiece(0, 0, 6, 0), 0, 0)).assertTrue();
    });

    it('lock_writes_shape_index_plus_one', 0, () => {
      const b = rules.emptyBoard();
      const piece = new ActivePiece(0, 0, 0, 0); // 形状索引 0 → 标记 1
      const locked = rules.lock(b, piece);
      expect(locked[0][0]).assertEqual(1);
      expect(locked[0][3]).assertEqual(1);
      expect(locked[0][4]).assertEqual(0);
      // 原棋盘不被修改（不可变）
      expect(b[0][0]).assertEqual(0);
    });

    it('clear_rows_removes_full_line_and_adds_blank_on_top', 0, () => {
      const b = rules.emptyBoard();
      for (let c = 0; c < 10; c++) { b[19][c] = 1; } // 底行填满
      const res = rules.clearRows(b);
      expect(res.lines).assertEqual(1);
      expect(res.board.length).assertEqual(20);
      // 顶部补空行
      let topEmpty = true;
      for (let c = 0; c < 10; c++) { if (res.board[0][c] !== 0) { topEmpty = false; } }
      expect(topEmpty).assertTrue();
      // 底行现在是原来的第 18 行（空）
      let bottomEmpty = true;
      for (let c = 0; c < 10; c++) { if (res.board[19][c] !== 0) { bottomEmpty = false; } }
      expect(bottomEmpty).assertTrue();
    });

    it('score_for_lines_scales_with_level', 0, () => {
      expect(rules.scoreForLines(1, 1)).assertEqual(100);
      expect(rules.scoreForLines(2, 1)).assertEqual(300);
      expect(rules.scoreForLines(4, 1)).assertEqual(800);
      expect(rules.scoreForLines(4, 2)).assertEqual(1600);
      expect(rules.scoreForLines(5, 1)).assertEqual(800); // 封顶 4 行
    });

    it('rotate_advances_state_and_skips_non_rotatable', 0, () => {
      const b = rules.emptyBoard();
      // T 有 4 态：rot 0 → 1
      const t = new ActivePiece(2, 0, 4, 0);
      expect(rules.rotated(b, t).rot).assertEqual(1);
      // O 只有 1 态：原样返回
      const o = new ActivePiece(1, 0, 4, 0);
      expect(rules.rotated(b, o).rot).assertEqual(0);
    });

    it('rotate_kicks_off_obstacle', 0, () => {
      const b = rules.emptyBoard();
      b[1][0] = 1; // 阻挡 T 在 x=0 的落点
      const t = new ActivePiece(2, 0, 0, 0);
      const r = rules.rotated(b, t);
      expect(r.rot).assertEqual(1);
      expect(r.x).assertEqual(1); // 回踢到 x=1 才放得下
    });

    it('hard_drop_y_reaches_bottom', 0, () => {
      const b = rules.emptyBoard();
      const piece = new ActivePiece(0, 0, 0, 0); // I 横放高 1
      expect(rules.hardDropY(b, piece)).assertEqual(19);
    });

    it('cell_mark_reflects_active_piece', 0, () => {
      const b = rules.emptyBoard();
      const piece = new ActivePiece(0, 0, 2, 5); // I 横放，占 (5,2..5)
      expect(rules.cellMark(b, piece, 5, 2)).assertEqual(1);
      expect(rules.cellMark(b, piece, 5, 5)).assertEqual(1);
      expect(rules.cellMark(b, piece, 5, 6)).assertEqual(0);
      expect(rules.cellMark(b, null, 5, 2)).assertEqual(0);
    });
  });
}
