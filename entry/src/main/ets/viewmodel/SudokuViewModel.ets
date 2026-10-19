/**
 * 数独 —— ViewModel 层
 *
 * 持有 UI 状态（@ObservedV2 + @Trace），编排生成/校验规则(Model) + 持久化。
 * 棋盘用一维 81 格数组（copy-on-write 整体赋值）；题面固定格 fixed 为私有。
 * 本游戏无暂停玩法：status 只有 进行中 ⇄ 已结束 两态。
 */
import { GameDifficulty, GameStatus } from '../common/GameConstants';
import { ContinuationValidation as V } from '../common/GameSessionTransfer';
import { GameDataManager } from '../model/GameData';
import { GameSoundEvent, gameSound } from '../common/GameSound';
import { GameLifecycleObserver } from '../common/GameLifecycleBus';
import { PuzzleResult, SudokuRules } from '../model/game/SudokuModel';
import { RandomSource, RealRandom } from '../model/game/RandomSource';
import { taskpool } from '@kit.ArkTS';
import { generateSudokuPuzzle } from '../model/game/SudokuTask';

const GAME_ID = 'sudoku';


interface SudokuContinuationState {
  version: number;
  board: number[];
  fixed: boolean[];
  puzzle: number[];
  previousKey: string;
  selectedRow: number;
  selectedCol: number;
  status: GameStatus;
  difficulty: GameDifficulty;
}

@ObservedV2
export class SudokuViewModel implements GameLifecycleObserver {
  @Trace board: number[] = [];
  @Trace selectedRow: number = -1;
  @Trace selectedCol: number = -1;
  @Trace status: GameStatus = GameStatus.PLAYING;
  @Trace difficulty: GameDifficulty = GameDataManager.getInitialDifficulty(GAME_ID);
  /** 退出确认弹窗显隐（F2：对局中返回需确认，防误丢填题进度） */
  @Trace confirmExit: boolean = false;
  @Trace isGenerating: boolean = false;
  @Trace generationFailed: boolean = false;
  @Trace resumePending: boolean = false;
  @Trace saveRestoreFailed: boolean = false;
  private savedGameRevision: number = GameDataManager.getSavedGameRevision();
  private generation: number = 0;
  private generationTask: taskpool.Task | null = null;

  private rules: SudokuRules = new SudokuRules();
  private rng: RandomSource;
  // 题面固定格（Given），整局不变
  private fixed: boolean[] = [];
  // 当前题面（用于「重新开始」还原）
  private puzzle: number[] = [];
  // 题面所属难度与正在请求的新难度可能不同，重开时不能混用。
  private puzzleDifficulty: GameDifficulty = this.difficulty;
  // 上一把题面指纹
  private previousKey: string = '';

  constructor(rng?: RandomSource) {
    this.rng = rng ?? new RealRandom();
  }

  newGame(): void {
    gameSound.stop(GAME_ID);
    this.savedGameRevision = GameDataManager.getSavedGameRevision();
    this.cancelGeneration();
    this.isGenerating = false;
    this.generationFailed = false;
    const result: PuzzleResult = this.rules.generatePuzzle(this.difficulty, this.previousKey, this.rng);
    this.previousKey = result.key;
    this.startGame(result.puzzle);
  }

  /** UI 入口：后台线程出题，令快速切难度、重开和退出后的旧结果失效。 */
  async newGameAsync(): Promise<void> {
    this.resumePending = false;
    this.savedGameRevision = GameDataManager.getSavedGameRevision();
    this.cancelGeneration();
    const generation: number = this.generation;
    this.isGenerating = true;
    this.generationFailed = false;
    this.status = GameStatus.PLAYING;
    this.selectedRow = -1;
    this.selectedCol = -1;
    try {
      const task: taskpool.Task = new taskpool.Task(generateSudokuPuzzle, this.difficulty,
        this.previousKey, Math.floor(this.rng.next() * 2147483647));
      this.generationTask = task;
      const puzzle: number[] = await taskpool.execute(task) as number[];
      if (generation !== this.generation) { return; }
      if (puzzle.length !== 81) { throw new Error('Invalid puzzle'); }
      this.previousKey = puzzle.join('');
      this.startGame(puzzle);
    } catch (e) {
      if (generation === this.generation) { this.generationFailed = true; }
    } finally {
      if (generation === this.generation) {
        this.generationTask = null;
        this.isGenerating = false;
        this.saveCurrentGame();
      }
    }
  }

  private cancelGeneration(): void {
    this.generation++;
    const task: taskpool.Task | null = this.generationTask;
    this.generationTask = null;
    if (task !== null) {
      try { taskpool.cancel(task); } catch (e) { /* 已完成的任务无需取消，代次校验仍有效。 */ }
    }
  }

  restartGame(): void {
    gameSound.stop(GAME_ID);
    this.savedGameRevision = GameDataManager.getSavedGameRevision();
    if (this.puzzle.length !== 81 || this.puzzleDifficulty !== this.difficulty) {
      this.newGameAsync(); return;
    }
    this.cancelGeneration();
    this.isGenerating = false;
    this.generationFailed = false;
    this.startGame(this.puzzle);
  }

  private startGame(puzzle: number[]): void {
    this.resumePending = false;
    this.confirmExit = false;
    GameDataManager.recordGameStarted(GAME_ID);
    const b = this.rules.copyGrid(puzzle);
    const f: boolean[] = [];
    for (let i = 0; i < 81; i++) { f.push(puzzle[i] !== 0); }
    this.board = b;
    this.fixed = f;
    this.puzzle = this.rules.copyGrid(puzzle);
    this.puzzleDifficulty = this.difficulty;
    this.status = GameStatus.PLAYING;
    this.selectedRow = -1;
    this.selectedCol = -1;
    this.saveCurrentGame();
  }

  changeDifficulty(d: GameDifficulty): void {
    if (this.resumePending) { return; }
    GameDataManager.rememberGameDifficulty(GAME_ID, d);
    if (this.difficulty === d) { return; }
    this.difficulty = d;
    this.newGameAsync();
  }

  selectCell(r: number, c: number): void {
    if (this.isGenerating || this.generationFailed || this.confirmExit || this.resumePending) { return; }
    if (!V.integer(r, 0, 8) || !V.integer(c, 0, 8)) { return; }
    this.selectedRow = r;
    this.selectedCol = c;
  }

  private setCell(index: number, value: number): void {
    const next = this.board.slice();
    next[index] = value;
    this.board = next;
  }

  setNumber(n: number): void {
    if (this.isGenerating || this.generationFailed || this.confirmExit || this.resumePending || !V.integer(n, 1, 9)) { return; }
    const r = this.selectedRow;
    const c = this.selectedCol;
    if (r < 0 || c < 0 || this.status === GameStatus.OVER) { return; }
    const idx = r * 9 + c;
    if (this.fixed[idx]) { return; }
    if (this.board[idx] === n) { return; }
    this.setCell(idx, n);
    gameSound.play(GAME_ID);
    this.saveRestoreFailed = false;
    this.checkComplete();
    this.saveCurrentGame();
  }

  erase(): void {
    if (this.isGenerating || this.generationFailed || this.confirmExit || this.resumePending || this.status === GameStatus.OVER) { return; }
    const r = this.selectedRow;
    const c = this.selectedCol;
    if (r < 0 || c < 0) { return; }
    const idx = r * 9 + c;
    if (this.fixed[idx]) { return; }
    if (this.board[idx] === 0) { return; }
    this.setCell(idx, 0);
    gameSound.play(GAME_ID);
    this.saveCurrentGame();
  }

  private checkComplete(): void {
    if (!this.rules.isComplete(this.board)) { return; }
    gameSound.play(GAME_ID, GameSoundEvent.WIN);
    this.status = GameStatus.OVER;
    // 难度越高完成得分越高
    let score = 100;
    if (this.difficulty === GameDifficulty.NORMAL) { score = 200; }
    else if (this.difficulty === GameDifficulty.HARD) { score = 300; }
    GameDataManager.updateHighScore(GAME_ID, score);
  }

  // —— 供 View 渲染的只读查询 ——
  cellValue(r: number, c: number): number { return this.board[r * 9 + c] ?? 0; }
  isFixed(r: number, c: number): boolean { return this.fixed[r * 9 + c] ?? false; }

  // —— GameLifecycleObserver（完成才计分、无定时器：切后台无需暂停/结算）——
  onAppHidden(): void {
    gameSound.stop(GAME_ID);
    this.saveCurrentGame();
    GameDataManager.flushNow();
  }

  onAppShown(): void {
  }

  /** 系统侧滑返回转发（NavDestination.onBackPressed）。进行中弹确认并拦截 */
  onBackRequested(): boolean {
    return this.requestBack();
  }

  /** 页面返回按钮与系统侧滑共用：进行中弹确认，其余放行。 */
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

  /** 页面销毁：取消后台生成任务，并令可能晚到的结果失效。 */
  dispose(): void {
    this.saveCurrentGame();
    GameDataManager.flushNow();
    this.cancelGeneration();
    this.isGenerating = false;
  }

  isPlayTimeActive(): boolean { return this.status === GameStatus.PLAYING && !this.confirmExit && !this.resumePending && !this.isGenerating && !this.generationFailed; }

  offerSavedGame(): boolean {
    const payload: string = GameDataManager.getSavedGame(GAME_ID);
    if (payload.length === 0) { return false; }
    try {
      if (payload.length > 8192) { throw new Error('Oversized saved game'); }
      const state: SudokuContinuationState = JSON.parse(payload) as SudokuContinuationState;
      if (state === null || state.status !== GameStatus.PLAYING || !V.numbers(state.puzzle, 81, 0, 9) ||
          state.puzzle.filter((value: number) => value > 0).length < 17 ||
          !V.numbers(state.board, 81, 0, 9) || this.rules.isComplete(state.board) || !this.importContinuation(payload)) {
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
    if (this.isGenerating || this.generationFailed || this.board.length !== 81 || this.puzzleDifficulty !== this.difficulty) { return; }
    GameDataManager.setSavedGame(GAME_ID, this.exportContinuation());
  }

  hasProgress(): boolean { return !this.isGenerating && this.status !== GameStatus.OVER && this.board.some((value: number, index: number) => !this.fixed[index] && value !== 0); }

  continuationGameId(): string { return GAME_ID; }

  /** Capture only game data; exporting never pauses or mutates the source game. */
  exportContinuation(): string {
    if (this.isGenerating || this.generationFailed) { throw new Error('Puzzle not ready'); }
    const state: SudokuContinuationState = {
      version: 1,
      board: this.board,
      fixed: this.fixed,
      puzzle: this.puzzle,
      previousKey: this.previousKey,
      selectedRow: this.selectedRow,
      selectedCol: this.selectedCol,
      status: this.status,
      difficulty: this.difficulty
    };
    return JSON.stringify(state);
  }

  /** Validate completely before replacing a running game. Rebuild observed class instances. */
  importContinuation(payload: string): boolean {
    try {
      if (payload.length > 65536) { return false; }
      const s: SudokuContinuationState = JSON.parse(payload) as SudokuContinuationState;
      if (s === null || s.version !== 1 || typeof s.previousKey !== 'string' || s.previousKey.length > 4096 ||
          !V.integer(s.selectedRow, -1) ||
          !V.integer(s.selectedCol, -1) ||
          (s.status !== GameStatus.PLAYING && s.status !== GameStatus.PAUSED && s.status !== GameStatus.OVER && s.status !== GameStatus.IDLE) ||
          (s.difficulty !== GameDifficulty.EASY && s.difficulty !== GameDifficulty.NORMAL && s.difficulty !== GameDifficulty.HARD)) { return false; }
      if (!V.numbers(s.board, 81, 0, 9) || !V.numbers(s.puzzle, 81, 0, 9) || !V.booleans(s.fixed, 81) ||
          !V.integer(s.selectedRow, -1, 8) || !V.integer(s.selectedCol, -1, 8)) { return false; }
      for (let i = 0; i < 81; i++) {
        if (s.fixed[i] !== (s.puzzle[i] !== 0) || (s.fixed[i] && s.board[i] !== s.puzzle[i])) { return false; }
      }
      this.cancelGeneration();
      this.board = s.board;
      this.fixed = s.fixed;
      this.puzzle = s.puzzle;
      this.previousKey = s.previousKey;
      this.selectedRow = s.selectedRow;
      this.selectedCol = s.selectedCol;
      this.status = s.status;
      this.difficulty = s.difficulty;
      this.puzzleDifficulty = s.difficulty;
      this.confirmExit = false;
      this.resumePending = false;
      this.savedGameRevision = GameDataManager.getSavedGameRevision();
      this.isGenerating = false;
      this.generationFailed = false;
      return true;
    } catch (e) {
      return false;
    }
  }
}
