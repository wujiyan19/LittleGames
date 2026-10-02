import { COLLECTION_IDS } from '../model/game/CollectionModel';

export class GameRoutes {
  /** 原有页面的游戏 ID → 路由名；新增合集由 routeName 的 COLLECTION_IDS 分支处理。 */
  static readonly PATHS: Record<string, string> = {
    'snake': 'SnakeGamePage',
    'tetris': 'TetrisGamePage',
    '2048': 'Game2048Page',
    'whackmole': 'WhackMolePage',
    'minesweeper': 'MinesweeperPage',
    'sudoku': 'SudokuPage',
    'slidepuzzle': 'SlidePuzzlePage',
    'klotski': 'KlotskiPage',
    'guessnumber': 'GuessNumberPage',
    'memorycard': 'MemoryCardPage',
    'jumpjump': 'JumpJumpPage',
    'brickbreaker': 'BrickBreakerPage',
    'match3': 'Match3Page'
  };

  /** 查路由名。未登记的 ID 返回空串，调用方应据此拒绝导航（而非静默跳错页） */
  static routeName(gameId: string): string {
    if (COLLECTION_IDS.includes(gameId)) { return 'Collection_' + gameId; }
    const name: string | undefined = GameRoutes.PATHS[gameId];
    if (name === undefined) {
      return '';
    }
    return name;
  }

  static gameIdForRoute(route: string): string {
    for (let i = 0; i < COLLECTION_IDS.length; i++) {
      if (route === 'Collection_' + COLLECTION_IDS[i]) { return COLLECTION_IDS[i]; }
    }
    const ids: string[] = ['snake', 'tetris', '2048', 'whackmole', 'minesweeper', 'sudoku',
      'slidepuzzle', 'klotski', 'guessnumber', 'memorycard', 'jumpjump', 'brickbreaker', 'match3'];
    for (let i = 0; i < ids.length; i++) {
      if (GameRoutes.routeName(ids[i]) === route) { return ids[i]; }
    }
    return '';
  }

  static isKnownRoute(route: string): boolean {
    return route === 'SettingsPage' || route === 'AboutPage' || GameRoutes.gameIdForRoute(route).length > 0;
  }
}
