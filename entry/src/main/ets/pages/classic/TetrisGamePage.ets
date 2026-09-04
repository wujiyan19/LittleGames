/**
 * 俄罗斯方块 - HarmonyOS 设计风格
 */
import { SemanticColors, RadiusTokens, FontTokens, ShadowTokens, SpacingTokens } from '../../common/DesignTokens';
import { GameHeader } from '../../components/GameHeader';
import { GameDifficulty, GameStatus } from '../../common/GameConstants';
import { GameDataManager } from '../../model/GameData';
import { SafeAreaInsets } from '../../common/SafeAreaInsets';
import { GameResultDialog } from '../../components/GameResultDialog';
import { ScreenUtils } from '../../common/ScreenUtils';
import { range } from '../../common/Range';

const COLS = 10;
const ROWS = 20;

// 每种方块的完整旋转状态（此前每种只有一态，导致旋转按键完全无效）
const SHAPES: number[][][][] = [
  // I
  [[[1,1,1,1]], [[1],[1],[1],[1]]],
  // O
  [[[1,1],[1,1]]],
  // T
  [[[0,1,0],[1,1,1]], [[1,0],[1,1],[1,0]], [[1,1,1],[0,1,0]], [[0,1],[1,1],[0,1]]],
  // S
  [[[0,1,1],[1,1,0]], [[1,0],[1,1],[0,1]]],
  // Z
  [[[1,1,0],[0,1,1]], [[0,1],[1,1],[1,0]]],
  // L
  [[[1,0,0],[1,1,1]], [[1,1],[1,0],[1,0]], [[1,1,1],[0,0,1]], [[0,1],[0,1],[1,1]]],
  // J
  [[[0,0,1],[1,1,1]], [[1,0],[1,0],[1,1]], [[1,1,1],[1,0,0]], [[1,1],[0,1],[0,1]]]
];
/**
 * 方块配色。原为字面量数组，违反「UI 常量应定义为 resources 资源值」的约定，
 * 已收编为资源；深色模式在 dark/element/color.json 中提供提亮后的版本。
 */
const SHAPE_COLORS: ResourceColor[] = [
  $r('app.color.shape_1'),
  $r('app.color.shape_2'),
  $r('app.color.shape_3'),
  $r('app.color.shape_4'),
  $r('app.color.shape_5'),
  $r('app.color.shape_6'),
  $r('app.color.shape_7')
];

/**
 * 当前下落方块。
 * 注意：颜色不再随对象存储——它与形状索引一一对应（SHAPES[idx] ↔ SHAPE_COLORS[idx]），
 * 存两份容易不同步。board 也改为存「形状索引 + 1」而非颜色本身，0 表示空格。
 */
interface Block { shape: number[][]; x: number; y: number; idx: number; rot: number; }

@ComponentV2
export struct TetrisGamePage {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local safeBottom: number = SafeAreaInsets.bottom;
  // 棋盘只存数据：0 = 空格，n = 第 (n-1) 号形状占据；颜色由 SHAPE_COLORS 在渲染时查表
  @Local board: number[][] = [];
  @Local score: number = 0;
  @Local highScore: number = 0;
  @Local level: number = 1;
  @Local difficulty: GameDifficulty = GameDifficulty.NORMAL;
  /**
   * 对局状态。原先由 isPlaying + isPaused 两个布尔拼出，其中「已结束但仍处于暂停」
   * 是无意义的非法态。改为单一枚举后，非法态在类型层面就无法表达。
   */
  @Local status: GameStatus = GameStatus.PLAYING;
  @Local cell: number = 18;
  // 改为 @Local：下落方块此前是普通私有字段，坐标变化不触发 UI 刷新，
  // 导致方块下落过程不可见、只在锁定瞬间突然出现
  @Local block: Block | null = null;
  private timer: number = -1;
  /** 本次暂停是否由「切后台」自动触发——决定回到前台时是否需要自动恢复 */
  private autoPaused: boolean = false;
  private rowIdx: number[] = range(ROWS);
  private colIdx: number[] = range(COLS);

  aboutToAppear(): void {
    this.highScore = GameDataManager.getGameById('tetris')?.highScore ?? 0;
    this.initCellSize();
    GameDataManager.incrementPlayCount('tetris');
    this.init(); this.spawn(); this.loop();
  }
  aboutToDisappear(): void { clearInterval(this.timer); }

  /** 切后台自动暂停，避免方块在后台持续下落堆满棋盘（定时回调只放行 PLAYING 状态） */
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

  initCellSize(): void {
    this.cell = ScreenUtils.calcCell(COLS, 560, 16, 8);
  }

  // 重新赋值 block 对象，确保 @Local 观察到变化并刷新 UI
  commitBlock(): void {
    const b = this.block;
    if (!b) { return; }
    this.block = { shape: b.shape, x: b.x, y: b.y, idx: b.idx, rot: b.rot };
  }

  makeBoard(): number[][] {
    const arr: number[][] = [];
    for (let i = 0; i < ROWS; i++) {
      const row: number[] = [];
      for (let j = 0; j < COLS; j++) { row[j] = 0; }
      arr[i] = row;
    }
    return arr;
  }

  init(): void {
    this.board = this.makeBoard();
    this.score = 0;
    this.level = 1;
  }

  spawn(): void {
    const idx = Math.floor(Math.random() * SHAPES.length);
    this.block = {
      shape: SHAPES[idx][0],
      x: Math.floor((COLS - SHAPES[idx][0][0].length) / 2),
      y: 0,
      idx: idx,
      rot: 0
    };
    if (!this.canPlace(0, 0)) { this.gameOver(); }
  }

  canPlace(dx: number, dy: number): boolean {
    if (!this.block) { return false; }
    const shape = this.block.shape;
    const x = this.block.x;
    const y = this.block.y;
    for (let r = 0; r < shape.length; r++) {
      for (let c = 0; c < shape[r].length; c++) {
        if (shape[r][c]) {
          const nx = x + c + dx;
          const ny = y + r + dy;
          if (nx < 0 || nx >= COLS || ny >= ROWS) { return false; }
          if (ny >= 0 && this.board[ny][nx] !== 0) { return false; }
        }
      }
    }
    return true;
  }

  lock(): void {
    if (!this.block) { return; }
    const shape = this.block.shape;
    const x = this.block.x;
    const y = this.block.y;
    // 落格记「形状索引 + 1」，颜色在渲染时查 SHAPE_COLORS，棋盘只存数据
    const mark = this.block.idx + 1;
    for (let r = 0; r < shape.length; r++) {
      for (let c = 0; c < shape[r].length; c++) {
        if (shape[r][c] && y + r >= 0) {
          this.board[y + r][x + c] = mark;
        }
      }
    }
    this.clearRows();
    this.spawn();
  }

  clearRows(): void {
    let lines = 0;
    let newBoard: number[][] = [];
    for (let i = 0; i < this.board.length; i++) {
      let full = true;
      for (let j = 0; j < this.board[i].length; j++) {
        if (this.board[i][j] === 0) { full = false; break; }
      }
      if (full) {
        lines++;
      } else {
        newBoard.push(this.board[i]);
      }
    }
    while (newBoard.length < ROWS) {
      let row: number[] = [];
      for (let j = 0; j < COLS; j++) { row[j] = 0; }
      newBoard.splice(0, 0, row);
    }
    this.board = newBoard;
    const scores = [0, 100, 300, 500, 800];
    this.score += scores[Math.min(lines, 4)] * this.level;
    // 升级后需重建定时器，否则下落速度不会随等级加快
    const newLevel = Math.floor(this.score / 1000) + 1;
    if (newLevel !== this.level) {
      this.level = newLevel;
      this.loop();
    }
  }

  loop(): void {
    clearInterval(this.timer);
    this.timer = setInterval(() => {
      if (this.status === GameStatus.PLAYING) { this.drop(); }
    }, Math.max(80, this.getBaseFallInterval() - (this.level - 1) * 40));
  }

  getBaseFallInterval(): number {
    if (this.difficulty === GameDifficulty.EASY) { return 650; }
    if (this.difficulty === GameDifficulty.HARD) { return 380; }
    return 500;
  }

  changeDifficulty(d: GameDifficulty): void {
    if (this.difficulty === d) { return; }
    this.difficulty = d;
    this.restart();
  }

  drop(): void {
    if (!this.block) { return; }
    if (this.canPlace(0, 1)) { this.block.y++; this.commitBlock(); }
    else { this.lock(); }
  }
  moveLeft(): void {
    if (this.status !== GameStatus.PLAYING) { return; }
    if (!this.block) { return; }
    if (this.canPlace(-1, 0)) { this.block.x--; this.commitBlock(); }
  }
  moveRight(): void {
    if (this.status !== GameStatus.PLAYING) { return; }
    if (!this.block) { return; }
    if (this.canPlace(1, 0)) { this.block.x++; this.commitBlock(); }
  }
  rotateBlock(): void {
    if (this.status !== GameStatus.PLAYING) { return; }
    if (!this.block) { return; }
    const shapes = SHAPES[this.block.idx];
    if (shapes.length <= 1) { return; }
    const next = (this.block.rot + 1) % shapes.length;
    const oldShape = this.block.shape;
    const oldRot = this.block.rot;
    this.block.shape = shapes[next];
    this.block.rot = next;
    const offsets = [0, -1, 1, -2, 2];
    for (let k = 0; k < offsets.length; k++) {
      this.block.x += offsets[k];
      if (this.canPlace(0, 0)) { this.commitBlock(); return; }
      this.block.x -= offsets[k];
    }
    // 还原时恢复记录的旧旋转值（原写法 rot -= 1 在 next 回绕为 0 时会得到 -1）
    this.block.shape = oldShape;
    this.block.rot = oldRot;
  }
  hardDrop(): void {
    if (this.status !== GameStatus.PLAYING) { return; }
    while (this.canPlace(0, 1) && this.block) { this.block.y++; }
    this.lock();
  }

  gameOver(): void {
    this.status = GameStatus.OVER;
    clearInterval(this.timer);
    if (this.score > this.highScore) { this.highScore = this.score; }
    GameDataManager.updateHighScore('tetris', this.score);
  }
  restart(): void {
    if (this.score > 0) { GameDataManager.updateHighScore('tetris', this.score); }
    GameDataManager.incrementPlayCount('tetris');
    this.init();
    this.spawn();
    this.status = GameStatus.PLAYING;
    this.loop();
  }
  /** 手动暂停/恢复。只在「进行中 ⇄ 暂停」间切换，已结束的对局不会被误切换 */
  togglePause(): void {
    if (this.status === GameStatus.PLAYING) {
      this.status = GameStatus.PAUSED;
    } else if (this.status === GameStatus.PAUSED) {
      this.status = GameStatus.PLAYING;
    }
  }

  getCellColor(r: number, c: number): ResourceColor {
    // 已落定的格子：由索引查回颜色
    if (this.board[r][c] !== 0) { return SHAPE_COLORS[this.board[r][c] - 1]; }
    if (this.block) {
      const shape = this.block.shape;
      const x = this.block.x;
      const y = this.block.y;
      const cr = r - y;
      const cc = c - x;
      if (cr >= 0 && cr < shape.length && cc >= 0 && cc < shape[0].length && shape[cr][cc]) {
        return SHAPE_COLORS[this.block.idx];
      }
    }
    return SemanticColors.cellRevealed;
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[SemanticColors.gradientScreen[0], 0], [SemanticColors.gradientScreen[1], 0.5], [SemanticColors.gradientScreen[2], 1]] })

      Column() {
        GameHeader({ gameTitle: '俄罗斯方块', // 得分/最高分已由下方大字指标卡展示，关闭标题栏的小字重复显示
          showScore: false,
          isPaused: this.status === GameStatus.PAUSED,
          difficulty: this.difficulty,
          onDifficultyChange: (d: GameDifficulty) => { this.changeDifficulty(d); },
          onBack: () => { this.pathStack.pop(); },
          onPauseToggle: () => { this.togglePause(); },
          onRestart: () => { this.restart(); } })

        Row() {
          Column() {
            Text('级别').fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textTertiary)
            Text('' + this.level).fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold).fontColor(SemanticColors.warning)
          }.layoutWeight(1).padding(8).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base)
          .alignItems(HorizontalAlign.Center).margin({ left: 16 })

          Column() {
            Text('得分').fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textTertiary)
            Text('' + this.score).fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold).fontColor(SemanticColors.accent)
          }.layoutWeight(1).padding(8).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base)
          .alignItems(HorizontalAlign.Center).margin({ left: 8, right: 16 })
        }.margin({ top: 12, bottom: 12 })

        Row() {
          Column() {
            ForEach(this.rowIdx, (row: number) => {
              Row() {
                ForEach(this.colIdx, (col: number) => {
                  Column() {}.width(this.cell).height(this.cell)
                    .backgroundColor(this.getCellColor(row, col))
                    .border({ width: 0.5, color: SemanticColors.divider })
                }, (col: number) => col.toString())
              }
            }, (row: number) => row.toString())
          }.width(this.cell * COLS).height(this.cell * ROWS)
          .border({ width: 2, color: SemanticColors.boardBorder, radius: RadiusTokens.sm })
          .backgroundColor(SemanticColors.boardBg)
        }.layoutWeight(1).justifyContent(FlexAlign.Center)

        Column({ space: SpacingTokens.sm }) {
          Row({ space: SpacingTokens.sm }) {
            Button() {
              SymbolGlyph($r('sys.symbol.arrow_left'))
                .fontSize(18).fontColor([SemanticColors.textPrimary])
            }
            .layoutWeight(1).height(48).backgroundColor(SemanticColors.surface)
            .borderRadius(RadiusTokens.base).shadow(ShadowTokens.button).onClick(() => this.moveLeft())
            Button() {
              SymbolGlyph($r('sys.symbol.arrow_clockwise'))
                .fontSize(18).fontColor([SemanticColors.textPrimary])
            }
            .layoutWeight(1).height(48).backgroundColor(SemanticColors.surface)
            .borderRadius(RadiusTokens.base).shadow(ShadowTokens.button).onClick(() => this.rotateBlock())
            Button() {
              SymbolGlyph($r('sys.symbol.arrow_right'))
                .fontSize(18).fontColor([SemanticColors.textPrimary])
            }
            .layoutWeight(1).height(48).backgroundColor(SemanticColors.surface)
            .borderRadius(RadiusTokens.base).shadow(ShadowTokens.button).onClick(() => this.moveRight())
          }
          .width('100%').padding({ left: SpacingTokens.base, right: SpacingTokens.base })
          Button() {
            Row({ space: SpacingTokens.xs }) {
              SymbolGlyph($r('sys.symbol.arrow_down'))
                .fontSize(16).fontColor([SemanticColors.textOnPrimary])
              Text('加速下落')
                .fontFamily(FontTokens.family)
                .fontSize(FontTokens.sizeBody).fontColor(SemanticColors.textOnPrimary)
            }
          }
          .width('80%').height(48).backgroundColor(SemanticColors.primary)
          .borderRadius(RadiusTokens.full).shadow(ShadowTokens.button).onClick(() => this.hardDrop())
        }.padding({ bottom: SpacingTokens.lg })
      }.width('100%').height('100%').padding({ bottom: this.safeBottom })

      if (this.status === GameStatus.OVER) {
        GameResultDialog({
          symbol: $r('sys.symbol.star_fill'),
          symbolColor: SemanticColors.warning,
          title: '游戏结束',
          detail: '得分 ' + this.score,
          detailColor: SemanticColors.accent,
          primaryText: '再来一局',
          onPrimary: () => { this.restart(); },
          secondaryText: '返回',
          onSecondary: () => { this.pathStack.pop(); }
        })
      }
    }.width('100%').height('100%')
  }
}
