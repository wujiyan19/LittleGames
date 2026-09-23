/**
 * 打砖块 —— ViewModel 层
 *
 * 持有并暴露 UI 状态（@ObservedV2 + @Trace），编排「规则(Model) + 计时 + 持久化」。
 * View 只与它交互，不接触 Model 类型。
 *
 * 可测性：随机源可注入；stepOnce() 可脱离定时器手动推进。
 */
import { GameStatus } from '../common/GameConstants';
import { GameDataManager } from '../model/GameData';
import { GameLifecycleObserver } from '../common/GameLifecycleBus';
import { RandomSource, RealRandom } from '../model/game/RandomSource';
import { BrickBreakerRules, BrickLayout, BallState } from '../model/game/BrickBreakerModel';

const GAME_ID = 'brickbreaker';
const TIMER_INTERVAL = 30; // ms，约33fps

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
  private timer: number = -1;
  private autoPaused: boolean = false;

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

  /** 开局并启动定时器 */
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
    this.ball = this.rules.initialBall(this.paddleCenterX, this.level, this.rng);
    this.ballX = this.ball.x;
    this.ballY = this.ball.y;
    this.started = false;
  }

  startTimer(): void {
    this.stopTimer();
    this.timer = setInterval(() => { this.stepOnce(); }, TIMER_INTERVAL);
  }

  stopTimer(): void {
    if (this.timer !== -1) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  /** 推进一步。定时器与单测都走这里 */
  stepOnce(): void {
    if (this.status !== GameStatus.PLAYING || !this.started) { return; }

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
    this.level += 1;
    this.levelClearMsg = true;
    this.status = GameStatus.PAUSED;
    // 2秒后自动进入下一关
    setTimeout(() => {
      this.levelClearMsg = false;
      this.status = GameStatus.PLAYING;
      this.initLevel();
    }, 2000);
  }

  /** 拖动挡板：centerX 为手指当前 X 位置（vp） */
  dragPaddle(centerX: number): void {
    this.paddleCenterX = this.rules.clampPaddleCenter(centerX);
    // 球未发射时跟随挡板
    if (!this.started && this.status === GameStatus.PLAYING) {
      this.ball.x = this.paddleCenterX;
      this.ballX = this.ball.x;
    }
  }

  /** 左按钮：挡板左移一个步长 */
  movePaddleLeft(): void {
    this.paddleCenterX = this.rules.clampPaddleCenter(this.paddleCenterX - BrickBreakerRules.PADDLE_STEP);
    if (!this.started && this.status === GameStatus.PLAYING) {
      this.ball.x = this.paddleCenterX;
      this.ballX = this.ball.x;
    }
  }

  /** 右按钮：挡板右移一个步长 */
  movePaddleRight(): void {
    this.paddleCenterX = this.rules.clampPaddleCenter(this.paddleCenterX + BrickBreakerRules.PADDLE_STEP);
    if (!this.started && this.status === GameStatus.PLAYING) {
      this.ball.x = this.paddleCenterX;
      this.ballX = this.ball.x;
    }
  }

  /** 发射球（首次操作触发） */
  launchBall(): void {
    if (!this.started && this.status === GameStatus.PLAYING) {
      this.started = true;
      this.startTimer();
    }
  }

  /** 手动暂停/恢复 */
  togglePause(): void {
    if (this.status === GameStatus.PLAYING) {
      this.status = GameStatus.PAUSED;
    } else if (this.status === GameStatus.PAUSED && !this.levelClearMsg) {
      this.status = GameStatus.PLAYING;
    }
  }

  private settleCurrentScore(): void {
    if (this.score > 0) { GameDataManager.updateHighScore(GAME_ID, this.score); }
  }

  private gameOver(): void {
    this.status = GameStatus.OVER;
    this.stopTimer();
    if (this.score > this.highScore) { this.highScore = this.score; }
    GameDataManager.updateHighScore(GAME_ID, this.score);
  }

  // GameLifecycleObserver 实现

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

  onBackRequested(): boolean {
    return this.requestBack();
  }

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

  dispose(): void {
    this.stopTimer();
    this.settleCurrentScore();
  }
}