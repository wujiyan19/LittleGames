/**
 * 数独 —— ViewModel 层
 *
 * 持有 UI 状态（@ObservedV2 + @Trace），编排生成/校验规则(Model) + 持久化。
 * 棋盘用一维 81 格数组（copy-on-write 整体赋值）；题面固定格 fixed 为私有。
 * 本游戏无暂停玩法：status 只有 进行中 ⇄ 已结束 两态。
 */
import { GameDifficulty, GameStatus } from '../common/GameConstants';
import { GameDataManager } from '../model/GameData';
import { GameLifecycleObserver } from '../common/GameLifecycleBus';
import { PuzzleResult, SudokuRules } from '../model/game/SudokuModel';
import { RandomSource, RealRandom } from '../model/game/RandomSource';

const GAME_ID = 'sudoku';

@ObservedV2
export class SudokuViewModel implements GameLifecycleObserver {
  @Trace board: number[] = [];
  @Trace selectedRow: number = -1;
  @Trace selectedCol: number = -1;
  @Trace status: GameStatus = GameStatus.PLAYING;
  @Trace difficulty: GameDifficulty = GameDifficulty.NORMAL;
  /** 退出确认弹窗显隐（F2：对局中返回需确认，防误丢填题进度） */
  @Trace confirmExit: boolean = false;

  private rules: SudokuRules = new SudokuRules();
  private rng: RandomSource;
  // 题面固定格（Given），整局不变
  private fixed: boolean[] = [];
  // 当前题面（用于「重新开始」还原）
  private puzzle: number[] = [];
  // 上一把题面指纹
  private previousKey: string = '';

  constructor(rng?: RandomSource) {
    this.rng = rng ?? new RealRandom();
  }

  newGame(): void {
    const result: PuzzleResult = this.rules.generatePuzzle(this.difficulty, this.previousKey, this.rng);
    this.previousKey = result.key;
    this.startGame(result.puzzle);
  }

  restartGame(): void {
    this.startGame(this.puzzle);
  }

  private startGame(puzzle: number[]): void {
    GameDataManager.incrementPlayCount(GAME_ID);
    const b = this.rules.copyGrid(puzzle);
    const f: boolean[] = [];
    for (let i = 0; i < 81; i++) { f.push(puzzle[i] !== 0); }
    this.board = b;
    this.fixed = f;
    this.puzzle = this.rules.copyGrid(puzzle);
    this.status = GameStatus.PLAYING;
    this.selectedRow = -1;
    this.selectedCol = -1;
  }

  changeDifficulty(d: GameDifficulty): void {
    if (this.difficulty === d) { return; }
    this.difficulty = d;
    this.newGame();
  }

  selectCell(r: number, c: number): void {
    this.selectedRow = r;
    this.selectedCol = c;
  }

  private setCell(index: number, value: number): void {
    const next = this.board.slice();
    next[index] = value;
    this.board = next;
  }

  setNumber(n: number): void {
    const r = this.selectedRow;
    const c = this.selectedCol;
    if (r < 0 || c < 0 || this.status === GameStatus.OVER) { return; }
    const idx = r * 9 + c;
    if (this.fixed[idx]) { return; }
    this.setCell(idx, n);
    this.checkComplete();
  }

  erase(): void {
    const r = this.selectedRow;
    const c = this.selectedCol;
    if (r < 0 || c < 0) { return; }
    const idx = r * 9 + c;
    if (this.fixed[idx]) { return; }
    this.setCell(idx, 0);
  }

  private checkComplete(): void {
    if (!this.rules.isComplete(this.board)) { return; }
    this.status = GameStatus.OVER;
    // 难度越高完成得分越高
    let score = 100;
    if (this.difficulty === GameDifficulty.NORMAL) { score = 200; }
    else if (this.difficulty === GameDifficulty.HARD) { score = 300; }
    GameDataManager.updateHighScore(GAME_ID, score);
  }

  // —— 供 View 渲染的只读查询 ——
  cellValue(r: number, c: number): number { return this.board[r * 9 + c]; }
  isFixed(r: number, c: number): boolean { return this.fixed[r * 9 + c]; }

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
