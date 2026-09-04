/**
 * 扫雷 - HarmonyOS 设计风格
 */
import { SemanticColors, RadiusTokens, FontTokens, ShadowTokens, SpacingTokens } from '../../common/DesignTokens';
import { GameHeader } from '../../components/GameHeader';
import { GameDifficulty, GameStatus } from '../../common/GameConstants';
import { GameDataManager } from '../../model/GameData';
import { SafeAreaInsets } from '../../common/SafeAreaInsets';
import { GameResultDialog } from '../../components/GameResultDialog';
import { ScreenUtils } from '../../common/ScreenUtils';
import { range } from '../../common/Range';

const ROWS = 9;
const COLS = 9;

@ComponentV2
export struct MinesweeperPage {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local safeBottom: number = SafeAreaInsets.bottom;
  @Local board: number[][] = [];
  @Local revealed: boolean[][] = [];
  @Local flagged: boolean[][] = [];
    /** 对局状态。本游戏无暂停玩法，只有 进行中 ⇄ 已结束 两态 */
@Local status: GameStatus = GameStatus.PLAYING;
  @Local flagCount: number = 0;
  @Local difficulty: GameDifficulty = GameDifficulty.NORMAL;
  @Local elapsed: number = 0;
  @Local gameResult: boolean = false;
  @Local cellSize: number = 32;
  private timer: number = -1;
  private startTime: number = 0;
  /** 计时是否已启动且尚未结束（用于区分「未开始计时」与「计时中被切后台暂停」） */
  private timerRunning: boolean = false;
  private minesPlaced: boolean = false;
  private idx9: number[] = range(COLS);

  aboutToAppear(): void {
    this.initCellSize();
    this.startGame();
  }
  aboutToDisappear(): void { clearInterval(this.timer); }

  /**
   * 切后台：暂停计时并清理定时器。
   * 扫雷没有暂停按钮，若不处理则 setInterval 在后台持续累加，
   * 切回来时用时已虚增，且「用时越短分越高」的计分会失真。
   */
  onPageHide(): void { this.pauseTimer(); }

  /** 回到前台：以已计时秒数为基准恢复计时 */
  onPageShow(): void { this.resumeTimer(); }

  pauseTimer(): void {
    if (!this.timerRunning) { return; }
    this.elapsed = Math.floor((Date.now() - this.startTime) / 1000);
    clearInterval(this.timer);
    this.timer = -1;
  }

  resumeTimer(): void {
    if (!this.timerRunning || this.timer !== -1) { return; }
    // 回拨起始时间，使恢复后接着已计时秒数继续，而非重新开始
    this.startTime = Date.now() - this.elapsed * 1000;
    this.timer = setInterval(() => {
      if (this.status === GameStatus.PLAYING) { this.elapsed = Math.floor((Date.now() - this.startTime) / 1000); }
    }, 1000);
  }

  initCellSize(): void {
    this.cellSize = ScreenUtils.calcCell(COLS, 520, 20, 24);
  }

  makeNumBoard(val: number): number[][] {
    const arr: number[][] = [];
    for (let i = 0; i < ROWS; i++) {
      const row: number[] = [];
      for (let j = 0; j < COLS; j++) { row[j] = val; }
      arr[i] = row;
    }
    return arr;
  }

  makeBoolBoard(): boolean[][] {
    const arr: boolean[][] = [];
    for (let i = 0; i < ROWS; i++) {
      const row: boolean[] = [];
      for (let j = 0; j < COLS; j++) { row[j] = false; }
      arr[i] = row;
    }
    return arr;
  }

  startGame(): void {
    GameDataManager.incrementPlayCount('minesweeper');
    this.board = this.makeNumBoard(0);
    this.revealed = this.makeBoolBoard();
    this.flagged = this.makeBoolBoard();
    this.status = GameStatus.PLAYING;
    this.flagCount = 0;
    this.elapsed = 0;
    // 雷与计时都推迟到首次点击，保证首点安全
    this.minesPlaced = false;
    this.timerRunning = false;
    clearInterval(this.timer);
    this.timer = -1;
  }

  placeMines(safeR: number, safeC: number): void {
    let mp = 0;
    while (mp < this.getMineCount()) {
      const r = Math.floor(Math.random() * ROWS);
      const c = Math.floor(Math.random() * COLS);
      // 排除首点格及其 3×3 邻域：首点必为 0，可直接展开一片
      if (Math.abs(r - safeR) <= 1 && Math.abs(c - safeC) <= 1) { continue; }
      if (this.board[r][c] !== -1) { this.board[r][c] = -1; mp++; }
    }
    for (let r = 0; r < ROWS; r++) {
      for (let c = 0; c < COLS; c++) {
        if (this.board[r][c] !== -1) { this.board[r][c] = this.countMines(r, c); }
      }
    }
  }

  startTimer(): void {
    clearInterval(this.timer);
    this.startTime = Date.now();
    this.timerRunning = true;
    this.timer = setInterval(() => {
      if (this.status === GameStatus.PLAYING) { this.elapsed = Math.floor((Date.now() - this.startTime) / 1000); }
    }, 1000);
  }

  getMineCount(): number {
    if (this.difficulty === GameDifficulty.EASY) { return 8; }
    if (this.difficulty === GameDifficulty.HARD) { return 14; }
    return 10;
  }

  changeDifficulty(d: GameDifficulty): void {
    if (this.difficulty === d) { return; }
    this.difficulty = d;
    this.startGame();
  }

  countMines(r: number, c: number): number {
    let cnt = 0;
    for (let dr = -1; dr <= 1; dr++) {
      for (let dc = -1; dc <= 1; dc++) {
        const nr = r + dr;
        const nc = c + dc;
        if (nr >= 0 && nr < ROWS && nc >= 0 && nc < COLS && this.board[nr][nc] === -1) {
          cnt++;
        }
      }
    }
    return cnt;
  }

  reveal(r: number, c: number): void {
    if (this.status !== GameStatus.PLAYING || this.revealed[r][c] || this.flagged[r][c]) { return; }
    if (!this.minesPlaced) {
      this.placeMines(r, c);
      this.minesPlaced = true;
      this.startTimer();
    }
    const nr = this.copyBoolBoard(this.revealed);
    nr[r][c] = true;
    if (this.board[r][c] === -1) { this.revealed = nr; this.gameOver(false); return; }
    if (this.board[r][c] === 0) {
      const q: number[][] = [[r, c]];
      while (q.length > 0) {
        const p = q.shift()!;
        const cr = p[0];
        const cc = p[1];
        for (let dr = -1; dr <= 1; dr++) {
          for (let dc = -1; dc <= 1; dc++) {
            const nr2 = cr + dr;
            const nc2 = cc + dc;
            if (nr2 >= 0 && nr2 < ROWS && nc2 >= 0 && nc2 < COLS && !nr[nr2][nc2] && !this.flagged[nr2][nc2]) {
              nr[nr2][nc2] = true;
              if (this.board[nr2][nc2] === 0) { q.push([nr2, nc2]); }
            }
          }
        }
      }
    }
    this.revealed = nr;
    this.checkWin();
  }

  copyBoolBoard(src: boolean[][]): boolean[][] {
    const arr: boolean[][] = [];
    for (let i = 0; i < src.length; i++) {
      const row: boolean[] = [];
      for (let j = 0; j < src[i].length; j++) { row[j] = src[i][j]; }
      arr[i] = row;
    }
    return arr;
  }

  toggleFlag(r: number, c: number): void {
    if (this.status !== GameStatus.PLAYING || this.revealed[r][c]) { return; }
    const nf = this.copyBoolBoard(this.flagged);
    nf[r][c] = !nf[r][c];
    this.flagged = nf;
    let cnt = 0;
    for (let i = 0; i < nf.length; i++) {
      for (let j = 0; j < nf[i].length; j++) {
        if (nf[i][j]) { cnt++; }
      }
    }
    this.flagCount = cnt;
    this.checkWin();
  }

  checkWin(): void {
    // 经典规则：揭开全部安全格即获胜（原实现还要求给所有雷插旗，导致几乎无法获胜）
    let won = true;
    for (let r = 0; r < ROWS; r++) {
      for (let c = 0; c < COLS; c++) {
        if (this.board[r][c] !== -1 && !this.revealed[r][c]) { won = false; break; }
      }
      if (!won) { break; }
    }
    if (won) { this.gameOver(true); }
  }

  gameOver(won: boolean): void {
    this.status = GameStatus.OVER;
    this.timerRunning = false;
    clearInterval(this.timer);
    this.timer = -1;
    this.gameResult = won;
    if (won) {
      // 用时越短得分越高
      const score = Math.max(1, 1000 - this.elapsed * 5);
      GameDataManager.updateHighScore('minesweeper', score);
    }
  }

  /**
   * 雷数提示色。原为字面量数组，其中数字 7 用的是纯白（#FFFFFF）——
   * 亮色模式下格子底色是浅蓝白（cell_revealed #F2F6FD），白字完全不可见。
   * 已收编为资源，两套主题各自给出可读的配色；越界值也由黑色改为 error 色，
   * 避免在深色底上「黑字配深底」同样看不见。
   */
  getNumColor(v: number): ResourceColor {
    if (v < 0 || v > 8) { return $r('app.color.mine_num_invalid'); }
    const colors: ResourceColor[] = [
      $r('app.color.mine_num_0'),
      $r('app.color.mine_num_1'),
      $r('app.color.mine_num_2'),
      $r('app.color.mine_num_3'),
      $r('app.color.mine_num_4'),
      $r('app.color.mine_num_5'),
      $r('app.color.mine_num_6'),
      $r('app.color.mine_num_7'),
      $r('app.color.mine_num_8')
    ];
    return colors[v];
  }

  getCellBg(row: number, col: number): ResourceColor {
    if (this.flagged[row][col]) { return SemanticColors.accentLight; }
    if (this.revealed[row][col]) {
      if (this.board[row][col] === -1) { return SemanticColors.error; }
      return SemanticColors.cellRevealed;
    }
    return SemanticColors.cellHidden;
  }

  getResultSymbol(): Resource {
    if (this.gameResult) { return $r('sys.symbol.checkmark_circle'); }
    return $r('sys.symbol.xmark_circle');
  }

  getResultColor(): Resource {
    if (this.gameResult) { return SemanticColors.success; }
    return SemanticColors.error;
  }

  getResultText(): string {
    if (this.gameResult) { return '扫雷成功!'; }
    return '踩到雷了';
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[SemanticColors.gradientScreen[0], 0], [SemanticColors.gradientScreen[1], 0.5], [SemanticColors.gradientScreen[2], 1]] })

      Column() {
        GameHeader({
          gameTitle: '扫雷',
          showScore: false,
          showPause: false,
          subtitle: '长按插旗 · 点击揭开',
          difficulty: this.difficulty,
          onDifficultyChange: (d: GameDifficulty) => { this.changeDifficulty(d); },
          onBack: () => { this.pathStack.pop(); },
          onPauseToggle: () => {},
          onRestart: () => { this.startGame(); }
        })

        Row() {
          Column() {
            Row({ space: SpacingTokens.xs }) {
              SymbolGlyph($r('sys.symbol.flag_fill'))
                .fontSize(12).fontColor([SemanticColors.warning])
              Text('旗帜').fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textTertiary)
            }
            Text(this.flagCount + '/' + this.getMineCount()).fontSize(FontTokens.sizeHeadline)
              .fontWeight(FontTokens.weightBold).fontColor(SemanticColors.warning)
          }.layoutWeight(1).padding(8).backgroundColor(SemanticColors.surface)
          .borderRadius(RadiusTokens.base).alignItems(HorizontalAlign.Center).margin({ left: 16 })

          Column() {
            Row({ space: SpacingTokens.xs }) {
              SymbolGlyph($r('sys.symbol.clock'))
                .fontSize(12).fontColor([SemanticColors.accent])
              Text('时间').fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textTertiary)
            }
            Text(this.elapsed + 's').fontSize(FontTokens.sizeHeadline)
              .fontWeight(FontTokens.weightBold).fontColor(SemanticColors.accent)
          }.layoutWeight(1).padding(8).backgroundColor(SemanticColors.surface)
          .borderRadius(RadiusTokens.base).alignItems(HorizontalAlign.Center).margin({ left: 8, right: 16 })
        }.margin({ top: 12, bottom: 12 })

        Column() {
          Column() {
            ForEach(this.idx9, (row: number) => {
              Row() {
                ForEach(this.idx9, (col: number) => {
                  Column() {
                    if (this.revealed[row][col]) {
                      if (this.board[row][col] === -1) {
                        Text('💣').fontSize(Math.max(14, this.cellSize * 0.5))
                      } else if (this.board[row][col] > 0) {
                        Text('' + this.board[row][col]).fontSize(Math.max(14, this.cellSize * 0.5)).fontWeight(FontWeight.Bold)
                          .fontColor(this.getNumColor(this.board[row][col]))
                      }
                    } else if (this.flagged[row][col]) {
                      Text('🚩').fontSize(Math.max(14, this.cellSize * 0.5))
                    }
                  }.width(this.cellSize).height(this.cellSize)
                  .backgroundColor(this.getCellBg(row, col))
                  .border({ width: 1, color: SemanticColors.boardBorder }).borderRadius(RadiusTokens.xs)
                  .onClick(() => { if (!this.flagged[row][col]) { this.reveal(row, col); } })
                  .gesture(LongPressGesture().onAction(() => this.toggleFlag(row, col)))
                }, (col: number) => col.toString())
              }
            }, (row: number) => row.toString())
          }.padding(2)
          .backgroundColor(SemanticColors.boardBg).border({ width: 2, color: SemanticColors.boardBorder, radius: RadiusTokens.md })
        }.layoutWeight(1).justifyContent(FlexAlign.Center)

        Text('长按插旗 · 点击揭开')
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeBodySmall).fontColor(SemanticColors.textTertiary)
          .padding({ bottom: SpacingTokens.lg, top: SpacingTokens.xs })
      }.width('100%').height('100%').padding({ bottom: this.safeBottom })

      if (this.status !== GameStatus.PLAYING) {
        GameResultDialog({
          symbol: this.getResultSymbol(),
          symbolColor: this.getResultColor(),
          title: this.getResultText(),
          detail: this.elapsed + ' 秒完成',
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
