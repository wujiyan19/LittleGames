/**
 * 贪吃蛇 - HarmonyOS 设计风格
 */
import { display } from '@kit.ArkUI';
import { SemanticColors, RadiusTokens, FontTokens, ShadowTokens, SpacingTokens } from '../../common/DesignTokens';
import { GameHeader } from '../../components/GameHeader';
import { ControlPad } from '../../components/ControlPad';
import { GameResultDialog } from '../../components/GameResultDialog';
import { GameDifficulty } from '../../common/GameConstants';
import { GameDataManager } from '../../model/GameData';
import { SafeAreaInsets } from '../../common/SafeAreaInsets';

const COLS = 20;
const ROWS = 20;

enum Direction { UP, DOWN, LEFT, RIGHT }
interface Point { x: number; y: number }

@ComponentV2
export struct SnakeGamePage {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local safeBottom: number = SafeAreaInsets.bottom;
  @Local snake: Point[] = [{ x: 10, y: 10 }];
  @Local food: Point = { x: 15, y: 10 };
  @Local snakeDirection: Direction = Direction.RIGHT;
  @Local score: number = 0;
  @Local highScore: number = 0;
  @Local isPlaying: boolean = true;
  @Local isPaused: boolean = false;
  @Local cell: number = 16;
  @Local difficulty: GameDifficulty = GameDifficulty.NORMAL;
  private timer: number = -1;
  /** 本次暂停是否由「切后台」自动触发——决定回到前台时是否需要自动恢复 */
  private autoPaused: boolean = false;
  // 方向输入缓冲：每个 tick 只应用一次转向，防止一个 tick 内连按两键造成 180° 反向自杀
  private pendingTurn: Direction | null = null;
  private idx20: number[] = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19];

  aboutToAppear(): void {
    this.highScore = GameDataManager.getGameById('snake')?.highScore ?? 0;
    this.initCellSize();
    this.startGame();
  }
  aboutToDisappear(): void { clearInterval(this.timer); }

  /**
   * 切后台自动暂停。
   * 定时回调里已有 isPaused 守卫，这里只需置位即可停住蛇；
   * 否则蛇会在后台一路撞墙直到 game over，用户切回来第一眼就是「游戏结束」。
   * 注意只处理「正在游戏中」的情况：用户手动暂停或已结束时不动，避免回前台被强行恢复。
   */
  onPageHide(): void {
    if (this.isPlaying && !this.isPaused) {
      this.autoPaused = true;
      this.isPaused = true;
    }
  }

  onPageShow(): void {
    if (this.autoPaused) {
      this.autoPaused = false;
      this.isPaused = false;
    }
  }

  initCellSize(): void {
    const d = display.getDefaultDisplaySync();
    const wVp = this.getUIContext().px2vp(d.width);
    this.cell = Math.max(8, Math.floor((Math.min(wVp, 560) - 24) / COLS));
  }

  startGame(): void {
    if (this.score > 0) { GameDataManager.updateHighScore('snake', this.score); }
    GameDataManager.incrementPlayCount('snake');
    this.snake = [{ x: 10, y: 10 }];
    this.snakeDirection = Direction.RIGHT;
    this.pendingTurn = null;
    this.score = 0;
    this.isPlaying = true;
    this.isPaused = false;
    this.spawnFood();
    clearInterval(this.timer);
    this.timer = setInterval(() => { if (!this.isPaused && this.isPlaying) { this.move(); } }, this.getMoveInterval());
  }

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

  move(): void {
    if (this.pendingTurn !== null) {
      this.snakeDirection = this.pendingTurn;
      this.pendingTurn = null;
    }
    const head = this.snake[0];
    let nh: Point = { x: head.x, y: head.y };
    if (this.snakeDirection === Direction.UP) { nh.y -= 1; }
    else if (this.snakeDirection === Direction.DOWN) { nh.y += 1; }
    else if (this.snakeDirection === Direction.LEFT) { nh.x -= 1; }
    else { nh.x += 1; }
    if (nh.x < 0 || nh.x >= COLS || nh.y < 0 || nh.y >= ROWS) { this.gameOver(); return; }
    // 未吃到食物时蛇尾会同步前移让出格子，因此尾格不算碰撞
    const willEat = nh.x === this.food.x && nh.y === this.food.y;
    const checkLen = willEat ? this.snake.length : this.snake.length - 1;
    let selfHit = false;
    for (let i = 0; i < checkLen; i++) {
      if (this.snake[i].x === nh.x && this.snake[i].y === nh.y) { selfHit = true; break; }
    }
    if (selfHit) { this.gameOver(); return; }
    const ns = [nh];
    for (let i = 0; i < this.snake.length; i++) { ns.push(this.snake[i]); }
    if (!willEat) { ns.pop(); }
    this.snake = ns;
    if (willEat) { this.score += 10; this.spawnFood(); }
  }

  spawnFood(): void {
    const empties: Point[] = [];
    for (let x = 0; x < COLS; x++) {
      for (let y = 0; y < ROWS; y++) {
        let occupied = false;
        for (let i = 0; i < this.snake.length; i++) {
          if (this.snake[i].x === x && this.snake[i].y === y) { occupied = true; break; }
        }
        if (!occupied) { empties.push({ x: x, y: y }); }
      }
    }
    // 棋盘被蛇占满：无处生成食物，直接胜利结束，避免死循环
    if (empties.length === 0) {
      this.food = { x: -1, y: -1 };
      this.gameOver();
      return;
    }
    this.food = empties[Math.floor(Math.random() * empties.length)];
  }

  turn(dir: Direction): void {
    if (!this.isPlaying || this.isPaused) { return; }
    // 本 tick 已有待应用转向时忽略新输入，避免连按两键合成 180° 反向
    if (this.pendingTurn !== null) { return; }
    const cur = this.snakeDirection;
    if (dir === cur) { return; }
    const opp = (cur === Direction.UP && dir === Direction.DOWN) ||
                (cur === Direction.DOWN && dir === Direction.UP) ||
                (cur === Direction.LEFT && dir === Direction.RIGHT) ||
                (cur === Direction.RIGHT && dir === Direction.LEFT);
    if (!opp) { this.pendingTurn = dir; }
  }

  gameOver(): void {
    this.isPlaying = false;
    clearInterval(this.timer);
    if (this.score > this.highScore) { this.highScore = this.score; }
    GameDataManager.updateHighScore('snake', this.score);
  }

  isSnakeCell(x: number, y: number): boolean {
    for (let i = 0; i < this.snake.length; i++) {
      if (this.snake[i].x === x && this.snake[i].y === y) { return true; }
    }
    return false;
  }

  getCellColor(col: number, row: number): ResourceColor {
    if (this.food.x === col && this.food.y === row) { return SemanticColors.error; }
    if (this.isSnakeCell(col, row)) { return SemanticColors.success; }
    if ((row + col) % 2 === 0) { return SemanticColors.cellHidden; }
    return SemanticColors.cellRevealed;
  }

  getCellRadius(col: number, row: number): number {
    if (this.food.x === col && this.food.y === row) { return RadiusTokens.md; }
    return 3;
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[SemanticColors.gradientScreen[0], 0], [SemanticColors.gradientScreen[1], 0.5], [SemanticColors.gradientScreen[2], 1]] })

      Column() {
        GameHeader({ gameTitle: '贪吃蛇', // 得分/最高分已由下方大字指标卡展示，关闭标题栏的小字重复显示
          showScore: false,
          isPaused: this.isPaused,
          difficulty: this.difficulty,
          onDifficultyChange: (d: GameDifficulty) => { this.changeDifficulty(d); },
          onBack: () => { this.pathStack.pop(); },
          onPauseToggle: () => { this.isPaused = !this.isPaused; },
          onRestart: () => { this.startGame(); } })

        Row() {
          Column() {
            Text('得分').fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textTertiary)
            Text('' + this.score).fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold).fontColor(SemanticColors.accent)
          }.layoutWeight(1).padding(8).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base)
          .alignItems(HorizontalAlign.Center).margin({ left: 16 })

          Column() {
            Text('最高').fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textTertiary)
            Text('' + this.highScore).fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold).fontColor(SemanticColors.textPrimary)
          }.layoutWeight(1).padding(8).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base)
          .alignItems(HorizontalAlign.Center).margin({ left: 8, right: 16 })
        }.margin({ top: 12, bottom: 12 })

        Column() {
          Column() {
            ForEach(this.idx20, (row: number) => {
              Row() {
                ForEach(this.idx20, (col: number) => {
                  Column() {}.width(this.cell).height(this.cell)
                    .backgroundColor(this.getCellColor(col, row))
                    .borderRadius(this.getCellRadius(col, row))
                }, (col: number) => col.toString())
              }
            }, (row: number) => row.toString())
          }.width(this.cell * COLS).height(this.cell * ROWS)
          .border({ width: 2, color: SemanticColors.boardBorder, radius: RadiusTokens.sm })
          .backgroundColor(SemanticColors.boardBg)
        }.layoutWeight(1).justifyContent(FlexAlign.Center)

        ControlPad({
          onUp: () => this.turn(Direction.UP),
          onDown: () => this.turn(Direction.DOWN),
          onLeft: () => this.turn(Direction.LEFT),
          onRight: () => this.turn(Direction.RIGHT),
          onCenter: () => {},
          showCenter: true, centerLabel: '✨'
        })
      }.width('100%').height('100%').padding({ bottom: this.safeBottom })

      if (!this.isPlaying) {
        GameResultDialog({
          symbol: $r('sys.symbol.star_fill'),
          symbolColor: SemanticColors.warning,
          title: '游戏结束',
          detail: '得分 ' + this.score,
          detailColor: SemanticColors.accent,
          primaryText: '再来一局',
          onPrimary: () => { this.startGame(); },
          secondaryText: '返回',
          onSecondary: () => { this.pathStack.pop(); }
        })
      }
    }.width('100%').height('100%')
  }
}
