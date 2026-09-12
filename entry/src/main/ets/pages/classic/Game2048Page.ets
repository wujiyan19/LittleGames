/**
 * 2048 —— View 层（展示与动画）
 *
 * 规则/状态在 Model/ViewModel；本层只负责：方块身份(id)与弹入/合并动画、配色、布局。
 * 不 import Model 类型。
 */
import { curves } from '@kit.ArkUI';
import { SemanticColors, RadiusTokens, FontTokens, SpacingTokens } from '../../common/DesignTokens';
import { GameHeader } from '../../components/GameHeader';
import { GameDifficulty, GameStatus } from '../../common/GameConstants';
import { SafeAreaInsets } from '../../common/SafeAreaInsets';
import { GameResultDialog } from '../../components/GameResultDialog';
import { ScreenUtils } from '../../common/ScreenUtils';
import { range } from '../../common/Range';
import { Game2048ViewModel } from '../../viewmodel/Game2048ViewModel';

const SIZE = 4;

interface TileData {
  value: number;
  id: number;
  offsetX: number;
  offsetY: number;
  scale: number;
  isNew: boolean;
  isMerged: boolean;
}

@ComponentV2
export struct Game2048Page {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local safeBottom: number = SafeAreaInsets.bottom;
  @Local viewModel: Game2048ViewModel = new Game2048ViewModel();
  @Local tiles: TileData[][] = [];
  @Local cell: number = 64;
  @Local boardSize: number = 286;
  private sx: number = 0;
  private sy: number = 0;
  private idx4: number[] = range(SIZE);
  private tileIdCounter: number = 0;
  private animationDuration: number = 150;

  aboutToAppear(): void {
    this.initBoardSize();
    this.startGame();
  }

  initBoardSize(): void {
    this.cell = ScreenUtils.calcCell(SIZE, 520, 32, 40);
    this.boardSize = this.cell * SIZE + SIZE * 6 + 8;
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

  copyRow(r: number): TileData[] {
    const row: TileData[] = [];
    for (let i = 0; i < SIZE; i++) {
      const src = this.tiles[r][i];
      row[i] = { value: src.value, id: src.id, offsetX: src.offsetX, offsetY: src.offsetY,
                 scale: src.scale, isNew: src.isNew, isMerged: src.isMerged };
    }
    return row;
  }

  startGame(): void {
    this.viewModel.startGame();
    this.tileIdCounter = 0;
    this.tiles = this.initTiles();
    this.syncTiles(true);
  }

  swipe(handler: () => void): void {
    handler();
    this.syncTiles(false);
  }

  /**
   * 根据 viewModel.board 重建 tiles，保留方块 id 以驱动动画。
   * animateAllNew=true（开局）时所有非空格视为新块；否则只有 viewModel 的 spawn 格算新块。
   */
  syncTiles(animateAllNew: boolean): void {
    const newTiles: TileData[][] = [];
    const newCells: number[] = [];
    const mergedCells: number[] = [];
    for (let r = 0; r < SIZE; r++) {
      const row: TileData[] = [];
      for (let c = 0; c < SIZE; c++) {
        const value = this.viewModel.cellValue(r, c);
        const old = this.tiles[r][c];
        if (value !== 0) {
          if (old.value !== 0 && value !== old.value) {
            // 合并：值变了
            row[c] = { value: value, id: old.id, offsetX: 0, offsetY: 0, scale: 1, isNew: false, isMerged: true };
            mergedCells.push(r * SIZE + c);
          } else if (old.value === 0) {
            const isSpawn = animateAllNew ||
              (r === this.viewModel.spawnRow && c === this.viewModel.spawnCol);
            row[c] = { value: value, id: ++this.tileIdCounter, offsetX: 0, offsetY: 0,
                       scale: 1, isNew: isSpawn, isMerged: false };
            if (isSpawn) { newCells.push(r * SIZE + c); }
          } else {
            // 原地不动
            row[c] = { value: value, id: old.id, offsetX: 0, offsetY: 0, scale: 1, isNew: false, isMerged: false };
          }
        } else {
          row[c] = { value: 0, id: 0, offsetX: 0, offsetY: 0, scale: 1, isNew: false, isMerged: false };
        }
      }
      newTiles[r] = row;
    }
    this.tiles = newTiles;

    for (let i = 0; i < mergedCells.length; i++) {
      this.animateMergedTile(Math.floor(mergedCells[i] / SIZE), mergedCells[i] % SIZE);
    }
    for (let i = 0; i < newCells.length; i++) {
      this.animateNewTile(Math.floor(newCells[i] / SIZE), newCells[i] % SIZE);
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
          onFinish: () => { updateTile(1, false); }
        }, () => { updateTile(1, true); });
      }
    }, () => { updateTile(1.2, true); });
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
          onFinish: () => { updateTile(1, false); }
        }, () => { updateTile(1, true); });
      }
    }, () => { updateTile(1.2, true); });
  }

  /**
   * 方块底色。已收编为资源，深色模式在 dark/element/color.json 提供另一套值。
   */
  getCellBg(v: number): ResourceColor {
    switch (v) {
      case 0: return SemanticColors.cellHidden;
      case 2: return $r('app.color.tile_2');
      case 4: return $r('app.color.tile_4');
      case 8: return $r('app.color.tile_8');
      case 16: return $r('app.color.tile_16');
      case 32: return $r('app.color.tile_32');
      case 64: return $r('app.color.tile_64');
      case 128: return $r('app.color.tile_128');
      case 256: return $r('app.color.tile_256');
      case 512: return $r('app.color.tile_512');
      case 1024: return $r('app.color.tile_1024');
      case 2048: return $r('app.color.tile_2048');
      default: return $r('app.color.tile_large');
    }
  }

  /** 2/4 为浅底配深字，8 以上为彩底配白字；随主题切换 */
  getTileFontColor(v: number): ResourceColor {
    if (v <= 4) { return $r('app.color.tile_text_low'); }
    return $r('app.color.tile_text_high');
  }

  getTileAnimation(isNew: boolean): AnimateParam {
    return {
      duration: isNew ? 200 : this.animationDuration,
      curve: isNew ? curves.springCurve(0.5, 1.0, 0.5, 2.0) : Curve.EaseOut,
      playMode: PlayMode.Normal
    };
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[SemanticColors.gradientScreen[0], 0], [SemanticColors.gradientScreen[1], 0.5], [SemanticColors.gradientScreen[2], 1]] })

      Column() {
        GameHeader({ gameTitle: '2048', // 得分/最高分已由下方大字指标卡展示，关闭标题栏的小字重复显示
          showScore: false,
          difficulty: this.viewModel.difficulty,
          showPause: false,
          onDifficultyChange: (d: GameDifficulty) => { this.viewModel.changeDifficulty(d); },
          onBack: () => { this.pathStack.pop(); },
          onPauseToggle: () => {},
          onRestart: () => { this.startGame(); } })

        Row() {
          Column() {
            Text('得分').fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textTertiary)
            Text('' + this.viewModel.score).fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold).fontColor(SemanticColors.accent)
          }.layoutWeight(1).padding(8).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base)
          .alignItems(HorizontalAlign.Center).margin({ left: 16 })

          Column() {
            Text('最高').fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textTertiary)
            Text('' + this.viewModel.highScore).fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold).fontColor(SemanticColors.textPrimary)
          }.layoutWeight(1).padding(8).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base)
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
          .backgroundColor(SemanticColors.boardBg)
          .border({ width: 2, color: SemanticColors.boardBorder, radius: RadiusTokens.base })
          .padding(4)
          // 16 个棋格同时做缩放/位移，整体缓存为一张位图，减少渲染批次（P2-1）
          .renderGroup(true)
          .gesture(PanGesture({ direction: PanDirection.All })
            .onActionStart((e: GestureEvent) => { this.sx = e.offsetX; this.sy = e.offsetY; })
            .onActionEnd((e: GestureEvent) => {
              const dx = e.offsetX - this.sx;
              const dy = e.offsetY - this.sy;
              if (Math.abs(dx) > Math.abs(dy)) {
                this.swipe(() => { if (dx > 0) { this.viewModel.swipeRight(); } else { this.viewModel.swipeLeft(); } });
              } else {
                this.swipe(() => { if (dy > 0) { this.viewModel.swipeDown(); } else { this.viewModel.swipeUp(); } });
              }
            }))
        }.layoutWeight(1).justifyContent(FlexAlign.Center)

        Text('上下左右滑动操作')
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeBodySmall).fontColor(SemanticColors.textTertiary)
          .padding({ bottom: SpacingTokens.lg })
      }.width('100%').height('100%').padding({ bottom: this.safeBottom })

      if (this.viewModel.status !== GameStatus.PLAYING) {
        GameResultDialog({
          symbol: $r('sys.symbol.star_fill'),
          symbolColor: SemanticColors.warning,
          title: '游戏结束',
          detail: '得分 ' + this.viewModel.score,
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
