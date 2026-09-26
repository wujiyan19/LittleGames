/** 消消乐开局与连锁后的可操作性回归。 */
import { describe, it, expect } from '@ohos/hypium';
import { Match3Rules, ChainResult } from '../main/ets/model/game/Match3Model';
import { RandomSource, SeededRandom } from '../main/ets/model/game/RandomSource';

class ConstantRandom implements RandomSource {
  next(): number { return 0; }
}

function deadBoard(): number[][] {
  const board: number[][] = [];
  for (let r = 0; r < 8; r++) {
    const row: number[] = [];
    for (let c = 0; c < 8; c++) {
      row.push((r + c) % 6);
    }
    board.push(row);
  }
  return board;
}

export default function match3ModelTest() {
  describe('Match3Rules', () => {
    it('detects_dead_board_without_changing_it', 0, () => {
      const rules: Match3Rules = new Match3Rules();
      const board: number[][] = deadBoard();
      const before: string = JSON.stringify(board);
      expect(rules.hasMatches(board)).assertFalse();
      expect(rules.hasLegalSwap(board)).assertFalse();
      expect(JSON.stringify(board)).assertEqual(before);
    });

    it('generated_boards_always_have_a_legal_swap', 0, () => {
      const rules: Match3Rules = new Match3Rules();
      for (let seed = 1; seed <= 20; seed++) {
        const board: number[][] = rules.generateBoard(new SeededRandom(seed));
        expect(rules.hasMatches(board)).assertFalse();
        expect(rules.hasLegalSwap(board)).assertTrue();
      }
    });

    it('degenerate_random_source_uses_playable_fallback', 0, () => {
      const rules: Match3Rules = new Match3Rules();
      const board: number[][] = rules.generateBoard(new ConstantRandom());
      expect(rules.hasMatches(board)).assertFalse();
      expect(rules.hasLegalSwap(board)).assertTrue();
    });

    it('dead_board_after_chain_is_replaced_without_extra_score', 0, () => {
      const rules: Match3Rules = new Match3Rules();
      const result: ChainResult = rules.resolveChain(deadBoard(), new SeededRandom(42));
      expect(result.chainRounds).assertEqual(0);
      expect(result.totalGained).assertEqual(0);
      expect(rules.hasMatches(result.board)).assertFalse();
      expect(rules.hasLegalSwap(result.board)).assertTrue();
    });

    it('resolved_match_still_leaves_a_playable_board', 0, () => {
      const rules: Match3Rules = new Match3Rules();
      const board: number[][] = rules.generateBoard(new ConstantRandom());
      const swapped: number[][] = rules.swap(board, 0, 1, 1, 1);
      const result: ChainResult = rules.resolveChain(swapped, new SeededRandom(7));
      expect(result.chainRounds > 0).assertTrue();
      expect(rules.hasMatches(result.board)).assertFalse();
      expect(rules.hasLegalSwap(result.board)).assertTrue();
    });
  });
}
