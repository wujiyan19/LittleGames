import { GameCategory, GameInfo } from '../common/GameConstants';
import { preferences } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const STORE_NAME = 'little_games_data';
const KEY_HIGH_SCORES = 'highScores';
const KEY_PLAY_COUNTS = 'playCounts';
const KEY_SETTINGS = 'settings';
/** 落盘防抖窗口（ms）：合并同窗口期内的多次变更，避免重复全量序列化 */
const PERSIST_DEBOUNCE_MS = 200;

/**
 * 游戏数据管理类 - 提供所有游戏的静态信息和运行时数据
 * 最高分 / 游玩次数通过 Preferences 持久化，应用重启后保留
 */
export class GameDataManager {
  private static store: preferences.Preferences | null = null;
  /** 防抖定时器句柄，-1 表示无待落盘任务 */
  private static flushTimer: number = -1;
  /** 用户设置（持久化） */
  private static settings: Record<string, boolean> = { 'hapticsEnabled': true };
  private static games: GameInfo[] = [
    {
      id: 'snake',
      name: $r('app.string.game_snake_name'),
      category: GameCategory.CLASSIC,
      icon: '🐍',
      description: $r('app.string.game_snake_desc'),
      highScore: 0,
      playCount: 0,
      scoreLabel: $r('app.string.game_snake_score_label'),
    },
    {
      id: 'tetris',
      name: $r('app.string.game_tetris_name'),
      category: GameCategory.CLASSIC,
      icon: '🧩',
      description: $r('app.string.game_tetris_desc'),
      highScore: 0,
      playCount: 0,
      scoreLabel: $r('app.string.game_tetris_score_label'),
    },
    {
      id: '2048',
      name: $r('app.string.game_2048_name'),
      category: GameCategory.CLASSIC,
      icon: '🔲',
      description: $r('app.string.game_2048_desc'),
      highScore: 0,
      playCount: 0,
      scoreLabel: $r('app.string.game_2048_score_label'),
    },
    {
      id: 'whackmole',
      name: $r('app.string.game_whackmole_name'),
      category: GameCategory.CLASSIC,
      icon: '🐹',
      description: $r('app.string.game_whackmole_desc'),
      highScore: 0,
      playCount: 0,
      scoreLabel: $r('app.string.game_whackmole_score_label'),
    },
    {
      id: 'minesweeper',
      name: $r('app.string.game_minesweeper_name'),
      category: GameCategory.CLASSIC,
      icon: '💣',
      description: $r('app.string.game_minesweeper_desc'),
      highScore: 0,
      playCount: 0,
      scoreLabel: $r('app.string.game_minesweeper_score_label'),
    },
    {
      id: 'sudoku',
      name: $r('app.string.game_sudoku_name'),
      category: GameCategory.PUZZLE,
      icon: '🔢',
      description: $r('app.string.game_sudoku_desc'),
      highScore: 0,
      playCount: 0,
      scoreLabel: $r('app.string.game_sudoku_score_label'),
    },
    {
      id: 'slidepuzzle',
      name: $r('app.string.game_slidepuzzle_name'),
      category: GameCategory.PUZZLE,
      icon: '🧩',
      description: $r('app.string.game_slidepuzzle_desc'),
      highScore: 0,
      playCount: 0,
      scoreLabel: $r('app.string.game_slidepuzzle_score_label'),
    },
    {
      id: 'klotski',
      name: $r('app.string.game_klotski_name'),
      category: GameCategory.PUZZLE,
      icon: '💠',
      description: $r('app.string.game_klotski_desc'),
      highScore: 0,
      playCount: 0,
      scoreLabel: $r('app.string.game_klotski_score_label'),
    },
    {
      id: 'guessnumber',
      name: $r('app.string.game_guessnumber_name'),
      category: GameCategory.PUZZLE,
      icon: '🎲',
      description: $r('app.string.game_guessnumber_desc'),
      highScore: 0,
      playCount: 0,
      scoreLabel: $r('app.string.game_guessnumber_score_label'),
    },
    {
      id: 'memorycard',
      name: $r('app.string.game_memorycard_name'),
      category: GameCategory.PUZZLE,
      icon: '🃏',
      description: $r('app.string.game_memorycard_desc'),
      highScore: 0,
      playCount: 0,
      scoreLabel: $r('app.string.game_memorycard_score_label'),
    },
    {
      id: 'jumpjump',
      name: $r('app.string.game_jumpjump_name'),
      category: GameCategory.CLASSIC,
      icon: '🐸',
      description: $r('app.string.game_jumpjump_desc'),
      highScore: 0,
      playCount: 0,
      scoreLabel: $r('app.string.game_jumpjump_score_label'),
    }
  ];

  static init(context: Context): void {
    try {
      GameDataManager.store = preferences.getPreferencesSync(context, { name: STORE_NAME });
      GameDataManager.restore();
    } catch (e) {
      // 初始化失败后 store 为 null，此后所有最高分都会静默丢失，必须留痕
      hilog.error(0x0000, 'LittleGames', 'Failed to init preferences, high scores will NOT persist');
      GameDataManager.store = null;
    }
  }

  private static restore(): void {
    if (!GameDataManager.store) { return; }
    const scoreJson = GameDataManager.store.getSync(KEY_HIGH_SCORES, '') as string;
    const countJson = GameDataManager.store.getSync(KEY_PLAY_COUNTS, '') as string;
    GameDataManager.applyMap(scoreJson, (g: GameInfo, v: number): void => { g.highScore = v; });
    GameDataManager.applyMap(countJson, (g: GameInfo, v: number): void => { g.playCount = v; });
    // 恢复用户设置
    const settingsJson = GameDataManager.store.getSync(KEY_SETTINGS, '') as string;
    if (settingsJson.length > 0) {
      try {
        const parsed = JSON.parse(settingsJson) as Record<string, boolean>;
        const keys = Object.keys(parsed);
        for (let i = 0; i < keys.length; i++) {
          GameDataManager.settings[keys[i]] = parsed[keys[i]];
        }
      } catch (e) {
        hilog.error(0x0000, 'LittleGames', 'Failed to parse settings, fallback to defaults');
      }
    }
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
      // 数据损坏时回退到默认值，但要留痕便于排查
      hilog.error(0x0000, 'LittleGames', 'Failed to parse persisted game data, fallback to defaults');
    }
  }

  /**
   * 标记数据变更，合并防抖窗口内的多次写入后统一落盘。
   * startGame() 常连续调用 updateHighScore + incrementPlayCount，
   * 若各自立即落盘，等于一次开局做两遍全量序列化 + 两次磁盘 IO。
   */
  private static markDirty(): void {
    if (!GameDataManager.store) { return; }
    if (GameDataManager.flushTimer !== -1) {
      clearTimeout(GameDataManager.flushTimer);
    }
    GameDataManager.flushTimer = setTimeout(() => {
      GameDataManager.flushTimer = -1;
      GameDataManager.persist();
    }, PERSIST_DEBOUNCE_MS);
  }

  /** 实际落盘：全量序列化 10 个游戏的最高分与游玩次数 */
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
      GameDataManager.store.putSync(KEY_SETTINGS, JSON.stringify(GameDataManager.settings));
      // flush 是异步的，原实现直接丢弃 Promise，写入失败无从察觉
      GameDataManager.store.flush().catch((err: BusinessError) => {
        hilog.error(0x0000, 'LittleGames', 'Failed to flush preferences: %{public}d', err.code);
      });
    } catch (e) {
      // 写入失败不影响游戏流程
      hilog.error(0x0000, 'LittleGames', 'Failed to persist game data');
    }
  }

  /**
   * 立即落盘（取消防抖待执行的任务）。
   * 应用退到后台时应调用，否则防抖窗口内的变更可能因进程被杀而丢失。
   */
  static flushNow(): void {
    if (GameDataManager.flushTimer !== -1) {
      clearTimeout(GameDataManager.flushTimer);
      GameDataManager.flushTimer = -1;
    }
    GameDataManager.persist();
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
      GameDataManager.markDirty();
    }
  }

  static incrementPlayCount(id: string): void {
    const game = GameDataManager.games.find(g => g.id === id);
    if (game) {
      game.playCount++;
      GameDataManager.markDirty();
    }
  }

  static getTopGames(limit: number = 5): GameInfo[] {
    return [...GameDataManager.games].sort((a, b) => b.highScore - a.highScore).slice(0, limit);
  }

  /** 按游玩次数排序——「热门/精选」口径，与「最高分排行」区分（P2-8） */
  static getMostPlayed(limit: number = 5): GameInfo[] {
    return [...GameDataManager.games].sort((a, b) => b.playCount - a.playCount).slice(0, limit);
  }

  /** 获取设置项，不存在时返回默认值 */
  static getSetting(key: string, defaultValue: boolean): boolean {
    const val = GameDataManager.settings[key];
    if (val === undefined) { return defaultValue; }
    return val;
  }

  /** 设置设置项并标记落盘 */
  static setSetting(key: string, value: boolean): void {
    GameDataManager.settings[key] = value;
    GameDataManager.markDirty();
  }
}
