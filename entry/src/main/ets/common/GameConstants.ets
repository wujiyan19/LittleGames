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
}

/**
 * 游戏状态
 */
export enum GameStatus {
  IDLE = 'idle',
  PLAYING = 'playing',
  PAUSED = 'paused',
  OVER = 'over'
}
