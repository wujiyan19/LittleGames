/**
 * 贪吃蛇 —— ViewModel 层
 *
 * 持有并暴露 UI 状态（@ObservedV2 + @Trace），编排「规则(Model) + 计时 + 持久化」。
 * View 只与它交互，不接触 Model 类型。
 *
 * 可测性：随机源可注入；stepOnce() 可脱离定时器手动推进，
 * 单测直接 new SnakeViewModel(new SeededRandom(1)) → newGame() → stepOnce()。
 */
import { GameDifficulty, GameStatus } from '../common/GameConstants';
import { GameDataManager } from '../model/GameData';
import { Direction, Point, SnakeRules } from '../model/game/SnakeModel';
import { RandomSource, RealRandom } from '../model/game/RandomSource';

const COLS = 20;
const ROWS = 20;
const GAME_ID = 'snake';

@ObservedV2
export class SnakeViewModel {
  /** 渲染所需的对局状态（蛇身/食物用整体替换，触发 @Trace 刷新） */
  @Trace snake: Point[] = [];
  @Trace food: Point = new Point(-1, -1);
  @Trace score: number = 0;
  @Trace highScore: number = 0;
  @Trace status: GameStatus = GameStatus.IDLE;
  @Trace difficulty: GameDifficulty = GameDifficulty.NORMAL;

  private rules: SnakeRules = new SnakeRules(COLS, ROWS);
  private rng: RandomSource;
  private direction: Direction = Direction.RIGHT;
  // 方向输入缓冲：每个 tick 只应用一次转向，防止一个 tick 内连按两键造成 180° 反向自杀
  private pendingTurn: Direction | null = null;
  private timer: number = -1;
  /** 本次暂停是否由「切后台」自动触发——决定回到前台时是否需要自动恢复 */
  private autoPaused: boolean = false;

  constructor(rng?: RandomSource) {
    this.rng = rng ?? new RealRandom();
    this.highScore = GameDataManager.getGameById(GAME_ID)?.highScore ?? 0;
  }

  cols(): number { return COLS; }
  rows(): number { return ROWS; }

  getMoveInterval(): number {
    if (this.difficulty === GameDifficulty.EASY) { return 240; }
    if (this.difficulty === GameDifficulty.HARD) { return 120; }
    return 180;
  }

  changeDifficulty(d: GameDifficulty): void {
    if (this.difficulty === d) { return; }
    this.difficulty = d;
    this.startGame();
  }

  /** 只铺开局数据，不启动定时器（初始化/单测用） */
  newGame(): void {
    GameDataManager.incrementPlayCount(GAME_ID);
    this.snake = this.rules.initialSnake();
    this.food = this.rules.spawnFood(this.snake, this.rng);
    this.direction = Direction.RIGHT;
    this.pendingTurn = null;
    this.score = 0;
    this.status = GameStatus.PLAYING;
  }

  /** 开局并启动定时器 */
  startGame(): void {
    if (this.score > 0) { GameDataManager.updateHighScore(GAME_ID, this.score); }
    this.newGame();
    this.startTimer();
  }

  startTimer(): void {
    this.stopTimer();
    this.timer = setInterval(() => { this.stepOnce(); }, this.getMoveInterval());
  }

  stopTimer(): void {
    if (this.timer !== -1) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  /** 推进一步。定时器与单测都走这里，测试可绕过定时器手动步进 */
  stepOnce(): void {
    if (this.status !== GameStatus.PLAYING) { return; }
    if (this.pendingTurn !== null) {
      this.direction = this.pendingTurn;
      this.pendingTurn = null;
    }
    const outcome = this.rules.step(this.snake, this.direction, this.food, this.score);
    if (outcome.dead) { this.gameOver(); return; }
    this.snake = outcome.snake;
    this.score = outcome.score;
    if (outcome.ate) {
      this.food = this.rules.spawnFood(this.snake, this.rng);
      // 棋盘占满：无处生成食物，直接结束（原实现如此，避免死循环）
      if (this.food.x < 0) { this.gameOver(); }
    }
  }

  /** 手动暂停/恢复。只在「进行中 ⇄ 暂停」间切换，已结束的对局不会被误切换 */
  togglePause(): void {
    if (this.status === GameStatus.PLAYING) {
      this.status = GameStatus.PAUSED;
    } else if (this.status === GameStatus.PAUSED) {
      this.status = GameStatus.PLAYING;
    }
  }

  turnUp(): void { this.turn(Direction.UP); }
  turnDown(): void { this.turn(Direction.DOWN); }
  turnLeft(): void { this.turn(Direction.LEFT); }
  turnRight(): void { this.turn(Direction.RIGHT); }

  private turn(dir: Direction): void {
    if (this.status !== GameStatus.PLAYING) { return; }
    if (this.pendingTurn !== null) { return; }
    if (!this.rules.turnAllowed(this.direction, dir)) { return; }
    this.pendingTurn = dir;
  }

  isSnakeCell(x: number, y: number): boolean {
    return this.rules.contains(this.snake, x, y);
  }

  isFood(x: number, y: number): boolean {
    return this.food.x === x && this.food.y === y;
  }

  /** 切后台自动暂停：否则蛇会在后台撞墙直到 game over */
  onPageHide(): void {
    if (this.status === GameStatus.PLAYING) {
      this.autoPaused = true;
      this.status = GameStatus.PAUSED;
    }
  }

  onPageShow(): void {
    if (this.autoPaused) {
      this.autoPaused = false;
      this.status = GameStatus.PLAYING;
    }
  }

  private gameOver(): void {
    this.status = GameStatus.OVER;
    this.stopTimer();
    if (this.score > this.highScore) { this.highScore = this.score; }
    GameDataManager.updateHighScore(GAME_ID, this.score);
  }

  dispose(): void {
    this.stopTimer();
  }
}
