/**
 * 华容道 Model 层单测
 */
import { describe, it, expect } from '@ohos/hypium';
import { KlotskiBlock, KlotskiRules } from '../main/ets/model/game/KlotskiModel';
import { GameDifficulty } from '../main/ets/common/GameConstants';

export default function klotskiModelTest() {
  describe('KlotskiRules', () => {
    const rules = new KlotskiRules(4, 5);

    it('layout_block_counts_by_difficulty', 0, () => {
      expect(rules.layout(GameDifficulty.EASY).length).assertEqual(5);
      expect(rules.layout(GameDifficulty.NORMAL).length).assertEqual(9);
      expect(rules.layout(GameDifficulty.HARD).length).assertEqual(9);
    });

    it('build_grid_places_blocks', 0, () => {
      const grid = rules.buildGrid(rules.layout(GameDifficulty.EASY));
      expect(grid[0][1]).assertEqual('cc');
      expect(grid[1][2]).assertEqual('cc');
      expect(grid[0][0]).assertEqual('g1');
      expect(grid[4][0]).assertEqual(null);
    });

    it('can_move_blocked_by_neighbor', 0, () => {
      const blocks = rules.layout(GameDifficulty.EASY);
      const grid = rules.buildGrid(blocks);
      // 曹操 2x2 位于 (1,0)，下方 (1,2)/(2,2) 有 b1/b2，无法下移
      expect(rules.canMove(blocks, grid, 'cc', 0, 1)).assertFalse();
    });

    it('can_move_into_empty_cell', 0, () => {
      const blocks = rules.layout(GameDifficulty.EASY);
      const grid = rules.buildGrid(blocks);
      // b1 位于 (1,2)，下方 (1,3) 为空
      expect(rules.canMove(blocks, grid, 'b1', 0, 1)).assertTrue();
    });

    it('apply_moves_and_grid_reflects', 0, () => {
      const blocks = rules.layout(GameDifficulty.EASY);
      const moved = rules.apply(blocks, 'b1', 0, 1);
      const b1 = rules.find(moved, 'b1');
      expect(b1 !== undefined && b1.y).assertEqual(3);
      const grid = rules.buildGrid(moved);
      expect(grid[3][1]).assertEqual('b1');
      expect(grid[2][1]).assertEqual(null);
    });

    it('win_when_target_at_center_bottom', 0, () => {
      const atGoal = new KlotskiBlock('cc', 2, 2, 1, 3, true);
      expect(rules.isWin(atGoal)).assertTrue();
      const notGoal = new KlotskiBlock('cc', 2, 2, 1, 0, true);
      expect(rules.isWin(notGoal)).assertFalse();
      const otherBlock = new KlotskiBlock('b1', 1, 1, 1, 3, false);
      expect(rules.isWin(otherBlock)).assertFalse();
    });

    it('kind_and_label', 0, () => {
      expect(rules.kind(new KlotskiBlock('cc', 2, 2, 0, 0, true))).assertEqual(1);
      expect(rules.kind(new KlotskiBlock('h', 2, 1, 0, 0, false))).assertEqual(2);
      expect(rules.kind(new KlotskiBlock('v', 1, 2, 0, 0, false))).assertEqual(3);
      expect(rules.kind(new KlotskiBlock('b', 1, 1, 0, 0, false))).assertEqual(4);
      expect(rules.label(new KlotskiBlock('cc', 2, 2, 0, 0, true))).assertEqual('曹');
      expect(rules.label(new KlotskiBlock('h', 2, 1, 0, 0, false))).assertEqual('将');
      expect(rules.label(new KlotskiBlock('b', 1, 1, 0, 0, false))).assertEqual('兵');
    });

    it('score_rewards_fewer_steps', 0, () => {
      expect(rules.score(0)).assertEqual(1000);
      expect(rules.score(10)).assertEqual(990);
      expect(rules.score(2000)).assertEqual(1);
    });
  });
}
