/**
 * 扫雷 - HarmonyOS 设计风格
 */
import { display } from '@kit.ArkUI';
import { DarkColors, RadiusTokens, FontTokens, ShadowTokens, SpacingTokens } from '../../common/DesignTokens';
import { GameHeader } from '../../components/GameHeader';
import { GameDifficulty } from '../../common/GameConstants';
import { GameDataManager } from '../../model/GameData';

const ROWS = 9;
const COLS = 9;

@Entry
@ComponentV2
struct MinesweeperPage {
  @Local board: number[][] = [];
  @Local revealed: boolean[][] = [];
  @Local flagged: boolean[][] = [];
  @Local isPlaying: boolean = true;
  @Local flagCount: number = 0;
  @Local difficulty: GameDifficulty = GameDifficulty.NORMAL;
  @Local elapsed: number = 0;
  @Local gameResult: boolean = false;
  @Local cellSize: number = 32;
  private timer: number = -1;
  private startTime: number = 0;
  private minesPlaced: boolean = false;
  private idx9: number[] = [0,1,2,3,4,5,6,7,8];

  aboutToAppear(): void {
    this.initCellSize();
    this.startGame();
  }
  aboutToDisappear(): void { clearInterval(this.timer); }

  initCellSize(): void {
    const d = display.getDefaultDisplaySync();
    const wVp = this.getUIContext().px2vp(d.width);
    this.cellSize = Math.max(24, Math.floor((Math.min(wVp, 520) - 20) / COLS));
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
    this.isPlaying = true;
    this.flagCount = 0;
    this.elapsed = 0;
    // 雷与计时都推迟到首次点击，保证首点安全
    this.minesPlaced = false;
    clearInterval(this.timer);
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
    this.timer = setInterval(() => {
      if (this.isPlaying) { this.elapsed = Math.floor((Date.now() - this.startTime) / 1000); }
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
    if (!this.isPlaying || this.revealed[r][c] || this.flagged[r][c]) { return; }
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
    if (!this.isPlaying || this.revealed[r][c]) { return; }
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
    this.isPlaying = false;
    clearInterval(this.timer);
    this.gameResult = won;
    if (won) {
      // 用时越短得分越高
      const score = Math.max(1, 1000 - this.elapsed * 5);
      GameDataManager.updateHighScore('minesweeper', score);
    }
  }

  getNumColor(v: number): string {
    if (v < 0 || v > 8) { return '#000000'; }
    const colors: string[] = ['#6B7280', '#3399FF', '#2DD482', '#FF6666', '#8675F8', '#FF6B6B', '#00D4B4', '#FFFFFF', '#6B7280'];
    return colors[v];
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[DarkColors.gradientScreen[0], 0], [DarkColors.gradientScreen[1], 0.5], [DarkColors.gradientScreen[2], 1]] })

      Column() {
        GameHeader({
          gameTitle: '扫雷',
          showScore: false,
          showPause: false,
          subtitle: '长按插旗 · 点击揭开',
          difficulty: this.difficulty,
          onDifficultyChange: (d: GameDifficulty) => { this.changeDifficulty(d); },
          onBack: () => { this.getUIContext().getRouter().back(); },
          onPauseToggle: () => {},
          onRestart: () => { this.startGame(); }
        })

        Row() {
          Column() {
            Row({ space: SpacingTokens.xs }) {
              SymbolGlyph($r('sys.symbol.flag_fill'))
                .fontSize(12).fontColor([DarkColors.warning])
              Text('旗帜').fontSize(FontTokens.sizeCaption).fontColor(DarkColors.textTertiary)
            }
            Text(this.flagCount + '/' + this.getMineCount()).fontSize(FontTokens.sizeHeadline)
              .fontWeight(FontTokens.weightBold).fontColor(DarkColors.warning)
          }.layoutWeight(1).padding(8).backgroundColor(DarkColors.surface)
          .borderRadius(RadiusTokens.base).alignItems(HorizontalAlign.Center).margin({ left: 16 })

          Column() {
            Row({ space: SpacingTokens.xs }) {
              SymbolGlyph($r('sys.symbol.clock'))
                .fontSize(12).fontColor([DarkColors.accent])
              Text('时间').fontSize(FontTokens.sizeCaption).fontColor(DarkColors.textTertiary)
            }
            Text(this.elapsed + 's').fontSize(FontTokens.sizeHeadline)
              .fontWeight(FontTokens.weightBold).fontColor(DarkColors.accent)
          }.layoutWeight(1).padding(8).backgroundColor(DarkColors.surface)
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
                  .backgroundColor(this.flagged[row][col] ? DarkColors.accentLight :
                    this.revealed[row][col] ? (this.board[row][col] === -1 ? DarkColors.error : DarkColors.cellRevealed) : DarkColors.cellHidden)
                  .border({ width: 1, color: DarkColors.boardBorder }).borderRadius(RadiusTokens.xs)
                  .onClick(() => { if (!this.flagged[row][col]) { this.reveal(row, col); } })
                  .gesture(LongPressGesture().onAction(() => this.toggleFlag(row, col)))
                })
              }
            })
          }.padding(2)
          .backgroundColor(DarkColors.boardBg).border({ width: 2, color: DarkColors.boardBorder, radius: RadiusTokens.md })
        }.layoutWeight(1).justifyContent(FlexAlign.Center)

        Text('长按插旗 · 点击揭开')
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeBodySmall).fontColor(DarkColors.textTertiary)
          .padding({ bottom: SpacingTokens.lg, top: SpacingTokens.xs })
      }.width('100%').height('100%')

      if (!this.isPlaying) {
        Column() {
          Column() {
            SymbolGlyph(this.gameResult ? $r('sys.symbol.checkmark_circle') : $r('sys.symbol.xmark_circle'))
              .fontSize(44)
              .fontWeight(FontWeight.Medium)
              .fontColor([this.gameResult ? DarkColors.success : DarkColors.error])
          }
          .width(76).height(76)
          .borderRadius(RadiusTokens.full)
          .backgroundColor(DarkColors.primaryLight)
          .justifyContent(FlexAlign.Center)

          Text(this.gameResult ? '扫雷成功!' : '踩到雷了')
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold)
            .fontColor(DarkColors.textPrimary).margin({ top: SpacingTokens.md, bottom: SpacingTokens.xs })
          Text(this.elapsed + ' 秒完成')
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeSubtitle)
            .fontColor(DarkColors.accent).margin({ bottom: SpacingTokens.lg })
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
            .onClick(() => this.startGame())
            Button('返回')
              .height(44).padding({ left: SpacingTokens.lg, right: SpacingTokens.lg })
              .fontFamily(FontTokens.family)
              .fontColor(DarkColors.textPrimary).backgroundColor(DarkColors.surface)
              .borderRadius(RadiusTokens.full).shadow(ShadowTokens.button)
              .onClick(() => this.getUIContext().getRouter().back())
          }
        }.width('100%').height('100%')
        .backgroundColor(DarkColors.scrim)
        .backdropBlur(20)
        .justifyContent(FlexAlign.Center)
      }
    }.width('100%').height('100%')
  }
}
