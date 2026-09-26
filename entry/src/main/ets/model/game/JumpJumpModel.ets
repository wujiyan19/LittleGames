/**
 * 跳一跳 —— Model 层（纯逻辑，零 ArkUI 依赖）
 *
 * 规则：玩家长按蓄力，松手后角色沿抛物线水平跳向下一个平台；
 * 落点落在目标平台水平范围内即成功（唯一判定条件，不引入高度差判定）。
 * 难度映射为「平台宽度 + 相邻平台间距」：
 *   简单 → 平台更宽、间距更近；困难 → 平台更窄、间距更远。
 * 同难度内平台宽度与间距取固定值，保证对局可预测、可复现。
 * 最大跳跃距离覆盖两平台中心距离，保证满蓄力可落台。
 *
 * 本层只做几何与判定，动画/相机/渲染留在 ViewModel 与 View。
 */
import { GameDifficulty } from '../../common/GameConstants';

/** 平台几何配置（vp）。gapMin/gapMax 保留区间语义，当前三档均取定值 */
export class JumpPlatformConfig {
  width: number;
  gapMin: number;
  gapMax: number;

  constructor(width: number, gapMin: number, gapMax: number) {
    this.width = width;
    this.gapMin = gapMin;
    this.gapMax = gapMax;
  }
}

/** 平台（世界坐标，centerX 为平台中心） */
export class JumpPlatform {
  centerX: number;
  width: number;

  constructor(centerX: number, width: number) {
    this.centerX = centerX;
    this.width = width;
  }

  left(): number {
    return this.centerX - this.width / 2;
  }

  right(): number {
    return this.centerX + this.width / 2;
  }
}

/** 落点判定结果 */
export class JumpOutcome {
  landed: boolean;
  landingX: number;

  constructor(landed: boolean, landingX: number) {
    this.landed = landed;
    this.landingX = landingX;
  }
}

export class JumpJumpRules {
  /** 三档难度的平台几何：简单更宽更近，困难更窄更远 */
  static configFor(difficulty: GameDifficulty): JumpPlatformConfig {
    if (difficulty === GameDifficulty.EASY) {
      return new JumpPlatformConfig(104, 120, 120);
    }
    if (difficulty === GameDifficulty.HARD) {
      return new JumpPlatformConfig(56, 185, 185);
    }
    return new JumpPlatformConfig(76, 150, 150);
  }

  /** 从当前平台中心起跳；满蓄力落在目标平台中心稍右处 */
  static maxJumpDistance(difficulty: GameDifficulty): number {
    const cfg: JumpPlatformConfig = JumpJumpRules.configFor(difficulty);
    // gap 是两平台边缘间距；同难度平台等宽，中心距离为 gap + width。
    // 额外四分之一平台宽度提供蓄满后的落点余量，仍在目标平台范围内。
    return cfg.gapMax + cfg.width * 1.25;
  }

  /** 蓄力比例（0~1）→ 水平跳跃距离；越界自动收敛到 [0,1] */
  static jumpDistance(ratio: number, difficulty: GameDifficulty): number {
    let r: number = ratio;
    if (r < 0) { r = 0; }
    if (r > 1) { r = 1; }
    return r * JumpJumpRules.maxJumpDistance(difficulty);
  }

  /** 在当前平台右侧生成下一个平台 */
  static spawnNext(current: JumpPlatform, difficulty: GameDifficulty): JumpPlatform {
    const cfg: JumpPlatformConfig = JumpJumpRules.configFor(difficulty);
    const gap: number = cfg.gapMin;
    const centerX: number = current.centerX + current.width / 2 + gap + cfg.width / 2;
    return new JumpPlatform(centerX, cfg.width);
  }

  /** 落点是否命中目标平台水平范围 */
  static judge(landingX: number, target: JumpPlatform): JumpOutcome {
    const landed: boolean = landingX >= target.left() && landingX <= target.right();
    return new JumpOutcome(landed, landingX);
  }
}
