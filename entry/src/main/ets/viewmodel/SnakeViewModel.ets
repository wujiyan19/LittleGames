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
import { ContinuationValidation as V } from '../common/GameSessionTransfer';
import { GameDataManager } from '../model/GameData';
import { GameLifecycleObserver } from '../common/GameLifecycleBus';
import { Direction, Point, SnakeRules } from '../model/game/SnakeModel';
import { RandomSource, RealRandom } from '../model/game/RandomSource';


const COLS = 20;
const ROWS = 20;
const GAME_ID = 'snake';

/** 每格独立观察，仅改变实际显示有变化的格子。 */
export enum SnakeCellKind { EMPTY, HEAD, BODY, CORNER, TAIL, FOOD }

@ObservedV2
export class SnakeCellData {
  readonly id: number;
  @Trace kind: SnakeCellKind = SnakeCellKind.EMPTY;
  @Trace rotation: number = 0;

  constructor(id: number) { this.id = id; }
}


interface SnakeContinuationState {
  version: number;
  snake: Point[];
  food: Point;
  score: number;
  highScore: number;
  status: GameStatus;
  difficulty: GameDifficulty;
  direction: Direction;
  pendingTurn: Direction | null;
  started: boolean;
}

@ObservedV2
export class SnakeViewModel implements GameLifecycleObserver {
  /** 渲染所需的对局状态（蛇身/食物用整体替换，触发 @Trace 刷新） */
  @Trace snake: Point[] = [];
  @Trace food: Point = new Point(-1, -1);
  @Trace score: number = 0;
  @Trace highScore: number = 0;
  @Trace status: GameStatus = GameStatus.IDLE;
  @Trace difficulty: GameDifficulty = GameDataManager.getInitialDifficulty(GAME_ID);
  /** 退出确认弹窗显隐（F2：对局中返回需确认） */
  @Trace confirmExit: boolean = false;

  private rules: SnakeRules = new SnakeRules(COLS, ROWS);
  private rng: RandomSource;
  private occupied: Set<number> = new Set<number>();
  private direction: Direction = Direction.RIGHT;
  readonly cells: SnakeCellData[] = [];
  private nextKinds: Int8Array = new Int8Array(COLS * ROWS);
  private nextRotations: Int16Array = new Int16Array(COLS * ROWS);
  // 方向输入缓冲：每个 tick 只应用一次转向，防止一个 tick 内连按两键造成 180° 反向自杀
  private pendingTurn: Direction | null = null;
  private timer: number = -1;
  /** 本次暂停是否由「切后台」自动触发——决定回到前台时是否需要自动恢复 */
  private autoPaused: boolean = false;
  private appVisible: boolean = true;
  /** 玩家是否已按过方向键（首次按键才启动定时器） */
  @Trace started: boolean = false;

  constructor(rng?: RandomSource) {
    this.rng = rng ?? new RealRandom();
    for (let i = 0; i < COLS * ROWS; i++) { this.cells.push(new SnakeCellData(i)); }
    this.highScore = GameDataManager.getGameById(GAME_ID)?.highScore ?? 0;
  }

  cols(): number { return COLS; }
  rows(): number { return ROWS; }

  /** 像素蛇头素材默认朝右；只跟随已应用的移动方向，不提前显示缓冲转向。 */
  getHeadRotation(): number {
    if (this.direction === Direction.UP) { return 270; }
    if (this.direction === Direction.DOWN) { return 90; }
    if (this.direction === Direction.LEFT) { return 180; }
    return 0;
  }

  isSnakeTail(x: number, y: number): boolean {
    return this.cells[y * COLS + x].kind === SnakeCellKind.TAIL;
  }

  isSnakeCorner(x: number, y: number): boolean {
    return this.cells[y * COLS + x].kind === SnakeCellKind.CORNER;
  }

  getSnakeRotation(x: number, y: number): number {
    return this.cells[y * COLS + x].rotation;
  }

  private updateCells(): void {
    this.nextKinds.fill(SnakeCellKind.EMPTY);
    this.nextRotations.fill(0);
    if (this.food.x >= 0) { this.nextKinds[this.food.y * COLS + this.food.x] = SnakeCellKind.FOOD; }
    for (let i = 0; i < this.snake.length; i++) {
      const segment: Point = this.snake[i];
      const index: number = segment.y * COLS + segment.x;
      let kind: SnakeCellKind = SnakeCellKind.BODY;
      let rotation: number = 0;
      if (i === 0) {
        kind = SnakeCellKind.HEAD;
        rotation = this.getHeadRotation();
      } else {
        const previous: Point = this.snake[i - 1];
        if (i === this.snake.length - 1) {
          kind = SnakeCellKind.TAIL;
          if (previous.x < segment.x) { rotation = 180; }
          else if (previous.y < segment.y) { rotation = 270; }
          else if (previous.y > segment.y) { rotation = 90; }
        } else {
          const next: Point = this.snake[i + 1];
          if (previous.y === next.y) { rotation = 0; }
          else if (previous.x === next.x) { rotation = 90; }
          else {
            kind = SnakeCellKind.CORNER;
            const left: boolean = previous.x < segment.x || next.x < segment.x;
            const down: boolean = previous.y > segment.y || next.y > segment.y;
            if (left && down) { rotation = 0; }
            else if (left) { rotation = 90; }
            else if (down) { rotation = 270; }
            else { rotation = 180; }
          }
        }
      }
      this.nextKinds[index] = kind;
      this.nextRotations[index] = rotation;
    }
    for (let i = 0; i < this.cells.length; i++) {
      const cell: SnakeCellData = this.cells[i];
      const kind: SnakeCellKind = this.nextKinds[i] as SnakeCellKind;
      if (cell.kind !== kind) { cell.kind = kind; }
      if (cell.rotation !== this.nextRotations[i]) { cell.rotation = this.nextRotations[i]; }
    }
  }

  getMoveInterval(): number {
    if (this.difficulty === GameDifficulty.EASY) { return 240; }
    if (this.difficulty === GameDifficulty.HARD) { return 120; }
    return 180;
  }

  changeDifficulty(d: GameDifficulty): void {
    GameDataManager.rememberGameDifficulty(GAME_ID, d);
    if (this.difficulty === d) { return; }
    this.difficulty = d;
    this.startGame();
  }

  /** 只铺开局数据，不启动定时器（初始化/单测用） */
  newGame(): void {
    this.stopTimer();
    this.autoPaused = false;
    this.confirmExit = false;
    GameDataManager.incrementPlayCount(GAME_ID);
    this.snake = this.rules.initialSnake();
    this.occupied = this.rules.occupancy(this.snake);
    this.food = this.rules.spawnFoodFromOccupancy(this.occupied, this.rng);
    this.direction = Direction.RIGHT;
    this.pendingTurn = null;
    this.score = 0;
    this.status = GameStatus.PLAYING;
    this.started = false;
    this.updateCells();
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
    if (!this.appVisible || this.confirmExit || this.status !== GameStatus.PLAYING || !this.started) { return; }
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
    if (this.status !== GameStatus.PLAYING || !this.appVisible || this.confirmExit) { return; }
    if (this.pendingTurn !== null) {
      this.direction = this.pendingTurn;
      this.pendingTurn = null;
    }
    const outcome = this.rules.step(this.snake, this.direction, this.food, this.score);
    if (outcome.dead) { this.gameOver(); return; }
    const oldTail: Point = this.snake[this.snake.length - 1];
    if (!outcome.ate) { this.occupied.delete(oldTail.y * COLS + oldTail.x); }
    this.snake = outcome.snake;
    this.occupied.add(this.snake[0].y * COLS + this.snake[0].x);
    this.score = outcome.score;
    if (outcome.ate) {
      this.food = this.rules.spawnFoodFromOccupancy(this.occupied, this.rng);
      // 棋盘占满：无处生成食物，直接结束（原实现如此，避免死循环）
      if (this.food.x < 0) { this.gameOver(); }
    }
    this.updateCells();
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
      this.stopTimer();
    } else if (this.status === GameStatus.PAUSED && this.appVisible && !this.confirmExit) {
      this.status = GameStatus.PLAYING;
      this.startTimer();
    }
  }

  turnUp(): void { this.turn(Direction.UP); }
  turnDown(): void { this.turn(Direction.DOWN); }
  turnLeft(): void { this.turn(Direction.LEFT); }
  turnRight(): void { this.turn(Direction.RIGHT); }

  private turn(dir: Direction): void {
    if (this.status !== GameStatus.PLAYING || !this.appVisible || this.confirmExit) { return; }
    if (!this.started && dir === this.direction) {
      this.started = true;
      this.startTimer();
      return;
    }
    if (this.pendingTurn !== null) { return; }
    if (!this.rules.turnAllowed(this.direction, dir)) { return; }
    this.pendingTurn = dir;
    // 首次按方向键时启动定时器（开局不自动移动，等玩家操作）
    if (!this.started) {
      this.started = true;
      this.startTimer();
    }
  }

  /** 渲染热路径：只订阅当前格的外观，不订阅整条蛇或占用集合。 */
  isSnakeCell(x: number, y: number): boolean {
    const kind: SnakeCellKind = this.cells[y * COLS + x].kind;
    return kind !== SnakeCellKind.EMPTY && kind !== SnakeCellKind.FOOD;
  }

  isSnakeHead(x: number, y: number): boolean {
    return this.cells[y * COLS + x].kind === SnakeCellKind.HEAD;
  }

  isFood(x: number, y: number): boolean {
    return this.cells[y * COLS + x].kind === SnakeCellKind.FOOD;
  }

  /**
   * 切后台（GameLifecycleBus：UIAbility.onBackground）。
   * 注意：不能依赖页面的 onPageHide()——它仅对 @Entry 组件生效，本应用游戏页是
   * @ComponentV2，该钩子永远不会被调用（切后台自动暂停曾因此整体失效）。
   */
  onAppHidden(): void {
    this.appVisible = false;
    this.stopTimer();
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
      this.startTimer();
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
    if (!GameDataManager.getSetting('confirmExitEnabled', true)) { return false; }
    if (this.status === GameStatus.PLAYING) {
      this.confirmExit = true;
      this.stopTimer();
      return true;
    }
    return false;
  }

  dismissExitConfirm(): void {
    this.confirmExit = false;
    this.startTimer();
  }

  private gameOver(): void {

    this.status = GameStatus.OVER;
    this.stopTimer();
    if (this.score > this.highScore) { this.highScore = this.score; }
    GameDataManager.updateHighScore(GAME_ID, this.score);
  }

  /** 页面销毁：停定时器并结算当前分（覆盖「中途退出丢分」主路径） */
  dispose(): void {
    this.appVisible = false;
    this.autoPaused = false;
    this.stopTimer();
    this.settleCurrentScore();
  }

  continuationGameId(): string { return GAME_ID; }

  /** Capture only game data; exporting never pauses or mutates the source game. */
  exportContinuation(): string {

    const state: SnakeContinuationState = {
      version: 1,
      snake: this.snake,
      food: this.food,
      score: this.score,
      highScore: this.highScore,
      status: this.status,
      difficulty: this.difficulty,
      direction: this.direction,
      pendingTurn: this.pendingTurn,
      started: this.started
    };
    return JSON.stringify(state);
  }

  /** Validate completely before replacing a running game. Rebuild observed class instances. */
  importContinuation(payload: string): boolean {
    try {
      if (payload.length > 65536) { return false; }
      const s: SnakeContinuationState = JSON.parse(payload) as SnakeContinuationState;
      if (s === null || s.version !== 1 || !V.integer(s.score) ||
          !V.integer(s.highScore) ||
          (s.status !== GameStatus.PLAYING && s.status !== GameStatus.PAUSED && s.status !== GameStatus.OVER && s.status !== GameStatus.IDLE) ||
          (s.difficulty !== GameDifficulty.EASY && s.difficulty !== GameDifficulty.NORMAL && s.difficulty !== GameDifficulty.HARD) ||
          typeof s.started !== 'boolean') { return false; }
      if (!Array.isArray(s.snake) || s.snake.length < 1 || s.snake.length > COLS * ROWS ||
          !V.integer(s.direction, 0, 3) || (s.pendingTurn !== null && !V.integer(s.pendingTurn, 0, 3))) { return false; }
      const occupied: Set<number> = new Set<number>();
      for (let i = 0; i < s.snake.length; i++) {
        const p: Point = s.snake[i];
        if (p === null || !V.integer(p.x, 0, COLS - 1) || !V.integer(p.y, 0, ROWS - 1)) { return false; }
        occupied.add(p.y * COLS + p.x);
      }
      if (occupied.size !== s.snake.length || s.food === null || !V.integer(s.food.x, -1, COLS - 1) ||
          !V.integer(s.food.y, -1, ROWS - 1)) { return false; }
      this.stopTimer();
      this.snake = s.snake;
      this.food = s.food;
      this.score = s.score;
      this.highScore = Math.max(s.highScore, GameDataManager.getGameById(GAME_ID)?.highScore ?? 0);
      GameDataManager.updateHighScore(GAME_ID, this.highScore);
      this.status = s.status;
      this.difficulty = s.difficulty;
      this.direction = s.direction;
      this.pendingTurn = s.pendingTurn;
      this.started = s.started;
      this.confirmExit = false;
      this.snake = s.snake.map((p: Point): Point => new Point(p.x, p.y));
      this.food = new Point(s.food.x, s.food.y);
      this.occupied = this.rules.occupancy(this.snake);
      this.appVisible = true;
      this.autoPaused = false;
      if (this.status === GameStatus.PLAYING && this.started) { this.status = GameStatus.PAUSED; }
      this.updateCells();
      return true;
    } catch (e) {
      return false;
    }
  }
}
