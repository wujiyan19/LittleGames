/**
 * 游戏分类枚举
 *
 * 枚举值为英文逻辑标识，UI 显示文案通过 getCategoryLabel() 获取 $r() 资源引用。
 * 所有使用枚举成员（如 GameCategory.CLASSIC）做逻辑判断的代码不受影响。
 */
export enum GameCategory {
  CLASSIC = 'classic',
  PUZZLE = 'puzzle'
}

/**
 * 游戏难度
 *
 * 枚举值为英文逻辑标识，UI 显示文案通过 getDifficultyLabel() 获取 $r() 资源引用。
 */
export enum GameDifficulty {
  EASY = 'easy',
  NORMAL = 'normal',
  HARD = 'hard'
}

/**
 * 游戏信息接口
 *
 * name/description/scoreLabel 支持 Resource | string，以支持国际化资源引用。
 * ArkUI 的 Text() 组件原生接受 Resource | string，无需额外转换。
 * 非组件代码中需通过 I18nUtils.resolveString() 将 Resource 解析为 string。
 */
export interface GameInfo {
  id: string;
  name: Resource | string;
  category: GameCategory;
  icon: Resource | string;
  description: Resource | string;
  highScore: number;
  playCount: number;
  /**
   * 最高分的计分口径。各游戏分数量纲不同（有的是原始得分，有的由步数/用时/次数换算），
   * 排行页需显示对应口径，避免把不同含义的分数混为一谈。
   */
  scoreLabel: Resource | string;
}

/**
 * 将 GameCategory 枚举映射到国际化资源引用
 */
export function getCategoryLabel(category: GameCategory): Resource {
  if (category === GameCategory.CLASSIC) {
    return $r('app.string.cat_classic');
  }
  return $r('app.string.cat_puzzle');
}

/**
 * 将 GameDifficulty 枚举映射到国际化资源引用
 */
export function getDifficultyLabel(difficulty: GameDifficulty): Resource {
  if (difficulty === GameDifficulty.EASY) {
    return $r('app.string.diff_easy');
  }
  if (difficulty === GameDifficulty.NORMAL) {
    return $r('app.string.diff_normal');
  }
  return $r('app.string.diff_hard');
}

/**
 * 对局状态
 *
 * 各游戏页用单字段 @Local status: GameStatus 表达，取代原先
 * isPlaying + isPaused 双布尔组合（会产生「已结束但仍暂停」这类非法态）。
 * 胜负「结果」不在此枚举内——那是游戏数据，与「状态」是两回事
 * （如扫雷的 gameResult、猜数字的 isWin，由各自页面另行持有）。
 * IDLE 预留给「开局前」的页面形态，当前尚未使用。
 */
export enum GameStatus {
  IDLE = 'idle',
  PLAYING = 'playing',
  PAUSED = 'paused',
  OVER = 'over'
}
