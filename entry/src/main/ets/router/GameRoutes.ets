/**
 * 路由映射 — Navigation 的 navDestination
 * 原先内嵌在 Index.ets 的 @Builder PageMap，抽成模块级函数后，
 * Index 只剩壳，新增游戏页只需在这里登记（配合 P1-2 后续改为路由表）。
 *
 * ⚠️ 调用约定：本函数**不能**被 navDestination 直接引用。
 *    Navigation 只给回调传一个 name 参数，写成 .navDestination(GamePageMap)
 *    的话 pathStack 拿不到值（编译不报错，是运行时陷阱），游戏页点「返回」
 *    调 pop() 会直接崩溃。必须由持有 pathStack 的组件包一层：
 *
 *      @Builder
 *      PageMap(name: string) { GamePageMap(name, this.pathStack) }
 *      // ...
 *      .navDestination(this.PageMap)
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
import { ProfilePage } from '../pages/ProfilePage';

@Builder
export function GamePageMap(name: string, pathStack: NavPathStack) {
  if (name === 'SnakeGamePage') {
    NavDestination() {
      SnakeGamePage({ pathStack: pathStack })
    }
    .hideTitleBar(true)
  } else if (name === 'TetrisGamePage') {
    NavDestination() {
      TetrisGamePage({ pathStack: pathStack })
    }
    .hideTitleBar(true)
  } else if (name === 'Game2048Page') {
    NavDestination() {
      Game2048Page({ pathStack: pathStack })
    }
    .hideTitleBar(true)
  } else if (name === 'WhackMolePage') {
    NavDestination() {
      WhackMolePage({ pathStack: pathStack })
    }
    .hideTitleBar(true)
  } else if (name === 'MinesweeperPage') {
    NavDestination() {
      MinesweeperPage({ pathStack: pathStack })
    }
    .hideTitleBar(true)
  } else if (name === 'SudokuPage') {
    NavDestination() {
      SudokuPage({ pathStack: pathStack })
    }
    .hideTitleBar(true)
  } else if (name === 'SlidePuzzlePage') {
    NavDestination() {
      SlidePuzzlePage({ pathStack: pathStack })
    }
    .hideTitleBar(true)
  } else if (name === 'KlotskiPage') {
    NavDestination() {
      KlotskiPage({ pathStack: pathStack })
    }
    .hideTitleBar(true)
  } else if (name === 'GuessNumberPage') {
    NavDestination() {
      GuessNumberPage({ pathStack: pathStack })
    }
    .hideTitleBar(true)
  } else if (name === 'MemoryCardPage') {
    NavDestination() {
      MemoryCardPage({ pathStack: pathStack })
    }
    .hideTitleBar(true)
  } else if (name === 'ProfilePage') {
    NavDestination() {
      ProfilePage({ pathStack: pathStack })
    }
    .hideTitleBar(true)
  }
}
