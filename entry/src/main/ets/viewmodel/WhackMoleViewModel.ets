/**
 * 打地鼠 —— ViewModel 层
 *
 * 持有 UI 状态（@ObservedV2 + @Trace），编排规则(Model) + 双定时器(倒计时/刷怪) + 持久化。
 * View 只与它交互，不接触 Model 类型。
 */
import { GameDifficulty, GameStatus } from '../common/GameConstants';
import { ContinuationValidation as V } from '../common/GameSessionTransfer';
import { GameDataManager } from '../model/GameData';
import { GameLifecycleObserver } from '../common/GameLifecycleBus';
import { WhackMoleRules, WhackResult } from '../model/game/WhackMoleModel';
import { RandomSource, RealRandom } from '../model/game/RandomSource';

const GAME_ID = 'whackmole';


interface WhackMoleContinuationState {
  version: number;
  holes: boolean[];
  score: number;
  highScore: number;
  timeLeft: number;
  status: GameStatus;
  difficulty: GameDifficulty;
  countdownRemainingMs: number;
}

@ObservedV2
export class WhackMoleViewModel implements GameLifecycleObserver {
  @Trace holes: boolean[] = [];
  @Trace score: number = 0;
  @Trace highScore: number = 0;
  @Trace timeLeft: number = 30;
  @Trace status: GameStatus = GameStatus.IDLE;
  @Trace difficulty: GameDifficulty = GameDataManager.getInitialDifficulty(GAME_ID);
  /** 退出确认弹窗显隐（F2：对局中返回需确认） */
  @Trace confirmExit: boolean = false;

  private rules: WhackMoleRules = new WhackMoleRules();
  private rng: RandomSource;
  private mtimer: number = -1;
  private ctimer: number = -1;
  private countdownRemainingMs: number = 1000;
  private countdownDeadline: number = 0;
  /** 本次暂停是否由「切后台」自动触发 */
  private autoPaused: boolean = false;
  private appVisible: boolean = true;

  constructor(rng?: RandomSource) {
    this.rng = rng ?? new RealRandom();
    this.highScore = GameDataManager.getGameById(GAME_ID)?.highScore ?? 0;
  }

  getGameTime(): number { return this.rules.getGameTime(this.difficulty); }
  getSpawnInterval(): number { return this.rules.getSpawnInterval(this.difficulty); }

  changeDifficulty(d: GameDifficulty): void {
    GameDataManager.rememberGameDifficulty(GAME_ID, d);
    if (this.difficulty === d) { return; }
    this.difficulty = d;
    this.startGame();
  }

  startGame(): void {
    if (this.score > 0) { GameDataManager.updateHighScore(GAME_ID, this.score); }
    this.stopTimers();
    this.autoPaused = false;
    this.confirmExit = false;
    GameDataManager.incrementPlayCount(GAME_ID);
    this.score = 0;
    this.timeLeft = this.getGameTime();
    this.countdownRemainingMs = 1000;
    this.status = GameStatus.PLAYING;
    this.holes = this.rules.initialHoles();
    this.startTimers();
  }

  private startTimers(): void {
    this.stopTimers();
    if (!this.appVisible || this.confirmExit || this.status !== GameStatus.PLAYING) { return; }
    this.scheduleCountdown();
    // 刷怪
    this.mtimer = setInterval(() => {
      if (this.status === GameStatus.PLAYING) {
        this.holes = this.rules.spawnHoles(this.rng);
      }
    }, this.getSpawnInterval());
  }

  private scheduleCountdown(): void {
    this.countdownDeadline = Date.now() + this.countdownRemainingMs;
    this.ctimer = setTimeout(() => {
      this.ctimer = -1;
      if (!this.appVisible || this.confirmExit || this.status !== GameStatus.PLAYING) { return; }
      this.timeLeft--;
      this.countdownRemainingMs = 1000;
      if (this.timeLeft <= 0) { this.gameOver(); }
      else { this.scheduleCountdown(); }
    }, this.countdownRemainingMs);
  }

  /**
   * 结算当前对局分数（max 语义幂等）。原先只在对局结束/下次开局时结算，
   * 中途退出会静默丢失当前得分。
   */
  private settleCurrentScore(): void {
    if (this.score > 0) { GameDataManager.updateHighScore(GAME_ID, this.score); }
  }

  /** 手动暂停/恢复。两个定时回调都只放行 PLAYING */
  togglePause(): void {
    if (this.status === GameStatus.PLAYING) {
      this.status = GameStatus.PAUSED;
      this.stopTimers();
    } else if (this.status === GameStatus.PAUSED && this.appVisible && !this.confirmExit) {
      this.status = GameStatus.PLAYING;
      this.startTimers();
    }
  }

  /**
   * 切后台（GameLifecycleBus：UIAbility.onBackground）。结算 + 自动暂停，
   * 避免倒计时在后台归零直接结算（页面 onPageHide() 仅对 @Entry 生效，不可依赖）。
   */
  onAppHidden(): void {
    this.appVisible = false;
    this.stopTimers();
    this.settleCurrentScore();
    if (this.status === GameStatus.PLAYING) {
      this.autoPaused = true;
      this.status = GameStatus.PAUSED;
    }
  }

  onAppShown(): void {
    this.appVisible = true;
    if (this.autoPaused) {
      this.autoPaused = false;
      this.status = GameStatus.PLAYING;
      this.startTimers();
    }
  }

  /** 系统侧滑返回转发（NavDestination.onBackPressed）。进行中弹确认并拦截 */
  onBackRequested(): boolean {
    return this.requestBack();
  }

  /** 页面返回按钮与系统侧滑共用：进行中弹确认，其余放行 */
  requestBack(): boolean {
    if (!GameDataManager.getSetting('confirmExitEnabled', true)) { return false; }
    if (this.status === GameStatus.PLAYING) {
      this.confirmExit = true;
      this.stopTimers();
      return true;
    }
    return false;
  }

  dismissExitConfirm(): void {
    this.confirmExit = false;
    this.startTimers();
  }

  whack(index: number): void {
    if (this.status !== GameStatus.PLAYING || this.confirmExit || !this.appVisible) { return; }
    const result: WhackResult = this.rules.whack(this.holes, index);
    this.holes = result.holes;
    this.score = Math.max(0, this.score + result.delta);
  }

  private gameOver(): void {
    this.status = GameStatus.OVER;
    this.stopTimers();
    if (this.score > this.highScore) { this.highScore = this.score; }
    GameDataManager.updateHighScore(GAME_ID, this.score);
  }

  private stopTimers(): void {
    if (this.ctimer !== -1) {
      this.countdownRemainingMs = Math.max(1, this.countdownDeadline - Date.now());
      clearTimeout(this.ctimer);
      this.ctimer = -1;
    }
    if (this.mtimer !== -1) { clearInterval(this.mtimer); this.mtimer = -1; }
  }

  /** 页面销毁：停定时器并结算当前分（覆盖「中途退出丢分」主路径） */
  dispose(): void {
    this.appVisible = false;
    this.autoPaused = false;
    this.stopTimers();
    this.settleCurrentScore();
  }

  continuationGameId(): string { return GAME_ID; }

  /** Capture only game data; exporting never pauses or mutates the source game. */
  exportContinuation(): string {

    const state: WhackMoleContinuationState = {
      version: 1,
      holes: this.holes,
      score: this.score,
      highScore: this.highScore,
      timeLeft: this.timeLeft,
      status: this.status,
      difficulty: this.difficulty,
      countdownRemainingMs: this.ctimer !== -1 ? Math.max(1, this.countdownDeadline - Date.now()) : this.countdownRemainingMs
    };
    return JSON.stringify(state);
  }

  /** Validate completely before replacing a running game. Rebuild observed class instances. */
  importContinuation(payload: string): boolean {
    try {
      if (payload.length > 65536) { return false; }
      const s: WhackMoleContinuationState = JSON.parse(payload) as WhackMoleContinuationState;
      if (s === null || s.version !== 1 || !V.integer(s.score) ||
          !V.integer(s.highScore) ||
          !V.integer(s.timeLeft) ||
          (s.status !== GameStatus.PLAYING && s.status !== GameStatus.PAUSED && s.status !== GameStatus.OVER && s.status !== GameStatus.IDLE) ||
          (s.difficulty !== GameDifficulty.EASY && s.difficulty !== GameDifficulty.NORMAL && s.difficulty !== GameDifficulty.HARD) ||
          !V.integer(s.countdownRemainingMs)) { return false; }
      if (!V.booleans(s.holes, 9) || s.timeLeft > this.rules.getGameTime(s.difficulty) ||
          !V.integer(s.countdownRemainingMs, 1, 1000)) { return false; }
      this.stopTimers();
      this.holes = s.holes;
      this.score = s.score;
      this.highScore = Math.max(s.highScore, GameDataManager.getGameById(GAME_ID)?.highScore ?? 0);
      GameDataManager.updateHighScore(GAME_ID, this.highScore);
      this.timeLeft = s.timeLeft;
      this.status = s.status;
      this.difficulty = s.difficulty;
      this.countdownRemainingMs = s.countdownRemainingMs;
      this.confirmExit = false;
      this.appVisible = true;
      this.autoPaused = false;
      if (this.status === GameStatus.PLAYING) { this.status = GameStatus.PAUSED; }
      return true;
    } catch (e) {
      return false;
    }
  }
}
