/**
 * 贪吃蛇 —— Model 层（纯逻辑，零 ArkUI 依赖）
 *
 * 这里只有「数据 + 规则」，不引用任何状态管理装饰器 / UI / 持久化，
 * 因此可以脱离 ArkUI 运行时直接单测。
 * 规则类设计为无状态（除棋盘尺寸外），调用方持有状态，便于断言与回放。
 */

export enum Direction { UP, DOWN, LEFT, RIGHT }

export class Point {
  x: number;
  y: number;

  constructor(x: number, y: number) {
    this.x = x;
    this.y = y;
  }
}

/** 随机源抽象：生产用 RealRandom，测试注入 SeededRandom 以获得确定性 */
export interface RandomSource {
  next(): number;
}

export class RealRandom implements RandomSource {
  next(): number {
    return Math.random();
  }
}

export class SeededRandom implements RandomSource {
  private seed: number;

  constructor(seed: number) {
    this.seed = seed;
  }

  next(): number {
    // 线性同余，够测试用；不追求统计质量
    this.seed = (this.seed * 1103515245 + 12345) % 2147483648;
    return this.seed / 2147483648;
  }
}

/** 一步推进的结果（纯数据，不引用外部状态） */
export class StepOutcome {
  snake: Point[];
  score: number;
  ate: boolean;
  dead: boolean;

  constructor(snake: Point[], score: number, ate: boolean, dead: boolean) {
    this.snake = snake;
    this.score = score;
    this.ate = ate;
    this.dead = dead;
  }
}

/**
 * 贪吃蛇规则。无状态：所有游戏状态由调用方（ViewModel）持有并传入。
 */
export class SnakeRules {
  private readonly cols: number;
  private readonly rows: number;

  constructor(cols: number, rows: number) {
    this.cols = cols;
    this.rows = rows;
  }

  /** 开局蛇身：位于棋盘正中，长度 1 */
  initialSnake(): Point[] {
    return [new Point(Math.floor(this.cols / 2), Math.floor(this.rows / 2))];
  }

  /** 转向是否合法：不能原地不变、不能 180° 反向 */
  turnAllowed(current: Direction, next: Direction): boolean {
    if (next === current) { return false; }
    const opposite = (current === Direction.UP && next === Direction.DOWN) ||
                     (current === Direction.DOWN && next === Direction.UP) ||
                     (current === Direction.LEFT && next === Direction.RIGHT) ||
                     (current === Direction.RIGHT && next === Direction.LEFT);
    return !opposite;
  }

  /**
   * 沿 dir 前进一步。
   * - 撞墙 / 撞自身（未吃食物时尾格会让位，不计入）→ dead
   * - 吃到食物 → ate 且分数 +10
   */
  step(snake: Point[], dir: Direction, food: Point, score: number): StepOutcome {
    const head = snake[0];
    let hx = head.x;
    let hy = head.y;
    if (dir === Direction.UP) { hy -= 1; }
    else if (dir === Direction.DOWN) { hy += 1; }
    else if (dir === Direction.LEFT) { hx -= 1; }
    else { hx += 1; }

    if (hx < 0 || hx >= this.cols || hy < 0 || hy >= this.rows) {
      return new StepOutcome(snake, score, false, true);
    }

    const willEat = hx === food.x && hy === food.y;
    // 未吃到食物时蛇尾同步前移让出格子，因此尾格不算碰撞
    const checkLen = willEat ? snake.length : snake.length - 1;
    for (let i = 0; i < checkLen; i++) {
      if (snake[i].x === hx && snake[i].y === hy) {
        return new StepOutcome(snake, score, false, true);
      }
    }

    const next: Point[] = [new Point(hx, hy)];
    for (let i = 0; i < snake.length; i++) { next.push(snake[i]); }
    if (!willEat) { next.pop(); }
    return new StepOutcome(next, willEat ? score + 10 : score, willEat, false);
  }

  /** 在空格中随机生成食物；棋盘被占满时返回 (-1,-1) 表示无处可生成 */
  spawnFood(snake: Point[], rng: RandomSource): Point {
    const empties: Point[] = [];
    for (let x = 0; x < this.cols; x++) {
      for (let y = 0; y < this.rows; y++) {
        if (!this.contains(snake, x, y)) {
          empties.push(new Point(x, y));
        }
      }
    }
    if (empties.length === 0) { return new Point(-1, -1); }
    const idx = Math.floor(rng.next() * empties.length);
    return empties[idx];
  }

  contains(snake: Point[], x: number, y: number): boolean {
    for (let i = 0; i < snake.length; i++) {
      if (snake[i].x === x && snake[i].y === y) { return true; }
    }
    return false;
  }
}
