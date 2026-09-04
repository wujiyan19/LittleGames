/**
 * 数独 - HarmonyOS 设计风格（带双指缩放）
 */
import { SemanticColors, RadiusTokens, FontTokens, ShadowTokens, SpacingTokens } from '../../common/DesignTokens';
import { GameHeader } from '../../components/GameHeader';
import { GameDifficulty, GameStatus } from '../../common/GameConstants';
import { GameDataManager } from '../../model/GameData';
import { SafeAreaInsets } from '../../common/SafeAreaInsets';
import { GameResultDialog } from '../../components/GameResultDialog';
import { ScreenUtils } from '../../common/ScreenUtils';
import { range } from '../../common/Range';

@ComponentV2
export struct SudokuPage {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local safeBottom: number = SafeAreaInsets.bottom;
  // 棋盘用「长度为 81 的一维数组」保存：二维数组的 board[r][c] = n 内层赋值无法被状态管理观测到，
  // 改了数据但界面不刷新。一维数组配合整体赋值（copy-on-write）可稳定触发重渲染。
  @Local board: number[] = [];
  @Local selectedRow: number = -1;
  @Local selectedCol: number = -1;
    /** 对局状态。本游戏无暂停玩法，只有 进行中 ⇄ 已结束 两态 */
@Local status: GameStatus = GameStatus.PLAYING;
  @Local scaleFactor: number = 1;
  @Local offsetX: number = 0;
  @Local offsetY: number = 0;
  @Local boardPixelSize: number = 302;
  @Local difficulty: GameDifficulty = GameDifficulty.NORMAL;
  // 题面固定格（Given），整局不变，无需参与渲染观测
  private fixed: boolean[] = [];
  private idx9: number[] = range(9);
  private startScale: number = 1;
  private startOffsetX: number = 0;
  private startOffsetY: number = 0;
  // 当前题面（用于「重新开始」还原）
  private puzzle: number[] = [];
  // 上一把题面指纹，保证「新游戏」不与上一把相同
  private previousKey: string = '';
  // 唯一解校验计数
  private solutionCount: number = 0;
  // ── 位掩码求解器状态 ──
  // 第 v-1 位为 1 表示该行/列/宫已经用过数字 v，候选集可由三次按位或一次取反得到。
  // 原实现每个候选都要扫 27 格（canPlaceAt），困难档生成要跑上万次，是卡顿的根因。
  private rowMask: Int32Array = new Int32Array(9);
  private colMask: Int32Array = new Int32Array(9);
  private boxMask: Int32Array = new Int32Array(9);
  // 掩码 → 数字（下标为 1<<(v-1)）
  private bitToVal: Int8Array = new Int8Array(512);
  // 掩码 → 其中 1 的个数
  private popCount: Int8Array = new Int8Array(512);
  // 格子下标 → 所属宫
  private boxOf: Int8Array = new Int8Array(81);

  aboutToAppear(): void {
    this.initLookupTables();
    this.initBoardSize();
    this.newGame();
  }

  initLookupTables(): void {
    for (let i = 0; i < 81; i++) {
      this.boxOf[i] = Math.floor(i / 27) * 3 + Math.floor((i % 9) / 3);
    }
    for (let m = 1; m < 512; m++) {
      this.popCount[m] = this.popCount[m >> 1] + (m & 1);
    }
    for (let v = 1; v <= 9; v++) {
      this.bitToVal[1 << (v - 1)] = v;
    }
  }

  initBoardSize(): void {
    const cell = ScreenUtils.calcCell(9, 520, 24, 28);
    this.boardPixelSize = cell * 9 + 8;
  }

  getCellSize(): number {
    return (this.boardPixelSize - 8) / 9;
  }

  makeBoard(val: number): number[] {
    const arr: number[] = [];
    for (let i = 0; i < 81; i++) { arr[i] = val; }
    return arr;
  }

  makeBoolBoard(): boolean[] {
    const arr: boolean[] = [];
    for (let i = 0; i < 81; i++) { arr[i] = false; }
    return arr;
  }

  cellIndex(row: number, col: number): number {
    return row * 9 + col;
  }

  cellValue(row: number, col: number): number {
    return this.board[this.cellIndex(row, col)];
  }

  isCellFixed(row: number, col: number): boolean {
    return this.fixed[this.cellIndex(row, col)];
  }

  newGame(): void {
    this.startGame(this.generatePuzzle());
  }

  restartGame(): void {
    this.startGame(this.puzzle);
  }

  startGame(puzzle: number[]): void {
    GameDataManager.incrementPlayCount('sudoku');
    const flatBoard: number[] = this.makeBoard(0);
    const flatFixed: boolean[] = this.makeBoolBoard();
    for (let i = 0; i < 81; i++) {
      flatBoard[i] = puzzle[i];
      flatFixed[i] = puzzle[i] !== 0;
    }
    // 先在本地填好再整体赋值，只触发一次重渲染
    this.board = flatBoard;
    this.fixed = flatFixed;
    this.puzzle = this.copyBoard(puzzle);
    this.status = GameStatus.PLAYING;
    this.selectedRow = -1;
    this.selectedCol = -1;
    // 重置缩放
    this.scaleFactor = 1;
    this.offsetX = 0;
    this.offsetY = 0;
  }

  copyBoard(src: number[]): number[] {
    const dst: number[] = [];
    for (let i = 0; i < 81; i++) { dst[i] = src[i]; }
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

  // 依据当前棋盘重建行/列/宫占用掩码
  buildMasks(grid: number[]): void {
    for (let i = 0; i < 9; i++) {
      this.rowMask[i] = 0;
      this.colMask[i] = 0;
      this.boxMask[i] = 0;
    }
    for (let i = 0; i < 81; i++) {
      const v = grid[i];
      if (v === 0) { continue; }
      const bit = 1 << (v - 1);
      const b = this.boxOf[i];
      this.rowMask[Math.floor(i / 9)] = this.rowMask[Math.floor(i / 9)] | bit;
      this.colMask[i % 9] = this.colMask[i % 9] | bit;
      this.boxMask[b] = this.boxMask[b] | bit;
    }
  }

  // 某格的候选集掩码：三个方向已占用位的并集取反，低 9 位有效
  candidateMask(idx: number): number {
    return (~(this.rowMask[Math.floor(idx / 9)] | this.colMask[idx % 9] | this.boxMask[this.boxOf[idx]])) & 0x1FF;
  }

  // 回溯填满一个完整解（MRV 选格）。成功返回时掩码保留终局状态，调用方需自行重建
  fillSolutionBit(grid: number[]): boolean {
    let idx = -1;
    let bestMask = 0;
    let bestLen = 10;
    for (let i = 0; i < 81; i++) {
      if (grid[i] !== 0) { continue; }
      const mask = this.candidateMask(i);
      if (mask === 0) { return false; }
      const len = this.popCount[mask];
      if (len < bestLen) {
        bestLen = len; idx = i; bestMask = mask;
        if (len === 1) { break; }
      }
    }
    if (idx === -1) { return true; }
    const r = Math.floor(idx / 9);
    const c = idx % 9;
    const b = this.boxOf[idx];
    const order = this.shuffled9();
    for (let k = 0; k < order.length; k++) {
      const v = order[k];
      const bit = 1 << (v - 1);
      if ((bestMask & bit) === 0) { continue; }
      grid[idx] = v;
      this.rowMask[r] = this.rowMask[r] | bit;
      this.colMask[c] = this.colMask[c] | bit;
      this.boxMask[b] = this.boxMask[b] | bit;
      if (this.fillSolutionBit(grid)) { return true; }
      grid[idx] = 0;
      this.rowMask[r] = this.rowMask[r] ^ bit;
      this.colMask[c] = this.colMask[c] ^ bit;
      this.boxMask[b] = this.boxMask[b] ^ bit;
    }
    return false;
  }

  generateSolution(): number[] {
    const board = this.makeBoard(0);
    this.buildMasks(board);
    this.fillSolutionBit(board);
    return board;
  }

  // 数解的个数，找到 2 个就提前退出（唯一解校验只需知道是否 > 1）
  solveCountBit(grid: number[]): void {
    if (this.solutionCount > 1) { return; }
    let bestIdx = -1;
    let bestMask = 0;
    let bestLen = 10;
    for (let i = 0; i < 81; i++) {
      if (grid[i] !== 0) { continue; }
      const mask = this.candidateMask(i);
      if (mask === 0) { return; }
      const len = this.popCount[mask];
      if (len < bestLen) {
        bestLen = len; bestIdx = i; bestMask = mask;
        if (len === 1) { break; }
      }
    }
    if (bestIdx === -1) {
      this.solutionCount++;
      return;
    }
    const r = Math.floor(bestIdx / 9);
    const c = bestIdx % 9;
    const b = this.boxOf[bestIdx];
    let m = bestMask;
    while (m !== 0) {
      const bit = m & (-m);
      m = m ^ bit;
      const v = this.bitToVal[bit];
      grid[bestIdx] = v;
      this.rowMask[r] = this.rowMask[r] | bit;
      this.colMask[c] = this.colMask[c] | bit;
      this.boxMask[b] = this.boxMask[b] | bit;
      this.solveCountBit(grid);
      grid[bestIdx] = 0;
      this.rowMask[r] = this.rowMask[r] ^ bit;
      this.colMask[c] = this.colMask[c] ^ bit;
      this.boxMask[b] = this.boxMask[b] ^ bit;
      if (this.solutionCount > 1) { return; }
    }
  }

  countSolutions(grid: number[]): number {
    this.solutionCount = 0;
    const work = this.copyBoard(grid);
    this.buildMasks(work);
    this.solveCountBit(work);
    return this.solutionCount;
  }

  getTargetClues(): number {
    if (this.difficulty === GameDifficulty.EASY) { return 45; }
    if (this.difficulty === GameDifficulty.HARD) { return 23; }
    return 29;
  }

  boardKey(grid: number[]): string {
    let key = '';
    for (let i = 0; i < 81; i++) {
      key += grid[i].toString();
    }
    return key;
  }

  generatePuzzle(): number[] {
    const targetClues = this.getTargetClues();
    let last: number[] = [];
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
        const idx = cells[k];
        const saved = candidate[idx];
        candidate[idx] = 0;
        if (this.countSolutions(candidate) !== 1) {
          candidate[idx] = saved;
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
    // 指纹必须取自真正返回的题面：此前记的是 last（最后一次候选），
    // 与实际返回的 fallback 不一致，导致去重失效、下一把仍可能重复。
    const fb: number[] = this.fallbackPuzzle();
    this.previousKey = this.boardKey(fb);
    return fb;
  }

  fallbackPuzzle(): number[] {
    if (this.difficulty === GameDifficulty.EASY) {
      // 简单：45 个提示（按行展开的一维棋盘）
      return [
        5, 3, 4, 6, 7, 8, 9, 1, 2, 6, 7, 2, 1, 9, 5, 3, 4, 8, 1, 9, 8, 3, 4, 2, 5, 6, 7,
        8, 5, 9, 7, 6, 1, 4, 2, 3, 0, 0, 6, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 6,
        0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 9, 0, 0, 5, 0, 0, 0, 0, 8, 0, 0, 7, 9
      ];
    }
    if (this.difficulty === GameDifficulty.HARD) {
      // 困难：23 个提示
      return [
        0, 0, 0, 0, 7, 0, 0, 0, 0, 6, 0, 0, 1, 0, 5, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 6, 0,
        8, 0, 0, 0, 0, 0, 0, 0, 3, 4, 0, 0, 8, 0, 3, 0, 0, 1, 7, 0, 0, 0, 2, 0, 0, 0, 6,
        0, 6, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 4, 1, 9, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 7, 9
      ];
    }
    // 普通：30 个提示（原有题面）
    return [
      5, 3, 0, 0, 7, 0, 0, 0, 0, 6, 0, 0, 1, 9, 5, 0, 0, 0, 0, 9, 8, 0, 0, 0, 0, 6, 0,
      8, 0, 0, 0, 6, 0, 0, 0, 3, 4, 0, 0, 8, 0, 3, 0, 0, 1, 7, 0, 0, 0, 2, 0, 0, 0, 6,
      0, 6, 0, 0, 0, 0, 2, 8, 0, 0, 0, 0, 4, 1, 9, 0, 0, 5, 0, 0, 0, 0, 8, 0, 0, 7, 9
    ];
  }

  changeDifficulty(d: GameDifficulty): void {
    if (this.difficulty === d) { return; }
    this.difficulty = d;
    this.newGame();
  }

  // copy-on-write 更新单个格子：整体赋值必定被 @Local 观测到
  setCellValue(index: number, value: number): void {
    const next: number[] = [];
    for (let i = 0; i < 81; i++) { next[i] = this.board[i]; }
    next[index] = value;
    this.board = next;
  }

  setNumber(n: number): void {
    const r = this.selectedRow;
    const c = this.selectedCol;
    if (r < 0 || c < 0 || this.status === GameStatus.OVER) { return; }
    const idx = this.cellIndex(r, c);
    if (this.fixed[idx]) { return; }
    this.setCellValue(idx, n);
    this.checkComplete();
  }

  erase(): void {
    const r = this.selectedRow;
    const c = this.selectedCol;
    if (r < 0 || c < 0) { return; }
    const idx = this.cellIndex(r, c);
    if (this.fixed[idx]) { return; }
    this.setCellValue(idx, 0);
  }

  checkComplete(): void {
    for (let r = 0; r < 9; r++) {
      for (let c = 0; c < 9; c++) {
        const v = this.cellValue(r, c);
        if (v === 0 || !this.isValid(r, c, v)) { return; }
      }
    }
    this.status = GameStatus.OVER;
    // 难度越高完成得分越高
    let score = 100;
    if (this.difficulty === GameDifficulty.NORMAL) { score = 200; }
    else if (this.difficulty === GameDifficulty.HARD) { score = 300; }
    GameDataManager.updateHighScore('sudoku', score);
  }

  isValid(r: number, c: number, v: number): boolean {
    for (let i = 0; i < 9; i++) {
      if (i !== c && this.cellValue(r, i) === v) { return false; }
      if (i !== r && this.cellValue(i, c) === v) { return false; }
    }
    const br = Math.floor(r / 3) * 3;
    const bc = Math.floor(c / 3) * 3;
    for (let i = br; i < br + 3; i++) {
      for (let j = bc; j < bc + 3; j++) {
        if ((i !== r || j !== c) && this.cellValue(i, j) === v) { return false; }
      }
    }
    return true;
  }

  getNumberColor(row: number, col: number): ResourceColor {
    if (this.isCellFixed(row, col)) { return SemanticColors.warning; }
    return SemanticColors.textPrimary;
  }

  getNumberWeight(row: number, col: number): FontWeight {
    if (this.isCellFixed(row, col)) { return FontWeight.Bold; }
    return FontWeight.Regular;
  }

  getCellBg(row: number, col: number): ResourceColor {
    if (this.selectedRow === row && this.selectedCol === col) { return SemanticColors.accent; }
    if ((Math.floor(row / 3) + Math.floor(col / 3)) % 2 === 0) { return SemanticColors.cellHidden; }
    return SemanticColors.cellRevealed;
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
        .linearGradient({ angle: 180, colors: [[SemanticColors.gradientScreen[0], 0], [SemanticColors.gradientScreen[1], 0.5], [SemanticColors.gradientScreen[2], 1]] })

      Column() {
        GameHeader({
          gameTitle: '数独',
          showScore: false,
          showPause: false,
          subtitle: '点击格子 · 填入数字',
          difficulty: this.difficulty,
          onDifficultyChange: (d: GameDifficulty) => { this.changeDifficulty(d); },
          onBack: () => { this.pathStack.pop(); },
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
                    if (this.cellValue(row, col) > 0) {
                      Text('' + this.cellValue(row, col)).fontSize(Math.max(14, this.getCellSize() * 0.5))
                        .fontColor(this.getNumberColor(row, col))
                        .fontWeight(this.getNumberWeight(row, col))
                    }
                  }.width(this.getCellSize()).height(this.getCellSize())
                  .backgroundColor(this.getCellBg(row, col))
                  .border({
                    width: this.getCellBorderWidth(row, col),
                    color: SemanticColors.boardBorder
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
                .fontColor(SemanticColors.textPrimary)
            }
            .layoutWeight(1).height(46)
            .backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base)
            .shadow(ShadowTokens.button)
            .onClick(() => this.setNumber(n))
          }, (n: number) => n.toString())
          Button() {
            SymbolGlyph($r('sys.symbol.xmark'))
              .fontSize(18).fontColor([SemanticColors.textOnPrimary])
          }
          .width(46).height(46)
          .backgroundColor(SemanticColors.error).borderRadius(RadiusTokens.base)
          .shadow(ShadowTokens.button)
          .onClick(() => this.erase())
        }.width('100%').padding({ left: SpacingTokens.base, right: SpacingTokens.base, bottom: SpacingTokens.lg })
      }.width('100%').height('100%').padding({ bottom: this.safeBottom })

      // 完成弹窗作为全屏遮罩层（原先内嵌在内容列中会撑破布局、超出屏幕）
      if (this.status === GameStatus.OVER) {
        GameResultDialog({
          symbol: $r('sys.symbol.checkmark_circle'),
          symbolColor: SemanticColors.success,
          title: '恭喜完成!',
          primaryText: '新游戏',
          onPrimary: () => { this.newGame(); }
        })
      }
    }.width('100%').height('100%')
  }
}
