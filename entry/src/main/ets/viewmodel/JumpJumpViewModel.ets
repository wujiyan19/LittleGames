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
 * - 跳跃位移用 offset（合成属性，不触发布局）；
 * - 角色压缩用 scale（不改 width/height）；
 * - 蓄力条增长用 scale + transformOrigin（不改 width）。
 */
import { GameDifficulty, GameStatus } from '../common/GameConstants';
import { GameDataManager } from '../model/GameData';
import { GameLifecycleObserver } from '../common/GameLifecycleBus';
import { ScreenUtils } from '../common/ScreenUtils';
import { JumpJumpRules, JumpPlatform, JumpOutcome } from '../model/game/JumpJumpModel';


const GAME_ID = 'jumpjump';
/** 蓄满所需按住时长（ms） */
const CHARGE_FULL_MS = 1200;
/** 蓄力刷新间隔（ms） */
const CHARGE_TICK_MS = 30;
/** 跳跃动画帧间隔（ms） */
const FRAME_MS = 16;
/** 初始平台数量 */
const INITIAL_PLATFORMS = 12;
/** 每次补充的平台数量 */
const REFILL_PLATFORMS = 6;
/** 当前平台在屏幕上的固定水平位置占比 */
const BASE_SCREEN_RATIO = 0.28;

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

@ObservedV2
export class JumpJumpViewModel implements GameLifecycleObserver {
  @Trace score: number = 0;
  @Trace highScore: number = 0;
  @Trace status: GameStatus = GameStatus.PLAYING;
  @Trace difficulty: GameDifficulty = GameDifficulty.NORMAL;
  /** 退出确认弹窗显隐（对局中返回需二次确认） */
  @Trace confirmExit: boolean = false;

  @Trace platforms: PlatformData[] = [];
  @Trace currentIndex: number = 0;
  /** 角色中心屏幕 x（归一化后世界坐标 == 屏幕坐标） */
  @Trace playerX: number = 0;
  /** 角色跳跃位移（抛物线，offset 表达） */
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
  private chargeTimer: number = -1;
  private jumpTimer: number = -1;
  private dropTimer: number = -1;
  private chargeStartTs: number = 0;

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

  // ---------------- 对局生命周期 ----------------

  /** 开局：结算上一局 → 记一次游玩 → 重置对局 */
  startGame(): void {
    this.stopAllTimers();
    this.settleCurrentScore();
    GameDataManager.incrementPlayCount(GAME_ID);
    this.newGame();
  }

  /** 只铺开局数据（初始化/单测用），不记游玩次数 */
  newGame(): void {
    this.stopAllTimers();
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
  }

  // ---------------- 蓄力 ----------------

  /** 按住：开始蓄力（仅进行中、未跳跃时接受） */
  beginCharge(): void {
    if (this.status !== GameStatus.PLAYING || this.isJumping || this.isCharging) { return; }
    this.isCharging = true;
    this.chargeRatio = 0;
    this.chargeStartTs = Date.now();
    this.chargeTimer = setInterval(() => { this.tickCharge(); }, CHARGE_TICK_MS);
  }

  private tickCharge(): void {
    const elapsed: number = Date.now() - this.chargeStartTs;
    let r: number = elapsed / CHARGE_FULL_MS;
    if (r > 1) { r = 1; }
    this.chargeRatio = r;
    this.applyChargeShape();
  }

  private applyChargeShape(): void {
    const r: number = this.chargeRatio;
    this.playerScaleX = 1 + r * 0.3;
    this.playerScaleY = 1 - r * 0.32;
  }

  /** 松手：结束蓄力并起跳。角色形变立即复原；蓄力条保留到本次跳跃结束 */
  endCharge(): void {
    if (!this.isCharging) { return; }
    this.isCharging = false;
    this.stopChargeTimer();
    const ratio: number = this.chargeRatio;
    this.playerScaleX = 1;
    this.playerScaleY = 1;
    this.launchJump(ratio);
  }

  /** 中断蓄力（切后台 / 销毁），复位形变与蓄力条，不产生跳跃 */
  abortCharge(): void {
    if (!this.isCharging) { return; }
    this.isCharging = false;
    this.stopChargeTimer();
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
    const duration: number = 260 + distance * 0.9;
    const height: number = 84;
    const startTs: number = Date.now();
    this.jumpTimer = setInterval(() => {
      const raw: number = (Date.now() - startTs) / duration;
      const t: number = raw > 1 ? 1 : raw;
      this.playerJumpX = distance * t;
      // 抛物线：-4H·t·(1-t)
      this.playerJumpY = -4 * height * t * (1 - t);
      if (t >= 1) {
        this.stopJumpTimer();
        this.settleJump(outcome.landed, landingX, target);
      }
    }, FRAME_MS);
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
    const startTs: number = Date.now();
    this.dropTimer = setInterval(() => {
      const raw: number = (Date.now() - startTs) / 520;
      const t: number = raw > 1 ? 1 : raw;
      this.playerDropY = 460 * t * t;
      if (t >= 1) {
        this.stopDropTimer();
        this.endGame();
      }
    }, FRAME_MS);
  }

  private endGame(): void {
    this.isJumping = false;
    this.status = GameStatus.OVER;
    GameDataManager.updateHighScore(GAME_ID, this.score);
  }

  // ---------------- 难度 / 返回 / 生命周期 ----------------

  changeDifficulty(d: GameDifficulty): void {
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
    if (this.status === GameStatus.PLAYING) {
      this.confirmExit = true;
      return true;
    }
    return false;
  }

  dismissExitConfirm(): void {
    this.confirmExit = false;
  }

  /** 结算当前对局分数（max 语义幂等） */
  private settleCurrentScore(): void {
    if (this.score > 0) { GameDataManager.updateHighScore(GAME_ID, this.score); }
  }

  /** 切后台：复位半途蓄力并结算当前分 */
  onAppHidden(): void {
    this.abortCharge();
    this.settleCurrentScore();
  }

  onAppShown(): void {
  }

  /** 页面销毁：停表并结算 */
  dispose(): void {
    this.stopAllTimers();
    this.settleCurrentScore();
  }

  private stopChargeTimer(): void {
    if (this.chargeTimer !== -1) {
      clearInterval(this.chargeTimer);
      this.chargeTimer = -1;
    }
  }

  private stopJumpTimer(): void {
    if (this.jumpTimer !== -1) {
      clearInterval(this.jumpTimer);
      this.jumpTimer = -1;
    }
  }

  private stopDropTimer(): void {
    if (this.dropTimer !== -1) {
      clearInterval(this.dropTimer);
      this.dropTimer = -1;
    }
  }

  private stopAllTimers(): void {
    this.stopChargeTimer();
    this.stopJumpTimer();
    this.stopDropTimer();
  }
}