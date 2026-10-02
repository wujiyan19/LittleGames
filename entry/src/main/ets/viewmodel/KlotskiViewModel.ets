/**
 * 华容道 —— ViewModel 层
 *
 * 持有 UI 状态（@ObservedV2 + @Trace），编排规则(Model) + 持久化。
 * 棋子/网格为本层私有，对外只暴露只读查询（种类/标签/选中），View 不接触 Model 类型。
 * 本游戏无暂停玩法：status 只有 进行中 ⇄ 已结束 两态。
 */
import { GameDifficulty, GameStatus } from '../common/GameConstants';
import { ContinuationValidation as V } from '../common/GameSessionTransfer';
import { GameDataManager } from '../model/GameData';
import { GameLifecycleObserver } from '../common/GameLifecycleBus';
import { KlotskiBlock, KlotskiRules } from '../model/game/KlotskiModel';

const BW = 4;
const BH = 5;
const GAME_ID = 'klotski';

/** A whole movable piece, kept separate from the rule model for the view. */
@ObservedV2
export class KlotskiPieceView {
  id: string;
  @Trace x: number = 0;
  @Trace y: number = 0;
  @Trace w: number = 1;
  @Trace h: number = 1;
  @Trace kind: number = 0;
  @Trace label: string = '';
  @Trace selected: boolean = false;

  constructor(id: string, x: number, y: number, w: number, h: number, kind: number, label: string, selected: boolean) {
    this.id = id;
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
    this.kind = kind;
    this.label = label;
    this.selected = selected;
  }
}


interface KlotskiContinuationState {
  version: number;
  blocks: KlotskiBlock[];
  selId: string;
  stepCount: number;
  status: GameStatus;
  difficulty: GameDifficulty;
}

@ObservedV2
export class KlotskiViewModel implements GameLifecycleObserver {
  @Trace private blocks: KlotskiBlock[] = [];
  @Trace private grid: (string | null)[][] = [];
  @Trace private selId: string = '';
  @Trace private pieceViews: KlotskiPieceView[] = [];
  @Trace stepCount: number = 0;
  @Trace status: GameStatus = GameStatus.PLAYING;
  @Trace difficulty: GameDifficulty = GameDataManager.getInitialDifficulty(GAME_ID);
  /** 退出确认弹窗显隐（F2：对局中返回需确认，防误丢步数进度） */
  @Trace confirmExit: boolean = false;

  private rules: KlotskiRules = new KlotskiRules(BW, BH);

  startGame(): void {
    GameDataManager.incrementPlayCount(GAME_ID);
    this.blocks = this.rules.layout(this.difficulty);
    this.grid = this.rules.buildGrid(this.blocks);
    this.stepCount = 0;
    this.status = GameStatus.PLAYING;
    this.selId = '';
    this.syncPieceViews();
  }

  changeDifficulty(d: GameDifficulty): void {
    GameDataManager.rememberGameDifficulty(GAME_ID, d);
    if (this.difficulty === d) { return; }
    this.difficulty = d;
    this.startGame();
  }

  /** 点击某格：选中/取消该格棋子 */
  selectBlockAt(r: number, c: number): void {
    if (this.status !== GameStatus.PLAYING) { return; }
    const id = this.grid[r][c];
    if (id === null) { return; }
    this.selId = (this.selId === id) ? '' : id;
    this.syncPieceViews();
  }

  moveBlock(dx: number, dy: number): void {
    if (this.selId === '' || this.status !== GameStatus.PLAYING) { return; }
    if (!this.rules.canMove(this.blocks, this.grid, this.selId, dx, dy)) { return; }
    this.blocks = this.rules.apply(this.blocks, this.selId, dx, dy);
    this.grid = this.rules.buildGrid(this.blocks);
    this.stepCount++;
    this.syncPieceViews();
    const moved = this.rules.find(this.blocks, this.selId);
    if (moved && this.rules.isWin(moved)) {
      this.status = GameStatus.OVER;
      // 步数越少得分越高
      GameDataManager.updateHighScore(GAME_ID, this.rules.score(this.stepCount));
    }
  }

  // —— 供 View 渲染的只读查询 ——
  /** 0=空 1=曹操 2=横将 3=竖将 4=小兵 */
  blockKind(r: number, c: number): number {
    const id = this.grid[r][c];
    if (id === null) { return 0; }
    const b = this.rules.find(this.blocks, id);
    return b ? this.rules.kind(b) : 0;
  }

  /** 仅当该格是棋子的左上角时返回文字，否则空串 */
  blockLabel(r: number, c: number): string {
    const id = this.grid[r][c];
    if (id === null) { return ''; }
    const b = this.rules.find(this.blocks, id);
    if (!b) { return ''; }
    if (b.x === c && b.y === r) { return this.rules.label(b); }
    return '';
  }

  isSelected(r: number, c: number): boolean {
    return this.selId !== '' && this.grid[r][c] === this.selId;
  }

  private syncPieceViews(): void {
    const pieces: KlotskiPieceView[] = [];
    for (let i = 0; i < this.blocks.length; i++) {
      const block = this.blocks[i];
      let piece: KlotskiPieceView | undefined = this.pieceViews.find((item: KlotskiPieceView) => item.id === block.id);
      if (piece === undefined) {
        piece = new KlotskiPieceView(block.id, block.x, block.y, block.w, block.h,
          this.rules.kind(block), this.rules.label(block), this.selId === block.id);
      } else {
        piece.x = block.x;
        piece.y = block.y;
        piece.w = block.w;
        piece.h = block.h;
        piece.kind = this.rules.kind(block);
        piece.label = this.rules.label(block);
        piece.selected = this.selId === block.id;
      }
      pieces.push(piece);
    }
    this.pieceViews = pieces;
  }

  piecesForView(): KlotskiPieceView[] {
    return this.pieceViews;
  }

  // —— GameLifecycleObserver（完成才计分、无定时器：切后台无需暂停/结算）——
  onAppHidden(): void {
  }

  onAppShown(): void {
  }

  /** 系统侧滑返回转发（NavDestination.onBackPressed）。进行中弹确认并拦截 */
  onBackRequested(): boolean {
    return this.requestBack();
  }

  /** 页面返回按钮与系统侧滑共用：进行中弹确认（进度无保存机制，防误退），其余放行 */
  requestBack(): boolean {
    if (!GameDataManager.getSetting('confirmExitEnabled', true)) { return false; }
    if (this.status === GameStatus.PLAYING) {
      this.confirmExit = true;
      return true;
    }
    return false;
  }

  dismissExitConfirm(): void {
    this.confirmExit = false;
  }

  /** 页面销毁：无定时器可停（保持全部 VM 的 dispose 形态统一） */
  dispose(): void {
  }

  continuationGameId(): string { return GAME_ID; }

  /** Capture only game data; exporting never pauses or mutates the source game. */
  exportContinuation(): string {

    const state: KlotskiContinuationState = {
      version: 1,
      blocks: this.blocks,
      selId: this.selId,
      stepCount: this.stepCount,
      status: this.status,
      difficulty: this.difficulty
    };
    return JSON.stringify(state);
  }

  /** Validate completely before replacing a running game. Rebuild observed class instances. */
  importContinuation(payload: string): boolean {
    try {
      if (payload.length > 65536) { return false; }
      const s: KlotskiContinuationState = JSON.parse(payload) as KlotskiContinuationState;
      if (s === null || s.version !== 1 || typeof s.selId !== 'string' || s.selId.length > 4096 ||
          !V.integer(s.stepCount) ||
          (s.status !== GameStatus.PLAYING && s.status !== GameStatus.PAUSED && s.status !== GameStatus.OVER && s.status !== GameStatus.IDLE) ||
          (s.difficulty !== GameDifficulty.EASY && s.difficulty !== GameDifficulty.NORMAL && s.difficulty !== GameDifficulty.HARD)) { return false; }
      const layout: KlotskiBlock[] = this.rules.layout(s.difficulty);
      if (!Array.isArray(s.blocks) || s.blocks.length !== layout.length) { return false; }
      const occupied: Set<number> = new Set<number>();
      const ids: Set<string> = new Set<string>();
      for (let i = 0; i < s.blocks.length; i++) {
        const b: KlotskiBlock = s.blocks[i];
        if (b === null || typeof b.id !== 'string' || !V.integer(b.w, 1, 2) || !V.integer(b.h, 1, 2) ||
            !V.integer(b.x, 0, BW - b.w) || !V.integer(b.y, 0, BH - b.h) || typeof b.target !== 'boolean') { return false; }
        const original: KlotskiBlock | undefined = this.rules.find(layout, b.id);
        if (original === undefined || original.w !== b.w || original.h !== b.h || original.target !== b.target) { return false; }
        ids.add(b.id);
        for (let y = b.y; y < b.y + b.h; y++) {
          for (let x = b.x; x < b.x + b.w; x++) {
            const cell: number = y * BW + x;
            if (occupied.has(cell)) { return false; }
            occupied.add(cell);
          }
        }
      }
      if (ids.size !== layout.length || (s.selId !== '' && !ids.has(s.selId))) { return false; }

      this.blocks = s.blocks;
      this.selId = s.selId;
      this.stepCount = s.stepCount;
      this.status = s.status;
      this.difficulty = s.difficulty;
      this.confirmExit = false;
      this.blocks = s.blocks.map((b: KlotskiBlock): KlotskiBlock => new KlotskiBlock(b.id, b.w, b.h, b.x, b.y, b.target));
      this.grid = this.rules.buildGrid(this.blocks);
      this.syncPieceViews();
      return true;
    } catch (e) {
      return false;
    }
  }
}
