/**
 * 滑动拼图 —— ViewModel 层
 *
 * 持有 UI 状态（@ObservedV2 + @Trace），编排规则(Model) + 持久化。
 * 本游戏无暂停玩法：status 只有 进行中 ⇄ 已结束 两态。
 * View 只与它交互，不接触 Model 类型。
 */
import { GameDifficulty, GameStatus } from '../common/GameConstants';
import { GameDataManager } from '../model/GameData';
import { GameLifecycleObserver } from '../common/GameLifecycleBus';
import { SlidePuzzleRules } from '../model/game/SlidePuzzleModel';
import { RandomSource, RealRandom } from '../model/game/RandomSource';

const GAME_ID = 'slidepuzzle';

@ObservedV2
export class SlidePuzzleViewModel implements GameLifecycleObserver {
  @Trace board: number[] = [];
  @Trace steps: number = 0;
  @Trace status: GameStatus = GameStatus.PLAYING;
  @Trace best: number = 999;
  @Trace difficulty: GameDifficulty = GameDifficulty.EASY;
  /** 退出确认弹窗显隐（F2：对局中返回需确认，防误丢步数进度） */
  @Trace confirmExit: boolean = false;

  private rules: SlidePuzzleRules;
  private rng: RandomSource;

  constructor(rng?: RandomSource) {
    this.rng = rng ?? new RealRandom();
    this.rules = new SlidePuzzleRules(this.getSize());
    const hs = GameDataManager.getGameById(GAME_ID)?.highScore ?? 0;
    this.best = hs > 0 ? Math.max(1, 1000 - hs) : 999;
  }

  getSize(): number {
    if (this.difficulty === GameDifficulty.EASY) { return 3; }
    if (this.difficulty === GameDifficulty.HARD) { return 5; }
    return 4;
  }

  changeDifficulty(d: GameDifficulty): void {
    if (this.difficulty === d) { return; }
    this.difficulty = d;
    this.startGame();
  }

  startGame(): void {
    this.rules = new SlidePuzzleRules(this.getSize());
    GameDataManager.incrementPlayCount(GAME_ID);
    this.board = this.rules.shuffle(this.rng);
    this.steps = 0;
    this.status = GameStatus.PLAYING;
  }

  cellAt(r: number, c: number): number {
    return this.board[r * this.getSize() + c];
  }

  tapCell(r: number, c: number): void {
    if (this.status === GameStatus.OVER) { return; }
    if (!this.rules.canMove(this.board, r, c)) { return; }
    this.board = this.rules.tap(this.board, r, c);
    this.steps++;
    if (this.rules.isSolved(this.board)) {
      this.status = GameStatus.OVER;
      if (this.steps < this.best) { this.best = this.steps; }
      GameDataManager.updateHighScore(GAME_ID, this.rules.score(this.steps));
    }
  }

  getBestText(): string {
    if (this.best === 999) { return '--'; }
    return '' + this.best;
  }

  // —— GameLifecycleObserver（完成才计分、无定时器：切后台无需暂停/结算）——
  onAppHidden(): void {
  }

  onAppShown(): void {
  }

  /** 系统侧滑返回转发（NavDestination.onBackPressed）。进行中弹确认并拦截 */
  onBackRequested(): boolean {
    return this.requestBack();
  }

  /** 页面返回按钮与系统侧滑共用：进行中弹确认（进度无保存机制，防误退），其余放行 */
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

  /** 页面销毁：无定时器可停（保持全部 VM 的 dispose 形态统一） */
  dispose(): void {
  }
}
