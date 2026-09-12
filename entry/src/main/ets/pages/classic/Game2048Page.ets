/**
 * 2048 —— View 层（展示与动画）
 *
 * 动画机制统一为「状态驱动 + .animation() 隐式动画」：
 * - 每个方块有稳定 id，渲染在 Stack 中按 row/col 用 offset 定位；
 * - 移动时沿用旧方块 id、只改 row/col → .animation() 自动把 offset 从旧位置插值到新位置（滑动）；
 * - 新块初始 scale=0.5、合并块先 scale=1.15，随后统一回落 1（弹动）。
 * 已删除原先 .animation() 与嵌套 animateTo 混用的实现（P2-4）。
 * 规则/状态在 Model/ViewModel；本层不 import Model 类型。
 */
import { SemanticColors, RadiusTokens, FontTokens, SpacingTokens } from '../../common/DesignTokens';
import { GameHeader } from '../../components/GameHeader';
import { GameDifficulty, GameStatus } from '../../common/GameConstants';
import { SafeAreaInsets } from '../../common/SafeAreaInsets';
import { GameResultDialog } from '../../components/GameResultDialog';
import { ScreenUtils } from '../../common/ScreenUtils';
import { range } from '../../common/Range';
import { Game2048ViewModel } from '../../viewmodel/Game2048ViewModel';

const SIZE = 4;
/** 格间距（每格 margin 3 → 相邻两格共 6） */
const GAP = 6;

interface TileData {
  id: number;
  value: number;
  row: number;
  col: number;
  scale: number;
}

@ComponentV2
export struct Game2048Page {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local safeBottom: number = SafeAreaInsets.bottom;
  @Local viewModel: Game2048ViewModel = new Game2048ViewModel();
  // 方块列表（稳定 id），非按格存储——这样移动时组件身份不变，offset 才会被插值
  @Local tiles: TileData[] = [];
  @Local cell: number = 64;
  @Local boardSize: number = 286;
  private sx: number = 0;
  private sy: number = 0;
  private idx4: number[] = range(SIZE);
  private tileIdCounter: number = 0;
  private animationDuration: number = 150;
  /** 弹动回落定时器（新块/合并块缩放回 1） */
  private settleTimer: number = -1;

  aboutToAppear(): void {
    this.initBoardSize();
    this.startGame();
  }

  aboutToDisappear(): void { this.clearSettleTimer(); }

  initBoardSize(): void {
    this.cell = ScreenUtils.calcCell(SIZE, 520, 32, 40);
    this.boardSize = this.innerSize() + 8;
  }

  private step(): number { return this.cell + GAP; }
  private innerSize(): number { return this.cell * SIZE + SIZE * GAP; }

  private clearSettleTimer(): void {
    if (this.settleTimer !== -1) {
      clearTimeout(this.settleTimer);
      this.settleTimer = -1;
    }
  }

  startGame(): void {
    this.clearSettleTimer();
    this.viewModel.startGame();
    this.tileIdCounter = 0;
    // 开局两个块都做弹入
    this.rebuildTiles(true);
  }

  swipe(handler: () => boolean): void {
    const changed = handler();
    if (changed) { this.rebuildTiles(false); }
  }

  /**
   * 依据 viewModel.board 重建方块列表。
   * animateAllNew=true（开局）时所有非空格视为新块；否则只有 spawn 格算新块。
   * 非空格优先沿用「来源格」的旧方块 id —— 保持身份不变，offset 变化即产生滑动。
   */
  rebuildTiles(animateAllNew: boolean): void {
    this.clearSettleTimer();
    // 旧方块按格索引归档
    const oldAt: (TileData | null)[] = [];
    for (let i = 0; i < SIZE * SIZE; i++) { oldAt.push(null); }
    for (let i = 0; i < this.tiles.length; i++) {
      const t = this.tiles[i];
      oldAt[t.row * SIZE + t.col] = t;
    }

    const next: TileData[] = [];
    const settleIds: number[] = [];
    for (let r = 0; r < SIZE; r++) {
      for (let c = 0; c < SIZE; c++) {
        const value = this.viewModel.cellValue(r, c);
        if (value === 0) { continue; }

        const isSpawn = animateAllNew ||
          (r === this.viewModel.spawnRow && c === this.viewModel.spawnCol);
        if (isSpawn) {
          const id = ++this.tileIdCounter;
          next.push({ id: id, value: value, row: r, col: c, scale: 0.5 });
          settleIds.push(id);
          continue;
        }

        const srcIdx = this.viewModel.sourceAt(r * SIZE + c);
        const old = (srcIdx >= 0) ? oldAt[srcIdx] : null;
        const id = (old !== null) ? old.id : ++this.tileIdCounter;
        // 合并判定：目标值 = 来源值 * 2
        const merged = (old !== null) && old.value > 0 && old.value * 2 === value;
        next.push({ id: id, value: value, row: r, col: c, scale: merged ? 1.15 : 1 });
        if (merged) { settleIds.push(id); }
      }
    }
    this.tiles = next;

    if (settleIds.length > 0) {
      this.settleTimer = setTimeout(() => {
        this.settleTimer = -1;
        this.settleScales(settleIds);
      }, this.animationDuration);
    }
  }

  /** 弹动回落：把指定方块 scale 归 1（由 .animation() 插值） */
  private settleScales(ids: number[]): void {
    const updated: TileData[] = [];
    for (let i = 0; i < this.tiles.length; i++) {
      const t = this.tiles[i];
      let scale = t.scale;
      for (let k = 0; k < ids.length; k++) {
        if (ids[k] === t.id) { scale = 1; break; }
      }
      updated.push({ id: t.id, value: t.value, row: t.row, col: t.col, scale: scale });
    }
    this.tiles = updated;
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

  /** 方块隐式动画参数：位移/缩放/底色变化都由它插值 */
  getTileAnimation(): AnimateParam {
    return {
      duration: this.animationDuration,
      curve: Curve.EaseOut,
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
          Stack({ alignContent: Alignment.TopStart }) {
            // 底色格
            ForEach(this.idx4, (row: number) => {
              Row() {
                ForEach(this.idx4, (col: number) => {
                  Column()
                    .width(this.cell).height(this.cell).margin(3)
                    .borderRadius(RadiusTokens.md)
                    .backgroundColor(SemanticColors.cellHidden)
                }, (col: number) => col.toString())
              }
            }, (row: number) => row.toString())

            // 方块层：稳定 id，按 row/col 偏移定位
            ForEach(this.tiles, (tile: TileData) => {
              Column() {
                Text('' + tile.value)
                  .fontSize(Math.max(18, this.cell * 0.36)).fontWeight(FontWeight.Bold)
                  .fontColor(this.getTileFontColor(tile.value))
              }
              .width(this.cell).height(this.cell)
              .borderRadius(RadiusTokens.md)
              .backgroundColor(this.getCellBg(tile.value))
              .justifyContent(FlexAlign.Center)
              .offset({ x: tile.col * this.step() + 3, y: tile.row * this.step() + 3 })
              .scale({ x: tile.scale, y: tile.scale })
              // 放在最后：对它之前的 offset/scale/backgroundColor 做隐式插值
              .animation(this.getTileAnimation())
            }, (tile: TileData) => tile.id.toString())
          }
          .width(this.innerSize()).height(this.innerSize())
          // 多个方块同时滑动/缩放，整体缓存为一张位图，减少渲染批次（P2-1）
          .renderGroup(true)
        }.width(this.boardSize).height(this.boardSize)
        .backgroundColor(SemanticColors.boardBg)
        .border({ width: 2, color: SemanticColors.boardBorder, radius: RadiusTokens.base })
        .padding(4)
        .gesture(PanGesture({ direction: PanDirection.All })
          .onActionStart((e: GestureEvent) => { this.sx = e.offsetX; this.sy = e.offsetY; })
          .onActionEnd((e: GestureEvent) => {
            const dx = e.offsetX - this.sx;
            const dy = e.offsetY - this.sy;
            if (Math.abs(dx) > Math.abs(dy)) {
              this.swipe(() => { return dx > 0 ? this.viewModel.swipeRight() : this.viewModel.swipeLeft(); });
            } else {
              this.swipe(() => { return dy > 0 ? this.viewModel.swipeDown() : this.viewModel.swipeUp(); });
            }
          }))
        .layoutWeight(1).justifyContent(FlexAlign.Center)

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
