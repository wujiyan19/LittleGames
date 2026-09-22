/**
 * 2048 —— ViewModel 层
 *
 * 持有 UI 状态（@ObservedV2 + @Trace），编排规则(Model) + 持久化。
 * 额外暴露「最近生成格」(spawnRow/spawnCol)，供 View 做新块弹入动画。
 * View 只与它交互，不接触 Model 类型。
 */
import { GameDifficulty, GameStatus } from '../common/GameConstants';
import { GameDataManager } from '../model/GameData';
import { GameLifecycleObserver } from '../common/GameLifecycleBus';
import { Game2048Rules, SpawnResult, SwipeDir, SwipeResult } from '../model/game/Game2048Model';
import { RandomSource, RealRandom } from '../model/game/RandomSource';

const SIZE = 4;
const GAME_ID = '2048';

@ObservedV2
export class Game2048ViewModel implements GameLifecycleObserver {
  @Trace board: number[][] = [[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]];
  @Trace score: number = 0;
  @Trace highScore: number = 0;
  @Trace status: GameStatus = GameStatus.PLAYING;
  @Trace difficulty: GameDifficulty = GameDifficulty.NORMAL;
  /** 最近一次生成的新块位置，-1 表示无（供 View 动画） */
  @Trace spawnRow: number = -1;
  @Trace spawnCol: number = -1;
  /** 退出确认弹窗显隐（F2：对局中返回需确认） */
  @Trace confirmExit: boolean = false;

  private rules: Game2048Rules = new Game2048Rules(SIZE);
  private rng: RandomSource;
  /** 最近一次滑动「每格来源」（供 View 计算位移动画）。
   *  @Trace：rebuildTiles() 通过 sourceAt() 读取此字段判断方块来源，
   *  若不加 @Trace，框架无法追踪依赖，滑动后方块身份判定可能出错。 */
  @Trace private lastSources: number[] = [];

  constructor(rng?: RandomSource) {
    this.rng = rng ?? new RealRandom();
    this.highScore = GameDataManager.getGameById(GAME_ID)?.highScore ?? 0;
  }

  size(): number { return SIZE; }

  getFourChance(): number {
    if (this.difficulty === GameDifficulty.EASY) { return 0.05; }
    if (this.difficulty === GameDifficulty.HARD) { return 0.2; }
    return 0.1;
  }

  changeDifficulty(d: GameDifficulty): void {
    if (this.difficulty === d) { return; }
    this.difficulty = d;
    this.startGame();
  }

  /** 只铺开局数据（初始化/单测用） */
  newGame(): void {
    GameDataManager.incrementPlayCount(GAME_ID);
    this.board = this.rules.emptyBoard();
    this.score = 0;
    this.status = GameStatus.PLAYING;
    this.lastSources = [];
    this.spawnRow = -1;
    this.spawnCol = -1;
    this.spawnTile();
    this.spawnTile();
  }

  startGame(): void {
    if (this.score > 0) { GameDataManager.updateHighScore(GAME_ID, this.score); }
    this.newGame();
  }

  private spawnTile(): void {
    const res: SpawnResult = this.rules.spawn(this.board, this.getFourChance(), this.rng);
    this.board = res.board;
    this.spawnRow = res.row;
    this.spawnCol = res.col;
  }

  swipeLeft(): boolean { return this.swipe(SwipeDir.LEFT); }
  swipeRight(): boolean { return this.swipe(SwipeDir.RIGHT); }
  swipeUp(): boolean { return this.swipe(SwipeDir.UP); }
  swipeDown(): boolean { return this.swipe(SwipeDir.DOWN); }

  /** 执行滑动，返回棋盘是否变化；View 据此决定是否重排方块 */
  private swipe(dir: SwipeDir): boolean {
    if (this.status !== GameStatus.PLAYING) { return false; }
    const result: SwipeResult = this.rules.swipe(this.board, dir);
    if (!result.changed) { return false; }
    this.lastSources = result.sources;
    this.board = result.board;
    this.score += result.gained;
    this.spawnTile();
    if (this.score > this.highScore) { this.highScore = this.score; }
    if (this.rules.isGameOver(this.board)) {
      this.status = GameStatus.OVER;
      GameDataManager.updateHighScore(GAME_ID, this.score);
    }
    return true;
  }

  /** 目标格(索引)在滑动前的来源格索引，-1 表示空格/无效 */
  sourceAt(index: number): number {
    if (index < 0 || index >= this.lastSources.length) { return -1; }
    return this.lastSources[index];
  }

  /**
   * 结算当前对局分数（max 语义幂等）。无定时器，切后台只需结算不需暂停。
   * 原先只在对局结束/下次开局时结算，中途退出会静默丢失当前得分。
   */
  private settleCurrentScore(): void {
    if (this.score > 0) { GameDataManager.updateHighScore(GAME_ID, this.score); }
  }

  /** 切后台（GameLifecycleBus）：结算当前分。无定时器，无需暂停 */
  onAppHidden(): void {
    this.settleCurrentScore();
  }

  onAppShown(): void {
  }

  /** 系统侧滑返回转发（NavDestination.onBackPressed）。进行中弹确认并拦截 */
  onBackRequested(): boolean {
    return this.requestBack();
  }

  /** 页面返回按钮与系统侧滑共用：进行中弹确认，其余放行 */
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

  cellValue(r: number, c: number): number {
    return this.board[r][c];
  }

  isOver(): boolean {
    return this.rules.isGameOver(this.board);
  }

  /** 页面销毁：结算当前分（无定时器可停） */
  dispose(): void {
    this.settleCurrentScore();
  }
}
