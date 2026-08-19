import { GameCategory, GameInfo } from '../common/GameConstants';
import { preferences } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';

const STORE_NAME = 'little_games_data';
const KEY_HIGH_SCORES = 'highScores';
const KEY_PLAY_COUNTS = 'playCounts';

/**
 * 游戏数据管理类 - 提供所有游戏的静态信息和运行时数据
 * 最高分 / 游玩次数通过 Preferences 持久化，应用重启后保留
 */
export class GameDataManager {
  private static store: preferences.Preferences | null = null;
  private static games: GameInfo[] = [
    {
      id: 'snake',
      name: '贪吃蛇',
      category: GameCategory.CLASSIC,
      icon: '🐍',
      description: '经典贪吃蛇游戏，控制小蛇吃食物不断变长',
      highScore: 0,
      playCount: 0,
    },
    {
      id: 'tetris',
      name: '俄罗斯方块',
      category: GameCategory.CLASSIC,
      icon: '🧩',
      description: '经典俄罗斯方块，消除行数得分',
      highScore: 0,
      playCount: 0,
    },
    {
      id: '2048',
      name: '2048',
      category: GameCategory.CLASSIC,
      icon: '🔲',
      description: '滑动合并数字方块，挑战2048',
      highScore: 0,
      playCount: 0,
    },
    {
      id: 'whackmole',
      name: '打地鼠',
      category: GameCategory.CLASSIC,
      icon: '🐹',
      description: '快速反应，点击冒出的地鼠',
      highScore: 0,
      playCount: 0,
    },
    {
      id: 'minesweeper',
      name: '扫雷',
      category: GameCategory.CLASSIC,
      icon: '💣',
      description: '经典扫雷游戏，找出所有地雷',
      highScore: 0,
      playCount: 0,
    },
    {
      id: 'sudoku',
      name: '数独',
      category: GameCategory.PUZZLE,
      icon: '🔢',
      description: '经典数独游戏，填满数字格',
      highScore: 0,
      playCount: 0,
    },
    {
      id: 'slidepuzzle',
      name: '滑动拼图',
      category: GameCategory.PUZZLE,
      icon: '🧩',
      description: '移动方块还原完整图片',
      highScore: 0,
      playCount: 0,
    },
    {
      id: 'klotski',
      name: '华容道',
      category: GameCategory.PUZZLE,
      icon: '💠',
      description: '经典华容道，移动方块让曹操出逃',
      highScore: 0,
      playCount: 0,
    },
    {
      id: 'guessnumber',
      name: '猜数字',
      category: GameCategory.PUZZLE,
      icon: '🎲',
      description: '通过提示猜测4位数字密码',
      highScore: 0,
      playCount: 0,
    },
    {
      id: 'memorycard',
      name: '记忆翻牌',
      category: GameCategory.PUZZLE,
      icon: '🃏',
      description: '翻开卡片找到相同的配对',
      highScore: 0,
      playCount: 0,
    }
  ];

  static init(context: Context): void {
    try {
      GameDataManager.store = preferences.getPreferencesSync(context, { name: STORE_NAME });
      GameDataManager.restore();
    } catch (e) {
      GameDataManager.store = null;
    }
  }

  private static restore(): void {
    if (!GameDataManager.store) { return; }
    const scoreJson = GameDataManager.store.getSync(KEY_HIGH_SCORES, '') as string;
    const countJson = GameDataManager.store.getSync(KEY_PLAY_COUNTS, '') as string;
    GameDataManager.applyMap(scoreJson, (g: GameInfo, v: number): void => { g.highScore = v; });
    GameDataManager.applyMap(countJson, (g: GameInfo, v: number): void => { g.playCount = v; });
  }

  private static applyMap(json: string, apply: (g: GameInfo, v: number) => void): void {
    if (json.length === 0) { return; }
    try {
      const map = JSON.parse(json) as Record<string, number>;
      const keys = Object.keys(map);
      for (let i = 0; i < keys.length; i++) {
        const game = GameDataManager.getGameById(keys[i]);
        if (game && typeof map[keys[i]] === 'number') { apply(game, map[keys[i]]); }
      }
    } catch (e) {
      // 数据损坏时忽略，使用默认值
    }
  }

  private static persist(): void {
    if (!GameDataManager.store) { return; }
    const scores: Record<string, number> = {};
    const counts: Record<string, number> = {};
    for (let i = 0; i < GameDataManager.games.length; i++) {
      const g = GameDataManager.games[i];
      scores[g.id] = g.highScore;
      counts[g.id] = g.playCount;
    }
    try {
      GameDataManager.store.putSync(KEY_HIGH_SCORES, JSON.stringify(scores));
      GameDataManager.store.putSync(KEY_PLAY_COUNTS, JSON.stringify(counts));
      GameDataManager.store.flush();
    } catch (e) {
      // 写入失败不影响游戏流程
    }
  }

  static getAllGames(): GameInfo[] {
    return GameDataManager.games;
  }

  static getGamesByCategory(category: GameCategory): GameInfo[] {
    return GameDataManager.games.filter(g => g.category === category);
  }

  static getGameById(id: string): GameInfo | undefined {
    return GameDataManager.games.find(g => g.id === id);
  }

  static updateHighScore(id: string, score: number): void {
    const game = GameDataManager.games.find(g => g.id === id);
    if (game && score > game.highScore) {
      game.highScore = score;
      GameDataManager.persist();
    }
  }

  static incrementPlayCount(id: string): void {
    const game = GameDataManager.games.find(g => g.id === id);
    if (game) {
      game.playCount++;
      GameDataManager.persist();
    }
  }

  static getTopGames(limit: number = 5): GameInfo[] {
    return [...GameDataManager.games].sort((a, b) => b.highScore - a.highScore).slice(0, limit);
  }
}
