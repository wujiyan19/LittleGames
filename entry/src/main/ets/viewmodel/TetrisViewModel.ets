/**
 * 俄罗斯方块 —— ViewModel 层
 *
 * 持有 UI 状态（@ObservedV2 + @Trace），编排规则(Model) + 计时 + 持久化。
 * View 只与它交互，不接触 Model 类型。
 */
import { GameDifficulty, GameStatus } from '../common/GameConstants';
import { GameDataManager } from '../model/GameData';
import { GameLifecycleObserver } from '../common/GameLifecycleBus';
import { ActivePiece, TetrisRules } from '../model/game/TetrisModel';
import { RandomSource, RealRandom } from '../model/game/RandomSource';

const COLS = 10;
const ROWS = 20;
const GAME_ID = 'tetris';

@ObservedV2
export class TetrisViewModel implements GameLifecycleObserver {
  /** 棋盘只存数据：0=空，n=第 (n-1) 号形状占据；颜色由 View 查表 */
  @Trace board: number[][] = [];
  @Trace piece: ActivePiece | null = null;
  @Trace score: number = 0;
  @Trace highScore: number = 0;
  @Trace level: number = 1;
  @Trace status: GameStatus = GameStatus.IDLE;
  @Trace difficulty: GameDifficulty = GameDifficulty.NORMAL;
  /** 退出确认弹窗显隐（F2：对局中返回需确认） */
  @Trace confirmExit: boolean = false;

  private rules: TetrisRules = new TetrisRules(COLS, ROWS);
  private rng: RandomSource;
  private timer: number = -1;
  /** 本次暂停是否由「切后台」自动触发 */
  private autoPaused: boolean = false;

  constructor(rng?: RandomSource) {
    this.rng = rng ?? new RealRandom();
    this.highScore = GameDataManager.getGameById(GAME_ID)?.highScore ?? 0;
  }

  cols(): number { return COLS; }
  rows(): number { return ROWS; }

  getBaseFallInterval(): number {
    if (this.difficulty === GameDifficulty.EASY) { return 650; }
    if (this.difficulty === GameDifficulty.HARD) { return 380; }
    return 500;
  }

  private fallInterval(): number {
    return Math.max(80, this.getBaseFallInterval() - (this.level - 1) * 40);
  }

  changeDifficulty(d: GameDifficulty): void {
    if (this.difficulty === d) { return; }
    this.difficulty = d;
    this.startGame();
  }

  /** 只铺开局数据，不启动定时器（初始化/单测用） */
  newGame(): void {
    GameDataManager.incrementPlayCount(GAME_ID);
    this.board = this.rules.emptyBoard();
    this.score = 0;
    this.level = 1;
    this.status = GameStatus.PLAYING;
    this.spawnPiece();
  }

  /** 开局并启动定时器 */
  startGame(): void {
    if (this.score > 0) { GameDataManager.updateHighScore(GAME_ID, this.score); }
    this.newGame();
    this.startTimer();
  }

  startTimer(): void {
    this.stopTimer();
    this.timer = setInterval(() => {
      if (this.status === GameStatus.PLAYING) { this.drop(); }
    }, this.fallInterval());
  }

  stopTimer(): void {
    if (this.timer !== -1) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private spawnPiece(): void {
    this.piece = this.rules.spawn(this.rng);
    if (!this.rules.canPlace(this.board, this.piece, 0, 0)) { this.gameOver(); }
  }

  /** 每 tick 下落一格；无法再下时锁定。定时器与单测都走这里 */
  drop(): void {
    if (this.status !== GameStatus.PLAYING) { return; }
    const p = this.piece;
    if (!p) { return; }
    if (this.rules.canPlace(this.board, p, 0, 1)) {
      this.piece = new ActivePiece(p.idx, p.rot, p.x, p.y + 1);
    } else {
      this.lockPiece();
    }
  }

  private lockPiece(): void {
    const p = this.piece;
    if (!p) { return; }
    const locked = this.rules.lock(this.board, p);
    const result = this.rules.clearRows(locked);
    this.board = result.board;
    if (result.lines > 0) {
      this.score += this.rules.scoreForLines(result.lines, this.level);
      const newLevel = Math.floor(this.score / 1000) + 1;
      if (newLevel !== this.level) {
        this.level = newLevel;
        // 速度随等级加快，重建定时器
        this.startTimer();
      }
    }
    this.spawnPiece();
  }

  moveLeft(): void {
    if (this.status !== GameStatus.PLAYING || !this.piece) { return; }
    if (this.rules.canPlace(this.board, this.piece, -1, 0)) {
      this.piece = new ActivePiece(this.piece.idx, this.piece.rot, this.piece.x - 1, this.piece.y);
    }
  }

  moveRight(): void {
    if (this.status !== GameStatus.PLAYING || !this.piece) { return; }
    if (this.rules.canPlace(this.board, this.piece, 1, 0)) {
      this.piece = new ActivePiece(this.piece.idx, this.piece.rot, this.piece.x + 1, this.piece.y);
    }
  }

  rotateBlock(): void {
    if (this.status !== GameStatus.PLAYING || !this.piece) { return; }
    this.piece = this.rules.rotated(this.board, this.piece);
  }

  hardDrop(): void {
    if (this.status !== GameStatus.PLAYING || !this.piece) { return; }
    const finalY = this.rules.hardDropY(this.board, this.piece);
    this.piece = new ActivePiece(this.piece.idx, this.piece.rot, this.piece.x, finalY);
    this.lockPiece();
  }

  /**
   * 结算当前对局分数（max 语义幂等）。原先只在对局结束/下次开局时结算，
   * 中途退出会静默丢失当前得分。
   */
  private settleCurrentScore(): void {
    if (this.score > 0) { GameDataManager.updateHighScore(GAME_ID, this.score); }
  }

  /** 手动暂停/恢复。只在「进行中 ⇄ 暂停」间切换 */
  togglePause(): void {
    if (this.status === GameStatus.PLAYING) {
      this.status = GameStatus.PAUSED;
    } else if (this.status === GameStatus.PAUSED) {
      this.status = GameStatus.PLAYING;
    }
  }

  /**
   * 切后台（GameLifecycleBus：UIAbility.onBackground）。结算 + 自动暂停。
   * 注意：页面 onPageHide() 仅对 @Entry 生效，本应用游戏页是 @ComponentV2，
   * 必须走总线（原 onPageHide/onPageShow 钩子从未被调用过）。
   */
  onAppHidden(): void {
    this.settleCurrentScore();
    if (this.status === GameStatus.PLAYING) {
      this.autoPaused = true;
      this.status = GameStatus.PAUSED;
    }
  }

  onAppShown(): void {
    if (this.autoPaused) {
      this.autoPaused = false;
      this.status = GameStatus.PLAYING;
    }
  }

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

  /** 供 View 渲染：0=空，n=占用（n-1 为形状索引） */
  cellMark(r: number, c: number): number {
    return this.rules.cellMark(this.board, this.piece, r, c);
  }

  private gameOver(): void {
    this.status = GameStatus.OVER;
    this.stopTimer();
    if (this.score > this.highScore) { this.highScore = this.score; }
    GameDataManager.updateHighScore(GAME_ID, this.score);
  }

  /** 页面销毁：停定时器并结算当前分（覆盖「中途退出丢分」主路径） */
  dispose(): void {
    this.stopTimer();
    this.settleCurrentScore();
  }
}
