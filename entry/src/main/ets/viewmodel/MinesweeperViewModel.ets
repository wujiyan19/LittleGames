/**
 * 扫雷 —— ViewModel 层
 *
 * 持有 UI 状态（@ObservedV2 + @Trace），编排规则(Model) + 计时 + 持久化。
 * 本游戏无暂停玩法：status 只有 进行中(PLAYING) ⇄ 已结束(OVER)；
 * 胜负结果（gameResult）与 status 正交，单独持有。
 * View 只与它交互，不接触 Model 类型。
 */
import { GameDifficulty, GameStatus } from '../common/GameConstants';
import { GameDataManager } from '../model/GameData';
import { GameLifecycleObserver } from '../common/GameLifecycleBus';
import { MinesweeperRules, RevealResult } from '../model/game/MinesweeperModel';
import { RandomSource, RealRandom } from '../model/game/RandomSource';

const ROWS = 9;
const COLS = 9;
const GAME_ID = 'minesweeper';

@ObservedV2
export class MinesweeperViewModel implements GameLifecycleObserver {
  @Trace board: number[][] = [];
  @Trace revealed: boolean[][] = [];
  @Trace flagged: boolean[][] = [];
  @Trace status: GameStatus = GameStatus.PLAYING;
  @Trace flagCount: number = 0;
  @Trace difficulty: GameDifficulty = GameDifficulty.NORMAL;
  @Trace elapsed: number = 0;
  @Trace gameResult: boolean = false;
  /** 退出确认弹窗显隐（F2：对局中返回需确认） */
  @Trace confirmExit: boolean = false;

  private rules: MinesweeperRules = new MinesweeperRules(ROWS, COLS);
  private rng: RandomSource;
  private timer: number = -1;
  private startTime: number = 0;
  /** 计时是否已启动且尚未结束 */
  private timerRunning: boolean = false;
  private minesPlaced: boolean = false;

  constructor(rng?: RandomSource) {
    this.rng = rng ?? new RealRandom();
  }

  rows(): number { return ROWS; }
  cols(): number { return COLS; }

  getMineCount(): number {
    if (this.difficulty === GameDifficulty.EASY) { return 8; }
    if (this.difficulty === GameDifficulty.HARD) { return 14; }
    return 10;
  }

  changeDifficulty(d: GameDifficulty): void {
    if (this.difficulty === d) { return; }
    this.difficulty = d;
    this.startGame();
  }

  newGame(): void {
    GameDataManager.incrementPlayCount(GAME_ID);
    this.board = this.rules.emptyBoard();
    this.revealed = this.rules.emptyBool();
    this.flagged = this.rules.emptyBool();
    this.status = GameStatus.PLAYING;
    this.flagCount = 0;
    this.elapsed = 0;
    // 雷与计时都推迟到首次点击，保证首点安全
    this.minesPlaced = false;
    this.timerRunning = false;
    this.stopTimer();
  }

  startGame(): void {
    this.newGame();
  }

  private stopTimer(): void {
    if (this.timer !== -1) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  /** 首次揭开时启动计时 */
  private startTimer(): void {
    this.stopTimer();
    this.startTime = Date.now();
    this.timerRunning = true;
    this.timer = setInterval(() => {
      if (this.status === GameStatus.PLAYING) {
        this.elapsed = Math.floor((Date.now() - this.startTime) / 1000);
      }
    }, 1000);
  }

  /** 切后台：暂停计时并清理定时器，避免后台虚增用时（影响「用时越短分越高」） */
  pauseTimer(): void {
    if (!this.timerRunning) { return; }
    this.elapsed = Math.floor((Date.now() - this.startTime) / 1000);
    this.stopTimer();
  }

  /** 回到前台：以已计时秒数为基准恢复计时 */
  resumeTimer(): void {
    if (!this.timerRunning || this.timer !== -1) { return; }
    this.startTime = Date.now() - this.elapsed * 1000;
    this.timer = setInterval(() => {
      if (this.status === GameStatus.PLAYING) {
        this.elapsed = Math.floor((Date.now() - this.startTime) / 1000);
      }
    }, 1000);
  }

  /**
   * 切后台（GameLifecycleBus：UIAbility.onBackground）：暂停计时。
   * 注意：页面 onPageHide() 仅对 @Entry 生效，本应用游戏页是 @ComponentV2，
   * 原有的 onPageHide/onPageShow 钩子从未被调用——后台计时虚增曾长期存在，
   * 直接破坏「用时越短分越高」的得分口径。
   */
  onAppHidden(): void { this.pauseTimer(); }
  onAppShown(): void { this.resumeTimer(); }

  /** 系统侧滑返回转发（NavDestination.onBackPressed）。进行中弹确认并拦截 */
  onBackRequested(): boolean {
    return this.requestBack();
  }

  /** 页面返回按钮与系统侧滑共用：进行中弹确认，其余放行 */
  requestBack(): boolean {
    if (this.status === GameStatus.PLAYING) {
      this.confirmExit = true;
      return true;
    }
    return false;
  }

  dismissExitConfirm(): void {
    this.confirmExit = false;
  }

  reveal(r: number, c: number): void {
    if (this.status !== GameStatus.PLAYING || this.revealed[r][c] || this.flagged[r][c]) { return; }
    if (!this.minesPlaced) {
      this.board = this.rules.placeMines(this.board, this.getMineCount(), r, c, this.rng);
      this.minesPlaced = true;
      this.startTimer();
    }
    const result: RevealResult = this.rules.reveal(this.board, this.revealed, this.flagged, r, c);
    this.revealed = result.revealed;
    if (result.hitMine) { this.gameOver(false); return; }
    if (this.rules.allSafeRevealed(this.board, this.revealed)) { this.gameOver(true); }
  }

  toggleFlag(r: number, c: number): void {
    if (this.status !== GameStatus.PLAYING || this.revealed[r][c]) { return; }
    this.flagged = this.rules.toggleFlag(this.revealed, this.flagged, r, c);
    this.flagCount = this.rules.countFlags(this.flagged);
  }

  private gameOver(won: boolean): void {
    this.status = GameStatus.OVER;
    this.timerRunning = false;
    this.stopTimer();
    this.gameResult = won;
    if (won) {
      // 用时越短得分越高
      const score = Math.max(1, 1000 - this.elapsed * 5);
      GameDataManager.updateHighScore(GAME_ID, score);
    }
  }

  // —— 供 View 渲染的只读查询 ——
  isRevealed(r: number, c: number): boolean { return this.revealed[r][c]; }
  isFlagged(r: number, c: number): boolean { return this.flagged[r][c]; }
  isMine(r: number, c: number): boolean { return this.board[r][c] === -1; }
  cellValue(r: number, c: number): number { return this.board[r][c]; }

  dispose(): void { this.stopTimer(); }
}
