import { GameCategory, GameInfo } from '../common/GameConstants';
import { collectionGames } from './CollectionCatalog';
import { expansionGames } from './ExpansionCatalog';
import { preferences } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { GameDifficulty } from '../common/GameDifficulty';
import { gameSound } from '../common/GameSound';
import { isGameAvailable } from '../common/GameAvailability';

const STORE_NAME = 'little_games_data';
const KEY_HIGH_SCORES = 'highScores';
const KEY_PLAY_COUNTS = 'playCounts';
const KEY_PLAY_TIMES = 'playTimesMs';
const KEY_PLAYED_GAMES = 'playedGames';
const KEY_SETTINGS = 'settings';
const KEY_RECENT_GAMES = 'recentGames';
const KEY_LAST_PLAYED_AT = 'lastPlayedAt';
const KEY_SAVED_2048 = 'savedGame2048';
const KEY_SAVED_SUDOKU = 'savedGameSudoku';
const MAX_SAVED_GAME_LENGTH: number = 8192;
/** JavaScript Date 支持的最大 Unix 毫秒时间，避免历史日期格式化失败。 */
const MAX_DATE_TIMESTAMP_MS = 8640000000000000;
/** 落盘防抖窗口（ms）：合并同窗口期内的多次变更，避免重复全量序列化 */
const PERSIST_DEBOUNCE_MS = 200;

/** 完整游玩历史的一项；旧记录未知的最近游玩时间为 0。 */
export class PlayedGameRecord {
  game: GameInfo;
  lastPlayedAt: number;

  constructor(game: GameInfo, lastPlayedAt: number) {
    this.game = game;
    this.lastPlayedAt = lastPlayedAt;
  }
}

/**
 * 游戏数据管理类 - 提供所有游戏的静态信息和运行时数据
 * 最高分 / 累计游玩毫秒通过 Preferences 持久化，应用重启后保留
 */
export class GameDataManager {
  private static store: preferences.Preferences | null = null;
  /** 防抖定时器句柄，-1 表示无待落盘任务 */
  private static flushTimer: number = -1;
  private static dirty: boolean = false;
  private static pendingFlushes: number = 0;
  private static saved2048: string = '';
  private static savedSudoku: string = '';
  private static savedGamesDirty: boolean = false;
  private static savedGameRevision: number = 0;
  /** 用户设置（持久化） */
  private static settings: Record<string, boolean | string> = {
    'hapticsEnabled': true, 'soundEnabled': true, 'themeMode': 'system', 'defaultDifficulty': 'normal',
    'rememberDifficulty': false, 'confirmExitEnabled': true
  };
  /** 最近进入的游戏 ID，按新到旧排列。 */
  private static recentGameIds: string[] = [];
  private static playedGameIds: string[] = [];
  /** 每款游戏最近开局的 Unix 毫秒时间，保留完整历史，不随预览数量截断。 */
  private static lastPlayedAtByGame: Record<string, number> = {};
  /** 完整登记目录用于保留撤下玩法的旧战绩，只有 games 对外提供上架内容。 */
  private static catalog: GameInfo[] = [
    {
      id: 'snake',
      name: $r('app.string.game_snake_name'),
      category: GameCategory.CLASSIC,
      icon: $r('app.media.game_snake'),
      description: $r('app.string.game_snake_desc'),
      highScore: 0,
      playTimeMs: 0,
      scoreLabel: $r('app.string.game_snake_score_label'),
    },
    {
      id: 'tetris',
      name: $r('app.string.game_tetris_name'),
      category: GameCategory.CLASSIC,
      icon: $r('app.media.game_tetris'),
      description: $r('app.string.game_tetris_desc'),
      highScore: 0,
      playTimeMs: 0,
      scoreLabel: $r('app.string.game_tetris_score_label'),
    },
    {
      id: '2048',
      name: $r('app.string.game_2048_name'),
      category: GameCategory.NUMBER,
      icon: $r('app.media.game_2048'),
      description: $r('app.string.game_2048_desc'),
      highScore: 0,
      playTimeMs: 0,
      scoreLabel: $r('app.string.game_2048_score_label'),
    },
    {
      id: 'whackmole',
      name: $r('app.string.game_whackmole_name'),
      category: GameCategory.REACTION,
      icon: $r('app.media.game_whackmole'),
      description: $r('app.string.game_whackmole_desc'),
      highScore: 0,
      playTimeMs: 0,
      scoreLabel: $r('app.string.game_whackmole_score_label'),
    },
    {
      id: 'minesweeper',
      name: $r('app.string.game_minesweeper_name'),
      category: GameCategory.PUZZLE,
      icon: $r('app.media.game_minesweeper'),
      description: $r('app.string.game_minesweeper_desc'),
      highScore: 0,
      playTimeMs: 0,
      scoreLabel: $r('app.string.game_minesweeper_score_label'),
    },
    {
      id: 'sudoku',
      name: $r('app.string.game_sudoku_name'),
      category: GameCategory.NUMBER,
      icon: $r('app.media.game_sudoku'),
      description: $r('app.string.game_sudoku_desc'),
      highScore: 0,
      playTimeMs: 0,
      scoreLabel: $r('app.string.game_sudoku_score_label'),
    },
    {
      id: 'slidepuzzle',
      name: $r('app.string.game_slidepuzzle_name'),
      category: GameCategory.PUZZLE,
      icon: $r('app.media.game_slidepuzzle'),
      description: $r('app.string.game_slidepuzzle_desc'),
      highScore: 0,
      playTimeMs: 0,
      scoreLabel: $r('app.string.game_slidepuzzle_score_label'),
    },
    {
      id: 'klotski',
      name: $r('app.string.game_klotski_name'),
      category: GameCategory.PUZZLE,
      icon: $r('app.media.game_klotski'),
      description: $r('app.string.game_klotski_desc'),
      highScore: 0,
      playTimeMs: 0,
      scoreLabel: $r('app.string.game_klotski_score_label'),
    },
    {
      id: 'guessnumber',
      name: $r('app.string.game_guessnumber_name'),
      category: GameCategory.NUMBER,
      icon: $r('app.media.game_guessnumber'),
      description: $r('app.string.game_guessnumber_desc'),
      highScore: 0,
      playTimeMs: 0,
      scoreLabel: $r('app.string.game_guessnumber_score_label'),
    },
    {
      id: 'memorycard',
      name: $r('app.string.game_memorycard_name'),
      category: GameCategory.MEMORY,
      icon: $r('app.media.game_memorycard'),
      description: $r('app.string.game_memorycard_desc'),
      highScore: 0,
      playTimeMs: 0,
      scoreLabel: $r('app.string.game_memorycard_score_label'),
    },
    {
      id: 'jumpjump',
      name: $r('app.string.game_jumpjump_name'),
      category: GameCategory.REACTION,
      icon: $r('app.media.game_jumpjump'),
      description: $r('app.string.game_jumpjump_desc'),
      highScore: 0,
      playTimeMs: 0,
      scoreLabel: $r('app.string.game_jumpjump_score_label'),
    },
    {
      id: 'brickbreaker',
      name: $r('app.string.game_brickbreaker_name'),
      category: GameCategory.CLASSIC,
      icon: $r('app.media.game_brickbreaker'),
      description: $r('app.string.game_brickbreaker_desc'),
      highScore: 0,
      playTimeMs: 0,
      scoreLabel: $r('app.string.game_brickbreaker_score_label'),
    },
    {
      id: 'match3',
      name: $r('app.string.game_match3_name'),
      category: GameCategory.PUZZLE,
      icon: $r('app.media.game_match3'),
      description: $r('app.string.game_match3_desc'),
      highScore: 0,
      playTimeMs: 0,
      scoreLabel: $r('app.string.game_match3_score_label'),
    },
    ...collectionGames(),
    ...expansionGames()
  ];
  private static games: GameInfo[] = GameDataManager.catalog.filter((game: GameInfo): boolean => isGameAvailable(game.id));

  static init(context: Context): void {
    try {
      GameDataManager.store = preferences.getPreferencesSync(context, { name: STORE_NAME });
      GameDataManager.restore();
    } catch (e) {
      // 初始化失败后 store 为 null，此后所有最高分都会静默丢失，必须留痕
      hilog.error(0x0000, 'LittleGames', 'Failed to init preferences, high scores will NOT persist');
      GameDataManager.store = null;
    }
    gameSound.setEnabled(GameDataManager.getSetting('soundEnabled', true));
  }

  private static restore(): void {
    if (!GameDataManager.store) { return; }
    const saved2048 = GameDataManager.store.getSync(KEY_SAVED_2048, '');
    const savedSudoku = GameDataManager.store.getSync(KEY_SAVED_SUDOKU, '');
    GameDataManager.saved2048 = typeof saved2048 === 'string' ? saved2048 : '';
    GameDataManager.savedSudoku = typeof savedSudoku === 'string' ? savedSudoku : '';
    const scoreJson = GameDataManager.store.getSync(KEY_HIGH_SCORES, '') as string;
    GameDataManager.applyMap(scoreJson, (g: GameInfo, v: number): void => { g.highScore = v; });
    const timeJson = GameDataManager.store.getSync(KEY_PLAY_TIMES, '') as string;
    GameDataManager.applyMap(timeJson, (g: GameInfo, v: number): void => {
      if (Number.isFinite(v) && v >= 0 && v <= Number.MAX_SAFE_INTEGER) { g.playTimeMs = Math.floor(v); }
    });
    const playedJson = GameDataManager.store.getSync(KEY_PLAYED_GAMES, '') as string;
    GameDataManager.playedGameIds = GameDataManager.restoreGameIds(playedJson);
    if (playedJson.length === 0) {
      // 旧次数只用于保留「已玩游戏」数量，无法换算为时长。
      const countJson = GameDataManager.store.getSync(KEY_PLAY_COUNTS, '') as string;
      GameDataManager.applyMap(countJson, (g: GameInfo, v: number): void => {
        if (Number.isFinite(v) && v > 0) { GameDataManager.markPlayed(g.id); }
      });
    }
    const recentJson = GameDataManager.store.getSync(KEY_RECENT_GAMES, '') as string;
    GameDataManager.recentGameIds = GameDataManager.restoreGameIds(recentJson);
    for (let i = 0; i < GameDataManager.recentGameIds.length; i++) {
      GameDataManager.markPlayed(GameDataManager.recentGameIds[i]);
    }
    for (let i = 0; i < GameDataManager.catalog.length; i++) {
      const game: GameInfo = GameDataManager.catalog[i];
      if (game.playTimeMs > 0) { GameDataManager.markPlayed(game.id); }
    }
    // 旧版本只保存已玩标记、最近顺序或累计时长，无法推算真实游玩日期。
    GameDataManager.lastPlayedAtByGame = {};
    const lastPlayedJson = GameDataManager.store.getSync(KEY_LAST_PLAYED_AT, '') as string;
    GameDataManager.applyMap(lastPlayedJson, (g: GameInfo, v: number): void => {
      if (Number.isFinite(v) && v > 0 && v <= MAX_DATE_TIMESTAMP_MS) {
        GameDataManager.lastPlayedAtByGame[g.id] = Math.floor(v);
        GameDataManager.markPlayed(g.id);
      }
    });
    // 恢复用户设置
    const settingsJson = GameDataManager.store.getSync(KEY_SETTINGS, '') as string;
    if (settingsJson.length > 0) {
      try {
        const parsed = JSON.parse(settingsJson) as Record<string, boolean | string>;
        const keys = Object.keys(parsed);
        for (let i = 0; i < keys.length; i++) {
          const value = parsed[keys[i]];
          if (typeof value === 'boolean' || typeof value === 'string') {
            GameDataManager.settings[keys[i]] = value;
          }
        }
      } catch (e) {
        hilog.error(0x0000, 'LittleGames', 'Failed to parse settings, fallback to defaults');
      }
    }
  }

  private static restoreGameIds(json: string): string[] {
    const result: string[] = [];
    if (json.length === 0) { return result; }
    try {
      const ids: string[] = JSON.parse(json) as string[];
      if (!Array.isArray(ids)) { return result; }
      for (let i = 0; i < ids.length; i++) {
        const id: string = ids[i];
        if (typeof id === 'string' && GameDataManager.catalog.some((game: GameInfo): boolean => game.id === id) && !result.includes(id)) {
          result.push(id);
        }
      }
    } catch (e) {
      hilog.error(0x0000, 'LittleGames', 'Failed to parse played game IDs');
    }
    return result;
  }

  private static markPlayed(id: string): void {
    if (!GameDataManager.playedGameIds.includes(id)) { GameDataManager.playedGameIds.push(id); }
  }

  private static applyMap(json: string, apply: (g: GameInfo, v: number) => void): void {
    if (json.length === 0) { return; }
    try {
      const map = JSON.parse(json) as Record<string, number>;
      const keys = Object.keys(map);
      for (let i = 0; i < keys.length; i++) {
        const game: GameInfo | undefined = GameDataManager.catalog.find((entry: GameInfo): boolean => entry.id === keys[i]);
        if (game && typeof map[keys[i]] === 'number') { apply(game, map[keys[i]]); }
      }
    } catch (e) {
      // 数据损坏时回退到默认值，但要留痕便于排查
      hilog.error(0x0000, 'LittleGames', 'Failed to parse persisted game data, fallback to defaults');
    }
  }

  /**
   * 标记数据变更，合并防抖窗口内的多次写入后统一落盘。
   * 合并开局记录、最高分和时长的连续变更，
   * 若各自立即落盘，等于一次开局做两遍全量序列化 + 两次磁盘 IO。
   */
  private static markDirty(): void {
    GameDataManager.dirty = true;
    if (!GameDataManager.store) { return; }
    if (GameDataManager.flushTimer !== -1) {
      clearTimeout(GameDataManager.flushTimer);
    }
    GameDataManager.flushTimer = setTimeout(() => {
      GameDataManager.flushTimer = -1;
      GameDataManager.persist();
    }, PERSIST_DEBOUNCE_MS);
  }

  /** 实际落盘：全量序列化游戏数据。关键操作使用同步刷盘。 */
  private static persist(sync: boolean = false): void {
    if (!GameDataManager.store) { return; }
    if (!GameDataManager.dirty && (!sync || GameDataManager.pendingFlushes === 0)) { return; }
    try {
      if (GameDataManager.dirty) {
        const scores: Record<string, number> = {};
        const times: Record<string, number> = {};
        // 撤下只影响展示与启动；设置或其他战绩落盘不能删除这些玩法的旧记录。
        for (let i = 0; i < GameDataManager.catalog.length; i++) {
          const game: GameInfo = GameDataManager.catalog[i];
          scores[game.id] = game.highScore;
          times[game.id] = game.playTimeMs;
        }
        GameDataManager.store.putSync(KEY_HIGH_SCORES, JSON.stringify(scores));
        GameDataManager.store.putSync(KEY_PLAY_TIMES, JSON.stringify(times));
        GameDataManager.store.putSync(KEY_PLAYED_GAMES, JSON.stringify(GameDataManager.playedGameIds));
        GameDataManager.store.putSync(KEY_SETTINGS, JSON.stringify(GameDataManager.settings));
        GameDataManager.store.putSync(KEY_RECENT_GAMES, JSON.stringify(GameDataManager.recentGameIds));
        GameDataManager.store.putSync(KEY_LAST_PLAYED_AT, JSON.stringify(GameDataManager.lastPlayedAtByGame));
        if (GameDataManager.savedGamesDirty) {
          GameDataManager.store.putSync(KEY_SAVED_2048, GameDataManager.saved2048);
          GameDataManager.store.putSync(KEY_SAVED_SUDOKU, GameDataManager.savedSudoku);
          GameDataManager.savedGamesDirty = false;
        }
        GameDataManager.dirty = false;
      }
      if (sync) {
        GameDataManager.store.flushSync();
      } else {
        const flush: Promise<void> = GameDataManager.store.flush();
        GameDataManager.pendingFlushes++;
        flush.then(() => {
          GameDataManager.pendingFlushes--;
        }).catch((err: BusinessError) => {
          GameDataManager.pendingFlushes--;
          GameDataManager.dirty = true;
          hilog.error(0x0000, 'LittleGames', 'Failed to flush preferences: %{public}d', err.code);
        });
      }
    } catch (e) {
      GameDataManager.dirty = true;
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
    GameDataManager.persist(true);
  }

  static getAllGames(): GameInfo[] {
    return GameDataManager.games;
  }

  /** Only the two supported games persist versioned, bounded game snapshots. */
  static getSavedGame(gameId: string): string {
    if (gameId === '2048') { return GameDataManager.saved2048; }
    if (gameId === 'sudoku') { return GameDataManager.savedSudoku; }
    return '';
  }

  static setSavedGame(gameId: string, payload: string): void {
    if (payload.length > MAX_SAVED_GAME_LENGTH || (gameId !== '2048' && gameId !== 'sudoku')) {
      hilog.error(0x0000, 'LittleGames', 'Rejected unsupported or oversized local game snapshot');
      return;
    }
    if (GameDataManager.getSavedGame(gameId) === payload) { return; }
    if (gameId === '2048') { GameDataManager.saved2048 = payload; }
    else { GameDataManager.savedSudoku = payload; }
    GameDataManager.savedGamesDirty = true;
    GameDataManager.markDirty();
  }

  /** Clearing data invalidates snapshots held by an already-open game page. */
  static getSavedGameRevision(): number { return GameDataManager.savedGameRevision; }

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

  static recordGamePlayed(id: string): void {
    const game = GameDataManager.games.find(g => g.id === id);
    if (game) {
      GameDataManager.markPlayed(id);
      GameDataManager.lastPlayedAtByGame[id] = Date.now();
      GameDataManager.recentGameIds = [id].concat(GameDataManager.recentGameIds.filter((recentId: string) => recentId !== id));
      GameDataManager.markDirty();
    }
  }

  static addPlayTime(id: string, milliseconds: number): void {
    const game: GameInfo | undefined = GameDataManager.getGameById(id);
    if (game === undefined || !Number.isFinite(milliseconds) || milliseconds < 1) { return; }
    const elapsed: number = Math.floor(milliseconds);
    if (elapsed > Number.MAX_SAFE_INTEGER - game.playTimeMs) { return; }
    game.playTimeMs += elapsed;
    GameDataManager.markPlayed(id);
    GameDataManager.markDirty();
  }

  static getTotalPlayTimeMs(): number {
    let total: number = 0;
    for (let i = 0; i < GameDataManager.games.length; i++) { total += GameDataManager.games[i].playTimeMs; }
    return total;
  }

  static getTopGames(limit: number = 5): GameInfo[] {
    return [...GameDataManager.games].sort((a, b) => b.highScore - a.highScore).slice(0, limit);
  }

  /** 按累计游玩时长排序，与最高分排行、最近顺序区分。 */
  static getMostPlayed(limit: number = 5): GameInfo[] {
    return [...GameDataManager.games].sort((a, b) => b.playTimeMs - a.playTimeMs).slice(0, limit);
  }

  /** 最近进入顺序，与累计时长无关。 */
  static getRecentlyPlayed(limit: number = 5): GameInfo[] {
    const result: GameInfo[] = [];
    for (let i = 0; i < GameDataManager.recentGameIds.length && result.length < limit; i++) {
      const game = GameDataManager.getGameById(GameDataManager.recentGameIds[i]);
      if (game !== undefined) { result.push(game); }
    }
    return result;
  }

  /** 全部已玩游戏按最近开局时间降序排列，时间相同或未知时保留原最近顺序。 */
  static getPlayHistory(): PlayedGameRecord[] {
    const orderedIds: string[] = GameDataManager.recentGameIds.slice();
    for (let i = 0; i < GameDataManager.playedGameIds.length; i++) {
      const id: string = GameDataManager.playedGameIds[i];
      if (!orderedIds.includes(id)) { orderedIds.push(id); }
    }
    const result: PlayedGameRecord[] = [];
    for (let i = 0; i < orderedIds.length; i++) {
      const game: GameInfo | undefined = GameDataManager.getGameById(orderedIds[i]);
      if (game !== undefined) {
        const lastPlayedAt: number = GameDataManager.lastPlayedAtByGame[game.id] ?? 0;
        result.push(new PlayedGameRecord(game, lastPlayedAt));
      }
    }
    return result.sort((a: PlayedGameRecord, b: PlayedGameRecord): number => {
      const timeDifference: number = b.lastPlayedAt - a.lastPlayedAt;
      if (timeDifference !== 0) { return timeDifference; }
      return orderedIds.indexOf(a.game.id) - orderedIds.indexOf(b.game.id);
    });
  }

  static getPlayedGameCount(): number {
    return GameDataManager.playedGameIds.filter((id: string): boolean => isGameAvailable(id)).length;
  }

  /** 获取设置项，不存在时返回默认值 */
  static getSetting(key: string, defaultValue: boolean): boolean {
    const val = GameDataManager.settings[key];
    return typeof val === 'boolean' ? val : defaultValue;
  }

  static getTextSetting(key: string, defaultValue: string): string {
    const val = GameDataManager.settings[key];
    return typeof val === 'string' ? val : defaultValue;
  }

  static getThemeMode(): string {
    const value = GameDataManager.getTextSetting('themeMode', 'system');
    return value === 'light' || value === 'dark' ? value : 'system';
  }

  static getDefaultDifficulty(): GameDifficulty {
    return GameDataManager.parseDifficulty(GameDataManager.getTextSetting('defaultDifficulty', 'normal'));
  }

  private static parseDifficulty(value: string): GameDifficulty {
    if (value === GameDifficulty.EASY) { return GameDifficulty.EASY; }
    if (value === GameDifficulty.HARD) { return GameDifficulty.HARD; }
    return GameDifficulty.NORMAL;
  }

  /** 仅在进入游戏时读取；重开当前对局保持当前难度。 */
  static getInitialDifficulty(gameId: string): GameDifficulty {
    const fallback: GameDifficulty = GameDataManager.getDefaultDifficulty();
    if (!GameDataManager.getSetting('rememberDifficulty', false)) { return fallback; }
    const value: string = GameDataManager.getTextSetting('difficulty_' + gameId, fallback);
    if (value === GameDifficulty.EASY || value === GameDifficulty.NORMAL || value === GameDifficulty.HARD) {
      return GameDataManager.parseDifficulty(value);
    }
    return fallback;
  }

  static rememberGameDifficulty(gameId: string, difficulty: GameDifficulty): void {
    if (GameDataManager.getSetting('rememberDifficulty', false)) {
      GameDataManager.setTextSetting('difficulty_' + gameId, difficulty);
    }
  }

  static setTextSetting(key: string, value: string): void {
    if (GameDataManager.settings[key] === value) { return; }
    GameDataManager.settings[key] = value;
    GameDataManager.dirty = true;
    GameDataManager.flushNow();
  }

  /** 仅恢复偏好设置，保留战绩。页面需同时应用恢复后的主题。 */
  static resetSettings(): void {
    GameDataManager.settings = {
      'hapticsEnabled': true, 'soundEnabled': true, 'themeMode': 'system', 'defaultDifficulty': 'normal',
      'rememberDifficulty': false, 'confirmExitEnabled': true
    };
    gameSound.setEnabled(true);
    GameDataManager.dirty = true;
    GameDataManager.flushNow();
  }

  /** 清空战绩和最近游玩列表，保留用户设置。调用前由设置页确认。 */
  static clearPlayData(): void {
    for (let i = 0; i < GameDataManager.catalog.length; i++) {
      GameDataManager.catalog[i].highScore = 0;
      GameDataManager.catalog[i].playTimeMs = 0;
    }
    GameDataManager.recentGameIds = [];
    GameDataManager.playedGameIds = [];
    GameDataManager.lastPlayedAtByGame = {};
    GameDataManager.saved2048 = '';
    GameDataManager.savedSudoku = '';
    GameDataManager.savedGamesDirty = true;
    GameDataManager.savedGameRevision++;
    GameDataManager.dirty = true;
    GameDataManager.flushNow();
  }

  /** 设置开关立即同步刷盘，避免快速结束进程时丢失。 */
  static setSetting(key: string, value: boolean): void {
    if (GameDataManager.settings[key] === value) { return; }
    GameDataManager.settings[key] = value;
    if (key === 'soundEnabled') { gameSound.setEnabled(value); }
    GameDataManager.dirty = true;
    GameDataManager.flushNow();
  }
}
