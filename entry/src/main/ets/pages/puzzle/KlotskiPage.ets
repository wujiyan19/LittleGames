/**
 * 华容道 - HarmonyOS 设计风格
 */
import { display } from '@kit.ArkUI';
import { SemanticColors, RadiusTokens, FontTokens, ShadowTokens, SpacingTokens } from '../../common/DesignTokens';
import { ControlPad } from '../../components/ControlPad';
import { GameHeader } from '../../components/GameHeader';
import { GameDifficulty } from '../../common/GameConstants';
import { GameDataManager } from '../../model/GameData';
import { SafeAreaInsets } from '../../common/SafeAreaInsets';
import { GameResultDialog } from '../../components/GameResultDialog';

interface BlockInfo { id: string; w: number; h: number; x: number; y: number; target: boolean; }
const BW = 4;
const BH = 5;

@ComponentV2
export struct KlotskiPage {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local safeBottom: number = SafeAreaInsets.bottom;
  @Local blocks: BlockInfo[] = [];
  @Local selId: string = '';
  @Local stepCount: number = 0;
  @Local isWin: boolean = false;
  @Local cell: number = 65;
  @Local difficulty: GameDifficulty = GameDifficulty.NORMAL;
  private grid: (string | null)[][] = [];
  private rowArray: number[] = [0,1,2,3,4];
  private colArray: number[] = [0,1,2,3];

  aboutToAppear(): void {
    this.initCellSize();
    this.startGame();
  }

  initCellSize(): void {
    const d = display.getDefaultDisplaySync();
    const wVp = this.getUIContext().px2vp(d.width);
    this.cell = Math.max(48, Math.floor((Math.min(wVp, 560) - 28) / BW));
  }

  makeNullGrid(): (string | null)[][] {
    const arr: (string | null)[][] = [];
    for (let i = 0; i < BH; i++) {
      const row: (string | null)[] = [];
      for (let j = 0; j < BW; j++) { row[j] = null; }
      arr[i] = row;
    }
    return arr;
  }

  startGame(): void {
    GameDataManager.incrementPlayCount('klotski');
    this.blocks = this.getLayout();
    this.stepCount = 0;
    this.isWin = false;
    this.selId = '';
    this.buildGrid();
  }

  getLayout(): BlockInfo[] {
    if (this.difficulty === GameDifficulty.EASY) {
      // 简单：棋子少，通道开阔
      return [
        { id: 'cc', w: 2, h: 2, x: 1, y: 0, target: true },
        { id: 'g1', w: 1, h: 2, x: 0, y: 0, target: false },
        { id: 'g2', w: 1, h: 2, x: 3, y: 0, target: false },
        { id: 'b1', w: 1, h: 1, x: 1, y: 2, target: false },
        { id: 'b2', w: 1, h: 1, x: 2, y: 2, target: false }
      ];
    }
    if (this.difficulty === GameDifficulty.HARD) {
      // 困难：出口两侧布满小兵，需层层让位
      return [
        { id: 'cc', w: 2, h: 2, x: 1, y: 0, target: true },
        { id: 'g1', w: 1, h: 2, x: 0, y: 0, target: false },
        { id: 'g2', w: 1, h: 2, x: 3, y: 0, target: false },
        { id: 'b1', w: 1, h: 1, x: 1, y: 2, target: false },
        { id: 'b2', w: 1, h: 1, x: 2, y: 2, target: false },
        { id: 'b3', w: 1, h: 1, x: 0, y: 3, target: false },
        { id: 'b4', w: 1, h: 1, x: 3, y: 3, target: false },
        { id: 'b5', w: 1, h: 1, x: 0, y: 4, target: false },
        { id: 'b6', w: 1, h: 1, x: 3, y: 4, target: false }
      ];
    }
    // 普通：两侧竖将 + 中部横阵
    return [
      { id: 'cc', w: 2, h: 2, x: 1, y: 0, target: true },
      { id: 'g1', w: 1, h: 2, x: 0, y: 0, target: false },
      { id: 'g2', w: 1, h: 2, x: 3, y: 0, target: false },
      { id: 'b1', w: 1, h: 1, x: 0, y: 2, target: false },
      { id: 'b2', w: 1, h: 1, x: 1, y: 2, target: false },
      { id: 'b3', w: 1, h: 1, x: 2, y: 2, target: false },
      { id: 'b4', w: 1, h: 1, x: 3, y: 2, target: false },
      { id: 'b5', w: 1, h: 1, x: 0, y: 3, target: false },
      { id: 'b6', w: 1, h: 1, x: 3, y: 3, target: false }
    ];
  }

  changeDifficulty(d: GameDifficulty): void {
    if (this.difficulty === d) { return; }
    this.difficulty = d;
    this.startGame();
  }

  buildGrid(): void {
    this.grid = this.makeNullGrid();
    for (let i = 0; i < this.blocks.length; i++) {
      const b = this.blocks[i];
      for (let r = b.y; r < b.y + b.h; r++) {
        for (let c = b.x; c < b.x + b.w; c++) {
          this.grid[r][c] = b.id;
        }
      }
    }
  }

  selectBlock(id: string): void {
    if (!this.isWin) { this.selId = this.selId === id ? '' : id; }
  }

  // copy-on-write 重建棋子数组：blocks 是 @Local，直接改 blocks[i].x 这种
  // 「数组内对象的字段赋值」观测不到，必须整体替换数组才会触发重渲染
  rebuildBlocks(movedIdx: number, nx: number, ny: number): void {
    const next: BlockInfo[] = [];
    for (let i = 0; i < this.blocks.length; i++) {
      const cur = this.blocks[i];
      if (i === movedIdx) {
        next[i] = { id: cur.id, w: cur.w, h: cur.h, x: nx, y: ny, target: cur.target };
      } else {
        next[i] = { id: cur.id, w: cur.w, h: cur.h, x: cur.x, y: cur.y, target: cur.target };
      }
    }
    this.blocks = next;
  }

  moveBlock(dx: number, dy: number): void {
    if (!this.selId || this.isWin) { return; }
    let idx = -1;
    for (let i = 0; i < this.blocks.length; i++) {
      if (this.blocks[i].id === this.selId) { idx = i; break; }
    }
    if (idx < 0) { return; }
    const block = this.blocks[idx];
    const nx = block.x + dx;
    const ny = block.y + dy;
    if (nx < 0 || nx + block.w > BW || ny < 0 || ny + block.h > BH) { return; }
    for (let r = ny; r < ny + block.h; r++) {
      for (let c = nx; c < nx + block.w; c++) {
        const occupied: string | null = this.grid[r][c];
        if (occupied !== null && occupied !== block.id) { return; }
      }
    }
    this.rebuildBlocks(idx, nx, ny);
    this.stepCount++;
    this.buildGrid();
    const moved = this.blocks[idx];
    if (moved.target && moved.x === 1 && moved.y === 3) {
      this.isWin = true;
      // 步数越少得分越高
      GameDataManager.updateHighScore('klotski', Math.max(1, 1000 - this.stepCount));
    }
  }

  /**
   * 棋子配色。原为字面量，已收编为资源（深色模式在 dark/ 下提供提亮版本）。
   * 棋子上的文字恒为白色——这些底色的明度在两套主题下都足以承托白字。
   */
  getBlockBg(block: BlockInfo): ResourceColor {
    if (block.target) { return $r('app.color.klotski_target'); }
    if (block.w === 2 && block.h === 1) { return $r('app.color.klotski_horizontal'); }
    if (block.w === 1 && block.h === 2) { return $r('app.color.klotski_vertical'); }
    return $r('app.color.klotski_normal');
  }

  getBlockLabel(block: BlockInfo): string {
    if (block.target) { return '曹'; }
    if (block.w === 1 && block.h === 2) { return '将'; }
    if (block.w === 2 && block.h === 1) { return '将'; }
    return '兵';
  }

  findBlockById(id: string): BlockInfo | undefined {
    for (let i = 0; i < this.blocks.length; i++) {
      if (this.blocks[i].id === id) { return this.blocks[i]; }
    }
    return undefined;
  }

  getCellBg(row: number, col: number): ResourceColor {
    const bid = this.grid[row][col];
    if (!bid) { return SemanticColors.boardBg; }
    const b = this.findBlockById(bid);
    return b ? this.getBlockBg(b) : SemanticColors.boardBg;
  }

  getBorderWidth(row: number, col: number): number {
    if (this.selId && this.grid[row][col] === this.selId) { return 2; }
    return 0;
  }

  isBlockTopLeft(block: BlockInfo, r: number, c: number): boolean {
    return block.x === c && block.y === r;
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[SemanticColors.gradientScreen[0], 0], [SemanticColors.gradientScreen[1], 0.5], [SemanticColors.gradientScreen[2], 1]] })

      Column() {
        GameHeader({
          gameTitle: '华容道',
          showScore: false,
          showPause: false,
          subtitle: '步数 ' + this.stepCount,
          difficulty: this.difficulty,
          onDifficultyChange: (d: GameDifficulty) => { this.changeDifficulty(d); },
          onBack: () => { this.pathStack.pop(); },
          onPauseToggle: () => {},
          onRestart: () => { this.startGame(); }
        })

        Column() {
          Column() {
            ForEach(this.rowArray, (row: number) => {
              Row() {
                ForEach(this.colArray, (col: number) => {
                  Column() {
                    if (this.grid[row][col]) {
                      if (this.findBlockById(this.grid[row][col]!) && this.isBlockTopLeft(this.findBlockById(this.grid[row][col]!)!, row, col)) {
                        Text(this.getBlockLabel(this.findBlockById(this.grid[row][col]!)!))
                          .fontSize(Math.max(16, this.cell * 0.28)).fontWeight(FontWeight.Bold)
                          // 棋子底色为彩色（见 getBlockBg），白字在两套主题下均可读
                          .fontColor('#FFFFFF')
                      }
                    } else if (row === 4 && col === 1) {
                      Text('出口').fontSize(Math.max(10, this.cell * 0.16)).fontColor(SemanticColors.textTertiary)
                    }
                  }.width(this.cell).height(this.cell).margin(2)
                  .backgroundColor(this.getCellBg(row, col))
                  .borderRadius(RadiusTokens.base)
                  .border({
                    width: this.getBorderWidth(row, col),
                    color: SemanticColors.borderStrong
                  })
                  .onClick(() => { if (this.grid[row][col]) { this.selectBlock(this.grid[row][col]!); } })
                }, (col: number) => col.toString())
              }
            }, (row: number) => row.toString())
          }.width(this.cell * BW + 30).height(this.cell * BH + 34)
          .backgroundColor(SemanticColors.boardBg)
          .border({ width: 3, color: SemanticColors.boardBorder, radius: RadiusTokens.base }).padding(4)
        }.layoutWeight(1).justifyContent(FlexAlign.Center)

        ControlPad({
          onUp: () => this.moveBlock(0, -1),
          onDown: () => this.moveBlock(0, 1),
          onLeft: () => this.moveBlock(-1, 0),
          onRight: () => this.moveBlock(1, 0),
          onCenter: () => {},
          centerLabel: '移'
        })
      }.width('100%').height('100%').padding({ bottom: this.safeBottom })

      // 胜利弹窗作为全屏遮罩层（原先内嵌在内容列中会撑破布局、超出屏幕）
      if (this.isWin) {
        GameResultDialog({
          symbol: $r('sys.symbol.checkmark_circle'),
          symbolColor: SemanticColors.success,
          title: '曹操出逃成功!',
          detail: '' + this.stepCount + ' 步完成',
          detailColor: SemanticColors.warning,
          primaryText: '再来一局',
          onPrimary: () => { this.startGame(); }
        })
      }
    }.width('100%').height('100%')
  }
}
