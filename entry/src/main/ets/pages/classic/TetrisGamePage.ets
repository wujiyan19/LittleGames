/**
 * 俄罗斯方块 - HarmonyOS 设计风格
 */
import { display } from '@kit.ArkUI';
import { DarkColors, RadiusTokens, FontTokens, ShadowTokens, SpacingTokens } from '../../common/DesignTokens';
import { GameHeader } from '../../components/GameHeader';
import { GameDifficulty } from '../../common/GameConstants';
import { GameDataManager } from '../../model/GameData';

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
const SHAPE_COLORS: string[] = ['#FF6B6B', '#FFAA33', '#2DD482', '#3399FF', '#8675F8', '#FF6B9D', '#00D4B4'];

interface Block { shape: number[][]; color: string; x: number; y: number; idx: number; rot: number; }

@Entry
@ComponentV2
struct TetrisGamePage {
  @Local board: string[][] = [];
  @Local score: number = 0;
  @Local highScore: number = 0;
  @Local level: number = 1;
  @Local difficulty: GameDifficulty = GameDifficulty.NORMAL;
  @Local isPlaying: boolean = true;
  @Local isPaused: boolean = false;
  @Local cell: number = 18;
  // 改为 @Local：下落方块此前是普通私有字段，坐标变化不触发 UI 刷新，
  // 导致方块下落过程不可见、只在锁定瞬间突然出现
  @Local block: Block | null = null;
  private timer: number = -1;
  private rowIdx: number[] = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19];
  private colIdx: number[] = [0,1,2,3,4,5,6,7,8,9];

  aboutToAppear(): void {
    this.initCellSize();
    GameDataManager.incrementPlayCount('tetris');
    this.init(); this.spawn(); this.loop();
  }
  aboutToDisappear(): void { clearInterval(this.timer); }

  initCellSize(): void {
    const d = display.getDefaultDisplaySync();
    const wVp = this.getUIContext().px2vp(d.width);
    this.cell = Math.max(8, Math.floor((Math.min(wVp, 560) - 16) / COLS));
  }

  // 重新赋值 block 对象，确保 @Local 观察到变化并刷新 UI
  commitBlock(): void {
    const b = this.block;
    if (!b) { return; }
    this.block = { shape: b.shape, color: b.color, x: b.x, y: b.y, idx: b.idx, rot: b.rot };
  }

  makeBoard(): string[][] {
    const arr: string[][] = [];
    for (let i = 0; i < ROWS; i++) {
      const row: string[] = [];
      for (let j = 0; j < COLS; j++) { row[j] = ''; }
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
      color: SHAPE_COLORS[idx],
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
          if (ny >= 0 && this.board[ny][nx]) { return false; }
        }
      }
    }
    return true;
  }

  lock(): void {
    if (!this.block) { return; }
    const shape = this.block.shape;
    const color = this.block.color;
    const x = this.block.x;
    const y = this.block.y;
    for (let r = 0; r < shape.length; r++) {
      for (let c = 0; c < shape[r].length; c++) {
        if (shape[r][c] && y + r >= 0) {
          this.board[y + r][x + c] = color;
        }
      }
    }
    this.clearRows();
    this.spawn();
  }

  clearRows(): void {
    let lines = 0;
    let newBoard: string[][] = [];
    for (let i = 0; i < this.board.length; i++) {
      let full = true;
      for (let j = 0; j < this.board[i].length; j++) {
        if (!this.board[i][j]) { full = false; break; }
      }
      if (full) {
        lines++;
      } else {
        newBoard.push(this.board[i]);
      }
    }
    while (newBoard.length < ROWS) {
      let row: string[] = [];
      for (let j = 0; j < COLS; j++) { row[j] = ''; }
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
      if (!this.isPaused && this.isPlaying) { this.drop(); }
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
    if (!this.block) { return; }
    if (this.canPlace(-1, 0)) { this.block.x--; this.commitBlock(); }
  }
  moveRight(): void {
    if (!this.block) { return; }
    if (this.canPlace(1, 0)) { this.block.x++; this.commitBlock(); }
  }
  rotateBlock(): void {
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
    while (this.canPlace(0, 1) && this.block) { this.block.y++; }
    this.lock();
  }

  gameOver(): void {
    this.isPlaying = false;
    clearInterval(this.timer);
    if (this.score > this.highScore) { this.highScore = this.score; }
    GameDataManager.updateHighScore('tetris', this.score);
  }
  restart(): void {
    if (this.score > 0) { GameDataManager.updateHighScore('tetris', this.score); }
    GameDataManager.incrementPlayCount('tetris');
    this.init();
    this.spawn();
    this.isPlaying = true;
    this.isPaused = false;
    this.loop();
  }

  getCellColor(r: number, c: number): ResourceColor {
    if (this.board[r][c]) { return this.board[r][c]; }
    if (this.block) {
      const shape = this.block.shape;
      const x = this.block.x;
      const y = this.block.y;
      const color = this.block.color;
      const cr = r - y;
      const cc = c - x;
      if (cr >= 0 && cr < shape.length && cc >= 0 && cc < shape[0].length && shape[cr][cc]) {
        return color;
      }
    }
    return DarkColors.cellRevealed;
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[DarkColors.gradientScreen[0], 0], [DarkColors.gradientScreen[1], 0.5], [DarkColors.gradientScreen[2], 1]] })

      Column() {
        GameHeader({ gameTitle: '俄罗斯方块', scoreValue: this.score, highScoreValue: this.highScore,
          isPaused: this.isPaused,
          difficulty: this.difficulty,
          onDifficultyChange: (d: GameDifficulty) => { this.changeDifficulty(d); },
          onBack: () => { this.getUIContext().getRouter().back(); },
          onPauseToggle: () => { this.isPaused = !this.isPaused; },
          onRestart: () => { this.restart(); } })

        Row() {
          Column() {
            Text('级别').fontSize(FontTokens.sizeCaption).fontColor(DarkColors.textTertiary)
            Text('' + this.level).fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold).fontColor(DarkColors.warning)
          }.layoutWeight(1).padding(8).backgroundColor(DarkColors.surface).borderRadius(RadiusTokens.base)
          .alignItems(HorizontalAlign.Center).margin({ left: 16 })

          Column() {
            Text('得分').fontSize(FontTokens.sizeCaption).fontColor(DarkColors.textTertiary)
            Text('' + this.score).fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold).fontColor(DarkColors.accent)
          }.layoutWeight(1).padding(8).backgroundColor(DarkColors.surface).borderRadius(RadiusTokens.base)
          .alignItems(HorizontalAlign.Center).margin({ left: 8, right: 16 })
        }.margin({ top: 12, bottom: 12 })

        Row() {
          Column() {
            ForEach(this.rowIdx, (row: number) => {
              Row() {
                ForEach(this.colIdx, (col: number) => {
                  Column() {}.width(this.cell).height(this.cell)
                    .backgroundColor(this.getCellColor(row, col))
                    .border({ width: 0.5, color: DarkColors.divider })
                })
              }
            })
          }.width(this.cell * COLS).height(this.cell * ROWS)
          .border({ width: 2, color: DarkColors.boardBorder, radius: RadiusTokens.sm })
          .backgroundColor(DarkColors.boardBg)
        }.layoutWeight(1).justifyContent(FlexAlign.Center)

        Column({ space: SpacingTokens.sm }) {
          Row({ space: SpacingTokens.sm }) {
            Button() {
              SymbolGlyph($r('sys.symbol.arrow_left'))
                .fontSize(18).fontColor([DarkColors.textPrimary])
            }
            .layoutWeight(1).height(48).backgroundColor(DarkColors.surface)
            .borderRadius(RadiusTokens.base).shadow(ShadowTokens.button).onClick(() => this.moveLeft())
            Button() {
              SymbolGlyph($r('sys.symbol.arrow_clockwise'))
                .fontSize(18).fontColor([DarkColors.textPrimary])
            }
            .layoutWeight(1).height(48).backgroundColor(DarkColors.surface)
            .borderRadius(RadiusTokens.base).shadow(ShadowTokens.button).onClick(() => this.rotateBlock())
            Button() {
              SymbolGlyph($r('sys.symbol.arrow_right'))
                .fontSize(18).fontColor([DarkColors.textPrimary])
            }
            .layoutWeight(1).height(48).backgroundColor(DarkColors.surface)
            .borderRadius(RadiusTokens.base).shadow(ShadowTokens.button).onClick(() => this.moveRight())
          }
          .width('100%').padding({ left: SpacingTokens.base, right: SpacingTokens.base })
          Button() {
            Row({ space: SpacingTokens.xs }) {
              SymbolGlyph($r('sys.symbol.arrow_down'))
                .fontSize(16).fontColor([DarkColors.textOnPrimary])
              Text('加速下落')
                .fontFamily(FontTokens.family)
                .fontSize(FontTokens.sizeBody).fontColor(DarkColors.textOnPrimary)
            }
          }
          .width('80%').height(48).backgroundColor(DarkColors.primary)
          .borderRadius(RadiusTokens.full).shadow(ShadowTokens.button).onClick(() => this.hardDrop())
        }.padding({ bottom: SpacingTokens.lg })
      }.width('100%').height('100%')

      if (!this.isPlaying) {
        Column() {
          Column() {
            SymbolGlyph($r('sys.symbol.star_fill'))
              .fontSize(40)
              .fontWeight(FontWeight.Medium)
              .fontColor([DarkColors.warning])
          }
          .width(72).height(72)
          .borderRadius(RadiusTokens.full)
          .backgroundColor(DarkColors.primaryLight)
          .justifyContent(FlexAlign.Center)

          Text('游戏结束')
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold)
            .fontColor(DarkColors.textPrimary).margin({ top: SpacingTokens.md, bottom: SpacingTokens.xs })
          Text('得分 ' + this.score)
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeSubtitle).fontColor(DarkColors.accent).margin({ bottom: SpacingTokens.lg })
          Row({ space: SpacingTokens.base }) {
            Button() {
              Row({ space: SpacingTokens.xs }) {
                SymbolGlyph($r('sys.symbol.arrow_clockwise'))
                  .fontSize(16).fontColor([DarkColors.textOnPrimary])
                Text('再来一局')
                  .fontFamily(FontTokens.family)
                  .fontSize(FontTokens.sizeBody).fontColor(DarkColors.textOnPrimary)
              }
            }
            .height(44).padding({ left: SpacingTokens.lg, right: SpacingTokens.lg })
            .backgroundColor(DarkColors.primary).borderRadius(RadiusTokens.full)
            .shadow(ShadowTokens.button)
            .onClick(() => this.restart())
            Button('返回')
              .height(44).padding({ left: SpacingTokens.lg, right: SpacingTokens.lg })
              .fontFamily(FontTokens.family)
              .fontColor(DarkColors.textPrimary).backgroundColor(DarkColors.surface)
              .borderRadius(RadiusTokens.full).shadow(ShadowTokens.button)
              .onClick(() => this.getUIContext().getRouter().back())
          }
        }
        .width('100%').height('100%')
        .backgroundColor(DarkColors.scrim)
        .backdropBlur(20)
        .justifyContent(FlexAlign.Center)
      }
    }.width('100%').height('100%')
  }
}
