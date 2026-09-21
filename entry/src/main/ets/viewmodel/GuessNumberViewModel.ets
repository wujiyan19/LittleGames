/**
 * 猜数字 —— ViewModel 层
 *
 * 持有 UI 状态（@ObservedV2 + @Trace），编排规则(Model) + 持久化。
 * View 只与它交互；列表项类型 GuessRecord 也定义在此层，View 从本模块 import。
 */
import { GameDifficulty, GameStatus } from '../common/GameConstants';
import { GameDataManager } from '../model/GameData';
import { GameLifecycleObserver } from '../common/GameLifecycleBus';
import { GuessFeedback, GuessNumberRules } from '../model/game/GuessNumberModel';
import { RandomSource, RealRandom } from '../model/game/RandomSource';

const GAME_ID = 'guessnumber';

/** 一条猜测记录（供 View 列表渲染） */
export class GuessRecord {
  guess: string;
  a: number;
  b: number;
  seq: number;

  constructor(guess: string, a: number, b: number, seq: number) {
    this.guess = guess;
    this.a = a;
    this.b = b;
    this.seq = seq;
  }
}

@ObservedV2
export class GuessNumberViewModel implements GameLifecycleObserver {
  @Trace secret: string = '';
  @Trace input: string = '';
  @Trace records: GuessRecord[] = [];
  @Trace isWin: boolean = false;
  /** 对局是否仍在进行。胜负由 isWin 表达——那是「结果」，与「状态」是两回事 */
  @Trace status: GameStatus = GameStatus.PLAYING;
  @Trace tries: number = 0;
  @Trace difficulty: GameDifficulty = GameDifficulty.NORMAL;
  /** 退出确认弹窗显隐（F2：对局中返回需确认，防误丢尝试进度） */
  @Trace confirmExit: boolean = false;

  private rules: GuessNumberRules = new GuessNumberRules();
  private rng: RandomSource;
  private recordSeq: number = 0;

  constructor(rng?: RandomSource) {
    this.rng = rng ?? new RealRandom();
  }

  getSecretLength(): number { return this.rules.secretLength(this.difficulty); }
  getMaxTries(): number { return this.rules.maxTries(this.difficulty); }
  getScore(): number { return this.rules.score(this.difficulty, this.tries); }
  isInputComplete(): boolean { return this.input.length === this.getSecretLength(); }

  startGame(): void {
    GameDataManager.incrementPlayCount(GAME_ID);
    this.secret = this.rules.generateSecret(this.getSecretLength(), this.rng);
    this.input = '';
    this.records = [];
    this.isWin = false;
    this.status = GameStatus.PLAYING;
    this.tries = 0;
    this.recordSeq = 0;
  }

  changeDifficulty(d: GameDifficulty): void {
    if (this.difficulty === d) { return; }
    this.difficulty = d;
    this.startGame();
  }

  pushDigit(d: string): void {
    if (this.status !== GameStatus.PLAYING || this.isWin ||
        this.input.length >= this.getSecretLength()) { return; }
    if (this.input.indexOf(d) >= 0) { return; }
    this.input += d;
  }

  deleteDigit(): void {
    if (this.status !== GameStatus.PLAYING) { return; }
    this.input = this.input.substring(0, this.input.length - 1);
  }

  submit(): void {
    if (this.status !== GameStatus.PLAYING ||
        this.input.length !== this.getSecretLength() || this.isWin) { return; }
    this.tries++;
    const feedback: GuessFeedback = this.rules.evaluate(this.secret, this.input);
    this.recordSeq++;
    const rec = new GuessRecord(this.input, feedback.a, feedback.b, this.recordSeq);
    const newRecs: GuessRecord[] = [rec];
    for (let i = 0; i < this.records.length; i++) { newRecs.push(this.records[i]); }
    this.records = newRecs;
    if (feedback.a === this.getSecretLength()) {
      this.isWin = true;
      this.status = GameStatus.OVER;
      GameDataManager.updateHighScore(GAME_ID, this.getScore());
    }
    if (this.tries >= this.getMaxTries()) { this.status = GameStatus.OVER; }
    this.input = '';
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
