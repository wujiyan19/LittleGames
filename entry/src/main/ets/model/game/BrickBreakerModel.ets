/**
 * 打砖块 —— Model 层（纯逻辑，零 ArkUI 依赖）
 *
 * 只有「数据 + 规则」，不引用任何状态管理装饰器 / UI / 持久化，
 * 可脱离 ArkUI 运行时直接单测。规则类无状态，调用方持有状态。
 */
import { RandomSource } from './RandomSource';

/** 砖块布局描述（位置 + 分值），由 Rules 生成，ViewModel 转为渲染数据 */
export class BrickLayout {
  row: number = 0;
  col: number = 0;
  scoreValue: number = 0;

  constructor(row: number, col: number, scoreValue: number) {
    this.row = row;
    this.col = col;
    this.scoreValue = scoreValue;
  }
}

/** 球状态（位置 + 速度），纯数据 */
export class BallState {
  x: number = 0;
  y: number = 0;
  vx: number = 0;
  vy: number = 0;
  radius: number = 6;

  constructor(x: number, y: number, vx: number, vy: number, radius: number) {
    this.x = x;
    this.y = y;
    this.vx = vx;
    this.vy = vy;
    this.radius = radius;
  }
}

/** 一步推进的结果 */
export class BrickStepResult {
  ball: BallState;
  brickHitIndex: number; // -1 表示未击中砖块
  ballLost: boolean;     // 球漏接
  wallBounced: boolean;  // 撞墙反弹

  constructor(ball: BallState, brickHitIndex: number, ballLost: boolean, wallBounced: boolean) {
    this.ball = ball;
    this.brickHitIndex = brickHitIndex;
    this.ballLost = ballLost;
    this.wallBounced = wallBounced;
  }
}

/** 砖块矩形（用于碰撞检测） */
export class BrickRect {
  left: number = 0;
  top: number = 0;
  right: number = 0;
  bottom: number = 0;

  constructor(left: number, top: number, right: number, bottom: number) {
    this.left = left;
    this.top = top;
    this.right = right;
    this.bottom = bottom;
  }
}

/**
 * 打砖块规则。无状态：所有游戏状态由调用方（ViewModel）持有并传入。
 */
export class BrickBreakerRules {
  // 游戏区域尺寸（vp）
  static readonly GAME_WIDTH: number = 320;
  static readonly GAME_HEIGHT: number = 400;

  // 砖块参数
  static readonly BRICK_COLS: number = 8;
  static readonly BRICK_GAP: number = 2;
  static readonly SIDE_PADDING: number = 8;
  static readonly TOP_PADDING: number = 20;
  static readonly BRICK_HEIGHT: number = 16;

  // 挡板参数
  static readonly PADDLE_WIDTH: number = 60;
  static readonly PADDLE_HEIGHT: number = 8;
  static readonly PADDLE_BOTTOM_MARGIN: number = 20;
  static readonly PADDLE_STEP: number = 20;

  // 球参数
  static readonly BALL_RADIUS: number = 6;

  // 球速
  static readonly BASE_SPEED: number = 3;
  static readonly SPEED_INCREMENT: number = 0.5;

  // 每行砖块分值（靠近顶部的行分值更高）
  static readonly ROW_SCORES: number[] = [50, 40, 30, 20, 10, 50, 40, 30];

  /** 计算砖块宽度 */
  brickWidth(): number {
    return (BrickBreakerRules.GAME_WIDTH - 2 * BrickBreakerRules.SIDE_PADDING -
      (BrickBreakerRules.BRICK_COLS - 1) * BrickBreakerRules.BRICK_GAP) /
      BrickBreakerRules.BRICK_COLS;
  }

  /** 计算某行某列砖块的矩形 */
  brickRect(row: number, col: number): BrickRect {
    const bw = this.brickWidth();
    const x = BrickBreakerRules.SIDE_PADDING + col * (bw + BrickBreakerRules.BRICK_GAP);
    const y = BrickBreakerRules.TOP_PADDING + row * (BrickBreakerRules.BRICK_HEIGHT + BrickBreakerRules.BRICK_GAP);
    return new BrickRect(x, y, x + bw, y + BrickBreakerRules.BRICK_HEIGHT);
  }

  /** 挡板 Y 坐标（顶部） */
  paddleY(): number {
    return BrickBreakerRules.GAME_HEIGHT - BrickBreakerRules.PADDLE_HEIGHT -
      BrickBreakerRules.PADDLE_BOTTOM_MARGIN;
  }

  /** 生成砖块布局。关卡越高行数越多（最多 8 行） */
  generateLayout(level: number): BrickLayout[] {
    const rows = Math.min(5 + Math.floor((level - 1) / 2), 8);
    const layouts: BrickLayout[] = [];
    for (let row = 0; row < rows; row++) {
      for (let col = 0; col < BrickBreakerRules.BRICK_COLS; col++) {
        const score = BrickBreakerRules.ROW_SCORES[row % BrickBreakerRules.ROW_SCORES.length];
        layouts.push(new BrickLayout(row, col, score));
      }
    }
    return layouts;
  }

  /** 获取球速（vp/帧），随关卡递增 */
  getBallSpeed(level: number): number {
    return BrickBreakerRules.BASE_SPEED + (level - 1) * BrickBreakerRules.SPEED_INCREMENT;
  }

  /** 生成球的初始状态（位于挡板上方中央，待发） */
  initialBall(paddleCenterX: number, level: number, rng: RandomSource): BallState {
    const speed = this.getBallSpeed(level);
    const dir = rng.next() > 0.5 ? 1 : -1;
    return new BallState(
      paddleCenterX,
      this.paddleY() - BrickBreakerRules.BALL_RADIUS - 2,
      speed * 0.6 * dir,
      -speed * 0.8,
      BrickBreakerRules.BALL_RADIUS
    );
  }

  /** 限制挡板中心在边界内 */
  clampPaddleCenter(centerX: number): number {
    const halfW = BrickBreakerRules.PADDLE_WIDTH / 2;
    if (centerX < halfW) { return halfW; }
    if (centerX > BrickBreakerRules.GAME_WIDTH - halfW) {
      return BrickBreakerRules.GAME_WIDTH - halfW;
    }
    return centerX;
  }

  /**
   * 推进球一步：更新位置 → 检测碰撞 → 返回结果。
   * bricksAlive：与 layouts 同序的布尔数组，表示每块砖是否存活。
   * paddleCenterX：挡板中心 X。
   */
  step(ball: BallState, layouts: BrickLayout[], bricksAlive: boolean[], paddleCenterX: number): BrickStepResult {
    let newBall = new BallState(ball.x + ball.vx, ball.y + ball.vy, ball.vx, ball.vy, ball.radius);
    let wallBounced = false;
    let brickHitIndex = -1;

    // 左右墙碰撞
    if (newBall.x - newBall.radius < 0) {
      newBall.x = newBall.radius;
      newBall.vx = Math.abs(newBall.vx);
      wallBounced = true;
    } else if (newBall.x + newBall.radius > BrickBreakerRules.GAME_WIDTH) {
      newBall.x = BrickBreakerRules.GAME_WIDTH - newBall.radius;
      newBall.vx = -Math.abs(newBall.vx);
      wallBounced = true;
    }

    // 顶部碰撞
    if (newBall.y - newBall.radius < 0) {
      newBall.y = newBall.radius;
      newBall.vy = Math.abs(newBall.vy);
      wallBounced = true;
    }

    // 挡板碰撞
    const pY = this.paddleY();
    const halfW = BrickBreakerRules.PADDLE_WIDTH / 2;
    if (newBall.vy > 0 &&
      newBall.y + newBall.radius >= pY &&
      newBall.y + newBall.radius <= pY + BrickBreakerRules.PADDLE_HEIGHT + 4 &&
      newBall.x >= paddleCenterX - halfW - newBall.radius &&
      newBall.x <= paddleCenterX + halfW + newBall.radius) {
      newBall.y = pY - newBall.radius - 1;
      newBall.vy = -Math.abs(newBall.vy);
      // 根据击中挡板的位置调整水平速度
      const hitOffset = (newBall.x - paddleCenterX) / halfW; // -1 ~ 1
      const speed = Math.sqrt(newBall.vx * newBall.vx + newBall.vy * newBall.vy);
      newBall.vx = speed * 0.6 * hitOffset;
      // 保持总速度大小不变，重新计算 vy
      const newVySq = speed * speed - newBall.vx * newBall.vx;
      if (newVySq > 0) {
        newBall.vy = -Math.sqrt(newVySq);
      } else {
        newBall.vy = -speed * 0.8;
      }
      wallBounced = true;
    }

    // 砖块碰撞（只检测第一个命中的砖块）
    for (let i = 0; i < layouts.length; i++) {
      if (!bricksAlive[i]) { continue; }
      const rect = this.brickRect(layouts[i].row, layouts[i].col);
      if (newBall.x + newBall.radius > rect.left &&
        newBall.x - newBall.radius < rect.right &&
        newBall.y + newBall.radius > rect.top &&
        newBall.y - newBall.radius < rect.bottom) {
        brickHitIndex = i;
        // 判断反弹方向：比较球中心与砖块中心的相对位置
        const brickCenterX = (rect.left + rect.right) / 2;
        const brickCenterY = (rect.top + rect.bottom) / 2;
        const dx = Math.abs(newBall.x - brickCenterX) / (rect.right - rect.left);
        const dy = Math.abs(newBall.y - brickCenterY) / (rect.bottom - rect.top);
        if (dx > dy) {
          newBall.vx = -newBall.vx;
        } else {
          newBall.vy = -newBall.vy;
        }
        break;
      }
    }

    // 漏接检测
    const ballLost = newBall.y - newBall.radius > BrickBreakerRules.GAME_HEIGHT;

    return new BrickStepResult(newBall, brickHitIndex, ballLost, wallBounced);
  }

  /** 检查是否所有砖块都被击碎 */
  allBricksCleared(bricksAlive: boolean[]): boolean {
    for (let i = 0; i < bricksAlive.length; i++) {
      if (bricksAlive[i]) { return false; }
    }
    return true;
  }
}