/**
 * 路由 — 游戏页注册表 与 Navigation 的 navDestination 映射
 *
 * ⚠️ 调用约定：GamePageMap **不能**被 navDestination 直接引用。
 *    Navigation 只给回调传一个 name 参数，写成 .navDestination(GamePageMap)
 *    的话 pathStack 拿不到值（编译不报错，是运行时陷阱），游戏页点「返回」
 *    调 pop() 会直接崩溃。必须由持有 pathStack 的组件包一层：
 *
 *      @Builder
 *      PageMap(name: string) { GamePageMap(name, this.pathStack) }
 *      // ...
 *      .navDestination(this.PageMap)
 *
 * 新增一款游戏的登记步骤：
 *   ① model/GameData.ets 的 games 数组加数据
 *   ② 本文件 GameRoutes.PATHS 加一条「id → 路由名」
 *   ③ GamePageMap 的 if-else 里加一个组件分支（ArkTS 不支持把组件当值存表，此链无法消除）
 *   ④ 首页 Tab 卡片由数据驱动，无需改动
 */
import { SnakeGamePage } from '../pages/classic/SnakeGamePage';
import { TetrisGamePage } from '../pages/classic/TetrisGamePage';
import { Game2048Page } from '../pages/classic/Game2048Page';
import { WhackMolePage } from '../pages/classic/WhackMolePage';
import { MinesweeperPage } from '../pages/classic/MinesweeperPage';
import { SudokuPage } from '../pages/puzzle/SudokuPage';
import { SlidePuzzlePage } from '../pages/puzzle/SlidePuzzlePage';
import { KlotskiPage } from '../pages/puzzle/KlotskiPage';
import { GuessNumberPage } from '../pages/puzzle/GuessNumberPage';
import { MemoryCardPage } from '../pages/puzzle/MemoryCardPage';

export class GameRoutes {
  /** 游戏 ID → 路由名。与 GameDataManager.games 的 id 一一对应 */
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
    'memorycard': 'MemoryCardPage'
  };

  /** 查路由名。未登记的 ID 返回空串，调用方应据此拒绝导航（而非静默跳错页） */
  static routeName(gameId: string): string {
    const name: string | undefined = GameRoutes.PATHS[gameId];
    if (name === undefined) {
      return '';
    }
    return name;
  }
}

@Builder
export function GamePageMap(name: string, pathStack: NavPathStack) {
  // NavDestination 与 hideTitleBar 只在这里写一次；if-else 只负责选组件
  // （ArkTS 不支持把组件当值存表，这条链是语言限制，已尽量收窄到一行一个分支）
  NavDestination() {
    if (name === 'SnakeGamePage') {
      SnakeGamePage({ pathStack: pathStack })
    } else if (name === 'TetrisGamePage') {
      TetrisGamePage({ pathStack: pathStack })
    } else if (name === 'Game2048Page') {
      Game2048Page({ pathStack: pathStack })
    } else if (name === 'WhackMolePage') {
      WhackMolePage({ pathStack: pathStack })
    } else if (name === 'MinesweeperPage') {
      MinesweeperPage({ pathStack: pathStack })
    } else if (name === 'SudokuPage') {
      SudokuPage({ pathStack: pathStack })
    } else if (name === 'SlidePuzzlePage') {
      SlidePuzzlePage({ pathStack: pathStack })
    } else if (name === 'KlotskiPage') {
      KlotskiPage({ pathStack: pathStack })
    } else if (name === 'GuessNumberPage') {
      GuessNumberPage({ pathStack: pathStack })
    } else if (name === 'MemoryCardPage') {
      MemoryCardPage({ pathStack: pathStack })
    }
  }
  .hideTitleBar(true)
}
