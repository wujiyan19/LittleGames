/**
 * 数独 - HarmonyOS 设计风格（带双指缩放）
 */
import { display } from '@kit.ArkUI';
import { DarkColors, RadiusTokens, FontTokens, ShadowTokens, SpacingTokens } from '../../common/DesignTokens';
import { GameHeader } from '../../components/GameHeader';
import { GameDifficulty } from '../../common/GameConstants';
import { GameDataManager } from '../../model/GameData';

@Entry
@ComponentV2
struct SudokuPage {
  @Local board: number[][] = [];
  @Local selectedRow: number = -1;
  @Local selectedCol: number = -1;
  @Local isComplete: boolean = false;
  @Local scaleFactor: number = 1;
  @Local offsetX: number = 0;
  @Local offsetY: number = 0;
  @Local boardPixelSize: number = 302;
  @Local difficulty: GameDifficulty = GameDifficulty.NORMAL;
  private fixed: boolean[][] = [];
  private idx9: number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8];
  private startScale: number = 1;
  private startOffsetX: number = 0;
  private startOffsetY: number = 0;
  // 当前题面（用于「重新开始」还原）
  private puzzle: number[][] = [];
  // 上一把题面指纹，保证「新游戏」不与上一把相同
  private previousKey: string = '';
  // 唯一解校验计数
  private solutionCount: number = 0;

  aboutToAppear(): void {
    this.initBoardSize();
    this.newGame();
  }

  initBoardSize(): void {
    const d = display.getDefaultDisplaySync();
    const wVp = this.getUIContext().px2vp(d.width);
    const cell = Math.max(28, Math.floor((Math.min(wVp, 520) - 24) / 9));
    this.boardPixelSize = cell * 9 + 8;
  }

  getCellSize(): number {
    return (this.boardPixelSize - 8) / 9;
  }

  makeBoard(val: number): number[][] {
    const arr: number[][] = [];
    for (let i = 0; i < 9; i++) {
      const row: number[] = [];
      for (let j = 0; j < 9; j++) { row[j] = val; }
      arr[i] = row;
    }
    return arr;
  }

  makeBoolBoard(): boolean[][] {
    const arr: boolean[][] = [];
    for (let i = 0; i < 9; i++) {
      const row: boolean[] = [];
      for (let j = 0; j < 9; j++) { row[j] = false; }
      arr[i] = row;
    }
    return arr;
  }

  newGame(): void {
    this.startGame(this.generatePuzzle());
  }

  restartGame(): void {
    this.startGame(this.puzzle);
  }

  startGame(puzzle: number[][]): void {
    GameDataManager.incrementPlayCount('sudoku');
    this.board = this.makeBoard(0);
    this.fixed = this.makeBoolBoard();
    this.puzzle = this.copyBoard(puzzle);
    for (let r = 0; r < 9; r++) {
      for (let c = 0; c < 9; c++) {
        this.board[r][c] = puzzle[r][c];
        this.fixed[r][c] = puzzle[r][c] !== 0;
      }
    }
    this.isComplete = false;
    this.selectedRow = -1;
    this.selectedCol = -1;
    // 重置缩放
    this.scaleFactor = 1;
    this.offsetX = 0;
    this.offsetY = 0;
  }

  copyBoard(src: number[][]): number[][] {
    const dst: number[][] = [];
    for (let i = 0; i < 9; i++) {
      const row: number[] = [];
      for (let j = 0; j < 9; j++) { row[j] = src[i][j]; }
      dst[i] = row;
    }
    return dst;
  }

  shuffled9(): number[] {
    const arr = [1, 2, 3, 4, 5, 6, 7, 8, 9];
    for (let i = 8; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      const t = arr[i]; arr[i] = arr[j]; arr[j] = t;
    }
    return arr;
  }

  canPlaceAt(grid: number[][], r: number, c: number, v: number): boolean {
    for (let i = 0; i < 9; i++) {
      if (grid[r][i] === v || grid[i][c] === v) { return false; }
    }
    const br = Math.floor(r / 3) * 3;
    const bc = Math.floor(c / 3) * 3;
    for (let i = br; i < br + 3; i++) {
      for (let j = bc; j < bc + 3; j++) {
        if (grid[i][j] === v) { return false; }
      }
    }
    return true;
  }

  fillSolution(board: number[][]): boolean {
    let r = -1;
    let c = -1;
    for (let i = 0; i < 9 && r === -1; i++) {
      for (let j = 0; j < 9 && r === -1; j++) {
        if (board[i][j] === 0) { r = i; c = j; }
      }
    }
    if (r === -1) { return true; }
    const order = this.shuffled9();
    for (let k = 0; k < order.length; k++) {
      const v = order[k];
      if (this.canPlaceAt(board, r, c, v)) {
        board[r][c] = v;
        if (this.fillSolution(board)) { return true; }
      }
    }
    board[r][c] = 0;
    return false;
  }

  generateSolution(): number[][] {
    const board = this.makeBoard(0);
    this.fillSolution(board);
    return board;
  }

  candidatesAt(grid: number[][], r: number, c: number): number[] {
    const res: number[] = [];
    for (let v = 1; v <= 9; v++) {
      if (this.canPlaceAt(grid, r, c, v)) { res.push(v); }
    }
    return res;
  }

  solveCount(board: number[][]): void {
    if (this.solutionCount > 1) { return; }
    let bestR = -1;
    let bestC = -1;
    let bestLen = 10;
    for (let r = 0; r < 9; r++) {
      for (let c = 0; c < 9; c++) {
        if (board[r][c] !== 0) { continue; }
        const cand = this.candidatesAt(board, r, c);
        if (cand.length === 0) { return; }
        if (cand.length < bestLen) {
          bestLen = cand.length;
          bestR = r;
          bestC = c;
        }
      }
    }
    if (bestR === -1) {
      this.solutionCount++;
      return;
    }
    const cand = this.candidatesAt(board, bestR, bestC);
    for (let k = 0; k < cand.length; k++) {
      board[bestR][bestC] = cand[k];
      this.solveCount(board);
      board[bestR][bestC] = 0;
      if (this.solutionCount > 1) { return; }
    }
  }

  countSolutions(grid: number[][]): number {
    this.solutionCount = 0;
    this.solveCount(this.copyBoard(grid));
    return this.solutionCount;
  }

  getTargetClues(): number {
    if (this.difficulty === GameDifficulty.EASY) { return 45; }
    if (this.difficulty === GameDifficulty.HARD) { return 23; }
    return 29;
  }

  boardKey(grid: number[][]): string {
    let key = '';
    for (let r = 0; r < 9; r++) {
      for (let c = 0; c < 9; c++) {
        key += grid[r][c].toString();
      }
    }
    return key;
  }

  generatePuzzle(): number[][] {
    const targetClues = this.getTargetClues();
    let last: number[][] = [];
    for (let attempt = 0; attempt < 30; attempt++) {
      const solution = this.generateSolution();
      const candidate = this.copyBoard(solution);
      const cells: number[] = [];
      for (let i = 0; i < 81; i++) { cells.push(i); }
      for (let i = 80; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        const t = cells[i]; cells[i] = cells[j]; cells[j] = t;
      }
      let clues = 81;
      for (let k = 0; k < cells.length && clues > targetClues; k++) {
        const r = Math.floor(cells[k] / 9);
        const c = cells[k] % 9;
        const saved = candidate[r][c];
        candidate[r][c] = 0;
        if (this.countSolutions(candidate) !== 1) {
          candidate[r][c] = saved;
        } else {
          clues--;
        }
      }
      last = candidate;
      const key = this.boardKey(candidate);
      if (key !== this.previousKey) {
        this.previousKey = key;
        return candidate;
      }
    }
    // 极端兜底（连续 30 次生成同一题面几乎不可能）
    this.previousKey = this.boardKey(last);
    return this.fallbackPuzzle();
  }

  fallbackPuzzle(): number[][] {
    if (this.difficulty === GameDifficulty.EASY) {
      // 简单：45 个提示
      return [
        [5, 3, 4, 6, 7, 8, 9, 1, 2], [6, 7, 2, 1, 9, 5, 3, 4, 8], [1, 9, 8, 3, 4, 2, 5, 6, 7],
        [8, 5, 9, 7, 6, 1, 4, 2, 3], [0, 0, 6, 0, 0, 0, 0, 0, 1], [0, 0, 0, 0, 0, 0, 0, 0, 6],
        [0, 0, 1, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 9, 0, 0, 5], [0, 0, 0, 0, 8, 0, 0, 7, 9]
      ];
    }
    if (this.difficulty === GameDifficulty.HARD) {
      // 困难：23 个提示
      return [
        [0, 0, 0, 0, 7, 0, 0, 0, 0], [6, 0, 0, 1, 0, 5, 0, 0, 0], [0, 0, 8, 0, 0, 0, 0, 6, 0],
        [8, 0, 0, 0, 0, 0, 0, 0, 3], [4, 0, 0, 8, 0, 3, 0, 0, 1], [7, 0, 0, 0, 2, 0, 0, 0, 6],
        [0, 6, 0, 0, 0, 0, 2, 0, 0], [0, 0, 0, 4, 1, 9, 0, 0, 5], [0, 0, 0, 0, 0, 0, 0, 7, 9]
      ];
    }
    // 普通：29 个提示（原有题面）
    return [
      [5, 3, 0, 0, 7, 0, 0, 0, 0], [6, 0, 0, 1, 9, 5, 0, 0, 0], [0, 9, 8, 0, 0, 0, 0, 6, 0],
      [8, 0, 0, 0, 6, 0, 0, 0, 3], [4, 0, 0, 8, 0, 3, 0, 0, 1], [7, 0, 0, 0, 2, 0, 0, 0, 6],
      [0, 6, 0, 0, 0, 0, 2, 8, 0], [0, 0, 0, 4, 1, 9, 0, 0, 5], [0, 0, 0, 0, 8, 0, 0, 7, 9]
    ];
  }

  changeDifficulty(d: GameDifficulty): void {
    if (this.difficulty === d) { return; }
    this.difficulty = d;
    this.newGame();
  }

  setNumber(n: number): void {
    const r = this.selectedRow;
    const c = this.selectedCol;
    if (r < 0 || c < 0 || this.fixed[r][c] || this.isComplete) { return; }
    this.board[r][c] = n;
    this.checkComplete();
  }

  erase(): void {
    const r = this.selectedRow;
    const c = this.selectedCol;
    if (r < 0 || c < 0 || this.fixed[r][c]) { return; }
    this.board[r][c] = 0;
  }

  checkComplete(): void {
    for (let r = 0; r < 9; r++) {
      for (let c = 0; c < 9; c++) {
        if (this.board[r][c] === 0 || !this.isValid(r, c, this.board[r][c])) { return; }
      }
    }
    this.isComplete = true;
    // 难度越高完成得分越高
    let score = 100;
    if (this.difficulty === GameDifficulty.NORMAL) { score = 200; }
    else if (this.difficulty === GameDifficulty.HARD) { score = 300; }
    GameDataManager.updateHighScore('sudoku', score);
  }

  isValid(r: number, c: number, v: number): boolean {
    for (let i = 0; i < 9; i++) {
      if (i !== c && this.board[r][i] === v) { return false; }
      if (i !== r && this.board[i][c] === v) { return false; }
    }
    const br = Math.floor(r / 3) * 3;
    const bc = Math.floor(c / 3) * 3;
    for (let i = br; i < br + 3; i++) {
      for (let j = bc; j < bc + 3; j++) {
        if ((i !== r || j !== c) && this.board[i][j] === v) { return false; }
      }
    }
    return true;
  }

  getNumberColor(row: number, col: number): ResourceColor {
    if (this.fixed[row][col]) { return DarkColors.warning; }
    return DarkColors.textPrimary;
  }

  getNumberWeight(row: number, col: number): FontWeight {
    if (this.fixed[row][col]) { return FontWeight.Bold; }
    return FontWeight.Regular;
  }

  getCellBg(row: number, col: number): ResourceColor {
    if (this.selectedRow === row && this.selectedCol === col) { return DarkColors.accent; }
    if ((Math.floor(row / 3) + Math.floor(col / 3)) % 2 === 0) { return DarkColors.cellHidden; }
    return DarkColors.cellRevealed;
  }

  getCellBorderWidth(row: number, col: number): EdgeWidths {
    return {
      top: row % 3 === 0 ? 2 : 0.5,
      left: col % 3 === 0 ? 2 : 0.5,
      right: 0.5,
      bottom: 0.5
    };
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[DarkColors.gradientScreen[0], 0], [DarkColors.gradientScreen[1], 0.5], [DarkColors.gradientScreen[2], 1]] })

      Column() {
        GameHeader({
          gameTitle: '数独',
          showScore: false,
          showPause: false,
          subtitle: '点击格子 · 填入数字',
          difficulty: this.difficulty,
          onDifficultyChange: (d: GameDifficulty) => { this.changeDifficulty(d); },
          onBack: () => { this.getUIContext().getRouter().back(); },
          onPauseToggle: () => {},
          onRestart: () => { this.restartGame(); },
          onNewGame: () => { this.newGame(); },
          enableNewGame: true
        })

        // 外层容器：fill 空间、居中，供缩放容器摆放
        Column() {
          // 棋盘容器：自然大小 = 棋盘实际尺寸，缩放变换作用于此
          Column() {
            ForEach(this.idx9, (row: number) => {
              Row() {
                ForEach(this.idx9, (col: number) => {
                  Column() {
                    if (this.board[row][col] > 0) {
                      Text('' + this.board[row][col]).fontSize(Math.max(14, this.getCellSize() * 0.5))
                        .fontColor(this.getNumberColor(row, col))
                        .fontWeight(this.getNumberWeight(row, col))
                    }
                  }.width(this.getCellSize()).height(this.getCellSize())
                  .backgroundColor(this.getCellBg(row, col))
                  .border({
                    width: this.getCellBorderWidth(row, col),
                    color: DarkColors.boardBorder
                  })
                  .justifyContent(FlexAlign.Center)
                  .onClick(() => { this.selectedRow = row; this.selectedCol = col; })
                }, (col: number) => col.toString())
              }
            }, (row: number) => row.toString())
          }
          .scale({ x: this.scaleFactor, y: this.scaleFactor })
          .offset({ x: this.offsetX, y: this.offsetY })
          .gesture(
            GestureGroup(GestureMode.Parallel,
              PinchGesture({ fingers: 2 })
                .onActionStart((event: GestureEvent) => {
                  this.startScale = this.scaleFactor;
                  this.startOffsetX = this.offsetX;
                  this.startOffsetY = this.offsetY;
                })
                .onActionUpdate((event: GestureEvent) => {
                  const newScale = Math.max(1, Math.min(3, this.startScale * event.scale));
                  const cx = event.pinchCenterX;
                  const cy = event.pinchCenterY;
                  const half = this.boardPixelSize / 2;
                  // 以 pinchCenter 为锚点计算偏移：保持触摸中心在视觉上不动
                  this.offsetX = this.startOffsetX + (cx - half) * (this.startScale - newScale);
                  this.offsetY = this.startOffsetY + (cy - half) * (this.startScale - newScale);
                  this.scaleFactor = newScale;
                }),
              TapGesture({ count: 2 })
                .onAction(() => {
                  // 双击重置缩放
                  this.scaleFactor = 1;
                  this.offsetX = 0;
                  this.offsetY = 0;
                })
            )
          )
        }.layoutWeight(1).justifyContent(FlexAlign.Center).clip(true)

        Row({ space: SpacingTokens.sm }) {
          ForEach([1, 2, 3, 4, 5, 6, 7, 8, 9], (n: number) => {
            Button() {
              Text('' + n)
                .fontFamily(FontTokens.family)
                .fontSize(18)
                .fontWeight(FontTokens.weightMedium)
                .fontColor(DarkColors.textPrimary)
            }
            .layoutWeight(1).height(46)
            .backgroundColor(DarkColors.surface).borderRadius(RadiusTokens.base)
            .shadow(ShadowTokens.button)
            .onClick(() => this.setNumber(n))
          }, (n: number) => n.toString())
          Button() {
            SymbolGlyph($r('sys.symbol.xmark'))
              .fontSize(18).fontColor([DarkColors.textOnPrimary])
          }
          .width(46).height(46)
          .backgroundColor(DarkColors.error).borderRadius(RadiusTokens.base)
          .shadow(ShadowTokens.button)
          .onClick(() => this.erase())
        }.width('100%').padding({ left: SpacingTokens.base, right: SpacingTokens.base, bottom: SpacingTokens.lg })
      }.width('100%').height('100%')

      // 完成弹窗作为全屏遮罩层（原先内嵌在内容列中会撑破布局、超出屏幕）
      if (this.isComplete) {
        Column() {
          Column() {
            SymbolGlyph($r('sys.symbol.checkmark_circle'))
              .fontSize(40)
              .fontWeight(FontWeight.Medium)
              .fontColor([DarkColors.success])
          }
          .width(72).height(72)
          .borderRadius(RadiusTokens.full)
          .backgroundColor(DarkColors.primaryLight)
          .justifyContent(FlexAlign.Center)

          Text('恭喜完成!')
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold)
            .fontColor(DarkColors.textPrimary).margin({ top: SpacingTokens.md, bottom: SpacingTokens.base })
          Button() {
            Row({ space: SpacingTokens.xs }) {
              SymbolGlyph($r('sys.symbol.arrow_clockwise'))
                .fontSize(16).fontColor([DarkColors.textOnPrimary])
              Text('新游戏')
                .fontFamily(FontTokens.family)
                .fontSize(FontTokens.sizeBody).fontColor(DarkColors.textOnPrimary)
            }
          }
          .height(44).padding({ left: SpacingTokens.lg, right: SpacingTokens.lg })
          .backgroundColor(DarkColors.primary).borderRadius(RadiusTokens.full)
          .shadow(ShadowTokens.button)
          .onClick(() => this.newGame())
        }
        .width('100%').height('100%')
        .backgroundColor(DarkColors.scrim)
        .backdropBlur(20)
        .justifyContent(FlexAlign.Center)
      }
    }.width('100%').height('100%')
  }
}
