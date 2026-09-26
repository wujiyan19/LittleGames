/**
 * GameDataManager 单测（纯查询/排序部分，不依赖 Preferences store）
 */
import { describe, it, expect } from '@ohos/hypium';
import { GameDataManager } from '../main/ets/model/GameData';
import { GameCategory } from '../main/ets/common/GameConstants';

export default function gameDataManagerTest() {
  describe('GameDataManager', () => {
    it('get_all_games_has_thirteen', 0, () => {
      expect(GameDataManager.getAllGames().length).assertEqual(13);
    });

    it('get_game_by_id_works', 0, () => {
      const g = GameDataManager.getGameById('snake');
      expect(g !== undefined).assertTrue();
      expect(GameDataManager.getGameById('not-exist') === undefined).assertTrue();
    });

    it('get_games_by_category_partitions', 0, () => {
      const classic = GameDataManager.getGamesByCategory(GameCategory.CLASSIC);
      const puzzle = GameDataManager.getGamesByCategory(GameCategory.PUZZLE);
      expect(classic.length + puzzle.length).assertEqual(13);
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
      expect(most[0].playCount >= most[1].playCount).assertTrue();
    });

    it('recent_games_follow_entry_order', 0, () => {
      GameDataManager.incrementPlayCount('snake');
      GameDataManager.incrementPlayCount('2048');
      GameDataManager.incrementPlayCount('snake');
      const recent = GameDataManager.getRecentlyPlayed(2);
      expect(recent.length).assertEqual(2);
      expect(recent[0].id).assertEqual('snake');
      expect(recent[1].id).assertEqual('2048');
    });
  });
}
