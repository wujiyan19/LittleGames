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
import { GameLifecycleObserver } from '../common/GameLifecycleBus';
import { Direction, Point, SnakeRules } from '../model/game/SnakeModel';
import { RandomSource, RealRandom } from '../model/game/RandomSource';


const COLS = 20;
const ROWS = 20;
const GAME_ID = 'snake';

@ObservedV2
export class SnakeViewModel implements GameLifecycleObserver {
  /** 渲染所需的对局状态（蛇身/食物用整体替换，触发 @Trace 刷新） */
  @Trace snake: Point[] = [];
  @Trace food: Point = new Point(-1, -1);
  @Trace score: number = 0;
  @Trace highScore: number = 0;
  @Trace status: GameStatus = GameStatus.IDLE;
  @Trace difficulty: GameDifficulty = GameDifficulty.NORMAL;
  /** 退出确认弹窗显隐（F2：对局中返回需确认） */
  @Trace confirmExit: boolean = false;

  private rules: SnakeRules = new SnakeRules(COLS, ROWS);
  private rng: RandomSource;
  /** 蛇身占用集合，随蛇变动重建；供渲染 O(1) 查询。
   *  @Trace：build 函数通过 isSnakeCell() → isOccupied(occupied,...) 间接读取，
   *  若不加 @Trace，蛇移动时 occupied 变化不会被框架检测，界面不刷新。 */
  @Trace private occupied: Set<number> = new Set<number>();
  private direction: Direction = Direction.RIGHT;
  // 方向输入缓冲：每个 tick 只应用一次转向，防止一个 tick 内连按两键造成 180° 反向自杀
  private pendingTurn: Direction | null = null;
  private timer: number = -1;
  /** 本次暂停是否由「切后台」自动触发——决定回到前台时是否需要自动恢复 */
  private autoPaused: boolean = false;
  /** 玩家是否已按过方向键（首次按键才启动定时器） */
  @Trace started: boolean = false;

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
    this.occupied = this.rules.occupancy(this.snake);
    this.food = this.rules.spawnFood(this.snake, this.rng);
    this.direction = Direction.RIGHT;
    this.pendingTurn = null;
    this.score = 0;
    this.status = GameStatus.PLAYING;
    this.started = false;
  }

  /** 开局并启动定时器 */
  startGame(): void {
    if (this.score > 0) { GameDataManager.updateHighScore(GAME_ID, this.score); }
    this.newGame();
    // 不立即启动定时器——等玩家按第一个方向键后再开始移动
    this.started = false;
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
    this.occupied = this.rules.occupancy(this.snake);
    this.score = outcome.score;
    if (outcome.ate) {
      this.food = this.rules.spawnFood(this.snake, this.rng);
      // 棋盘占满：无处生成食物，直接结束（原实现如此，避免死循环）
      if (this.food.x < 0) { this.gameOver(); }
    }
  }

  /**
   * 结算当前对局分数。updateHighScore 为 max 语义，重复调用幂等。
   * 场景：中途退出（dispose）、切后台（onAppHidden）——原先只在对局结束/下次开局时结算，
   * 中途退出会静默丢失当前得分。
   */
  private settleCurrentScore(): void {
    if (this.score > 0) { GameDataManager.updateHighScore(GAME_ID, this.score); }
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
    // 首次按方向键时启动定时器（开局不自动移动，等玩家操作）
    if (!this.started) {
      this.started = true;
      this.startTimer();
    }
  }

  /** 渲染热路径：O(1) 查询占用集合（P2-2） */
  isSnakeCell(x: number, y: number): boolean {
    return this.rules.isOccupied(this.occupied, x, y);
  }

  isSnakeHead(x: number, y: number): boolean {
    return this.snake.length > 0 && this.snake[0].x === x && this.snake[0].y === y;
  }

  isFood(x: number, y: number): boolean {
    return this.food.x === x && this.food.y === y;
  }

  /**
   * 切后台（GameLifecycleBus：UIAbility.onBackground）。
   * 注意：不能依赖页面的 onPageHide()——它仅对 @Entry 组件生效，本应用游戏页是
   * @ComponentV2，该钩子永远不会被调用（切后台自动暂停曾因此整体失效）。
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

  /**
   * 页面返回按钮与系统侧滑共用的退出请求。
   * 进行中 → 置 confirmExit 弹确认并拦截；暂停/已结束 → 放行
   * （暂停与退出路径的分数结算由 dispose()/onAppHidden() 兜底，无需再打扰）。
   */
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
