/**
 * 滑动拼图 - HarmonyOS 设计风格
 */
import { display } from '@kit.ArkUI';
import { DarkColors, RadiusTokens, FontTokens, ShadowTokens, SpacingTokens } from '../../common/DesignTokens';
import { GameHeader } from '../../components/GameHeader';
import { GameDifficulty } from '../../common/GameConstants';
import { GameDataManager } from '../../model/GameData';

@Entry
@ComponentV2
struct SlidePuzzlePage {
  @Local board: number[][] = [];
  @Local steps: number = 0;
  @Local isComplete: boolean = false;
  @Local best: number = 999;
  @Local cell: number = 85;
  @Local difficulty: GameDifficulty = GameDifficulty.EASY;
  private idxN: number[] = [0, 1, 2];

  aboutToAppear(): void {
    const hs = GameDataManager.getGameById('slidepuzzle')?.highScore ?? 0;
    this.best = hs > 0 ? Math.max(1, 1000 - hs) : 999;
    this.initCellSize();
    this.startGame();
  }

  initCellSize(): void {
    const d = display.getDefaultDisplaySync();
    const wVp = this.getUIContext().px2vp(d.width);
    this.cell = Math.max(40, Math.floor((Math.min(wVp, 520) - 40) / this.getSize()));
  }

  getSize(): number {
    if (this.difficulty === GameDifficulty.EASY) { return 3; }
    if (this.difficulty === GameDifficulty.HARD) { return 5; }
    return 4;
  }

  changeDifficulty(d: GameDifficulty): void {
    if (this.difficulty === d) { return; }
    this.difficulty = d;
    this.initCellSize();
    this.startGame();
  }

  startGame(): void {
    GameDataManager.incrementPlayCount('slidepuzzle');
    const n = this.getSize();
    this.idxN = [];
    for (let i = 0; i < n; i++) { this.idxN.push(i); }
    const nums: number[] = [];
    for (let i = 1; i < n * n; i++) { nums.push(i); }
    nums.push(0);
    let attempts = 0;
    do {
      for (let i = nums.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        const tmp = nums[i];
        nums[i] = nums[j];
        nums[j] = tmp;
      }
      attempts++;
    } while (!this.isSolvable(nums) && attempts < 100);
    this.board = [];
    for (let r = 0; r < n; r++) {
      const row: number[] = [];
      for (let c = 0; c < n; c++) { row.push(nums[r * n + c]); }
      this.board.push(row);
    }
    this.steps = 0;
    this.isComplete = false;
  }

  isSolvable(arr: number[]): boolean {
    let inv = 0;
    const flat: number[] = [];
    for (let i = 0; i < arr.length; i++) { if (arr[i] !== 0) { flat.push(arr[i]); } }
    for (let i = 0; i < flat.length; i++) {
      for (let j = i + 1; j < flat.length; j++) {
        if (flat[i] > flat[j]) { inv++; }
      }
    }
    const n = this.getSize();
    if (n % 2 === 0) {
      // 偶数宽度棋盘：逆序数 + 空格从底部数的行号 为奇数时才有解。
      // 原实现写成 === 0（偶数）恰好反了，导致 4x4 普通难度生成的局面全部无解
      const blankRowFromBottom = n - Math.floor(arr.indexOf(0) / n);
      return (inv + blankRowFromBottom) % 2 === 1;
    }
    return inv % 2 === 0;
  }

  findZeroRow(): number {
    for (let i = 0; i < this.board.length; i++) {
      for (let j = 0; j < this.board[i].length; j++) {
        if (this.board[i][j] === 0) { return i; }
      }
    }
    return -1;
  }
  findZeroCol(): number {
    for (let i = 0; i < this.board.length; i++) {
      for (let j = 0; j < this.board[i].length; j++) {
        if (this.board[i][j] === 0) { return j; }
      }
    }
    return -1;
  }

  tapCell(r: number, c: number): void {
    if (this.isComplete) { return; }
    const zr = this.findZeroRow();
    const zc = this.findZeroCol();
    const dr = Math.abs(r - zr);
    const dc = Math.abs(c - zc);
    if ((dr === 1 && dc === 0) || (dr === 0 && dc === 1)) {
      this.board[zr][zc] = this.board[r][c];
      this.board[r][c] = 0;
      this.steps++;
      this.checkWin();
    }
  }

  checkWin(): void {
    const n = this.getSize();
    let ok = true;
    for (let i = 0; i < n; i++) {
      for (let j = 0; j < n; j++) {
        if (i === n - 1 && j === n - 1) {
          if (this.board[i][j] !== 0) { ok = false; }
        } else if (this.board[i][j] !== i * n + j + 1) {
          ok = false;
        }
      }
    }
    if (ok) {
      this.isComplete = true;
      if (this.steps < this.best) { this.best = this.steps; }
      // 步数越少得分越高
      GameDataManager.updateHighScore('slidepuzzle', Math.max(1, 1000 - this.steps));
    }
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[DarkColors.gradientScreen[0], 0], [DarkColors.gradientScreen[1], 0.5], [DarkColors.gradientScreen[2], 1]] })

      Column() {
        GameHeader({ gameTitle: '滑动拼图',
          showScore: false,
          showPause: false,
          subtitle: '移动方块还原顺序',
          difficulty: this.difficulty,
          onDifficultyChange: (d: GameDifficulty) => { this.changeDifficulty(d); },
          onBack: () => { this.getUIContext().getRouter().back(); },
          onPauseToggle: () => {},
          onRestart: () => { this.startGame(); } })

        Row() {
          Column() {
            Text('步数').fontSize(FontTokens.sizeCaption).fontColor(DarkColors.textTertiary)
            Text('' + this.steps).fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold).fontColor(DarkColors.accent)
          }.layoutWeight(1).padding(8).backgroundColor(DarkColors.surface).borderRadius(RadiusTokens.base)
          .alignItems(HorizontalAlign.Center).margin({ left: 16 })
          Column() {
            Text('最佳').fontSize(FontTokens.sizeCaption).fontColor(DarkColors.textTertiary)
            Text(this.best === 999 ? '--' : '' + this.best).fontSize(FontTokens.sizeHeadline)
              .fontWeight(FontTokens.weightBold).fontColor(DarkColors.textPrimary)
          }.layoutWeight(1).padding(8).backgroundColor(DarkColors.surface).borderRadius(RadiusTokens.base)
          .alignItems(HorizontalAlign.Center).margin({ left: 8, right: 16 })
        }.margin({ top: 12, bottom: 12 })

        Column() {
          Column() {
            ForEach(this.idxN, (r: number) => {
              Row() {
                ForEach(this.idxN, (c: number) => {
                  Column() {
                    if (this.board[r][c] > 0) {
                      Text('' + this.board[r][c]).fontSize(Math.max(22, this.cell * 0.34))
                        .fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                    }
                  }.width(this.cell).height(this.cell).margin(2)
                  .backgroundColor(this.board[r][c] === 0 ? DarkColors.boardBg :
                    this.board[r][c] === r * this.getSize() + c + 1 ? DarkColors.success : DarkColors.accent)
                  .borderRadius(RadiusTokens.base)
                  .shadow(ShadowTokens.button)
                  .opacity(this.board[r][c] === 0 ? 0 : 1)
                  .onClick(() => this.tapCell(r, c))
                })
              }
            })
          }.backgroundColor(DarkColors.boardBg).borderRadius(RadiusTokens.base).padding(4)
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
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

          Text('拼图完成!')
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold)
            .fontColor(DarkColors.textPrimary).margin({ top: SpacingTokens.md, bottom: SpacingTokens.xs })
          Text('步数: ' + this.steps)
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeSubtitle).fontColor(DarkColors.accent)
            .margin({ bottom: SpacingTokens.base })
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
        }
        .width('100%').height('100%')
        .backgroundColor(DarkColors.scrim)
        .backdropBlur(20)
        .justifyContent(FlexAlign.Center)
      }
    }.width('100%').height('100%')
  }
}
