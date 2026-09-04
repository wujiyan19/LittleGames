/**
 * 游戏分类枚举
 */
export enum GameCategory {
  CLASSIC = '经典休闲',
  PUZZLE = '益智解谜'
}

/**
 * 游戏难度
 */
export enum GameDifficulty {
  EASY = '简单',
  NORMAL = '普通',
  HARD = '困难'
}

/**
 * 游戏信息接口
 */
export interface GameInfo {
  id: string;
  name: string;
  category: GameCategory;
  icon: string;
  description: string;
  highScore: number;
  playCount: number;
  /**
   * 最高分的计分口径。各游戏分数量纲不同（有的是原始得分，有的由步数/用时/次数换算），
   * 排行页需显示对应口径，避免把不同含义的分数混为一谈。
   */
  scoreLabel: string;
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
