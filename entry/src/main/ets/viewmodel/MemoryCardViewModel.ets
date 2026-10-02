/**
 * 记忆翻牌 —— ViewModel 层
 *
 * 持有 UI 状态（@ObservedV2 + @Trace），编排发牌规则(Model) + 翻牌计时 + 持久化。
 * 卡牌为本层私有，对外只暴露只读查询。结算逻辑放在 resolvePending()，
 * 定时回调与单测都走它（单测可直接调用，无需等待）。
 */
import { GameDifficulty, GameStatus } from '../common/GameConstants';
import { ContinuationValidation as V } from '../common/GameSessionTransfer';
import { GameDataManager } from '../model/GameData';
import { GameLifecycleObserver } from '../common/GameLifecycleBus';
import { Card, MemoryCardRules } from '../model/game/MemoryCardModel';
import { RandomSource, RealRandom } from '../model/game/RandomSource';

const GAME_ID = 'memorycard';


interface MemoryCardContinuationState {
  version: number;
  cards: Card[];
  flippedIdxs: number[];
  matchedCount: number;
  attempts: number;
  bestScore: number;
  status: GameStatus;
  difficulty: GameDifficulty;
  locked: boolean;
  pendingMatch: boolean;
}

@ObservedV2
export class MemoryCardViewModel implements GameLifecycleObserver {
  @Trace private cards: Card[] = [];
  @Trace private flippedIdxs: number[] = [];
  @Trace matchedCount: number = 0;
  @Trace attempts: number = 0;
  @Trace bestScore: number = 999;
  @Trace status: GameStatus = GameStatus.PLAYING;
  @Trace difficulty: GameDifficulty = GameDataManager.getInitialDifficulty(GAME_ID);
  /** 退出确认弹窗显隐（F2：对局中返回需确认，防误丢尝试进度） */
  @Trace confirmExit: boolean = false;

  private rules: MemoryCardRules = new MemoryCardRules();
  private rng: RandomSource;
  private locked: boolean = false;
  private flipTimer: number = -1;
  private pendingMatch: boolean = false;

  constructor(rng?: RandomSource) {
    this.rng = rng ?? new RealRandom();
    const hs = GameDataManager.getGameById(GAME_ID)?.highScore ?? 0;
    this.bestScore = hs > 0 ? Math.max(1, 1000 - hs) : 999;
  }

  getPairCount(): number { return this.rules.pairCount(this.difficulty); }
  getRowCount(): number { return this.rules.rowCount(this.difficulty); }

  changeDifficulty(d: GameDifficulty): void {
    GameDataManager.rememberGameDifficulty(GAME_ID, d);
    if (this.difficulty === d) { return; }
    this.difficulty = d;
    this.startGame();
  }

  startGame(): void {
    GameDataManager.incrementPlayCount(GAME_ID);
    this.clearTimer();
    this.cards = this.rules.deal(this.getPairCount(), this.rng);
    this.flippedIdxs = [];
    this.matchedCount = 0;
    this.attempts = 0;
    this.status = GameStatus.PLAYING;
    this.locked = false;
  }

  private cloneCards(): Card[] {
    const next: Card[] = [];
    for (let i = 0; i < this.cards.length; i++) {
      const c = this.cards[i];
      next.push(new Card(c.id, c.emoji, c.flipped, c.matched));
    }
    return next;
  }

  private isAlreadyFlipped(idx: number): boolean {
    for (let i = 0; i < this.flippedIdxs.length; i++) {
      if (this.flippedIdxs[i] === idx) { return true; }
    }
    return false;
  }

  flipCard(idx: number): void {
    if (this.locked || this.status === GameStatus.OVER) { return; }
    if (this.flippedIdxs.length >= 2) { return; }
    if (this.cards[idx].matched) { return; }
    if (this.isAlreadyFlipped(idx)) { return; }

    const flipped = this.cloneCards();
    flipped[idx].flipped = true;
    this.cards = flipped;

    const newFlipped: number[] = [];
    for (let i = 0; i < this.flippedIdxs.length; i++) { newFlipped.push(this.flippedIdxs[i]); }
    newFlipped.push(idx);
    this.flippedIdxs = newFlipped;

    if (this.flippedIdxs.length === 2) {
      this.attempts++;
      this.locked = true;
      const a = this.flippedIdxs[0];
      const b = this.flippedIdxs[1];
      this.pendingMatch = this.rules.isMatch(this.cards, a, b);
      this.flipTimer = setTimeout(() => { this.resolvePending(); }, this.pendingMatch ? 500 : 800);
    }
  }

  /** 结算当前翻开的对子（定时回调；单测可直接调用） */
  resolvePending(): void {
    if (this.flippedIdxs.length !== 2) { return; }
    const a = this.flippedIdxs[0];
    const b = this.flippedIdxs[1];
    if (this.pendingMatch) {
      const matched = this.cloneCards();
      matched[a].matched = true;
      matched[b].matched = true;
      this.cards = matched;
      this.matchedCount++;
      if (this.matchedCount === this.getPairCount()) {
        this.status = GameStatus.OVER;
        if (this.attempts < this.bestScore) { this.bestScore = this.attempts; }
        GameDataManager.updateHighScore(GAME_ID, this.rules.score(this.attempts));
      }
    } else {
      const reset = this.cloneCards();
      reset[a].flipped = false;
      reset[b].flipped = false;
      this.cards = reset;
    }
    this.flippedIdxs = [];
    this.locked = false;
  }

  private clearTimer(): void {
    if (this.flipTimer !== -1) {
      clearTimeout(this.flipTimer);
      this.flipTimer = -1;
    }
  }

  // —— 供 View 渲染的只读查询 ——
  isFaceUp(idx: number): boolean {
    const c = this.cards[idx];
    return c.flipped || c.matched;
  }
  isFlipped(idx: number): boolean { return this.cards[idx].flipped; }
  isMatched(idx: number): boolean { return this.cards[idx].matched; }
  cardEmoji(idx: number): string { return this.cards[idx].emoji; }

  getBestText(): string {
    if (this.bestScore === 999) { return '--'; }
    return '' + this.bestScore;
  }

  // —— GameLifecycleObserver（完成才计分；flipTimer 为亚秒级翻牌延时，切后台无需处理）——
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

  /** 页面销毁：清理翻牌结算定时器 */
  dispose(): void { this.clearTimer(); }

  continuationGameId(): string { return GAME_ID; }

  /** Capture only game data; exporting never pauses or mutates the source game. */
  exportContinuation(): string {

    const state: MemoryCardContinuationState = {
      version: 1,
      cards: this.cards,
      flippedIdxs: this.flippedIdxs,
      matchedCount: this.matchedCount,
      attempts: this.attempts,
      bestScore: this.bestScore,
      status: this.status,
      difficulty: this.difficulty,
      locked: this.locked,
      pendingMatch: this.pendingMatch
    };
    return JSON.stringify(state);
  }

  /** Validate completely before replacing a running game. Rebuild observed class instances. */
  importContinuation(payload: string): boolean {
    try {
      if (payload.length > 65536) { return false; }
      const s: MemoryCardContinuationState = JSON.parse(payload) as MemoryCardContinuationState;
      if (s === null || s.version !== 1 || !V.integer(s.matchedCount) ||
          !V.integer(s.attempts) ||
          !V.integer(s.bestScore) ||
          (s.status !== GameStatus.PLAYING && s.status !== GameStatus.PAUSED && s.status !== GameStatus.OVER && s.status !== GameStatus.IDLE) ||
          (s.difficulty !== GameDifficulty.EASY && s.difficulty !== GameDifficulty.NORMAL && s.difficulty !== GameDifficulty.HARD) ||
          typeof s.locked !== 'boolean' ||
          typeof s.pendingMatch !== 'boolean') { return false; }
      const pairs: number = this.rules.pairCount(s.difficulty);
      if (!Array.isArray(s.cards) || s.cards.length !== pairs * 2 || s.matchedCount > pairs ||
          !Array.isArray(s.flippedIdxs) || s.flippedIdxs.length > 2 ||
          !V.numbers(s.flippedIdxs, s.flippedIdxs.length, 0, s.cards.length - 1)) { return false; }
      for (let i = 0; i < s.cards.length; i++) {
        const c: Card = s.cards[i];
        if (c === null || !V.integer(c.id) || typeof c.emoji !== 'string' || c.emoji.length > 32 ||
            typeof c.flipped !== 'boolean' || typeof c.matched !== 'boolean') { return false; }
      }
      if (s.locked !== (s.flippedIdxs.length === 2)) { return false; }
      this.clearTimer();
      this.cards = s.cards;
      this.flippedIdxs = s.flippedIdxs;
      this.matchedCount = s.matchedCount;
      this.attempts = s.attempts;
      this.bestScore = Math.min(this.bestScore, s.bestScore);
      this.status = s.status;
      this.difficulty = s.difficulty;
      this.locked = s.locked;
      this.pendingMatch = s.pendingMatch;
      this.confirmExit = false;
      this.cards = s.cards.map((c: Card): Card => new Card(c.id, c.emoji, c.flipped, c.matched));
      if (this.locked) {
        this.flipTimer = setTimeout(() => { this.resolvePending(); }, this.pendingMatch ? 500 : 800);
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}
