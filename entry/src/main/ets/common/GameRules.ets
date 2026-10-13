import { COLLECTION_IDS } from '../model/game/CollectionModel';
import { collectionRules } from '../model/CollectionCatalog';
import { EXPANSION_IDS, expansionRules } from '../model/ExpansionCatalog';

/** 所有游戏的玩法说明共用设置入口；合集沿用各自完整规则。 */
export function gameRules(id: string): Resource {
  if (COLLECTION_IDS.includes(id)) { return collectionRules(id); }
  if (EXPANSION_IDS.includes(id)) { return expansionRules(id); }
  const rules: Record<string, Resource> = {
    'snake': $r('app.string.game_snake_rules'),
    'tetris': $r('app.string.game_tetris_rules'),
    '2048': $r('app.string.game_2048_rules'),
    'whackmole': $r('app.string.game_whackmole_rules'),
    'minesweeper': $r('app.string.game_minesweeper_rules'),
    'sudoku': $r('app.string.game_sudoku_rules'),
    'slidepuzzle': $r('app.string.game_slidepuzzle_rules'),
    'klotski': $r('app.string.game_klotski_rules'),
    'guessnumber': $r('app.string.game_guessnumber_rules'),
    'memorycard': $r('app.string.game_memorycard_rules'),
    'jumpjump': $r('app.string.game_jumpjump_rules'),
    'brickbreaker': $r('app.string.game_brickbreaker_rules'),
    'match3': $r('app.string.game_match3_rules')
  };
  return rules[id] ?? $r('app.string.game_settings_rules');
}
