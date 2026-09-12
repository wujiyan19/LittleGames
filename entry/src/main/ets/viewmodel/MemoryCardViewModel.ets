/**
 * 记忆翻牌 —— ViewModel 层
 *
 * 持有 UI 状态（@ObservedV2 + @Trace），编排发牌规则(Model) + 翻牌计时 + 持久化。
 * 卡牌为本层私有，对外只暴露只读查询。结算逻辑放在 resolvePending()，
 * 定时回调与单测都走它（单测可直接调用，无需等待）。
 */
import { GameDifficulty, GameStatus } from '../common/GameConstants';
import { GameDataManager } from '../model/GameData';
import { Card, MemoryCardRules } from '../model/game/MemoryCardModel';
import { RandomSource, RealRandom } from '../model/game/RandomSource';

const GAME_ID = 'memorycard';

@ObservedV2
export class MemoryCardViewModel {
  @Trace private cards: Card[] = [];
  @Trace private flippedIdxs: number[] = [];
  @Trace matchedCount: number = 0;
  @Trace attempts: number = 0;
  @Trace bestScore: number = 999;
  @Trace status: GameStatus = GameStatus.PLAYING;
  @Trace difficulty: GameDifficulty = GameDifficulty.NORMAL;

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

  dispose(): void { this.clearTimer(); }
}
