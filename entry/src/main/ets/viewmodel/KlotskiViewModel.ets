/**
 * 华容道 —— ViewModel 层
 *
 * 持有 UI 状态（@ObservedV2 + @Trace），编排规则(Model) + 持久化。
 * 棋子/网格为本层私有，对外只暴露只读查询（种类/标签/选中），View 不接触 Model 类型。
 * 本游戏无暂停玩法：status 只有 进行中 ⇄ 已结束 两态。
 */
import { GameDifficulty, GameStatus } from '../common/GameConstants';
import { GameDataManager } from '../model/GameData';
import { GameLifecycleObserver } from '../common/GameLifecycleBus';
import { KlotskiBlock, KlotskiRules } from '../model/game/KlotskiModel';

const BW = 4;
const BH = 5;
const GAME_ID = 'klotski';

/** A whole movable piece, kept separate from the rule model for the view. */
export class KlotskiPieceView {
  id: string;
  x: number;
  y: number;
  w: number;
  h: number;
  kind: number;
  label: string;
  selected: boolean;

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

@ObservedV2
export class KlotskiViewModel implements GameLifecycleObserver {
  @Trace private blocks: KlotskiBlock[] = [];
  @Trace private grid: (string | null)[][] = [];
  @Trace private selId: string = '';
  @Trace stepCount: number = 0;
  @Trace status: GameStatus = GameStatus.PLAYING;
  @Trace difficulty: GameDifficulty = GameDifficulty.NORMAL;
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
  }

  changeDifficulty(d: GameDifficulty): void {
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
  }

  moveBlock(dx: number, dy: number): void {
    if (this.selId === '' || this.status !== GameStatus.PLAYING) { return; }
    if (!this.rules.canMove(this.blocks, this.grid, this.selId, dx, dy)) { return; }
    this.blocks = this.rules.apply(this.blocks, this.selId, dx, dy);
    this.grid = this.rules.buildGrid(this.blocks);
    this.stepCount++;
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

  piecesForView(): KlotskiPieceView[] {
    const pieces: KlotskiPieceView[] = [];
    for (let i = 0; i < this.blocks.length; i++) {
      const block = this.blocks[i];
      pieces.push(new KlotskiPieceView(
        block.id, block.x, block.y, block.w, block.h,
        this.rules.kind(block), this.rules.label(block), this.selId === block.id
      ));
    }
    return pieces;
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
}
