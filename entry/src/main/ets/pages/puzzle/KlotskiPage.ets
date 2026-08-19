/**
 * 华容道 - HarmonyOS 设计风格
 */
import { display } from '@kit.ArkUI';
import { DarkColors, RadiusTokens, FontTokens, ShadowTokens, SpacingTokens } from '../../common/DesignTokens';
import { ControlPad } from '../../components/ControlPad';
import { GameHeader } from '../../components/GameHeader';
import { GameDifficulty } from '../../common/GameConstants';
import { GameDataManager } from '../../model/GameData';

interface BlockInfo { id: string; w: number; h: number; x: number; y: number; target: boolean; }
const BW = 4;
const BH = 5;

@Entry
@ComponentV2
struct KlotskiPage {
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

  moveBlock(dx: number, dy: number): void {
    if (!this.selId || this.isWin) { return; }
    let block: BlockInfo | undefined;
    for (let i = 0; i < this.blocks.length; i++) {
      if (this.blocks[i].id === this.selId) { block = this.blocks[i]; break; }
    }
    if (!block) { return; }
    const nx = block.x + dx;
    const ny = block.y + dy;
    if (nx < 0 || nx + block.w > BW || ny < 0 || ny + block.h > BH) { return; }
    for (let r = ny; r < ny + block.h; r++) {
      for (let c = nx; c < nx + block.w; c++) {
        if (this.grid[r][c] && this.grid[r][c] !== block.id) { return; }
      }
    }
    block.x = nx;
    block.y = ny;
    this.stepCount++;
    this.buildGrid();
    if (block.target && block.x === 1 && block.y === 3) {
      this.isWin = true;
      // 步数越少得分越高
      GameDataManager.updateHighScore('klotski', Math.max(1, 1000 - this.stepCount));
    }
  }

  getBlockBg(block: BlockInfo): string {
    if (block.target) { return '#FF6666'; }
    if (block.w === 2 && block.h === 1) { return '#FFAA33'; }
    if (block.w === 1 && block.h === 2) { return '#3399FF'; }
    return '#2DD482';
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
    if (!bid) { return DarkColors.boardBg; }
    const b = this.findBlockById(bid);
    return b ? this.getBlockBg(b) : DarkColors.boardBg;
  }

  isBlockTopLeft(block: BlockInfo, r: number, c: number): boolean {
    return block.x === c && block.y === r;
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[DarkColors.gradientScreen[0], 0], [DarkColors.gradientScreen[1], 0.5], [DarkColors.gradientScreen[2], 1]] })

      Column() {
        GameHeader({
          gameTitle: '华容道',
          showScore: false,
          showPause: false,
          subtitle: '步数 ' + this.stepCount,
          difficulty: this.difficulty,
          onDifficultyChange: (d: GameDifficulty) => { this.changeDifficulty(d); },
          onBack: () => { this.getUIContext().getRouter().back(); },
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
                          .fontSize(Math.max(16, this.cell * 0.28)).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                      }
                    } else if (row === 3 && col === 0) {
                      Text('出口').fontSize(Math.max(10, this.cell * 0.16)).fontColor(DarkColors.textTertiary)
                    }
                  }.width(this.cell).height(this.cell).margin(2)
                  .backgroundColor(this.getCellBg(row, col))
                  .borderRadius(RadiusTokens.base)
                  .border({
                    width: this.selId && this.grid[row][col] === this.selId ? 2 : 0,
                    color: DarkColors.borderStrong
                  })
                  .onClick(() => { if (this.grid[row][col]) { this.selectBlock(this.grid[row][col]!); } })
                })
              }
            })
          }.width(this.cell * BW + 30).height(this.cell * BH + 34)
          .backgroundColor(DarkColors.boardBg)
          .border({ width: 3, color: DarkColors.boardBorder, radius: RadiusTokens.base }).padding(4)
        }.layoutWeight(1).justifyContent(FlexAlign.Center)

        ControlPad({
          onUp: () => this.moveBlock(0, -1),
          onDown: () => this.moveBlock(0, 1),
          onLeft: () => this.moveBlock(-1, 0),
          onRight: () => this.moveBlock(1, 0),
          onCenter: () => {},
          centerLabel: '移'
        })
      }.width('100%').height('100%')

      // 胜利弹窗作为全屏遮罩层（原先内嵌在内容列中会撑破布局、超出屏幕）
      if (this.isWin) {
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

          Text('曹操出逃成功!')
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold)
            .fontColor(DarkColors.textPrimary).margin({ top: SpacingTokens.md, bottom: SpacingTokens.xs })
          Text('' + this.stepCount + ' 步完成')
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeSubtitle).fontColor(DarkColors.warning)
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
