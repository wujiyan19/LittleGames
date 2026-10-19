/**
 * GameDataManager 单测（纯查询/排序部分，不依赖 Preferences store）
 */
import { describe, it, expect } from '@ohos/hypium';
import { GameDataManager } from '../main/ets/model/GameData';
import { GameCategory, GAME_CATEGORIES } from '../main/ets/common/GameConstants';

export default function gameDataManagerTest() {
  describe('GameDataManager', () => {
    it('get_all_games_includes_implemented_expansion', 0, () => {
      expect(GameDataManager.getAllGames().length).assertEqual(79);
    });

    it('get_game_by_id_works', 0, () => {
      const g = GameDataManager.getGameById('snake');
      expect(g !== undefined).assertTrue();
      expect(GameDataManager.getGameById('not-exist') === undefined).assertTrue();
    });

    it('get_games_by_category_partitions', 0, () => {
      const classic = GameDataManager.getGamesByCategory(GameCategory.CLASSIC);
      const puzzle = GameDataManager.getGamesByCategory(GameCategory.PUZZLE);
      let total: number = 0;
      for (let i = 0; i < GAME_CATEGORIES.length; i++) {
        const count: number = GameDataManager.getGamesByCategory(GAME_CATEGORIES[i]).length;
        expect(count > 0).assertTrue(); total += count;
      }
      expect(total).assertEqual(79);
      expect(classic.length > 0 && puzzle.length > 0).assertTrue();
    });

    it('get_top_games_sorted_desc_and_limited', 0, () => {
      const top = GameDataManager.getTopGames(3);
      expect(top.length).assertEqual(3);
      expect(top[0].highScore >= top[1].highScore).assertTrue();
      expect(top[1].highScore >= top[2].highScore).assertTrue();
    });

    it('get_most_played_sorted_desc_and_limited', 0, () => {
      const most = GameDataManager.getMostPlayed(3);
      expect(most.length).assertEqual(3);
      expect(most[0].playTimeMs >= most[1].playTimeMs).assertTrue();
    });

    it('recent_games_follow_entry_order', 0, () => {
      GameDataManager.recordGamePlayed('snake');
      GameDataManager.recordGamePlayed('2048');
      GameDataManager.recordGamePlayed('snake');
      const recent = GameDataManager.getRecentlyPlayed(2);
      expect(recent.length).assertEqual(2);
      expect(recent[0].id).assertEqual('snake');
      expect(recent[1].id).assertEqual('2048');
    });

    it('play_history_keeps_more_than_five_games', 0, () => {
      GameDataManager.clearPlayData();
      const ids: string[] = ['snake', 'tetris', '2048', 'whackmole', 'minesweeper', 'sudoku', 'slidepuzzle'];
      for (let i = 0; i < ids.length; i++) { GameDataManager.recordGamePlayed(ids[i]); }
      const history = GameDataManager.getPlayHistory();
      expect(history.length).assertEqual(ids.length);
      expect(GameDataManager.getRecentlyPlayed().length).assertEqual(5);
      expect(GameDataManager.getPlayedGameCount()).assertEqual(ids.length);
      for (let i = 1; i < history.length; i++) {
        expect(history[i - 1].lastPlayedAt >= history[i].lastPlayedAt).assertTrue();
      }
      GameDataManager.clearPlayData();
    });

    it('replaying_updates_history_without_duplicate_records', 0, () => {
      GameDataManager.clearPlayData();
      GameDataManager.recordGamePlayed('snake');
      GameDataManager.recordGamePlayed('2048');
      const beforeReplay: number = Date.now();
      GameDataManager.recordGamePlayed('snake');
      const history = GameDataManager.getPlayHistory();
      expect(history.length).assertEqual(2);
      expect(history[0].game.id).assertEqual('snake');
      expect(history[0].lastPlayedAt >= beforeReplay).assertTrue();
      expect(history[1].game.id).assertEqual('2048');
      GameDataManager.clearPlayData();
      expect(GameDataManager.getPlayHistory().length).assertEqual(0);
    });
  });
}
