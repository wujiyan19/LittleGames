/**
 * 滑动拼图 —— ViewModel 层
 *
 * 持有 UI 状态（@ObservedV2 + @Trace），编排规则(Model) + 持久化。
 * 本游戏无暂停玩法：status 只有 进行中 ⇄ 已结束 两态。
 * View 只与它交互，不接触 Model 类型。
 */
import { GameDifficulty, GameStatus } from '../common/GameConstants';
import { GameDataManager } from '../model/GameData';
import { SlidePuzzleRules } from '../model/game/SlidePuzzleModel';
import { RandomSource, RealRandom } from '../model/game/RandomSource';

const GAME_ID = 'slidepuzzle';

@ObservedV2
export class SlidePuzzleViewModel {
  @Trace board: number[] = [];
  @Trace steps: number = 0;
  @Trace status: GameStatus = GameStatus.PLAYING;
  @Trace best: number = 999;
  @Trace difficulty: GameDifficulty = GameDifficulty.EASY;

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
}
