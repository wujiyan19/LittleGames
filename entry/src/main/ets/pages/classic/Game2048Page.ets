/**
 * 2048 - HarmonyOS 设计风格（带滑动动画）
 */
import { display, curves } from '@kit.ArkUI';
import { DarkColors, RadiusTokens, FontTokens, ShadowTokens, SpacingTokens } from '../../common/DesignTokens';
import { GameHeader } from '../../components/GameHeader';
import { GameDifficulty } from '../../common/GameConstants';
import { GameDataManager } from '../../model/GameData';

const SIZE = 4;
const CELL_SIZE = 64;
const CELL_GAP = 6;

interface Position {
  r: number;
  c: number;
}

interface TileData {
  value: number;
  id: number;
  offsetX: number;
  offsetY: number;
  scale: number;
  isNew: boolean;
  isMerged: boolean;
}

@Entry
@ComponentV2
struct Game2048Page {
  @Local board: number[][] = [];
  @Local tiles: TileData[][] = [];
  @Local score: number = 0;
  @Local highScore: number = 0;
  @Local difficulty: GameDifficulty = GameDifficulty.NORMAL;
  @Local isPlaying: boolean = true;
  @Local animationDuration: number = 150;
  @Local cell: number = 64;
  @Local boardSize: number = 286;
  private sx: number = 0;
  private sy: number = 0;
  private idx4: number[] = [0, 1, 2, 3];
  private tileIdCounter: number = 0;

  aboutToAppear(): void {
    this.highScore = GameDataManager.getGameById('2048')?.highScore ?? 0;
    this.initBoardSize();
    this.start();
  }

  getFourChance(): number {
    if (this.difficulty === GameDifficulty.EASY) { return 0.05; }
    if (this.difficulty === GameDifficulty.HARD) { return 0.2; }
    return 0.1;
  }

  changeDifficulty(d: GameDifficulty): void {
    if (this.difficulty === d) { return; }
    this.difficulty = d;
    this.start();
  }

  initBoardSize(): void {
    const d = display.getDefaultDisplaySync();
    const wVp = this.getUIContext().px2vp(d.width);
    this.cell = Math.max(40, Math.floor((Math.min(wVp, 520) - 32) / SIZE));
    this.boardSize = this.cell * SIZE + SIZE * 6 + 8;
  }

  initBoard(): number[][] {
    const arr: number[][] = [];
    for (let i = 0; i < SIZE; i++) {
      const row: number[] = [];
      for (let j = 0; j < SIZE; j++) { row[j] = 0; }
      arr[i] = row;
    }
    return arr;
  }

  initTiles(): TileData[][] {
    const arr: TileData[][] = [];
    for (let i = 0; i < SIZE; i++) {
      const row: TileData[] = [];
      for (let j = 0; j < SIZE; j++) {
        row[j] = { value: 0, id: 0, offsetX: 0, offsetY: 0, scale: 1, isNew: false, isMerged: false };
      }
      arr[i] = row;
    }
    return arr;
  }

  // 复制 tiles 的某一行，用于触发 @Local 响应式更新
  copyRow(r: number): TileData[] {
    const row: TileData[] = [];
    for (let i = 0; i < SIZE; i++) {
      const src = this.tiles[r][i];
      row[i] = { value: src.value, id: src.id, offsetX: src.offsetX, offsetY: src.offsetY,
                 scale: src.scale, isNew: src.isNew, isMerged: src.isMerged };
    }
    return row;
  }

  // 完全根据 board 重建 tiles 数组，确保 @Local 能检测到响应式变化
  syncTilesFromBoard(): void {
    const newTiles: TileData[][] = [];
    for (let r = 0; r < SIZE; r++) {
      const row: TileData[] = [];
      for (let c = 0; c < SIZE; c++) {
        const value = this.board[r][c];
        const oldTile = this.tiles[r][c];

        if (value !== 0) {
          if (oldTile.value !== 0 && value !== oldTile.value) {
            // 合并：值变了
            row[c] = { value: value, id: oldTile.id, offsetX: 0, offsetY: 0,
                       scale: 1, isNew: false, isMerged: true };
          } else if (oldTile.value === 0) {
            // 新移动过来的格子
            row[c] = { value: value, id: ++this.tileIdCounter, offsetX: 0, offsetY: 0,
                       scale: 1, isNew: false, isMerged: false };
          } else {
            // 原地不动的格子
            row[c] = { value: value, id: oldTile.id, offsetX: 0, offsetY: 0,
                       scale: 1, isNew: false, isMerged: false };
          }
        } else {
          row[c] = { value: 0, id: 0, offsetX: 0, offsetY: 0,
                     scale: 1, isNew: false, isMerged: false };
        }
      }
      newTiles[r] = row;
    }
    this.tiles = newTiles;

    // 对合并的格子触发动画
    for (let r = 0; r < SIZE; r++) {
      for (let c = 0; c < SIZE; c++) {
        if (this.tiles[r][c].isMerged) {
          this.animateMergedTile(r, c);
        }
      }
    }
  }

  animateMergedTile(r: number, c: number): void {
    const updateTile = (scale: number, isMerged: boolean) => {
      const row = this.copyRow(r);
      const t = row[c];
      row[c] = { value: t.value, id: t.id, offsetX: t.offsetX, offsetY: t.offsetY,
                 scale: scale, isNew: t.isNew, isMerged: isMerged };
      this.tiles[r] = row;
    };

    updateTile(1.2, true);
    this.getUIContext().animateTo({
      duration: 100,
      curve: Curve.EaseOut,
      onFinish: () => {
        this.getUIContext().animateTo({
          duration: 100,
          curve: curves.springCurve(0.5, 1.0, 0.5, 2.0),
          onFinish: () => {
            updateTile(1, false);
          }
        }, () => {
          updateTile(1, true);
        });
      }
    }, () => {
      updateTile(1.2, true);
    });
  }

  animateNewTile(r: number, c: number): void {
    const updateTile = (scale: number, isNew: boolean) => {
      const row = this.copyRow(r);
      const t = row[c];
      row[c] = { value: t.value, id: t.id, offsetX: t.offsetX, offsetY: t.offsetY,
                 scale: scale, isNew: isNew, isMerged: t.isMerged };
      this.tiles[r] = row;
    };

    updateTile(0.5, true);
    this.getUIContext().animateTo({
      duration: 150,
      curve: curves.springCurve(0.5, 1.0, 0.5, 2.0),
      onFinish: () => {
        this.getUIContext().animateTo({
          duration: 100,
          curve: Curve.EaseOut,
          onFinish: () => {
            updateTile(1, false);
          }
        }, () => {
          updateTile(1, true);
        });
      }
    }, () => {
      updateTile(1.2, true);
    });
  }

  start(): void {
    if (this.score > 0) { GameDataManager.updateHighScore('2048', this.score); }
    GameDataManager.incrementPlayCount('2048');
    this.board = this.initBoard();
    this.tiles = this.initTiles();
    this.score = 0;
    this.isPlaying = true;
    this.tileIdCounter = 0;
    this.addRandom();
    this.addRandom();
  }

  addRandom(): void {
    const empty: Position[] = [];
    for (let r = 0; r < SIZE; r++) {
      for (let c = 0; c < SIZE; c++) {
        if (this.board[r][c] === 0) {
          empty.push({ r: r, c: c });
        }
      }
    }
    if (empty.length > 0) {
      const idx = Math.floor(Math.random() * empty.length);
      const pos = empty[idx];
      const value = Math.random() < (1 - this.getFourChance()) ? 2 : 4;
      this.board[pos.r][pos.c] = value;

      const row = this.copyRow(pos.r);
      row[pos.c] = { value: value, id: ++this.tileIdCounter, offsetX: 0, offsetY: 0,
                     scale: 1, isNew: true, isMerged: false };
      this.tiles[pos.r] = row;

      this.animateNewTile(pos.r, pos.c);
    }
  }

  mergeRow(line: number[]): number[] {
    const f: number[] = [];
    for (let i = 0; i < line.length; i++) {
      if (line[i] > 0) { f.push(line[i]); }
    }
    const result: number[] = [];
    let k = 0;
    while (k < f.length) {
      if (k + 1 < f.length && f[k] === f[k + 1]) {
        result.push(f[k] * 2);
        this.score += f[k] * 2;
        k += 2;
      } else {
        result.push(f[k]);
        k += 1;
      }
    }
    while (result.length < SIZE) { result.push(0); }
    return result;
  }

  swipe(dir: string): void {
    if (!this.isPlaying) { return; }
    const old = JSON.stringify(this.board);
    const nb = this.initBoard();

    for (let i = 0; i < SIZE; i++) {
      let line: number[] = [];
      for (let j = 0; j < SIZE; j++) {
        if (dir === 'left') { line.push(this.board[i][j]); }
        else if (dir === 'right') { line.push(this.board[i][SIZE - 1 - j]); }
        else if (dir === 'up') { line.push(this.board[j][i]); }
        else { line.push(this.board[SIZE - 1 - j][i]); }
      }
      line = this.mergeRow(line);
      for (let j = 0; j < SIZE; j++) {
        if (dir === 'left') { nb[i][j] = line[j]; }
        else if (dir === 'right') { nb[i][SIZE - 1 - j] = line[j]; }
        else if (dir === 'up') { nb[j][i] = line[j]; }
        else { nb[SIZE - 1 - j][i] = line[j]; }
      }
    }

    if (old !== JSON.stringify(nb)) {
      this.board = nb;
      this.syncTilesFromBoard();
      this.addRandom();
      if (this.score > this.highScore) { this.highScore = this.score; }
      if (this.isGameOver()) {
        this.isPlaying = false;
        GameDataManager.updateHighScore('2048', this.score);
      }
    }
  }

  getCellBg(v: number): ResourceColor {
    switch (v) {
      case 0: return DarkColors.cellHidden;
      case 2: return '#EEE4DA';
      case 4: return '#EDE0C8';
      case 8: return '#F2B179';
      case 16: return '#F59563';
      case 32: return '#F67C5F';
      case 64: return '#F65E3B';
      case 128: return '#EDCF72';
      case 256: return '#EDCC61';
      case 512: return '#EDC850';
      case 1024: return '#EDC53F';
      case 2048: return '#EDC22E';
      default: return '#3C3A32';
    }
  }

  getTileFontColor(v: number): ResourceColor {
    if (v <= 4) { return '#776E65'; }
    return '#FFFFFF';
  }

  getTileAnimation(isNew: boolean): AnimateParam {
    return {
      duration: isNew ? 200 : this.animationDuration,
      curve: isNew ? curves.springCurve(0.5, 1.0, 0.5, 2.0) : Curve.EaseOut,
      playMode: PlayMode.Normal
    };
  }

  isGameOver(): boolean {
    for (let r = 0; r < SIZE; r++) {
      for (let c = 0; c < SIZE; c++) {
        if (this.board[r][c] === 0) { return false; }
        if (c + 1 < SIZE && this.board[r][c] === this.board[r][c + 1]) { return false; }
        if (r + 1 < SIZE && this.board[r][c] === this.board[r + 1][c]) { return false; }
      }
    }
    return true;
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[DarkColors.gradientScreen[0], 0], [DarkColors.gradientScreen[1], 0.5], [DarkColors.gradientScreen[2], 1]] })

      Column() {
        GameHeader({ gameTitle: '2048', scoreValue: this.score, highScoreValue: this.highScore,
          difficulty: this.difficulty,
          showPause: false,
          onDifficultyChange: (d: GameDifficulty) => { this.changeDifficulty(d); },
          onBack: () => { this.getUIContext().getRouter().back(); },
          onPauseToggle: () => {},
          onRestart: () => { this.start(); } })

        Row() {
          Column() {
            Text('最高').fontSize(FontTokens.sizeCaption).fontColor(DarkColors.textTertiary)
            Text('' + this.highScore).fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold).fontColor(DarkColors.textPrimary)
          }.layoutWeight(1).padding(8).backgroundColor(DarkColors.surface).borderRadius(RadiusTokens.base)
          .alignItems(HorizontalAlign.Center).margin({ left: 8, right: 16 })
        }.margin({ top: 12, bottom: 12 })

        Column() {
          Column() {
            ForEach(this.idx4, (row: number) => {
              Row() {
                ForEach(this.idx4, (col: number) => {
                  Column() {
                    if (this.tiles[row][col].value > 0) {
                      Text('' + this.tiles[row][col].value)
                        .fontSize(Math.max(18, this.cell * 0.36)).fontWeight(FontWeight.Bold)
                        .fontColor(this.getTileFontColor(this.tiles[row][col].value))
                    }
                  }.width(this.cell).height(this.cell).margin(3).borderRadius(RadiusTokens.md)
                  .backgroundColor(this.getCellBg(this.tiles[row][col].value))
                  .justifyContent(FlexAlign.Center)
                  .offset({ x: this.tiles[row][col].offsetX, y: this.tiles[row][col].offsetY })
                  .scale({ x: this.tiles[row][col].scale, y: this.tiles[row][col].scale })
                  .animation(this.getTileAnimation(this.tiles[row][col].isNew))
                }, (col: number) => col.toString())
              }
            }, (row: number) => row.toString())
          }.width(this.boardSize).height(this.boardSize)
          .backgroundColor(DarkColors.boardBg)
          .border({ width: 2, color: DarkColors.boardBorder, radius: RadiusTokens.base })
          .padding(4)
          .gesture(PanGesture({ direction: PanDirection.All })
            .onActionStart((e: GestureEvent) => { this.sx = e.offsetX; this.sy = e.offsetY; })
            .onActionEnd((e: GestureEvent) => {
              const dx = e.offsetX - this.sx;
              const dy = e.offsetY - this.sy;
              if (Math.abs(dx) > Math.abs(dy)) {
                this.swipe(dx > 0 ? 'right' : 'left');
              } else {
                this.swipe(dy > 0 ? 'down' : 'up');
              }
            }))
        }.layoutWeight(1).justifyContent(FlexAlign.Center)

        Text('上下左右滑动操作')
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeBodySmall).fontColor(DarkColors.textTertiary)
          .padding({ bottom: SpacingTokens.lg })
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
            .fontSize(FontTokens.sizeSubtitle).fontColor(DarkColors.accent)
            .margin({ bottom: SpacingTokens.lg })
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
            .onClick(() => this.start())
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
