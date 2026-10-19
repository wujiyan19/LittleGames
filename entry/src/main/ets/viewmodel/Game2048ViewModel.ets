/**
 * 2048 —— ViewModel 层
 *
 * 持有 UI 状态（@ObservedV2 + @Trace），编排规则(Model) + 持久化。
 * 额外暴露「最近生成格」(spawnRow/spawnCol)，供 View 做新块弹入动画。
 * View 只与它交互，不接触 Model 类型。
 */
import { GameDifficulty, GameStatus } from '../common/GameConstants';
import { ContinuationValidation as V } from '../common/GameSessionTransfer';
import { GameDataManager } from '../model/GameData';
import { GameLifecycleObserver } from '../common/GameLifecycleBus';
import { Game2048Rules, SpawnResult, SwipeDir, SwipeResult } from '../model/game/Game2048Model';
import { RandomSource, RealRandom } from '../model/game/RandomSource';
import { GameSoundEvent, gameSound } from '../common/GameSound';

const SIZE = 4;
const GAME_ID = '2048';


interface Game2048ContinuationState {
  version: number;
  board: number[][];
  score: number;
  highScore: number;
  status: GameStatus;
  difficulty: GameDifficulty;
}

@ObservedV2
export class Game2048ViewModel implements GameLifecycleObserver {
  @Trace board: number[][] = [[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]];
  @Trace score: number = 0;
  @Trace highScore: number = 0;
  @Trace status: GameStatus = GameStatus.PLAYING;
  @Trace difficulty: GameDifficulty = GameDataManager.getInitialDifficulty(GAME_ID);
  /** 最近一次生成的新块位置，-1 表示无（供 View 动画） */
  @Trace spawnRow: number = -1;
  @Trace spawnCol: number = -1;
  /** 退出确认弹窗显隐（F2：对局中返回需确认） */
  @Trace confirmExit: boolean = false;
  @Trace resumePending: boolean = false;
  @Trace saveRestoreFailed: boolean = false;
  private savedGameRevision: number = GameDataManager.getSavedGameRevision();

  private rules: Game2048Rules = new Game2048Rules(SIZE);
  private rng: RandomSource;
  /** 最近一次滑动「每格来源」（供 View 计算位移动画）。
   *  @Trace：rebuildTiles() 通过 sourceAt() 读取此字段判断方块来源，
   *  若不加 @Trace，框架无法追踪依赖，滑动后方块身份判定可能出错。 */
  @Trace private lastSources: number[] = [];

  constructor(rng?: RandomSource) {
    this.rng = rng ?? new RealRandom();
    this.highScore = GameDataManager.getGameById(GAME_ID)?.highScore ?? 0;
  }

  size(): number { return SIZE; }

  getFourChance(): number {
    if (this.difficulty === GameDifficulty.EASY) { return 0.05; }
    if (this.difficulty === GameDifficulty.HARD) { return 0.2; }
    return 0.1;
  }

  changeDifficulty(d: GameDifficulty): void {
    if (this.resumePending) { return; }
    GameDataManager.rememberGameDifficulty(GAME_ID, d);
    if (this.difficulty === d) { return; }
    this.difficulty = d;
    this.startGame();
  }

  /** 只铺开局数据（初始化/单测用） */
  newGame(): void {
    gameSound.stop(GAME_ID);
    this.resumePending = false;
    this.confirmExit = false;
    this.savedGameRevision = GameDataManager.getSavedGameRevision();
    GameDataManager.recordGameStarted(GAME_ID);
    this.board = this.rules.emptyBoard();
    this.score = 0;
    this.status = GameStatus.PLAYING;
    this.lastSources = [];
    this.spawnRow = -1;
    this.spawnCol = -1;
    this.spawnTile();
    this.spawnTile();
    this.saveCurrentGame();
  }

  startGame(): void {
    gameSound.stop(GAME_ID);
    this.settleCurrentScore();
    this.newGame();
  }

  private spawnTile(): void {
    const res: SpawnResult = this.rules.spawn(this.board, this.getFourChance(), this.rng);
    this.board = res.board;
    this.spawnRow = res.row;
    this.spawnCol = res.col;
  }

  swipeLeft(): boolean { return this.swipe(SwipeDir.LEFT); }
  swipeRight(): boolean { return this.swipe(SwipeDir.RIGHT); }
  swipeUp(): boolean { return this.swipe(SwipeDir.UP); }
  swipeDown(): boolean { return this.swipe(SwipeDir.DOWN); }

  /** 执行滑动，返回棋盘是否变化；View 据此决定是否重排方块 */
  private swipe(dir: SwipeDir): boolean {
    if (this.status !== GameStatus.PLAYING || this.resumePending || this.confirmExit) { return false; }
    const result: SwipeResult = this.rules.swipe(this.board, dir);
    if (!result.changed) { return false; }
    gameSound.play(GAME_ID, result.gained > 0 ? GameSoundEvent.REWARD : GameSoundEvent.ACTION);
    this.lastSources = result.sources;
    this.board = result.board;
    this.score += result.gained;
    this.saveRestoreFailed = false;
    this.spawnTile();
    if (this.score > this.highScore) { this.highScore = this.score; }
    if (this.rules.isGameOver(this.board)) {
      gameSound.play(GAME_ID, GameSoundEvent.LOSE);
      this.status = GameStatus.OVER;
      GameDataManager.updateHighScore(GAME_ID, this.score);
    }
    this.saveCurrentGame();
    return true;
  }

  /** 目标格(索引)在滑动前的来源格索引，-1 表示空格/无效 */
  sourceAt(index: number): number {
    if (index < 0 || index >= this.lastSources.length) { return -1; }
    return this.lastSources[index];
  }

  /**
   * 结算当前对局分数（max 语义幂等）。无定时器，切后台只需结算不需暂停。
   * 原先只在对局结束/下次开局时结算，中途退出会静默丢失当前得分。
   */
  private settleCurrentScore(): void {
    if (this.resumePending || this.savedGameRevision !== GameDataManager.getSavedGameRevision()) { return; }
    if (this.score > 0) { GameDataManager.updateHighScore(GAME_ID, this.score); }
  }

  /** 切后台（GameLifecycleBus）：结算当前分。无定时器，无需暂停 */
  onAppHidden(): void {
    gameSound.stop(GAME_ID);
    this.settleCurrentScore();
    this.saveCurrentGame();
    GameDataManager.flushNow();
  }

  onAppShown(): void {
  }

  /** 系统侧滑返回转发（NavDestination.onBackPressed）。进行中弹确认并拦截 */
  onBackRequested(): boolean {
    return this.requestBack();
  }

  /** 页面返回按钮与系统侧滑共用：进行中弹确认，其余放行 */
  requestBack(): boolean {
    if (this.resumePending) { return false; }
    if (!GameDataManager.getSetting('confirmExitEnabled', true)) { return false; }
    if (this.status === GameStatus.PLAYING) {
      gameSound.stop(GAME_ID); this.confirmExit = true;
      return true;
    }
    return false;
  }

  dismissExitConfirm(): void {
    this.confirmExit = false;
  }

  cellValue(r: number, c: number): number {
    return this.board[r][c];
  }

  isOver(): boolean {
    return this.rules.isGameOver(this.board);
  }

  /** 页面销毁：结算当前分（无定时器可停） */
  dispose(): void {
    this.settleCurrentScore();
    this.saveCurrentGame();
    GameDataManager.flushNow();
  }

  isPlayTimeActive(): boolean { return this.status === GameStatus.PLAYING && !this.confirmExit && !this.resumePending; }

  /** Preview the saved board behind a blocking choice; no new round or play time. */
  offerSavedGame(): boolean {
    const payload: string = GameDataManager.getSavedGame(GAME_ID);
    if (payload.length === 0) { return false; }
    try {
      if (payload.length > 8192) { throw new Error('Oversized saved game'); }
      const state: Game2048ContinuationState = JSON.parse(payload) as Game2048ContinuationState;
      if (state === null || state.status !== GameStatus.PLAYING || !V.matrix(state.board, 4, 4, 0, 1073741824) ||
          state.board.reduce((count: number, row: number[]) => count + row.filter((value: number) => value > 0).length, 0) < 2 ||
          this.rules.isGameOver(state.board) || !this.importContinuation(payload)) {
        throw new Error('Invalid saved game');
      }
      this.resumePending = true;
      return true;
    } catch (e) {
      this.saveRestoreFailed = true;
      GameDataManager.setSavedGame(GAME_ID, '');
      return false;
    }
  }

  continueSavedGame(): void {
    if (!this.resumePending) { return; }
    this.resumePending = false;
  }

  saveCurrentGame(): void {
    if (this.resumePending || this.savedGameRevision !== GameDataManager.getSavedGameRevision()) { return; }
    if (this.status === GameStatus.OVER) { GameDataManager.setSavedGame(GAME_ID, ''); return; }
    if (this.status === GameStatus.PLAYING && this.board.some((row: number[]) => row.some((value: number) => value > 0))) {
      GameDataManager.setSavedGame(GAME_ID, this.exportContinuation());
    }
  }

  hasProgress(): boolean {
    const tiles: number = this.board.reduce((count: number, row: number[]) =>
      count + row.filter((value: number) => value > 0).length, 0);
    return this.status !== GameStatus.OVER && (this.score > 0 || tiles > 2);
  }

  continuationGameId(): string { return GAME_ID; }

  /** Capture only game data; exporting never pauses or mutates the source game. */
  exportContinuation(): string {

    const state: Game2048ContinuationState = {
      version: 1,
      board: this.board,
      score: this.score,
      highScore: this.highScore,
      status: this.status,
      difficulty: this.difficulty
    };
    return JSON.stringify(state);
  }

  /** Validate completely before replacing a running game. Rebuild observed class instances. */
  importContinuation(payload: string): boolean {
    try {
      if (payload.length > 65536) { return false; }
      const s: Game2048ContinuationState = JSON.parse(payload) as Game2048ContinuationState;
      if (s === null || s.version !== 1 || !V.integer(s.score) ||
          !V.integer(s.highScore) ||
          (s.status !== GameStatus.PLAYING && s.status !== GameStatus.PAUSED && s.status !== GameStatus.OVER && s.status !== GameStatus.IDLE) ||
          (s.difficulty !== GameDifficulty.EASY && s.difficulty !== GameDifficulty.NORMAL && s.difficulty !== GameDifficulty.HARD)) { return false; }
      if (!V.matrix(s.board, 4, 4, 0, 1073741824)) { return false; }
      for (let r = 0; r < 4; r++) {
        for (let c = 0; c < 4; c++) {
          const value: number = s.board[r][c];
          if (value !== 0 && (value < 2 || !Number.isInteger(Math.log2(value)))) { return false; }
        }
      }

      this.board = s.board;
      this.score = s.score;
      this.highScore = Math.max(s.highScore, GameDataManager.getGameById(GAME_ID)?.highScore ?? 0);
      GameDataManager.updateHighScore(GAME_ID, this.highScore);
      this.status = s.status;
      this.difficulty = s.difficulty;
      this.confirmExit = false;
      this.resumePending = false;
      this.savedGameRevision = GameDataManager.getSavedGameRevision();
      this.lastSources = [];
      this.spawnRow = -1;
      this.spawnCol = -1;
      return true;
    } catch (e) {
      return false;
    }
  }
}
