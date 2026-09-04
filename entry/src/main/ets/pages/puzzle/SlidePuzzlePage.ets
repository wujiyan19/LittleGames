/**
 * 滑动拼图 - HarmonyOS 设计风格
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
export struct SlidePuzzlePage {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local safeBottom: number = SafeAreaInsets.bottom;
  // 棋盘为长度 n*n 的一维数组：二维数组的 board[r][c] = v 内层赋值观测不到，
  // 会导致移动后方块位置不刷新
  @Local board: number[] = [];
  @Local steps: number = 0;
    /** 对局状态。本游戏无暂停玩法，只有 进行中 ⇄ 已结束 两态 */
@Local status: GameStatus = GameStatus.PLAYING;
  @Local best: number = 999;
  @Local cell: number = 85;
  @Local difficulty: GameDifficulty = GameDifficulty.EASY;
  private idxN: number[] = range(3);

  aboutToAppear(): void {
    const hs = GameDataManager.getGameById('slidepuzzle')?.highScore ?? 0;
    this.best = hs > 0 ? Math.max(1, 1000 - hs) : 999;
    this.initCellSize();
    this.startGame();
  }

  initCellSize(): void {
    this.cell = ScreenUtils.calcCell(this.getSize(), 520, 40, 40);
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
    this.idxN = range(n);
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
    // 先在本地组装好再整体赋值，只触发一次重渲染
    const flat: number[] = [];
    for (let i = 0; i < n * n; i++) { flat.push(nums[i]); }
    this.board = flat;
    this.steps = 0;
    this.status = GameStatus.PLAYING;
  }

  cellAt(r: number, c: number): number {
    return this.board[r * this.getSize() + c];
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

  findZeroIndex(): number {
    for (let i = 0; i < this.board.length; i++) {
      if (this.board[i] === 0) { return i; }
    }
    return -1;
  }

  tapCell(r: number, c: number): void {
    if (this.status === GameStatus.OVER) { return; }
    const n = this.getSize();
    const zi = this.findZeroIndex();
    if (zi < 0) { return; }
    const zr = Math.floor(zi / n);
    const zc = zi % n;
    const dr = Math.abs(r - zr);
    const dc = Math.abs(c - zc);
    if ((dr === 1 && dc === 0) || (dr === 0 && dc === 1)) {
      // copy-on-write：先复制再整体赋值，保证 @Local 观测到
      const next: number[] = [];
      for (let i = 0; i < this.board.length; i++) { next.push(this.board[i]); }
      const tapped = r * n + c;
      next[zi] = next[tapped];
      next[tapped] = 0;
      this.board = next;
      this.steps++;
      this.checkWin();
    }
  }

  checkWin(): void {
    const n = this.getSize();
    let ok = true;
    for (let i = 0; i < n; i++) {
      for (let j = 0; j < n; j++) {
        const v = this.cellAt(i, j);
        if (i === n - 1 && j === n - 1) {
          if (v !== 0) { ok = false; }
        } else if (v !== i * n + j + 1) {
          ok = false;
        }
      }
    }
    if (ok) {
      this.status = GameStatus.OVER;
      if (this.steps < this.best) { this.best = this.steps; }
      // 步数越少得分越高
      GameDataManager.updateHighScore('slidepuzzle', Math.max(1, 1000 - this.steps));
    }
  }

  getCellBg(r: number, c: number): ResourceColor {
    const v = this.cellAt(r, c);
    if (v === 0) { return SemanticColors.boardBg; }
    if (v === r * this.getSize() + c + 1) { return SemanticColors.success; }
    return SemanticColors.accent;
  }

  getCellOpacity(r: number, c: number): number {
    if (this.cellAt(r, c) === 0) { return 0; }
    return 1;
  }

  getBestText(): string {
    if (this.best === 999) { return '--'; }
    return '' + this.best;
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[SemanticColors.gradientScreen[0], 0], [SemanticColors.gradientScreen[1], 0.5], [SemanticColors.gradientScreen[2], 1]] })

      Column() {
        GameHeader({ gameTitle: '滑动拼图',
          showScore: false,
          showPause: false,
          subtitle: '移动方块还原顺序',
          difficulty: this.difficulty,
          onDifficultyChange: (d: GameDifficulty) => { this.changeDifficulty(d); },
          onBack: () => { this.pathStack.pop(); },
          onPauseToggle: () => {},
          onRestart: () => { this.startGame(); } })

        Row() {
          Column() {
            Text('步数').fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textTertiary)
            Text('' + this.steps).fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold).fontColor(SemanticColors.accent)
          }.layoutWeight(1).padding(8).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base)
          .alignItems(HorizontalAlign.Center).margin({ left: 16 })
          Column() {
            Text('最佳').fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textTertiary)
            Text(this.getBestText()).fontSize(FontTokens.sizeHeadline)
              .fontWeight(FontTokens.weightBold).fontColor(SemanticColors.textPrimary)
          }.layoutWeight(1).padding(8).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base)
          .alignItems(HorizontalAlign.Center).margin({ left: 8, right: 16 })
        }.margin({ top: 12, bottom: 12 })

        Column() {
          Column() {
            ForEach(this.idxN, (r: number) => {
              Row() {
                ForEach(this.idxN, (c: number) => {
                  Column() {
                    if (this.cellAt(r, c) > 0) {
                      Text('' + this.cellAt(r, c)).fontSize(Math.max(22, this.cell * 0.34))
                        .fontWeight(FontWeight.Bold)
                        // 拼图块底色为 accent / success，白字在两套主题下均可读
                        .fontColor('#FFFFFF')
                    }
                  }.width(this.cell).height(this.cell).margin(2)
                  .backgroundColor(this.getCellBg(r, c))
                  .borderRadius(RadiusTokens.base)
                  .shadow(ShadowTokens.button)
                  .opacity(this.getCellOpacity(r, c))
                  .onClick(() => this.tapCell(r, c))
                }, (c: number) => c.toString())
              }
            }, (r: number) => r.toString())
          }.backgroundColor(SemanticColors.boardBg).borderRadius(RadiusTokens.base).padding(4)
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      }.width('100%').height('100%').padding({ bottom: this.safeBottom })

      // 完成弹窗作为全屏遮罩层（原先内嵌在内容列中会撑破布局、超出屏幕）
      if (this.status === GameStatus.OVER) {
        GameResultDialog({
          symbol: $r('sys.symbol.checkmark_circle'),
          symbolColor: SemanticColors.success,
          title: '拼图完成!',
          detail: '步数: ' + this.steps,
          detailColor: SemanticColors.accent,
          primaryText: '再来一局',
          onPrimary: () => { this.startGame(); }
        })
      }
    }.width('100%').height('100%')
  }
}
