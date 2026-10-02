/**
 * 跳一跳 —— ViewModel 层
 *
 * 持有 UI 状态（@ObservedV2 + @Trace），编排规则(Model) + 持久化。
 * 结算时机沿用项目既有口径：startGame() 先结算上一局、onAppHidden()、
 * dispose()、游戏结束立即结算。
 *
 * 坐标口径：所有平台/角色坐标在每次落定后「归一化」——把新当前平台
 * 平移回屏幕左侧基准位，使世界坐标恒等于屏幕坐标，数值不会随局内进度无限增长。
 *
 * 动画口径（遵守 AGENTS.md ArkUI 动画规范）：
 * - 跳跃位移用 translate（图形变换，不触发布局）；
 * - 角色压缩用 scale（不改 width/height）；
 * - 蓄力条增长用 scale + transformOrigin（不改 width）。
 */
import { GameDifficulty, GameStatus } from '../common/GameConstants';
import { ContinuationValidation as V } from '../common/GameSessionTransfer';
import { GameDataManager } from '../model/GameData';
import { GameLifecycleObserver } from '../common/GameLifecycleBus';
import { ScreenUtils } from '../common/ScreenUtils';
import { FrameLoop } from '../common/FrameLoop';
import { JumpJumpRules, JumpPlatform, JumpOutcome } from '../model/game/JumpJumpModel';


const GAME_ID = 'jumpjump';
/** 蓄满所需按住时长（ms） */
const CHARGE_FULL_MS = 1200;
/** 初始平台数量 */
const INITIAL_PLATFORMS = 12;
/** 每次补充的平台数量 */
const REFILL_PLATFORMS = 6;
/** 当前平台在屏幕上的固定水平位置占比 */
const BASE_SCREEN_RATIO = 0.18;

/** 平台视图数据：@ObservedV2 + @Trace 以便原地改 centerX 触发重渲染 */
@ObservedV2
export class PlatformData {
  readonly id: number;
  @Trace centerX: number;
  @Trace width: number;

  constructor(id: number, centerX: number, width: number) {
    this.id = id;
    this.centerX = centerX;
    this.width = width;
  }
}


interface JumpJumpContinuationState {
  version: number;
  score: number;
  highScore: number;
  status: GameStatus;
  difficulty: GameDifficulty;
  platforms: PlatformData[];
  currentIndex: number;
  playerX: number;
  playerJumpX: number;
  playerJumpY: number;
  playerDropY: number;
  isJumping: boolean;
  platformId: number;
  motionElapsed: number;
  motionDuration: number;
  motionDistance: number;
  pendingLanding: boolean;
  pendingLandingX: number;
  pendingFall: boolean;
}

@ObservedV2
export class JumpJumpViewModel implements GameLifecycleObserver {
  @Trace score: number = 0;
  @Trace highScore: number = 0;
  @Trace status: GameStatus = GameStatus.PLAYING;
  @Trace difficulty: GameDifficulty = GameDataManager.getInitialDifficulty(GAME_ID);
  /** 退出确认弹窗显隐（对局中返回需二次确认） */
  @Trace confirmExit: boolean = false;

  @Trace platforms: PlatformData[] = [];
  @Trace currentIndex: number = 0;
  /** 角色中心屏幕 x（归一化后世界坐标 == 屏幕坐标） */
  @Trace playerX: number = 0;
  /** 角色跳跃位移（抛物线，translate 表达） */
  @Trace playerJumpX: number = 0;
  @Trace playerJumpY: number = 0;
  /** 落空后的下落位移 */
  @Trace playerDropY: number = 0;
  /** 角色形变（压缩用 scale 表达，不改 height） */
  @Trace playerScaleX: number = 1;
  @Trace playerScaleY: number = 1;

  @Trace chargeRatio: number = 0;
  @Trace isCharging: boolean = false;
  @Trace isJumping: boolean = false;


  private platformId: number = 0;
  private frames: FrameLoop | null = null;
  private appVisible: boolean = true;
  private motionElapsed: number = 0;
  private motionDuration: number = 0;
  private motionDistance: number = 0;
  private chargeStartTs: number = 0;
  private chargeElapsed: number = 0;
  private pendingLanding: boolean = false;
  private pendingLandingX: number = 0;
  private pendingTarget: PlatformData | null = null;
  private pendingFall: boolean = false;

  constructor() {
    this.highScore = GameDataManager.getGameById(GAME_ID)?.highScore ?? 0;
  }

  /** 当前平台应在的屏幕基准 x */
  baseScreenX(): number {
    const w: number = ScreenUtils.windowWidthVp();
    if (w <= 0) { return 100; }
    return w * BASE_SCREEN_RATIO;
  }

  /** 当前平台的视图数据（可能越界，调用方自行判空） */
  currentPlatform(): PlatformData | undefined {
    if (this.currentIndex < 0 || this.currentIndex >= this.platforms.length) { return undefined; }
    return this.platforms[this.currentIndex];
  }

  isCurrentPlatform(id: number): boolean {
    return this.currentPlatform()?.id === id;
  }

  isNextPlatform(id: number): boolean {
    return this.platforms[this.currentIndex + 1]?.id === id;
  }

  // ---------------- 对局生命周期 ----------------

  /** 开局：结算上一局 → 记一次游玩 → 重置对局 */
  startGame(): void {
    this.frames?.stop();
    this.settleCurrentScore();
    GameDataManager.incrementPlayCount(GAME_ID);
    this.newGame();
  }

  /** 只铺开局数据（初始化/单测用），不记游玩次数 */
  newGame(): void {
    this.frames?.stop();
    this.pendingTarget = null;
    this.pendingFall = false;
    this.score = 0;
    this.status = GameStatus.PLAYING;
    this.confirmExit = false;
    this.isCharging = false;
    this.isJumping = false;
    this.chargeRatio = 0;
    this.playerScaleX = 1;
    this.playerScaleY = 1;
    this.playerJumpX = 0;
    this.playerJumpY = 0;
    this.playerDropY = 0;
    this.buildPlatforms();
  }

  private buildPlatforms(): void {
    const cfgWidth: number = JumpJumpRules.configFor(this.difficulty).width;
    const base: number = this.baseScreenX();
    const list: PlatformData[] = [];
    this.platformId = 0;
    let cur: JumpPlatform = new JumpPlatform(base, cfgWidth);
    list.push(new PlatformData(++this.platformId, cur.centerX, cur.width));
    for (let i = 1; i < INITIAL_PLATFORMS; i++) {
      cur = JumpJumpRules.spawnNext(cur, this.difficulty);
      list.push(new PlatformData(++this.platformId, cur.centerX, cur.width));
    }
    this.platforms = list;
    this.currentIndex = 0;
    this.playerX = base;
  }

  private ensurePlatforms(): void {
    if (this.currentIndex + 6 < this.platforms.length) { return; }
    const last: PlatformData = this.platforms[this.platforms.length - 1];
    let cur: JumpPlatform = new JumpPlatform(last.centerX, last.width);
    const extra: PlatformData[] = [];
    for (let i = 0; i < REFILL_PLATFORMS; i++) {
      cur = JumpJumpRules.spawnNext(cur, this.difficulty);
      extra.push(new PlatformData(++this.platformId, cur.centerX, cur.width));
    }
    this.platforms = this.platforms.concat(extra);
  }

  /** 归一化：把新当前平台平移回屏幕基准位（世界坐标恒等于屏幕坐标） */
  private normalize(): void {
    const cur: PlatformData | undefined = this.currentPlatform();
    if (cur === undefined) { return; }
    const shift: number = cur.centerX - this.baseScreenX();
    if (shift <= 0.5) { return; }
    for (let i = 0; i < this.platforms.length; i++) {
      this.platforms[i].centerX = this.platforms[i].centerX - shift;
    }
    this.playerX = this.playerX - shift;
    // 只删除已离屏且不会再参与落台判定的历史平台，保留稳定 id。
    let removeCount: number = 0;
    while (removeCount < this.currentIndex - 1) {
      const old: PlatformData = this.platforms[removeCount];
      if (old.centerX + old.width / 2 >= -20) { break; }
      removeCount++;
    }
    if (removeCount > 0) {
      this.platforms = this.platforms.slice(removeCount);
      this.currentIndex -= removeCount;
    }
  }

  // ---------------- 蓄力 ----------------

  /** 按住：开始蓄力（仅进行中、未跳跃时接受） */
  beginCharge(): void {
    if (!this.appVisible || this.confirmExit || this.status !== GameStatus.PLAYING || this.isJumping || this.isCharging) { return; }
    this.isCharging = true;
    this.chargeRatio = 0;
    this.chargeStartTs = Date.now();
    this.chargeElapsed = 0;
    this.startFrames();
  }

  private tickCharge(): void {
    const elapsed: number = Math.max(this.chargeElapsed, Date.now() - this.chargeStartTs);
    let r: number = elapsed / CHARGE_FULL_MS;
    if (r > 1) { r = 1; }
    this.chargeRatio = r;
    this.applyChargeShape();
    if (r >= 1) { this.frames?.stop(); }
  }

  private applyChargeShape(): void {
    const r: number = this.chargeRatio;
    this.playerScaleX = 1 + r * 0.3;
    this.playerScaleY = 1 - r * 0.32;
  }

  /** 松手：结束蓄力并起跳。角色形变立即复原；蓄力条保留到本次跳跃结束 */
  endCharge(): void {
    if (!this.isCharging) { return; }
    if (!this.appVisible || this.confirmExit) { this.abortCharge(); return; }
    this.tickCharge();
    this.isCharging = false;
    this.frames?.stop();
    const ratio: number = this.chargeRatio;
    this.playerScaleX = 1;
    this.playerScaleY = 1;
    this.launchJump(ratio);
  }

  /** 中断蓄力（切后台 / 销毁），复位形变与蓄力条，不产生跳跃 */
  abortCharge(): void {
    if (!this.isCharging) { return; }
    this.isCharging = false;
    this.frames?.stop();
    this.chargeRatio = 0;
    this.playerScaleX = 1;
    this.playerScaleY = 1;
  }

  // ---------------- 跳跃 ----------------

  private launchJump(ratio: number): void {
    const target: PlatformData | undefined = this.platforms[this.currentIndex + 1];
    if (target === undefined) { return; }
    const distance: number = JumpJumpRules.jumpDistance(ratio, this.difficulty);
    const landingX: number = this.playerX + distance;
    const outcome: JumpOutcome =
      JumpJumpRules.judge(landingX, new JumpPlatform(target.centerX, target.width));

    this.isJumping = true;
    this.pendingLanding = outcome.landed;
    this.pendingLandingX = landingX;
    this.pendingTarget = target;
    this.motionDuration = 260 + distance * 0.9;
    this.motionDistance = distance;
    this.motionElapsed = 0;
    this.startFrames();
  }

  setFrameLoop(frames: FrameLoop): void {
    this.frames?.dispose();
    this.frames = frames;
  }

  private startFrames(): void {
    if (!this.appVisible || this.confirmExit || this.status !== GameStatus.PLAYING) { return; }
    if (this.isCharging && this.chargeRatio >= 1) { return; }
    if (!this.isCharging && !this.isJumping) { return; }
    this.frames?.start((deltaMs: number) => { this.advanceFrame(deltaMs); });
  }

  advanceFrame(deltaMs: number): void {
    if (!this.appVisible || this.confirmExit || this.status !== GameStatus.PLAYING) { return; }
    if (this.isCharging) {
      this.chargeElapsed += Math.max(0, deltaMs);
      this.tickCharge();
      return;
    }
    if (!this.isJumping) { return; }
    this.motionElapsed += Math.max(0, deltaMs);
    const t: number = Math.min(1, this.motionElapsed / this.motionDuration);
    if (this.pendingFall) {
      this.playerDropY = 460 * t * t;
      if (t >= 1) {
        this.frames?.stop();
        this.pendingFall = false;
        this.endGame();
      }
    } else {
      this.playerJumpX = this.motionDistance * t;
      this.playerJumpY = -4 * 84 * t * (1 - t);
      const target: PlatformData | null = this.pendingTarget;
      if (t >= 1 && target !== null) {
        this.frames?.stop();
        this.pendingTarget = null;
        this.settleJump(this.pendingLanding, this.pendingLandingX, target);
      }
    }
  }

  private settleJump(landed: boolean, landingX: number, target: PlatformData): void {
    this.playerJumpX = 0;
    this.playerJumpY = 0;
    this.chargeRatio = 0;
    if (landed) {
      // 成功：吸附到目标平台中心，得分 +1，推进平台序列
      this.playerX = target.centerX;
      this.currentIndex++;
      this.score++;
      if (this.score > this.highScore) { this.highScore = this.score; }
      this.isJumping = false;
      this.normalize();
      this.ensurePlatforms();
    } else {
      // 落空：停在落点后向下掉落
      this.playerX = landingX;
      this.startFall();
    }
  }

  private startFall(): void {
    this.chargeRatio = 0;
    this.pendingFall = true;
    this.motionElapsed = 0;
    this.motionDuration = 520;
    this.startFrames();
  }

  private endGame(): void {
    this.isJumping = false;
    this.status = GameStatus.OVER;
    GameDataManager.updateHighScore(GAME_ID, this.score);
  }

  // ---------------- 难度 / 返回 / 生命周期 ----------------

  changeDifficulty(d: GameDifficulty): void {
    GameDataManager.rememberGameDifficulty(GAME_ID, d);
    if (this.difficulty === d) { return; }
    this.difficulty = d;
    this.startGame();
  }

  /** 系统侧滑返回转发（NavDestination.onBackPressed） */
  onBackRequested(): boolean {
    return this.requestBack();
  }

  /** 页面返回按钮与系统侧滑共用：进行中弹确认，其余放行 */
  requestBack(): boolean {
    if (!GameDataManager.getSetting('confirmExitEnabled', true)) { return false; }
    if (this.status === GameStatus.PLAYING) {
      this.confirmExit = true;
      this.abortCharge();
      this.frames?.stop();
      return true;
    }
    return false;
  }

  dismissExitConfirm(): void {
    this.confirmExit = false;
    this.startFrames();
  }

  /** 结算当前对局分数（max 语义幂等） */
  private settleCurrentScore(): void {
    if (this.score > 0) { GameDataManager.updateHighScore(GAME_ID, this.score); }
  }

  /** 后台/遮挡时冻结运动；前台恢复从原进度继续，不补后台经过的时间。 */
  onAppHidden(): void {
    this.appVisible = false;
    this.abortCharge();
    this.frames?.stop();
    this.settleCurrentScore();
  }

  onAppShown(): void {
    this.appVisible = true;
    this.startFrames();
  }

  /** 页面销毁：停帧回调并结算。 */
  dispose(): void {
    this.appVisible = false;
    this.frames?.dispose();
    this.frames = null;
    this.pendingTarget = null;
    this.pendingFall = false;
    this.settleCurrentScore();
  }

  continuationGameId(): string { return GAME_ID; }

  /** Capture only game data; exporting never pauses or mutates the source game. */
  exportContinuation(): string {

    const state: JumpJumpContinuationState = {
      version: 1,
      score: this.score,
      highScore: this.highScore,
      status: this.status,
      difficulty: this.difficulty,
      platforms: this.platforms,
      currentIndex: this.currentIndex,
      playerX: this.playerX,
      playerJumpX: this.playerJumpX,
      playerJumpY: this.playerJumpY,
      playerDropY: this.playerDropY,
      isJumping: this.isJumping,
      platformId: this.platformId,
      motionElapsed: this.motionElapsed,
      motionDuration: this.motionDuration,
      motionDistance: this.motionDistance,
      pendingLanding: this.pendingLanding,
      pendingLandingX: this.pendingLandingX,
      pendingFall: this.pendingFall
    };
    return JSON.stringify(state);
  }

  /** Validate completely before replacing a running game. Rebuild observed class instances. */
  importContinuation(payload: string): boolean {
    try {
      if (payload.length > 65536) { return false; }
      const s: JumpJumpContinuationState = JSON.parse(payload) as JumpJumpContinuationState;
      if (s === null || s.version !== 1 || !V.integer(s.score) ||
          !V.integer(s.highScore) ||
          (s.status !== GameStatus.PLAYING && s.status !== GameStatus.PAUSED && s.status !== GameStatus.OVER && s.status !== GameStatus.IDLE) ||
          (s.difficulty !== GameDifficulty.EASY && s.difficulty !== GameDifficulty.NORMAL && s.difficulty !== GameDifficulty.HARD) ||
          !V.integer(s.currentIndex) ||
          !V.finite(s.playerX) ||
          !V.finite(s.playerJumpX) ||
          !V.finite(s.playerJumpY) ||
          !V.finite(s.playerDropY) ||
          typeof s.isJumping !== 'boolean' ||
          !V.integer(s.platformId) ||
          !V.finite(s.motionElapsed) ||
          !V.finite(s.motionDuration) ||
          !V.finite(s.motionDistance) ||
          typeof s.pendingLanding !== 'boolean' ||
          !V.finite(s.pendingLandingX) ||
          typeof s.pendingFall !== 'boolean') { return false; }
      if (!Array.isArray(s.platforms) || s.platforms.length < 2 || s.platforms.length > 100 ||
          !V.integer(s.currentIndex, 0, s.platforms.length - 1)) { return false; }
      for (let i = 0; i < s.platforms.length; i++) {
        const p: PlatformData = s.platforms[i];
        if (p === null || !V.integer(p.id, 1) || !V.finite(p.centerX) || !V.finite(p.width) || p.width <= 0) { return false; }
      }
      if (s.isJumping && !s.pendingFall && s.currentIndex + 1 >= s.platforms.length) { return false; }
      if (s.isJumping && s.motionDuration <= 0) { return false; }
      this.frames?.stop();
      this.score = s.score;
      this.highScore = Math.max(s.highScore, GameDataManager.getGameById(GAME_ID)?.highScore ?? 0);
      GameDataManager.updateHighScore(GAME_ID, this.highScore);
      this.status = s.status;
      this.difficulty = s.difficulty;
      this.platforms = s.platforms;
      this.currentIndex = s.currentIndex;
      this.playerX = s.playerX;
      this.playerJumpX = s.playerJumpX;
      this.playerJumpY = s.playerJumpY;
      this.playerDropY = s.playerDropY;
      this.isJumping = s.isJumping;
      this.platformId = s.platformId;
      this.motionElapsed = s.motionElapsed;
      this.motionDuration = s.motionDuration;
      this.motionDistance = s.motionDistance;
      this.pendingLanding = s.pendingLanding;
      this.pendingLandingX = s.pendingLandingX;
      this.pendingFall = s.pendingFall;
      this.confirmExit = false;
      this.platforms = s.platforms.map((p: PlatformData): PlatformData => new PlatformData(p.id, p.centerX, p.width));
      // Preserve distances and the in-flight trajectory while anchoring to the target window.
      const shift: number = this.baseScreenX() - this.platforms[this.currentIndex].centerX;
      for (let i = 0; i < this.platforms.length; i++) { this.platforms[i].centerX += shift; }
      this.playerX += shift;
      this.pendingLandingX += shift;
      this.pendingTarget = this.isJumping && !this.pendingFall ? this.platforms[this.currentIndex + 1] : null;
      this.appVisible = true;
      this.isCharging = false;
      this.chargeRatio = 0;
      this.playerScaleX = 1;
      this.playerScaleY = 1;
      this.startFrames();
      return true;
    } catch (e) {
      return false;
    }
  }
}
