/**
 * 打砖块 —— ViewModel 层
 *
 * 持有并暴露 UI 状态（@ObservedV2 + @Trace），编排「规则(Model) + 计时 + 持久化」。
 * View 只与它交互，不接触 Model 类型。
 *
 * 可测性：随机源可注入；stepOnce() 可脱离定时器手动推进。
 */
import { GameStatus } from '../common/GameConstants';
import { ContinuationValidation as V } from '../common/GameSessionTransfer';
import { GameDataManager } from '../model/GameData';
import { GameLifecycleObserver } from '../common/GameLifecycleBus';
import { RandomSource, RealRandom } from '../model/game/RandomSource';
import { BrickBreakerRules, BrickLayout, BallState } from '../model/game/BrickBreakerModel';
import { FrameLoop } from '../common/FrameLoop';

const GAME_ID = 'brickbreaker';
const PHYSICS_STEP_MS = 30; // 保留原球速与物理步长，显示位置按帧插值。

/** 砖块渲染数据。@ObservedV2 + @Trace alive：击碎时原地改 alive 即触发 UI 更新 */
@ObservedV2
export class BrickViewData {
  readonly id: number;
  readonly row: number;
  readonly col: number;
  readonly scoreValue: number;
  @Trace alive: boolean;

  constructor(id: number, row: number, col: number, scoreValue: number, alive: boolean) {
    this.id = id;
    this.row = row;
    this.col = col;
    this.scoreValue = scoreValue;
    this.alive = alive;
  }
}


interface BrickBreakerContinuationState {
  version: number;
  score: number;
  highScore: number;
  lives: number;
  level: number;
  status: GameStatus;
  ball: BallState;
  layouts: BrickLayout[];
  bricksAlive: boolean[];
  paddleCenterX: number;
  started: boolean;
  levelClearMsg: boolean;
}

@ObservedV2
export class BrickBreakerViewModel implements GameLifecycleObserver {
  @Trace score: number = 0;
  @Trace highScore: number = 0;
  @Trace lives: number = 3;
  @Trace level: number = 1;
  @Trace status: GameStatus = GameStatus.IDLE;
  @Trace confirmExit: boolean = false;
  @Trace bricks: BrickViewData[] = [];
  @Trace ballX: number = 0;
  @Trace ballY: number = 0;
  @Trace paddleCenterX: number = 0;
  @Trace started: boolean = false;
  @Trace levelClearMsg: boolean = false;

  private rules: BrickBreakerRules = new BrickBreakerRules();
  private rng: RandomSource;
  private ball: BallState = new BallState(0, 0, 0, 0, BrickBreakerRules.BALL_RADIUS);
  private layouts: BrickLayout[] = [];
  private bricksAlive: boolean[] = [];
  private frames: FrameLoop | null = null;
  private accumulator: number = 0;
  private previousBallX: number = 0;
  private previousBallY: number = 0;
  private appVisible: boolean = true;
  private autoPaused: boolean = false;
  private levelTransitionTimer: number = -1;
  private levelTransitionGeneration: number = 0;

  constructor(rng?: RandomSource) {
    this.rng = rng ?? new RealRandom();
    this.highScore = GameDataManager.getGameById(GAME_ID)?.highScore ?? 0;
    this.paddleCenterX = BrickBreakerRules.GAME_WIDTH / 2;
  }

  gameWidth(): number { return BrickBreakerRules.GAME_WIDTH; }
  gameHeight(): number { return BrickBreakerRules.GAME_HEIGHT; }
  paddleWidth(): number { return BrickBreakerRules.PADDLE_WIDTH; }
  paddleHeight(): number { return BrickBreakerRules.PADDLE_HEIGHT; }
  ballRadius(): number { return BrickBreakerRules.BALL_RADIUS; }
  brickHeight(): number { return BrickBreakerRules.BRICK_HEIGHT; }
  brickGap(): number { return BrickBreakerRules.BRICK_GAP; }
  sidePadding(): number { return BrickBreakerRules.SIDE_PADDING; }
  topPadding(): number { return BrickBreakerRules.TOP_PADDING; }
  paddleStep(): number { return BrickBreakerRules.PADDLE_STEP; }
  brickWidth(): number { return this.rules.brickWidth(); }
  paddleY(): number { return this.rules.paddleY(); }

  /** 只铺开局数据，不启动定时器 */
  newGame(): void {
    this.cancelLevelTransition();
    this.stopTimer();
    this.autoPaused = false;
    GameDataManager.incrementPlayCount(GAME_ID);
    this.score = 0;
    this.lives = 3;
    this.level = 1;
    this.status = GameStatus.PLAYING;
    this.started = false;
    this.levelClearMsg = false;
    this.confirmExit = false;
    this.paddleCenterX = BrickBreakerRules.GAME_WIDTH / 2;
    this.initLevel();
  }

  /** 开局，等待玩家发射后才启动帧循环 */
  startGame(): void {
    if (this.score > 0) { GameDataManager.updateHighScore(GAME_ID, this.score); }
    this.newGame();
  }

  /** 初始化某一关的砖块和球 */
  private initLevel(): void {
    this.layouts = this.rules.generateLayout(this.level);
    this.bricksAlive = [];
    const newBricks: BrickViewData[] = [];
    for (let i = 0; i < this.layouts.length; i++) {
      this.bricksAlive.push(true);
      const layout = this.layouts[i];
      newBricks.push(new BrickViewData(i, layout.row, layout.col, layout.scoreValue, true));
    }
    this.bricks = newBricks;
    this.resetBall();
  }

  /** 重置球到挡板上方待发位置 */
  private resetBall(): void {
    this.stopTimer();
    this.ball = this.rules.initialBall(this.paddleCenterX, this.level, this.rng);
    this.ballX = this.ball.x;
    this.ballY = this.ball.y;
    this.started = false;
    this.accumulator = 0;
    this.previousBallX = this.ball.x;
    this.previousBallY = this.ball.y;
  }

  setFrameLoop(frames: FrameLoop): void {
    this.frames?.dispose();
    this.frames = frames;
  }

  startTimer(): void {
    if (!this.appVisible || this.confirmExit || this.status !== GameStatus.PLAYING || !this.started) { return; }
    this.frames?.start((deltaMs: number) => { this.advanceFrame(deltaMs); });
  }

  stopTimer(): void {
    this.frames?.stop();
  }

  /** 最多补三步，避免长卡顿后在 UI 线程追赶数百步；显示与物理速度解耦。 */
  advanceFrame(deltaMs: number): void {
    if (!this.appVisible || this.confirmExit || this.status !== GameStatus.PLAYING || !this.started) { return; }
    this.accumulator += Math.min(Math.max(deltaMs, 0), PHYSICS_STEP_MS * 3);
    while (this.accumulator >= PHYSICS_STEP_MS) {
      this.accumulator -= PHYSICS_STEP_MS;
      this.previousBallX = this.ball.x;
      this.previousBallY = this.ball.y;
      this.stepOnce();
      if (!this.started || this.status !== GameStatus.PLAYING) { return; }
    }
    const alpha: number = this.accumulator / PHYSICS_STEP_MS;
    this.ballX = this.previousBallX + (this.ball.x - this.previousBallX) * alpha;
    this.ballY = this.previousBallY + (this.ball.y - this.previousBallY) * alpha;
  }

  /** 推进一步。定时器与单测都走这里 */
  stepOnce(): void {
    if (!this.appVisible || this.confirmExit || this.status !== GameStatus.PLAYING || !this.started) { return; }

    const result = this.rules.step(this.ball, this.layouts, this.bricksAlive, this.paddleCenterX);
    this.ball = result.ball;
    this.ballX = this.ball.x;
    this.ballY = this.ball.y;

    if (result.brickHitIndex >= 0) {
      this.bricksAlive[result.brickHitIndex] = false;
      // 原地修改 BrickViewData.alive，触发 @Trace 更新
      this.bricks[result.brickHitIndex].alive = false;
      this.score += this.layouts[result.brickHitIndex].scoreValue;
      if (this.score > this.highScore) {
        this.highScore = this.score;
      }
      // 检查通关
      if (this.rules.allBricksCleared(this.bricksAlive)) {
        this.nextLevel();
        return;
      }
    }

    if (result.ballLost) {
      this.lives -= 1;
      if (this.lives <= 0) {
        this.gameOver();
      } else {
        this.resetBall();
      }
    }
  }

  /** 进入下一关 */
  private nextLevel(): void {
    this.stopTimer();
    this.level += 1;
    this.levelClearMsg = true;
    this.status = GameStatus.PAUSED;
    this.scheduleLevelTransition();
  }

  private cancelLevelTransition(): void {
    this.levelTransitionGeneration++;
    if (this.levelTransitionTimer !== -1) {
      clearTimeout(this.levelTransitionTimer);
      this.levelTransitionTimer = -1;
    }
  }

  private scheduleLevelTransition(): void {
    this.cancelLevelTransition();
    const generation: number = this.levelTransitionGeneration;
    this.levelTransitionTimer = setTimeout(() => {
      if (generation !== this.levelTransitionGeneration || !this.levelClearMsg ||
        this.status !== GameStatus.PAUSED || this.autoPaused) {
        return;
      }
      this.levelTransitionTimer = -1;
      this.levelClearMsg = false;
      this.status = GameStatus.PLAYING;
      this.initLevel();
    }, 2000);
  }

  /** 拖动挡板：centerX 为手指当前 X 位置（vp） */
  dragPaddle(centerX: number): void {
    if (!this.appVisible || this.confirmExit || this.status !== GameStatus.PLAYING) { return; }
    this.paddleCenterX = this.rules.clampPaddleCenter(centerX);
    // 球未发射时跟随挡板
    if (!this.started && this.status === GameStatus.PLAYING) {
      this.ball.x = this.paddleCenterX;
      this.ballX = this.ball.x;
    }
  }

  /** 左按钮：挡板左移一个步长 */
  movePaddleLeft(): void {
    if (!this.appVisible || this.confirmExit || this.status !== GameStatus.PLAYING) { return; }
    this.paddleCenterX = this.rules.clampPaddleCenter(this.paddleCenterX - BrickBreakerRules.PADDLE_STEP);
    if (!this.started && this.status === GameStatus.PLAYING) {
      this.ball.x = this.paddleCenterX;
      this.ballX = this.ball.x;
    }
  }

  /** 右按钮：挡板右移一个步长 */
  movePaddleRight(): void {
    if (!this.appVisible || this.confirmExit || this.status !== GameStatus.PLAYING) { return; }
    this.paddleCenterX = this.rules.clampPaddleCenter(this.paddleCenterX + BrickBreakerRules.PADDLE_STEP);
    if (!this.started) {
      this.ball.x = this.paddleCenterX;
      this.ballX = this.ball.x;
    }
  }

  /** 发射球（首次操作触发） */
  launchBall(): void {
    if (!this.started && this.appVisible && !this.confirmExit && this.status === GameStatus.PLAYING) {
      this.previousBallX = this.ball.x;
      this.previousBallY = this.ball.y;
      this.accumulator = 0;
      this.started = true;
      this.startTimer();
    }
  }

  /** 手动暂停/恢复 */
  togglePause(): void {
    if (this.status === GameStatus.PLAYING) {
      this.status = GameStatus.PAUSED;
      this.stopTimer();
    } else if (this.status === GameStatus.PAUSED && !this.levelClearMsg && this.appVisible && !this.confirmExit) {
      this.status = GameStatus.PLAYING;
      this.startTimer();
    }
  }

  private settleCurrentScore(): void {
    if (this.score > 0) { GameDataManager.updateHighScore(GAME_ID, this.score); }
  }

  private gameOver(): void {
    this.cancelLevelTransition();
    this.status = GameStatus.OVER;
    this.stopTimer();
    if (this.score > this.highScore) { this.highScore = this.score; }
    GameDataManager.updateHighScore(GAME_ID, this.score);
  }

  // GameLifecycleObserver 实现

  onAppHidden(): void {
    this.appVisible = false;
    this.stopTimer();
    this.settleCurrentScore();
    if (this.levelClearMsg) {
      this.cancelLevelTransition();
      this.autoPaused = true;
    } else if (this.status === GameStatus.PLAYING) {
      this.autoPaused = true;
      this.status = GameStatus.PAUSED;
    }
  }

  onAppShown(): void {
    this.appVisible = true;
    if (this.autoPaused) {
      this.autoPaused = false;
      if (this.levelClearMsg) {
        this.scheduleLevelTransition();
      } else if (this.status === GameStatus.PAUSED) {
        this.status = GameStatus.PLAYING;
        this.startTimer();
      }
    }
  }

  onBackRequested(): boolean {
    return this.requestBack();
  }

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

  dispose(): void {
    this.appVisible = false;
    this.cancelLevelTransition();
    this.stopTimer();
    this.frames?.dispose();
    this.frames = null;
    this.settleCurrentScore();
  }

  continuationGameId(): string { return GAME_ID; }

  /** Capture only game data; exporting never pauses or mutates the source game. */
  exportContinuation(): string {

    const state: BrickBreakerContinuationState = {
      version: 1,
      score: this.score,
      highScore: this.highScore,
      lives: this.lives,
      level: this.level,
      status: this.status,
      ball: this.ball,
      layouts: this.layouts,
      bricksAlive: this.bricksAlive,
      paddleCenterX: this.paddleCenterX,
      started: this.started,
      levelClearMsg: this.levelClearMsg
    };
    return JSON.stringify(state);
  }

  /** Validate completely before replacing a running game. Rebuild observed class instances. */
  importContinuation(payload: string): boolean {
    try {
      if (payload.length > 65536) { return false; }
      const s: BrickBreakerContinuationState = JSON.parse(payload) as BrickBreakerContinuationState;
      if (s === null || s.version !== 1 || !V.integer(s.score) ||
          !V.integer(s.highScore) ||
          !V.integer(s.lives) ||
          !V.integer(s.level) ||
          (s.status !== GameStatus.PLAYING && s.status !== GameStatus.PAUSED && s.status !== GameStatus.OVER && s.status !== GameStatus.IDLE) ||
          !V.finite(s.paddleCenterX) ||
          typeof s.started !== 'boolean' ||
          typeof s.levelClearMsg !== 'boolean') { return false; }
      if (s.level < 1 || s.lives > 3 || !Array.isArray(s.layouts) || s.layouts.length < 1 || s.layouts.length > 100 ||
          !V.booleans(s.bricksAlive, s.layouts.length) || s.ball === null ||
          !V.finite(s.ball.x) || !V.finite(s.ball.y) || !V.finite(s.ball.vx) || !V.finite(s.ball.vy) ||
          s.ball.radius !== BrickBreakerRules.BALL_RADIUS || !V.finite(s.paddleCenterX)) { return false; }
      for (let i = 0; i < s.layouts.length; i++) {
        const b: BrickLayout = s.layouts[i];
        if (b === null || !V.integer(b.row, 0, 20) || !V.integer(b.col, 0, 20) || !V.integer(b.scoreValue)) { return false; }
      }
      this.stopTimer();
      this.cancelLevelTransition();
      this.score = s.score;
      this.highScore = Math.max(s.highScore, GameDataManager.getGameById(GAME_ID)?.highScore ?? 0);
      GameDataManager.updateHighScore(GAME_ID, this.highScore);
      this.lives = s.lives;
      this.level = s.level;
      this.status = s.status;
      this.ball = s.ball;
      this.layouts = s.layouts;
      this.bricksAlive = s.bricksAlive;
      this.paddleCenterX = s.paddleCenterX;
      this.started = s.started;
      this.levelClearMsg = s.levelClearMsg;
      this.confirmExit = false;
      this.ball = new BallState(s.ball.x, s.ball.y, s.ball.vx, s.ball.vy, s.ball.radius);
      this.layouts = s.layouts.map((b: BrickLayout): BrickLayout => new BrickLayout(b.row, b.col, b.scoreValue));
      this.bricks = this.layouts.map((b: BrickLayout, i: number): BrickViewData => new BrickViewData(i, b.row, b.col, b.scoreValue, s.bricksAlive[i]));
      this.ballX = this.ball.x;
      this.ballY = this.ball.y;
      this.previousBallX = this.ball.x;
      this.previousBallY = this.ball.y;
      this.accumulator = 0;
      this.appVisible = true;
      this.autoPaused = false;
      if (this.levelClearMsg) { this.scheduleLevelTransition(); }
      else if (this.status === GameStatus.PLAYING && this.started) { this.status = GameStatus.PAUSED; }
      return true;
    } catch (e) {
      return false;
    }
  }
}
