/**
 * 消消乐（Match3）—— ViewModel 层
 *
 * 持有 UI 状态（@ObservedV2 + @Trace），编排规则(Model) + 持久化。
 * View 只与它交互，不接触 Model 类型。
 */
import { GameStatus } from '../common/GameConstants';
import { ContinuationValidation as V } from '../common/GameSessionTransfer';
import { GameDataManager } from '../model/GameData';
import { GameLifecycleObserver } from '../common/GameLifecycleBus';
import { Match3Rules, ChainResult } from '../model/game/Match3Model';
import { RandomSource, RealRandom } from '../model/game/RandomSource';
import { Haptics } from '../common/Haptics';

const GAME_ID = 'match3';
const MAX_MOVES = 30;


interface Match3ContinuationState {
  version: number;
  board: number[][];
  score: number;
  highScore: number;
  movesLeft: number;
  status: GameStatus;
  selectedRow: number;
  selectedCol: number;
}

@ObservedV2
export class Match3ViewModel implements GameLifecycleObserver {
  @Trace board: number[][] = [];
  @Trace score: number = 0;
  @Trace highScore: number = 0;
  @Trace movesLeft: number = MAX_MOVES;
  @Trace status: GameStatus = GameStatus.PLAYING;
  @Trace selectedRow: number = -1;
  @Trace selectedCol: number = -1;
  @Trace confirmExit: boolean = false;

  private rules: Match3Rules = new Match3Rules();
  private rng: RandomSource;

  constructor(rng?: RandomSource) {
    this.rng = rng ?? new RealRandom();
    this.highScore = GameDataManager.getGameById(GAME_ID)?.highScore ?? 0;
  }

  rows(): number { return this.rules.getRows(); }
  cols(): number { return this.rules.getCols(); }

  /** 开局：生成棋盘、重置指标、增加游玩次数 */
  startGame(): void {
    if (this.score > 0) { GameDataManager.updateHighScore(GAME_ID, this.score); }
    GameDataManager.incrementPlayCount(GAME_ID);
    this.board = this.rules.generateBoard(this.rng);
    this.score = 0;
    this.movesLeft = MAX_MOVES;
    this.status = GameStatus.PLAYING;
    this.selectedRow = -1;
    this.selectedCol = -1;
  }

  /** 点击宝石处理：选中/取消选中/不相邻转移/相邻交换 */
  onGemClick(row: number, col: number): void {
    if (this.status !== GameStatus.PLAYING) { return; }

    // 无选中：选中当前
    if (this.selectedRow === -1) {
      this.selectedRow = row;
      this.selectedCol = col;
      Haptics.tap();
      return;
    }

    // 点击同一宝石：取消选中
    if (this.selectedRow === row && this.selectedCol === col) {
      this.selectedRow = -1;
      this.selectedCol = -1;
      return;
    }

    // 相邻：尝试交换
    if (this.rules.isAdjacent(this.selectedRow, this.selectedCol, row, col)) {
      this.trySwap(this.selectedRow, this.selectedCol, row, col);
      this.selectedRow = -1;
      this.selectedCol = -1;
      return;
    }

    // 不相邻：转移选中
    this.selectedRow = row;
    this.selectedCol = col;
    Haptics.tap();
  }

  /** 执行相邻交换：有效则消除+连锁+扣步，无效则回退 */
  private trySwap(r1: number, c1: number, r2: number, c2: number): void {
    const swapResult = this.rules.trySwap(this.board, r1, c1, r2, c2);

    if (!swapResult.hasMatch) {
      // 无连线：回退（棋盘不变，不扣步数）
      return;
    }

    // 有效交换：提交棋盘、扣步、连锁消除
    Haptics.tap();
    this.board = swapResult.board;
    this.movesLeft--;

    const chainResult: ChainResult = this.rules.resolveChain(this.board, this.rng);
    this.board = chainResult.board;
    this.score += chainResult.totalGained;

    if (this.score > this.highScore) {
      this.highScore = this.score;
    }

    // 步数归零：结算并结束
    if (this.movesLeft === 0) {
      this.status = GameStatus.OVER;
      GameDataManager.updateHighScore(GAME_ID, this.score);
    }
  }

  /** 判断宝石是否选中 */
  isSelected(row: number, col: number): boolean {
    return this.selectedRow === row && this.selectedCol === col;
  }

  /** 获取宝石类型（供 View 渲染） */
  gemType(row: number, col: number): number {
    return this.board[row][col];
  }

  /** 结算当前对局分数（max 语义幂等） */
  private settleCurrentScore(): void {
    if (this.score > 0) { GameDataManager.updateHighScore(GAME_ID, this.score); }
  }

  /** 切后台：结算当前分 */
  onAppHidden(): void {
    this.settleCurrentScore();
  }

  onAppShown(): void {
  }

  /** 系统侧滑返回转发 */
  onBackRequested(): boolean {
    return this.requestBack();
  }

  /** 页面返回按钮与系统侧滑共用：进行中弹确认，其余放行 */
  requestBack(): boolean {
    if (!GameDataManager.getSetting('confirmExitEnabled', true)) { return false; }
    if (this.status === GameStatus.PLAYING) {
      this.confirmExit = true;
      return true;
    }
    return false;
  }

  dismissExitConfirm(): void {
    this.confirmExit = false;
  }

  /** 页面销毁：结算当前分 */
  dispose(): void {
    this.settleCurrentScore();
  }

  continuationGameId(): string { return GAME_ID; }

  /** Capture only game data; exporting never pauses or mutates the source game. */
  exportContinuation(): string {

    const state: Match3ContinuationState = {
      version: 1,
      board: this.board,
      score: this.score,
      highScore: this.highScore,
      movesLeft: this.movesLeft,
      status: this.status,
      selectedRow: this.selectedRow,
      selectedCol: this.selectedCol
    };
    return JSON.stringify(state);
  }

  /** Validate completely before replacing a running game. Rebuild observed class instances. */
  importContinuation(payload: string): boolean {
    try {
      if (payload.length > 65536) { return false; }
      const s: Match3ContinuationState = JSON.parse(payload) as Match3ContinuationState;
      if (s === null || s.version !== 1 || !V.integer(s.score) ||
          !V.integer(s.highScore) ||
          !V.integer(s.movesLeft) ||
          (s.status !== GameStatus.PLAYING && s.status !== GameStatus.PAUSED && s.status !== GameStatus.OVER && s.status !== GameStatus.IDLE) ||
          !V.integer(s.selectedRow, -1) ||
          !V.integer(s.selectedCol, -1)) { return false; }
      if (!V.matrix(s.board, 8, 8, 0, 5) || s.movesLeft > MAX_MOVES ||
          !V.integer(s.selectedRow, -1, 7) || !V.integer(s.selectedCol, -1, 7) ||
          (s.selectedRow === -1) !== (s.selectedCol === -1)) { return false; }

      this.board = s.board;
      this.score = s.score;
      this.highScore = Math.max(s.highScore, GameDataManager.getGameById(GAME_ID)?.highScore ?? 0);
      GameDataManager.updateHighScore(GAME_ID, this.highScore);
      this.movesLeft = s.movesLeft;
      this.status = s.status;
      this.selectedRow = s.selectedRow;
      this.selectedCol = s.selectedCol;
      this.confirmExit = false;

      return true;
    } catch (e) {
      return false;
    }
  }
}